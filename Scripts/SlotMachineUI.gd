extends Control
class_name SlotMachineUI

@export_group("UI Colors")
@export var debt_color: Color = Color.RED
@export var coins_low_color: Color = Color.RED
@export var coins_warning_color: Color = Color.YELLOW
@export var coins_normal_color: Color = Color.WHITE
@export var result_win_color: Color = Color.GREEN
@export var result_jackpot_color: Color = Color.GOLD
@export var result_debt_color: Color = Color.BLUE
@export var result_lose_color: Color = Color.RED
@export var respawn_counter_color: Color = Color.ORANGE  # NEW
@export var pacman_blocked_color: Color = Color.RED  # NEW

@export_group("UI Settings")
@export var coins_low_threshold: int = 10
@export var coins_warning_threshold: int = 25
@export var payout_table_sprite_size: int = 20

signal spin_button_pressed
signal upgrade_button_pressed
signal pacman_button_pressed

@onready var debt_label = $TopPanel/DebtLabel
@onready var coins_label = $TopPanel/CoinsLabel
@onready var help_button = $TopPanel/HelpButton
@onready var spin_button = $BottomPanel/SpinButton
@onready var upgrade_button = $BottomPanel/UpgradeButton
@onready var pacman_button = get_node_or_null("BottomPanel/PacmanButton")  # Optional node
@onready var result_label = $CenterPanel/ResultLabel

# NEW: Coin respawn tracking UI
@onready var coin_respawn_label = create_coin_respawn_label()
@onready var pacman_status_label = create_pacman_status_label()

@onready var payout_table_panel = $PayoutTable
@onready var payout_table_container = $PayoutTable/ScrollContainer/VBoxContainer
@onready var debug_label = create_debug_label()

var config: SlotMachineConfig
var controller: SlotMachineController
var upgrade_shop_scene = null
var payout_table_visible: bool = false

func setup_with_config(slot_config: SlotMachineConfig):
	config = slot_config
	setup_payout_table()

func _ready():
	controller = get_parent() as SlotMachineController
	# Ensure PacmanButton exists
	ensure_pacman_button_exists()
	connect_buttons()
	connect_gamemanager_signals()  # NEW
	update_display()
	# Initialize coin respawn counter display
	var spins_left = GameManager.get_spins_until_coin_respawn()
	if spins_left > 0:
		_on_coin_respawn_counter_changed(spins_left)

func connect_buttons():
	if spin_button:
		spin_button.pressed.connect(_on_spin_button_pressed)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	if pacman_button:
		pacman_button.pressed.connect(_on_pacman_button_pressed)
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)

# NEW: Connect to GameManager signals for real-time updates
func connect_gamemanager_signals():
	if GameManager.has_signal("coin_respawn_counter_changed"):
		GameManager.coin_respawn_counter_changed.connect(_on_coin_respawn_counter_changed)
	if GameManager.has_signal("pacman_entry_status_changed"):
		GameManager.pacman_entry_status_changed.connect(_on_pacman_entry_status_changed)

# NEW: Create coin respawn counter label
func create_coin_respawn_label() -> Label:
	var label = Label.new()
	label.name = "CoinRespawnLabel"
	label.text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", respawn_counter_color)
	
	# Position it in the center-left area
	label.position = Vector2(50, 300)
	label.size = Vector2(300, 100)
	
	add_child(label)
	return label

# NEW: Create Pacman status label
func create_pacman_status_label() -> Label:
	var label = Label.new()
	label.name = "PacmanStatusLabel"
	label.text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", pacman_blocked_color)
	
	# Position it near the Pacman button
	label.position = Vector2(50, 400)
	label.size = Vector2(300, 60)
	
	add_child(label)
	return label

# NEW: Handle coin respawn counter updates
func _on_coin_respawn_counter_changed(spins_left: int):
	if not coin_respawn_label:
		return
	
	if spins_left > 0:
		coin_respawn_label.text = "🔄 Coin Respawn in: " + str(spins_left) + " spins"
		coin_respawn_label.visible = true
	else:
		coin_respawn_label.text = "✨ Coins Available!"
		# Hide after a moment
		await get_tree().create_timer(2.0).timeout
		if coin_respawn_label:
			coin_respawn_label.visible = false

# NEW: Handle Pacman entry status updates
func _on_pacman_entry_status_changed(can_enter: bool, reason: String):
	if not pacman_status_label:
		return
	
	if can_enter:
		pacman_status_label.text = ""
		pacman_status_label.visible = false
	else:
		pacman_status_label.text = "🚫 " + reason
		pacman_status_label.visible = true

func setup_payout_table():
	if not payout_table_container or not config:
		return
	
	# Clear existing content
	for child in payout_table_container.get_children():
		child.queue_free()
	
	# Calculate screen scale for header elements
	var screen_scale = get_viewport().get_visible_rect().size.y / 648.0
	
	# Create header
	var header = Label.new()
	header.text = "PAYOUT TABLE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", int(20 * screen_scale))
	header.add_theme_color_override("font_color", Color.YELLOW)
	payout_table_container.add_child(header)
	
	# Add multiplier info
	var multiplier_info = Label.new()
	multiplier_info.text = "2 Match = 1.5x | 3 Match = 3.0x"
	multiplier_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	multiplier_info.add_theme_font_size_override("font_size", int(14 * screen_scale))
	payout_table_container.add_child(multiplier_info)
	
	# Add separator
	var separator = HSeparator.new()
	payout_table_container.add_child(separator)
	
	# Add symbol entries
	for i in range(config.get_symbol_count()):
		var symbol_data = config.get_symbol_by_index(i)
		if symbol_data:
			create_payout_entry(symbol_data)

func create_payout_entry(symbol_data: SymbolData):
	var entry_container = HBoxContainer.new()
	
	# Scale container height with screen resolution
	var base_height = 32
	var screen_scale = get_viewport().get_visible_rect().size.y / 648.0
	var scaled_height = int(base_height * screen_scale)
	entry_container.custom_minimum_size.y = scaled_height
	
	payout_table_container.add_child(entry_container)

	if symbol_data.symbol_texture:
		# Create a container to strictly control the texture size
		var texture_container = Control.new()
		
		# Calculate size based on payout_table_sprite_size
		var final_size = max(8, 60 - payout_table_sprite_size * 2)
		
		# Force the container to be exactly this size
		texture_container.custom_minimum_size = Vector2(final_size, final_size)
		texture_container.size = Vector2(final_size, final_size)
		texture_container.clip_contents = true
		
		# Create the actual texture display
		var texture_rect = TextureRect.new()
		texture_rect.texture = symbol_data.symbol_texture
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		
		# Make texture fill the container exactly
		texture_rect.anchor_left = 0.0
		texture_rect.anchor_top = 0.0
		texture_rect.anchor_right = 1.0
		texture_rect.anchor_bottom = 1.0
		texture_rect.offset_left = 0
		texture_rect.offset_top = 0
		texture_rect.offset_right = 0
		texture_rect.offset_bottom = 0
		
		texture_container.add_child(texture_rect)
		entry_container.add_child(texture_container)
		
		# Add some spacing
		var spacer = Control.new()
		spacer.custom_minimum_size.x = int(8 * screen_scale)
		entry_container.add_child(spacer)
	else:
		var name_label = Label.new()
		name_label.text = symbol_data.symbol_name
		name_label.custom_minimum_size.x = int(60 * screen_scale)
		name_label.add_theme_font_size_override("font_size", int(14 * screen_scale))
		entry_container.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = get_payout_description(symbol_data)
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var base_font_size = 16
	var scaled_font_size = int(base_font_size * screen_scale)
	desc_label.add_theme_font_size_override("font_size", scaled_font_size)
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry_container.add_child(desc_label)

func get_compact_payout_description(symbol_data: SymbolData) -> String:
	match symbol_data.payout_type:
		"Jackpot":
			return "JACKPOT (3 only)"
		"Money":
			return "$" + format_number_compact(symbol_data.base_payout_amount)
		"Coins":
			return str(symbol_data.base_payout_amount) + " coins"
		_:
			return "Unknown"

func format_number_compact(num: int) -> String:
	if num >= 1000:
		return str(num / 1000) + "k"
	else:
		return str(num)

func get_payout_description(symbol_data: SymbolData) -> String:
	match symbol_data.payout_type:
		"Jackpot":
			return "JACKPOT! (3 only)"
		"Money":
			return "$" + str(symbol_data.base_payout_amount)
		"Coins":
			return str(symbol_data.base_payout_amount) + " coins"
		_:
			return "Unknown"

func _on_spin_button_pressed():
	spin_button_pressed.emit()

func _on_upgrade_button_pressed():
	upgrade_button_pressed.emit()

func _on_pacman_button_pressed():
	# NEW: Check if entry is allowed before emitting signal
	var entry_status = GameManager.get_pacman_entry_status()
	if entry_status.can_enter:
		pacman_button_pressed.emit()
	else:
		show_message(entry_status.reason)

func _on_help_button_pressed():
	payout_table_visible = not payout_table_visible
	if payout_table_panel:
		payout_table_panel.visible = payout_table_visible

func update_display():
	update_debt_display()
	update_coins_display()
	update_button_states()

func update_debt_display():
	if not debt_label or not controller:
		return
	
	debt_label.text = "DEBT: $" + str(controller.get_current_debt())
	debt_label.modulate = debt_color

func update_coins_display():
	if not coins_label or not controller:
		return
	
	var coins = controller.get_current_coins()
	coins_label.text = "COINS: " + str(coins)
	
	if coins < coins_low_threshold:
		coins_label.modulate = coins_low_color
	elif coins < coins_warning_threshold:
		coins_label.modulate = coins_warning_color
	else:
		coins_label.modulate = coins_normal_color

func update_button_states():
	if not spin_button or not controller:
		return
	
	var can_spin = controller.can_perform_spin()
	var spin_cost = controller.get_spin_cost()
	
	spin_button.disabled = not can_spin
	spin_button.text = "SPIN ($" + str(spin_cost) + ")"
	spin_button.modulate.a = 1.0 if can_spin else 0.6
	
	if upgrade_button:
		upgrade_button.visible = not controller.is_tutorial_mode()
		upgrade_button.text = "UPGRADES"
	
	if pacman_button:
		pacman_button.visible = not controller.is_tutorial_mode()
		pacman_button.text = "ENTER MAZE"
		# NEW: Use enhanced entry check
		var entry_status = GameManager.get_pacman_entry_status()
		pacman_button.disabled = not entry_status.can_enter
	
	if help_button:
		help_button.text = "?" if not payout_table_visible else "X"

func set_spinning_state(spinning: bool):
	if spin_button:
		spin_button.disabled = spinning
		spin_button.modulate.a = 0.6 if spinning else 1.0

func display_result(result: Dictionary):
	if not result_label:
		return
	
	var winning_line_text = ""
	if result.match_count >= 2:
		var positions = result.winning_positions
		var line_description = get_line_description(positions)
		winning_line_text = "\n" + line_description
	
	match result.type:
		"jackpot":
			result_label.text = "🎉 JACKPOT! DEBT CLEARED! 🎉" + winning_line_text
			result_label.modulate = result_jackpot_color
		"coin_win":
			result_label.text = "💰 WON " + str(result.coins_won) + " COINS! 💰" + winning_line_text
			result_label.modulate = result_win_color
		"debt_win":
			result_label.text = "💳 DEBT REDUCED BY $" + str(result.debt_reduction) + "! 💳" + winning_line_text
			result_label.modulate = result_debt_color
		_:
			result_label.text = "💸 YOU LOSE! 💸"
			result_label.modulate = result_lose_color
	
	clear_result_after_delay()

func get_line_description(positions: Array) -> String:
	if positions.size() < 2:
		return ""
	
	# Sort positions to show them in order
	var sorted_positions = positions.duplicate()
	sorted_positions.sort()
	
	var line_text = "Winning Line: "
	for i in range(sorted_positions.size()):
		line_text += "Reel " + str(sorted_positions[i] + 1)
		if i < sorted_positions.size() - 1:
			line_text += " + "
	
	return line_text

func show_evil_message():
	if not result_label:
		return
	
	result_label.text = "😈 MWAHAHAHA! TO THE MAZE! 😈"
	result_label.modulate = result_lose_color
	
	# Use safer timer callback
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(_on_evil_message_timer_finished)

func _on_evil_message_timer_finished():
	clear_result()

func clear_result_after_delay():
	var delay_time = 3.0
	if config:
		delay_time = config.result_display_time
	
	# Use safer timer callback
	var timer = get_tree().create_timer(delay_time)
	timer.timeout.connect(_on_clear_result_timer_finished)

func _on_clear_result_timer_finished():
	clear_result()

func clear_result():
	if result_label:
		result_label.text = ""

func create_debug_label() -> Label:
	var debug = Label.new()
	debug.name = "DebugLabel"
	debug.position = Vector2(10, 100)
	debug.add_theme_font_size_override("font_size", 14)
	debug.add_theme_color_override("font_color", Color.CYAN)
	debug.visible = false
	add_child(debug)
	return debug

func update_debug_info(symbols: Array[int], result: Dictionary):
	if not debug_label or not config:
		return
	
	var debug_text = "DEBUG INFO:\n"
	debug_text += "Symbols: " + str(symbols) + "\n"
	debug_text += "Match Count: " + str(result.match_count) + "\n"
	debug_text += "Winning Symbol: " + str(result.winning_symbol) + "\n"
	debug_text += "Positions: " + str(result.winning_positions) + "\n"
	debug_text += "Result Type: " + result.type
	
	debug_label.text = debug_text
	debug_label.visible = true
	
	# Hide after a few seconds - use safer callback method
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_on_debug_timer_finished)

func show_upgrade_shop():
	if upgrade_shop_scene:
		upgrade_shop_scene.show_shop()
		return
	
	var upgrade_scene_path = "res://Scenes/UpgradeShop.tscn"
	if ResourceLoader.exists(upgrade_scene_path):
		upgrade_shop_scene = preload("res://Scenes/UpgradeShop.tscn").instantiate()
		get_tree().current_scene.add_child(upgrade_shop_scene)
		upgrade_shop_scene.show_shop()
	else:
		push_error("Upgrade shop scene not found!")

func show_victory_screen():
	var victory_popup = AcceptDialog.new()
	victory_popup.dialog_text = "🎉 CONGRATULATIONS! YOU'VE PAID OFF YOUR DEBT! 🎉"
	add_child(victory_popup)
	victory_popup.popup_centered()
	
	# Use safer timer callback
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_on_victory_timer_finished.bind(victory_popup))

func _on_victory_timer_finished(popup: AcceptDialog):
	if popup and is_instance_valid(popup):
		popup.queue_free()

func show_message(message: String):
	if result_label:
		result_label.text = message
		result_label.modulate = Color.YELLOW
		clear_result_after_delay()

# Ensure PacmanButton exists in the UI
func ensure_pacman_button_exists():
	if pacman_button:
		return  # Button already exists
	
	# Create PacmanButton if it doesn't exist
	var bottom_panel = get_node_or_null("BottomPanel")
	if not bottom_panel:
		print("ERROR: BottomPanel not found - cannot create PacmanButton")
		return
	
	print("Creating missing PacmanButton...")
	pacman_button = Button.new()
	pacman_button.name = "PacmanButton"
	pacman_button.text = "ENTER MAZE"
	pacman_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add to bottom panel
	bottom_panel.add_child(pacman_button)
	
	# Style the button to match others
	pacman_button.add_theme_font_size_override("font_size", 16)
	
	print("PacmanButton created successfully")

# Debug timer callback
func _on_debug_timer_finished():
	if debug_label:
		debug_label.visible = false

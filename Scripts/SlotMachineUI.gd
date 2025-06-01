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

@export_group("UI Settings")
@export var coins_low_threshold: int = 10
@export var coins_warning_threshold: int = 25
@export var show_info_panel: bool = true

signal spin_button_pressed
signal upgrade_button_pressed
signal info_panel_toggled(visible: bool)

@onready var debt_label = $TopPanel/DebtLabel
@onready var coins_label = $TopPanel/CoinsLabel
@onready var spin_button = $BottomPanel/SpinButton
@onready var upgrade_button = $BottomPanel/UpgradeButton
@onready var info_button = $BottomPanel/InfoButton
@onready var result_label = $CenterPanel/ResultLabel
var info_panel: Panel

var config: SlotMachineConfig
var controller: SlotMachineController
var upgrade_shop_scene = null
var info_panel_visible: bool = false

func setup_with_config(slot_config: SlotMachineConfig):
	config = slot_config

func _ready():
	controller = get_parent() as SlotMachineController
	connect_buttons()
	setup_info_panel()
	update_display()

func connect_buttons():
	if spin_button:
		spin_button.pressed.connect(_on_spin_button_pressed)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	if info_button:
		info_button.pressed.connect(_on_info_button_pressed)

func setup_info_panel():
	if not info_panel:
		create_info_panel()
	
	if info_panel:
		info_panel.visible = false
		update_info_panel_content()

func create_info_panel():
	info_panel = Panel.new()
	info_panel.name = "InfoPanel"
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	info_panel.size = Vector2(400, 300)
	info_panel.visible = false
	add_child(info_panel)
	
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_panel.add_child(scroll_container)
	
	var content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	scroll_container.add_child(content_container)
	
	var title_label = Label.new()
	title_label.text = "SYMBOL PAYOUTS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	content_container.add_child(title_label)
	
	var close_button = Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(_on_info_button_pressed)
	content_container.add_child(close_button)

func update_info_panel_content():
	if not info_panel or not config:
		return
	
	var content_container = info_panel.get_node_or_null("ScrollContainer/ContentContainer")
	if not content_container:
		return
	
	# Clear existing symbol info (keep title and close button)
	var children_to_remove = []
	for child in content_container.get_children():
		if child.name.begins_with("SymbolInfo"):
			children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()
	
	# Add symbol information
	for i in range(config.get_symbol_count()):
		var symbol_data = config.get_symbol_by_index(i)
		if symbol_data:
			create_symbol_info_entry(content_container, symbol_data)

func create_symbol_info_entry(container: VBoxContainer, symbol_data: SymbolData):
	var info_container = HBoxContainer.new()
	info_container.name = "SymbolInfo" + str(symbol_data.symbol_index)
	container.add_child(info_container)
	
	# Symbol icon
	if symbol_data.symbol_texture:
		var texture_rect = TextureRect.new()
		texture_rect.texture = symbol_data.symbol_texture
		texture_rect.custom_minimum_size = Vector2(32, 32)
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		info_container.add_child(texture_rect)
	
	# Symbol description
	var desc_label = Label.new()
	desc_label.text = symbol_data.get_payout_description()
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_container.add_child(desc_label)

func _on_spin_button_pressed():
	spin_button_pressed.emit()

func _on_upgrade_button_pressed():
	upgrade_button_pressed.emit()

func _on_info_button_pressed():
	info_panel_visible = not info_panel_visible
	if info_panel:
		info_panel.visible = info_panel_visible
	info_panel_toggled.emit(info_panel_visible)

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
	
	if info_button:
		info_button.text = "INFO" if not info_panel_visible else "HIDE INFO"

func set_spinning_state(spinning: bool):
	if spin_button:
		spin_button.disabled = spinning
		spin_button.modulate.a = 0.6 if spinning else 1.0

func display_result(result: Dictionary):
	if not result_label:
		return
	
	match result.type:
		"jackpot":
			result_label.text = "🎉 JACKPOT! DEBT CLEARED! 🎉"
			result_label.modulate = result_jackpot_color
		"coin_win":
			result_label.text = "💰 WON " + str(result.coins_won) + " COINS! 💰"
			result_label.modulate = result_win_color
		"debt_win":
			result_label.text = "💳 DEBT REDUCED BY $" + str(result.debt_reduction) + "! 💳"
			result_label.modulate = result_debt_color
		_:
			result_label.text = "💸 YOU LOSE! 💸"
			result_label.modulate = result_lose_color
	
	clear_result_after_delay()

func show_evil_message():
	if not result_label:
		return
	
	result_label.text = "😈 MWAHAHAHA! TO THE MAZE! 😈"
	result_label.modulate = result_lose_color
	
	await get_tree().create_timer(4.0).timeout
	clear_result()

func clear_result_after_delay():
	if config:
		await get_tree().create_timer(config.result_display_time).timeout
	else:
		await get_tree().create_timer(3.0).timeout
	clear_result()

func clear_result():
	if result_label:
		result_label.text = ""

func show_upgrade_shop():
	if upgrade_shop_scene:
		upgrade_shop_scene.show_shop()
		return
	
	var upgrade_scene_path = "res://Scenes/UpgradeShop.tscn"
	if ResourceLoader.exists(upgrade_scene_path):
		upgrade_shop_scene = preload("res://Scenes/UpgradeShop.tscn").instantiate()
		add_child(upgrade_shop_scene)
		upgrade_shop_scene.show_shop()
	else:
		push_error("Upgrade shop scene not found!")

func show_victory_screen():
	var victory_popup = AcceptDialog.new()
	victory_popup.dialog_text = "🎉 CONGRATULATIONS! YOU'VE PAID OFF YOUR DEBT! 🎉"
	add_child(victory_popup)
	victory_popup.popup_centered()
	
	await get_tree().create_timer(5.0).timeout
	if victory_popup and is_instance_valid(victory_popup):
		victory_popup.queue_free()

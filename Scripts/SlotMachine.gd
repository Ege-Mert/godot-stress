extends Control

# UI References
@onready var debt_label = $UI/TopPanel/DebtLabel
@onready var coins_label = $UI/TopPanel/CoinsLabel
@onready var spin_button = $UI/BottomPanel/SpinButton
@onready var upgrade_button = $UI/BottomPanel/UpgradeButton

# Slot machine elements
@onready var handle = $SlotMachine/Handle
@onready var reel1 = $SlotMachine/Reels/Reel1
@onready var reel2 = $SlotMachine/Reels/Reel2
@onready var reel3 = $SlotMachine/Reels/Reel3
@onready var result_label = $UI/CenterPanel/ResultLabel

# Handle mechanics
var handle_original_pos: Vector2
var is_handle_dragging: bool = false
var handle_pulled: bool = false
var handle_pull_threshold: float = 50.0

# Reel mechanics - Sprite-based system
var reel_symbols = [
	"res://Sprites/cherry.png",
	"res://Sprites/lemon.png", 
	"res://Sprites/orange.png",
	"res://Sprites/bell.png",
	"res://Sprites/star.png",
	"res://Sprites/diamond.png",
	"res://Sprites/seven.png"
]
var reel_symbol_names = ["Cherry", "Lemon", "Orange", "Bell", "Star", "Diamond", "Seven"]  # Fallback text
var loaded_textures: Array[Texture2D] = []  # Cache for loaded textures
var is_spinning: bool = false
var reel_speeds = [0.0, 0.0, 0.0]
var reel_positions = [0.0, 0.0, 0.0]
var reel_target_positions = [0, 0, 0]  # Final symbol indices
var reel_stop_times = [0.0, 0.0, 0.0]
var spin_timer: float = 0.0
var current_spin_result: Dictionary = {}

# Upgrade shop
var upgrade_shop_scene = null

# Audio
@onready var audio_spin = $Audio/SpinSound
@onready var audio_win = $Audio/WinSound
@onready var audio_lose = $Audio/LoseSound
@onready var audio_evil_laugh = $Audio/EvilLaugh

func _ready():
	# Connect to GameManager signals
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.debt_changed.connect(_on_debt_changed)
	GameManager.spin_completed.connect(_on_spin_completed)
	GameManager.evil_laugh_trigger.connect(_on_evil_laugh)
	
	# Preload all textures for better performance
	preload_symbol_textures()
	
	# Debug: Check if reels exist
	print("=== SLOT MACHINE DEBUG ===")
	print("Reel1 exists: ", reel1 != null)
	print("Reel2 exists: ", reel2 != null)
	print("Reel3 exists: ", reel3 != null)
	print("Loaded textures: ", loaded_textures.size())
	if reel1:
		print("Reel1 type: ", reel1.get_class(), " size: ", reel1.size)
	
	# Set up handle
	if handle:
		handle_original_pos = handle.position
		# Make handle interactive
		var input_detector = Control.new()
		input_detector.set_size(handle.size if handle.size != Vector2.ZERO else Vector2(50, 100))
		input_detector.gui_input.connect(_on_handle_input)
		handle.add_child(input_detector)
	
	# Connect button signals
	spin_button.pressed.connect(_on_spin_button_pressed)
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	
	# Initialize reels
	initialize_reels()
	
	# Initialize UI
	update_ui()

func preload_symbol_textures():
	"""Preload all symbol textures for smooth animation"""
	loaded_textures.clear()
	
	for symbol_path in reel_symbols:
		var texture = load(symbol_path) as Texture2D
		if texture:
			loaded_textures.append(texture)
			print("Loaded texture: ", symbol_path)
		else:
			print("Failed to load texture: ", symbol_path)
			# Add null placeholder to maintain index alignment
			loaded_textures.append(null)
	
	print("Total textures loaded: ", loaded_textures.size())

func initialize_reels():
	# Set up initial reel display
	for i in range(3):
		var reel = [reel1, reel2, reel3][i]
		if reel:
			display_reel_symbol(reel, randi() % reel_symbols.size())

func display_reel_symbol(reel: Control, symbol_index: int):
	"""Display a single symbol on a reel using sprite or fallback text"""
	# Clear existing children
	for child in reel.get_children():
		child.queue_free()
	
	# Check if we have a valid texture
	if symbol_index < loaded_textures.size() and loaded_textures[symbol_index]:
		# Create sprite node
		var sprite = TextureRect.new()
		sprite.texture = loaded_textures[symbol_index]
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sprite.modulate = Color.WHITE  # Final symbol is fully opaque
		reel.add_child(sprite)
	else:
		# Fallback to text label
		var label = Label.new()
		if symbol_index < reel_symbol_names.size():
			label.text = reel_symbol_names[symbol_index]
		else:
			label.text = "?"
		label.add_theme_font_size_override("font_size", 48)  # Larger final symbol
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.modulate = Color.WHITE
		reel.add_child(label)

func _on_handle_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_handle_mouse_down()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			release_handle()
	
	elif event is InputEventMouseMotion and is_handle_dragging:
		var pull_distance = event.position.y
		pull_distance = max(0, pull_distance)  # Only allow downward pull
		
		# Update handle position
		if handle:
			handle.position.y = handle_original_pos.y + min(pull_distance, handle_pull_threshold)
		
		# Check if pulled enough
		if pull_distance >= handle_pull_threshold and not handle_pulled:
			handle_pulled = true
			trigger_spin()

func _on_handle_mouse_down():
	if is_spinning or not GameManager.can_spin():
		return
	
	is_handle_dragging = true
	handle_pulled = false

func release_handle():
	is_handle_dragging = false
	
	# Animate handle back to original position
	if handle:
		var tween = create_tween()
		tween.tween_property(handle, "position", handle_original_pos, 0.3)
		tween.tween_callback(func(): handle_pulled = false)

func _on_spin_button_pressed():
	if not is_spinning and GameManager.can_spin():
		trigger_spin()

func trigger_spin():
	if is_spinning or not GameManager.can_spin():
		print("Cannot spin: is_spinning=", is_spinning, " can_spin=", GameManager.can_spin())
		return
	
	print("Starting spin...")
	is_spinning = true
	spin_timer = 0.0
	
	# Disable controls
	spin_button.disabled = true
	
	# Start reel spinning animation first
	start_reel_animation()
	
	# Play spin sound
	if audio_spin and audio_spin.stream:
		audio_spin.play()
	
	# Schedule reel stops (staggered for realism)
	reel_stop_times[0] = 2.0  # First reel stops after 2 seconds
	reel_stop_times[1] = 2.8  # Second reel stops after 2.8 seconds
	reel_stop_times[2] = 3.5  # Third reel stops after 3.5 seconds
	
	# Process spin result AFTER reels would stop
	call_deferred("process_spin_result_delayed")

func process_spin_result_delayed():
	# Wait for reels to stop before processing result
	await get_tree().create_timer(4.0).timeout
	
	# Get spin result and determine final symbols
	current_spin_result = GameManager.perform_spin()
	
	# Set target symbols based on result
	set_target_symbols_from_result(current_spin_result)

func set_target_symbols_from_result(result: Dictionary):
	# Set target symbols based on win/loss
	match result.type:
		"jackpot":
			# Three 7s for jackpot
			reel_target_positions = [6, 6, 6]  # 7️⃣ is at index 6
		
		"coin_win", "debt_win":
			# Two matching symbols for smaller wins
			var winning_symbol = randi() % 5  # Use first 5 symbols for wins
			reel_target_positions = [winning_symbol, winning_symbol, randi() % reel_symbols.size()]
		
		"loss":
			# Ensure no matches for losses
			reel_target_positions = [0, 1, 2]  # Different symbols

func start_reel_animation():
	print("Starting reel animation...")
	# Set initial spinning speeds (fast)
	reel_speeds[0] = 30.0  # symbols per second
	reel_speeds[1] = 32.0
	reel_speeds[2] = 28.0
	
	# Reset positions
	reel_positions = [0.0, 0.0, 0.0]
	print("Reel speeds set: ", reel_speeds)

func _process(delta):
	if not is_spinning:
		return
	
	spin_timer += delta
	
	# Debug output every second
	if int(spin_timer) != int(spin_timer - delta):  # New second
		print("Spin timer: ", spin_timer, " Reel speeds: ", reel_speeds)
	
	# Update reel animations
	for i in range(3):
		if spin_timer < reel_stop_times[i]:
			# Still spinning - create rolling effect
			reel_speeds[i] = max(5.0, reel_speeds[i])  # Minimum speed
			reel_positions[i] += reel_speeds[i] * delta
			
			# Create rolling effect by showing multiple symbols
			update_rolling_reel(i)
		
		elif reel_speeds[i] > 0.0:  # Explicit float comparison
			# Time to slow down this reel
			reel_speeds[i] = max(0.0, reel_speeds[i] - 40.0 * delta)  # Explicit float values
			
			if reel_speeds[i] <= 0.0:  # Explicit float comparison
				# Stopped - show final symbol
				print("Reel ", i, " stopped")
				finalize_reel(i)
	
	# Check if all reels stopped
	if reel_speeds[0] <= 0.0 and reel_speeds[1] <= 0.0 and reel_speeds[2] <= 0.0:  # Explicit float comparisons
		print("All reels stopped, completing spin")
		complete_spin()

func update_rolling_reel(reel_index: int):
	"""Create vertical scrolling effect for reel during spinning"""
	var reel = [reel1, reel2, reel3][reel_index]
	if not reel:
		return
	
	# Clear existing children
	for child in reel.get_children():
		child.queue_free()
	
	# Create multiple symbols for scrolling effect
	var symbols_to_show = 3  # Show 3 symbols at once
	var symbol_height = reel.size.y / float(symbols_to_show)
	var scroll_offset = fmod(reel_positions[reel_index], 1.0) * symbol_height
	
	for i in range(symbols_to_show + 1):  # +1 for smooth scrolling
		var symbol_index = (int(reel_positions[reel_index]) + i) % reel_symbols.size()
		var y_pos = (i * symbol_height) - scroll_offset
		
		# Only create symbol if it's visible in the reel area
		if y_pos > -symbol_height and y_pos < reel.size.y:
			create_scrolling_symbol(reel, symbol_index, y_pos, symbol_height)

func create_scrolling_symbol(reel: Control, symbol_index: int, y_pos: float, height: float):
	"""Create a single symbol for the scrolling effect"""
	if symbol_index < loaded_textures.size() and loaded_textures[symbol_index]:
		# Create sprite for scrolling
		var sprite = TextureRect.new()
		sprite.texture = loaded_textures[symbol_index]
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		
		# Position and size the sprite to fill the reel area properly
		sprite.position = Vector2(0, y_pos)
		sprite.size = Vector2(reel.size.x, height)
		
		# Ensure sprite fills the area properly
		sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
		
		# Add spinning effect
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.9)
		
		reel.add_child(sprite)
	else:
		# Text fallback for scrolling
		var label = Label.new()
		if symbol_index < reel_symbol_names.size():
			label.text = reel_symbol_names[symbol_index]
		else:
			label.text = "?"
		
		label.add_theme_font_size_override("font_size", int(height * 0.6))  # Larger font
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Position and size the label
		label.position = Vector2(0, y_pos)
		label.size = Vector2(reel.size.x, height)
		
		# Add spinning effect
		label.modulate = Color.YELLOW
		
		reel.add_child(label)

func create_symbol_node(symbol_index: int) -> Node2D:
	# Ensure valid symbol index
	if symbol_index < 0 or symbol_index >= reel_symbols.size():
		symbol_index = 0
	
	var texture = load(reel_symbols[symbol_index])
	
	if texture:
		var sprite = Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2(0.6, 0.6)
		return sprite
	else:
		# Fallback to text
		var label = Label.new()
		if symbol_index < reel_symbol_names.size():
			label.text = reel_symbol_names[symbol_index]
		else:
			label.text = "?"
		label.add_theme_font_size_override("font_size", 32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return label

func finalize_reel(reel_index: int):
	var reel = [reel1, reel2, reel3][reel_index]
	var target_symbol = reel_target_positions[reel_index]
	
	display_reel_symbol(reel, target_symbol)

func complete_spin():
	is_spinning = false
	
	# Wait a moment before showing result and re-enabling controls
	await get_tree().create_timer(1.0).timeout
	
	spin_button.disabled = false
	
	# The result was already processed by GameManager, just show feedback
	# This is handled by the _on_spin_completed signal

func _on_spin_completed(result: Dictionary):
	# Display result
	match result.type:
		"jackpot":
			result_label.text = "🎉 JACKPOT! DEBT CLEARED! 🎉"
			result_label.modulate = Color.GOLD
			if audio_win and audio_win.stream:
				audio_win.play()
		
		"coin_win":
			result_label.text = "💰 WON " + str(result.coins_won) + " COINS! 💰"
			result_label.modulate = Color.GREEN
			if audio_win and audio_win.stream:
				audio_win.play()
		
		"debt_win":
			result_label.text = "💳 DEBT REDUCED BY $" + str(result.debt_reduction) + "! 💳"
			result_label.modulate = Color.BLUE
			if audio_win:
				audio_win.play()
		
		"loss":
			result_label.text = "💸 YOU LOSE! 💸"
			result_label.modulate = Color.RED
			if audio_lose and audio_lose.stream:
				audio_lose.play()
	
	# Clear result after delay
	await get_tree().create_timer(3.0).timeout
	result_label.text = ""

func _on_evil_laugh():
	if audio_evil_laugh and audio_evil_laugh.stream:
		audio_evil_laugh.play()
	
	# Visual effects for evil laugh
	var screen_shake_tween = create_tween()
	for i in range(10):
		screen_shake_tween.tween_property(self, "position", 
			Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.1)
	screen_shake_tween.tween_property(self, "position", Vector2.ZERO, 0.1)
	
	# Show evil message
	result_label.text = "😈 MWAHAHAHA! TO THE MAZE! 😈"
	result_label.modulate = Color.RED
	
	# Wait for visual/audio effects to complete, then transition
	await get_tree().create_timer(6.0).timeout  # Increased from 5.0 to 6.0 for better readability
	transition_to_pacman()

func transition_to_pacman():
	# Load Pacman scene
	get_tree().change_scene_to_file("res://Scenes/PacmanScene.tscn")

func _on_upgrade_button_pressed():
	# Create and show upgrade shop
	if not upgrade_shop_scene:
		upgrade_shop_scene = preload("res://Scenes/UpgradeShop.tscn").instantiate()
		add_child(upgrade_shop_scene)
	
	upgrade_shop_scene.show_shop()

func _on_coins_changed(_new_amount: int):
	update_ui()

func _on_debt_changed(_new_amount: int):
	update_ui()
	
	# Check win condition
	if GameManager.is_game_won():
		show_victory_screen()

func update_ui():
	if debt_label:
		debt_label.text = "DEBT: $" + str(GameManager.total_debt)
	if coins_label:
		coins_label.text = "COINS: " + str(GameManager.current_coins)
	
	# Update button states
	if spin_button:
		spin_button.disabled = not GameManager.can_spin() or is_spinning
	
	# Hide upgrade button during tutorial (first spin)
	if upgrade_button:
		upgrade_button.visible = not GameManager.is_tutorial_mode
	
	# Color coding for stress
	if coins_label:
		if GameManager.current_coins < 10:
			coins_label.modulate = Color.RED
		elif GameManager.current_coins < 25:
			coins_label.modulate = Color.YELLOW
		else:
			coins_label.modulate = Color.WHITE

func show_victory_screen():
	# Simple victory display
	var victory_popup = AcceptDialog.new()
	victory_popup.dialog_text = "🎉 CONGRATULATIONS! YOU'VE PAID OFF YOUR DEBT! 🎉"
	add_child(victory_popup)
	victory_popup.popup_centered()

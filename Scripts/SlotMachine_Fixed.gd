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

# Reel mechanics - Optimized for performance
var reel_symbols: Array[String] = [
	"res://Sprites/cherry.png",
	"res://Sprites/lemon.png", 
	"res://Sprites/orange.png",
	"res://Sprites/bell.png",
	"res://Sprites/star.png",
	"res://Sprites/diamond.png",
	"res://Sprites/seven.png"
]
var reel_symbol_names: Array[String] = ["Cherry", "Lemon", "Orange", "Bell", "Star", "Diamond", "Seven"]
var loaded_textures: Array[Texture2D] = []
var is_spinning: bool = false

# Simplified reel system for better performance
var final_symbols: Array[int] = [0, 0, 0]  # Final symbols to display
var spin_tweens: Array[Tween] = []

# Upgrade shop
var upgrade_shop_scene = null

# Audio with null safety
@onready var audio_spin = $Audio/SpinSound
@onready var audio_win = $Audio/WinSound
@onready var audio_lose = $Audio/LoseSound
@onready var audio_evil_laugh = $Audio/EvilLaugh

func _ready():
	print("🎰 Starting SlotMachine scene...")
	
	# Connect to GameManager signals with error handling
	if GameManager.has_signal("coins_changed"):
		GameManager.coins_changed.connect(_on_coins_changed)
	if GameManager.has_signal("debt_changed"):
		GameManager.debt_changed.connect(_on_debt_changed)
	if GameManager.has_signal("spin_completed"):
		GameManager.spin_completed.connect(_on_spin_completed)
	if GameManager.has_signal("evil_laugh_trigger"):
		GameManager.evil_laugh_trigger.connect(_on_evil_laugh)
	
	# Preload textures safely
	preload_symbol_textures()
	
	# Set up handle with error checking
	setup_handle()
	
	# Connect button signals with null checks
	if spin_button:
		spin_button.pressed.connect(_on_spin_button_pressed)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	
	# Initialize reels
	initialize_reels()
	
	# Initialize UI
	update_ui()
	
	print("✅ SlotMachine initialization complete")

func preload_symbol_textures():
	"""Safely preload all symbol textures"""
	loaded_textures.clear()
	
	for i in range(reel_symbols.size()):
		var symbol_path = reel_symbols[i]
		var texture: Texture2D = null
		
		if ResourceLoader.exists(symbol_path):
			texture = load(symbol_path) as Texture2D
		
		if texture:
			loaded_textures.append(texture)
			print("✅ Loaded: ", reel_symbol_names[i])
		else:
			print("❌ Failed: ", symbol_path)
			# Create a fallback texture or use null
			loaded_textures.append(null)
	
	print("🎨 Textures loaded: ", loaded_textures.size(), "/", reel_symbols.size())

func setup_handle():
	"""Set up handle with proper null checking"""
	if not handle:
		print("⚠️ Handle not found")
		return
	
	handle_original_pos = handle.position
	
	# Create input detector as a simple Control node
	var input_detector = Control.new()
	input_detector.name = "InputDetector"
	input_detector.size = Vector2(50, 100)  # Fixed size
	input_detector.gui_input.connect(_on_handle_input)
	input_detector.mouse_filter = Control.MOUSE_FILTER_PASS
	handle.add_child(input_detector)
	
	print("🕹️ Handle setup complete")

func initialize_reels():
	"""Initialize reels with random symbols"""
	var reels = [reel1, reel2, reel3]
	
	for i in range(reels.size()):
		if reels[i]:
			var random_symbol = randi() % reel_symbols.size()
			final_symbols[i] = random_symbol
			display_symbol_on_reel(reels[i], random_symbol)

func display_symbol_on_reel(reel_control: Control, symbol_index: int):
	"""Display a single symbol on a reel"""
	if not reel_control:
		return
	
	# Clear existing children
	for child in reel_control.get_children():
		child.queue_free()
	
	# Wait one frame for children to be freed
	await get_tree().process_frame
	
	# Create symbol display
	if symbol_index < loaded_textures.size() and loaded_textures[symbol_index]:
		# Use texture
		var texture_rect = TextureRect.new()
		texture_rect.texture = loaded_textures[symbol_index]
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		reel_control.add_child(texture_rect)
	else:
		# Fallback to text
		var label = Label.new()
		if symbol_index < reel_symbol_names.size():
			label.text = reel_symbol_names[symbol_index]
		else:
			label.text = "?"
		
		label.add_theme_font_size_override("font_size", 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		reel_control.add_child(label)

func _on_handle_input(event):
	"""Handle input with proper error checking"""
	if not handle or is_spinning or not GameManager.can_spin():
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			start_handle_drag()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			release_handle()
	
	elif event is InputEventMouseMotion and is_handle_dragging:
		var pull_distance = event.position.y
		pull_distance = max(0, pull_distance)  # Only allow downward pull
		
		# Update handle position safely
		if handle:
			handle.position.y = handle_original_pos.y + min(pull_distance, handle_pull_threshold)
		
		# Check if pulled enough
		if pull_distance >= handle_pull_threshold and not handle_pulled:
			handle_pulled = true
			trigger_spin()

func start_handle_drag():
	"""Start handle dragging"""
	is_handle_dragging = true
	handle_pulled = false

func release_handle():
	"""Release handle and animate back"""
	is_handle_dragging = false
	
	if handle:
		var tween = create_tween()
		tween.tween_property(handle, "position", handle_original_pos, 0.3)
		tween.tween_callback(func(): handle_pulled = false)

func _on_spin_button_pressed():
	"""Handle spin button press"""
	if not is_spinning and GameManager.can_spin():
		trigger_spin()

func trigger_spin():
	"""Start the spinning process"""
	if is_spinning or not GameManager.can_spin():
		return
	
	print("🎰 Starting spin...")
	is_spinning = true
	
	# Get spin result first (this determines final symbols)
	var spin_result = GameManager.perform_spin()
	if not spin_result.get("success", true):
		print("❌ Spin failed: ", spin_result.get("reason", "unknown"))
		is_spinning = false
		return
	
	# Set final symbols based on result
	set_final_symbols_from_result(spin_result)
	
	# Disable controls
	if spin_button:
		spin_button.disabled = true
	
	# Play audio safely
	play_audio(audio_spin)
	
	# Start visual spinning animation
	start_spin_animation()

func set_final_symbols_from_result(result: Dictionary):
	"""Set the final symbols based on the spin result"""
	print("🎯 Setting symbols for result: ", result.type)
	
	match result.type:
		"jackpot":
			# All sevens
			final_symbols = [6, 6, 6]  # Seven is at index 6
			print("🎉 JACKPOT: Three Sevens!")
		
		"coin_win", "debt_win":
			# Two matching symbols
			var winning_symbol = randi() % 5  # Use first 5 symbols for wins
			var different_symbol = (winning_symbol + 1 + randi() % 4) % reel_symbols.size()
			final_symbols = [winning_symbol, winning_symbol, different_symbol]
			print("💰 WIN: ", reel_symbol_names[winning_symbol], " x2 + ", reel_symbol_names[different_symbol])
		
		_:  # "loss" or any other case
			# Three different symbols
			var symbol1 = randi() % reel_symbols.size()
			var symbol2 = (symbol1 + 1 + randi() % 3) % reel_symbols.size()
			var symbol3 = (symbol2 + 1 + randi() % 3) % reel_symbols.size()
			final_symbols = [symbol1, symbol2, symbol3]
			print("💸 LOSS: ", reel_symbol_names[symbol1], ", ", reel_symbol_names[symbol2], ", ", reel_symbol_names[symbol3])

func start_spin_animation():
	"""Start simplified spin animation for better performance"""
	var reels = [reel1, reel2, reel3]
	
	# Clear any existing tweens
	for tween in spin_tweens:
		if tween and tween.is_valid():
			tween.kill()
	spin_tweens.clear()
	
	# Create spinning effect for each reel
	for i in range(reels.size()):
		if not reels[i]:
			continue
		
		var reel = reels[i]
		var final_symbol = final_symbols[i]
		
		# Create tween for this reel
		var tween = create_tween()
		spin_tweens.append(tween)
		
		# Animate spinning effect
		var spin_duration = 1.5 + (i * 0.4)  # Staggered timing
		
		# Simple rotation-based spinning effect
		tween.tween_method(
			func(angle): animate_reel_spin(reel, angle, final_symbol),
			0.0,
			360.0 * 3,  # 3 full rotations
			spin_duration
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		
		# When the last reel finishes, complete the spin
		if i == reels.size() - 1:
			tween.tween_callback(complete_spin)

func animate_reel_spin(reel: Control, angle: float, final_symbol: int):
	"""Animate reel with rotation effect"""
	if not reel:
		return
	
	# Calculate which symbol to show based on angle
	var symbol_count = reel_symbols.size()
	var current_symbol_index = int(angle / 51.4) % symbol_count  # ~51.4 degrees per symbol
	
	# Near the end of animation, lock to final symbol
	if angle > 900:  # Last 180 degrees
		current_symbol_index = final_symbol
	
	# Clear and display current symbol
	for child in reel.get_children():
		child.queue_free()
	
	# Create symbol with rotation effect
	if current_symbol_index < loaded_textures.size() and loaded_textures[current_symbol_index]:
		var texture_rect = TextureRect.new()
		texture_rect.texture = loaded_textures[current_symbol_index]
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Add slight rotation for spinning effect
		if angle < 900:
			texture_rect.rotation = deg_to_rad(sin(angle * 0.1) * 5)  # Subtle wobble
		
		reel.add_child(texture_rect)
	else:
		# Text fallback
		var label = Label.new()
		if current_symbol_index < reel_symbol_names.size():
			label.text = reel_symbol_names[current_symbol_index]
		else:
			label.text = "?"
		
		label.add_theme_font_size_override("font_size", 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		if angle < 900:
			label.rotation = deg_to_rad(sin(angle * 0.1) * 5)
		
		reel.add_child(label)

func complete_spin():
	"""Complete the spin and show results"""
	print("🎉 Spin animation complete")
	is_spinning = false
	
	# Re-enable controls
	if spin_button:
		spin_button.disabled = false
	
	# Final display of symbols
	var reels = [reel1, reel2, reel3]
	for i in range(reels.size()):
		if reels[i]:
			display_symbol_on_reel(reels[i], final_symbols[i])
	
	# The result will be shown via the GameManager signal

func _on_spin_completed(result: Dictionary):
	"""Handle spin completion from GameManager"""
	if not result_label:
		return
	
	# Display result with color coding
	match result.type:
		"jackpot":
			result_label.text = "🎉 JACKPOT! DEBT CLEARED! 🎉"
			result_label.modulate = Color.GOLD
			play_audio(audio_win)
		
		"coin_win":
			result_label.text = "💰 WON " + str(result.coins_won) + " COINS! 💰"
			result_label.modulate = Color.GREEN
			play_audio(audio_win)
		
		"debt_win":
			result_label.text = "💳 DEBT REDUCED BY $" + str(result.debt_reduction) + "! 💳"
			result_label.modulate = Color.BLUE
			play_audio(audio_win)
		
		_:  # Loss
			result_label.text = "💸 YOU LOSE! 💸"
			result_label.modulate = Color.RED
			play_audio(audio_lose)
	
	# Clear result after delay
	await get_tree().create_timer(3.0).timeout
	if result_label:
		result_label.text = ""

func _on_evil_laugh():
	"""Handle evil laugh with safe audio"""
	print("😈 EVIL LAUGH TRIGGERED!")
	
	play_audio(audio_evil_laugh)
	
	# Screen shake effect
	create_screen_shake()
	
	# Show evil message
	if result_label:
		result_label.text = "😈 MWAHAHAHA! TO THE MAZE! 😈"
		result_label.modulate = Color.RED
	
	# Transition after delay
	await get_tree().create_timer(4.0).timeout
	transition_to_pacman()

func create_screen_shake():
	"""Create screen shake effect safely"""
	var shake_tween = create_tween()
	var original_position = position
	
	for i in range(8):
		var shake_offset = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		shake_tween.tween_property(self, "position", original_position + shake_offset, 0.1)
	
	shake_tween.tween_property(self, "position", original_position, 0.1)

func transition_to_pacman():
	"""Safely transition to Pacman scene"""
	print("🚀 Transitioning to Pacman scene...")
	var pacman_scene_path = "res://Scenes/PacmanScene.tscn"
	
	if ResourceLoader.exists(pacman_scene_path):
		get_tree().change_scene_to_file(pacman_scene_path)
	else:
		print("❌ Pacman scene not found!")

func _on_upgrade_button_pressed():
	"""Handle upgrade button press"""
	if upgrade_shop_scene:
		upgrade_shop_scene.show_shop()
		return
	
	var upgrade_scene_path = "res://Scenes/UpgradeShop.tscn"
	if ResourceLoader.exists(upgrade_scene_path):
		upgrade_shop_scene = preload("res://Scenes/UpgradeShop.tscn").instantiate()
		add_child(upgrade_shop_scene)
		upgrade_shop_scene.show_shop()
	else:
		print("❌ Upgrade shop scene not found!")

func _on_coins_changed(_new_amount: int):
	"""Handle coins changed signal"""
	update_ui()

func _on_debt_changed(_new_amount: int):
	"""Handle debt changed signal"""
	update_ui()
	
	# Check win condition
	if GameManager.is_game_won():
		show_victory_screen()

func update_ui():
	"""Update UI elements safely"""
	if debt_label:
		debt_label.text = "DEBT: $" + str(GameManager.total_debt)
	
	if coins_label:
		coins_label.text = "COINS: " + str(GameManager.current_coins)
		
		# Color coding for stress
		if GameManager.current_coins < 10:
			coins_label.modulate = Color.RED
		elif GameManager.current_coins < 25:
			coins_label.modulate = Color.YELLOW
		else:
			coins_label.modulate = Color.WHITE
	
	# Update button states
	if spin_button:
		var can_spin = GameManager.can_spin() and not is_spinning
		spin_button.disabled = not can_spin
		var spin_cost = GameManager.get_spin_cost()
		spin_button.text = "SPIN ($" + str(spin_cost) + ")"
	
	# Hide upgrade button during tutorial
	if upgrade_button:
		upgrade_button.visible = not GameManager.is_tutorial_mode

func show_victory_screen():
	"""Show victory screen safely"""
	var victory_popup = AcceptDialog.new()
	victory_popup.dialog_text = "🎉 CONGRATULATIONS! YOU'VE PAID OFF YOUR DEBT! 🎉"
	add_child(victory_popup)
	victory_popup.popup_centered()
	
	# Auto-close after 5 seconds
	await get_tree().create_timer(5.0).timeout
	if victory_popup and is_instance_valid(victory_popup):
		victory_popup.queue_free()

func play_audio(audio_player: AudioStreamPlayer2D):
	"""Safely play audio with null checking"""
	if not audio_player:
		return
	
	if not audio_player.stream:
		print("⚠️ Audio player has no stream")
		return
	
	if audio_player.playing:
		audio_player.stop()
	
	audio_player.play()

# Cleanup function
func _exit_tree():
	"""Clean up when exiting"""
	# Stop all tweens
	for tween in spin_tweens:
		if tween and tween.is_valid():
			tween.kill()
	spin_tweens.clear()

extends Control
class_name SlotMachineController

@export_group("Configuration")
@export var config: SlotMachineConfig
@export var enable_debug_mode: bool = false

@export_group("Tutorial Settings")
@export var force_first_spin_loss: bool = true
@export var first_spin_symbols: Array[int] = [0, 1, 2]

signal spin_started
signal spin_completed(result: Dictionary)
signal evil_laugh_triggered

var ui_manager: SlotMachineUI
var reel_manager: SlotMachineReels
var handle_manager: SlotMachineHandle
var audio_manager: SlotMachineAudio

var is_spinning: bool = false
var current_spin_result: Dictionary

func _ready():
	# Web-safe random seeding - avoid randomize() on web
	if OS.has_feature("web"):
		# Use time-based seed instead of randomize() which calls get_process_id()
		var time_seed = Time.get_unix_time_from_system()
		seed(int(time_seed * 1000000) % 2147483647)  # Convert to valid seed range
	else:
		randomize()  # Safe to use on desktop platforms
	
	setup_configuration()
	setup_components()
	connect_signals()
	initialize_game()

func setup_configuration():
	if not config:
		config = SlotMachineConfig.new()
		create_basic_symbols()
		push_warning("No SlotMachineConfig assigned, using default configuration")

	if not config.validate_config():
		push_error("Invalid SlotMachine configuration!")

func create_basic_symbols():
	if not config:
		return

	config.symbols.clear()

	var symbol_names = ["Seven", "Diamond", "Bell", "Cherry", "Carrot", "Watermelon", "Strawberry"]
	var payout_types = ["Jackpot", "Money", "Money", "Money", "Coins", "Coins", "Coins"]
	var payouts = [1000000, 50000, 25000, 10000, 50, 25, 10]

	for i in range(symbol_names.size()):
		var symbol = SymbolData.new()
		symbol.symbol_name = symbol_names[i]
		symbol.symbol_index = i
		symbol.payout_type = payout_types[i]
		symbol.base_payout_amount = payouts[i]
		config.symbols.append(symbol)

func setup_components():
	ui_manager = $UI as SlotMachineUI
	reel_manager = $ReelManager as SlotMachineReels
	handle_manager = $HandleManager as SlotMachineHandle
	audio_manager = $AudioManager as SlotMachineAudio

	if not ui_manager:
		push_error("SlotMachineUI component not found!")
	if not reel_manager:
		push_error("SlotMachineReels component not found!")
	if not handle_manager:
		push_error("SlotMachineHandle component not found!")
	if not audio_manager:
		push_error("SlotMachineAudio component not found!")

	if reel_manager:
		reel_manager.setup_with_config(config)
	if ui_manager:
		ui_manager.setup_with_config(config)
	if audio_manager:
		audio_manager.setup_with_config(config)

func connect_signals():
	if GameManager.has_signal("coins_changed"):
		GameManager.coins_changed.connect(_on_coins_changed)
	if GameManager.has_signal("debt_changed"):
		GameManager.debt_changed.connect(_on_debt_changed)
	if GameManager.has_signal("evil_laugh_trigger"):
		GameManager.evil_laugh_trigger.connect(_on_evil_laugh_trigger)

	if ui_manager:
		ui_manager.spin_button_pressed.connect(_on_spin_requested)
		ui_manager.upgrade_button_pressed.connect(_on_upgrade_requested)

	if handle_manager:
		handle_manager.handle_pulled.connect(_on_spin_requested)

	if reel_manager:
		reel_manager.animation_completed.connect(_on_reel_animation_completed)
		reel_manager.reel_stopped.connect(_on_individual_reel_stopped)

func initialize_game():
	update_ui()
	if reel_manager:
		reel_manager.initialize_reels()

func _on_spin_requested():
	if can_perform_spin():
		perform_spin()

func can_perform_spin() -> bool:
	return not is_spinning and GameManager.can_spin()

func perform_spin():
	if not can_perform_spin():
		return

	is_spinning = true
	spin_started.emit()

	if not GameManager.deduct_spin_cost():
		is_spinning = false
		return

	if ui_manager:
		ui_manager.set_spinning_state(true)

	if audio_manager:
		audio_manager.play_spin_sound()

	# Start the reels spinning - result will be determined by where they stop
	if reel_manager:
		reel_manager.start_spin()

func _on_individual_reel_stopped(reel_index: int):
	if config.enable_screen_shake:
		create_reel_stop_shake()

	if audio_manager:
		audio_manager.play_reel_stop_sound()

func _on_reel_animation_completed():
	is_spinning = false

	# Get the actual symbols from where the reels stopped
	var final_symbols = reel_manager.get_final_symbols()

	# DEBUG: Print what symbols were detected
	print("DEBUG: Final symbols detected: ", final_symbols)
	for i in range(final_symbols.size()):
		if i < config.symbols.size():
			print("  Reel ", i, ": Symbol ", final_symbols[i], " (", config.symbols[final_symbols[i]].symbol_name, ")")

	# Handle first spin tutorial if needed
	if force_first_spin_loss and GameManager.is_first_spin and not GameManager.first_spin_completed:
		print("DEBUG: First tutorial spin detected - forcing loss")
		# Override with losing combination
		final_symbols = first_spin_symbols
		# Mark tutorial as completed to prevent override on future spins
		GameManager.first_spin_completed = true
		GameManager.is_first_spin = false
		print("DEBUG: Tutorial completed, future spins will use natural results")

	# Calculate result based on actual reel positions
	current_spin_result = calculate_result_from_symbols(final_symbols)

	print("DEBUG: Calculated result: ", current_spin_result)

	# Apply results to GameManager
	if current_spin_result.coins_won > 0:
		GameManager.current_coins += current_spin_result.coins_won
		GameManager.coins_changed.emit(GameManager.current_coins)

	if current_spin_result.debt_reduction > 0:
		GameManager.total_debt -= current_spin_result.debt_reduction
		GameManager.debt_changed.emit(GameManager.total_debt)

	if ui_manager:
		ui_manager.set_spinning_state(false)
		ui_manager.display_result(current_spin_result)

	# Highlight winning symbols
	if current_spin_result.match_count >= 2 and reel_manager:
		reel_manager.highlight_winning_symbols(current_spin_result)

	# Create win-specific screen shake
	if current_spin_result.type != "loss":
		create_win_shake(current_spin_result)

	play_result_audio(current_spin_result)
	spin_completed.emit(current_spin_result)

	if not GameManager.can_spin():
		call_deferred("trigger_evil_laugh")

func calculate_result_from_symbols(symbols: Array[int]) -> Dictionary:
	var result = {
		"symbols": symbols,
		"coins_won": 0,
		"debt_reduction": 0,
		"type": "loss",
		"match_count": 0,
		"winning_symbol": -1,
		"winning_positions": []  # Add this for highlighting
	}

	if enable_debug_mode:
		print("=== SPIN RESULT DEBUG ===")
		print("Symbols landed: ", symbols)
		for i in range(symbols.size()):
			var symbol_data = config.get_symbol_by_index(symbols[i])
			if symbol_data:
				print("Reel ", i + 1, ": ", symbol_data.symbol_name, " (index: ", symbols[i], ")")

	# Count exact matches
	var symbol_counts = {}
	for i in range(symbols.size()):
		var symbol = symbols[i]
		if not symbol_counts.has(symbol):
			symbol_counts[symbol] = []
		symbol_counts[symbol].append(i)

	# Find the highest match count
	var max_count = 0
	var winning_symbol = -1
	var winning_positions = []

	for symbol in symbol_counts.keys():
		var positions = symbol_counts[symbol]
		if positions.size() > max_count:
			max_count = positions.size()
			winning_symbol = symbol
			winning_positions = positions

	result.match_count = max_count
	result.winning_symbol = winning_symbol
	result.winning_positions = winning_positions

	if enable_debug_mode:
		print("Match count: ", max_count)
		if max_count >= 2:
			var symbol_data = config.get_symbol_by_index(winning_symbol)
			if symbol_data:
				print("Winning symbol: ", symbol_data.symbol_name)
				print("Winning positions: ", winning_positions)

	# Only award payouts for 2+ matches (and 3 for jackpot)
	if max_count >= 2:
		var symbol_data = config.get_symbol_by_index(winning_symbol)
		if symbol_data:
			var payout = symbol_data.get_payout_for_matches(max_count)

			if enable_debug_mode:
				print("Base payout: ", symbol_data.base_payout_amount)
				print("Final payout: ", payout)

			match symbol_data.payout_type:
				"Jackpot":
					if max_count == 3:
						result.debt_reduction = GameManager.total_debt
						result.type = "jackpot"
						if enable_debug_mode:
							print("JACKPOT! Debt cleared!")
				"Money":
					result.debt_reduction = payout
					result.type = "debt_win"
					if enable_debug_mode:
						print("Money win: $", payout)
				"Coins":
					result.coins_won = payout
					result.type = "coin_win"
					if enable_debug_mode:
						print("Coin win: ", payout, " coins")

	if enable_debug_mode:
		print("Final result type: ", result.type)
		print("========================")

	return result

func create_reel_stop_shake():
	if not config.enable_screen_shake:
		return

	var shake_tween = create_tween()
	var original_position = position
	var intensity = 2.0

	for i in range(3):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(self, "position", original_position + offset, 0.05)

	shake_tween.tween_property(self, "position", original_position, 0.05)

func create_win_shake(result: Dictionary):
	if not config.enable_screen_shake:
		return

	var intensity = config.shake_small_win

	match result.type:
		"jackpot":
			intensity = config.shake_jackpot
		"debt_win":
			intensity = config.shake_big_win if result.debt_reduction > 20000 else config.shake_medium_win
		"coin_win":
			intensity = config.shake_medium_win if result.coins_won > 30 else config.shake_small_win

	var shake_tween = create_tween()
	var original_position = position

	for i in range(config.shake_frequency):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(self, "position", original_position + offset, config.shake_duration / config.shake_frequency)

	shake_tween.tween_property(self, "position", original_position, 0.1)

func play_result_audio(result: Dictionary):
	if not audio_manager:
		return

	match result.type:
		"jackpot", "coin_win", "debt_win":
			audio_manager.play_win_sound()
		_:
			audio_manager.play_lose_sound()

func trigger_evil_laugh():
	await get_tree().create_timer(2.0).timeout

	if audio_manager:
		audio_manager.play_evil_laugh()

	if config.enable_screen_shake:
		create_win_shake({"type": "jackpot"})

	if ui_manager:
		ui_manager.show_evil_message()

	evil_laugh_triggered.emit()

	await get_tree().create_timer(4.0).timeout
	transition_to_pacman()

func transition_to_pacman():
	var pacman_scene_path = "res://Scenes/PacmanScene.tscn"
	if ResourceLoader.exists(pacman_scene_path):
		get_tree().change_scene_to_file(pacman_scene_path)
	else:
		push_error("Pacman scene not found at: " + pacman_scene_path)

func _on_upgrade_requested():
	if ui_manager:
		ui_manager.show_upgrade_shop()

func _on_coins_changed(_new_amount: int):
	update_ui()

func _on_debt_changed(_new_amount: int):
	update_ui()
	if GameManager.is_game_won() and ui_manager:
		ui_manager.show_victory_screen()

func _on_evil_laugh_trigger():
	trigger_evil_laugh()

func update_ui():
	if ui_manager:
		ui_manager.update_display()

func get_spin_cost() -> int:
	return config.spin_cost if config else 5

func get_current_coins() -> int:
	return GameManager.current_coins

func get_current_debt() -> int:
	return GameManager.total_debt

func is_tutorial_mode() -> bool:
	return GameManager.is_tutorial_mode

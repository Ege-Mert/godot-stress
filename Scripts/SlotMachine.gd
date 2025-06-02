extends Control
class_name SlotMachineController

@export_group("Configuration")
@export var config: SlotMachineConfig
@export var enable_debug_mode: bool = false

@export_group("Enhanced Luck System")
@export var use_enhanced_luck: bool = true  ## Use new enhanced luck system
@export var enhanced_luck_system: EnhancedLuckSystem  ## Enhanced luck system instance
@export var show_streak_info: bool = true  ## Show streak information in UI
@export var animate_luck_changes: bool = true  ## Animate luck-based changes

@export_group("Tutorial Settings")
@export var force_first_spin_loss: bool = true
@export var first_spin_symbols: Array[int] = [0, 1, 2]

signal spin_started
signal spin_completed(result: Dictionary)
signal evil_laugh_triggered
signal streak_status_changed(streak_type: String, length: int)
signal luck_modifier_updated(modifier: float)

var ui_manager: SlotMachineUI
var reel_manager: SlotMachineReels
var handle_manager: SlotMachineHandle
var audio_manager: SlotMachineAudio

var is_spinning: bool = false
var current_spin_result: Dictionary

func _ready():
	print("SlotMachine _ready() started")
	# Improved web-safe random seeding
	setup_random_seed()
	print("Random seed setup complete")
	setup_configuration()
	print("Configuration setup complete")
	setup_components()
	print("Components setup complete")
	setup_enhanced_luck_system()
	print("Enhanced luck system setup complete")
	connect_signals()
	print("Signals connected")
	initialize_game()
	print("Game initialized successfully")

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

func setup_enhanced_luck_system():
	if not enhanced_luck_system:
		enhanced_luck_system = EnhancedLuckSystem.new()
		add_child(enhanced_luck_system)
		print("Enhanced Luck System created automatically")
	
	# Connect luck system signals
	enhanced_luck_system.streak_changed.connect(_on_streak_changed)
	enhanced_luck_system.luck_modifier_changed.connect(_on_luck_modifier_changed)
	
	print("Enhanced luck system configured with base win chance: ", enhanced_luck_system.base_win_chance, "%")

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
		ui_manager.pacman_button_pressed.connect(_on_pacman_entry_requested)

	if handle_manager:
		handle_manager.handle_pulled.connect(_on_spin_requested)

	if reel_manager:
		reel_manager.animation_completed.connect(_on_reel_animation_completed)
		reel_manager.reel_stopped.connect(_on_individual_reel_stopped)

func setup_random_seed():
	if OS.has_feature("web"):
		# Use multiple entropy sources for web
		var time_microsec = Time.get_unix_time_from_system() * 1000000
		var slot_hash = str(self).hash()
		var combined_seed = int(time_microsec + slot_hash) % 2147483647
		seed(combined_seed)
		print("Web SlotMachine seed set to: ", combined_seed)
	else:
		randomize()
		print("Desktop SlotMachine randomize() called")

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
	
	# Apply results to GameManager
	if current_spin_result.coins_won > 0:
		GameManager.current_coins += current_spin_result.coins_won
		GameManager.coins_changed.emit(GameManager.current_coins)

	if current_spin_result.debt_reduction > 0:
		GameManager.total_debt -= current_spin_result.debt_reduction
		GameManager.debt_changed.emit(GameManager.total_debt)
	
	# Always update spin counter for coin respawn system
	GameManager.spins_since_coin_reset += 1
	var spins_left = GameManager.get_spins_until_coin_respawn()
	GameManager.coin_respawn_counter_changed.emit(spins_left)
	
	# Check for coin reset
	if GameManager.should_reset_coins():
		GameManager.perform_coin_reset()

	print("DEBUG: Calculated result: ", current_spin_result)

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

# NEW: Manipulate reel outcomes to match the GameManager's predetermined result
func manipulate_reel_outcome_to_match(original_symbols: Array[int], gm_result: Dictionary) -> Array[int]:
	var manipulated_symbols = original_symbols.duplicate()
	
	# Force the visual outcome to match the GameManager's decision
	if gm_result.type == "loss":
		# Ensure no winning combinations appear
		manipulated_symbols = create_losing_combination()
		print("MANIPULATION: Forced losing combination")
	elif gm_result.type == "jackpot":
		# Show jackpot symbols (3 of the highest value)
		if config.symbols.size() > 0:
			var jackpot_symbol = 0  # Assuming first symbol is jackpot
			manipulated_symbols = [jackpot_symbol, jackpot_symbol, jackpot_symbol]
			print("MANIPULATION: Forced jackpot combination")
	else:
		# For regular wins, create appropriate symbol combination
		manipulated_symbols = create_winning_combination(gm_result)
		print("MANIPULATION: Forced winning combination for ", gm_result.type)
	
	# Occasionally create "near miss" for psychological effect
	if gm_result.type == "loss" and randf() * 100.0 < config.near_miss_frequency:
		manipulated_symbols = create_near_miss_combination()
		print("MANIPULATION: Created near miss for psychological effect")
	
	return manipulated_symbols

func create_losing_combination() -> Array[int]:
	# Ensure no two symbols match
	var symbols: Array[int] = []
	var available_symbols = range(config.symbols.size())
	
	# Pick 3 different symbols to guarantee no match
	for i in range(3):
		if available_symbols.size() > 0:
			var random_index = randi() % available_symbols.size()
			symbols.append(available_symbols[random_index])
			available_symbols.remove_at(random_index)
		else:
			# Fallback if not enough different symbols
			symbols.append(i % config.symbols.size())
	
	return symbols

func create_winning_combination(gm_result: Dictionary) -> Array[int]:
	# Create a simple 2-match combination for wins
	var winning_symbol = randi() % config.symbols.size()
	var different_symbol = (winning_symbol + 1) % config.symbols.size()
	
	# For most wins, just give 2 matching symbols
	return [winning_symbol, winning_symbol, different_symbol]

func create_near_miss_combination() -> Array[int]:
	# Create a combination that almost wins (2 matching + 1 close)
	var almost_winning_symbol = randi() % config.symbols.size()
	var close_symbol = (almost_winning_symbol + 1) % config.symbols.size()
	
	return [almost_winning_symbol, almost_winning_symbol, close_symbol]

# Helper function to calculate visual properties for manipulated results
func update_visual_result_properties(result: Dictionary):
	var symbols = result.symbols
	
	# Count exact matches for visual effects
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
	
	# Update result properties
	result.match_count = max_count
	result.winning_symbol = winning_symbol
	result.winning_positions = winning_positions

func calculate_result_from_symbols(symbols: Array[int]) -> Dictionary:
	var result = {
		"symbols": symbols,
		"coins_won": 0,
		"debt_reduction": 0,
		"type": "loss",
		"match_count": 0,
		"winning_symbol": -1,
		"winning_positions": [],
		"streak_info": {},
		"is_enhanced_luck": use_enhanced_luck
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

	# Add streak information if using enhanced luck
	if use_enhanced_luck and enhanced_luck_system:
		result.streak_info = enhanced_luck_system.get_current_streak_info()

	if enable_debug_mode:
		print("Match count: ", max_count)
		if max_count >= 2:
			var symbol_data = config.get_symbol_by_index(winning_symbol)
			if symbol_data:
				print("Winning symbol: ", symbol_data.symbol_name)
				print("Winning positions: ", winning_positions)

	# Award payouts for 2+ matches - FIXED TO USE PROPER SYMBOL PAYOUTS
	if max_count >= 2:
		var symbol_data = config.get_symbol_by_index(winning_symbol)
		if symbol_data:
			# Calculate base payout from symbol data (not GameManager harsh values)
			var base_payout = symbol_data.base_payout_amount
			var match_multiplier = 1.0 if max_count == 2 else 2.0  # 2x bonus for 3 of a kind
			
			# Apply enhanced luck streak multiplier if enabled
			var streak_multiplier = 1.0
			if use_enhanced_luck and enhanced_luck_system:
				streak_multiplier = enhanced_luck_system.get_streak_multiplier()
				enhanced_luck_system.track_spin_result(true)  # Track this as a win
			
			# Apply upgrade multipliers
			var upgrade_multiplier = 1.0
			if GameManager:
				upgrade_multiplier += GameManager.slot_upgrades.payout_boost * GameManager.upgrade_payout_boost
			
			var final_payout = int(base_payout * match_multiplier * streak_multiplier * upgrade_multiplier)
			
			match symbol_data.payout_type:
				"Jackpot":
					if max_count == 3:
						# Use GameManager's jackpot setting for total debt clear
						if GameManager and GameManager.jackpot_clears_all_debt:
							result.debt_reduction = GameManager.total_debt
						else:
							result.debt_reduction = final_payout
						result.type = "jackpot"
						if enable_debug_mode:
							print("JACKPOT! Debt reduction: ", result.debt_reduction)
				"Money":
					# Use calculated payout, not harsh GameManager values
					result.debt_reduction = final_payout
					result.type = "debt_win"
					if enable_debug_mode:
						print("Money win: $", result.debt_reduction, " (base: ", base_payout, ", multipliers: ", match_multiplier * streak_multiplier * upgrade_multiplier, ")")
				"Coins":
					# Use calculated payout, not harsh GameManager values
					result.coins_won = final_payout
					result.type = "coin_win"
					if enable_debug_mode:
						print("Coin win: ", result.coins_won, " coins (base: ", base_payout, ", multipliers: ", match_multiplier * streak_multiplier * upgrade_multiplier, ")")
	else:
		# No win - track as loss in enhanced luck system
		if use_enhanced_luck and enhanced_luck_system:
			enhanced_luck_system.track_spin_result(false)
			
			# Check for near miss creation
			if enhanced_luck_system.should_create_near_miss():
				result.type = "near_miss"
				if enable_debug_mode:
					print("Near miss created for psychological effect")

	if enable_debug_mode:
		print("Final result type: ", result.type)
		if use_enhanced_luck:
			print("Streak info: ", result.streak_info)
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
	# Use deferred call to avoid tilemap loading issues
	call_deferred("_safe_transition_to_pacman")

func _safe_transition_to_pacman():
	var pacman_scene_path = "res://Scenes/PacmanScene.tscn"
	if ResourceLoader.exists(pacman_scene_path):
		# Add small delay to ensure current frame is complete
		await get_tree().process_frame
		# Use a more robust scene change method
		var result = get_tree().change_scene_to_file(pacman_scene_path)
		if result != OK:
			push_error("Failed to load Pacman scene: " + str(result))
	else:
		push_error("Pacman scene not found at: " + pacman_scene_path)
		# Try alternative scene name
		var alt_path = "res://Scenes/PacmanSceneRefactored.tscn"
		if ResourceLoader.exists(alt_path):
			print("Trying alternative scene: ", alt_path)
			await get_tree().process_frame
			get_tree().change_scene_to_file(alt_path)
		else:
			print("No Pacman scene found! Available scenes:")
			# List available scenes for debugging
			var dir = DirAccess.open("res://Scenes/")
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if file_name.ends_with(".tscn"):
						print("  ", file_name)
					file_name = dir.get_next()

func _on_upgrade_requested():
	if ui_manager:
		ui_manager.show_upgrade_shop()

func _on_pacman_entry_requested():
	# Use enhanced entry check from GameManager
	var entry_status = GameManager.get_pacman_entry_status()
	if entry_status.can_enter:
		transition_to_pacman()
	else:
		if ui_manager:
			ui_manager.show_message(entry_status.reason)

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

# NEW: Enhanced luck system signal handlers
func _on_streak_changed(streak_type: String, length: int):
	print("Streak changed: ", streak_type, " (length: ", length, ")")
	streak_status_changed.emit(streak_type, length)
	
	# Update UI if available
	if ui_manager and show_streak_info:
		# You can add UI updates here when you implement streak display
		pass
	
	# Optional: Create visual effects for streak changes
	if animate_luck_changes:
		_animate_streak_change(streak_type)

func _on_luck_modifier_changed(modifier: float):
	print("Luck modifier changed: ", modifier)
	luck_modifier_updated.emit(modifier)
	
	# Update UI to show luck changes
	if ui_manager and show_streak_info:
		# You can add UI updates here
		pass

func _animate_streak_change(streak_type: String):
	if not animate_luck_changes:
		return
	
	# Create visual feedback for streak changes
	match streak_type:
		"hot":
			# Golden glow effect
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color.GOLD, 0.5)
			tween.tween_property(self, "modulate", Color.WHITE, 0.5)
		"cold":
			# Blue tint effect
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color.CYAN, 0.5)
			tween.tween_property(self, "modulate", Color.WHITE, 0.5)
		"mercy":
			# Bright flash effect
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color.WHITE * 2.0, 0.2)
			tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func get_enhanced_luck_info() -> Dictionary:
	if not enhanced_luck_system:
		return {}
	return enhanced_luck_system.get_current_streak_info()

func reset_enhanced_luck():
	if enhanced_luck_system:
		enhanced_luck_system.reset_luck_system()
		print("Enhanced luck system reset")

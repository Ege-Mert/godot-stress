extends Node

# INSPECTOR CONFIGURABLE WIN CHANCES - BALANCED FOR ENHANCED LUCK SYSTEM
@export_group("Winning Probabilities (%)")
@export_range(0.0, 100.0, 0.001) var jackpot_chance: float = 0.1  ## Chance for massive jackpot (0.1% = 1 in 1,000)
@export_range(0.0, 100.0, 0.01) var base_win_chance: float = 25.0  ## Base chance for ANY win (25% = 1 in 4) - Enhanced luck will modify this
@export_range(0.0, 1.0, 0.01) var coin_win_ratio: float = 0.3  ## Of wins, how many are coin wins vs debt wins
@export_range(0.0, 10.0, 0.01) var upgrade_win_boost: float = 2.0  ## How much each upgrade level increases win chance (%)
@export_range(0.0, 10.0, 0.01) var lucky_spin_chance_per_level: float = 1.0  ## Lucky spin chance per upgrade level (%)

@export_group("Payout Ranges")
@export var min_coin_win: int = 10  ## Minimum coins won (restored from harsh values)
@export var max_coin_win: int = 30  ## Maximum coins won (restored from harsh values)
@export var min_debt_reduction: int = 100  ## Minimum debt reduction (restored from harsh values)
@export var max_debt_reduction: int = 300  ## Maximum debt reduction (restored from harsh values)
@export_range(1.0, 5.0, 0.1) var lucky_multiplier: float = 1.5  ## Multiplier for lucky wins
@export_range(1.0, 5.0, 0.1) var upgrade_payout_boost: float = 0.2  ## Payout boost per upgrade level

@export_group("Jackpot Settings")
@export var jackpot_clears_all_debt: bool = true  ## Whether jackpot clears all debt
@export var jackpot_fixed_amount: int = 1000000  ## Fixed jackpot amount if not clearing all debt

# Game state variables
var current_coins: int = 5
var total_debt: int = 500000  # Start with 500k debt for tutorial
var spin_counter: int = 0
var is_first_spin: bool = true
var is_first_pacman: bool = true
var has_collected_first_10_coins: bool = false
var is_tutorial_mode: bool = true  # Track tutorial state

# Enhanced coin persistence system
var pacman_coin_positions: Array[Vector2] = []
var collected_coin_positions: Array[Vector2] = []
var spins_since_coin_reset: int = 0
@export var spins_needed_for_coin_reset: int = 8  # Configurable from inspector

# NEW: Track available coins count when player exits Pacman
var coins_available_on_last_exit: int = 0
var minimum_coins_for_entry: int = 5
var pacman_entry_blocked: bool = false

# Game state tracking
var game_session_started: bool = false
var first_spin_completed: bool = false

# Upgrade levels
var slot_upgrades = {
	"win_frequency": 0,    # Increased chance to win
	"payout_boost": 0,    # Higher payouts
	"lucky_spin": 0       # Chance for bonus features
}

var pacman_upgrades = {
	"movement_speed": 0,
	"coin_radar": 0,      # Shows coin locations
	"ghost_slowdown": 0   # Slows down ghosts
}

# Pacman stage variables
var pacman_coins_collected: int = 0
var pacman_minimum_coins: int = 5
var pacman_exit_unlocked: bool = false

# Audio references (to be set by scenes)
var audio_manager: AudioStreamPlayer

# Signals for communication between scenes
signal coins_changed(new_amount: int)
signal debt_changed(new_amount: int)
signal spin_completed(result: Dictionary)
signal pacman_exit_available()
signal evil_laugh_trigger()
signal coin_reset_triggered()
signal coin_respawn_counter_changed(spins_left: int)  # NEW: For UI updates
signal pacman_entry_status_changed(can_enter: bool, reason: String)  # NEW: For UI feedback

func _ready():
	# Improved web-safe random seeding
	setup_random_seed()
	
	# Set up autoload persistence
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Only set first spin on true first load, not on scene reloads
	if not game_session_started:
		# First time launching the game
		game_session_started = true
		is_first_spin = true
		first_spin_completed = false
		print("Game session started - first spin will have tutorial override")
	else:
		# Scene reloaded or revisited
		print("Scene reloaded - maintaining previous game state")
	
	# Debug current state
	print("DEBUG GameManager state:")
	print("  is_first_spin: ", is_first_spin)
	print("  first_spin_completed: ", first_spin_completed)
	print("  game_session_started: ", game_session_started)
	print("  coins_available_on_last_exit: ", coins_available_on_last_exit)
	print("  pacman_entry_blocked: ", pacman_entry_blocked)

func setup_random_seed():
	if OS.has_feature("web"):
		# Use multiple entropy sources for web
		var time_microsec = Time.get_unix_time_from_system() * 1000000
		var manager_hash = str(self).hash()
		var combined_seed = int(time_microsec + manager_hash) % 2147483647
		seed(combined_seed)
		print("Web GameManager seed set to: ", combined_seed)
	else:
		randomize()
		print("Desktop GameManager randomize() called")

# NEW: Enhanced Pacman entry check
func can_enter_pacman() -> Dictionary:
	var result = {
		"can_enter": false,
		"reason": ""
	}
	
	# Must have at least 1 coin
	if current_coins < 1:
		result.reason = "Need at least 1 coin to enter maze"
		return result
	
	# During tutorial, standard rules apply
	if is_tutorial_mode:
		result.can_enter = true
		result.reason = "Tutorial mode - entry allowed"
		return result
	
	# If entry is blocked due to insufficient coins on last exit
	if pacman_entry_blocked:
		var spins_left = spins_needed_for_coin_reset - spins_since_coin_reset
		result.reason = "Insufficient coins in maze. Wait " + str(spins_left) + " more spins for coin respawn"
		return result
	
	# Otherwise, entry is allowed
	result.can_enter = true
	result.reason = "Entry allowed"
	return result

# NEW: Enhanced Pacman exit tracking
func exit_pacman_stage_enhanced(coins_in_maze_when_exited: int) -> int:
	var coins_earned = pacman_coins_collected
	current_coins += coins_earned
	
	# Track how many coins were available when player exited
	coins_available_on_last_exit = coins_in_maze_when_exited
	
	# If fewer than minimum coins were left, block re-entry
	if coins_available_on_last_exit < minimum_coins_for_entry:
		pacman_entry_blocked = true
		print("Pacman entry blocked - only ", coins_available_on_last_exit, " coins left in maze")
		pacman_entry_status_changed.emit(false, "Insufficient coins in maze")
	else:
		pacman_entry_blocked = false
		pacman_entry_status_changed.emit(true, "Entry allowed")
	
	# After first rigged pacman, enable normal gameplay
	if is_first_pacman:
		is_first_pacman = false
	
	coins_changed.emit(current_coins)
	print("Player exited Pacman with ", coins_earned, " coins. ", coins_available_on_last_exit, " coins left in maze.")
	return coins_earned

# NEW: Count available coins in current Pacman state
func count_available_coins_in_pacman() -> int:
	var available = 0
	for pos in pacman_coin_positions:
		if not is_coin_collected(pos):
			available += 1
	return available
	
# Slot machine functions
func can_spin() -> bool:
	var spin_cost = get_spin_cost()
	return current_coins >= spin_cost

func get_spin_cost() -> int:
	var base_cost = 5
	return base_cost  # No more cost reduction upgrade

func deduct_spin_cost() -> bool:
	var spin_cost = get_spin_cost()
	if current_coins >= spin_cost:
		current_coins -= spin_cost
		coins_changed.emit(current_coins)
		return true
	return false

func perform_spin() -> Dictionary:
	var spin_cost = get_spin_cost()
	if not can_spin():
		return {"success": false, "reason": "insufficient_coins"}
	
	current_coins -= spin_cost
	spin_counter += 1
	spins_since_coin_reset += 1  # Track spins for coin reset
	
	# Emit counter change for UI
	var spins_left = spins_needed_for_coin_reset - spins_since_coin_reset
	coin_respawn_counter_changed.emit(max(0, spins_left))
	
	var result = calculate_spin_result()
	
	# Apply results
	if result.coins_won > 0:
		current_coins += result.coins_won
	
	if result.debt_reduction > 0:
		total_debt -= result.debt_reduction
	
	# Check for coin reset
	if should_reset_coins():
		result.coin_reset = true
		perform_coin_reset()
	
	# Emit signals
	coins_changed.emit(current_coins)
	debt_changed.emit(total_debt)
	spin_completed.emit(result)
	
	# Check if player is broke (with delay to let result show)
	if not can_spin():
		call_deferred("_trigger_evil_laugh_delayed")
	
	return result

func _trigger_evil_laugh_delayed():
	# Wait a bit to let the spin result be visible
	await get_tree().create_timer(2.0).timeout
	evil_laugh_trigger.emit()

# NEW: Calculate spin result without applying effects (for visual manipulation)
func calculate_spin_result_only() -> Dictionary:
	var result = {
		"coins_won": 0,
		"debt_reduction": 0,
		"type": "loss",
		"coin_reset": false,
		"symbols": [],
		"match_count": 0,
		"winning_symbol": -1,
		"winning_positions": []
	}
	
	# Special first spin logic - should fail to trigger pacman
	if is_first_spin and not first_spin_completed:
		result.type = "loss"
		return result
	
	# NEW ULTRA-LOW WIN CHANCE SYSTEM
	# Convert percentages to 0-1 range
	var jackpot_probability = jackpot_chance / 100.0
	var total_win_probability = (base_win_chance + (slot_upgrades.win_frequency * upgrade_win_boost)) / 100.0
	
	# Cap maximum win chance to prevent it getting too high
	total_win_probability = min(total_win_probability, 0.15)  # Max 15% even with all upgrades
	
	var spin_chance = randf()
	
	# Lucky spin calculation with much lower chances
	var lucky_probability = (slot_upgrades.lucky_spin * lucky_spin_chance_per_level) / 100.0
	var is_lucky_spin = randf() < lucky_probability
	
	# Debug output (can be removed in final version)
	print("SPIN DEBUG: Chance rolled: ", spin_chance, " | Jackpot threshold: ", jackpot_probability, " | Win threshold: ", total_win_probability)
	
	# Check for jackpot first (extremely rare)
	if spin_chance < jackpot_probability:
		if jackpot_clears_all_debt:
			result.debt_reduction = total_debt  # Clear all debt
		else:
			result.debt_reduction = jackpot_fixed_amount
		result.type = "jackpot"
		print("JACKPOT HIT! Probability was ", jackpot_probability * 100, "%")
		return result
	
	# Check for regular wins (still very rare)
	if spin_chance < total_win_probability:
		# Determine win type based on coin_win_ratio
		var win_type_roll = randf()
		
		if win_type_roll < coin_win_ratio:
			# Coin win - much smaller amounts
			var base_coins = randi_range(min_coin_win, max_coin_win)
			var multiplier = 1.0 + (slot_upgrades.payout_boost * upgrade_payout_boost)
			
			if is_lucky_spin:
				multiplier *= lucky_multiplier
				result.type = "lucky_coin_win"
			else:
				result.type = "coin_win"
			
			result.coins_won = max(1, int(base_coins * multiplier))  # Ensure at least 1 coin
			print("Coin win: ", result.coins_won, " coins (lucky: ", is_lucky_spin, ")")
		else:
			# Debt reduction win - much smaller amounts
			var base_reduction = randi_range(min_debt_reduction, max_debt_reduction)
			var multiplier = 1.0 + (slot_upgrades.payout_boost * upgrade_payout_boost)
			
			if is_lucky_spin:
				multiplier *= lucky_multiplier
				result.type = "lucky_debt_win"
			else:
				result.type = "debt_win"
			
			result.debt_reduction = max(1, int(base_reduction * multiplier))  # Ensure at least 1
			print("Debt win: $", result.debt_reduction, " reduction (lucky: ", is_lucky_spin, ")")
	else:
		# Loss - this should be the vast majority of spins
		result.type = "loss"
		print("Loss - no payout")
	
	return result

func calculate_spin_result() -> Dictionary:
	var result = {
		"coins_won": 0,
		"debt_reduction": 0,
		"type": "loss",
		"coin_reset": false
	}
	
	# Special first spin logic - should fail to trigger pacman
	if is_first_spin and not first_spin_completed:
		is_first_spin = false
		first_spin_completed = true
		print("First spin ever - forcing loss to trigger pacman")
		result.type = "loss"
		return result
	
	# NEW ULTRA-LOW WIN CHANCE SYSTEM
	# Convert percentages to 0-1 range
	var jackpot_probability = jackpot_chance / 100.0
	var total_win_probability = (base_win_chance + (slot_upgrades.win_frequency * upgrade_win_boost)) / 100.0
	
	# Cap maximum win chance to prevent it getting too high
	total_win_probability = min(total_win_probability, 0.15)  # Max 15% even with all upgrades
	
	var spin_chance = randf()
	
	# Lucky spin calculation with much lower chances
	var lucky_probability = (slot_upgrades.lucky_spin * lucky_spin_chance_per_level) / 100.0
	var is_lucky_spin = randf() < lucky_probability
	
	# Debug output (can be removed in final version)
	print("SPIN DEBUG: Chance rolled: ", spin_chance, " | Jackpot threshold: ", jackpot_probability, " | Win threshold: ", total_win_probability)
	
	# Check for jackpot first (extremely rare)
	if spin_chance < jackpot_probability:
		if jackpot_clears_all_debt:
			result.debt_reduction = total_debt  # Clear all debt
		else:
			result.debt_reduction = jackpot_fixed_amount
		result.type = "jackpot"
		print("JACKPOT HIT! Probability was ", jackpot_probability * 100, "%")
		return result
	
	# Check for regular wins (still very rare)
	if spin_chance < total_win_probability:
		# Determine win type based on coin_win_ratio
		var win_type_roll = randf()
		
		if win_type_roll < coin_win_ratio:
			# Coin win - much smaller amounts
			var base_coins = randi_range(min_coin_win, max_coin_win)
			var multiplier = 1.0 + (slot_upgrades.payout_boost * upgrade_payout_boost)
			
			if is_lucky_spin:
				multiplier *= lucky_multiplier
				result.type = "lucky_coin_win"
			else:
				result.type = "coin_win"
			
			result.coins_won = max(1, int(base_coins * multiplier))  # Ensure at least 1 coin
			print("Coin win: ", result.coins_won, " coins (lucky: ", is_lucky_spin, ")")
		else:
			# Debt reduction win - much smaller amounts
			var base_reduction = randi_range(min_debt_reduction, max_debt_reduction)
			var multiplier = 1.0 + (slot_upgrades.payout_boost * upgrade_payout_boost)
			
			if is_lucky_spin:
				multiplier *= lucky_multiplier
				result.type = "lucky_debt_win"
			else:
				result.type = "debt_win"
			
			result.debt_reduction = max(1, int(base_reduction * multiplier))  # Ensure at least 1
			print("Debt win: $", result.debt_reduction, " reduction (lucky: ", is_lucky_spin, ")")
	else:
		# Loss - this should be the vast majority of spins
		result.type = "loss"
		print("Loss - no payout")
	
	return result

# Pacman stage functions
func start_pacman_stage():
	pacman_coins_collected = 0
	pacman_exit_unlocked = false

func collect_pacman_coin():
	pacman_coins_collected += 1
	
	# Check for first pacman special condition
	if is_first_pacman and pacman_coins_collected >= 10 and not has_collected_first_10_coins:
		has_collected_first_10_coins = true
		# This will trigger the wall-phasing ghost
		return true
	
	# Check if minimum coins reached
	if pacman_coins_collected >= pacman_minimum_coins:
		pacman_exit_unlocked = true
		pacman_exit_available.emit()
	
	return false

func exit_pacman_stage() -> int:
	var coins_earned = pacman_coins_collected
	# Use enhanced exit tracking
	var available_coins = count_available_coins_in_pacman()
	return exit_pacman_stage_enhanced(available_coins)

func trigger_debt_trap():
	# Tutorial debt trap mechanic - add 500k more debt
	if is_first_pacman and is_tutorial_mode:
		total_debt += 500000  # Add 500k (now total 1M)
		is_tutorial_mode = false  # End tutorial mode
		debt_changed.emit(total_debt)
		print("Tutorial debt trap triggered: debt is now ", total_debt)

# Coin reset system functions
func should_reset_coins() -> bool:
	return spins_since_coin_reset >= spins_needed_for_coin_reset

func perform_coin_reset():
	collected_coin_positions.clear()
	spins_since_coin_reset = 0
	
	# NEW: Unblock Pacman entry when coins respawn
	if pacman_entry_blocked:
		pacman_entry_blocked = false
		pacman_entry_status_changed.emit(true, "Coins respawned - entry allowed")
		print("Coin respawn unblocked Pacman entry")
	
	coin_reset_triggered.emit()
	coin_respawn_counter_changed.emit(spins_needed_for_coin_reset)  # Reset counter
	print("Coins reset! All collected coins will respawn.")

# NEW: Get spins remaining until coin respawn
func get_spins_until_coin_respawn() -> int:
	return max(0, spins_needed_for_coin_reset - spins_since_coin_reset)

# NEW: Get detailed Pacman entry status for UI
func get_pacman_entry_status() -> Dictionary:
	return can_enter_pacman()

# Coin tracking functions
func register_coin_position(pos: Vector2):
	if pos not in pacman_coin_positions:
		pacman_coin_positions.append(pos)

func collect_coin_at_position(pos: Vector2):
	if pos not in collected_coin_positions:
		collected_coin_positions.append(pos)

func is_coin_collected(pos: Vector2) -> bool:
	return pos in collected_coin_positions

func get_available_coin_positions() -> Array[Vector2]:
	var available = []
	for pos in pacman_coin_positions:
		if not is_coin_collected(pos):
			available.append(pos)
	return available

# Upgrade functions
func can_afford_upgrade(upgrade_type: String, upgrade_category: String) -> bool:
	var cost = get_upgrade_cost(upgrade_type, upgrade_category)
	return current_coins >= cost

func get_upgrade_cost(upgrade_type: String, upgrade_category: String) -> int:
	var base_costs = {
		"win_frequency": 60,
		"payout_boost": 120,
		"lucky_spin": 200,
		"movement_speed": 40,
		"coin_radar": 80,
		"ghost_slowdown": 150
	}
	
	var current_level = 0
	if upgrade_category == "slot":
		current_level = slot_upgrades.get(upgrade_type, 0)
	else:
		current_level = pacman_upgrades.get(upgrade_type, 0)
	
	var base_cost = base_costs.get(upgrade_type, 50)
	return base_cost + (current_level * base_cost / 2)  # Increasing cost per level

func purchase_upgrade(upgrade_type: String, upgrade_category: String) -> bool:
	if not can_afford_upgrade(upgrade_type, upgrade_category):
		return false
	
	var cost = get_upgrade_cost(upgrade_type, upgrade_category)
	current_coins -= cost
	
	if upgrade_category == "slot":
		slot_upgrades[upgrade_type] += 1
	else:
		pacman_upgrades[upgrade_type] += 1
	
	coins_changed.emit(current_coins)
	return true

# Utility functions
func get_pacman_difficulty_multiplier() -> float:
	# Difficulty increases with upgrades
	var total_upgrades = 0
	for value in slot_upgrades.values():
		total_upgrades += value
	for value in pacman_upgrades.values():
		total_upgrades += value
	
	return 1.0 + (total_upgrades * 0.2)

# Check win condition
func is_game_won() -> bool:
	return total_debt <= 0

func reset_game():
	current_coins = 5
	total_debt = 500000  # Reset to tutorial debt
	spin_counter = 0
	is_first_spin = true
	is_first_pacman = true
	has_collected_first_10_coins = false
	is_tutorial_mode = true  # Reset tutorial mode
	
	# NEW: Reset coin system state
	coins_available_on_last_exit = 0
	pacman_entry_blocked = false
	spins_since_coin_reset = 0
	
	# Reset upgrades
	slot_upgrades = {
		"win_frequency": 0,
		"payout_boost": 0,
		"lucky_spin": 0
	}
	pacman_upgrades = {
		"movement_speed": 0,
		"coin_radar": 0,
		"ghost_slowdown": 0
	}

# Safe scene change method for use as fallback
func _safe_scene_change(scene_path: String):
	if get_tree():
		get_tree().change_scene_to_file(scene_path)
	else:
		print("ERROR: Cannot change scene - no tree available")

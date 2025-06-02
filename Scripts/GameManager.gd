extends Node

# Game state variables
var current_coins: int = 5
var total_debt: int = 500000  # Start with 500k debt for tutorial
var spin_counter: int = 0
var is_first_spin: bool = true
var is_first_pacman: bool = true
var has_collected_first_10_coins: bool = false
var is_tutorial_mode: bool = true  # Track tutorial state

# Game state tracking
var game_session_started: bool = false
var first_spin_completed: bool = false

# Upgrade levels
var slot_upgrades = {
	"better_odds": 0,
	"coin_multiplier": 0,
	"reduced_cost": 0
}

var pacman_upgrades = {
	"movement_speed": 0,
	"invincibility": 0,
	"coin_magnetism": 0
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

func _ready():
	# Web-safe random seeding
	if OS.has_feature("web"):
		randomize()  # Uses time-based seed on web
	else:
		seed(OS.get_process_id() + Time.get_unix_time_from_system())
	
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

# Check these variables in GameManager
	print("DEBUG GameManager state:")
	print("  is_first_spin: ", GameManager.is_first_spin)
	print("  first_spin_completed: ", GameManager.first_spin_completed)
	
# Slot machine functions
func can_spin() -> bool:
	var spin_cost = get_spin_cost()
	return current_coins >= spin_cost

func get_spin_cost() -> int:
	var base_cost = 5
	var reduction = slot_upgrades.reduced_cost
	return max(1, base_cost - reduction)

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
	
	var result = calculate_spin_result()
	
	# Apply results
	if result.coins_won > 0:
		current_coins += result.coins_won
	
	if result.debt_reduction > 0:
		total_debt -= result.debt_reduction
	
	# Check for coin reset (every 10 spins)
	if spin_counter % 10 == 0:
		result.coin_reset = true
	
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
	
	# Normal spin probabilities (affected by upgrades)
	var base_win_chance = 0.3 + (slot_upgrades.better_odds * 0.1)
	var spin_chance = randf()
	
	if spin_chance < 0.0001:  # 0.01% chance for jackpot
		result.debt_reduction = 1000000
		result.type = "jackpot"
	elif spin_chance < base_win_chance * 0.6:  # Coin wins
		var base_coins = randi_range(10, 30)
		var multiplier = 1.0 + (slot_upgrades.coin_multiplier * 0.5)
		result.coins_won = int(base_coins * multiplier)
		result.type = "coin_win"
	elif spin_chance < base_win_chance:  # Debt reduction wins
		var base_reduction = randi_range(50, 200)
		var multiplier = 1.0 + (slot_upgrades.coin_multiplier * 0.3)
		result.debt_reduction = int(base_reduction * multiplier)
		result.type = "debt_win"
	
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
	current_coins += coins_earned
	
	# After first rigged pacman, enable normal gameplay
	if is_first_pacman:
		is_first_pacman = false
	
	coins_changed.emit(current_coins)
	return coins_earned

func trigger_debt_trap():
	# Tutorial debt trap mechanic - add 500k more debt
	if is_first_pacman and is_tutorial_mode:
		total_debt += 500000  # Add 500k (now total 1M)
		is_tutorial_mode = false  # End tutorial mode
		debt_changed.emit(total_debt)
		print("Tutorial debt trap triggered: debt is now ", total_debt)

# Upgrade functions
func can_afford_upgrade(upgrade_type: String, upgrade_category: String) -> bool:
	var cost = get_upgrade_cost(upgrade_type, upgrade_category)
	return current_coins >= cost

func get_upgrade_cost(upgrade_type: String, upgrade_category: String) -> int:
	var base_costs = {
		"better_odds": 50,
		"coin_multiplier": 100,
		"reduced_cost": 75,
		"movement_speed": 40,
		"invincibility": 150,
		"coin_magnetism": 80
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
	
	# Reset upgrades
	for key in slot_upgrades.keys():
		slot_upgrades[key] = 0
	for key in pacman_upgrades.keys():
		pacman_upgrades[key] = 0

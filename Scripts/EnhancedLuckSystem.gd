# Enhanced Slot Machine Luck System
# This system balances authenticity with controlled outcomes

extends Node
class_name EnhancedLuckSystem

# INSPECTOR CONFIGURABLE SETTINGS
@export_group("Luck Mechanics")
@export_range(1.0, 100.0, 1.0) var base_win_chance: float = 25.0  ## Base win percentage (more reasonable)
@export_range(0.001, 1.0, 0.001) var jackpot_chance: float = 0.1   ## Jackpot chance percentage
@export_range(0.0, 50.0, 1.0) var hot_streak_bonus: float = 5.0   ## Bonus chance during hot streaks
@export_range(0.0, 50.0, 1.0) var cold_streak_penalty: float = 10.0 ## Penalty during cold streaks

@export_group("Streak System")
@export var hot_streak_threshold: int = 2   ## Wins before hot streak
@export var cold_streak_threshold: int = 5  ## Losses before cold streak
@export var max_cold_streak: int = 10       ## Maximum losses before mercy win
@export var mercy_win_guaranteed: bool = true ## Force win after max cold streak

@export_group("Symbol Weighting")
@export var use_weighted_symbols: bool = true ## Use symbol weights instead of forcing results
@export var symbol_weights: Array[float] = [1.0, 3.0, 5.0, 8.0, 12.0, 15.0, 20.0] ## Per symbol weight (lower = rarer)

@export_group("Near Miss System")
@export_range(0.0, 50.0, 1.0) var near_miss_chance: float = 15.0 ## Chance for near misses on losses
@export var near_miss_patterns: Array[Array] = [[0,0,1], [1,1,0], [2,2,1]] ## Predefined near miss patterns

# Internal state tracking
var consecutive_losses: int = 0
var consecutive_wins: int = 0
var total_spins: int = 0
var luck_modifier: float = 0.0  # Dynamic luck adjustment
var current_streak_type: String = "normal"  # "hot", "cold", "normal", "mercy"

# Payout scaling based on difficulty
var payout_multipliers = {
	"jackpot": 1.0,
	"big_win": 0.8,
	"medium_win": 0.6,
	"small_win": 0.4
}

signal streak_changed(streak_type: String, length: int)
signal luck_modifier_changed(modifier: float)

func _ready():
	# Initialize with normalized symbol weights if empty
	if symbol_weights.is_empty():
		symbol_weights = [1.0, 3.0, 5.0, 8.0, 12.0, 15.0, 20.0]

# Main function to determine if a spin should win
func should_spin_win() -> bool:
	total_spins += 1
	update_streak_status()
	
	# Calculate current win chance with modifiers
	var current_win_chance = calculate_current_win_chance()
	var roll = randf() * 100.0
	
	print("Enhanced Luck: Win chance = ", current_win_chance, "%, Roll = ", roll)
	
	return roll < current_win_chance

# Calculate win chance with all modifiers
func calculate_current_win_chance() -> float:
	var chance = base_win_chance
	
	# Apply streak modifiers
	match current_streak_type:
		"hot":
			chance += hot_streak_bonus
		"cold":
			chance -= cold_streak_penalty
		"mercy":
			chance = 90.0  # Almost guaranteed win for mercy
	
	# Apply upgrade bonuses (from GameManager)
	if GameManager:
		chance += GameManager.slot_upgrades.win_frequency * GameManager.upgrade_win_boost
	
	# Apply dynamic luck modifier
	chance += luck_modifier
	
	# Cap the chance
	return clamp(chance, 1.0, 95.0)

# Update streak tracking and determine current state
func update_streak_status():
	var old_streak = current_streak_type
	
	if consecutive_losses >= max_cold_streak and mercy_win_guaranteed:
		current_streak_type = "mercy"
	elif consecutive_losses >= cold_streak_threshold:
		current_streak_type = "cold"
	elif consecutive_wins >= hot_streak_threshold:
		current_streak_type = "hot"
	else:
		current_streak_type = "normal"
	
	if old_streak != current_streak_type:
		var length = consecutive_losses if current_streak_type == "cold" else consecutive_wins
		streak_changed.emit(current_streak_type, length)

# Get multiplier based on current streak for payouts
func get_streak_multiplier() -> float:
	match current_streak_type:
		"hot":
			return 1.2  # 20% bonus during hot streaks
		"cold":
			return 0.8  # 20% penalty during cold streaks
		"mercy":
			return 1.5  # 50% bonus for mercy wins
		_:
			return 1.0

# Track results and update internal state
func track_spin_result(won: bool):
	if won:
		consecutive_wins += 1
		consecutive_losses = 0
		luck_modifier = 0.0  # Reset luck modifier on wins
	else:
		consecutive_losses += 1
		consecutive_wins = 0
		
		# Gradually increase luck modifier during long cold streaks
		if consecutive_losses > cold_streak_threshold:
			luck_modifier += 0.5
	
	# Emit signals for UI updates
	luck_modifier_changed.emit(luck_modifier)

# Check if we should create a near miss
func should_create_near_miss() -> bool:
	return randf() * 100.0 < near_miss_chance and consecutive_losses > 2

# Modify symbol strip to influence outcomes naturally
func modify_reel_strip_for_luck(original_strip: SlotMachineSymbolStrip) -> SlotMachineSymbolStrip:
	if not use_weighted_symbols:
		return original_strip
		
	var modified = SlotMachineSymbolStrip.new()
	modified.strip_name = original_strip.strip_name + "_enhanced"
	
	var new_pattern: Array[int] = []
	var pattern_length = 48  # Standard strip length
	
	# Calculate symbol distribution based on win chance and weights
	var win_chance = calculate_current_win_chance()
	var symbol_distribution = calculate_symbol_distribution(win_chance)
	
	# Build new pattern
	for i in range(pattern_length):
		var symbol = select_weighted_symbol(symbol_distribution)
		new_pattern.append(symbol)
	
	modified.strip_pattern = new_pattern
	return modified

# Calculate how many of each symbol should appear
func calculate_symbol_distribution(win_chance: float) -> Array[int]:
	var distribution: Array[int] = []
	var total_symbols = symbol_weights.size()
	
	for i in range(total_symbols):
		# Base frequency from weight (inverse relationship)
		var base_frequency = 48.0 / symbol_weights[i] if symbol_weights[i] > 0 else 1.0
		
		# Modify based on win chance
		if i < 3:  # High value symbols (first 3)
			base_frequency *= (win_chance / 20.0)  # More frequent with higher win chance
		else:  # Low value symbols
			base_frequency *= (2.0 - win_chance / 50.0)  # Less frequent with higher win chance
		
		distribution.append(max(1, int(base_frequency)))
	
	return distribution

# Select a symbol based on weighted distribution
func select_weighted_symbol(distribution: Array[int]) -> int:
	var total_weight = 0
	for count in distribution:
		total_weight += count
	
	var roll = randi() % total_weight
	var current_weight = 0
	
	for i in range(distribution.size()):
		current_weight += distribution[i]
		if roll < current_weight:
			return i
	
	return distribution.size() - 1  # Fallback

# Utility functions for integration
func get_current_streak_info() -> Dictionary:
	return {
		"type": current_streak_type,
		"consecutive_losses": consecutive_losses,
		"consecutive_wins": consecutive_wins,
		"luck_modifier": luck_modifier,
		"total_spins": total_spins
	}

# Reset the luck system
func reset_luck_system():
	consecutive_losses = 0
	consecutive_wins = 0
	total_spins = 0
	luck_modifier = 0.0
	current_streak_type = "normal"
	
# Force a specific streak type (for debugging/testing)
func set_streak_type(streak_type: String, length: int = 0):
	current_streak_type = streak_type
	if streak_type == "cold" or streak_type == "mercy":
		consecutive_losses = max(length, cold_streak_threshold)
		consecutive_wins = 0
	elif streak_type == "hot":
		consecutive_wins = max(length, hot_streak_threshold)
		consecutive_losses = 0
	else:
		consecutive_losses = 0
		consecutive_wins = 0

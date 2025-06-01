extends Resource
class_name SlotMachineConfig

@export_group("Game Balance")
@export var base_win_chance: float = 0.3
@export var jackpot_chance: float = 0.001
@export var spin_cost: int = 5
@export var minimum_bet: int = 1

@export_group("Reel Animation - Phase 1: Rise")
@export var rise_distance: float = 30.0
@export var rise_duration: float = 0.3
@export var rise_ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Reel Animation - Phase 2: Fall")
@export var fall_speed_multiplier: float = 2.0
@export var fall_ease_type: Tween.EaseType = Tween.EASE_IN

@export_group("Reel Animation - Phase 3: Spin")
@export var base_spin_duration: float = 2.0
@export var spin_speed_rps: float = 8.0
@export var deceleration_duration: float = 1.0
@export var deceleration_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("Sequential Stopping")
@export var reel_stop_delay: float = 0.5
@export var final_settle_duration: float = 0.2

@export_group("Screen Shake Effects")
@export var enable_screen_shake: bool = true
@export var shake_small_win: float = 2.0
@export var shake_medium_win: float = 5.0
@export var shake_big_win: float = 8.0
@export var shake_jackpot: float = 12.0
@export var shake_duration: float = 0.5
@export var shake_frequency: int = 8

@export_group("Visual Effects")
@export var show_win_highlights: bool = true
@export var highlight_duration: float = 2.0
@export var result_display_time: float = 3.0
@export var symbol_scale_on_win: float = 1.2

@export_group("Audio Settings")
@export var master_volume: float = 1.0
@export var reel_stop_volume: float = 0.8
@export var win_volume: float = 1.0
@export var jackpot_volume: float = 1.2

@export_group("Symbol Configuration")
@export var symbols: Array[SymbolData] = []

func get_symbol_by_index(index: int) -> SymbolData:
	if index >= 0 and index < symbols.size():
		return symbols[index]
	return null

func get_symbol_count() -> int:
	return symbols.size()

func validate_config() -> bool:
	if symbols.is_empty():
		push_error("SlotMachineConfig: No symbols configured!")
		return false
	
	for i in range(symbols.size()):
		if not symbols[i]:
			push_error("SlotMachineConfig: Symbol at index " + str(i) + " is null!")
			return false
		symbols[i].symbol_index = i
	
	return true

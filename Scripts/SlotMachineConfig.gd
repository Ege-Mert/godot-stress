extends Resource
class_name SlotMachineConfig

@export_group("Game Balance")
@export var spin_cost: int = 5
@export var minimum_bet: int = 1

@export_group("Physics Settings")
@export var initial_velocity_min: float = 15.0
@export var initial_velocity_max: float = 25.0
@export var friction: float = 3.0
@export var stop_threshold: float = 0.1
@export var snap_to_symbol: bool = true
@export var snap_duration: float = 0.2

@export_group("Reel Settings")
@export var symbol_height: float = 120.0  # Increase from 80.0 to 120.0 or higher
@export var visible_symbols_per_reel: int = 1
@export var spin_delay_between_reels: float = 0.15
@export var auto_stop_after: float = 5.0

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

@export_group("Debug Settings")
@export var enable_detailed_logging: bool = false
@export var show_symbol_indices: bool = false
@export var highlight_all_matches: bool = true

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

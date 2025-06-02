extends Resource
class_name SymbolData

@export var symbol_name: String = ""
@export var symbol_texture: Texture2D
@export var symbol_index: int = 0

@export_group("Payout Settings")
@export_enum("Coins", "Money", "Jackpot") var payout_type: String = "Coins"
@export var base_payout_amount: int = 10
@export var two_match_multiplier: float = 1.5
@export var three_match_multiplier: float = 3.0

@export_group("Visual Settings")
@export var highlight_color: Color = Color.YELLOW
@export var win_particle_color: Color = Color.WHITE

func get_payout_for_matches(match_count: int) -> int:
	match match_count:
		2:
			return int(base_payout_amount * two_match_multiplier)
		3:
			return int(base_payout_amount * three_match_multiplier)
		_:
			return 0

func validate_symbol() -> bool:
	# Ensure multipliers are reasonable
	if two_match_multiplier <= 0.0 or three_match_multiplier <= 0.0:
		return false
	if base_payout_amount < 0:
		return false
	return true

func get_payout_description() -> String:
	var desc = symbol_name + ": "
	match payout_type:
		"Jackpot":
			desc += "CLEARS ALL DEBT!"
		"Money":
			desc += "$" + str(base_payout_amount) + " debt reduction"
		"Coins":
			desc += str(base_payout_amount) + " coins"
	
	desc += " (2x: " + str(get_payout_for_matches(2))
	desc += ", 3x: " + str(get_payout_for_matches(3)) + ")"
	return desc

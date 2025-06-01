extends Resource
class_name SlotMachineSymbolStrip

# Represents a physical reel strip with symbols in order
@export var strip_pattern: Array[int] = []
@export var strip_name: String = "Default Strip"

func get_symbol_at_position(position: float) -> int:
	if strip_pattern.is_empty():
		return 0
	
	# Normalize position to strip length
	var normalized_pos = fmod(position, strip_pattern.size())
	if normalized_pos < 0:
		normalized_pos += strip_pattern.size()
	
	return strip_pattern[int(normalized_pos)]

func get_strip_length() -> int:
	return strip_pattern.size()

func get_symbols_in_view(center_position: float, view_count: int = 3) -> Array[int]:
	var symbols: Array[int] = []
	var half_view = view_count / 2
	
	for i in range(-half_view, half_view + 1):
		var pos = center_position + i
		symbols.append(get_symbol_at_position(pos))
	
	return symbols

# Create a default balanced strip
static func create_default_strip() -> SlotMachineSymbolStrip:
	var strip = SlotMachineSymbolStrip.new()
	strip.strip_name = "Default Balanced"
	
	# Symbol distribution (0=Seven, 1=Diamond, 2=Bell, 3=Cherry, 4=Star, 5=Lemon, 6=Orange)
	# Less frequent: Sevens (jackpot)
	# Medium frequent: Diamond, Bell, Cherry (money)
	# Most frequent: Star, Lemon, Orange (coins)
	strip.strip_pattern = [
		6, 5, 4, 3, 5, 6, 4,  # Common symbols
		2, 4, 5, 6, 4, 5,     # Mix with Bell
		1, 5, 4, 6, 5, 4,     # Mix with Diamond
		3, 6, 4, 5, 6, 4,     # Mix with Cherry
		0, 4, 5, 6, 4, 5, 6,  # Seven (rare)
		2, 5, 4, 6, 5, 4,     # More common
		1, 4, 6, 5, 4, 6,     # More mix
		3, 5, 4, 6, 5, 4, 6   # Full pattern = 48 symbols
	]
	
	return strip

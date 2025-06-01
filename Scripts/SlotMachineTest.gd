extends Node

# Quick test script to verify the new slot machine system
# This can be attached to a test scene or run independently

func _ready():
	print("=== Slot Machine Physics Test ===")
	test_symbol_strip()
	test_reel_physics()

func test_symbol_strip():
	print("\n--- Testing Symbol Strip ---")
	var strip = SlotMachineSymbolStrip.create_default_strip()
	print("Strip length: ", strip.get_strip_length())
	print("Symbol at position 0: ", strip.get_symbol_at_position(0))
	print("Symbol at position 5.5: ", strip.get_symbol_at_position(5.5))
	print("Symbol at position -1: ", strip.get_symbol_at_position(-1))
	print("Symbols in view at pos 10: ", strip.get_symbols_in_view(10, 3))

func test_reel_physics():
	print("\n--- Testing Reel Physics ---")
	# Create a test reel
	var reel = SlotMachineReel.new()
	reel.reel_strip = SlotMachineSymbolStrip.create_default_strip()
	reel.initial_velocity_min = 20
	reel.initial_velocity_max = 30
	reel.friction = 3.0
	
	print("Initial position: ", reel.get_reel_position())
	print("Current symbol: ", reel.get_current_symbol())
	
	# Test position setting
	reel.set_reel_position(5.5)
	print("After setting to 5.5: ", reel.get_current_symbol())

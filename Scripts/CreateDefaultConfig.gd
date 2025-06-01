@tool
extends EditorScript

# Run this script in the editor to create default symbol configuration

func _run():
	var config = SlotMachineConfig.new()
	
	# Create Seven - Jackpot
	var seven = SymbolData.new()
	seven.symbol_name = "Seven"
	seven.symbol_index = 0
	seven.payout_type = "Jackpot"
	seven.base_payout_amount = 1000000
	seven.symbol_texture = load("res://Sprites/seven.png")
	
	# Create Diamond - Big Money
	var diamond = SymbolData.new()
	diamond.symbol_name = "Diamond"
	diamond.symbol_index = 1
	diamond.payout_type = "Money"
	diamond.base_payout_amount = 300
	diamond.symbol_texture = load("res://Sprites/diamond.png")
	
	# Create Bell - Medium Money
	var bell = SymbolData.new()
	bell.symbol_name = "Bell"
	bell.symbol_index = 2
	bell.payout_type = "Money"
	bell.base_payout_amount = 150
	bell.symbol_texture = load("res://Sprites/bell.png")
	
	# Create Cherry - Small Money
	var cherry = SymbolData.new()
	cherry.symbol_name = "Cherry"
	cherry.symbol_index = 3
	cherry.payout_type = "Money"
	cherry.base_payout_amount = 75
	cherry.symbol_texture = load("res://Sprites/cherry.png")
	
	# Create Star - Big Coins
	var star = SymbolData.new()
	star.symbol_name = "Star"
	star.symbol_index = 4
	star.payout_type = "Coins"
	star.base_payout_amount = 50
	star.symbol_texture = load("res://Sprites/star.png")
	
	# Create Lemon - Medium Coins
	var lemon = SymbolData.new()
	lemon.symbol_name = "Lemon"
	lemon.symbol_index = 5
	lemon.payout_type = "Coins"
	lemon.base_payout_amount = 25
	lemon.symbol_texture = load("res://Sprites/lemon.png")
	
	# Create Orange - Small Coins
	var orange = SymbolData.new()
	orange.symbol_name = "Orange"
	orange.symbol_index = 6
	orange.payout_type = "Coins"
	orange.base_payout_amount = 10
	orange.symbol_texture = load("res://Sprites/orange.png")
	
	# Add all symbols to config
	config.symbols = [seven, diamond, bell, cherry, star, lemon, orange]
	
	# Save the configuration
	ResourceSaver.save(config, "res://SlotMachineConfig.tres")
	print("Default SlotMachineConfig created and saved!")

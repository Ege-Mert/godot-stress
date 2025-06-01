extends Node
class_name PacmanCoinManager

# Coin collection and management for Pacman game

signal coin_collected(total_coins: int)
signal magnetism_triggered(coins_collected: Array)

@export var coins_needed_for_exit: int = 5
@export var coins_lost_on_death: int = 3

var coin_container: Node
var scene_root: Node2D
var utility: PacmanUtility

var coins_collected: int = 0

func initialize(container: Node, root: Node2D, utilities: PacmanUtility):
	coin_container = container
	scene_root = root
	utility = utilities

func connect_existing_coins():
	# Connect signals for coins that are already placed in the scene
	var all_coins = []
	
	# Get coins from coin_container if it exists
	if coin_container:
		all_coins.append_array(coin_container.get_children())
	
	# Also check direct children of scene (instances placed directly)
	for child in scene_root.get_children():
		if child.name.begins_with("Coin"):
			all_coins.append(child)
	
	print("Found ", all_coins.size(), " coins to connect")
	
	for coin in all_coins:
		if coin.has_signal("picked_up") and not coin.picked_up.is_connected(_on_coin_picked_up):
			coin.picked_up.connect(_on_coin_picked_up)
			print("Connected coin at position: ", coin.position)
		else:
			print("Coin already connected or no signal: ", coin.name)

func check_coin_collection(grid_pos: Vector2):
	# Check if there's a coin at this position
	# Look in coin_container first
	if coin_container:
		for coin in coin_container.get_children():
			var coin_grid_pos = utility.world_to_grid(coin.position)
			if coin_grid_pos == grid_pos and not coin.is_collected:
				coin.collect()
				return
	
	# Also check direct children for coins
	for child in scene_root.get_children():
		if child.name.begins_with("Coin") and not child.is_collected:
			var coin_grid_pos = utility.world_to_grid(child.position)
			if coin_grid_pos == grid_pos:
				child.collect()
				return

func apply_coin_magnetism(player_position: Vector2, magnetism_level: int):
	# Collect coins within magnetism range
	var magnetism_range = magnetism_level  # 1 level = 1 tile radius
	var player_grid = utility.world_to_grid(player_position)
	var collected_coins = []
	
	# Check surrounding tiles for coins
	for x_offset in range(-magnetism_range, magnetism_range + 1):
		for y_offset in range(-magnetism_range, magnetism_range + 1):
			var check_pos = player_grid + Vector2(x_offset, y_offset)
			var coin = get_coin_at_position(check_pos)
			if coin:
				collected_coins.append(coin)
				check_coin_collection(check_pos)
	
	if collected_coins.size() > 0:
		magnetism_triggered.emit(collected_coins)

func get_coin_at_position(grid_pos: Vector2):
	# Check coin_container first
	if coin_container:
		for coin in coin_container.get_children():
			var coin_grid_pos = utility.world_to_grid(coin.position)
			if coin_grid_pos == grid_pos and not coin.is_collected:
				return coin
	
	# Check direct children
	for child in scene_root.get_children():
		if child.name.begins_with("Coin") and not child.is_collected:
			var coin_grid_pos = utility.world_to_grid(child.position)
			if coin_grid_pos == grid_pos:
				return child
	
	return null

func lose_coins_on_death() -> int:
	var coins_lost = min(coins_collected, coins_lost_on_death)
	coins_collected = max(0, coins_collected - coins_lost_on_death)
	return coins_lost

func get_coins_collected() -> int:
	return coins_collected

func is_exit_available() -> bool:
	return coins_collected >= coins_needed_for_exit

func reset_coins():
	coins_collected = 0

func _on_coin_picked_up():
	coins_collected += 1
	
	# Let GameManager handle the coin collection
	var _trigger_phasing_ghost = GameManager.collect_pacman_coin()
	
	coin_collected.emit(coins_collected)

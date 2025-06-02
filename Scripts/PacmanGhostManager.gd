extends Node
class_name PacmanGhostManager

# Ghost spawning and management for Pacman game

signal player_caught_by_normal_ghost
signal player_caught_by_phasing_ghost
signal ghost_spawned(ghost_type: String)

@export var enable_normal_ghosts: bool = true
@export var initial_ghost_count: int = 2
@export var ghost_spawn_positions: Array[Vector2] = [Vector2(8, 6), Vector2(9, 7)]
@export var additional_ghost_spawn_delay: float = 30.0
@export var ghost_spawn_acceleration: float = 2.0
@export var min_ghost_spawn_delay: float = 10.0

@export var enable_wall_phasing_ghost: bool = true
@export var wall_ghost_spawn_position: Vector2 = Vector2(5, 5)

var tilemap_layer: TileMapLayer
var ghost_container: Node2D
var player: CharacterBody2D
var utility: PacmanUtility

# Ghost management
var normal_ghosts: Array = []
var wall_phasing_ghost = null
var wall_phasing_ghost_spawned: bool = false
var ghost_spawn_timer: float = 0.0
var ghost_spawn_interval: float = 30.0

func initialize(tilemap: TileMapLayer, container: Node2D, player_node: CharacterBody2D, utilities: PacmanUtility):
	tilemap_layer = tilemap
	ghost_container = container
	player = player_node
	utility = utilities
	ghost_spawn_interval = additional_ghost_spawn_delay

func spawn_initial_ghosts():
	# Don't spawn normal ghosts in first pacman game
	if GameManager.is_first_pacman:
		return
	
	# Spawn ghosts at configured positions
	var positions_to_use = ghost_spawn_positions.slice(0, initial_ghost_count)
	
	for pos in positions_to_use:
		call_deferred("spawn_normal_ghost", pos)

func spawn_normal_ghost(grid_pos: Vector2):
	var ghost = preload("res://Scenes/Ghost.tscn").instantiate()
	ghost.position = utility.grid_to_world(grid_pos)
	
	# Initialize ghost AI properly - check which method exists
	if ghost.has_method("initialize"):
		ghost.initialize(player, tilemap_layer)
	elif ghost.has_method("setup_normal_ai"):
		# Check if it expects parameters
		if ghost.get_method_list().any(func(method): return method.name == "setup_normal_ai" and method.args.size() == 0):
			ghost.setup_normal_ai()
		else:
			ghost.setup_normal_ai(tilemap_layer)
	
	ghost_container.add_child(ghost)
	normal_ghosts.append(ghost)
	
	# Connect death signal
	if ghost.has_signal("player_caught"):
		ghost.player_caught.connect(_on_normal_ghost_caught_player)
	
	ghost_spawned.emit("normal")

func spawn_wall_phasing_ghost():
	if wall_phasing_ghost_spawned or not enable_wall_phasing_ghost:
		return
	
	print("Spawning wall-phasing ghost...")
	# Use call_deferred to avoid physics query conflicts
	call_deferred("_spawn_wall_phasing_ghost_deferred")

func _spawn_wall_phasing_ghost_deferred():
	wall_phasing_ghost_spawned = true
	wall_phasing_ghost = preload("res://Scenes/WallPhasingGhost.tscn").instantiate()
	wall_phasing_ghost.position = utility.grid_to_world(wall_ghost_spawn_position)
	
	# Initialize ghost properly - check which method exists
	if wall_phasing_ghost.has_method("initialize"):
		wall_phasing_ghost.initialize(player, tilemap_layer)
	elif wall_phasing_ghost.has_method("setup_phasing_ai"):
		wall_phasing_ghost.setup_phasing_ai(player)
	
	ghost_container.add_child(wall_phasing_ghost)
	
	# Connect death signal
	if wall_phasing_ghost.has_signal("player_caught"):
		wall_phasing_ghost.player_caught.connect(_on_phasing_ghost_caught_player)
		print("Connected wall-phasing ghost signal")
	else:
		print("WARNING: Wall-phasing ghost has no player_caught signal!")
	
	ghost_spawned.emit("wall_phasing")

func update_ghost_spawning(delta: float, coins_collected: int, coins_needed_for_exit: int):
	# Add more ghosts over time (stress mechanic)
	if coins_collected > coins_needed_for_exit:  # Only after minimum collection
		ghost_spawn_timer += delta
		if ghost_spawn_timer >= ghost_spawn_interval:
			ghost_spawn_timer = 0.0
			call_deferred("spawn_additional_ghost")

func spawn_additional_ghost():
	# Use configured ghost spawn positions
	if ghost_spawn_positions.size() == 0:
		return
	
	# Find position farthest from player
	var player_grid_pos = utility.world_to_grid(player.position)
	var best_pos = ghost_spawn_positions[0]
	var max_distance = 0.0
	
	for pos in ghost_spawn_positions:
		var distance = pos.distance_to(player_grid_pos)
		if distance > max_distance:
			max_distance = distance
			best_pos = pos
	
	spawn_normal_ghost(best_pos)
	
	# Reduce spawn interval (increasing pressure)
	ghost_spawn_interval = max(min_ghost_spawn_delay, ghost_spawn_interval - ghost_spawn_acceleration)

func should_spawn_phasing_ghost(coins_collected: int, coins_to_trigger: int) -> bool:
	return (GameManager.is_first_pacman and 
			coins_collected >= coins_to_trigger and 
			enable_wall_phasing_ghost and 
			not wall_phasing_ghost_spawned)

func cleanup_ghosts():
	for ghost in normal_ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	normal_ghosts.clear()
	
	if wall_phasing_ghost and is_instance_valid(wall_phasing_ghost):
		wall_phasing_ghost.queue_free()
		wall_phasing_ghost = null
	
	wall_phasing_ghost_spawned = false

func _on_normal_ghost_caught_player():
	player_caught_by_normal_ghost.emit()

func _on_phasing_ghost_caught_player():
	player_caught_by_phasing_ghost.emit()

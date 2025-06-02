extends CharacterBody2D
class_name ImprovedGhostAI

@export var base_speed: float = 100.0
@export var detection_range: float = 200.0
@export var tile_size: int = 32
@export var pathfinding_update_interval: float = 0.5
@export var random_move_chance: float = 0.1

var player_target: Node2D
var tilemap: TileMapLayer
var current_path: Array[Vector2] = []
var path_index: int = 0
var last_pathfind_time: float = 0.0
var current_direction: Vector2 = Vector2.ZERO
var grid_position: Vector2
var target_position: Vector2
var move_timer: float = 0.0
var move_interval: float = 0.3

enum GhostState {
	WANDERING,
	CHASING,
	CORNERING
}

var current_state: GhostState = GhostState.WANDERING

func initialize(player: Node2D, tilemap_layer: TileMapLayer):
	player_target = player
	tilemap = tilemap_layer
	grid_position = world_to_grid(global_position)
	target_position = grid_to_world(grid_position)

func _physics_process(delta):
	update_ai_state()
	move_timer += delta
	
	if move_timer >= move_interval:
		move_timer = 0.0
		decide_next_move()
	
	move_towards_target(delta)

func update_ai_state():
	if not player_target:
		return
	
	var distance_to_player = global_position.distance_to(player_target.global_position)
	
	if distance_to_player <= detection_range:
		current_state = GhostState.CHASING
	else:
		current_state = GhostState.WANDERING

func decide_next_move():
	match current_state:
		GhostState.WANDERING:
			wander_behavior()
		GhostState.CHASING:
			chase_behavior()
		GhostState.CORNERING:
			corner_behavior()

func wander_behavior():
	# Random movement with slight bias towards player
	var possible_directions = get_valid_directions()
	if possible_directions.is_empty():
		return
	
	var chosen_direction: Vector2
	
	if randf() < random_move_chance and player_target:
		# Occasionally move towards player
		var player_grid = world_to_grid(player_target.global_position)
		var direction_to_player = (player_grid - grid_position).normalized()
		chosen_direction = find_closest_valid_direction(direction_to_player, possible_directions)
	else:
		# Random movement
		chosen_direction = possible_directions[randi() % possible_directions.size()]
	
	set_target_grid_position(grid_position + chosen_direction)

func chase_behavior():
	if not player_target:
		return
	
	var player_grid = world_to_grid(player_target.global_position)
	var possible_directions = get_valid_directions()
	
	if possible_directions.is_empty():
		return
	
	# Find best direction towards player
	var best_direction = Vector2.ZERO
	var best_distance = INF
	
	for direction in possible_directions:
		var test_pos = grid_position + direction
		var distance = test_pos.distance_squared_to(player_grid)
		if distance < best_distance:
			best_distance = distance
			best_direction = direction
	
	set_target_grid_position(grid_position + best_direction)

func corner_behavior():
	# Try to predict player movement and cut them off
	if not player_target:
		chase_behavior()
		return
	
	var player_grid = world_to_grid(player_target.global_position)
	# Try to move to where player might go
	var predicted_player_pos = player_grid + Vector2(1, 0)  # Simple prediction
	
	var possible_directions = get_valid_directions()
	if possible_directions.is_empty():
		return
	
	var best_direction = find_closest_valid_direction(
		(predicted_player_pos - grid_position).normalized(), 
		possible_directions
	)
	
	set_target_grid_position(grid_position + best_direction)

func get_valid_directions() -> Array[Vector2]:
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var valid_directions: Array[Vector2] = []
	
	for direction in directions:
		var test_pos = grid_position + direction
		if is_position_walkable(test_pos):
			valid_directions.append(direction)
	
	return valid_directions

func find_closest_valid_direction(target_direction: Vector2, valid_directions: Array[Vector2]) -> Vector2:
	if valid_directions.is_empty():
		return Vector2.ZERO
	
	var best_direction = valid_directions[0]
	var best_dot = target_direction.dot(best_direction)
	
	for direction in valid_directions:
		var dot = target_direction.dot(direction)
		if dot > best_dot:
			best_dot = dot
			best_direction = direction
	
	return best_direction

func set_target_grid_position(new_grid_pos: Vector2):
	grid_position = new_grid_pos
	target_position = grid_to_world(grid_position)

func move_towards_target(delta: float):
	var direction = (target_position - global_position).normalized()
	velocity = direction * base_speed
	move_and_slide()
	
	# Snap to grid when close enough
	if global_position.distance_to(target_position) < 5.0:
		global_position = target_position

func world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(int(world_pos.x / tile_size), int(world_pos.y / tile_size))

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return Vector2(grid_pos.x * tile_size + tile_size/2, grid_pos.y * tile_size + tile_size/2)

func is_position_walkable(grid_pos: Vector2) -> bool:
	if not tilemap:
		return true
	
	# Check if position has a walkable tile
	var tile_data = tilemap.get_cell_source_id(Vector2i(grid_pos))
	return tile_data == -1  # -1 means no tile (walkable)

# Add missing function that other scripts expect
func setup_normal_ai():
	# This function is called by the ghost manager
	# Set up basic AI behavior
	current_state = GhostState.WANDERING
	print("Ghost AI initialized for normal behavior")

# Alternative setup function with tilemap parameter (for backward compatibility)
func setup_normal_ai_with_tilemap(tilemap_layer: TileMapLayer):
	tilemap = tilemap_layer
	setup_normal_ai()

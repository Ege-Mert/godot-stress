extends Node
class_name PacmanPlayer

# Player movement and input handling for Pacman game

signal player_moved(new_grid_pos: Vector2)
signal player_reached_target

@export var base_move_speed: float = 150.0
@export var movement_precision: float = 2.0

var player_node: CharacterBody2D
var tilemap_layer: TileMapLayer
var utility: PacmanUtility

# Movement variables
var move_speed: float = 150.0
var player_direction: Vector2 = Vector2.ZERO
var next_player_direction: Vector2 = Vector2.ZERO  # Input buffer
var player_grid_pos: Vector2
var target_pos: Vector2
var player_is_moving: bool = false

func initialize(player: CharacterBody2D, tilemap: TileMapLayer, utilities: PacmanUtility):
	player_node = player
	tilemap_layer = tilemap
	utility = utilities

func set_starting_position(grid_pos: Vector2):
	player_grid_pos = grid_pos
	player_node.position = utility.grid_to_world(player_grid_pos)
	target_pos = player_node.position

func apply_speed_upgrade(speed_bonus: float):
	move_speed = base_move_speed + speed_bonus

func handle_input():
	# Capture input for direction buffer
	var input_direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		input_direction = Vector2(0, -1)
	elif Input.is_action_pressed("ui_down"):
		input_direction = Vector2(0, 1)
	elif Input.is_action_pressed("ui_left"):
		input_direction = Vector2(-1, 0)
	elif Input.is_action_pressed("ui_right"):
		input_direction = Vector2(1, 0)
	
	# Store input for next movement opportunity
	if input_direction != Vector2.ZERO:
		next_player_direction = input_direction
	
	# Try to start movement immediately if not moving
	if not player_is_moving and next_player_direction != Vector2.ZERO:
		try_start_movement()

func try_start_movement():
	# Try to start movement in the buffered direction
	if can_move_to(player_grid_pos + next_player_direction):
		player_direction = next_player_direction
		target_pos = utility.grid_to_world(player_grid_pos + player_direction)
		player_is_moving = true
		next_player_direction = Vector2.ZERO  # Clear buffer

func update_movement(delta: float):
	if not player_is_moving:
		return
	
	# Move towards target with constant speed
	var movement_distance = move_speed * delta
	player_node.position = player_node.position.move_toward(target_pos, movement_distance)
	
	# Check if reached target
	if player_node.position.distance_to(target_pos) <= movement_precision:
		# Snap to exact grid position
		player_grid_pos += player_direction
		player_node.position = utility.grid_to_world(player_grid_pos)
		player_is_moving = false
		
		# Emit signals for other systems to react
		player_moved.emit(player_grid_pos)
		player_reached_target.emit()
		
		# Try to continue movement in current direction or use buffered input
		if next_player_direction != Vector2.ZERO:
			try_start_movement()  # Try buffered direction first
		elif can_move_to(player_grid_pos + player_direction):
			# Continue in same direction
			target_pos = utility.grid_to_world(player_grid_pos + player_direction)
			player_is_moving = true
		else:
			# Stop movement
			player_direction = Vector2.ZERO

func can_move_to(grid_pos: Vector2) -> bool:
	# Check tilemap for walls
	var tile_source_id = tilemap_layer.get_cell_source_id(Vector2i(grid_pos.x, grid_pos.y))
	return tile_source_id == -1  # -1 = empty/walkable, 0+ = wall

func reset_to_spawn(spawn_pos: Vector2):
	player_grid_pos = spawn_pos
	player_node.position = utility.grid_to_world(player_grid_pos)
	target_pos = player_node.position
	player_direction = Vector2.ZERO
	player_is_moving = false
	next_player_direction = Vector2.ZERO

func get_current_grid_position() -> Vector2:
	return player_grid_pos

func get_current_world_position() -> Vector2:
	return player_node.position

func is_moving() -> bool:
	return player_is_moving

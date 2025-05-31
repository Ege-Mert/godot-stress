extends CharacterBody2D

signal player_caught

@onready var sprite = $Sprite2D
@onready var detection_area = $DetectionArea
@onready var collision = $CollisionShape2D

# AI variables
var tilemap_layer: TileMapLayer  # Updated for Godot 4.4
var target_player: Node2D
var move_speed: float = 80.0
var tile_size: int = 32
var current_direction: Vector2 = Vector2.ZERO
var grid_position: Vector2
var target_position: Vector2
var is_moving: bool = false
var ai_timer: float = 0.0
var ai_update_interval: float = 0.5

# Pathfinding
var path: Array = []
var path_index: int = 0

func _ready():
	# Set up sprite appearance
	if sprite:
		sprite.modulate = Color.RED
		# Create simple ghost shape if no sprite
		var texture = ImageTexture.new()
		var image = Image.create(24, 24, false, Image.FORMAT_RGB8)
		image.fill(Color.RED)
		texture.set_image(image)
		sprite.texture = texture
	
	# Detection will be connected after setup
	
	# Initialize position
	grid_position = Vector2(int(position.x / tile_size), int(position.y / tile_size))
	target_position = position

func setup_normal_ai(game_tilemap_layer: TileMapLayer):
	tilemap_layer = game_tilemap_layer
	# Delay finding player until next frame to ensure it's in the tree
	call_deferred("find_player")

func find_player():
	target_player = get_tree().get_first_node_in_group("player")
	# Now connect detection
	if detection_area:
		detection_area.body_entered.connect(_on_player_detected)

func _process(delta):
	if not tilemap_layer or not target_player:
		return
	
	ai_timer += delta
	if ai_timer >= ai_update_interval:
		ai_timer = 0.0
		update_ai()
	
	move_towards_target(delta)

func update_ai():
	# Simple AI: move towards player with some randomness
	var player_grid_pos = Vector2(
		int(target_player.position.x / float(tile_size)),
		int(target_player.position.y / float(tile_size))
	)
	
	# Calculate direction to player
	var direction_to_player = (player_grid_pos - grid_position).normalized()
	
	# Add some randomness (30% chance to move randomly)
	var target_direction: Vector2
	if randf() < 0.7:  # 70% chase player
		target_direction = get_best_direction_to_player(direction_to_player)
	else:  # 30% random movement
		var random_directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		target_direction = random_directions[randi() % random_directions.size()]
	
	# Check if we can move in that direction
	if can_move_to(grid_position + target_direction):
		current_direction = target_direction
		target_position = grid_to_world(grid_position + current_direction)
		is_moving = true

func get_best_direction_to_player(preferred_direction: Vector2) -> Vector2:
	# Try preferred direction first
	if abs(preferred_direction.x) > abs(preferred_direction.y):
		# Move horizontally
		var horizontal_dir = Vector2(sign(preferred_direction.x), 0)
		if can_move_to(grid_position + horizontal_dir):
			return horizontal_dir
		# Fall back to vertical
		var vertical_dir = Vector2(0, sign(preferred_direction.y))
		if can_move_to(grid_position + vertical_dir):
			return vertical_dir
	else:
		# Move vertically
		var vertical_dir = Vector2(0, sign(preferred_direction.y))
		if can_move_to(grid_position + vertical_dir):
			return vertical_dir
		# Fall back to horizontal
		var horizontal_dir = Vector2(sign(preferred_direction.x), 0)
		if can_move_to(grid_position + horizontal_dir):
			return horizontal_dir
	
	# If neither works, try any valid direction
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for dir in directions:
		if can_move_to(grid_position + dir):
			return dir
	
	return Vector2.ZERO

func move_towards_target(delta):
	if not is_moving:
		return
	
	# Move towards target position
	var movement = current_direction * move_speed * delta
	position = position.move_toward(target_position, movement.length())
	
	# Check if reached target
	if position.distance_to(target_position) < 2.0:
		grid_position += current_direction
		position = grid_to_world(grid_position)
		is_moving = false
		current_direction = Vector2.ZERO

func can_move_to(grid_pos: Vector2) -> bool:
	# Check bounds
	if grid_pos.x < 0 or grid_pos.x >= 11 or grid_pos.y < 0 or grid_pos.y >= 14:
		return false
	
	# Check for walls in tilemap layer (updated for Godot 4.4)
	var tile_id = tilemap_layer.get_cell_source_id(Vector2i(grid_pos.x, grid_pos.y))
	return tile_id == -1  # -1 = empty, 0+ = wall/obstacle

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return grid_pos * float(tile_size) + Vector2(float(tile_size)/2.0, float(tile_size)/2.0)

func _on_player_detected(body):
	if body.is_in_group("player"):
		player_caught.emit()

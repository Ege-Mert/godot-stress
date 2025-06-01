extends CharacterBody2D

signal player_caught

@onready var sprite = $Sprite2D
@onready var detection_area = $DetectionArea
@onready var collision = $CollisionShape2D

# AI variables
var tilemap_layer: TileMapLayer  # Updated for Godot 4.4
var target_player: Node2D
var move_speed: float = 100.0
var tile_size: int = 32
var current_direction: Vector2 = Vector2.ZERO
var next_direction: Vector2 = Vector2.ZERO
var grid_position: Vector2
var target_position: Vector2
var is_moving: bool = false
var ai_timer: float = 0.0
var ai_update_interval: float = 0.3  # Faster AI updates
var movement_precision: float = 2.0  # How close to target before snapping

# Pathfinding
var path: Array = []
var path_index: int = 0

func _ready():
	# Set up sprite appearance
	if sprite:
		# Only create programmatic texture if no sprite asset is loaded
		if not sprite.texture:
			sprite.modulate = Color.RED
			# Create simple ghost shape as fallback
			var texture = ImageTexture.new()
			var image = Image.create(24, 24, false, Image.FORMAT_RGB8)
			image.fill(Color.RED)
			texture.set_image(image)
			sprite.texture = texture
		else:
			# Scale actual sprite assets to appropriate size
			sprite.scale = Vector2(2.0, 2.0)  # Adjust this value as needed
			sprite.modulate = Color.RED
	
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
	
	# Update AI less frequently but move every frame
	ai_timer += delta
	if ai_timer >= ai_update_interval:
		ai_timer = 0.0
		update_ai()
	
	# Always try to move
	move_towards_target(delta)

func update_ai():
	# Only change direction when not currently moving or at intersection
	if is_moving:
		return
	
	# Get player position
	var player_grid_pos = Vector2(
		int(target_player.position.x / float(tile_size)),
		int(target_player.position.y / float(tile_size))
	)
	
	# Calculate direction to player
	var direction_to_player = player_grid_pos - grid_position
	
	# Choose next direction (80% chase, 20% random)
	var target_direction: Vector2
	if randf() < 0.8:  # 80% chase player
		target_direction = get_best_direction_to_player(direction_to_player)
	else:  # 20% random movement
		var random_directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		target_direction = random_directions[randi() % random_directions.size()]
	
	# Start movement if direction is valid
	if target_direction != Vector2.ZERO and can_move_to(grid_position + target_direction):
		next_direction = target_direction
		start_movement()
	else:
		# Try any valid direction if stuck
		var fallback_directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		for dir in fallback_directions:
			if can_move_to(grid_position + dir):
				next_direction = dir
				start_movement()
				break

func start_movement():
	current_direction = next_direction
	target_position = grid_to_world(grid_position + current_direction)
	is_moving = true

func get_best_direction_to_player(direction_to_player: Vector2) -> Vector2:
	if direction_to_player == Vector2.ZERO:
		return Vector2.ZERO
	
	# Determine primary direction (horizontal or vertical)
	var directions_to_try = []
	
	if abs(direction_to_player.x) > abs(direction_to_player.y):
		# Horizontal movement is preferred
		var horizontal_dir = Vector2(sign(direction_to_player.x), 0)
		var vertical_dir = Vector2(0, sign(direction_to_player.y))
		directions_to_try = [horizontal_dir, vertical_dir]
	else:
		# Vertical movement is preferred
		var vertical_dir = Vector2(0, sign(direction_to_player.y))
		var horizontal_dir = Vector2(sign(direction_to_player.x), 0)
		directions_to_try = [vertical_dir, horizontal_dir]
	
	# Try directions in order of preference
	for dir in directions_to_try:
		if dir != Vector2.ZERO and can_move_to(grid_position + dir):
			return dir
	
	return Vector2.ZERO

func move_towards_target(delta):
	if not is_moving:
		return
	
	# Move towards target position with constant speed
	var movement_distance = move_speed * delta
	position = position.move_toward(target_position, movement_distance)
	
	# Check if reached target with precision
	if position.distance_to(target_position) <= movement_precision:
		# Snap to exact grid position
		grid_position += current_direction
		position = grid_to_world(grid_position)
		is_moving = false
		current_direction = Vector2.ZERO
		next_direction = Vector2.ZERO

func can_move_to(grid_pos: Vector2) -> bool:
	# More flexible bounds - allow ghosts to move in larger area
	if grid_pos.x < -1 or grid_pos.x >= 22 or grid_pos.y < -1 or grid_pos.y >= 16:
		return false
	
	# Check for walls in tilemap layer (updated for Godot 4.4)
	var tile_id = tilemap_layer.get_cell_source_id(Vector2i(grid_pos.x, grid_pos.y))
	return tile_id == -1  # -1 = empty, 0+ = wall/obstacle

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return grid_pos * float(tile_size) + Vector2(float(tile_size)/2.0, float(tile_size)/2.0)

func _on_player_detected(body):
	if body.is_in_group("player"):
		player_caught.emit()

extends Area2D

signal picked_up

@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var animation_player = $AnimationPlayer

var is_collected: bool = false
var grid_position: Vector2  # Store grid position for persistence

func _ready():
	# Connect to player detection
	body_entered.connect(_on_body_entered)
	
	# Start idle animation
	# if animation_player:
		# animation_player.play("idle_spin")
	
	# Set up sprite (you can replace this with actual coin sprite)
	if sprite:
		# Only create programmatic texture if no sprite asset is loaded
		if not sprite.texture:
			sprite.modulate = Color.YELLOW
			# Create a simple circular coin shape as fallback
			var texture = ImageTexture.new()
			var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
			image.fill(Color.YELLOW)
			texture.set_image(image)
			sprite.texture = texture
		else:
			# Scale actual sprite assets to appropriate size
			sprite.scale = Vector2(1.5, 1.5)  # Adjust this value as needed
			sprite.modulate = Color.YELLOW

func _on_body_entered(body):
	if body.is_in_group("player") and not is_collected:
		collect()

func collect():
	if is_collected:
		return  # Prevent double collection
		
	is_collected = true
	
	# Disable collision immediately to prevent multiple triggers
	if collision:
		collision.disabled = true
	
	# Emit signal
	picked_up.emit()
	
	# Collection animation
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.2)
	
	# Hide completely after animation
	tween.tween_callback(_on_collection_complete)

func _on_collection_complete():
	# Hide the coin but don't queue_free it (for persistence)
	hide()
	set_process(false)
	set_physics_process(false)
	# Disable collision to prevent invisible collection
	if collision:
		collision.disabled = true

func set_collected_state(collected: bool):
	"""Set whether this coin should be considered collected"""
	is_collected = collected
	if collected:
		# Hide and disable collision
		hide()
		set_process(false)
		set_physics_process(false)
		if collision:
			collision.disabled = true
	else:
		# Show and enable collision
		show()
		set_process(true)
		set_physics_process(true)
		if collision:
			collision.disabled = false
		if sprite:
			sprite.modulate.a = 1.0  # Reset alpha
			sprite.scale = Vector2(1.5, 1.5)  # Reset scale

func reset():
	"""Reset coin to uncollected state"""
	set_collected_state(false)
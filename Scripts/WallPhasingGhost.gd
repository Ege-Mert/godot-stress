extends CharacterBody2D

signal player_caught

@onready var sprite = $Sprite2D
@onready var detection_area = $DetectionArea  # This should exist in the scene
@onready var ghost_trail = get_node_or_null("GhostTrail")  # May not exist

# AI variables
var target_player: Node2D
var base_move_speed: float = 120.0  # Starting speed
var current_move_speed: float = 120.0
var speed_increase_rate: float = 20.0  # Speed increase per second
var max_speed: float = 300.0  # Maximum speed cap
var tile_size: int = 32
var can_phase_walls: bool = true
var spawn_time: float = 0.0

# Visual effects
var phase_alpha: float = 0.7  # Semi-transparent to show wall phasing
var trail_timer: float = 0.0
var trail_interval: float = 0.1

func _ready():
	# Set up special appearance
	if sprite:
		sprite.modulate = Color(1.0, 0.3, 1.0, phase_alpha)  # Purple/magenta
		# Create special ghost shape
		var texture = ImageTexture.new()
		var image = Image.create(28, 28, false, Image.FORMAT_RGB8)
		image.fill(Color(1.0, 0.3, 1.0))
		texture.set_image(image)
		sprite.texture = texture
	
	# Connect detection (will be connected in setup_phasing_ai)
	# if detection_area:
	#	detection_area.body_entered.connect(_on_player_detected)
	
	# Special visual effects
	add_pulsing_effect()

func setup_phasing_ai(player: Node2D):
	target_player = player
	spawn_time = Time.get_ticks_msec() / 1000.0
	current_move_speed = base_move_speed
	
	# Set up detection after node is fully in tree
	call_deferred("setup_detection")
		
	print("Wall-phasing ghost spawned - will get faster over time!")

func setup_detection():
	"""Set up collision detection after node is in scene tree"""
	var detect_area = get_node_or_null("DetectionArea")
	if detect_area:
		if not detect_area.body_entered.is_connected(_on_player_detected):
			detect_area.body_entered.connect(_on_player_detected)
			print("✅ Detection area connected successfully!")
		else:
			print("Detection area signal already connected")
	else:
		print("❌ ERROR: DetectionArea node not found in scene!")
		print("Available children: ", get_children())

func _process(delta):
	if not target_player:
		return
	
	# Increase speed over time
	var time_alive = (Time.get_ticks_msec() / 1000.0) - spawn_time
	current_move_speed = min(base_move_speed + (time_alive * speed_increase_rate), max_speed)
	
	# Update sprite color based on speed (more red = faster)
	var speed_ratio = (current_move_speed - base_move_speed) / (max_speed - base_move_speed)
	var red_intensity = 1.0
	var other_intensity = 1.0 - (speed_ratio * 0.7)  # Reduce green/blue as speed increases
	sprite.modulate = Color(red_intensity, other_intensity, other_intensity, phase_alpha)
	
	# Direct movement towards player (can ignore walls)
	move_directly_to_player(delta)
	
	# Update visual effects
	update_trail_effect(delta)

func move_directly_to_player(delta):
	if not target_player:
		return
	
	# Calculate direct path to player
	var direction_to_player = (target_player.position - position).normalized()
	
	# Move directly (ignore collision with walls) using current speed
	velocity = direction_to_player * current_move_speed
	
	# Don't use move_and_slide() since we want to phase through walls
	position += velocity * delta

func add_pulsing_effect():
	# Pulsing alpha effect to show supernatural nature
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "modulate:a", 0.4, 1.0)
	tween.tween_property(sprite, "modulate:a", 0.8, 1.0)

func update_trail_effect(delta):
	trail_timer += delta
	if trail_timer >= trail_interval:
		trail_timer = 0.0
		create_trail_particle()

func create_trail_particle():
	# Create a trail effect behind the ghost
	var trail_particle = Sprite2D.new()
	trail_particle.texture = sprite.texture
	trail_particle.modulate = Color(1.0, 0.3, 1.0, 0.3)
	trail_particle.position = position
	trail_particle.scale = Vector2(0.8, 0.8)
	
	get_parent().add_child(trail_particle)
	
	# Fade out trail particle
	var tween = create_tween()
	tween.tween_property(trail_particle, "modulate:a", 0.0, 0.5)
	tween.tween_property(trail_particle, "scale", Vector2(0.3, 0.3), 0.5)
	tween.tween_callback(trail_particle.queue_free)

func _on_player_detected(body):
	print("🔍 Wall ghost detected collision with: ", body.name, " (class: ", body.get_class(), ")")
	print("Body groups: ", body.get_groups())
	
	if body.is_in_group("player"):
		print("✅ Confirmed player collision - emitting signal")
		# Special effect when catching player
		create_catch_effect()
		print("📡 About to emit player_caught signal...")
		player_caught.emit()
		print("📡 Signal emitted successfully")
	else:
		print("❌ Not a player - ignoring collision")

func create_catch_effect():
	# Screen flash effect
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.0, 1.0, 0.5)
	flash.size = get_viewport().size
	get_tree().current_scene.add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(flash.queue_free)
extends Control
class_name SlotMachineHandle

@export_group("Handle Settings")
@export var handle_pull_threshold: float = 60.0
@export var handle_return_speed: float = 0.4
@export var handle_sensitivity: float = 1.0
@export var enable_handle: bool = true

@export_group("Visual Feedback")
@export var handle_normal_color: Color = Color.WHITE
@export var handle_pulled_color: Color = Color.YELLOW
@export var handle_disabled_color: Color = Color.GRAY

@export_group("Scale Settings")
@export var min_scale: float = 0.8 ## Scale when fully pulled
@export var max_scale: float = 1.0 ## Scale when at rest
@export var scale_smoothness: float = 0.1 ## How smooth the scaling is

signal handle_pulled

@onready var handle_sprite = $HandleSprite

var handle_original_pos: Vector2
var handle_original_scale: Vector2
var is_handle_dragging: bool = false
var handle_pulled_state: bool = false
var drag_start_pos: Vector2
var handle_tween: Tween
var controller: SlotMachineController
var position_initialized: bool = false

func _ready():
	controller = get_parent() as SlotMachineController
	
	print("Handle _ready - Initial position:", position)
	
	# Wait for one frame to ensure everything is ready
	await get_tree().process_frame
	call_deferred("setup_handle")

func setup_handle():
	if not handle_sprite:
		push_error("HandleSprite not found!")
		return
	
	# Store the position now that layout is complete
	handle_original_pos = position
	handle_original_scale = scale
	position_initialized = true
	
	print("Handle setup complete - Position: ", handle_original_pos, " Scale: ", handle_original_scale)
	
	# Set sprite offset to center horizontally and anchor at bottom for scaling
	if handle_sprite and handle_sprite.texture:
		var texture_size = handle_sprite.texture.get_size()
		# Center horizontally, anchor at bottom
		handle_sprite.offset = Vector2(-texture_size.x / 2, -texture_size.y)
	
	var input_detector = Control.new()
	input_detector.name = "InputDetector"
	input_detector.size = size if size != Vector2.ZERO else Vector2(50, 100)
	input_detector.position = Vector2.ZERO
	input_detector.gui_input.connect(_on_handle_input)
	input_detector.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(input_detector)

func _on_handle_input(event):
	if not enable_handle or not controller or not controller.can_perform_spin() or not position_initialized:
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			start_handle_drag(event.global_position)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			release_handle()
	
	elif event is InputEventMouseMotion and is_handle_dragging:
		update_handle_drag(event.global_position)

func _input(event):
	if event is InputEventMouseButton:
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_handle_dragging:
				release_handle()

func start_handle_drag(global_mouse_pos: Vector2):
	if not enable_handle or not position_initialized:
		return
	
	is_handle_dragging = true
	handle_pulled_state = false
	drag_start_pos = global_mouse_pos
	
	# Kill any existing tweens
	if handle_tween and handle_tween.is_valid():
		handle_tween.kill()
	
	update_handle_visual(true)

func update_handle_drag(global_mouse_pos: Vector2):
	if not is_handle_dragging or not position_initialized:
		return
	
	var pull_distance = (global_mouse_pos.y - drag_start_pos.y) * handle_sensitivity
	pull_distance = max(0, pull_distance)
	
	# Update position
	var new_y = handle_original_pos.y + min(pull_distance, handle_pull_threshold)
	position.y = new_y
	
	# Update scale based on pull distance - scale from bottom up
	var pull_progress = min(pull_distance / handle_pull_threshold, 1.0)
	var current_scale_y = lerp(max_scale, min_scale, pull_progress)
	
	# Apply scaling with bottom anchor point by adjusting position
	var scale_diff = handle_original_scale.y - current_scale_y
	if handle_sprite and handle_sprite.texture:
		var texture_height = handle_sprite.texture.get_size().y
		var scale_offset = (texture_height * scale_diff) * 0.5
		
		# Scale uniformly but adjust Y position to maintain bottom anchor
		scale = Vector2(current_scale_y, current_scale_y)
		position.y = new_y + scale_offset
	else:
		scale = Vector2(current_scale_y, current_scale_y)
	
	if pull_distance >= handle_pull_threshold and not handle_pulled_state:
		handle_pulled_state = true
		on_handle_pulled()

func release_handle():
	if not is_handle_dragging:
		return
	
	is_handle_dragging = false
	
	animate_handle_return()
	update_handle_visual(false)

func animate_handle_return():
	if not position_initialized:
		return
		
	# Animate position and scale return with proper bottom anchoring
	handle_tween = create_tween()
	handle_tween.set_parallel(true)
	
	# Return to original position
	handle_tween.tween_property(self, "position", handle_original_pos, handle_return_speed)
	
	# Return to original scale
	handle_tween.tween_property(self, "scale", handle_original_scale, handle_return_speed)
	
	# Reset state when animation completes
	handle_tween.tween_callback(func(): handle_pulled_state = false)

func on_handle_pulled():
	handle_pulled.emit()
	update_handle_visual(false, true)

func update_handle_visual(dragging: bool, pulled: bool = false):
	if not handle_sprite:
		return
	
	if not enable_handle:
		handle_sprite.modulate = handle_disabled_color
	elif pulled:
		handle_sprite.modulate = handle_pulled_color
	elif dragging:
		handle_sprite.modulate = handle_pulled_color.lerp(handle_normal_color, 0.5)
	else:
		handle_sprite.modulate = handle_normal_color

func set_handle_enabled(enabled: bool):
	enable_handle = enabled
	update_handle_visual(false)
	
	# Reset to original state when disabled
	if not enabled and position_initialized:
		position = handle_original_pos
		scale = handle_original_scale

func reset_handle_position():
	"""Reset handle to original position and scale - useful for debugging"""
	if not position_initialized:
		call_deferred("reset_handle_position")
		return
	
	is_handle_dragging = false
	handle_pulled_state = false
	
	# Kill any active tweens
	if handle_tween and handle_tween.is_valid():
		handle_tween.kill()
	
	# Reset to original state
	position = handle_original_pos
	scale = handle_original_scale
	update_handle_visual(false)
	
	print("Handle reset to original position: ", handle_original_pos, " scale: ", handle_original_scale)

func set_original_position(new_pos: Vector2, new_scale: Vector2 = Vector2.ONE):
	"""Manually set the original position and scale for the handle"""
	handle_original_pos = new_pos
	handle_original_scale = new_scale
	position = handle_original_pos
	scale = handle_original_scale
	position_initialized = true
	print("Handle original position set to: ", handle_original_pos, " scale: ", handle_original_scale)

func get_original_position() -> Vector2:
	"""Get the handle's original position"""
	return handle_original_pos

func _exit_tree():
	if handle_tween and handle_tween.is_valid():
		handle_tween.kill()

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

signal handle_pulled

@onready var handle_sprite = $HandleSprite

var handle_original_pos: Vector2
var is_handle_dragging: bool = false
var handle_pulled_state: bool = false
var drag_start_pos: Vector2
var handle_tween: Tween
var controller: SlotMachineController

func _ready():
	controller = get_parent() as SlotMachineController
	setup_handle()

func setup_handle():
	if not handle_sprite:
		push_error("HandleSprite not found!")
		return
	
	handle_original_pos = position
	
	var input_detector = Control.new()
	input_detector.name = "InputDetector"
	input_detector.size = size if size != Vector2.ZERO else Vector2(50, 100)
	input_detector.position = Vector2.ZERO
	input_detector.gui_input.connect(_on_handle_input)
	input_detector.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(input_detector)

func _on_handle_input(event):
	if not enable_handle or not controller or not controller.can_perform_spin():
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
	if not enable_handle:
		return
	
	is_handle_dragging = true
	handle_pulled_state = false
	drag_start_pos = global_mouse_pos
	
	if handle_tween and handle_tween.is_valid():
		handle_tween.kill()
	
	update_handle_visual(true)

func update_handle_drag(global_mouse_pos: Vector2):
	if not is_handle_dragging:
		return
	
	var pull_distance = (global_mouse_pos.y - drag_start_pos.y) * handle_sensitivity
	pull_distance = max(0, pull_distance)
	
	var new_y = handle_original_pos.y + min(pull_distance, handle_pull_threshold)
	position.y = new_y
	
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
	handle_tween = create_tween()
	handle_tween.tween_property(self, "position", handle_original_pos, handle_return_speed)
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

func _exit_tree():
	if handle_tween and handle_tween.is_valid():
		handle_tween.kill()

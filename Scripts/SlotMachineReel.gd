extends Control
class_name SlotMachineReel

signal reel_stopped(final_position: float, visible_symbols: Array[int])
signal reel_spinning()

@export_group("Reel Configuration")
@export var reel_strip: SlotMachineSymbolStrip
@export var reel_index: int = 0
@export var symbol_height: float = 80.0
@export var visible_symbols: int = 1  # How many symbols are visible (usually 1 for center)

@export_group("Physics Settings")
@export var initial_velocity_min: float = 20.0
@export var initial_velocity_max: float = 30.0
@export var friction: float = 2.0
@export var stop_threshold: float = 0.1
@export var snap_to_symbol: bool = true
@export var snap_strength: float = 5.0

var current_position: float = 0.0
var current_velocity: float = 0.0
var is_spinning: bool = false
var symbol_textures: Array[Texture2D] = []
var symbol_containers: Array[Control] = []
var config: SlotMachineConfig

var stop_requested: bool = false

func setup_with_config(slot_config: SlotMachineConfig, textures: Array[Texture2D]):
	config = slot_config
	symbol_textures = textures

	# Create default strip if none assigned
	if not reel_strip:
		reel_strip = SlotMachineSymbolStrip.create_default_strip()

	# Initialize visual elements
	_create_symbol_containers()
	_update_symbol_display()

func _ready():
	clip_contents = true
	set_process(false)

func _create_symbol_containers():
	# Clear existing containers
	for container in symbol_containers:
		container.queue_free()
	symbol_containers.clear()

	# Create containers for visible symbols plus buffer
	var buffer_symbols = 2  # Extra symbols above and below for smooth scrolling
	var total_symbols = visible_symbols + (buffer_symbols * 2)

	# Apply visual offset to center the middle symbol properly
	var visual_offset = symbol_height  # Move everything down by one symbol height

	for i in range(total_symbols):
		var container = Control.new()
		container.size = Vector2(size.x, symbol_height)
		# Shift containers down by adding visual_offset
		container.position.y = (i - buffer_symbols) * symbol_height + visual_offset
		add_child(container)
		symbol_containers.append(container)

func start_spin():
	if is_spinning:
		return

	is_spinning = true
	current_velocity = randf_range(initial_velocity_min, initial_velocity_max)
	set_process(true)
	reel_spinning.emit()

func stop_spin():
	# Natural deceleration is already happening
	# This just ensures we're processing
	if not is_spinning:
		return
	set_process(true)

func force_stop():
	is_spinning = false
	current_velocity = 0.0
	set_process(false)
	_snap_to_nearest_symbol()

func request_stop():
	# Mark that this reel should stop naturally
	stop_requested = true
	# Make sure the reel has some minimum velocity to ensure it stops within a reasonable time
	if current_velocity < 5.0:
		current_velocity = 5.0

func _process(delta: float):
	if not is_spinning:
		return
	
	# Update position based on velocity
	current_position += current_velocity * delta
	
	# Apply friction (stronger if stop is requested)
	var friction_multiplier = 3.0 if stop_requested else 1.0
	current_velocity -= friction * friction_multiplier * delta
	
	# Check if we should stop
	if current_velocity <= stop_threshold:
		is_spinning = false
		current_velocity = 0.0
		stop_requested = false
		set_process(false)
		
		if snap_to_symbol:
			_snap_to_nearest_symbol()
		else:
			_on_reel_stopped()
	
	# Update visual display
	_update_symbol_display()

func _snap_to_nearest_symbol():
	# Find nearest whole symbol position
	var nearest_symbol = round(current_position)
	
	# Smooth tween to the nearest whole position
	var tween = create_tween()
	tween.tween_property(self, "current_position", nearest_symbol, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(_on_reel_stopped)
	tween.tween_callback(_update_symbol_display)

func _update_symbol_display():
	if not reel_strip or symbol_containers.is_empty():
		return
	
	var strip_length = reel_strip.get_strip_length()
	if strip_length == 0:
		return
	
	var center_position = current_position
	var offset_within_symbol = fmod(current_position, 1.0)
	
	# Apply visual offset to shift display down by one symbol
	var visual_offset = symbol_height  # One symbol height down
	
	# Update each symbol container
	for i in range(symbol_containers.size()):
		var container = symbol_containers[i]
		var symbol_offset = i - (symbol_containers.size() / 2)
		
		# Get symbol index at current position
		var symbol_index = reel_strip.get_symbol_at_position(center_position + symbol_offset)
		
		# Clear previous content
		for child in container.get_children():
			child.queue_free()
		
		# Add new symbol
		_create_symbol_visual(container, symbol_index)
		
		# Update position with offset for smooth scrolling
		container.position.y = (symbol_offset - offset_within_symbol) * symbol_height + visual_offset

func _create_symbol_visual(container: Control, symbol_index: int):
	if symbol_index < symbol_textures.size() and symbol_textures[symbol_index]:
		var texture = symbol_textures[symbol_index]
		var texture_rect = TextureRect.new()
		texture_rect.texture = texture
		texture_rect.expand = true
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.size = container.size
		container.add_child(texture_rect)
	else:
		# Fallback for missing texture
		var label = Label.new()
		if config and symbol_index < config.symbols.size():
			label.text = config.symbols[symbol_index].symbol_name
		else:
			label.text = "Symbol " + str(symbol_index)
		label.add_theme_font_size_override("font_size", 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = container.size
		container.add_child(label)

func _on_reel_stopped():
	var final_symbol = reel_strip.get_symbol_at_position(current_position)
	var visible_syms = reel_strip.get_symbols_in_view(current_position, visible_symbols)
	reel_stopped.emit(current_position, visible_syms)

func get_current_symbol() -> int:
	if not reel_strip:
		return 0

	# Debug what symbol we think is at current position
	var symbol = reel_strip.get_symbol_at_position(current_position)
	print("DEBUG Reel ", reel_index, " thinks symbol at pos ", current_position, " is ", symbol)
	
	# Also check what the visual display thinks
	var visual_center_pos = current_position
	print("DEBUG Visual center should be at: ", visual_center_pos)
	
	return symbol

func get_reel_position() -> float:
	return current_position

func set_reel_position(new_position: float):
	current_position = new_position
	_update_symbol_display()

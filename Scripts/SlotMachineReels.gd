extends Control
class_name SlotMachineReels

signal animation_completed
signal reel_stopped(reel_index: int)

@onready var reel1 = $Reels/Reel1
@onready var reel2 = $Reels/Reel2
@onready var reel3 = $Reels/Reel3

var config: SlotMachineConfig
var final_symbols: Array[int] = [0, 0, 0]
var reel_containers: Array[Control] = []
var spinning_symbols: Array[Array] = [[], [], []]
var animation_tweens: Array[Tween] = []
var reels_stopped_count: int = 0

func setup_with_config(slot_config: SlotMachineConfig):
	config = slot_config
	if not config:
		push_error("SlotMachineReels: No config provided!")

func _ready():
	setup_reel_containers()

func setup_reel_containers():
	reel_containers = [reel1, reel2, reel3]
	
	for i in range(reel_containers.size()):
		if reel_containers[i]:
			reel_containers[i].clip_contents = true

func initialize_reels():
	if not config or config.get_symbol_count() == 0:
		push_error("Cannot initialize reels: no valid config or symbols")
		return
	
	for i in range(reel_containers.size()):
		if reel_containers[i]:
			var random_symbol = randi() % config.get_symbol_count()
			final_symbols[i] = random_symbol
			create_static_symbol(reel_containers[i], random_symbol)

func start_spin_animation(symbols: Array[int]):
	if not config:
		push_error("Cannot start animation: no config")
		return
	
	final_symbols = symbols
	reels_stopped_count = 0
	clear_animation_tweens()
	
	# Start the 3-phase animation for each reel
	for i in range(reel_containers.size()):
		start_reel_sequence(i)

func start_reel_sequence(reel_index: int):
	if reel_index >= reel_containers.size() or not reel_containers[reel_index]:
		return
	
	var reel = reel_containers[reel_index]
	
	# Phase 1: Rise up
	start_rise_phase(reel, reel_index)

func start_rise_phase(reel: Control, reel_index: int):
	clear_reel_children(reel)
	
	# Create symbol for rising animation
	var symbol_node = create_spinning_symbol(reel, final_symbols[reel_index])
	symbol_node.position.y = 0
	
	var rise_tween = create_tween()
	animation_tweens.append(rise_tween)
	
	rise_tween.tween_property(
		symbol_node, 
		"position:y", 
		-config.rise_distance, 
		config.rise_duration
	).set_ease(config.rise_ease_type)
	
	rise_tween.tween_callback(func(): start_fall_phase(reel, reel_index))

func start_fall_phase(reel: Control, reel_index: int):
	var symbol_node = get_reel_symbol_node(reel)
	if not symbol_node:
		return
	
	var fall_duration = config.rise_duration / config.fall_speed_multiplier
	var fall_tween = create_tween()
	animation_tweens.append(fall_tween)
	
	fall_tween.tween_property(
		symbol_node,
		"position:y",
		0,
		fall_duration
	).set_ease(config.fall_ease_type)
	
	fall_tween.tween_callback(func(): start_spin_phase(reel, reel_index))

func start_spin_phase(reel: Control, reel_index: int):
	# Clear the reel and setup spinning symbols
	clear_reel_children(reel)
	setup_spinning_symbols(reel, reel_index)
	
	# Calculate total spin time including stagger
	var total_spin_time = config.base_spin_duration + (reel_index * config.reel_stop_delay)
	
	# Start spinning animation
	var spin_tween = create_tween()
	animation_tweens.append(spin_tween)
	
	spin_tween.tween_method(
		func(progress): update_spinning_reel(reel, reel_index, progress),
		0.0,
		1.0,
		total_spin_time
	).set_ease(config.deceleration_ease)
	
	spin_tween.tween_callback(func(): stop_reel(reel, reel_index))

func setup_spinning_symbols(reel: Control, reel_index: int):
	spinning_symbols[reel_index].clear()
	
	# Create multiple symbols for smooth spinning effect
	var symbols_in_view = 5  # Number of symbols visible during spin
	var symbol_height = reel.size.y / 3  # Assume 3 symbols fit in view
	
	for i in range(symbols_in_view * 2):  # Extra symbols for smooth loop
		var symbol_index = randi() % config.get_symbol_count()
		var symbol_node = create_spinning_symbol(reel, symbol_index)
		symbol_node.position.y = i * symbol_height - symbol_height
		spinning_symbols[reel_index].append(symbol_node)

func update_spinning_reel(reel: Control, reel_index: int, progress: float):
	if spinning_symbols[reel_index].is_empty():
		return
	
	# Calculate spin speed with deceleration
	var current_speed = config.spin_speed_rps
	if progress > 0.7:  # Start slowing down in last 30%
		var decel_progress = (progress - 0.7) / 0.3
		current_speed = lerp(config.spin_speed_rps, 0.1, decel_progress)
	
	# Move symbols downward to create spinning effect
	var symbol_height = reel.size.y / 3
	var delta = 0.016  # Assume 60 FPS for consistent animation
	var movement = current_speed * symbol_height * delta
	
	for symbol_node in spinning_symbols[reel_index]:
		if symbol_node and is_instance_valid(symbol_node):
			symbol_node.position.y += movement
			
			# Loop symbol back to top when it goes off screen
			if symbol_node.position.y > reel.size.y + symbol_height:
				symbol_node.position.y -= (spinning_symbols[reel_index].size() * symbol_height)

func stop_reel(reel: Control, reel_index: int):
	# Clear spinning symbols and show final result
	clear_reel_children(reel)
	
	# Create final symbol with settle animation
	var final_symbol = create_spinning_symbol(reel, final_symbols[reel_index])
	final_symbol.position.y = -10  # Start slightly above
	
	var settle_tween = create_tween()
	animation_tweens.append(settle_tween)
	
	settle_tween.tween_property(
		final_symbol,
		"position:y",
		0,
		config.final_settle_duration
	).set_ease(Tween.EASE_OUT)
	
	# Emit reel stopped signal
	reel_stopped.emit(reel_index)
	
	reels_stopped_count += 1
	if reels_stopped_count >= reel_containers.size():
		animation_completed.emit()

func create_spinning_symbol(reel: Control, symbol_index: int) -> Control:
	var symbol_data = config.get_symbol_by_index(symbol_index)
	if not symbol_data:
		return create_fallback_symbol(reel, symbol_index)
	
	if symbol_data.symbol_texture:
		return create_texture_symbol(reel, symbol_data)
	else:
		return create_text_symbol(reel, symbol_data)

func create_texture_symbol(reel: Control, symbol_data: SymbolData) -> TextureRect:
	var texture_rect = TextureRect.new()
	texture_rect.texture = symbol_data.symbol_texture
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.size = reel.size
	texture_rect.position = Vector2.ZERO
	reel.add_child(texture_rect)
	return texture_rect

func create_text_symbol(reel: Control, symbol_data: SymbolData) -> Label:
	var label = Label.new()
	label.text = symbol_data.symbol_name
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = reel.size
	label.position = Vector2.ZERO
	reel.add_child(label)
	return label

func create_fallback_symbol(reel: Control, symbol_index: int) -> Label:
	var label = Label.new()
	label.text = "?" + str(symbol_index)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = reel.size
	label.position = Vector2.ZERO
	reel.add_child(label)
	return label

func create_static_symbol(reel: Control, symbol_index: int):
	clear_reel_children(reel)
	create_spinning_symbol(reel, symbol_index)

func highlight_winning_symbols(result: Dictionary):
	if not config.show_win_highlights or result.winning_symbol == -1:
		return
	
	var winning_symbol_data = config.get_symbol_by_index(result.winning_symbol)
	if not winning_symbol_data:
		return
	
	# Highlight matching symbols
	for i in range(reel_containers.size()):
		if final_symbols[i] == result.winning_symbol:
			highlight_reel(i, winning_symbol_data.highlight_color)

func highlight_reel(reel_index: int, color: Color):
	if reel_index >= reel_containers.size():
		return
	
	var reel = reel_containers[reel_index]
	var symbol_node = get_reel_symbol_node(reel)
	
	if not symbol_node:
		return
	
	# Create highlight effect
	var original_modulate = symbol_node.modulate
	var original_scale = symbol_node.scale
	
	var highlight_tween = create_tween()
	highlight_tween.set_parallel(true)
	
	# Color highlight
	highlight_tween.tween_property(symbol_node, "modulate", color, 0.2)
	highlight_tween.tween_property(symbol_node, "modulate", original_modulate, 0.2).set_delay(0.2)
	
	# Scale effect
	highlight_tween.tween_property(symbol_node, "scale", original_scale * config.symbol_scale_on_win, 0.2)
	highlight_tween.tween_property(symbol_node, "scale", original_scale, 0.2).set_delay(0.2)
	
	# Repeat a few times
	for i in range(3):
		var delay = (i + 1) * 0.5
		highlight_tween.tween_property(symbol_node, "modulate", color, 0.2).set_delay(delay)
		highlight_tween.tween_property(symbol_node, "modulate", original_modulate, 0.2).set_delay(delay + 0.2)

func get_reel_symbol_node(reel: Control) -> Control:
	if reel.get_child_count() > 0:
		return reel.get_child(0)
	return null

func clear_reel_children(reel: Control):
	for child in reel.get_children():
		child.queue_free()

func clear_animation_tweens():
	for tween in animation_tweens:
		if tween and tween.is_valid():
			tween.kill()
	animation_tweens.clear()
	
	# Clear spinning symbols arrays
	for i in range(spinning_symbols.size()):
		spinning_symbols[i].clear()

func _exit_tree():
	clear_animation_tweens()

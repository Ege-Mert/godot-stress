extends Control
class_name SlotMachineReels

@export_group("Reel Symbols")
@export var reel_symbols: Array[String] = [
	"res://Sprites/cherry.png",
	"res://Sprites/lemon.png", 
	"res://Sprites/orange.png",
	"res://Sprites/bell.png",
	"res://Sprites/star.png",
	"res://Sprites/diamond.png",
	"res://Sprites/seven.png"
]
@export var reel_symbol_names: Array[String] = ["Cherry", "Lemon", "Orange", "Bell", "Star", "Diamond", "Seven"]

@export_group("Animation Settings")
@export var kick_up_distance: float = 20.0
@export var kick_up_duration: float = 0.2
@export var base_spin_duration: float = 2.5
@export var spin_stagger_delay: float = 0.6
@export var total_rotations: float = 4.0
@export var ease_out_strength: float = 2.0

@export_group("Visual Effects")
@export var enable_wobble: bool = true
@export var wobble_intensity: float = 10.0
@export var use_textures: bool = true
@export var fallback_font_size: int = 24

signal animation_completed

@onready var reel1 = $Reels/Reel1
@onready var reel2 = $Reels/Reel2
@onready var reel3 = $Reels/Reel3

var loaded_textures: Array[Texture2D] = []
var final_symbols: Array[int] = [0, 0, 0]
var spin_tweens: Array[Tween] = []
var controller: SlotMachineController

func _ready():
	controller = get_parent() as SlotMachineController
	preload_symbol_textures()

func preload_symbol_textures():
	loaded_textures.clear()
	
	for i in range(reel_symbols.size()):
		var symbol_path = reel_symbols[i]
		var texture: Texture2D = null
		
		if ResourceLoader.exists(symbol_path):
			texture = load(symbol_path) as Texture2D
		
		if texture:
			loaded_textures.append(texture)
		else:
			loaded_textures.append(null)
			push_warning("Failed to load texture: " + symbol_path)

func initialize_reels():
	var reels = [reel1, reel2, reel3]
	
	for i in range(reels.size()):
		if reels[i]:
			var random_symbol = randi() % reel_symbols.size()
			final_symbols[i] = random_symbol
			display_symbol_on_reel(reels[i], random_symbol)

func start_spin_animation(symbols: Array[int]):
	final_symbols = symbols
	clear_spin_tweens()
	start_kickup_animation()

func start_kickup_animation():
	var reels = [reel1, reel2, reel3]
	
	for i in range(reels.size()):
		if not reels[i]:
			continue
		
		var reel = reels[i]
		
		if reel.get_child_count() > 0:
			var symbol_node = reel.get_child(0)
			var kickup_tween = create_tween()
			spin_tweens.append(kickup_tween)
			
			var original_pos = Vector2.ZERO
			var kick_target = Vector2(0, -kick_up_distance)
			
			kickup_tween.tween_property(symbol_node, "position", kick_target, kick_up_duration)
			kickup_tween.tween_callback(func(): start_individual_reel_spin(i))

func start_individual_reel_spin(reel_index: int):
	var reels = [reel1, reel2, reel3]
	if reel_index >= reels.size() or not reels[reel_index]:
		return
	
	var reel = reels[reel_index]
	var final_symbol = final_symbols[reel_index]
	
	var spin_tween = create_tween()
	spin_tweens.append(spin_tween)
	
	var spin_duration = base_spin_duration + (reel_index * spin_stagger_delay)
	
	spin_tween.tween_method(
		func(progress): animate_symbol_spin(reel, progress, final_symbol),
		0.0,
		1.0,
		spin_duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	
	if reel_index == reels.size() - 1:
		spin_tween.tween_callback(complete_spin)

func animate_symbol_spin(reel: Control, progress: float, final_symbol: int):
	if not reel:
		return
	
	var total_angle = progress * 360.0 * total_rotations
	var symbol_count = reel_symbols.size()
	var current_symbol_index = int(total_angle / (360.0 / symbol_count)) % symbol_count
	
	if progress > 0.8:
		current_symbol_index = final_symbol
	
	clear_reel_children(reel)
	
	var symbol_y_pos = lerp(-kick_up_distance, 0.0, progress)
	
	if use_textures and current_symbol_index < loaded_textures.size() and loaded_textures[current_symbol_index]:
		create_texture_symbol(reel, current_symbol_index, symbol_y_pos, progress, total_angle)
	else:
		create_text_symbol(reel, current_symbol_index, symbol_y_pos, progress, total_angle)

func create_texture_symbol(reel: Control, symbol_index: int, y_pos: float, progress: float, angle: float):
	var texture_rect = TextureRect.new()
	texture_rect.texture = loaded_textures[symbol_index]
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.position = Vector2(0, y_pos)
	texture_rect.size = reel.size
	
	if enable_wobble and progress < 0.8:
		var wobble_amount = (1.0 - progress) * wobble_intensity
		texture_rect.rotation = deg_to_rad(sin(angle * 0.1) * wobble_amount)
	
	reel.add_child(texture_rect)

func create_text_symbol(reel: Control, symbol_index: int, y_pos: float, progress: float, angle: float):
	var label = Label.new()
	
	if symbol_index < reel_symbol_names.size():
		label.text = reel_symbol_names[symbol_index]
	else:
		label.text = "?"
	
	label.add_theme_font_size_override("font_size", fallback_font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, y_pos)
	label.size = reel.size
	
	if enable_wobble and progress < 0.8:
		var wobble_amount = (1.0 - progress) * wobble_intensity
		label.rotation = deg_to_rad(sin(angle * 0.1) * wobble_amount)
	
	reel.add_child(label)

func clear_reel_children(reel: Control):
	for child in reel.get_children():
		child.queue_free()

func display_symbol_on_reel(reel_control: Control, symbol_index: int):
	if not reel_control:
		return
	
	clear_reel_children(reel_control)
	await get_tree().process_frame
	
	if use_textures and symbol_index < loaded_textures.size() and loaded_textures[symbol_index]:
		var texture_rect = TextureRect.new()
		texture_rect.texture = loaded_textures[symbol_index]
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.position = Vector2.ZERO
		texture_rect.size = reel_control.size
		reel_control.add_child(texture_rect)
	else:
		var label = Label.new()
		if symbol_index < reel_symbol_names.size():
			label.text = reel_symbol_names[symbol_index]
		else:
			label.text = "?"
		
		label.add_theme_font_size_override("font_size", fallback_font_size)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2.ZERO
		label.size = reel_control.size
		reel_control.add_child(label)

func complete_spin():
	var reels = [reel1, reel2, reel3]
	for i in range(reels.size()):
		if reels[i]:
			display_symbol_on_reel(reels[i], final_symbols[i])
	
	animation_completed.emit()

func clear_spin_tweens():
	for tween in spin_tweens:
		if tween and tween.is_valid():
			tween.kill()
	spin_tweens.clear()

func _exit_tree():
	clear_spin_tweens()

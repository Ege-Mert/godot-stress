extends Control
class_name SlotMachineReels

signal animation_completed
signal reel_stopped(reel_index: int)
signal spin_started

@export_group("Reel Strips")
@export var reel_strip_1: SlotMachineSymbolStrip
@export var reel_strip_2: SlotMachineSymbolStrip
@export var reel_strip_3: SlotMachineSymbolStrip

@export_group("Spin Settings")
@export var spin_delay_between_reels: float = 0.2
@export var auto_stop_after: float = 4.0
@export var use_different_strips: bool = false

@onready var reel1 = $Reels/Reel1
@onready var reel2 = $Reels/Reel2
@onready var reel3 = $Reels/Reel3

var config: SlotMachineConfig
var reel_components: Array[SlotMachineReel] = []
var reels_stopped_count: int = 0
var symbol_textures: Array[Texture2D] = []
var is_spinning: bool = false

func setup_with_config(slot_config: SlotMachineConfig):
	config = slot_config
	_prepare_symbol_textures()
	_setup_reels()

func _ready():
	pass

func _prepare_symbol_textures():
	symbol_textures.clear()
	if not config:
		return

	for symbol in config.symbols:
		if symbol and symbol.symbol_texture:
			symbol_textures.append(symbol.symbol_texture)
		else:
			symbol_textures.append(null)

func _setup_reels():
	# Clear old reel components
	for comp in reel_components:
		if comp:
			comp.queue_free()
	reel_components.clear()

	# Create new reel components
	var reel_containers = [reel1, reel2, reel3]
	var strips = [reel_strip_1, reel_strip_2, reel_strip_3]

	for i in range(reel_containers.size()):
		if not reel_containers[i]:
			continue

		# Create physics-based reel
		var reel_comp = SlotMachineReel.new()
		reel_comp.name = "ReelComponent"
		reel_comp.size = reel_containers[i].size
		reel_comp.reel_index = i

		# Assign strip (use same strip for all if not using different)
		if use_different_strips and strips[i]:
			reel_comp.reel_strip = strips[i]
		elif reel_strip_1:
			reel_comp.reel_strip = reel_strip_1
		else:
			# Create default strip if none provided
			var default_strip = SlotMachineSymbolStrip.create_default_strip()
			reel_comp.reel_strip = default_strip
			if i == 0:  # Store for others to use
				reel_strip_1 = default_strip

		# Clear container and add component
		for child in reel_containers[i].get_children():
			child.queue_free()

		reel_containers[i].add_child(reel_comp)
		reel_comp.setup_with_config(config, symbol_textures)

		# Connect signals
		reel_comp.reel_stopped.connect(_on_reel_stopped.bind(i))

		reel_components.append(reel_comp)

func initialize_reels():
	# Set random starting positions for each reel
	for reel in reel_components:
		if reel and reel.reel_strip:
			var random_pos = randf() * reel.reel_strip.get_strip_length()
			reel.set_reel_position(random_pos)

func start_spin():
	if is_spinning:
		return

	is_spinning = true
	reels_stopped_count = 0
	spin_started.emit()

	# Start all reels at the same time
	for reel in reel_components:
		if reel:
			reel.start_spin()

	# Schedule sequential stops with delays
	for i in range(reel_components.size()):
		var stop_delay = 2.0 + (i * 1.0)  # First reel stops after 2s, then +1s for each
		get_tree().create_timer(stop_delay).timeout.connect(func():
			if i < reel_components.size() and reel_components[i]:
				reel_components[i].request_stop()
		)

	# Auto-stop timer as safety
	get_tree().create_timer(auto_stop_after + 3.0).timeout.connect(func():
		for reel in reel_components:
			if reel and reel.is_spinning:
				reel.force_stop()
	)

func stop_reels():
	# Let reels stop naturally
	# The physics will handle the deceleration
	pass

func _on_reel_stopped(_final_position: float, _visible_symbols: Array[int], reel_index: int):
	reel_stopped.emit(reel_index)

	reels_stopped_count += 1
	if reels_stopped_count >= reel_components.size():
		is_spinning = false
		animation_completed.emit()

func get_current_symbols() -> Array[int]:
	var symbols: Array[int] = []
	for reel in reel_components:
		if reel:
			symbols.append(reel.get_current_symbol())
		else:
			symbols.append(0)
	return symbols

func get_final_symbols() -> Array[int]:
	var symbols: Array[int] = []
	for i in range(reel_components.size()):
		var reel = reel_components[i]
		var symbol = reel.get_current_symbol()
		var reel_position = reel.get_reel_position()  # Changed from 'position' to 'reel_position'
		print("DEBUG Reel ", i, ": Position=", reel_position, " Symbol=", symbol)
		symbols.append(symbol)
	return symbols

func highlight_winning_symbols(result: Dictionary):
	if not config or not config.show_win_highlights or result.winning_symbol == -1:
		return

	var winning_symbol_data = config.get_symbol_by_index(result.winning_symbol)
	if not winning_symbol_data:
		return

	# Clear any existing highlights first
	clear_all_highlights()

	# Highlight only the winning positions
	for pos in result.winning_positions:
		if pos < reel_components.size() and reel_components[pos]:
			highlight_reel(reel_components[pos], Color.YELLOW)
			add_win_border_effect(reel_components[pos])

func clear_all_highlights():
	for reel in reel_components:
		if reel:
			reel.modulate = Color.WHITE
			# Remove any existing border effects
			var borders = reel.get_children().filter(func(child):
				return child.name == "WinBorder"
			)
			for border in borders:
				border.queue_free()

func highlight_reel(reel: SlotMachineReel, highlight_color: Color):
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(reel, "modulate", highlight_color, 0.3)
	tween.tween_property(reel, "modulate", Color.WHITE, 0.3)

	# Auto-clear after highlight duration
	get_tree().create_timer(config.highlight_duration).timeout.connect(func():
		if tween.is_valid():
			tween.kill()
		reel.modulate = Color.WHITE
	)

func add_win_border_effect(reel: SlotMachineReel):
	# Create a colorful border around winning reels
	var border = ColorRect.new()
	border.name = "WinBorder"
	border.color = Color.YELLOW
	border.size = reel.size + Vector2(8, 8)
	border.position = Vector2(-4, -4)
	border.z_index = -1
	reel.add_child(border)

	# Animate the border
	var border_tween = create_tween()
	border_tween.set_loops()
	border_tween.tween_property(border, "color", Color.RED, 0.4)
	border_tween.tween_property(border, "color", Color.YELLOW, 0.4)

	# Remove border after highlight duration
	get_tree().create_timer(config.highlight_duration).timeout.connect(func():
		if border_tween.is_valid():
			border_tween.kill()
		border.queue_free()
	)

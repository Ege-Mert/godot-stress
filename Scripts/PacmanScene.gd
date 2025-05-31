extends Node2D

# Player and movement
@onready var player = $Player
@onready var tilemap_layer = $TileMapLayer  # Updated for Godot 4.4
@onready var exit_gates = $ExitGates
@onready var coin_container = get_node_or_null("Coins")  # May not exist
@onready var ghost_container = $Ghosts

# UI
@onready var ui = $UI
@onready var coins_collected_label = $UI/CoinsLabel
@onready var exit_prompt_label = $UI/ExitPrompt
@onready var warning_label = $UI/WarningLabel

# INSPECTOR CONFIGURABLE VALUES
@export_group("Level Settings")
@export var player_start_pos: Vector2 = Vector2(1, 1) ## Player starting grid position
@export var tile_size: int = 32 ## Size of each grid tile in pixels
@export var use_bounds_checking: bool = false ## Enable/disable map boundary collision
@export var map_width: int = 20 ## Map width in tiles (only used if bounds checking enabled)
@export var map_height: int = 20 ## Map height in tiles (only used if bounds checking enabled)

@export_group("Player Movement")
@export var base_move_speed: float = 150.0 ## Base player movement speed
@export var movement_smoothness: float = 2.0 ## How close player needs to be to target before stopping

@export_group("Ghost Settings")
@export var enable_normal_ghosts: bool = true ## Spawn normal ghosts
@export var initial_ghost_count: int = 2 ## Number of ghosts at start (non-first game)
@export var ghost_spawn_positions: Array[Vector2] = [Vector2(8, 6), Vector2(9, 7)] ## Initial ghost spawn positions
@export var additional_ghost_spawn_delay: float = 30.0 ## Seconds between additional ghost spawns
@export var ghost_spawn_acceleration: float = 2.0 ## How much faster ghosts spawn over time
@export var min_ghost_spawn_delay: float = 10.0 ## Minimum delay between ghost spawns

@export_group("Coin Collection")
@export var coins_needed_for_exit: int = 5 ## Minimum coins to unlock exit
@export var coins_lost_on_death: int = 3 ## Coins lost when caught by normal ghost

@export_group("Special Events")
@export var enable_wall_phasing_ghost: bool = true ## Enable special wall-phasing ghost
@export var wall_ghost_spawn_position: Vector2 = Vector2(5, 5) ## Where wall-phasing ghost spawns
@export var coins_to_trigger_wall_ghost: int = 10 ## Coins needed to spawn wall-phasing ghost (first game)

@export_group("Audio Settings")
@export var enable_audio: bool = true ## Enable/disable all audio

# Game state variables
var coins_collected: int = 0
var exit_unlocked: bool = false
var game_active: bool = true
var wall_phasing_ghost_spawned: bool = false

# Movement variables
var move_speed: float = 150.0  # Will be modified by upgrades
var player_direction: Vector2 = Vector2.ZERO
var next_player_direction: Vector2 = Vector2.ZERO  # Input buffer
var player_grid_pos: Vector2
var target_pos: Vector2
var player_is_moving: bool = false
var movement_precision: float = 2.0

# Ghost management
var normal_ghosts: Array = []
var wall_phasing_ghost = null
var ghost_spawn_timer: float = 0.0
var ghost_spawn_interval: float = 30.0

# Audio references
@onready var audio_coin_pickup = $Audio/CoinPickup
@onready var audio_ghost_spawn = $Audio/GhostSpawn
@onready var audio_death = $Audio/Death
@onready var audio_gate_open = $Audio/GateOpen

func setup_screen_adaptation():
	# Get the viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	var game_area_size = Vector2(640, 640)  # Approximate game area size
	
	# Calculate scale to fit screen while maintaining aspect ratio
	var scale_factor = min(
		viewport_size.x / game_area_size.x,
		viewport_size.y / game_area_size.y
	) * 0.9  # 90% of screen to leave some padding
	
	# Apply scale to the entire scene
	scale = Vector2(scale_factor, scale_factor)
	
	# Center the scaled content
	var scaled_size = game_area_size * scale_factor
	position = (viewport_size - scaled_size) / 2
	
	print("Screen adaptation: viewport=", viewport_size, " scale=", scale_factor, " position=", position)

func _ready():
	# Connect to GameManager
	GameManager.pacman_exit_available.connect(_on_exit_available)
	
	# Center and scale the level for different screen sizes
	setup_screen_adaptation()
	
	# Initialize game
	setup_game()
	
	# Start GameManager pacman stage
	GameManager.start_pacman_stage()

func setup_game():
	# Apply upgrades before setting up the game
	apply_upgrades()
	
	# Set initial values from inspector
	ghost_spawn_interval = additional_ghost_spawn_delay
	
	# Set player starting position
	player_grid_pos = player_start_pos
	player.position = grid_to_world(player_grid_pos)
	target_pos = player.position
	
	# Handle exit gates based on game state
	if GameManager.is_first_pacman:
		# Hide gates completely in tutorial
		hide_exit_gates()
	else:
		# Close gates initially in normal games
		close_exit_gates()
	
	# Connect existing coins in the scene (manually placed)
	connect_existing_coins()
	
	# Spawn initial ghosts if enabled
	if enable_normal_ghosts:
		spawn_initial_ghosts()
	
	# Update UI
	update_ui()

func apply_upgrades():
	# Apply movement speed upgrade
	var speed_upgrade = GameManager.pacman_upgrades.movement_speed
	move_speed = base_move_speed + (speed_upgrade * 30.0)  # +30 speed per level
	
	# Apply other upgrades as needed
	print("Applied upgrades - Move speed: ", move_speed)

func connect_existing_coins():
	# Connect signals for coins that are already placed in the scene
	# Check both direct children and in coin_container
	var all_coins = []
	
	# Get coins from coin_container if it exists
	if coin_container:
		all_coins.append_array(coin_container.get_children())
	
	# Also check direct children of scene (instances placed directly)
	for child in get_children():
		if child.name.begins_with("Coin"):
			all_coins.append(child)
	
	print("Found ", all_coins.size(), " coins to connect")
	
	for coin in all_coins:
		if coin.has_signal("picked_up") and not coin.picked_up.is_connected(_on_coin_picked_up):
			coin.picked_up.connect(_on_coin_picked_up)
			print("Connected coin at position: ", coin.position)
		else:
			print("Coin already connected or no signal: ", coin.name)

func spawn_initial_ghosts():
	# Don't spawn normal ghosts in first pacman game
	if GameManager.is_first_pacman:
		return
	
	# Spawn ghosts at configured positions
	var positions_to_use = ghost_spawn_positions.slice(0, initial_ghost_count)
	
	for pos in positions_to_use:
		spawn_normal_ghost(pos)

func spawn_normal_ghost(grid_pos: Vector2):
	var ghost = preload("res://Scenes/Ghost.tscn").instantiate()
	ghost.position = grid_to_world(grid_pos)
	ghost.setup_normal_ai(tilemap_layer)
	ghost_container.add_child(ghost)
	normal_ghosts.append(ghost)
	
	# Connect death signal
	ghost.player_caught.connect(_on_player_caught)

func spawn_wall_phasing_ghost():
	if wall_phasing_ghost_spawned or not enable_wall_phasing_ghost:
		return
	
	print("Spawning wall-phasing ghost...")
	wall_phasing_ghost_spawned = true
	wall_phasing_ghost = preload("res://Scenes/WallPhasingGhost.tscn").instantiate()
	wall_phasing_ghost.position = grid_to_world(wall_ghost_spawn_position)
	wall_phasing_ghost.setup_phasing_ai(player)
	ghost_container.add_child(wall_phasing_ghost)
	
	# Connect death signal
	if wall_phasing_ghost.has_signal("player_caught"):
		wall_phasing_ghost.player_caught.connect(_on_player_caught_by_phasing_ghost)
		print("Connected wall-phasing ghost signal")
	else:
		print("WARNING: Wall-phasing ghost has no player_caught signal!")
	
	# Visual/audio feedback
	if enable_audio and audio_ghost_spawn and audio_ghost_spawn.stream:
		audio_ghost_spawn.play()
	elif enable_audio and audio_ghost_spawn:
		print("Warning: audio_ghost_spawn has no stream")
	
	warning_label.text = "SPECIAL DEBT COLLECTOR SPAWNED!"
	warning_label.modulate = Color.RED
	
	await get_tree().create_timer(3.0).timeout
	warning_label.text = ""

func _process(delta):
	if not game_active:
		return
	
	handle_input()
	update_player_movement(delta)
	
	if enable_normal_ghosts:
		update_ghost_spawning(delta)

func handle_input():
	# Capture input for direction buffer
	var input_direction = Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		input_direction = Vector2(0, -1)
	elif Input.is_action_pressed("ui_down"):
		input_direction = Vector2(0, 1)
	elif Input.is_action_pressed("ui_left"):
		input_direction = Vector2(-1, 0)
	elif Input.is_action_pressed("ui_right"):
		input_direction = Vector2(1, 0)
	
	# Store input for next movement opportunity
	if input_direction != Vector2.ZERO:
		next_player_direction = input_direction
	
	# Try to start movement immediately if not moving
	if not player_is_moving and next_player_direction != Vector2.ZERO:
		try_start_movement()

func try_start_movement():
	# Try to start movement in the buffered direction
	if can_move_to(player_grid_pos + next_player_direction):
		player_direction = next_player_direction
		target_pos = grid_to_world(player_grid_pos + player_direction)
		player_is_moving = true
		next_player_direction = Vector2.ZERO  # Clear buffer

func update_player_movement(delta):
	if not player_is_moving:
		return
	
	# Move towards target with constant speed
	var movement_distance = move_speed * delta
	player.position = player.position.move_toward(target_pos, movement_distance)
	
	# Check if reached target
	if player.position.distance_to(target_pos) <= movement_precision:
		# Snap to exact grid position
		player_grid_pos += player_direction
		player.position = grid_to_world(player_grid_pos)
		player_is_moving = false
		
		# Try to continue movement in current direction or use buffered input
		if next_player_direction != Vector2.ZERO:
			try_start_movement()  # Try buffered direction first
		elif can_move_to(player_grid_pos + player_direction):
			# Continue in same direction
			target_pos = grid_to_world(player_grid_pos + player_direction)
			player_is_moving = true
		else:
			# Stop movement
			player_direction = Vector2.ZERO
	
	# Collect coins at current position and nearby (magnetism)
	var grid_pos = world_to_grid(player.position)
	check_coin_collection(grid_pos)
	
	# Check for exit gate collision (only if exit is unlocked and gates visible)
	if exit_unlocked and not GameManager.is_first_pacman:
		check_gate_collision()
	
	# Also check adjacent positions for more forgiving coin collection
	var nearby_positions = [
		grid_pos + Vector2(1, 0), grid_pos + Vector2(-1, 0),
		grid_pos + Vector2(0, 1), grid_pos + Vector2(0, -1)
	]
	for pos in nearby_positions:
		check_coin_collection(pos)
	
	# Apply coin magnetism upgrade
	var magnetism_level = GameManager.pacman_upgrades.coin_magnetism
	if magnetism_level > 0:
		apply_coin_magnetism(magnetism_level)

func update_ghost_spawning(delta):
	# Add more ghosts over time (stress mechanic)
	if coins_collected > coins_needed_for_exit:  # Only after minimum collection
		ghost_spawn_timer += delta
		if ghost_spawn_timer >= ghost_spawn_interval:
			ghost_spawn_timer = 0.0
			spawn_additional_ghost()

func spawn_additional_ghost():
	# Use configured ghost spawn positions
	if ghost_spawn_positions.size() == 0:
		return
	
	# Find position farthest from player
	var best_pos = ghost_spawn_positions[0]
	var max_distance = 0.0
	
	for pos in ghost_spawn_positions:
		var distance = pos.distance_to(player_grid_pos)
		if distance > max_distance:
			max_distance = distance
			best_pos = pos
	
	spawn_normal_ghost(best_pos)
	
	# Reduce spawn interval (increasing pressure)
	ghost_spawn_interval = max(min_ghost_spawn_delay, ghost_spawn_interval - ghost_spawn_acceleration)

func can_move_to(grid_pos: Vector2) -> bool:
	# Check configured bounds if enabled
	if use_bounds_checking:
		if grid_pos.x < 0 or grid_pos.x >= map_width or grid_pos.y < 0 or grid_pos.y >= map_height:
			return false
	
	# Check tilemap for walls
	var tile_source_id = tilemap_layer.get_cell_source_id(Vector2i(grid_pos.x, grid_pos.y))
	return tile_source_id == -1  # -1 = empty/walkable, 0+ = wall

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return grid_pos * float(tile_size) + Vector2(float(tile_size)/2.0, float(tile_size)/2.0)

func world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(
		int(round(world_pos.x / float(tile_size))), 
		int(round(world_pos.y / float(tile_size)))
	)

func apply_coin_magnetism(magnetism_level: int):
	# Collect coins within magnetism range
	var magnetism_range = magnetism_level  # 1 level = 1 tile radius
	var player_grid = world_to_grid(player.position)
	
	# Check surrounding tiles for coins
	for x_offset in range(-magnetism_range, magnetism_range + 1):
		for y_offset in range(-magnetism_range, magnetism_range + 1):
			var check_pos = player_grid + Vector2(x_offset, y_offset)
			check_coin_collection(check_pos)

func check_coin_collection(grid_pos: Vector2):
	# Check if there's a coin at this position
	# Look in coin_container first
	if coin_container:
		for coin in coin_container.get_children():
			var coin_grid_pos = world_to_grid(coin.position)
			if coin_grid_pos == grid_pos and not coin.is_collected:
				coin.collect()
				return
	
	# Also check direct children for coins
	for child in get_children():
		if child.name.begins_with("Coin") and not child.is_collected:
			var coin_grid_pos = world_to_grid(child.position)
			if coin_grid_pos == grid_pos:
				child.collect()
				return

func check_gate_collision():
	"""Check if player is colliding with any exit gate"""
	if not exit_gates:
		return
	
	var player_pos = player.position
	var collision_distance = 40.0  # How close player needs to be to gate
	
	for gate in exit_gates.get_children():
		if gate.visible:  # Only check visible gates
			var distance = player_pos.distance_to(gate.position)
			if distance < collision_distance:
				print("Player touched exit gate - exiting!")
				exit_pacman_stage()
				return

func _on_coin_picked_up():
	coins_collected += 1
	
	if enable_audio and audio_coin_pickup and audio_coin_pickup.stream:
		audio_coin_pickup.play()
	elif enable_audio and audio_coin_pickup:
		print("Warning: audio_coin_pickup has no stream")
	elif enable_audio:
		print("Warning: audio_coin_pickup node not found")
	
	# Let GameManager handle the coin collection
	var _trigger_phasing_ghost = GameManager.collect_pacman_coin()  # Prefixed with _
	
	# Check if we should spawn wall-phasing ghost based on configured trigger
	if (GameManager.is_first_pacman and 
		coins_collected >= coins_to_trigger_wall_ghost and 
		enable_wall_phasing_ghost and 
		not wall_phasing_ghost_spawned):
		spawn_wall_phasing_ghost()
	
	update_ui()

func _on_exit_available():
	# Don't show exit in first pacman game (gates are hidden)
	if GameManager.is_first_pacman:
		return
	
	exit_unlocked = true
	open_exit_gates()
	
	if enable_audio and audio_gate_open and audio_gate_open.stream:
		audio_gate_open.play()
	elif enable_audio and audio_gate_open:
		print("Warning: audio_gate_open has no stream")
	
	exit_prompt_label.text = "EXIT GATES OPENED! Walk into a gate to exit the maze."
	exit_prompt_label.modulate = Color.GREEN

func open_exit_gates():
	# Animate gates opening
	var tween = create_tween()
	for gate in exit_gates.get_children():
		tween.parallel().tween_property(gate, "modulate:a", 0.5, 0.5)

func close_exit_gates():
	for gate in exit_gates.get_children():
		gate.modulate.a = 1.0
		gate.visible = true

func hide_exit_gates():
	"""Completely hide exit gates during tutorial"""
	for gate in exit_gates.get_children():
		gate.visible = false

func _on_player_caught():
	# Normal ghost caught player - lose coins and respawn
	if enable_audio and audio_death and audio_death.stream:
		audio_death.play()
	elif enable_audio and audio_death:
		print("Warning: audio_death has no stream")
	
	coins_collected = max(0, coins_collected - coins_lost_on_death)
	player_grid_pos = player_start_pos
	player.position = grid_to_world(player_grid_pos)
	target_pos = player.position
	player_direction = Vector2.ZERO
	
	update_ui()

func _on_player_caught_by_phasing_ghost():
	# Tutorial debt trap mechanic (first pacman only)
	print("🛑 SIGNAL RECEIVED: Player caught by wall-phasing ghost!")
	
	if GameManager.is_first_pacman:
		print("Processing tutorial debt trap...")
		GameManager.trigger_debt_trap()
		
		# Show debt trap message
		if warning_label:
			warning_label.text = "TUTORIAL DEBT TRAP! DEBT INCREASED BY $500,000!"
			warning_label.modulate = Color.RED
			print("Debt trap message displayed")
		
		# Screen effects
		var screen_flash = create_tween()
		screen_flash.tween_property(get_viewport(), "canvas_transform", 
			get_viewport().canvas_transform.scaled(Vector2(1.1, 1.1)), 0.1)
		screen_flash.tween_property(get_viewport(), "canvas_transform", 
			Transform2D.IDENTITY, 0.1)
		
		# Disable game to prevent further input
		game_active = false
		print("Game disabled, starting countdown...")
		
		# Wait for message to be read
		print("Waiting 3 seconds before transition...")
		await get_tree().create_timer(3.0).timeout
		
		# Return coins to GameManager and transition
		print("Timer complete, transitioning back to slot machine...")
		var _coins_earned = GameManager.exit_pacman_stage()
		print("GameManager.exit_pacman_stage() completed")
		
		# Small delay to ensure everything is processed
		await get_tree().process_frame
		print("About to change scene...")
		get_tree().change_scene_to_file("res://Scenes/SlotMachine.tscn")
		print("Scene change initiated")
	else:
		print("Not first pacman - normal death")
		# Normal death in subsequent games
		_on_player_caught()

func exit_pacman_stage():
	if not game_active:
		return
	
	game_active = false
	
	# Return coins to GameManager
	var _coins_earned = GameManager.exit_pacman_stage()
	
	# Transition back to slot machine
	get_tree().change_scene_to_file("res://Scenes/SlotMachine.tscn")

func update_ui():
	coins_collected_label.text = "Coins Collected: " + str(coins_collected)
	
	if exit_unlocked:
		coins_collected_label.text += " (Exit Available!)"
		coins_collected_label.modulate = Color.GREEN
	elif coins_collected >= coins_needed_for_exit - 1:
		coins_collected_label.text += " (Almost there!)"
		coins_collected_label.modulate = Color.YELLOW
	else:
		coins_collected_label.modulate = Color.WHITE

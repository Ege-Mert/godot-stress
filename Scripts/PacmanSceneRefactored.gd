extends Node2D

# Refactored PacmanScene - Main coordinator that orchestrates all subsystems

# Component references
var player_controller: PacmanPlayer
var ghost_manager: PacmanGhostManager
var coin_manager: PacmanCoinManager
var game_state: PacmanGameState
var ui_manager: PacmanUI
var audio_manager: PacmanAudio
var utility: PacmanUtility

# Node references
@onready var player = $Player
@onready var tilemap_layer = $TileMapLayer
@onready var exit_gates = $ExitGates
@onready var coin_container = get_node_or_null("Coins")
@onready var ghost_container = $Ghosts

# UI references
@onready var ui = $UI
@onready var coins_collected_label = $UI/CoinsLabel
@onready var exit_prompt_label = $UI/ExitPrompt
@onready var warning_label = $UI/WarningLabel

# Audio references
@onready var audio_coin_pickup = $Audio/CoinPickup
@onready var audio_ghost_spawn = $Audio/GhostSpawn
@onready var audio_death = $Audio/Death
@onready var audio_gate_open = $Audio/GateOpen

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

func setup_screen_adaptation():
	# Get the actual tilemap bounds instead of hardcoded values
	var tilemap_rect = tilemap_layer.get_used_rect()
	var actual_game_size = Vector2(
		tilemap_rect.size.x * tile_size,
		tilemap_rect.size.y * tile_size
	)
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate scale to fit screen while maintaining aspect ratio
	var scale_factor = min(
		viewport_size.x / actual_game_size.x,
		viewport_size.y / actual_game_size.y
	) * 0.9  # 90% of screen to leave some padding
	
	# Apply scale to the entire scene
	scale = Vector2(scale_factor, scale_factor)
	
	# Center based on actual tilemap position
	var tilemap_world_pos = Vector2(
		tilemap_rect.position.x * tile_size,
		tilemap_rect.position.y * tile_size
	)
	
	var scaled_size = actual_game_size * scale_factor
	position = (viewport_size - scaled_size) / 2 - tilemap_world_pos * scale_factor
	
	print("Screen adaptation: tilemap_rect=", tilemap_rect, " actual_size=", actual_game_size, " scale=", scale_factor, " position=", position)

func _ready():
	# Wait one frame to ensure everything is properly loaded on web
	await get_tree().process_frame
	
	# Verify critical nodes exist before proceeding
	if not verify_scene_nodes():
		push_error("Critical scene nodes missing! Cannot initialize Pacman scene.")
		return
	
	# Connect to GameManager
	GameManager.pacman_exit_available.connect(_on_exit_available)
	
	# Check and fix tilemap issues first
	if tilemap_layer:
		debug_tilemap_issues()
	
	# Initialize all components
	initialize_components()
	
	# Setup the game
	setup_game()
	
	# Start GameManager pacman stage
	GameManager.start_pacman_stage()

func verify_scene_nodes() -> bool:
	# Check for critical nodes and initialize them if @onready failed
	if not player:
		player = get_node_or_null("Player")
		if not player:
			print("ERROR: Player node not found! Attempting to create backup player...")
			# Try to create a backup player as last resort
			if create_backup_player():
				print("Backup player created successfully!")
			else:
				print("Failed to create backup player!")
				return false
	
	if not tilemap_layer:
		tilemap_layer = get_node_or_null("TileMapLayer")
		if not tilemap_layer:
			print("ERROR: TileMapLayer node not found!")
			return false
	
	if not exit_gates:
		exit_gates = get_node_or_null("ExitGates")
		if not exit_gates:
			print("ERROR: ExitGates node not found!")
			return false
	
	if not ghost_container:
		ghost_container = get_node_or_null("Ghosts")
		if not ghost_container:
			print("ERROR: Ghosts container not found!")
			return false
	
	# UI nodes
	if not ui:
		ui = get_node_or_null("UI")
		if not ui:
			print("ERROR: UI node not found!")
			return false
	
	if not coins_collected_label:
		coins_collected_label = get_node_or_null("UI/CoinsLabel")
		if not coins_collected_label:
			print("ERROR: CoinsLabel not found!")
			return false
	
	if not exit_prompt_label:
		exit_prompt_label = get_node_or_null("UI/ExitPrompt")
		if not exit_prompt_label:
			print("ERROR: ExitPrompt not found!")
			return false
	
	if not warning_label:
		warning_label = get_node_or_null("UI/WarningLabel")
		if not warning_label:
			print("ERROR: WarningLabel not found!")
			return false
	
	# Audio nodes
	if not audio_coin_pickup:
		audio_coin_pickup = get_node_or_null("Audio/CoinPickup")
		if not audio_coin_pickup:
			print("WARNING: Audio/CoinPickup not found!")
	
	if not audio_ghost_spawn:
		audio_ghost_spawn = get_node_or_null("Audio/GhostSpawn")
		if not audio_ghost_spawn:
			print("WARNING: Audio/GhostSpawn not found!")
	
	if not audio_death:
		audio_death = get_node_or_null("Audio/Death")
		if not audio_death:
			print("WARNING: Audio/Death not found!")
	
	if not audio_gate_open:
		audio_gate_open = get_node_or_null("Audio/GateOpen")
		if not audio_gate_open:
			print("WARNING: Audio/GateOpen not found!")
	
	# Optional: coin_container might not exist
	if not coin_container:
		coin_container = get_node_or_null("Coins")
		# This is optional, so don't fail if it doesn't exist
	
	print("Scene node verification completed successfully!")
	return true

func create_backup_player() -> bool:
	# Create a backup player node if the original failed to load
	player = CharacterBody2D.new()
	player.name = "Player"
	player.add_to_group("player")
	
	# Add sprite
	var sprite = Sprite2D.new()
	sprite.modulate = Color.YELLOW
	sprite.scale = Vector2(0.2, 0.2)
	# Try to load the player texture
	var texture = load("res://Sprites/pacman-characters_0002_Layer-11.png")
	if texture:
		sprite.texture = texture
	player.add_child(sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	player.add_child(collision)
	
	# Set initial position
	player.position = Vector2(984, 736)  # Default position from scene
	
	# Add to scene
	add_child(player)
	
	print("Backup player created at position: ", player.position)
	return true

func initialize_components():
	# Create utility component first (other components depend on it)
	utility = PacmanUtility.new()
	utility.tile_size = tile_size
	utility.use_bounds_checking = use_bounds_checking
	utility.map_width = map_width
	utility.map_height = map_height
	add_child(utility)
	
	# Initialize player controller
	player_controller = PacmanPlayer.new()
	player_controller.base_move_speed = base_move_speed
	player_controller.movement_precision = movement_smoothness
	add_child(player_controller)
	
	# Verify player node exists before initializing
	if not player:
		push_error("Player node is null! Cannot initialize player controller.")
		return
	
	if not tilemap_layer:
		push_error("TileMapLayer is null! Cannot initialize player controller.")
		return
	
	if not utility:
		push_error("Utility is null! Cannot initialize player controller.")
		return
	
	player_controller.initialize(player, tilemap_layer, utility)
	print("Player controller initialized successfully with player at: ", player.position)
	
	# Initialize ghost manager
	ghost_manager = PacmanGhostManager.new()
	ghost_manager.enable_normal_ghosts = enable_normal_ghosts
	ghost_manager.initial_ghost_count = initial_ghost_count
	ghost_manager.ghost_spawn_positions = ghost_spawn_positions
	ghost_manager.additional_ghost_spawn_delay = additional_ghost_spawn_delay
	ghost_manager.ghost_spawn_acceleration = ghost_spawn_acceleration
	ghost_manager.min_ghost_spawn_delay = min_ghost_spawn_delay
	ghost_manager.enable_wall_phasing_ghost = enable_wall_phasing_ghost
	ghost_manager.wall_ghost_spawn_position = wall_ghost_spawn_position
	add_child(ghost_manager)
	ghost_manager.initialize(tilemap_layer, ghost_container, player, utility)
	
	# Initialize coin manager
	coin_manager = PacmanCoinManager.new()
	coin_manager.coins_needed_for_exit = coins_needed_for_exit
	coin_manager.coins_lost_on_death = coins_lost_on_death
	add_child(coin_manager)
	coin_manager.initialize(coin_container, self, utility)
	
	# Initialize game state
	game_state = PacmanGameState.new()
	game_state.coins_to_trigger_wall_ghost = coins_to_trigger_wall_ghost
	add_child(game_state)
	game_state.initialize(exit_gates, player_start_pos, utility)
	
	# Initialize UI manager
	ui_manager = PacmanUI.new()
	add_child(ui_manager)
	ui_manager.initialize(coins_collected_label, exit_prompt_label, warning_label, coins_needed_for_exit)
	
	# Initialize audio manager
	audio_manager = PacmanAudio.new()
	audio_manager.enable_audio = enable_audio
	add_child(audio_manager)
	audio_manager.initialize(audio_coin_pickup, audio_ghost_spawn, audio_death, audio_gate_open)
	
	# Connect component signals
	connect_component_signals()

func connect_component_signals():
	# Player signals
	player_controller.player_moved.connect(_on_player_moved)
	player_controller.player_reached_target.connect(_on_player_reached_target)
	
	# Ghost manager signals
	ghost_manager.player_caught_by_normal_ghost.connect(_on_normal_ghost_caught_player)
	ghost_manager.player_caught_by_phasing_ghost.connect(_on_phasing_ghost_caught_player)
	ghost_manager.ghost_spawned.connect(_on_ghost_spawned)
	
	# Coin manager signals
	coin_manager.coin_collected.connect(_on_coin_collected)
	
	# Game state signals
	game_state.exit_unlocked.connect(_on_exit_unlocked_state)
	game_state.game_over.connect(_on_game_over)
	game_state.debt_trap_triggered.connect(_on_debt_trap_triggered)
	
	# UI signals
	ui_manager.ui_message_displayed.connect(_on_ui_message_displayed)
	
	# Audio signals
	audio_manager.audio_played.connect(_on_audio_played)

func setup_game():
	# Add web-specific debugging
	if OS.has_feature("web"):
		print("[WEB DEBUG] Setting up Pacman game...")
		print("[WEB DEBUG] Player node: ", player)
		print("[WEB DEBUG] Player position: ", player.position if player else "PLAYER IS NULL")
		print("[WEB DEBUG] Player controller: ", player_controller)
		print("[WEB DEBUG] TileMap layer: ", tilemap_layer)
	
	# Apply upgrades before setting up the game
	apply_upgrades()
	
	# Set player starting position
	if player_controller:
		player_controller.set_starting_position(player_start_pos)
		print("[DEBUG] Player starting position set to: ", player_start_pos)
	else:
		push_error("Cannot set player starting position - player_controller is null!")
		return
	
	# Setup initial game state
	game_state.setup_initial_state()
	
	# Connect existing coins in the scene
	coin_manager.connect_existing_coins()
	
	# Spawn initial ghosts if enabled
	if enable_normal_ghosts:
		ghost_manager.spawn_initial_ghosts()
	
	# Update UI
	update_ui()
	
	# Web-specific final verification
	if OS.has_feature("web"):
		print("[WEB DEBUG] Game setup completed. Final player position: ", player.position if player else "PLAYER IS NULL")

func apply_upgrades():
	# Apply movement speed upgrade
	var speed_upgrade = GameManager.pacman_upgrades.movement_speed
	var speed_bonus = speed_upgrade * 30.0  # +30 speed per level
	player_controller.apply_speed_upgrade(speed_bonus)
	
	print("Applied upgrades - Move speed bonus: ", speed_bonus)

func _process(delta):
	if not game_state.is_game_active():
		return
	
	# Update player
	player_controller.handle_input()
	player_controller.update_movement(delta)
	
	# Update ghost spawning
	if enable_normal_ghosts:
		ghost_manager.update_ghost_spawning(delta, coin_manager.get_coins_collected(), coins_needed_for_exit)

func update_ui():
	ui_manager.update_coins_display(coin_manager.get_coins_collected(), game_state.is_exit_unlocked())

# Signal handlers
func _on_player_moved(new_grid_pos: Vector2):
	# Check for coin collection at new position
	coin_manager.check_coin_collection(new_grid_pos)
	
	# Note: coin_magnetism upgrade was removed - no automatic collection

func _on_player_reached_target():
	# Check for gate collision if exit is available
	if game_state.is_exit_unlocked():
		if game_state.check_gate_collision(player_controller.get_current_world_position()):
			exit_pacman_stage()

func _on_coin_collected(total_coins: int):
	audio_manager.play_coin_pickup()
	
	# Check if we should spawn wall-phasing ghost
	if game_state.should_spawn_phasing_ghost(total_coins):
		ghost_manager.spawn_wall_phasing_ghost()
	
	update_ui()

func _on_normal_ghost_caught_player():
	audio_manager.play_death()
	
	# Reset player position and lose coins
	coin_manager.lose_coins_on_death()
	player_controller.reset_to_spawn(game_state.get_spawn_position())
	
	update_ui()

func _on_phasing_ghost_caught_player():
	game_state.handle_phasing_ghost_caught()

func _on_ghost_spawned(ghost_type: String):
	audio_manager.play_ghost_spawn()
	
	if ghost_type == "wall_phasing":
		ui_manager.show_wall_ghost_warning()

func _on_exit_unlocked_state():
	audio_manager.play_gate_open()
	ui_manager.show_exit_available()

func _on_game_over(reason: String):
	if reason == "exit":
		exit_pacman_stage()

func _on_debt_trap_triggered():
	# Handle tutorial debt trap
	GameManager.trigger_debt_trap()
	ui_manager.show_debt_trap_message()
	
	# Screen effects
	var screen_flash = create_tween()
	screen_flash.tween_property(get_viewport(), "canvas_transform", 
		get_viewport().canvas_transform.scaled(Vector2(1.1, 1.1)), 0.1)
	screen_flash.tween_property(get_viewport(), "canvas_transform", 
		Transform2D.IDENTITY, 0.1)
	
	# Use a safer timer method with immediate transition
	call_deferred("_immediate_debt_trap_transition")

func _immediate_debt_trap_transition():
	# Return coins to GameManager immediately
	var _coins_earned = GameManager.exit_pacman_stage()
	
	# Transition immediately without timer to avoid tree issues
	if is_inside_tree():
		get_tree().change_scene_to_file("res://Scenes/SlotMachine.tscn")
	else:
		# Fallback: use GameManager to handle scene change
		print("Using GameManager fallback for scene transition")
		GameManager.call_deferred("_safe_scene_change", "res://Scenes/SlotMachine.tscn")

func _on_ui_message_displayed(message: String):
	print("UI Message: ", message)

func _on_audio_played(audio_type: String):
	print("Audio played: ", audio_type)

func _on_exit_available():
	game_state.handle_exit_available()

func exit_pacman_stage():
	if not game_state.is_game_active():
		return
	
	game_state.exit_game()
	
	# Return coins to GameManager
	var _coins_earned = GameManager.exit_pacman_stage()
	
	# Transition back to slot machine
	get_tree().change_scene_to_file("res://Scenes/SlotMachine.tscn")

# Debug function to identify tilemap issues
func debug_tilemap_issues():
	print("=== TILEMAP DEBUG ===")
	
	if not tilemap_layer:
		print("ERROR: No tilemap_layer found!")
		return
	
	var tileset = tilemap_layer.tile_set
	if not tileset:
		print("ERROR: No tileset assigned to tilemap!")
		return
	
	print("TileSet has ", tileset.get_source_count(), " sources")
	var used_rect = tilemap_layer.get_used_rect()
	print("Used rect: ", used_rect)
	print("Tilemap layer name: ", tilemap_layer.name)
	print("======================")

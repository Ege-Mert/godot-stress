extends Node
class_name PacmanGameState

# Game state management for Pacman game

signal exit_unlocked
signal game_over(reason: String)
signal debt_trap_triggered

@export var coins_to_trigger_wall_ghost: int = 10

var game_active: bool = true
var exit_unlocked_state: bool = false
var player_start_pos: Vector2

var exit_gates: Node2D
var utility: PacmanUtility

func initialize(gates: Node2D, start_pos: Vector2, utilities: PacmanUtility):
	exit_gates = gates
	player_start_pos = start_pos
	utility = utilities

func setup_initial_state():
	# Handle exit gates based on game state
	if GameManager.is_first_pacman:
		hide_exit_gates()
	else:
		close_exit_gates()

func check_gate_collision(player_position: Vector2) -> bool:
	"""Check if player is colliding with any exit gate"""
	if not exit_gates or not exit_unlocked_state:
		return false
	
	var collision_distance = 40.0  # How close player needs to be to gate
	
	for gate in exit_gates.get_children():
		if gate.visible:  # Only check visible gates
			var distance = player_position.distance_to(gate.position)
			if distance < collision_distance:
				print("Player touched exit gate - exiting!")
				return true
	
	return false

func handle_exit_available():
	# Don't show exit in first pacman game (gates are hidden)
	if GameManager.is_first_pacman:
		return
	
	exit_unlocked_state = true
	open_exit_gates()
	exit_unlocked.emit()

func handle_normal_ghost_caught():
	# Normal ghost caught player - trigger respawn
	if not game_active:
		return
	
	print("Player caught by normal ghost")

func handle_phasing_ghost_caught():
	# Phasing ghost caught player
	print("🛑 Player caught by wall-phasing ghost!")
	
	if GameManager.is_first_pacman:
		print("Processing tutorial debt trap...")
		game_active = false
		debt_trap_triggered.emit()
	else:
		print("Not first pacman - normal death")
		handle_normal_ghost_caught()

func should_spawn_phasing_ghost(coins_collected: int) -> bool:
	return (GameManager.is_first_pacman and 
			coins_collected >= coins_to_trigger_wall_ghost)

func exit_game():
	if not game_active:
		return
	
	game_active = false
	game_over.emit("exit")

func open_exit_gates():
	# Animate gates opening
	var tween = exit_gates.create_tween()
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

func is_game_active() -> bool:
	return game_active

func is_exit_unlocked() -> bool:
	return exit_unlocked_state

func get_spawn_position() -> Vector2:
	return player_start_pos

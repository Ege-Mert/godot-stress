extends Control
class_name SlotMachineController

@export_group("Game Balance")
@export var first_spin_win_chance: float = 0.05
@export var normal_win_chance: float = 0.3
@export var jackpot_chance: float = 0.0001
@export var coin_win_ratio: float = 0.6

@export_group("Payout Settings")
@export var min_coin_win: int = 10
@export var max_coin_win: int = 30
@export var min_debt_reduction: int = 50
@export var max_debt_reduction: int = 200
@export var jackpot_debt_clear: int = 1000000

@export_group("Audio Settings")
@export var enable_audio: bool = true
@export var audio_volume: float = 1.0

@export_group("Visual Effects")
@export var enable_screen_shake: bool = true
@export var shake_intensity: float = 3.0
@export var result_display_duration: float = 3.0

signal spin_started
signal spin_completed(result: Dictionary)
signal evil_laugh_triggered

var ui_manager: SlotMachineUI
var reel_manager: SlotMachineReels
var handle_manager: SlotMachineHandle
var audio_manager: SlotMachineAudio

var is_spinning: bool = false
var current_spin_result: Dictionary

func _ready():
	setup_components()
	connect_signals()
	initialize_game()

func setup_components():
	ui_manager = $UI as SlotMachineUI
	reel_manager = $ReelManager as SlotMachineReels
	handle_manager = $HandleManager as SlotMachineHandle
	audio_manager = $AudioManager as SlotMachineAudio
	
	if not ui_manager:
		push_error("SlotMachineUI component not found!")
	if not reel_manager:
		push_error("SlotMachineReels component not found!")
	if not handle_manager:
		push_error("SlotMachineHandle component not found!")
	if not audio_manager:
		push_error("SlotMachineAudio component not found!")

func connect_signals():
	if GameManager.has_signal("coins_changed"):
		GameManager.coins_changed.connect(_on_coins_changed)
	if GameManager.has_signal("debt_changed"):
		GameManager.debt_changed.connect(_on_debt_changed)
	if GameManager.has_signal("evil_laugh_trigger"):
		GameManager.evil_laugh_trigger.connect(_on_evil_laugh_trigger)
	
	if ui_manager:
		ui_manager.spin_button_pressed.connect(_on_spin_requested)
		ui_manager.upgrade_button_pressed.connect(_on_upgrade_requested)
	
	if handle_manager:
		handle_manager.handle_pulled.connect(_on_spin_requested)
	
	if reel_manager:
		reel_manager.animation_completed.connect(_on_reel_animation_completed)

func initialize_game():
	update_ui()
	if reel_manager:
		reel_manager.initialize_reels()

func _on_spin_requested():
	if can_perform_spin():
		perform_spin()

func can_perform_spin() -> bool:
	return not is_spinning and GameManager.can_spin()

func perform_spin():
	if not can_perform_spin():
		return
	
	is_spinning = true
	spin_started.emit()
	
	var spin_result = GameManager.perform_spin()
	if not spin_result.get("success", true):
		is_spinning = false
		return
	
	current_spin_result = spin_result
	
	if ui_manager:
		ui_manager.set_spinning_state(true)
	
	if audio_manager and enable_audio:
		audio_manager.play_spin_sound()
	
	if reel_manager:
		var symbols = determine_symbols_from_result(spin_result)
		reel_manager.start_spin_animation(symbols)

func determine_symbols_from_result(result: Dictionary) -> Array[int]:
	var symbols: Array[int] = [0, 0, 0]
	
	match result.type:
		"jackpot":
			symbols = [6, 6, 6]  # Three sevens
		"coin_win", "debt_win":
			var winning_symbol = randi() % 5
			var different_symbol = (winning_symbol + 1 + randi() % 4) % 7
			symbols = [winning_symbol, winning_symbol, different_symbol]
		_:  # Loss
			symbols[0] = randi() % 7
			symbols[1] = (symbols[0] + 1 + randi() % 3) % 7
			symbols[2] = (symbols[1] + 1 + randi() % 3) % 7
	
	return symbols

func _on_reel_animation_completed():
	is_spinning = false
	
	if ui_manager:
		ui_manager.set_spinning_state(false)
		ui_manager.display_result(current_spin_result)
	
	play_result_audio(current_spin_result)
	spin_completed.emit(current_spin_result)
	
	if not GameManager.can_spin():
		call_deferred("trigger_evil_laugh")

func play_result_audio(result: Dictionary):
	if not audio_manager or not enable_audio:
		return
	
	match result.type:
		"jackpot", "coin_win", "debt_win":
			audio_manager.play_win_sound()
		_:
			audio_manager.play_lose_sound()

func trigger_evil_laugh():
	await get_tree().create_timer(2.0).timeout
	
	if audio_manager and enable_audio:
		audio_manager.play_evil_laugh()
	
	if enable_screen_shake:
		create_screen_shake()
	
	if ui_manager:
		ui_manager.show_evil_message()
	
	evil_laugh_triggered.emit()
	
	await get_tree().create_timer(4.0).timeout
	transition_to_pacman()

func create_screen_shake():
	if not enable_screen_shake:
		return
	
	var shake_tween = create_tween()
	var original_position = position
	
	for i in range(8):
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_tween.tween_property(self, "position", original_position + shake_offset, 0.1)
	
	shake_tween.tween_property(self, "position", original_position, 0.1)

func transition_to_pacman():
	var pacman_scene_path = "res://Scenes/PacmanScene.tscn"
	if ResourceLoader.exists(pacman_scene_path):
		get_tree().change_scene_to_file(pacman_scene_path)
	else:
		push_error("Pacman scene not found at: " + pacman_scene_path)

func _on_upgrade_requested():
	if ui_manager:
		ui_manager.show_upgrade_shop()

func _on_coins_changed(_new_amount: int):
	update_ui()

func _on_debt_changed(_new_amount: int):
	update_ui()
	if GameManager.is_game_won() and ui_manager:
		ui_manager.show_victory_screen()

func _on_evil_laugh_trigger():
	trigger_evil_laugh()

func update_ui():
	if ui_manager:
		ui_manager.update_display()

func get_spin_cost() -> int:
	return GameManager.get_spin_cost()

func get_current_coins() -> int:
	return GameManager.current_coins

func get_current_debt() -> int:
	return GameManager.total_debt

func is_tutorial_mode() -> bool:
	return GameManager.is_tutorial_mode

extends Node
class_name PacmanUI

# UI management for Pacman game

signal ui_message_displayed(message: String)

var coins_collected_label: Label
var exit_prompt_label: Label
var warning_label: Label

var coins_needed_for_exit: int = 5

func initialize(coins_label: Label, exit_label: Label, warn_label: Label, coins_needed: int):
	coins_collected_label = coins_label
	exit_prompt_label = exit_label
	warning_label = warn_label
	coins_needed_for_exit = coins_needed

func update_coins_display(coins_collected: int, exit_unlocked: bool):
	coins_collected_label.text = "Coins Collected: " + str(coins_collected)
	
	if exit_unlocked:
		coins_collected_label.text += " (Exit Available!)"
		coins_collected_label.modulate = Color.GREEN
	elif coins_collected >= coins_needed_for_exit - 1:
		coins_collected_label.text += " (Almost there!)"
		coins_collected_label.modulate = Color.YELLOW
	else:
		coins_collected_label.modulate = Color.WHITE

func show_exit_available():
	exit_prompt_label.text = "EXIT GATES OPENED! Walk into a gate to exit the maze."
	exit_prompt_label.modulate = Color.GREEN
	ui_message_displayed.emit("Exit gates opened")

func show_wall_ghost_warning():
	warning_label.text = "SPECIAL DEBT COLLECTOR SPAWNED!"
	warning_label.modulate = Color.RED
	ui_message_displayed.emit("Wall ghost spawned")
	
	# Auto-clear warning after 3 seconds
	await warning_label.get_tree().create_timer(3.0).timeout
	clear_warning()

func show_debt_trap_message():
	warning_label.text = "TUTORIAL DEBT TRAP! DEBT INCREASED BY $500,000!"
	warning_label.modulate = Color.RED
	ui_message_displayed.emit("Debt trap triggered")

func clear_warning():
	warning_label.text = ""

func clear_exit_prompt():
	exit_prompt_label.text = ""

func show_custom_message(message: String, color: Color = Color.WHITE, duration: float = 0.0):
	warning_label.text = message
	warning_label.modulate = color
	ui_message_displayed.emit(message)
	
	if duration > 0:
		await warning_label.get_tree().create_timer(duration).timeout
		clear_warning()

func reset_ui():
	clear_warning()
	clear_exit_prompt()
	update_coins_display(0, false)

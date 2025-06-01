extends Control
class_name SlotMachineUI

@export_group("UI Colors")
@export var debt_color: Color = Color.RED
@export var coins_low_color: Color = Color.RED
@export var coins_warning_color: Color = Color.YELLOW
@export var coins_normal_color: Color = Color.WHITE
@export var result_win_color: Color = Color.GREEN
@export var result_jackpot_color: Color = Color.GOLD
@export var result_debt_color: Color = Color.BLUE
@export var result_lose_color: Color = Color.RED

@export_group("UI Settings")
@export var coins_low_threshold: int = 10
@export var coins_warning_threshold: int = 25
@export var result_display_duration: float = 3.0
@export var evil_message_duration: float = 4.0

@export_group("Button Settings")
@export var spin_button_text: String = "SPIN"
@export var upgrade_button_text: String = "UPGRADES"
@export var disabled_button_alpha: float = 0.6

signal spin_button_pressed
signal upgrade_button_pressed

@onready var debt_label = $TopPanel/DebtLabel
@onready var coins_label = $TopPanel/CoinsLabel
@onready var spin_button = $BottomPanel/SpinButton
@onready var upgrade_button = $BottomPanel/UpgradeButton
@onready var result_label = $CenterPanel/ResultLabel

var controller: SlotMachineController
var upgrade_shop_scene = null

func _ready():
	controller = get_parent() as SlotMachineController
	connect_buttons()
	update_display()

func connect_buttons():
	if spin_button:
		spin_button.pressed.connect(_on_spin_button_pressed)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)

func _on_spin_button_pressed():
	spin_button_pressed.emit()

func _on_upgrade_button_pressed():
	upgrade_button_pressed.emit()

func update_display():
	update_debt_display()
	update_coins_display()
	update_button_states()

func update_debt_display():
	if not debt_label or not controller:
		return
	
	debt_label.text = "DEBT: $" + str(controller.get_current_debt())
	debt_label.modulate = debt_color

func update_coins_display():
	if not coins_label or not controller:
		return
	
	var coins = controller.get_current_coins()
	coins_label.text = "COINS: " + str(coins)
	
	if coins < coins_low_threshold:
		coins_label.modulate = coins_low_color
	elif coins < coins_warning_threshold:
		coins_label.modulate = coins_warning_color
	else:
		coins_label.modulate = coins_normal_color

func update_button_states():
	if not spin_button or not controller:
		return
	
	var can_spin = controller.can_perform_spin()
	var spin_cost = controller.get_spin_cost()
	
	spin_button.disabled = not can_spin
	spin_button.text = spin_button_text + " ($" + str(spin_cost) + ")"
	spin_button.modulate.a = 1.0 if can_spin else disabled_button_alpha
	
	if upgrade_button:
		upgrade_button.visible = not controller.is_tutorial_mode()
		upgrade_button.text = upgrade_button_text

func set_spinning_state(spinning: bool):
	if spin_button:
		spin_button.disabled = spinning
		spin_button.modulate.a = disabled_button_alpha if spinning else 1.0

func display_result(result: Dictionary):
	if not result_label:
		return
	
	match result.type:
		"jackpot":
			result_label.text = "🎉 JACKPOT! DEBT CLEARED! 🎉"
			result_label.modulate = result_jackpot_color
		"coin_win":
			result_label.text = "💰 WON " + str(result.coins_won) + " COINS! 💰"
			result_label.modulate = result_win_color
		"debt_win":
			result_label.text = "💳 DEBT REDUCED BY $" + str(result.debt_reduction) + "! 💳"
			result_label.modulate = result_debt_color
		_:
			result_label.text = "💸 YOU LOSE! 💸"
			result_label.modulate = result_lose_color
	
	clear_result_after_delay()

func show_evil_message():
	if not result_label:
		return
	
	result_label.text = "😈 MWAHAHAHA! TO THE MAZE! 😈"
	result_label.modulate = result_lose_color
	
	await get_tree().create_timer(evil_message_duration).timeout
	clear_result()

func clear_result_after_delay():
	await get_tree().create_timer(result_display_duration).timeout
	clear_result()

func clear_result():
	if result_label:
		result_label.text = ""

func show_upgrade_shop():
	if upgrade_shop_scene:
		upgrade_shop_scene.show_shop()
		return
	
	var upgrade_scene_path = "res://Scenes/UpgradeShop.tscn"
	if ResourceLoader.exists(upgrade_scene_path):
		upgrade_shop_scene = preload("res://Scenes/UpgradeShop.tscn").instantiate()
		add_child(upgrade_shop_scene)
		upgrade_shop_scene.show_shop()
	else:
		push_error("Upgrade shop scene not found!")

func show_victory_screen():
	var victory_popup = AcceptDialog.new()
	victory_popup.dialog_text = "🎉 CONGRATULATIONS! YOU'VE PAID OFF YOUR DEBT! 🎉"
	add_child(victory_popup)
	victory_popup.popup_centered()
	
	await get_tree().create_timer(5.0).timeout
	if victory_popup and is_instance_valid(victory_popup):
		victory_popup.queue_free()

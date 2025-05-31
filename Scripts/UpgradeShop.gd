extends Control

# UI References
@onready var upgrade_panel = $UpgradePanel
@onready var close_button = $UpgradePanel/CloseButton
@onready var coins_label = $UpgradePanel/Header/CoinsLabel

# Slot machine upgrades
@onready var better_odds_button = $UpgradePanel/MainContainer/SlotUpgrades/BetterOdds/UpgradeButton
@onready var better_odds_level = $UpgradePanel/MainContainer/SlotUpgrades/BetterOdds/LevelLabel
@onready var better_odds_cost = $UpgradePanel/MainContainer/SlotUpgrades/BetterOdds/CostLabel

@onready var coin_multiplier_button = $UpgradePanel/MainContainer/SlotUpgrades/CoinMultiplier/UpgradeButton
@onready var coin_multiplier_level = $UpgradePanel/MainContainer/SlotUpgrades/CoinMultiplier/LevelLabel
@onready var coin_multiplier_cost = $UpgradePanel/MainContainer/SlotUpgrades/CoinMultiplier/CostLabel

@onready var reduced_cost_button = $UpgradePanel/MainContainer/SlotUpgrades/ReducedCost/UpgradeButton
@onready var reduced_cost_level = $UpgradePanel/MainContainer/SlotUpgrades/ReducedCost/LevelLabel
@onready var reduced_cost_cost = $UpgradePanel/MainContainer/SlotUpgrades/ReducedCost/CostLabel

# Pacman upgrades
@onready var movement_speed_button = $UpgradePanel/MainContainer/PacmanUpgrades/MovementSpeed/UpgradeButton
@onready var movement_speed_level = $UpgradePanel/MainContainer/PacmanUpgrades/MovementSpeed/LevelLabel
@onready var movement_speed_cost = $UpgradePanel/MainContainer/PacmanUpgrades/MovementSpeed/CostLabel

@onready var invincibility_button = $UpgradePanel/MainContainer/PacmanUpgrades/Invincibility/UpgradeButton
@onready var invincibility_level = $UpgradePanel/MainContainer/PacmanUpgrades/Invincibility/LevelLabel
@onready var invincibility_cost = $UpgradePanel/MainContainer/PacmanUpgrades/Invincibility/CostLabel

@onready var coin_magnetism_button = $UpgradePanel/MainContainer/PacmanUpgrades/CoinMagnetism/UpgradeButton
@onready var coin_magnetism_level = $UpgradePanel/MainContainer/PacmanUpgrades/CoinMagnetism/LevelLabel
@onready var coin_magnetism_cost = $UpgradePanel/MainContainer/PacmanUpgrades/CoinMagnetism/CostLabel

# Warning label
@onready var warning_label = $UpgradePanel/WarningLabel

func _ready():
	# Connect signals
	GameManager.coins_changed.connect(_on_coins_changed)
	
	# Connect upgrade buttons
	better_odds_button.pressed.connect(func(): purchase_upgrade("better_odds", "slot"))
	coin_multiplier_button.pressed.connect(func(): purchase_upgrade("coin_multiplier", "slot"))
	reduced_cost_button.pressed.connect(func(): purchase_upgrade("reduced_cost", "slot"))
	
	movement_speed_button.pressed.connect(func(): purchase_upgrade("movement_speed", "pacman"))
	invincibility_button.pressed.connect(func(): purchase_upgrade("invincibility", "pacman"))
	coin_magnetism_button.pressed.connect(func(): purchase_upgrade("coin_magnetism", "pacman"))
	
	close_button.pressed.connect(close_shop)
	
	# Initially hidden
	visible = false

func show_shop():
	visible = true
	update_all_upgrades()

func close_shop():
	visible = false

func purchase_upgrade(upgrade_type: String, category: String):
	if GameManager.purchase_upgrade(upgrade_type, category):
		# Success feedback
		show_purchase_feedback(upgrade_type, true)
		update_all_upgrades()
	else:
		# Failure feedback
		show_purchase_feedback(upgrade_type, false)

func show_purchase_feedback(upgrade_type: String, success: bool):
	if success:
		warning_label.text = upgrade_type.replace("_", " ").capitalize() + " upgraded!"
		warning_label.modulate = Color.GREEN
	else:
		warning_label.text = "Not enough coins!"
		warning_label.modulate = Color.RED
	
	# Clear after delay
	await get_tree().create_timer(2.0).timeout
	warning_label.text = ""

func update_all_upgrades():
	update_coins_display()
	update_slot_upgrades()
	update_pacman_upgrades()
	update_warning_display()

func update_coins_display():
	coins_label.text = "Coins: " + str(GameManager.current_coins)

func update_slot_upgrades():
	# Better Odds
	var better_odds_lvl = GameManager.slot_upgrades.better_odds
	better_odds_level.text = "Level: " + str(better_odds_lvl)
	var better_odds_cost_val = GameManager.get_upgrade_cost("better_odds", "slot")
	better_odds_cost.text = "Cost: " + str(better_odds_cost_val)
	better_odds_button.disabled = not GameManager.can_afford_upgrade("better_odds", "slot")
	
	# Coin Multiplier
	var coin_mult_lvl = GameManager.slot_upgrades.coin_multiplier
	coin_multiplier_level.text = "Level: " + str(coin_mult_lvl)
	var coin_mult_cost_val = GameManager.get_upgrade_cost("coin_multiplier", "slot")
	coin_multiplier_cost.text = "Cost: " + str(coin_mult_cost_val)
	coin_multiplier_button.disabled = not GameManager.can_afford_upgrade("coin_multiplier", "slot")
	
	# Reduced Cost
	var reduced_cost_lvl = GameManager.slot_upgrades.reduced_cost
	reduced_cost_level.text = "Level: " + str(reduced_cost_lvl)
	var reduced_cost_cost_val = GameManager.get_upgrade_cost("reduced_cost", "slot")
	reduced_cost_cost.text = "Cost: " + str(reduced_cost_cost_val)
	reduced_cost_button.disabled = not GameManager.can_afford_upgrade("reduced_cost", "slot")

func update_pacman_upgrades():
	# Movement Speed
	var movement_lvl = GameManager.pacman_upgrades.movement_speed
	movement_speed_level.text = "Level: " + str(movement_lvl)
	var movement_cost_val = GameManager.get_upgrade_cost("movement_speed", "pacman")
	movement_speed_cost.text = "Cost: " + str(movement_cost_val)
	movement_speed_button.disabled = not GameManager.can_afford_upgrade("movement_speed", "pacman")
	
	# Invincibility
	var invince_lvl = GameManager.pacman_upgrades.invincibility
	invincibility_level.text = "Level: " + str(invince_lvl)
	var invince_cost_val = GameManager.get_upgrade_cost("invincibility", "pacman")
	invincibility_cost.text = "Cost: " + str(invince_cost_val)
	invincibility_button.disabled = not GameManager.can_afford_upgrade("invincibility", "pacman")
	
	# Coin Magnetism
	var magnetism_lvl = GameManager.pacman_upgrades.coin_magnetism
	coin_magnetism_level.text = "Level: " + str(magnetism_lvl)
	var magnetism_cost_val = GameManager.get_upgrade_cost("coin_magnetism", "pacman")
	coin_magnetism_cost.text = "Cost: " + str(magnetism_cost_val)
	coin_magnetism_button.disabled = not GameManager.can_afford_upgrade("coin_magnetism", "pacman")

func update_warning_display():
	# Show risk warning
	var total_upgrades = 0
	for value in GameManager.slot_upgrades.values():
		total_upgrades += value
	for value in GameManager.pacman_upgrades.values():
		total_upgrades += value
	
	if total_upgrades > 5:
		var risk_text = "WARNING: High upgrade levels increase Pacman difficulty!"
		if warning_label.text == "":
			warning_label.text = risk_text
			warning_label.modulate = Color.ORANGE

func _on_coins_changed(_new_amount: int):  # Prefixed with underscore
	if visible:
		update_all_upgrades()

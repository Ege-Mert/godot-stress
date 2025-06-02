extends Control

# UI References
@onready var upgrade_panel = $UpgradePanel
@onready var close_button = $UpgradePanel/CloseButton
@onready var coins_label = $UpgradePanel/Header/CoinsLabel

# Slot machine upgrades
@onready var win_frequency_button = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/WinFrequency/UpgradeButton")
@onready var win_frequency_level = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/WinFrequency/LevelLabel")
@onready var win_frequency_cost = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/WinFrequency/CostLabel")

@onready var payout_boost_button = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/PayoutBoost/UpgradeButton")
@onready var payout_boost_level = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/PayoutBoost/LevelLabel")
@onready var payout_boost_cost = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/PayoutBoost/CostLabel")

@onready var lucky_spin_button = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/LuckySpin/UpgradeButton")
@onready var lucky_spin_level = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/LuckySpin/LevelLabel")
@onready var lucky_spin_cost = get_node_or_null("UpgradePanel/MainContainer/SlotUpgrades/LuckySpin/CostLabel")

# Pacman upgrades
@onready var movement_speed_button = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/MovementSpeed/UpgradeButton")
@onready var movement_speed_level = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/MovementSpeed/LevelLabel")
@onready var movement_speed_cost = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/MovementSpeed/CostLabel")

@onready var coin_radar_button = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/CoinRadar/UpgradeButton")
@onready var coin_radar_level = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/CoinRadar/LevelLabel")
@onready var coin_radar_cost = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/CoinRadar/CostLabel")

@onready var ghost_slowdown_button = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/GhostSlowdown/UpgradeButton")
@onready var ghost_slowdown_level = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/GhostSlowdown/LevelLabel")
@onready var ghost_slowdown_cost = get_node_or_null("UpgradePanel/MainContainer/PacmanUpgrades/GhostSlowdown/CostLabel")

# Warning label
@onready var warning_label = $UpgradePanel/WarningLabel

func _ready():
	# Connect signals
	GameManager.coins_changed.connect(_on_coins_changed)
	
	# Connect upgrade buttons (with safety checks)
	if win_frequency_button:
		win_frequency_button.pressed.connect(func(): purchase_upgrade("win_frequency", "slot"))
	if payout_boost_button:
		payout_boost_button.pressed.connect(func(): purchase_upgrade("payout_boost", "slot"))
	if lucky_spin_button:
		lucky_spin_button.pressed.connect(func(): purchase_upgrade("lucky_spin", "slot"))
	
	if movement_speed_button:
		movement_speed_button.pressed.connect(func(): purchase_upgrade("movement_speed", "pacman"))
	if coin_radar_button:
		coin_radar_button.pressed.connect(func(): purchase_upgrade("coin_radar", "pacman"))
	if ghost_slowdown_button:
		ghost_slowdown_button.pressed.connect(func(): purchase_upgrade("ghost_slowdown", "pacman"))
	
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
	# Win Frequency
	var win_freq_lvl = GameManager.slot_upgrades.win_frequency
	if win_frequency_level:
		win_frequency_level.text = "Level: " + str(win_freq_lvl)
	var win_freq_cost_val = GameManager.get_upgrade_cost("win_frequency", "slot")
	if win_frequency_cost:
		win_frequency_cost.text = "Cost: " + str(win_freq_cost_val)
	if win_frequency_button:
		win_frequency_button.disabled = not GameManager.can_afford_upgrade("win_frequency", "slot")
	
	# Payout Boost
	var payout_lvl = GameManager.slot_upgrades.payout_boost
	if payout_boost_level:
		payout_boost_level.text = "Level: " + str(payout_lvl)
	var payout_cost_val = GameManager.get_upgrade_cost("payout_boost", "slot")
	if payout_boost_cost:
		payout_boost_cost.text = "Cost: " + str(payout_cost_val)
	if payout_boost_button:
		payout_boost_button.disabled = not GameManager.can_afford_upgrade("payout_boost", "slot")
	
	# Lucky Spin
	var lucky_lvl = GameManager.slot_upgrades.lucky_spin
	if lucky_spin_level:
		lucky_spin_level.text = "Level: " + str(lucky_lvl)
	var lucky_cost_val = GameManager.get_upgrade_cost("lucky_spin", "slot")
	if lucky_spin_cost:
		lucky_spin_cost.text = "Cost: " + str(lucky_cost_val)
	if lucky_spin_button:
		lucky_spin_button.disabled = not GameManager.can_afford_upgrade("lucky_spin", "slot")

func update_pacman_upgrades():
	# Movement Speed
	var movement_lvl = GameManager.pacman_upgrades.movement_speed
	if movement_speed_level:
		movement_speed_level.text = "Level: " + str(movement_lvl)
	var movement_cost_val = GameManager.get_upgrade_cost("movement_speed", "pacman")
	if movement_speed_cost:
		movement_speed_cost.text = "Cost: " + str(movement_cost_val)
	if movement_speed_button:
		movement_speed_button.disabled = not GameManager.can_afford_upgrade("movement_speed", "pacman")
	
	# Coin Radar
	var radar_lvl = GameManager.pacman_upgrades.coin_radar
	if coin_radar_level:
		coin_radar_level.text = "Level: " + str(radar_lvl)
	var radar_cost_val = GameManager.get_upgrade_cost("coin_radar", "pacman")
	if coin_radar_cost:
		coin_radar_cost.text = "Cost: " + str(radar_cost_val)
	if coin_radar_button:
		coin_radar_button.disabled = not GameManager.can_afford_upgrade("coin_radar", "pacman")
	
	# Ghost Slowdown
	var slowdown_lvl = GameManager.pacman_upgrades.ghost_slowdown
	if ghost_slowdown_level:
		ghost_slowdown_level.text = "Level: " + str(slowdown_lvl)
	var slowdown_cost_val = GameManager.get_upgrade_cost("ghost_slowdown", "pacman")
	if ghost_slowdown_cost:
		ghost_slowdown_cost.text = "Cost: " + str(slowdown_cost_val)
	if ghost_slowdown_button:
		ghost_slowdown_button.disabled = not GameManager.can_afford_upgrade("ghost_slowdown", "pacman")

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

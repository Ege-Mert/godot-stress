extends Node

# Temporary debug script - attach to any scene to test functionality
# You can add this to either SlotMachine or PacmanScene nodes

func _ready():
	print("=== DEBUG TEST STARTED ===")
	
	# Test GameManager state
	print("GameManager coins: ", GameManager.current_coins)
	print("GameManager debt: ", GameManager.total_debt)
	print("Can spin: ", GameManager.can_spin())
	
	# If this is the Pacman scene, test coin detection
	if get_parent().name == "PacmanScene":
		test_coin_detection()
	
	# If this is the Slot Machine, test reel references
	if get_parent().name == "SlotMachine":
		test_reel_references()

func test_coin_detection():
	print("\n--- COIN DETECTION TEST ---")
	var scene = get_parent()
	
	# Count all potential coins
	var total_coins = 0
	for child in scene.get_children():
		if child.name.begins_with("Coin"):
			total_coins += 1
			print("Found coin: ", child.name, " at ", child.position)
	
	print("Total coins found: ", total_coins)
	
	# Test if coins have the right signal
	for child in scene.get_children():
		if child.name.begins_with("Coin"):
			if child.has_signal("picked_up"):
				print("✅ Coin ", child.name, " has picked_up signal")
			else:
				print("❌ Coin ", child.name, " missing picked_up signal")

func test_reel_references():
	print("\n--- REEL REFERENCE TEST ---")
	var scene = get_parent()
	
	var reel_paths = [
		"SlotMachine/Reels/Reel1",
		"SlotMachine/Reels/Reel2", 
		"SlotMachine/Reels/Reel3"
	]
	
	for path in reel_paths:
		if scene.has_node(path):
			var reel = scene.get_node(path)
			print("✅ Found reel: ", path, " - Type: ", reel.get_class())
		else:
			print("❌ Missing reel: ", path)

func _input(event):
	# Press T to run tests again
	if event.is_action_pressed("ui_cancel"):  # ESC key
		print("\n=== MANUAL TEST TRIGGERED ===")
		if get_parent().name == "PacmanScene":
			test_coin_detection()
		elif get_parent().name == "SlotMachine":
			test_reel_references()

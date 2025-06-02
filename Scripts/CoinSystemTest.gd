# CoinSystemTest.gd - Test script for the enhanced coin respawn system
# Attach this to a node in your scene and call test_enhanced_coin_system() to verify functionality

extends Node

func test_enhanced_coin_system():
	print("🧪 TESTING ENHANCED COIN RESPAWN SYSTEM")
	print("=" * 50)
	
	# Test 1: Check initial state
	print("\n📋 TEST 1: Initial State")
	print("Current coins: ", GameManager.current_coins)
	print("Spins since reset: ", GameManager.spins_since_coin_reset)
	print("Spins until respawn: ", GameManager.get_spins_until_coin_respawn())
	print("Pacman entry blocked: ", GameManager.pacman_entry_blocked)
	
	# Test 2: Check Pacman entry status
	print("\n📋 TEST 2: Pacman Entry Status")
	var entry_status = GameManager.get_pacman_entry_status()
	print("Can enter Pacman: ", entry_status.can_enter)
	print("Reason: ", entry_status.reason)
	
	# Test 3: Simulate coin collection and exit
	print("\n📋 TEST 3: Simulate Pacman Session")
	
	# Register some test coin positions
	var test_positions = [
		Vector2(100, 100), Vector2(200, 100), Vector2(300, 100),
		Vector2(100, 200), Vector2(200, 200), Vector2(300, 200),
		Vector2(100, 300), Vector2(200, 300)  # Only 8 coins total
	]
	
	print("Registering ", test_positions.size(), " coin positions...")
	for pos in test_positions:
		GameManager.register_coin_position(pos)
	
	# Simulate collecting 6 coins (leaving only 2)
	print("Simulating collecting 6 coins...")
	for i in range(6):
		GameManager.collect_coin_at_position(test_positions[i])
		GameManager.collect_pacman_coin()
	
	# Simulate exiting Pacman with only 2 coins left
	print("Simulating Pacman exit...")
	var coins_earned = GameManager.exit_pacman_stage()
	print("Coins earned: ", coins_earned)
	print("Coins left in maze: ", GameManager.coins_available_on_last_exit)
	print("Pacman entry blocked: ", GameManager.pacman_entry_blocked)
	
	# Test 4: Check entry status after insufficient coins
	print("\n📋 TEST 4: Entry Status After Insufficient Coins")
	entry_status = GameManager.get_pacman_entry_status()
	print("Can enter Pacman: ", entry_status.can_enter)
	print("Reason: ", entry_status.reason)
	
	# Test 5: Simulate spins to trigger coin respawn
	print("\n📋 TEST 5: Simulate Spins for Coin Respawn")
	var spins_needed = GameManager.spins_needed_for_coin_reset
	print("Spins needed for reset: ", spins_needed)
	
	for i in range(spins_needed):
		GameManager.spins_since_coin_reset += 1
		var spins_left = GameManager.get_spins_until_coin_respawn()
		print("Spin ", i + 1, " - Spins left until respawn: ", spins_left)
		
		# Trigger reset when threshold reached
		if GameManager.should_reset_coins():
			print("🔄 TRIGGERING COIN RESET!")
			GameManager.perform_coin_reset()
			break
	
	# Test 6: Check entry status after coin respawn
	print("\n📋 TEST 6: Entry Status After Coin Respawn")
	entry_status = GameManager.get_pacman_entry_status()
	print("Can enter Pacman: ", entry_status.can_enter)
	print("Reason: ", entry_status.reason)
	print("Pacman entry blocked: ", GameManager.pacman_entry_blocked)
	
	# Test 7: Check available coins
	print("\n📋 TEST 7: Available Coins After Reset")
	var available_coins = GameManager.get_available_coin_positions()
	print("Available coin positions: ", available_coins.size())
	print("All coins should be available again!")
	
	print("\n✅ ENHANCED COIN SYSTEM TEST COMPLETE!")
	print("=" * 50)

# Call this function to run a quick verification
func quick_test():
	print("🚀 QUICK COIN SYSTEM TEST")
	
	# Show current status
	var entry_status = GameManager.get_pacman_entry_status()
	print("Can enter Pacman: ", entry_status.can_enter)
	print("Reason: ", entry_status.reason)
	print("Spins until coin respawn: ", GameManager.get_spins_until_coin_respawn())
	
	# If entry is blocked, show when it will be unblocked
	if not entry_status.can_enter and GameManager.pacman_entry_blocked:
		var spins_left = GameManager.get_spins_until_coin_respawn()
		print("⏰ Pacman entry will be unblocked in ", spins_left, " spins")

# Helper function to manually trigger coin respawn (for testing)
func force_coin_respawn():
	print("🔧 FORCING COIN RESPAWN...")
	GameManager.perform_coin_reset()
	print("✅ Coins respawned!")

# Helper function to simulate insufficient coins exit
func simulate_insufficient_exit():
	print("🔧 SIMULATING INSUFFICIENT COINS EXIT...")
	# Simulate exiting with less than 5 coins available
	GameManager.coins_available_on_last_exit = 3
	GameManager.pacman_entry_blocked = true
	GameManager.pacman_entry_status_changed.emit(false, "Insufficient coins in maze")
	print("✅ Pacman entry blocked due to insufficient coins!")

# Instructions for using this test script
func _ready():
	print("📚 COIN SYSTEM TEST SCRIPT LOADED")
	print("Available functions:")
	print("  - test_enhanced_coin_system() - Full comprehensive test")
	print("  - quick_test() - Quick status check")
	print("  - force_coin_respawn() - Manually trigger respawn")
	print("  - simulate_insufficient_exit() - Test blocked entry")
	print()
	print("Example usage in debug console:")
	print("  get_node('/root/CoinSystemTest').test_enhanced_coin_system()")

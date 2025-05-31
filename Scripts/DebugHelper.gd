extends Node

# Simple error handling and debugging for game jam
# Add this as an autoload if you want extra debugging

var debug_mode: bool = true

func _ready():
	if debug_mode:
		print("=== DEBT COLLECTOR DEBUG MODE ===")
		print("GameManager initial state:")
		print("- Coins: ", GameManager.current_coins)
		print("- Debt: ", GameManager.total_debt)
		print("- First spin: ", GameManager.is_first_spin)
		print("===============================")

func log_error(message: String, context: String = ""):
	var full_message = "[ERROR]"
	if context != "":
		full_message += " [" + context + "]"
	full_message += " " + message
	print(full_message)

func log_warning(message: String, context: String = ""):
	var full_message = "[WARNING]"
	if context != "":
		full_message += " [" + context + "]"
	full_message += " " + message
	print(full_message)

func log_info(message: String, context: String = ""):
	if debug_mode:
		var full_message = "[INFO]"
		if context != "":
			full_message += " [" + context + "]"
		full_message += " " + message
		print(full_message)

func validate_scene_structure(scene_node: Node, required_nodes: Array) -> bool:
	var missing_nodes = []
	
	for node_path in required_nodes:
		if not scene_node.has_node(node_path):
			missing_nodes.append(node_path)
	
	if missing_nodes.size() > 0:
		log_warning("Missing scene nodes: " + str(missing_nodes), scene_node.name)
		return false
	
	return true

func safe_audio_play(audio_player: AudioStreamPlayer, context: String = ""):
	if not audio_player:
		log_warning("Audio player is null", context)
		return false
	
	if not audio_player.stream:
		log_info("No audio stream assigned", context)
		return false
	
	audio_player.play()
	return true

# Quick scene validation functions
func validate_slot_machine_scene(scene: Node) -> bool:
	var required_nodes = [
		"UI/TopPanel/DebtLabel",
		"UI/TopPanel/CoinsLabel", 
		"UI/BottomPanel/SpinButton"
	]
	return validate_scene_structure(scene, required_nodes)

func validate_pacman_scene(scene: Node) -> bool:
	var required_nodes = [
		"Player",
		"TileMapLayer",
		"UI/CoinsLabel"
	]
	return validate_scene_structure(scene, required_nodes)

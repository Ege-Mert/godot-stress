extends Node
class_name PacmanAudio

# Audio management for Pacman game

signal audio_played(audio_type: String)

@export var enable_audio: bool = true

var audio_coin_pickup: AudioStreamPlayer2D
var audio_ghost_spawn: AudioStreamPlayer2D
var audio_death: AudioStreamPlayer2D
var audio_gate_open: AudioStreamPlayer2D

func initialize(coin_audio: AudioStreamPlayer2D, ghost_audio: AudioStreamPlayer2D, 
			   death_audio: AudioStreamPlayer2D, gate_audio: AudioStreamPlayer2D):
	audio_coin_pickup = coin_audio
	audio_ghost_spawn = ghost_audio
	audio_death = death_audio
	audio_gate_open = gate_audio

func play_coin_pickup():
	if not enable_audio:
		return
	
	if audio_coin_pickup and audio_coin_pickup.stream:
		audio_coin_pickup.play()
		audio_played.emit("coin_pickup")
	elif audio_coin_pickup:
		print("Warning: audio_coin_pickup has no stream")
	else:
		print("Warning: audio_coin_pickup node not found")

func play_ghost_spawn():
	if not enable_audio:
		return
	
	if audio_ghost_spawn and audio_ghost_spawn.stream:
		audio_ghost_spawn.play()
		audio_played.emit("ghost_spawn")
	elif audio_ghost_spawn:
		print("Warning: audio_ghost_spawn has no stream")
	else:
		print("Warning: audio_ghost_spawn node not found")

func play_death():
	if not enable_audio:
		return
	
	if audio_death and audio_death.stream:
		audio_death.play()
		audio_played.emit("death")
	elif audio_death:
		print("Warning: audio_death has no stream")
	else:
		print("Warning: audio_death node not found")

func play_gate_open():
	if not enable_audio:
		return
	
	if audio_gate_open and audio_gate_open.stream:
		audio_gate_open.play()
		audio_played.emit("gate_open")
	elif audio_gate_open:
		print("Warning: audio_gate_open has no stream")
	else:
		print("Warning: audio_gate_open node not found")

func set_audio_enabled(enabled: bool):
	enable_audio = enabled

func stop_all_audio():
	if audio_coin_pickup:
		audio_coin_pickup.stop()
	if audio_ghost_spawn:
		audio_ghost_spawn.stop()
	if audio_death:
		audio_death.stop()
	if audio_gate_open:
		audio_gate_open.stop()

func is_audio_enabled() -> bool:
	return enable_audio

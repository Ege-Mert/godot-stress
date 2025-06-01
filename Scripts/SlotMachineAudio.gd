extends Node
class_name SlotMachineAudio

@export_group("Audio Settings")
@export var master_volume: float = 1.0
@export var spin_volume: float = 1.0
@export var win_volume: float = 1.0
@export var lose_volume: float = 1.0
@export var evil_laugh_volume: float = 1.0

@export_group("Audio Clips")
@export var spin_sound: AudioStream
@export var win_sound: AudioStream
@export var lose_sound: AudioStream
@export var evil_laugh_sound: AudioStream

@export_group("Playback Settings")
@export var enable_audio: bool = true
@export var interrupt_on_new_sound: bool = true

@onready var spin_player = $SpinSound
@onready var win_player = $WinSound
@onready var lose_player = $LoseSound
@onready var evil_laugh_player = $EvilLaugh

var controller: SlotMachineController

func _ready():
	controller = get_parent() as SlotMachineController
	setup_audio_players()

func setup_audio_players():
	setup_player(spin_player, spin_sound, spin_volume)
	setup_player(win_player, win_sound, win_volume)
	setup_player(lose_player, lose_sound, lose_volume)
	setup_player(evil_laugh_player, evil_laugh_sound, evil_laugh_volume)

func setup_player(player: AudioStreamPlayer2D, stream: AudioStream, volume: float):
	if not player:
		return
	
	if stream:
		player.stream = stream
	
	player.volume_db = linear_to_db(volume * master_volume)

func play_spin_sound():
	play_audio(spin_player)

func play_win_sound():
	play_audio(win_player)

func play_lose_sound():
	play_audio(lose_player)

func play_evil_laugh():
	play_audio(evil_laugh_player)

func play_audio(player: AudioStreamPlayer2D):
	if not enable_audio or not player or not player.stream:
		return
	
	if interrupt_on_new_sound and player.playing:
		player.stop()
	
	player.play()

func stop_all_audio():
	if spin_player:
		spin_player.stop()
	if win_player:
		win_player.stop()
	if lose_player:
		lose_player.stop()
	if evil_laugh_player:
		evil_laugh_player.stop()

func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	setup_audio_players()

func set_audio_enabled(enabled: bool):
	enable_audio = enabled
	if not enabled:
		stop_all_audio()

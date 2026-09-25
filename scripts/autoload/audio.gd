extends Node
## Sound effects and the music loop. Autoloaded as `Audio`.

const SOUNDS := ["tap", "cook", "ready", "pickup", "serve", "coin", "grumble", "door", "buy", "nope", "open", "close", "sparkle"]
const VOICES := 10

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		_streams[s] = load("res://assets/audio/%s.wav" % s)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/audio/music.wav")
	_music.volume_db = -11.0
	add_child(_music)
	apply_settings()


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not GameState.sound_on or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = volume_db
	p.play()


func apply_settings() -> void:
	if GameState.music_on:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()

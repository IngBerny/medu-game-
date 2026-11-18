extends Node
## Sfx (Autoload)
##
## Reproduce los efectos de sonido y la música ambiental.
## Usa un grupo de reproductores para que varios sonidos puedan sonar a la vez
## sin crear nodos nuevos durante la partida (mejor rendimiento en gama baja).

const SOUND_NAMES := ["dash", "zap", "pop", "hit", "gameover", "start", "click", "heal"]
const VOICES := 8

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name in SOUND_NAMES:
		var path := "res://assets/sfx/%s.wav" % sound_name
		if ResourceLoader.exists(path):
			_streams[sound_name] = load(path)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)

	_music = AudioStreamPlayer.new()
	_music.volume_db = -11.0
	add_child(_music)
	var music_path := "res://assets/music/ambient.wav"
	if ResourceLoader.exists(music_path):
		var stream: AudioStreamWAV = load(music_path)
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2   # 16 bits mono -> 2 bytes por muestra
		_music.stream = stream
	GameManager.settings_changed.connect(_apply_music_state)
	_apply_music_state()


func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not GameManager.sound_enabled:
		return
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _apply_music_state() -> void:
	if _music.stream == null:
		return
	if GameManager.sound_enabled:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()

extends Node
## GameManager (Autoload)
##
## Cerebro del juego. Guarda el estado (menú / jugando / pausa / game over),
## el puntaje, las vidas, la dificultad progresiva y el High Score en el teléfono.
## Todos los demás scripts le hablan mediante señales para no depender unos de otros.

# --- Señales ---------------------------------------------------------------
signal state_changed(new_state: int)
signal score_changed(score: int)
signal lives_changed(lives: int)
signal game_started
signal game_over(final_score: int, is_new_record: bool)
signal settings_changed

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

# --- Ajustes de dificultad (puedes tocarlos para balancear el juego) -------
const MAX_LIVES := 3
const START_SPEED := 300.0       # velocidad inicial del mundo (px/seg)
const MAX_SPEED := 820.0         # tope de velocidad
const RAMP_SECONDS := 150.0      # segundos hasta llegar a la dificultad máxima
const POINTS_PER_SECOND := 10.0  # puntos por sobrevivir

const SAVE_PATH := "user://medu_save.cfg"

# --- Estado ---------------------------------------------------------------
var state: int = State.MENU
var score: int = 0
var high_score: int = 0
var lives: int = MAX_LIVES
var elapsed: float = 0.0
var difficulty: float = 0.0      # 0.0 (fácil) -> 1.0 (máximo)
var game_speed: float = START_SPEED
var new_record: bool = false

var sound_enabled: bool = true
var vibration_enabled: bool = true

var _score_acc: float = 0.0


func _ready() -> void:
	# Debe seguir funcionando aunque el juego esté en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El botón "atrás" de Android no cierra la app; lo manejamos nosotros.
	get_tree().set_quit_on_go_back(false)
	_load_data()


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	delta = minf(delta, 0.05)
	elapsed += delta
	difficulty = clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
	game_speed = lerpf(START_SPEED, MAX_SPEED, difficulty)
	_score_acc += POINTS_PER_SECOND * delta
	if _score_acc >= 1.0:
		var whole := int(_score_acc)
		_score_acc -= whole
		add_score(whole)


# --- Utilidades --------------------------------------------------------------
## Tamaño visible de la pantalla en píxeles lógicos (cambia según el teléfono).
func view_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func vibrate(ms: int) -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


# --- Control de partida --------------------------------------------------------
func start_game() -> void:
	score = 0
	lives = MAX_LIVES
	elapsed = 0.0
	difficulty = 0.0
	game_speed = START_SPEED
	new_record = false
	_score_acc = 0.0
	get_tree().paused = false
	score_changed.emit(score)
	lives_changed.emit(lives)
	game_started.emit()
	_set_state(State.PLAYING)


func add_score(amount: int) -> void:
	if state != State.PLAYING:
		return
	score += amount
	score_changed.emit(score)


## Resta una vida. Devuelve true si el jugador murió.
func lose_life() -> bool:
	if state != State.PLAYING:
		return false
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	if lives <= 0:
		end_game()
		return true
	return false


## Recupera una vida (corazón recogido).
func heal() -> void:
	if state != State.PLAYING or lives >= MAX_LIVES:
		return
	lives += 1
	lives_changed.emit(lives)


func end_game() -> void:
	if state == State.GAME_OVER:
		return
	if score > high_score:
		high_score = score
		new_record = true
		_save_data()
	_set_state(State.GAME_OVER)
	game_over.emit(score, new_record)


func pause_game() -> void:
	if state != State.PLAYING:
		return
	get_tree().paused = true
	_set_state(State.PAUSED)


func resume_game() -> void:
	if state != State.PAUSED:
		return
	get_tree().paused = false
	_set_state(State.PLAYING)


func go_to_menu() -> void:
	get_tree().paused = false
	_set_state(State.MENU)


func set_sound_enabled(value: bool) -> void:
	sound_enabled = value
	_save_data()
	settings_changed.emit()


func _set_state(new_state: int) -> void:
	state = new_state
	state_changed.emit(new_state)


# --- Eventos del sistema (Android) -----------------------------------------
func _notification(what: int) -> void:
	match what:
		# Salir de la app / apagar pantalla / llamada entrante -> pausa automática
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			pause_game()
		# Botón "atrás" de Android
		NOTIFICATION_WM_GO_BACK_REQUEST:
			match state:
				State.PLAYING:
					pause_game()
				State.PAUSED:
					resume_game()
				State.GAME_OVER:
					go_to_menu()
				_:
					get_tree().quit()


# --- Guardado ---------------------------------------------------------------
func _save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("medu", "high_score", high_score)
	cfg.set_value("medu", "sound", sound_enabled)
	cfg.set_value("medu", "vibration", vibration_enabled)
	cfg.save(SAVE_PATH)


func _load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	high_score = int(cfg.get_value("medu", "high_score", 0))
	sound_enabled = bool(cfg.get_value("medu", "sound", true))
	vibration_enabled = bool(cfg.get_value("medu", "vibration", true))

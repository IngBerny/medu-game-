extends CanvasLayer
## UI: menú principal, HUD de puntaje, pausa y pantalla de fin de juego.
## Todo se construye por código para que la escena principal sea mínima.

var player: Node2D

var _controls: Control
var _score_label: Label
var _best_label: Label
var _menu: Control
var _pause: Control
var _over: Control
var _menu_best: Label
var _sound_btn: Button
var _over_score: Label
var _over_record: Label
var _over_best: Label
var _over_token := 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_controls = preload("res://scripts/touch_controls.gd").new()
	_controls.player = player
	add_child(_controls)

	_score_label = _label(self, "0", 52)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_top = 8.0
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_best_label = _label(self, "", 24, Color(1, 1, 1, 0.75))
	_best_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_best_label.offset_top = 70.0
	_best_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_menu()
	_build_pause()
	_build_over()

	GameManager.state_changed.connect(_on_state)
	GameManager.score_changed.connect(_on_score)
	GameManager.game_over.connect(_on_game_over)
	GameManager.settings_changed.connect(_update_sound_text)
	_on_score(GameManager.score)
	_update_sound_text()
	_on_state(GameManager.state)


# --- Construcción --------------------------------------------------------------
func _build_menu() -> void:
	_menu = _make_panel(0.25)
	var box: VBoxContainer = _menu.get_meta("box")
	_label(box, "EL ATAQUE", 76, Color(0.98, 0.6, 0.96))
	_label(box, "DEL MEDU", 76, Color(0.6, 0.95, 1.0))
	_menu_best = _label(box, "", 30, Color(1, 0.95, 0.6))
	_button(box, "JUGAR", _on_play)
	_sound_btn = _button(box, "", _on_toggle_sound, Color(0.25, 0.4, 0.6))
	_label(box, "Mantén la pantalla para subir", 24, Color(1, 1, 1, 0.8))


func _build_pause() -> void:
	_pause = _make_panel(0.6)
	var box: VBoxContainer = _pause.get_meta("box")
	_label(box, "PAUSA", 70)
	_button(box, "CONTINUAR", func(): GameManager.resume_game())
	_button(box, "MENÚ", func(): GameManager.go_to_menu(), Color(0.25, 0.4, 0.6))


func _build_over() -> void:
	_over = _make_panel(0.65)
	var box: VBoxContainer = _over.get_meta("box")
	_label(box, "¡FIN DEL JUEGO!", 64, Color(1.0, 0.5, 0.5))
	_over_score = _label(box, "", 50)
	_over_record = _label(box, "¡NUEVO RÉCORD!", 38, Color(1.0, 0.9, 0.3))
	_over_best = _label(box, "", 28, Color(1, 1, 1, 0.8))
	_button(box, "REINTENTAR", _on_play)
	_button(box, "MENÚ", func(): GameManager.go_to_menu(), Color(0.25, 0.4, 0.6))


func _make_panel(dim: float) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.05, 0.12, dim)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	root.set_meta("box", box)
	root.visible = false
	add_child(root)
	return root


func _label(parent: Node, text: String, font_size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.05, 0.15, 0.9))
	l.add_theme_constant_override("outline_size", maxi(font_size / 8, 4))
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable, color: Color = Color(0.1, 0.6, 0.8)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340.0, 84.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 34)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		match st:
			"normal":
				sb.bg_color = color
			"hover":
				sb.bg_color = color.lightened(0.15)
			_:
				sb.bg_color = color.darkened(0.2)
		sb.set_corner_radius_all(22)
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.35)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(_click.bind(cb))
	parent.add_child(b)
	return b


func _click(cb: Callable) -> void:
	Sfx.play("click")
	cb.call()


# --- Eventos -------------------------------------------------------------------
func _on_play() -> void:
	GameManager.start_game()


func _on_toggle_sound() -> void:
	GameManager.set_sound_enabled(not GameManager.sound_enabled)


func _update_sound_text() -> void:
	_sound_btn.text = "SONIDO: SÍ" if GameManager.sound_enabled else "SONIDO: NO"


func _on_score(score: int) -> void:
	_score_label.text = str(score)
	_best_label.text = "Mejor: %d" % GameManager.high_score


func _on_state(s: int) -> void:
	var playing := s == GameManager.State.PLAYING or s == GameManager.State.PAUSED
	_menu.visible = s == GameManager.State.MENU
	_pause.visible = s == GameManager.State.PAUSED
	_controls.visible = playing
	_score_label.visible = playing or s == GameManager.State.GAME_OVER
	_best_label.visible = _score_label.visible
	if s != GameManager.State.GAME_OVER:
		_over.visible = false
		_over_token += 1
	if s == GameManager.State.MENU:
		_menu_best.text = "Mejor puntaje: %d" % GameManager.high_score
	_best_label.text = "Mejor: %d" % GameManager.high_score


func _on_game_over(final_score: int, is_record: bool) -> void:
	_over_token += 1
	var token := _over_token
	await get_tree().create_timer(0.8, true).timeout
	if token != _over_token:
		return
	_over_score.text = "Puntos: %d" % final_score
	_over_record.visible = is_record
	_over_best.text = "Mejor: %d" % GameManager.high_score
	_over.visible = true

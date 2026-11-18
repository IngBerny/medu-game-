extends Control
## TouchControls: HUD de juego (corazones, pausa) y botones táctiles.
##
## - Tocar/mantener en cualquier parte libre de la pantalla = subir.
## - Botón de rayo (abajo-derecha) = descarga eléctrica frontal.
## - Botón de onda (a su izquierda) = descarga circular con recarga larga.
## Cada dedo se asigna a un rol, así se pueden usar varios dedos a la vez.

const BTN_R := 62.0

var player: Node2D

var _rise_finger := -1
var _atk_finger := -1
var _shock_finger := -1
var _heart := PackedVector2Array()
var _bolt := PackedVector2Array([
	Vector2(-8, -28), Vector2(12, -28), Vector2(3, -5), Vector2(17, -5),
	Vector2(-10, 30), Vector2(-2, 3), Vector2(-15, 3)])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		_heart.append(Vector2(x, y) * 1.25)
	GameManager.state_changed.connect(_on_state)


func _on_state(_s: int) -> void:
	_rise_finger = -1
	_atk_finger = -1
	_shock_finger = -1
	if player:
		player.rise_input = false


func _atk_pos() -> Vector2:
	return Vector2(size.x - 105.0, size.y - 105.0)


func _shock_pos() -> Vector2:
	return Vector2(size.x - 255.0, size.y - 90.0)


func _pause_pos() -> Vector2:
	return Vector2(size.x - 56.0, 56.0)


func _input(event: InputEvent) -> void:
	if GameManager.state != GameManager.State.PLAYING or player == null:
		return
	var t := event as InputEventScreenTouch
	if t == null:
		return
	var p := t.position
	if t.pressed:
		if p.distance_to(_atk_pos()) <= BTN_R * 1.3:
			_atk_finger = t.index
			player.attack()
		elif p.distance_to(_shock_pos()) <= BTN_R * 1.3:
			_shock_finger = t.index
			player.shock()
		elif p.distance_to(_pause_pos()) <= 46.0:
			GameManager.pause_game()
		elif _rise_finger == -1:
			_rise_finger = t.index
			player.rise_input = true
	else:
		if t.index == _rise_finger:
			_rise_finger = -1
			player.rise_input = false
		elif t.index == _atk_finger:
			_atk_finger = -1
		elif t.index == _shock_finger:
			_shock_finger = -1


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	# Corazones
	for i in GameManager.MAX_LIVES:
		draw_set_transform(Vector2(46.0 + i * 56.0, 48.0), 0.0, Vector2.ONE)
		if i < GameManager.lives:
			draw_colored_polygon(_heart, Color(1.0, 0.3, 0.42))
			draw_circle(Vector2(-8, -8), 4.0, Color(1, 1, 1, 0.6))
		else:
			draw_colored_polygon(_heart, Color(1, 1, 1, 0.14))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Botón de pausa
	var pc := _pause_pos()
	draw_circle(pc, 30.0, Color(1, 1, 1, 0.18))
	draw_rect(Rect2(pc.x - 10.0, pc.y - 12.0, 7.0, 24.0), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(pc.x + 3.0, pc.y - 12.0, 7.0, 24.0), Color(1, 1, 1, 0.85))

	if player == null:
		return

	# Botón de descarga
	var ac := _atk_pos()
	_draw_action(ac, player.attack_cd_frac(), Color(0.35, 0.85, 1.0), _atk_finger != -1)
	draw_set_transform(ac, 0.0, Vector2(1.0, 1.0))
	draw_colored_polygon(_bolt, Color(1, 1, 1, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Botón de onda
	var sc := _shock_pos()
	_draw_action(sc, player.shock_cd_frac(), Color(1.0, 0.85, 0.3), _shock_finger != -1)
	draw_circle(sc, 6.0, Color(1, 1, 1, 0.95))
	draw_arc(sc, 17.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9), 4.0)
	draw_arc(sc, 29.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)


func _draw_action(c: Vector2, cd: float, col: Color, pressed: bool) -> void:
	var ready := cd <= 0.0
	var fill := 0.45 if pressed else (0.28 if ready else 0.12)
	draw_circle(c, BTN_R, Color(col.r, col.g, col.b, fill))
	draw_arc(c, BTN_R, 0.0, TAU, 44, Color(col.r, col.g, col.b, 0.95 if ready else 0.35), 4.0)
	if not ready:
		draw_arc(c, BTN_R - 9.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - cd), 40,
			Color(1, 1, 1, 0.6), 5.0)

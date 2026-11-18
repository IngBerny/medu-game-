extends Node2D
## Player: el medu (medusa).
##
## - Mantener pulsado = subir; soltar = hundirse suavemente.
## - attack(): descarga eléctrica hacia adelante (destruye basura y peces).
## - shock(): onda eléctrica circular (destruye también minas), con recarga larga.
## - take_hit(): pierde una vida y da invulnerabilidad breve.

const HIT_RADIUS := 20.0
const GRAVITY := 900.0
const THRUST := 1700.0
const MAX_RISE := 420.0
const MAX_FALL := 360.0
const DRAG := 1.4
const MARGIN_Y := 44.0

const ATTACK_DUR := 0.18
const ATTACK_CD := 0.5
const ATTACK_RANGE := 190.0
const ATTACK_HALF_H := 50.0

const SHOCK_DUR := 0.4
const SHOCK_CD := 3.2
const SHOCK_RADIUS := 260.0

const INVULN_TIME := 1.3

var effects: Node2D
var rise_input := false     # lo ponen los controles táctiles (o el bot de pruebas)
var vy := 0.0
var invuln := 0.0
var attack_t := 0.0
var attack_cd := 0.0
var shock_t := 0.0
var shock_cd := 0.0

var _time := 0.0
var _bubble_t := 0.0


func _ready() -> void:
	z_index = 5
	reset()


func reset() -> void:
	var s := GameManager.view_size()
	position = Vector2(_home_x(s), s.y * 0.5)
	vy = 0.0
	invuln = 0.0
	attack_t = 0.0
	attack_cd = 0.0
	shock_t = 0.0
	shock_cd = 0.0
	rise_input = false
	modulate.a = 1.0


func _home_x(s: Vector2) -> float:
	return clampf(s.x * 0.2, 150.0, 380.0)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_time += delta
	var s := GameManager.view_size()
	position.x = lerpf(position.x, _home_x(s), minf(delta * 8.0, 1.0))

	match GameManager.state:
		GameManager.State.PLAYING:
			_play(delta, s)
		GameManager.State.MENU:
			position.y = s.y * 0.5 + sin(_time * 1.6) * 22.0
			vy = 0.0
		GameManager.State.GAME_OVER:
			vy = move_toward(vy, 120.0, 300.0 * delta)
			position.y = minf(position.y + vy * delta, s.y - MARGIN_Y)

	if invuln > 0.0 and GameManager.state == GameManager.State.PLAYING:
		modulate.a = 0.35 if int(_time * 14.0) % 2 == 0 else 0.9
	else:
		modulate.a = 1.0
	queue_redraw()


func _play(delta: float, s: Vector2) -> void:
	attack_t = maxf(attack_t - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	shock_t = maxf(shock_t - delta, 0.0)
	shock_cd = maxf(shock_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)

	var kb := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP) \
		or Input.is_key_pressed(KEY_W)
	if rise_input or kb:
		vy -= THRUST * delta
	else:
		vy += GRAVITY * delta
	vy -= vy * DRAG * delta
	vy = clampf(vy, -MAX_RISE, MAX_FALL)
	position.y += vy * delta

	if position.y < MARGIN_Y:
		position.y = MARGIN_Y
		vy = maxf(vy, 0.0)
	elif position.y > s.y - MARGIN_Y:
		position.y = s.y - MARGIN_Y
		vy = minf(vy, 0.0)

	_bubble_t -= delta
	if _bubble_t <= 0.0 and effects:
		_bubble_t = 0.14
		effects.bubble(position + Vector2(-22.0, 12.0))


func _unhandled_input(event: InputEvent) -> void:
	# Atajos de teclado para probar en computadora.
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_X, KEY_Z, KEY_J:
			attack()
		KEY_C, KEY_K:
			shock()
		KEY_ESCAPE, KEY_P:
			if GameManager.state == GameManager.State.PLAYING:
				GameManager.pause_game()
			elif GameManager.state == GameManager.State.PAUSED:
				GameManager.resume_game()


# --- Acciones ----------------------------------------------------------------
func attack() -> void:
	if GameManager.state != GameManager.State.PLAYING or attack_cd > 0.0:
		return
	attack_t = ATTACK_DUR
	attack_cd = ATTACK_CD
	Sfx.play("zap")
	GameManager.vibrate(15)
	if effects:
		effects.burst(position + Vector2(30.0, 0.0), Color(0.6, 0.95, 1.0), 8, 200.0, 3.5)


func shock() -> void:
	if GameManager.state != GameManager.State.PLAYING or shock_cd > 0.0:
		return
	shock_t = SHOCK_DUR
	shock_cd = SHOCK_CD
	Sfx.play("dash")
	Sfx.play("zap", 2.0, 0.65)
	GameManager.vibrate(40)
	if effects:
		effects.shake.emit(6.0)


func attack_active() -> bool:
	return attack_t > 0.0


## Radio actual de la onda (0 si no está activa).
func shock_radius() -> float:
	if shock_t <= 0.0:
		return 0.0
	var prog := 1.0 - shock_t / SHOCK_DUR
	return lerpf(50.0, SHOCK_RADIUS, prog)


func attack_cd_frac() -> float:
	return clampf(attack_cd / ATTACK_CD, 0.0, 1.0)


func shock_cd_frac() -> float:
	return clampf(shock_cd / SHOCK_CD, 0.0, 1.0)


func take_hit() -> void:
	if invuln > 0.0 or GameManager.state != GameManager.State.PLAYING:
		return
	invuln = INVULN_TIME
	vy = -140.0
	if effects:
		effects.burst(position, Color(1.0, 0.35, 0.35), 18, 260.0, 5.0)
		effects.shake.emit(12.0)
		effects.flash(Color(1.0, 0.1, 0.1), 0.35)
	GameManager.vibrate(80)
	var dead := GameManager.lose_life()
	if dead:
		Sfx.play("gameover")
		GameManager.vibrate(250)
	else:
		Sfx.play("hit")


# --- Dibujo ----------------------------------------------------------------
func _draw() -> void:
	# Onda eléctrica
	if shock_t > 0.0:
		var prog := 1.0 - shock_t / SHOCK_DUR
		var r := shock_radius()
		var a := 1.0 - prog
		draw_circle(Vector2.ZERO, r, Color(0.4, 0.85, 1.0, 0.12 * a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(0.7, 0.95, 1.0, 0.9 * a), 6.0)
		draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.6 * a), 3.0)

	# Rayo hacia adelante
	if attack_t > 0.0:
		var pts := PackedVector2Array()
		pts.append(Vector2(24.0, 0.0))
		var x := 44.0
		while x < ATTACK_RANGE:
			pts.append(Vector2(x, randf_range(-16.0, 16.0)))
			x += 22.0
		pts.append(Vector2(ATTACK_RANGE + 10.0, randf_range(-8.0, 8.0)))
		draw_polyline(pts, Color(0.4, 0.85, 1.0, 0.55), 12.0)
		draw_polyline(pts, Color(0.8, 1.0, 1.0, 1.0), 5.0)
		draw_polyline(pts, Color(1.0, 1.0, 1.0, 1.0), 2.0)

	# Brillo
	var glow := 0.18 + (0.25 if (attack_t > 0.0 or shock_t > 0.0) else 0.0)
	draw_circle(Vector2.ZERO, 50.0, Color(0.95, 0.5, 0.95, glow * 0.6))

	# Tentáculos
	var lean := -vy * 0.025
	for i in 5:
		var x0 := -16.0 + i * 8.0
		var pts2 := PackedVector2Array()
		for seg in 7:
			var f := float(seg)
			pts2.append(Vector2(
				x0 + sin(_time * 6.0 + i * 0.9 + f * 0.8) * (1.0 + f * 0.9),
				4.0 + f * 7.0 + lean * f * 0.5))
		draw_polyline(pts2, Color(0.98, 0.62, 0.96, 0.85), 4.0)

	# Campana
	var pulse := sin(_time * 7.0) * 2.0
	var bell := PackedVector2Array()
	for k in 21:
		var ang := PI * k / 20.0
		bell.append(Vector2(cos(ang) * (28.0 + pulse), -sin(ang) * (24.0 - pulse * 0.5)))
	draw_colored_polygon(bell, Color(0.96, 0.47, 0.92, 0.95))
	var rim := PackedVector2Array()
	for k in 20:
		var ang2 := TAU * k / 20.0
		rim.append(Vector2(cos(ang2) * (28.0 + pulse), sin(ang2) * 5.0))
	draw_colored_polygon(rim, Color(0.9, 0.38, 0.86, 1.0))
	# Brillo de la campana
	draw_circle(Vector2(-10.0, -15.0), 5.0, Color(1.0, 0.8, 0.98, 0.7))
	# Ojos
	draw_circle(Vector2(-9.0, -7.0), 4.0, Color(0.16, 0.08, 0.28))
	draw_circle(Vector2(9.0, -7.0), 4.0, Color(0.16, 0.08, 0.28))
	draw_circle(Vector2(-8.0, -8.3), 1.4, Color.WHITE)
	draw_circle(Vector2(10.0, -8.3), 1.4, Color.WHITE)

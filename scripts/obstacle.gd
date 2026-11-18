extends Node2D
## Obstacle: un solo script para todos los tipos (basura, pez, mina, roca, corazón).
## Los objetos se reutilizan (object pooling): nunca se crean ni destruyen durante la partida.
## No tienen _process propio; el Spawner los mueve con step() en un único bucle.

enum Kind { TRASH, FISH, MINE, ROCK, HEART }

var kind: int = Kind.TRASH
var radius := 24.0
var vx_extra := 0.0   # velocidad extra hacia la izquierda (peces)
var points := 0

var _base_y := 0.0
var _bob_amp := 0.0
var _bob_speed := 0.0
var _age := 0.0
var _phase := 0.0
var _variant := 0
var _rock := PackedVector2Array()


func setup(k: int, x: float, y: float, size_arg: float = 1.0) -> void:
	kind = k
	position = Vector2(x, y)
	_base_y = y
	_age = 0.0
	_phase = randf() * TAU
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	vx_extra = 0.0
	_bob_amp = 0.0
	_variant = randi() % 2
	match k:
		Kind.TRASH:
			radius = 22.0
			points = 10
			rotation = randf_range(-0.5, 0.5)
			_bob_amp = randf_range(4.0, 14.0)
			_bob_speed = randf_range(1.5, 3.0)
		Kind.FISH:
			radius = 24.0
			points = 25
			vx_extra = randf_range(70.0, 160.0)
			_bob_amp = randf_range(20.0, 60.0)
			_bob_speed = randf_range(1.5, 3.5)
		Kind.MINE:
			radius = 26.0
			points = 40
			_bob_amp = randf_range(6.0, 16.0)
			_bob_speed = randf_range(1.0, 2.0)
		Kind.ROCK:
			radius = size_arg * 0.92
			points = 0
			_build_rock(size_arg)
		Kind.HEART:
			radius = 22.0
			points = 0
			_bob_amp = 10.0
			_bob_speed = 2.5
	visible = true
	queue_redraw()


func step(delta: float, speed: float) -> void:
	_age += delta
	position.x -= (speed + vx_extra) * delta
	if _bob_amp > 0.0:
		position.y = _base_y + sin(_age * _bob_speed + _phase) * _bob_amp
	match kind:
		Kind.MINE:
			rotation += 0.6 * delta
			var b := 1.0 + 0.2 * sin(_age * 7.0)
			modulate = Color(b, b * 0.9, b * 0.9)
		Kind.TRASH:
			rotation += sin(_age * 2.0 + _phase) * 0.4 * delta
		Kind.HEART:
			var s := 1.0 + 0.12 * sin(_age * 6.0)
			scale = Vector2(s, s)
		Kind.FISH:
			rotation = cos(_age * _bob_speed + _phase) * 0.18


## La descarga frontal destruye basura y peces.
func can_attack_destroy() -> bool:
	return kind == Kind.TRASH or kind == Kind.FISH


## La onda circular destruye todo menos rocas y corazones.
func can_shock_destroy() -> bool:
	return kind != Kind.ROCK and kind != Kind.HEART


func fx_color() -> Color:
	match kind:
		Kind.TRASH:
			return Color(0.8, 0.95, 1.0)
		Kind.FISH:
			return Color(1.0, 0.5, 0.3)
		Kind.MINE:
			return Color(1.0, 0.7, 0.2)
		Kind.HEART:
			return Color(1.0, 0.5, 0.7)
	return Color(0.5, 0.6, 0.8)


# --- Dibujo ------------------------------------------------------------------
func _ellipse(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _build_rock(r: float) -> void:
	_rock = PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := 14
	for i in n:
		var a := TAU * i / n
		var rr := r * rng.randf_range(0.85, 1.08)
		_rock.append(Vector2(cos(a), sin(a)) * rr)


func _draw() -> void:
	match kind:
		Kind.TRASH:
			_draw_trash()
		Kind.FISH:
			_draw_fish()
		Kind.MINE:
			_draw_mine()
		Kind.ROCK:
			_draw_rock()
		Kind.HEART:
			_draw_heart()


func _draw_trash() -> void:
	if _variant == 0:
		# Bolsa de plástico
		draw_colored_polygon(_ellipse(Vector2(0, 3), 18.0, 22.0), Color(0.85, 0.93, 0.97, 0.72))
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -14), Vector2(-16, -30), Vector2(-4, -18)]),
			Color(0.85, 0.93, 0.97, 0.72))
		draw_colored_polygon(PackedVector2Array([Vector2(12, -14), Vector2(16, -30), Vector2(4, -18)]),
			Color(0.85, 0.93, 0.97, 0.72))
		draw_arc(Vector2(0, 3), 18.0, 0.0, TAU, 24, Color(1, 1, 1, 0.55), 2.0)
		draw_line(Vector2(-6, -6), Vector2(-2, 14), Color(1, 1, 1, 0.5), 3.0)
	else:
		# Botella
		draw_rect(Rect2(-10, -20, 20, 40), Color(0.6, 0.85, 0.95, 0.75))
		draw_rect(Rect2(-5, -30, 10, 12), Color(0.6, 0.85, 0.95, 0.75))
		draw_rect(Rect2(-6, -35, 12, 6), Color(0.9, 0.25, 0.25))
		draw_rect(Rect2(-10, -4, 20, 12), Color(0.95, 0.95, 0.95, 0.65))
		draw_line(Vector2(-6, -16), Vector2(-6, 14), Color(1, 1, 1, 0.5), 2.5)


func _draw_fish() -> void:
	# Mira hacia la izquierda (avanza hacia el jugador).
	draw_colored_polygon(PackedVector2Array([Vector2(26, 0), Vector2(50, -18), Vector2(50, 18)]),
		Color(0.75, 0.2, 0.18))
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -16), Vector2(12, -32), Vector2(18, -14)]),
		Color(0.75, 0.2, 0.18))
	draw_colored_polygon(_ellipse(Vector2.ZERO, 32.0, 19.0), Color(0.95, 0.35, 0.25))
	draw_colored_polygon(_ellipse(Vector2(-2, 7), 24.0, 9.0), Color(1.0, 0.7, 0.5, 0.9))
	# Ojo enojado
	draw_circle(Vector2(-18, -5), 6.0, Color.WHITE)
	draw_circle(Vector2(-20, -5), 3.0, Color(0.1, 0.05, 0.1))
	draw_line(Vector2(-27, -13), Vector2(-12, -8), Color(0.35, 0.05, 0.05), 3.0)
	# Dientes
	for i in 3:
		var tx := -30.0 + i * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx, 4), Vector2(tx + 6, 4), Vector2(tx + 3, 10)]),
			Color.WHITE)


func _draw_mine() -> void:
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector2(cos(a), sin(a))
		draw_line(d * 18.0, d * 30.0, Color(0.5, 0.52, 0.6), 5.0)
		draw_circle(d * 31.0, 4.0, Color(0.95, 0.3, 0.2))
	draw_circle(Vector2.ZERO, 21.0, Color(0.2, 0.22, 0.3))
	draw_circle(Vector2(-6, -7), 8.0, Color(0.34, 0.37, 0.48))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.25, 0.2))


func _draw_rock() -> void:
	draw_colored_polygon(_rock, Color(0.1, 0.17, 0.28))
	var hl := PackedVector2Array()
	for p in _rock:
		hl.append(p * 0.72 + Vector2(-radius * 0.1, -radius * 0.14))
	draw_colored_polygon(hl, Color(0.16, 0.26, 0.4, 0.85))
	var outline := _rock.duplicate()
	outline.append(_rock[0])
	draw_polyline(outline, Color(0.35, 0.5, 0.65, 0.5), 3.0)


func _draw_heart() -> void:
	draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.5, 0.7, 0.18))
	var pts := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y) * 1.1)
	draw_colored_polygon(pts, Color(1.0, 0.3, 0.5))
	draw_circle(Vector2(-7, -6), 3.5, Color(1, 1, 1, 0.7))

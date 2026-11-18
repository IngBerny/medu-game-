extends Node2D
## Background: fondo marino dibujado por código (sin imágenes), con parallax.

const N_BUBBLES := 28

var _scroll := 0.0
var _time := 0.0
var _bubbles: Array = []   # Vector4(x_norm, y_norm, radio, velocidad)


func _ready() -> void:
	z_index = -10
	for i in N_BUBBLES:
		_bubbles.append(Vector4(randf(), randf(), randf_range(2.0, 7.0), randf_range(15.0, 50.0)))


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	var speed := GameManager.game_speed if GameManager.state == GameManager.State.PLAYING else 70.0
	_scroll += speed * delta
	_time += delta
	var h := GameManager.view_size().y
	for i in _bubbles.size():
		var b: Vector4 = _bubbles[i]
		b.y -= b.w * delta / h
		b.x -= speed * 0.05 * delta / GameManager.view_size().x
		if b.y < -0.05:
			b.y = 1.05
			b.x = randf()
		if b.x < -0.05:
			b.x = 1.05
		_bubbles[i] = b
	queue_redraw()


func _draw() -> void:
	var s := GameManager.view_size()
	# Degradado de agua
	var top := Color(0.05, 0.42, 0.66)
	var mid := Color(0.03, 0.22, 0.42)
	var bot := Color(0.01, 0.06, 0.18)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.5), Vector2(0, s.y * 0.5)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.5), Vector2(s.x, s.y * 0.5), Vector2(s.x, s.y), Vector2(0, s.y)]),
		PackedColorArray([mid, mid, bot, bot]))

	# Rayos de luz
	for i in 5:
		var x := fmod(i * s.x * 0.28 + _time * 12.0, s.x + 300.0) - 150.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 0), Vector2(x + 70, 0), Vector2(x - 90, s.y), Vector2(x - 230, s.y)]),
			Color(0.9, 1.0, 1.0, 0.035))

	# Colinas lejanas y cercanas
	_hills(s, 0.15, 0.80, 40.0, Color(0.02, 0.14, 0.30), 0.004)
	_hills(s, 0.35, 0.90, 36.0, Color(0.02, 0.10, 0.22), 0.006)

	# Algas
	var n := int(s.x / 190.0) + 3
	for i in n:
		var x2 := posmod(i * 190.0 - _scroll * 0.7, s.x + 380.0) - 190.0
		var pts := PackedVector2Array()
		for k in 6:
			var f := float(k)
			pts.append(Vector2(x2 + sin(_time * 1.6 + i + f * 0.7) * 5.0 * f, s.y + 5.0 - f * 24.0))
		draw_polyline(pts, Color(0.1, 0.45, 0.35, 0.8), 8.0)

	# Burbujas
	for b in _bubbles:
		var p := Vector2(b.x * s.x, b.y * s.y)
		draw_circle(p, b.z, Color(1, 1, 1, 0.12))
		draw_arc(p, b.z, 0.0, TAU, 12, Color(1, 1, 1, 0.25), 1.2)


func _hills(s: Vector2, parallax: float, base_frac: float, amp: float, col: Color, freq: float) -> void:
	var pts := PackedVector2Array()
	var off := _scroll * parallax
	var x := 0.0
	while x <= s.x + 32.0:
		var u := (x + off) * freq
		var y := s.y * base_frac + sin(u) * amp + sin(u * 2.3) * amp * 0.4
		pts.append(Vector2(x, y))
		x += 32.0
	pts.append(Vector2(s.x + 32.0, s.y + 10.0))
	pts.append(Vector2(0.0, s.y + 10.0))
	draw_colored_polygon(pts, col)

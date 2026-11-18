extends Node2D
## Effects: partículas (chispas y burbujas), textos flotantes y destello de pantalla.
## Usa un buffer circular de tamaño fijo: no se crean nodos ni objetos nuevos.

signal shake(amount: float)

const MAX := 200

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _col := PackedColorArray()
var _kind := PackedInt32Array()   # 0 = chispa, 1 = burbuja
var _head := 0
var _texts: Array = []            # [pos, texto, vida, color]
var _flash := 0.0
var _flash_col := Color.RED


func _ready() -> void:
	z_index = 20
	_pos.resize(MAX)
	_vel.resize(MAX)
	_life.resize(MAX)
	_max_life.resize(MAX)
	_size.resize(MAX)
	_col.resize(MAX)
	_kind.resize(MAX)
	for i in MAX:
		_life[i] = 0.0
		_max_life[i] = 1.0


func _spawn(pos: Vector2, vel: Vector2, life: float, size: float, col: Color, kind: int) -> void:
	var i := _head
	_head = (_head + 1) % MAX
	_pos[i] = pos
	_vel[i] = vel
	_life[i] = life
	_max_life[i] = life
	_size[i] = size
	_col[i] = col
	_kind[i] = kind


func burst(pos: Vector2, color: Color, count: int, speed: float, size: float) -> void:
	for i in count:
		var ang := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_spawn(pos, Vector2(cos(ang), sin(ang)) * sp, randf_range(0.3, 0.7),
			randf_range(0.5, 1.0) * size, color, 0)


func bubble(pos: Vector2) -> void:
	_spawn(pos, Vector2(randf_range(-30.0, -10.0), randf_range(-35.0, -10.0)),
		randf_range(0.8, 1.4), randf_range(2.0, 5.0), Color(1, 1, 1, 0.5), 1)


func text(pos: Vector2, s: String, color: Color = Color.WHITE) -> void:
	if _texts.size() < 12:
		_texts.append([pos, s, 0.8, color])


func flash(color: Color, alpha: float) -> void:
	_flash_col = color
	_flash = alpha


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	for i in MAX:
		if _life[i] <= 0.0:
			continue
		_life[i] -= delta
		_pos[i] += _vel[i] * delta
		if _kind[i] == 0:
			_vel[i] *= maxf(1.0 - 2.5 * delta, 0.0)
		else:
			_vel[i].y -= 25.0 * delta
	for j in range(_texts.size() - 1, -1, -1):
		var t: Array = _texts[j]
		t[0] = t[0] + Vector2(0.0, -55.0 * delta)
		t[2] = t[2] - delta
		if t[2] <= 0.0:
			_texts.remove_at(j)
	_flash = maxf(_flash - delta * 1.2, 0.0)
	queue_redraw()


func _draw() -> void:
	for i in MAX:
		if _life[i] <= 0.0:
			continue
		var f := _life[i] / _max_life[i]
		var c := _col[i]
		c.a *= clampf(f * 1.6, 0.0, 1.0)
		if _kind[i] == 0:
			draw_circle(_pos[i], _size[i] * (0.4 + 0.6 * f), c)
		else:
			draw_arc(_pos[i], _size[i], 0.0, TAU, 10, c, 1.5)
	var font := ThemeDB.fallback_font
	for t in _texts:
		var col: Color = t[3]
		col.a = clampf(t[2] * 2.0, 0.0, 1.0)
		draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_CENTER, -1, 34, col)
	if _flash > 0.0:
		var s := GameManager.view_size()
		draw_rect(Rect2(-80, -80, s.x + 160, s.y + 160),
			Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash))

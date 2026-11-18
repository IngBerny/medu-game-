extends Node2D
## ObstacleSpawner
##
## - Mantiene un POOL fijo de obstáculos reutilizables (sin instanciar durante el juego).
## - Un único bucle mueve todos los obstáculos activos y resuelve colisiones y ataques.
## - La dificultad sube con GameManager.difficulty (más velocidad, más minas/rocas, menos pausa).

const ObstacleScript := preload("res://scripts/obstacle.gd")
const Kind := ObstacleScript.Kind
const POOL_SIZE := 28

var player: Node2D
var effects: Node2D
var pool: Array = []     # inactivos
var active: Array = []   # en pantalla
var _timer := 1.5


func _ready() -> void:
	z_index = 2
	for i in POOL_SIZE:
		var o: Node2D = ObstacleScript.new()
		o.visible = false
		add_child(o)
		pool.append(o)


func clear() -> void:
	for i in range(active.size() - 1, -1, -1):
		_release(i)
	_timer = 1.5


func _process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING or player == null:
		return
	delta = minf(delta, 0.05)
	_timer -= delta
	if _timer <= 0.0:
		_spawn_wave()
	_update(delta, GameManager.game_speed)


# --- Aparición ----------------------------------------------------------------
func _spawn_wave() -> void:
	var d := GameManager.difficulty
	var base := lerpf(1.5, 0.55, d)
	if GameManager.elapsed < 8.0:
		base *= 1.25
	_timer = base * randf_range(0.8, 1.25)

	var s := GameManager.view_size()
	_spawn_one(s, 0.0)
	# A mayor dificultad, a veces aparece un segundo obstáculo cercano.
	if randf() < d * 0.5:
		_spawn_one(s, randf_range(160.0, 280.0))


func _spawn_one(s: Vector2, x_offset: float) -> void:
	if pool.is_empty():
		return
	var d := GameManager.difficulty
	var early := GameManager.elapsed < 8.0
	var w_rock := 0.0 if early else 0.14 + 0.08 * d
	var w_mine := 0.0 if early else 0.08 + 0.18 * d
	var w_fish := 0.28 + 0.10 * d
	var w_heart := 0.05 if GameManager.lives < GameManager.MAX_LIVES else 0.0

	var r := randf()
	var kind: int = Kind.TRASH
	if r < w_rock:
		kind = Kind.ROCK
	elif r < w_rock + w_mine:
		kind = Kind.MINE
	elif r < w_rock + w_mine + w_fish:
		kind = Kind.FISH
	elif r < w_rock + w_mine + w_fish + w_heart:
		kind = Kind.HEART

	var o: Node2D = pool.pop_back()
	var x := s.x + 70.0 + x_offset
	var y := randf_range(80.0, s.y - 80.0)
	var size_arg := 1.0
	if kind == Kind.ROCK:
		size_arg = randf_range(55.0, 95.0 + 30.0 * d)
		if randf() < 0.5:
			y = size_arg * 0.35 - 10.0           # techo
		else:
			y = s.y - size_arg * 0.35 + 10.0     # suelo
		x += size_arg
	o.setup(kind, x, y, size_arg)
	active.append(o)


# --- Actualización y colisiones ---------------------------------------------------
func _update(delta: float, speed: float) -> void:
	var ppos := player.position
	var atk: bool = player.attack_active()
	var rect := Rect2(ppos.x + 14.0, ppos.y - player.ATTACK_HALF_H,
		player.ATTACK_RANGE, player.ATTACK_HALF_H * 2.0)
	var shock_r: float = player.shock_radius()

	for i in range(active.size() - 1, -1, -1):
		var o: Node2D = active[i]
		o.step(delta, speed)
		if o.position.x < -o.radius * 2.0 - 90.0:
			_release(i)
			continue

		if shock_r > 0.0 and o.can_shock_destroy() \
				and ppos.distance_to(o.position) <= shock_r + o.radius:
			_destroy(i, true)
			continue
		if atk and o.can_attack_destroy() and _circle_rect(o.position, o.radius, rect):
			_destroy(i, true)
			continue

		if ppos.distance_to(o.position) < o.radius + player.HIT_RADIUS:
			if o.kind == Kind.HEART:
				GameManager.heal()
				Sfx.play("heal")
				effects.burst(o.position, Color(1.0, 0.5, 0.7), 12, 200.0, 4.0)
				effects.text(o.position, "+1", Color(1.0, 0.6, 0.75))
				_release(i)
			elif player.invuln <= 0.0:
				player.take_hit()
				if o.kind != Kind.ROCK:
					_destroy(i, false)


func _destroy(i: int, scored: bool) -> void:
	var o: Node2D = active[i]
	effects.burst(o.position, o.fx_color(), 14, 280.0, 5.0)
	if scored:
		GameManager.add_score(o.points)
		effects.text(o.position, "+%d" % o.points, Color(1.0, 0.95, 0.5))
		Sfx.play("pop", 0.0, randf_range(0.9, 1.15))
		GameManager.vibrate(12)
	_release(i)


func _release(i: int) -> void:
	var o: Node2D = active[i]
	active.remove_at(i)
	o.visible = false
	pool.append(o)


static func _circle_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nx := clampf(c.x, rect.position.x, rect.end.x)
	var ny := clampf(c.y, rect.position.y, rect.end.y)
	return c.distance_squared_to(Vector2(nx, ny)) <= r * r

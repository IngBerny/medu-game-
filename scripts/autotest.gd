extends Node
## Prueba automática (humo) para CI:
##   godot --headless --fixed-fps 60 --path . -- --autotest
## Juega con un bot, verifica reglas básicas y termina con código 0 (OK) o 1 (falla).

var main: Node
var _errors: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_errors.append(msg)
		printerr("AUTOTEST FALLO: ", msg)


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var S = GameManager.State

	# 1) Morir: 3 golpes -> game over y récord guardado
	GameManager.start_game()
	await get_tree().process_frame
	_check(GameManager.state == S.PLAYING, "start_game -> PLAYING")
	_check(GameManager.lives == 3, "3 vidas al empezar")
	GameManager.add_score(50)
	for i in 3:
		main.player.invuln = 0.0
		main.player.take_hit()
	_check(GameManager.lives == 0, "0 vidas tras 3 golpes")
	_check(GameManager.state == S.GAME_OVER, "estado GAME_OVER")
	_check(GameManager.high_score >= 50, "high score actualizado")
	GameManager.high_score = 0
	GameManager._save_data()

	# 2) Pausa / reanudar
	GameManager.start_game()
	await get_tree().process_frame
	GameManager.pause_game()
	_check(get_tree().paused and GameManager.state == S.PAUSED, "pausa")
	GameManager.resume_game()
	_check(not get_tree().paused and GameManager.state == S.PLAYING, "reanudar")

	# 3) Bot jugando 45 s de juego
	var frames := 0
	while GameManager.state == S.PLAYING and GameManager.elapsed < 45.0:
		await get_tree().process_frame
		_bot()
		frames += 1
		if frames % 60 == 0:
			var sp = main.spawner
			_check(sp.pool.size() + sp.active.size() == sp.POOL_SIZE, "pool íntegro")
			_check(sp.active.size() <= sp.POOL_SIZE, "activos <= pool")
	_check(GameManager.score > 0, "el puntaje subió")
	_check(GameManager.game_speed > GameManager.START_SPEED or GameManager.elapsed < 5.0,
		"la velocidad aumenta")

	var ok := _errors.is_empty()
	print("AUTOTEST ", "OK" if ok else "FALLO", " | tiempo=%.1fs puntos=%d vidas=%d velocidad=%.0f" % [
		GameManager.elapsed, GameManager.score, GameManager.lives, GameManager.game_speed])
	get_tree().quit(0 if ok else 1)


func _bot() -> void:
	var p = main.player
	var h := GameManager.view_size().y
	var target := h * 0.5
	for o in main.spawner.active:
		var dx: float = o.position.x - p.position.x
		if dx < -40.0 or dx > 420.0:
			continue
		var dy: float = o.position.y - p.position.y
		if o.kind == 3 or o.kind == 2:   # roca o mina: esquivar
			if absf(dy) < o.radius + 70.0:
				target = o.position.y + (o.radius + 100.0) * (1.0 if o.position.y < h * 0.5 else -1.0)
		elif o.can_attack_destroy() and dx < 230.0 and absf(dy) < 45.0:
			p.attack()
	target = clampf(target, 60.0, h - 60.0)
	p.rise_input = p.position.y > target + 10.0

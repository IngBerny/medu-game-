extends Node2D
## Main: arma la escena completa por código y conecta las piezas.
##   Background -> World(Spawner, Player, Effects) -> UI (CanvasLayer)

var background: Node2D
var world: Node2D
var spawner: Node2D
var player: Node2D
var effects: Node2D
var ui: CanvasLayer
var _shake := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.02, 0.1, 0.2))

	background = preload("res://scripts/background.gd").new()
	add_child(background)

	world = Node2D.new()
	add_child(world)
	spawner = preload("res://scripts/obstacle_spawner.gd").new()
	player = preload("res://scripts/player.gd").new()
	effects = preload("res://scripts/effects.gd").new()
	world.add_child(spawner)
	world.add_child(player)
	world.add_child(effects)
	spawner.player = player
	spawner.effects = effects
	player.effects = effects
	effects.shake.connect(_on_shake)

	ui = preload("res://scripts/ui.gd").new()
	ui.player = player
	add_child(ui)

	GameManager.game_started.connect(_reset_world)
	GameManager.state_changed.connect(_on_state)

	if "--autotest" in OS.get_cmdline_user_args():
		var t := Node.new()
		t.set_script(preload("res://scripts/autotest.gd"))
		t.set("main", self)
		add_child(t)


func _process(delta: float) -> void:
	if _shake > 0.0:
		world.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
		_shake = move_toward(_shake, 0.0, 40.0 * delta)
	else:
		world.position = Vector2.ZERO


func _on_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _reset_world() -> void:
	spawner.clear()
	player.reset()
	Sfx.play("start")


func _on_state(s: int) -> void:
	if s == GameManager.State.MENU:
		spawner.clear()
		player.reset()

extends SceneTree
## Fonte S3/Main real, sem build S2. Entrada sintética e reposicionamento de ensaio.
## Sem legendas diagnósticas: apresentação capturada é o HUD e o menu do jogo.

const MAIN := preload("res://src/game/main.tscn")
const ENEMY := preload("res://src/enemies/melee_chaser.tscn")
const Ticks := preload("res://tests/fixtures/s3_native_ticks.gd")
const NAMES := ["01-nascimento", "02-preparacao", "03-ativo-dano", "04-recuperacao", "05-protecao", "06-pausa", "07-reinicio", "08-sobreposicao", "09-vitoria", "10-derrota", "11-reinicio-final"]
var destination: String
var target: Vector2i
var load_count: int
var failed := false
var checks := 0
var main: Node2D
var arena: Node2D
var player: CharacterBody2D
var enemies: Array[Node] = []
var captures: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		failed = true
		printerr("CAPTURE_FAIL: ", message)
	return value

func _run() -> void:
	create_timer(25.0, true, false, true).timeout.connect(func() -> void:
		printerr("CAPTURE_WATCHDOG")
		quit(1))
	var args := OS.get_cmdline_user_args()
	if not _check(args.size() == 3 and args[0] in ["720", "1080"] and args[1] in ["3", "12"] and args[2].is_valid_identifier() and args[2].length() <= 48,
			"argumentos fechados:720/1080 3/12 identificador novo"):
		quit(1)
		return
	destination = "res://.tools/s3/unit2-capture-" + args[2]
	# Destino ocupado (arquivo ou diretório) é recusado antes de qualquer gravação.
	if not _reserve_destination():
		quit(1)
		return
	if not _check(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility", "janela Compatibility real"):
		quit(1)
		return
	target = Vector2i(1280, 720) if args[0] == "720" else Vector2i(1920, 1080)
	load_count = int(args[1])
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = target
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	paused = false
	main = MAIN.instantiate()
	root.add_child(main)
	_prepare()
	if not await _capture(NAMES[0]): return
	_cluster(3)
	if not await _ticks(12): return
	_check(enemies[0].action_state.phase == 1 and player.health.current == 100, "aviso real sem dano")
	if not await _capture(NAMES[1]): return
	if not await _ticks(25): return
	_check(enemies[0].active_snapshot and player.health.current == 70, "três acertos reais100 para70")
	if not await _capture(NAMES[2]): return
	if not await _ticks(8): return
	_check(enemies[0].action_state.phase == 3 and player.health.current == 70, "recuperação sem repetição")
	if not await _capture(NAMES[3]): return
	await _restart()
	_cluster(3)
	if not await _ticks(36): return
	player.apply_intent(Vector2.ZERO, Vector2.UP)
	player.queue_actions(false, true)
	if not await _ticks(1): return
	_check(player.action_state.invulnerable and player.health.current == 100, "proteção real recusa ataques")
	if not await _capture(NAMES[4]): return
	main.set_paused(true)
	if not await _capture(NAMES[5]): return
	await _restart()
	if not await _capture(NAMES[6]): return
	_cluster(load_count)
	if not await _ticks(12): return
	if not await _capture(NAMES[7]): return
	# Voltar à composição canônica antes de provar resultados do encontro3.
	await _restart()
	for enemy: Node in enemies:
		_check(enemy.receive_hit(30), "últimas mortes válidas no encontro real")
	_check(arena.state == "completed", "vitória real")
	if not await _capture(NAMES[8]): return
	await _restart()
	_check(player.receive_hit(100) and arena.state == "defeat", "derrota real")
	if not await _capture(NAMES[9]): return
	await _restart()
	_check(player.health.current == 100 and arena.remaining == 3, "reinício restaura3 e100")
	if not await _capture(NAMES[10]): return
	if not _save_manifest():
		quit(1)
		return
	arena.shutdown()
	main.free()
	print("S3 ENCOUNTER CAPTURE: %d checks; failed=%s; destination=%s" % [checks, failed, destination])
	quit(1 if failed else 0)

func _reserve_destination() -> bool:
	if not _check(not FileAccess.file_exists(destination) and not DirAccess.dir_exists_absolute(destination), "destino ocupado; nenhum IO autorizado"):
		return false
	return _check(DirAccess.make_dir_recursive_absolute(destination) == OK, "reservar destino novo")

func _prepare() -> void:
	arena = main.get_node("FirstEncounter")
	_freeze(arena)
	player = arena.get_node("Actors/Player")
	player.audio_enabled = false
	arena.get_node("PlayerInput").set_focus_active(true)
	main.set_paused(false)
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	enemies.clear()
	for name: String in ["Enemy1", "Enemy2", "Enemy3"]:
		enemies.append(arena.get_node("Actors/" + name))
	player.get_node("Camera2D").force_update_scroll()
	arena.refresh_status()

func _restart() -> void:
	main.restart_encounter()
	await process_frame
	_prepare()

func _cluster(count: int) -> void:
	# Ensaio12 separado: nove corpos extras fora da contagem canônica. Sem dano
	# acelerado ou mudança de desenho/regra U1; só esta prova usa esse arranjo.
	for index: int in range(enemies.size(), count):
		var enemy := ENEMY.instantiate()
		enemy.set_physics_process(false)
		arena.get_node("Actors").add_child(enemy)
		_check(enemy.set_target(player), "alvo do corpo extra de ensaio")
		enemy.set_encounter_enabled(true)
		enemies.append(enemy)
	for index: int in range(count):
		var angle := TAU * float(index) / count
		enemies[index].position = player.position + Vector2.from_angle(angle) * 45.0
		enemies[index].interrupt_actions()

func _freeze(node: Node) -> void:
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _ticks(count: int) -> bool:
	var actors: Array[Node] = [player]
	actors.append_array(enemies)
	if not _check(await Ticks.run(self, actors, count), "orçamento físico exato"):
		quit(1)
		return false
	return true

func _capture(name: String) -> bool:
	arena.refresh_status()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not _check(image != null and image.get_size() == target, "dimensões nativas exatas"):
		quit(1)
		return false
	if not _write_png(image, destination.path_join(name + ".png")):
		quit(1)
		return false
	var phases: Array[int] = []
	for enemy: Node in enemies:
		phases.append(enemy.action_state.phase)
	captures.append({"name": name, "life": player.health.current, "remaining": arena.remaining, "state": arena.state,
		"paused": paused, "enemies": enemies.size(), "phases": phases})
	return true

func _write_png(image: Image, path: String) -> bool:
	# Guarda também reavaliada no PNG tardio; não promete atomicidade/reparse.
	if not _check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path), "PNG ocupado; preservar bytes"):
		return false
	return _check(image.save_png(path) == OK, "gravação PNG")

func _save_manifest() -> bool:
	var path := destination.path_join("captures.json")
	if not _check(not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path), "manifesto novo"):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "manifesto gravável"):
		return false
	file.store_string(JSON.stringify({"source": "S3 Main", "version": ProjectSettings.get_setting("application/config/version"),
		"viewport": [target.x, target.y], "stress_count": load_count, "captures": captures, "checks": checks, "failed": failed}, "\t"))
	file.close()
	return true

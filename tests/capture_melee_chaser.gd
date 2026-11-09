extends SceneTree
## Prova nativa isolada da fonte S3, não da Main/build S2. Sem entrada física,
## áudio, arte final ou aceite humano. Usa callbacks físicos reais do teste U1.

const Physics := preload("res://tests/integration/test_melee_chaser.gd")
const PLAYER := preload("res://src/player/player.tscn")
const ENEMY := preload("res://src/enemies/melee_chaser.tscn")
var failed: bool = false
var checks: int = 0
var destination: String
var note: Label
var status: Label
var player: CharacterBody2D
var enemy: CharacterBody2D
var captures: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		printerr("CAPTURE_FAIL: ", message)


func _label(position: Vector2, text: String, font_size: int = 20) -> Label:
	var label := Label.new()
	label.position = position
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f4d8a5"))
	label.add_theme_color_override("font_outline_color", Color("182d36"))
	label.add_theme_constant_override("outline_size", 3)
	root.add_child(label)
	return label


func _run() -> void:
	create_timer(25.0, true, false, true).timeout.connect(func() -> void:
		printerr("CAPTURE_WATCHDOG")
		quit(1))
	var args := OS.get_cmdline_user_args()
	_check(args.size() == 1 and args[0] in ["720", "1080"], "argumento permitido720/1080")
	_check(DisplayServer.get_name() != "headless"
		and RenderingServer.get_current_rendering_method() == "gl_compatibility", "janela Compatibility real")
	if failed:
		quit(1)
		return
	var target := Vector2i(1280, 720) if args[0] == "720" else Vector2i(1920, 1080)
	# Somente caminho fixo local + valores permitidos + relógio; sem caminho externo.
	destination = "res://.tools/s3/unit1-capture-%s-%d" % [args[0], Time.get_ticks_usec()]
	if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination):
		_check(false, "destino ocupado; nenhum arquivo foi gravado")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		_check(false, "falha ao reservar destino novo")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = target
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	paused = false
	var floor := Polygon2D.new()
	floor.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)])
	floor.color = Color(0.49, 0.45, 0.36)
	root.add_child(floor)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	root.add_child(actors)
	player = PLAYER.instantiate()
	player.set_physics_process(false)
	player.audio_enabled = false
	player.position = Vector2(790, 420)
	actors.add_child(player)
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	enemy = ENEMY.instantiate()
	enemy.set_physics_process(false)
	enemy.position = Vector2(590, 420)
	actors.add_child(enemy)
	_check(enemy.set_target(player), "alvo real válido")
	enemy.set_encounter_enabled(true)
	_label(Vector2(32, 24), "Último Sol · S3 · Perseguidor isolado", 30)
	_label(Vector2(32, 68), "BLOCKOUT TEMPORÁRIO · FONTE ATUAL · CAPTURA AUTOMATIZADA", 17)
	note = _label(Vector2(32, 124), "", 25)
	status = _label(Vector2(32, 169), "", 20)
	_label(Vector2(32, 550), "AVISO: braços retraídos + chevron + setor vazio\nATIVO: braços estendidos + setor hachurado\nRECUPERAÇÃO: braços baixos + duas barras", 20)
	_label(Vector2(32, 655), "Sem som · Não comprova hardware, diversão ou aceite humano. Alcance60 / setor90°.", 17)
	_check(await _ticks(20), "perseguição nativa")
	if not await _capture("01-perseguicao", "PERSEGUIÇÃO · aproximação direta com colisão", target):
		return
	enemy.position = Vector2(590, 420)
	player.position = Vector2(635, 420)
	_check(await _ticks(12), "preparação0,20")
	_check(player.health.current == 100 and enemy.action_state.phase == 1, "aviso sem dano")
	if not await _capture("02-preparacao", "PREPARAÇÃO · direção fixada / jogador100", target):
		return
	_check(await _ticks(25), "chegada ao ativo0,6167")
	_check(player.health.current == 90 and enemy.active_snapshot, "receive_hit real100 para90")
	if not await _capture("03-ativo-dano", "ATIVO · acerto100 → 90 / reação local real", target):
		return
	_check(await _ticks(8), "recuperação0,75")
	_check(enemy.action_state.phase == 3 and player.health.current == 90, "recuperação sem duplicação")
	if not await _capture("04-recuperacao", "RECUPERAÇÃO · sem novo dano / direção ainda fixada", target):
		return
	enemy.interrupt_actions()
	_check(await _ticks(36), "nova preparação completa após interrupção")
	player.queue_actions(false, true)
	_check(await _ticks(1), "esquiva nativa na primeira amostra ativa")
	_check(player.health.current == 90 and player.action_state.invulnerable, "proteção real recusa dano")
	if not await _capture("05-protecao", "PROTEÇÃO · esquiva recusa golpe / vida permanece90", target):
		return
	player.interrupt_actions()
	enemy.interrupt_actions()
	player.position = Vector2(545, 420)
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	for strike in range(3):
		player.queue_actions(true, false)
		_check(await _ticks(17), "cassetete nativo " + str(strike + 1))
		_check(enemy.health.current == 20 - strike * 10, "vida inimiga por cassetete real")
		if not await _capture("0%d-cassetete-%d" % [6 + strike, strike + 1],
				"CASSETETE · golpe%d / inimigo%d de30" % [strike + 1, enemy.health.current], target):
			return
	_check(enemy.health.dead and enemy.collision_layer == 0, "cadáver sem colisão")
	var manifest_path := destination.path_join("captures.json")
	if FileAccess.file_exists(manifest_path) or DirAccess.dir_exists_absolute(manifest_path):
		_check(false, "manifesto ocupado")
		quit(1)
		return
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		_check(false, "manifesto não pôde ser criado")
		quit(1)
		return
	file.store_string(JSON.stringify({"viewport": target, "captures": captures, "checks": checks,
		"failed": failed, "engine": Engine.get_version_info().string}, "\t"))
	file.close()
	print("S3 CAPTURE: %d verificações; falha=%s; destino=%s" % [checks, failed, destination])
	actors.free()
	quit(1 if failed else 0)


func _ticks(count: int) -> bool:
	return await Physics.new()._run_ticks(self, [player, enemy], count, Callable(), Callable())


func _capture(name: String, title: String, target: Vector2i) -> bool:
	note.text = title
	status.text = "Jogador %d/100     Inimigo %d/30     Serial %d     Fase %d" % [
		player.health.current, enemy.health.current, enemy.action_state.attack_serial, enemy.action_state.phase]
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and image.get_size() == target, "dimensões nativas exatas")
	if image == null or image.get_size() != target:
		quit(1)
		return false
	var path := destination.path_join(name + ".png")
	# Recusa colisões conhecidas. Não promete IO atômico contra troca concorrente.
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_check(false, "PNG ocupado; não gravar")
		quit(1)
		return false
	if image.save_png(path) != OK:
		_check(false, "gravação PNG falhou")
		quit(1)
		return false
	captures.append({"path": path, "player_health": player.health.current,
		"enemy_health": enemy.health.current, "phase": enemy.action_state.phase,
		"serial": enemy.action_state.attack_serial, "protected": player.action_state.invulnerable})
	return true

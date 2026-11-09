extends SceneTree
## Ensaio de fonte S3, não benchmark de build exportada nem meta gráfica S7.
## Mesmo cenário/configuração3/12; jogador protegido APENAS pelo script de fixture.

const ARENA := preload("res://src/arenas/first_encounter.tscn")
const ENEMY := preload("res://src/enemies/melee_chaser.tscn")
const ProtectedPlayer := preload("res://tests/fixtures/s3_protected_player.gd")
var destination: String
var arena: Node2D
var player: CharacterBody2D
var enemies: Array[Node] = []
var start: int
var previous: int
var samples: Array[Dictionary] = []
var frame_ms: Array[float] = []
var next_sample := 1.0
var count: int
var finished := false

func _initialize() -> void:
	_run.call_deferred()

func _fail(message: String) -> void:
	printerr("PROFILE_FAIL: ", message)
	quit(1)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["3", "12"] or not args[1].is_valid_identifier() or args[1].length() > 48:
		_fail("argumentos fechados:3/12 identificador novo")
		return
	if "--fixed-fps" in OS.get_cmdline_args() or DisplayServer.get_name() == "headless":
		_fail("exige tempo real e janela nativa")
		return
	count = int(args[0])
	destination = "res://.tools/s3/unit2-profile-" + args[1]
	if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination):
		_fail("destino ocupado; preservar")
		return
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		_fail("destino novo indisponível")
		return
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	paused = false
	arena = ARENA.instantiate()
	player = arena.get_node("Actors/Player")
	player.set_script(ProtectedPlayer)
	player.audio_enabled = false
	for name: String in ["Enemy1", "Enemy2", "Enemy3"]:
		enemies.append(arena.get_node("Actors/" + name))
	for index: int in range(3, count):
		var enemy := ENEMY.instantiate()
		enemy.position = Vector2(800, 500) + Vector2.from_angle(TAU * index / count) * 150.0
		arena.get_node("Actors").add_child(enemy)
		enemies.append(enemy)
	root.add_child(arena)
	var adapter := arena.get_node("PlayerInput")
	adapter.set_physics_process(false)
	adapter.set_process_input(false)
	adapter.set_process_unhandled_input(false)
	adapter.set_focus_active(true)
	for enemy: Node in enemies:
		if not enemy.set_target(player):
			_fail("alvo de ensaio inválido")
			return
		enemy.set_encounter_enabled(true)
	Engine.max_fps = 60
	start = Time.get_ticks_usec()
	previous = start
	print("PROFILE_BEGIN count=%d pid=%d viewport=1920x1080 source=S3 protected_fixture=true" % [count, OS.get_process_id()])

func _process(_delta: float) -> bool:
	if start == 0 or finished:
		return false
	var now := Time.get_ticks_usec()
	var elapsed := (now - start) / 1000000.0
	frame_ms.append((now - previous) / 1000.0)
	previous = now
	# Percurso repetível na área livre, sem comandos de ataque que matem a carga.
	player.apply_intent(Vector2.from_angle(elapsed * 0.5 + PI * 0.5) * 0.12, Vector2.RIGHT)
	if elapsed >= next_sample:
		samples.append({"elapsed_real_s": elapsed, "process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"fps_monitor": Performance.get_monitor(Performance.TIME_FPS), "attempted_hits": player.attempted_hits})
		next_sample += 1.0
	if elapsed >= 60.0:
		finished = true
		_complete(elapsed)
	return false

func _complete(elapsed: float) -> void:
	var path := destination.path_join("profile.json")
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_fail("relatório ocupado")
		return
	var intact: bool = arena.state == "running" and arena.remaining == 3 and player.health.current == 100 and samples.size() >= 60 and root.size == Vector2i(1920, 1080)
	for enemy: Node in enemies:
		intact = intact and is_instance_valid(enemy) and enemy.health.current == 30 and enemy.is_inside_tree()
	frame_ms.sort()
	var data := {"source": "S3 FirstEncounter", "version": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(), "logical_cpus": OS.get_processor_count(),
		"viewport": [1920, 1080], "load": count, "elapsed_real_s": elapsed, "frames": frame_ms.size(),
		"frame_interval_ms": {"p95": frame_ms[int(floor((frame_ms.size() - 1) * 0.95))], "p99": frame_ms[int(floor((frame_ms.size() - 1) * 0.99))], "peak": frame_ms[-1]},
		"samples": samples, "intact": intact, "protected_fixture": true, "fps_cap": 60,
		"limits": "TIME_PROCESS/PHYSICS são tempos de processamento nativos, não CPU total do processo/GPU; MEMORY_STATIC não é memória privada do processo; intervalos incluem espera/apresentação. Sem meta S7 ou custo/tokens medidos."}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("falha ao gravar relatório")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	arena.shutdown()
	arena.free()
	print("PROFILE_COMPLETE count=%d elapsed_real_s=%.6f samples=%d intact=%s destination=%s" % [count, elapsed, samples.size(), intact, destination])
	quit(0 if intact else 1)

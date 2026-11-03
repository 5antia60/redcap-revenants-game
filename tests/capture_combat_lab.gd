extends SceneTree
## Captura gráfica nativa da fonte. Entrada sintética não equivale a hardware/feeling.

const BASE := Vector2i(1280, 720)
const DeviceReads := preload("res://tests/fixtures/test_player_input_collection.gd").DeviceReads
var failed: bool = false
var checks: int = 0

class Step extends Node:
	signal finished
	var callback: Callable
	var completed: bool = false
	func _physics_process(_delta: float) -> void:
		set_physics_process(false)
		completed = callback.call() == true
		finished.emit()

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		printerr("CAPTURE_FAIL: ", message)

func _freeze(node: Node) -> void:
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _step(callback: Callable) -> bool:
	var step := Step.new()
	step.callback = callback
	step.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(step)
	await step.finished
	await process_frame
	var completed := step.completed
	step.free()
	return completed


func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.device = 16
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)


func _joy(adapter: Node, button: int) -> void:
	for pressed: bool in [true, false]:
		adapter.buttons = {37: {button: pressed}}
		var event := InputEventJoypadButton.new()
		event.device = 37
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)


func _poll(adapter: Node) -> bool:
	return await _step(func() -> bool:
		adapter._physics_process(1.0 / 60.0)
		return true)

func _run() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void:
		printerr("CAPTURE_WATCHDOG")
		quit(1))
	var args := OS.get_cmdline_user_args()
	_check(args.size() == 1 and args[0] in ["720", "1080"], "escolha720/1080 explícita")
	_check(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility", "janela e Compatibility reais")
	if failed:
		quit(1)
		return
	var target := BASE if args[0] == "720" else Vector2i(1920, 1080)
	var destination := "res://.tools/s2/captures/task3-correction1-%s-%s" % [args[0], Time.get_ticks_usec()]
	_check(not DirAccess.dir_exists_absolute(destination), "destino novo")
	_check(DirAccess.make_dir_recursive_absolute(destination) == OK, "criar destino novo")
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.current_screen = 0
	root.position = DisplayServer.screen_get_position(0)
	root.size = target
	var saved_pause := paused
	var main = load("res://src/game/main.tscn").instantiate()
	var initial_lab: Node = main.get_node("MovementLab")
	var initial_adapter: Node = initial_lab.get_node("PlayerInput")
	initial_adapter.set_script(DeviceReads)
	initial_adapter.player = initial_lab.get_node("Actors/Player")
	initial_adapter.connected_ids = PackedInt32Array([37])
	main.child_entered_tree.connect(func(child: Node) -> void:
		if child.name == "MovementLab":
			child.ready.connect(func() -> void: _freeze(child)))
	root.add_child(main)
	var lab: Node = main.get_node("MovementLab")
	_freeze(lab)
	var player = lab.get_node("Actors/Player")
	var adapter = lab.get_node("PlayerInput")
	adapter.set_focus_active(true)
	main.set_paused(false)
	player.audio_enabled = false
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	var note := Label.new()
	note.text = "CAPTURA AUTOMATIZADA DA FONTE · ENTRADA SINTÉTICA · NÃO É ACEITE MANUAL"
	note.position = Vector2(24, 192)
	note.add_theme_font_size_override("font_size", 15)
	var evidence := CanvasLayer.new()
	evidence.layer = 30
	root.add_child(evidence)
	evidence.add_child(note)
	var attempt_id: int = lab.get_instance_id()
	var deaths := [0]
	player.died.connect(func() -> void: deaths[0] += 1)
	for stage: String in ["nascimento", "preparacao", "ativo-acerto", "recuperacao", "alvo-morto-vida", "protecao", "esquiva-sem-protecao", "zona-treino", "pausa", "navegacao-teclado", "reinicio-confirmacao", "reinicio-cancelado", "pausa-controle", "navegacao-controle", "morte-jogador", "reinicio", "reinicio-confirmado"]:
		if stage == "preparacao":
			player.position = lab.get_node("Actors/Target1").position - Vector2(45, 0)
			_check(await _step(func() -> bool:
				player.queue_actions(true, false)
				player._physics_process(0.03)
				return true), "preparação concluída")
		elif stage == "ativo-acerto":
			_check(await _step(func() -> bool:
				player._physics_process(0.04)
				return true), "ativo concluído")
			_check(player.active_snapshot and lab.get_node("Actors/Target1").health.current == 20, "acerto real coincide com setor")
		elif stage == "recuperacao":
			player._physics_process(0.10)
			player._physics_process(0.016)
			_check(player.action_state.phase == 3 and not player.active_snapshot, "recuperação não promete janela ativa")
		elif stage == "alvo-morto-vida":
			lab.get_node("Actors/Target2").receive_hit(30)
			player.receive_hit(25)
		elif stage == "protecao":
			player._physics_process(0.75)
			player.queue_actions(false, true)
			player._physics_process(0.04)
			_check(player.action_state.invulnerable, "contorno protegido real")
		elif stage == "esquiva-sem-protecao":
			player._physics_process(0.07)
			_check(not player.action_state.invulnerable and player.action_state.phase == 4, "rastro/arma não prometem proteção após0,10")
		elif stage == "pausa":
			_key(KEY_ESCAPE)
			_check(paused and main._continue.has_focus(), "Escape abre pausa com Continuar focado")
		elif stage == "navegacao-teclado":
			_key(KEY_DOWN)
			_check(main._restart.has_focus(), "seta para baixo navega até Reiniciar")
		elif stage == "reinicio-confirmacao":
			_key(KEY_ENTER)
			_check(main._confirming and main._cancel.has_focus() and lab.get_instance_id() == attempt_id,
				"Enter pede confirmação sem trocar arena e foca Cancelar")
		elif stage == "reinicio-cancelado":
			_key(KEY_ENTER)
			_check(paused and not main._confirming and main._continue.has_focus() and lab.get_instance_id() == attempt_id,
				"Enter em Cancelar preserva tentativa e retorna foco")
		elif stage == "pausa-controle":
			_check(await _poll(adapter), "controle neutraliza pela coleta normal na pausa")
			adapter.axes = {37: {JOY_AXIS_RIGHT_X: 0.6}}
			_check(await _poll(adapter), "analógico seleciona ID37 pela coleta normal")
			_check(adapter.active_device == 37, "ajuda do controle corresponde ao ID coletado")
			_joy(adapter, JOY_BUTTON_DPAD_DOWN)
			_check(main._restart.has_focus(), "direcional para baixo navega até Reiniciar")
			_joy(adapter, JOY_BUTTON_DPAD_UP)
			_check(main._continue.has_focus(), "direcional para cima retorna a Continuar")
			_joy(adapter, JOY_BUTTON_A)
			_check(not paused and player.action_state.phase == 4, "sul continua sem iniciar outra ação")
			adapter.buttons = {}
			_check(await _poll(adapter), "soltar controle após Continuar")
			adapter.buttons = {37: {JOY_BUTTON_START: true}}
			_check(await _poll(adapter), "Start abre pausa pela coleta de produção")
			_check(paused and main._continue.has_focus(), "Start retorna à pausa com foco visível")
			adapter.buttons = {}
			_check(await _poll(adapter), "soltar Start no menu")
			lab.refresh_status()
		elif stage == "navegacao-controle":
			_joy(adapter, JOY_BUTTON_DPAD_DOWN)
			_check(main._restart.has_focus(), "controle mantém foco em Reiniciar sem confirmar acidentalmente")
		elif stage == "morte-jogador":
			_joy(adapter, JOY_BUTTON_DPAD_UP)
			_joy(adapter, JOY_BUTTON_A)
			player.interrupt_actions()
			player.position = lab.get_node("DamageZone").position
			for pulse in range(3):
				_check(await _step(func() -> bool:
					lab.get_node("DamageZone")._physics_process(1.0)
					return true), "pulso real da zona para evidência de morte")
			_check(player.health.current == 0 and player.action_state.phase == 5 and deaths[0] == 1
				and paused and not main._continue.visible and main._restart.has_focus(),
				"zona mata uma vez, pausa e foca reinício direto")
		elif stage == "zona-treino":
			player.position = lab.get_node("DamageZone").position - Vector2(130, 0)
			_check(await _step(func() -> bool:
				lab.get_node("DamageZone")._physics_process(0.36)
				return true), "zona real desenha snapshot ativo")
		elif stage == "reinicio":
			_joy(adapter, JOY_BUTTON_A)
			await process_frame
			lab = main.get_node("MovementLab")
			player = lab.get_node("Actors/Player")
			adapter = lab.get_node("PlayerInput")
			adapter.set_focus_active(true)
			main.set_paused(false)
			_check(player.health.current == 100 and lab.get_node("Actors/Target2").health.current == 30, "reinício restaura vida/alvos")
			_check(lab.get_instance_id() != attempt_id, "sul após morte recria laboratório sem confirmação")
			attempt_id = lab.get_instance_id()
		elif stage == "reinicio-confirmado":
			_key(KEY_ESCAPE)
			await process_frame
			_key(KEY_DOWN)
			_key(KEY_ENTER)
			_check(main._confirming and main._cancel.has_focus(), "tentativa viva pede confirmação novamente")
			_key(KEY_UP)
			_check(main._restart.has_focus(), "seta seleciona Confirmar reinício")
			_key(KEY_ENTER)
			await process_frame
			lab = main.get_node("MovementLab")
			player = lab.get_node("Actors/Player")
			adapter = lab.get_node("PlayerInput")
			adapter.set_focus_active(true)
			main.set_paused(false)
			_check(lab.get_instance_id() != attempt_id and player.health.current == 100, "confirmar pela GUI recria uma tentativa viva")
		var camera: Camera2D = player.get_node("Camera2D")
		camera.force_update_scroll()
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		if stage in ["nascimento", "reinicio", "reinicio-confirmado"]:
			for target_name: String in ["Target1", "Target2", "Target3"]:
				var target_node: Node2D = lab.get_node("Actors/" + target_name)
				var proof := target_node.get_global_transform_with_canvas() * Rect2(-28, -64, 56, 76)
				for panel: Control in [lab.get_node("HUD/Panel"), lab.get_node("HUD/Help")]:
					_check(not panel.get_global_rect().intersects(proof), "alvo/vida livres do HUD: " + target_name)
			var zone_node: Node2D = lab.get_node("DamageZone")
			var proof := zone_node.get_global_transform_with_canvas() * Rect2(-60, -70, 160, 110)
			for panel: Control in [lab.get_node("HUD/Panel"), lab.get_node("HUD/Help")]:
				_check(not panel.get_global_rect().intersects(proof), "zona e rótulo livres do HUD no nascimento/reinício")
		var image := root.get_texture().get_image()
		var client := DisplayServer.window_get_size(root.get_window_id())
		_check(root.size == target and client == target and image.get_size() == target, "janela/cliente/imagem nativos sem upscale")
		_check(root.content_scale_size == BASE, "base lógica preservada")
		for label_name: String in ["Title", "State", "Combat", "Instructions", "Recovery"]:
			var label: Label = lab.get_node("HUD").find_child(label_name, true, false)
			_check(label.size.x >= label.get_minimum_size().x and label.size.y >= label.get_minimum_size().y
				and Rect2(Vector2.ZERO, Vector2(BASE)).encloses(label.get_global_rect()), "texto sem recorte: " + label_name)
		if stage == "pausa":
			for button: Button in [main._continue, main._restart]:
				_check(button.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(BASE)).encloses(button.get_global_rect()), "menu visível dentro da base")
			_check(main._continue.has_focus(), "Continuar mostra foco determinístico")
		var path := destination.path_join(stage + ".png")
		_check(not FileAccess.file_exists(path), "não sobrescrever captura")
		_check(image.save_png(path) == OK, "salvar PNG nativo")
		var focused := root.gui_get_focus_owner()
		print("CAPTURE_NAV stage=%s paused=%s focus=%s device=%s confirming=%s attempt=%s" % [
			stage, paused, focused.text if focused is Button else "nenhum", adapter.active_device, main._confirming, lab.get_instance_id()])
		print("CAPTURE stage=%s window=%s client=%s image=%s base=%s renderer=%s adapter=%s phase=%s active=%s protected=%s life=%s path=%s" % [
			stage, root.size, client, image.get_size(), root.content_scale_size, RenderingServer.get_current_rendering_method(),
			RenderingServer.get_video_adapter_name(), player.action_state.phase, player.active_snapshot, player.action_state.invulnerable,
			player.health.current, ProjectSettings.globalize_path(path)])
	main.free()
	evidence.free()
	paused = saved_pause
	print("CAPTURE_RESULT: failed=%s checks=%s" % [failed, checks])
	quit(1 if failed else 0)

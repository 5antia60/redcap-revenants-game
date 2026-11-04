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

class DamageTicks extends Node:
	signal finished
	var player: Node
	var zone: Node
	var budget: int
	var observed: int = 0
	var elapsed: float = 0.0
	func _physics_process(delta: float) -> void:
		observed += 1
		elapsed += delta
		if observed == budget:
			player.set_physics_process(false)
			zone.set_physics_process(false)
			set_physics_process(false)
			finished.emit()

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		printerr("CAPTURE_FAIL: ", message)


func _reserve_destination(destination: String) -> bool:
	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):
		_check(false, "destino de captura ocupado")
		quit(1)
		return false
	var created := DirAccess.make_dir_recursive_absolute(destination) == OK
	_check(created, "criar destino novo")
	if not created:
		quit(1)
	return created


func _save_capture(image: Image, path: String) -> bool:
	# Recusa uma colisão já observável. Este check seguido de save_png não é
	# criação atômica nem proteção contra troca concorrente após a verificação.
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		_check(false, "arquivo de captura ocupado")
		quit(1)
		return false
	var saved := image.save_png(path) == OK
	_check(saved, "salvar PNG nativo")
	if not saved:
		quit(1)
	return saved

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
	if args.size() == 2 and args[0] in ["720", "1080"] and args[1] in ["damage-red", "damage-green", "damage-confirm"]:
		await _damage_run(BASE if args[0] == "720" else Vector2i(1920, 1080), args[1])
		return
	_check(args.size() == 1 and args[0] in ["720", "1080"], "escolha720/1080 explícita")
	_check(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility", "janela e Compatibility reais")
	if failed:
		quit(1)
		return
	var target := BASE if args[0] == "720" else Vector2i(1920, 1080)
	var destination := "res://.tools/s2-feedback-dano/legacy-capture-%s-%s" % [args[0], Time.get_ticks_usec()]
	if not _reserve_destination(destination):
		return
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
		if not _save_capture(image, path):
			main.free()
			evidence.free()
			paused = saved_pause
			return
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


func _damage_run(target: Vector2i, mode: String) -> void:
	_check(DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "gl_compatibility", "janela nativa Compatibility")
	if failed:
		quit(1)
		return
	var destination := "res://.tools/s2-feedback-dano/%s-%s-%s" % [mode, target.y, Time.get_ticks_usec()]
	if not _reserve_destination(destination):
		return
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.size = target
	var main = load("res://src/game/main.tscn").instantiate()
	main.child_entered_tree.connect(func(child: Node) -> void:
		if child.name == "MovementLab":
			child.ready.connect(func() -> void: _freeze(child)))
	root.add_child(main)
	var lab: Node = main.get_node("MovementLab")
	_freeze(lab)
	var player: Node = lab.get_node("Actors/Player")
	var zone: Node = lab.get_node("DamageZone")
	lab.get_node("PlayerInput").set_focus_active(true)
	main.set_paused(false)
	player.audio_enabled = false
	player.position = zone.position
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	_check(await _step(func() -> bool:
		player._physics_process(1.0 / 60.0)
		zone._physics_process(0.34)
		return true), "contato físico na zona antes do pulso")
	if not await _damage_png(destination, "01-dentro-aviso", lab, player, 0.0, target):
		return
	_check(await _step(func() -> bool:
		player._physics_process(1.0 / 60.0)
		zone._physics_process(0.02)
		return true), "pulso da zona após corpo no tick real")
	_check(player.health.current == 75, "pulso real aceito100→75 com corpo dentro")
	if not await _damage_png(destination, "02-pos-dano25-t0", lab, player, 0.0, target):
		return
	if mode != "damage-red":
		_check(_damage_numbers(player) == ["−25"] and is_equal_approx(player.reaction_remaining, 0.20), "feedback inicial aceito")
	if mode == "damage-green":
		var elapsed := 0.0
		for sample: Array in [[6, "03-pos-dano-t100ms"], [5, "04-marca-t183ms"], [1, "05-sem-marca-t200ms"],
			[23, "06-numero-t583ms"], [1, "07-expirado-t600ms"]]:
			elapsed += await _damage_ticks(player, zone, sample[0])
			if not await _damage_png(destination, sample[1], lab, player, elapsed, target):
				return
		_check(_damage_numbers(player).is_empty() and player.reaction_remaining == 0.0 and player.health.current == 75,
			"expiração nativa sem dano novo")
		_check(player.receive_hit(7), "segundo valor válido")
		if not await _damage_png(destination, "08-dano7", lab, player, 0.0, target):
			return
		main.set_paused(true)
		var remaining: float = player.reaction_remaining
		_check(not player.receive_hit(25), "pausa não recebe outro dano")
		if not await _damage_png(destination, "09-pausa-congelada", lab, player, 0.0, target):
			return
		_check(player.reaction_remaining == remaining, "pausa conserva efeito")
		main.set_paused(false)
		if not await _damage_png(destination, "10-retorno-sem-evento", lab, player, 0.0, target):
			return
		_check(_damage_numbers(player) == ["−7"], "retorno preserva somente evento existente")
		_check(player.receive_hit(3), "segundo slot")
		if not await _damage_png(destination, "11-dois-slots", lab, player, 0.0, target):
			return
		_check(player.receive_hit(2), "terceiro evento")
		if not await _damage_png(destination, "12-substitui-antigo", lab, player, 0.0, target):
			return
		_check(_damage_numbers(player) == ["−2", "−3"], "sem soma nem fila no terceiro evento")
		lab = await _damage_reset(main)
		player = lab.get_node("Actors/Player")
		zone = lab.get_node("DamageZone")
		if not await _damage_png(destination, "13-reinicio", lab, player, 0.0, target):
			return
		_check(_damage_numbers(player).is_empty() and player.health.current == 100, "reset limpa eventos")
		player.position = zone.position
		player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
		zone.advance_clock(0.34)
		_check(await _step(func() -> bool:
			player.queue_actions(false, true)
			player._physics_process(0.04)
			zone._physics_process(0.02)
			return true), "tentativa protegida no pulso físico")
		_check(player.action_state.invulnerable and player.health.current == 100 and _damage_numbers(player).is_empty(), "proteção recusa sem feedback")
		if not await _damage_png(destination, "14-protecao-dentro-zona", lab, player, 0.04, target):
			return
		await _damage_ticks(player, zone, 5)
		_check(not player.action_state.invulnerable and player.health.current == 100 and _damage_numbers(player).is_empty(), "fim de proteção não reaplica pulso consumido")
		if not await _damage_png(destination, "15-fim-protecao-sem-falso-dano", lab, player, 0.123333, target):
			return
		player.interrupt_actions()
		_check(player.receive_hit(95) and player.health.current == 5, "vida restante5")
		if not await _damage_png(destination, "16-sobrevida5-perda95", lab, player, 0.0, target):
			return
		_check(player.receive_hit(25) and player.health.current == 0 and paused and _damage_numbers(player).is_empty()
			and player.reaction_remaining == 0.0, "sobreletal perde só5 e limpa morte antes do menu")
		if not await _damage_png(destination, "17-morte-sem-residuo", lab, player, 0.0, target):
			return
		lab = await _damage_reset(main)
		player = lab.get_node("Actors/Player")
		if not await _damage_png(destination, "18-reinicio-apos-morte", lab, player, 0.0, target):
			return
		player.position = Vector2(1100, 480)
		if not await _damage_png(destination, "19-prop-oclusao-legitima-atras", lab, player, 0.0, target):
			return
		player.position = Vector2(1100, 550)
		if not await _damage_png(destination, "20-prop-jogador-a-frente", lab, player, 0.0, target):
			return
	main.free()
	paused = false
	print("CAPTURE_RESULT: failed=%s checks=%s directory=%s" % [failed, checks, ProjectSettings.globalize_path(destination)])
	quit(1 if failed else 0)


func _damage_numbers(player: Node) -> Array[String]:
	var numbers: Array[String] = []
	for child: Node in player.get_children():
		if child is Label and str(child.name).begins_with("DamageNumber") and child.visible:
			numbers.append(child.text)
	return numbers


func _damage_reset(main: Node) -> Node:
	main.restart_lab()
	await process_frame
	var lab: Node = main.get_node("MovementLab")
	_freeze(lab)
	lab.get_node("PlayerInput").set_focus_active(true)
	main.set_paused(false)
	lab.get_node("Actors/Player").audio_enabled = false
	return lab


func _damage_ticks(player: Node, zone: Node, budget: int) -> float:
	# A engine agenda os callbacks de produção. Só a observação tem prioridade20,
	# depois de corpo0/zona10, e congela exatamente no último tick do orçamento.
	var observer := DamageTicks.new()
	observer.player = player
	observer.zone = zone
	observer.budget = budget
	observer.process_physics_priority = 20
	root.add_child(observer)
	player.set_physics_process(true)
	zone.set_physics_process(true)
	await observer.finished
	_check(observer.observed == budget, "orçamento nativo sem tick extra")
	var elapsed := observer.elapsed
	await process_frame
	observer.free()
	return elapsed


func _damage_png(destination: String, stage: String, lab: Node, player: Node, elapsed: float, target: Vector2i) -> bool:
	player.get_node("Camera2D").force_update_scroll()
	lab.refresh_status()
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var client := DisplayServer.window_get_size(root.get_window_id())
	_check(root.size == target and client == target and image.get_size() == target and root.content_scale_size == BASE,
		"janela/cliente/imagem nativos sem upscale")
	var path := destination.path_join(stage + ".png")
	if not _save_capture(image, path):
		return false
	var numbers := _damage_numbers(player)
	for child: Node in player.get_children():
		if child is Label and str(child.name).begins_with("DamageNumber"):
			print("DAMAGE_SLOT stage=%s slot=%s visible=%s position=%s size=%s center=%s font=%s outline=%s" % [
				stage, child.name, child.visible, child.position, child.size, child.position + child.size / 2.0,
				child.get_theme_font_size("font_size"), child.get_theme_constant("outline_size")])
	print("DAMAGE_CAPTURE stage=%s elapsed_physics=%.6f window=%s client=%s image=%s feet=%s zone=%s life=%s reaction=%.6f numbers=%s protected=%s paused=%s path=%s" % [
		stage, elapsed, root.size, client, image.get_size(), player.position, lab.get_node("DamageZone").position,
		player.health.current, player.reaction_remaining, numbers, player.action_state.invulnerable, paused, ProjectSettings.globalize_path(path)])
	return true

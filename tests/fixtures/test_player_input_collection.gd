extends RefCounted
## Substitui somente leituras de hardware; coleta, foco, sinais e física são produção.
## A Window escondida tem has_focus=false real da engine, não foco simulado pelo stub.

const MAIN := preload("res://src/game/main.tscn")

class DeviceReads extends "res://src/player/player_input.gd":
	var connected_ids := PackedInt32Array([37, 83])
	var axes: Dictionary = {}
	var buttons: Dictionary = {}
	func _read_connected_joypads() -> PackedInt32Array:
		return connected_ids
	func _read_joy_axis(device: int, axis: int) -> float:
		var values: Dictionary = axes.get(device, {})
		return float(values.get(axis, 0.0))
	func _read_joy_button_pressed(device: int, button: int) -> bool:
		return bool(buttons.get(device, {}).get(button, false))

class TickBudget extends Node:
	signal finished
	var player: Node
	var adapter: Node
	var completed: int = 0
	var lab: Node
	func _physics_process(_delta: float) -> void:
		completed += 1
		_set_ticks(lab, false)
		player.set_physics_process(false)
		adapter.set_physics_process(false)
		set_physics_process(false)
		finished.emit()
	func _set_ticks(node: Node, enabled: bool) -> void:
		node.set_physics_process(enabled)
		for child: Node in node.get_children():
			_set_ticks(child, enabled)


func run(tree: SceneTree, check: Callable) -> bool:
	var saved_pause := tree.paused
	check.call(await _test_polling(tree, check) == true, "coleta normal de controles deve concluir")
	check.call(await _test_global_key(tree, check) == true, "estado global real de tecla deve concluir")
	check.call(await _test_buttons(tree, check) == true, "botões e GUI pela coleta de produção devem concluir")
	check.call(await _test_simultaneous_devices(tree, check) == true, "arbitragem simultânea pela coleta normal deve concluir")
	tree.paused = saved_pause
	return true


func _test_simultaneous_devices(tree: SceneTree, check: Callable) -> bool:
	# Uma borda do controle anterior não pode cancelar o golpe do selecionado.
	# Inverter ações e enumeração também cobre a saída simétrica da arbitragem.
	for order: PackedInt32Array in [PackedInt32Array([37, 83]), PackedInt32Array([83, 37])]:
		for sample: Dictionary in [{"south": 37, "west": 83}, {"south": 83, "west": 37}, {"south": 37, "west": 37}]:
			var south_device: int = sample.south
			var window := SubViewport.new()
			window.size = Vector2i(1280, 720)
			window.world_2d = World2D.new()
			window.process_mode = Node.PROCESS_MODE_ALWAYS
			tree.root.add_child(window)
			var main := MAIN.instantiate()
			var lab := main.get_node("MovementLab")
			var player := lab.get_node("Actors/Player")
			var adapter := lab.get_node("PlayerInput")
			adapter.set_script(DeviceReads)
			adapter.player = player
			adapter.connected_ids = order
			window.add_child(main)
			_freeze(lab)
			adapter.set_focus_active(true)
			main.set_paused(false)
			player.audio_enabled = false
			check.call(await _tick(tree, player, adapter), "coleta: neutralizar/rearmar dois dispositivos antes da simultaneidade")
			var west_device: int = sample.west
			adapter.buttons = {south_device: {JOY_BUTTON_A: true}}
			if west_device != south_device:
				adapter.buttons[west_device] = {}
			adapter.buttons[west_device][JOY_BUTTON_X] = true
			check.call(await _tick(tree, player, adapter), "coleta: bordas simultâneas em dois IDs pelo processamento físico normal")
			var selected: int = south_device if south_device == west_device else order[1]
			var dodge := selected == south_device
			check.call(adapter.active_device == selected, "coleta: última atividade deliberada seleciona ID sem mudar ordem existente")
			check.call(player.action_state.phase == (4 if dodge else 1)
				and player.action_state.attack_serial == (0 if dodge else 1)
				and (absf(player.action_state.cooldown_remaining - 0.733333333) < 0.00001 if dodge else player.action_state.cooldown_remaining == 0.0),
				"coleta: simultâneos publicam somente ação/serial/custo do ID escolhido: ordem=%s sul=%s fase=%s serial=%s custo=%s" % [
					order, south_device, player.action_state.phase, player.action_state.attack_serial, player.action_state.cooldown_remaining])
			check.call(await _tick(tree, player, adapter), "coleta: manter simultâneos não recicla borda do ID descartado")
			check.call(adapter.active_device == selected and player.action_state.attack_serial == (0 if dodge else 1),
				"coleta: controle descartado não deixa ataque enfileirado")
			window.free()
			tree.paused = false
			await tree.process_frame
	return true


func _test_buttons(tree: SceneTree, check: Callable) -> bool:
	# SubViewport mantém cursor virtual para hit-test GUI em headless. As provas
	# de foco inicial acima continuam usando Window real escondida.
	var window := SubViewport.new()
	window.size = Vector2i(1280, 720)
	window.world_2d = World2D.new()
	window.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(window)
	var main := MAIN.instantiate()
	var lab := main.get_node("MovementLab")
	var player := lab.get_node("Actors/Player")
	var adapter := lab.get_node("PlayerInput")
	adapter.set_script(DeviceReads)
	adapter.player = player
	adapter.buttons = {37: {JOY_BUTTON_X: true}}
	window.add_child(main)
	_freeze(lab)
	adapter.get_window().focus_entered.emit()
	main.set_paused(false)
	player.position = lab.get_node("Actors/Target1").position - Vector2(45, 0)
	check.call(await _tick(tree, player, adapter), "coleta: botão oeste retido no foco inicial")
	check.call(player.action_state.attack_serial == 0, "coleta: botão retido exige soltura antes de armar")
	adapter.buttons = {}
	check.call(await _tick(tree, player, adapter), "coleta: soltar botões rearma fronteira real")
	adapter.buttons = {37: {JOY_BUTTON_X: true}}
	check.call(await _tick(tree, player, adapter), "coleta: nova pressão oeste do ID37")
	check.call(player.action_state.attack_serial == 1 and adapter.active_device == 37,
		"coleta: botão oeste do ID37 inicia golpe pela coleta normal")
	for tick in range(18):
		check.call(await _tick(tree, player, adapter), "coleta: manter botão não repete golpe")
	check.call(player.action_state.attack_serial == 1 and player.action_state.phase == 0,
		"coleta: segurar oeste não repete nem enfileira ação")
	check.call(lab.get_node("Actors/Target1").health.current == 20,
		"coleta: botão real atravessa Main, fase, setor e vida; mesmo serial não duplica dano")
	adapter.buttons = {83: {JOY_BUTTON_A: true}}
	check.call(await _tick(tree, player, adapter), "coleta: pressão deliberada sul do ID83")
	check.call(player.action_state.phase == 4 and adapter.active_device == 83,
		"coleta: botão sul do ID83 escolhe dispositivo sem somar IDs")
	Input.joy_connection_changed.emit(83, false)
	check.call(tree.paused and player.action_state.phase == 0 and not player.action_state.invulnerable,
		"coleta: desconexão interrompe esquiva e pausa Main real")
	var cost: float = player.action_state.cooldown_remaining
	check.call(await _tick(tree, player, adapter), "coleta: relógios congelados após desconexão")
	check.call(player.action_state.cooldown_remaining == cost and not player.receive_hit(25),
		"coleta: pausa por desconexão não recebe dano de fundo")
	main.set_paused(false)
	adapter.buttons = {}
	check.call(await _tick(tree, player, adapter), "coleta: neutralizar após desconexão")
	main.set_paused(true)
	var serial: int = player.action_state.attack_serial
	await tree.process_frame
	var center: Vector2 = main._continue.get_global_rect().get_center()
	window.notify_mouse_entered()
	var motion := InputEventMouseMotion.new()
	motion.device = 32
	motion.position = center
	motion.relative = Vector2.ONE
	window.push_input(motion, true)
	await tree.process_frame
	for pressed: bool in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.device = 32
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = center
		mouse.pressed = pressed
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		window.push_input(mouse, true)
	check.call(not tree.paused, "coleta: clique nativo no botão Continuar retoma")
	check.call(await _tick(tree, player, adapter), "coleta: tick após clique sobre menu")
	check.call(player.action_state.attack_serial == serial, "coleta: LMB consumido pela GUI não ataca mundo")
	main.set_paused(true)
	await tree.process_frame
	adapter.buttons = {37: {JOY_BUTTON_A: true}}
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 37
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		window.push_input(event, true)
	check.call(not tree.paused, "coleta: botão sul confirma Continuar pela GUI real")
	check.call(await _tick(tree, player, adapter), "coleta: confirmação sul retida após GUI")
	check.call(player.action_state.phase == 0 and player.action_state.cooldown_remaining < cost,
		"coleta: botão sul do menu não vira esquiva ao retomar")
	adapter.get_window().focus_exited.emit()
	check.call(tree.paused and player.action_state.phase == 0 and player.velocity == Vector2.ZERO,
		"coleta: foco perdido interrompe ação e pausa Main real")
	adapter.get_window().focus_entered.emit()
	await tree.process_frame
	check.call(not main._continue.disabled and tree.paused,
		"coleta: foco recuperado habilita Continuar sem retomar automaticamente")
	window.free()
	tree.paused = false
	await tree.process_frame
	return true


func _test_polling(tree: SceneTree, check: Callable) -> bool:
	var window := _unfocused_window(tree)
	check.call(not window.has_focus() and not window.visible, "Window real já nasce sem foco antes de Main")
	var main := MAIN.instantiate()
	var lab := main.get_node("MovementLab")
	var player := lab.get_node("Actors/Player") as CharacterBody2D
	# Troca de script apenas antes de entrar na árvore; o _ready herdado é o real.
	var adapter := lab.get_node("PlayerInput")
	adapter.set_script(DeviceReads)
	adapter.player = player
	window.add_child(main)
	_freeze(lab)
	check.call(not adapter.focus_active, "coleta: inicialização consulta Window sem esperar focus_exited")
	var start := player.position
	check.call(await _tick(tree, player, adapter), "coleta: conexão neutra em tick real")
	_axes(adapter, 37, Vector2(0.6, 0), Vector2(-0.6, 0.8))
	check.call(await _tick(tree, player, adapter), "coleta: eixos retidos sem foco")
	check.call(player.velocity == Vector2.ZERO and player.position == start and player.aim_direction == Vector2.RIGHT,
		"coleta: nascer sem foco não move nem altera mira em segundo plano")
	var state := lab.get_node("HUD/Panel/Margin/Rows/State") as Label
	check.call(state.text.contains("perdido"), "coleta: HUD informa foco inicial perdido")
	window.focus_entered.emit()
	main.set_paused(false)
	check.call(await _tick(tree, player, adapter), "coleta: retorno com sticks retidos")
	check.call(player.velocity == Vector2.ZERO, "coleta: retorno exige neutralizar sticks")
	_axes(adapter, 37, Vector2.ZERO, Vector2.ZERO)
	check.call(await _tick(tree, player, adapter), "coleta: neutralização pela leitura normal")
	_axes(adapter, 37, Vector2(0.6, 0), Vector2(-0.6, 0.8))
	check.call(await _tick(tree, player, adapter), "coleta: ativação deliberada ID37")
	check.call(adapter.active_device == 37 and player.velocity.distance_to(Vector2(120, 0)) < 0.001
		and player.aim_direction.distance_to(Vector2(-0.6, 0.8)) < 0.001,
		"coleta: enumeração e quatro eixos do ID37 geram movimento parcial e mira independentes")
	_axes(adapter, 37, Vector2(0, -0.6), Vector2(0.8, -0.6))
	check.call(await _tick(tree, player, adapter), "coleta: variação independente dos quatro eixos")
	check.call(player.velocity.distance_to(Vector2(0, -120)) < 0.001
		and player.aim_direction.distance_to(Vector2(0.8, -0.6)) < 0.001,
		"coleta: eixo vertical de movimento não é eixo da mira")
	_axes(adapter, 83, Vector2.LEFT, Vector2.LEFT)
	check.call(await _tick(tree, player, adapter), "coleta: ativação deliberada ID83")
	check.call(adapter.active_device == 83 and player.velocity == Vector2(-240, 0),
		"coleta: ID correto, sem soma de dois controles")
	adapter.connected_ids = PackedInt32Array([37])
	Input.joy_connection_changed.emit(83, false)
	check.call(adapter.active_device == -1 and player.velocity == Vector2.ZERO and adapter.disconnected,
		"coleta: sinal de desconexão limpa ativo e velocidade imediatamente")
	main.set_paused(false)
	check.call(await _tick(tree, player, adapter), "coleta: após desconexão")
	check.call(player.velocity == Vector2.ZERO, "coleta: controle estável restante não recicla intenção")
	_key(window, true)
	check.call(await _tick(tree, player, adapter), "coleta: recuperação por teclado")
	check.call(player.velocity == Vector2(240, 0), "coleta: teclado recupera após desconexão")
	_key(window, false)
	adapter.connected_ids = PackedInt32Array([37, 83])
	Input.joy_connection_changed.emit(83, true)
	check.call(await _tick(tree, player, adapter), "coleta: reconexão retida")
	check.call(player.velocity == Vector2.ZERO and adapter.active_device == -1,
		"coleta: reconexão retida não reassume controle")
	_axes(adapter, 83, Vector2.ZERO, Vector2.ZERO)
	check.call(await _tick(tree, player, adapter), "coleta: neutro após reconexão")
	_axes(adapter, 83, Vector2(0, 0.6), Vector2.UP)
	check.call(await _tick(tree, player, adapter), "coleta: intenção nova após reconexão")
	check.call(adapter.active_device == 83 and player.velocity.distance_to(Vector2(0, 120)) < 0.001
		and player.aim_direction == Vector2.UP, "coleta: neutralização rearma reconexão pela coleta normal")
	window.free()
	tree.paused = false
	await tree.process_frame
	return true


func _test_global_key(tree: SceneTree, check: Callable) -> bool:
	var window := _unfocused_window(tree)
	# parse_input_event realmente altera o singleton Input. Não se chama _input no
	# adaptador e não se simula is_physical_key_pressed neste caso.
	_global_key(true)
	check.call(Input.is_physical_key_pressed(KEY_D), "coleta: engine confirma tecla física retida antes da cena")
	check.call(not window.has_focus(), "coleta: Window sem foco comprovada antes da instância nativa")
	var main := MAIN.instantiate()
	window.add_child(main)
	var lab := main.get_node("MovementLab")
	var player := lab.get_node("Actors/Player") as CharacterBody2D
	var adapter := lab.get_node("PlayerInput")
	_freeze(lab)
	check.call(not adapter.focus_active, "coleta: adaptador nativo consulta foco inicial real")
	check.call(await _tick(tree, player, adapter), "coleta: tecla global retida sem foco")
	check.call(player.velocity == Vector2.ZERO, "coleta: tecla global não move em segundo plano")
	window.focus_entered.emit()
	main.set_paused(false)
	_key(window, true)
	check.call(await _tick(tree, player, adapter), "coleta: entrega de tecla ainda retida ao retornar")
	check.call(player.velocity == Vector2.ZERO,
		"coleta: consulta global de tecla retida bloqueia pressão sem soltura anterior")
	_global_key(false)
	_key(window, false)
	check.call(await _tick(tree, player, adapter), "coleta: soltura global e local")
	check.call(not Input.is_physical_key_pressed(KEY_D) and player.velocity == Vector2.ZERO,
		"coleta: soltura é observada pela engine")
	_global_key(true)
	_key(window, true)
	check.call(await _tick(tree, player, adapter), "coleta: nova pressão global e local")
	check.call(player.velocity == Vector2(240, 0), "coleta: nova pressão após soltura recupera movimento")
	_global_key(false)
	_key(window, false)
	window.free()
	tree.paused = false
	await tree.process_frame
	check.call(not Input.is_physical_key_pressed(KEY_D), "coleta: limpeza não deixa tecla global presa")
	return true


func _unfocused_window(tree: SceneTree) -> Window:
	var window := Window.new()
	# Como a Window raiz do jogo, a fronteira de UI continua recebendo eventos na pausa.
	window.process_mode = Node.PROCESS_MODE_ALWAYS
	window.size = Vector2i(1280, 720)
	window.world_2d = World2D.new()
	window.visible = false
	tree.root.add_child(window)
	return window


func _axes(adapter: Node, device: int, move: Vector2, aim: Vector2) -> void:
	adapter.axes[device] = {JOY_AXIS_LEFT_X: move.x, JOY_AXIS_LEFT_Y: move.y,
		JOY_AXIS_RIGHT_X: aim.x, JOY_AXIS_RIGHT_Y: aim.y}


func _tick(tree: SceneTree, player: Node, adapter: Node) -> bool:
	var budget := TickBudget.new()
	budget.player = player
	budget.adapter = adapter
	budget.lab = adapter.get_parent()
	budget.process_mode = Node.PROCESS_MODE_ALWAYS
	budget.process_physics_priority = 100
	tree.root.add_child(budget)
	budget._set_ticks(budget.lab, true)
	await budget.finished
	await tree.process_frame
	var completed := budget.completed == 1
	budget.free()
	return completed


func _freeze(node: Node) -> void:
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)


func _key(window: Window, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = pressed
	window.push_input(event, true)


func _global_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

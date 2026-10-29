extends RefCounted
## Substitui somente leituras de hardware; coleta, foco, sinais e física são produção.
## A Window escondida tem has_focus=false real da engine, não foco simulado pelo stub.

const MAIN := preload("res://src/game/main.tscn")

class DeviceReads extends "res://src/player/player_input.gd":
	var connected_ids := PackedInt32Array([37, 83])
	var axes: Dictionary = {}
	func _read_connected_joypads() -> PackedInt32Array:
		return connected_ids
	func _read_joy_axis(device: int, axis: int) -> float:
		var values: Dictionary = axes.get(device, {})
		return float(values.get(axis, 0.0))

class TickBudget extends Node:
	signal finished
	var player: Node
	var adapter: Node
	var completed: int = 0
	func _physics_process(_delta: float) -> void:
		completed += 1
		player.set_physics_process(false)
		adapter.set_physics_process(false)
		set_physics_process(false)
		finished.emit()


func run(tree: SceneTree, check: Callable) -> bool:
	check.call(await _test_polling(tree, check) == true, "coleta normal de controles deve concluir")
	check.call(await _test_global_key(tree, check) == true, "estado global real de tecla deve concluir")
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
	check.call(not adapter.focus_active, "coleta: adaptador nativo consulta foco inicial real")
	check.call(await _tick(tree, player, adapter), "coleta: tecla global retida sem foco")
	check.call(player.velocity == Vector2.ZERO, "coleta: tecla global não move em segundo plano")
	window.focus_entered.emit()
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
	await tree.process_frame
	check.call(not Input.is_physical_key_pressed(KEY_D), "coleta: limpeza não deixa tecla global presa")
	return true


func _unfocused_window(tree: SceneTree) -> Window:
	var window := Window.new()
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
	budget.process_physics_priority = 100
	tree.root.add_child(budget)
	player.set_physics_process(true)
	adapter.set_physics_process(true)
	await budget.finished
	await tree.process_frame
	var completed := budget.completed == 1
	budget.free()
	return completed


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

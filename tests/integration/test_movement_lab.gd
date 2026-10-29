extends RefCounted
## Eventos e amostras sintéticos exercitam o adaptador real; não comprovam hardware.

const MAIN := "res://src/game/main.tscn"

class TickBudget extends Node:
	signal finished
	var player: Node
	var adapter: Node
	var target: int
	var completed: int = 0
	func _physics_process(_delta: float) -> void:
		completed += 1
		if completed == target:
			player.set_physics_process(false)
			adapter.set_physics_process(false)
			set_physics_process(false)
			finished.emit()


func run(tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(MAIN), "S1: Main jogável deve existir")
	if not ResourceLoader.exists(MAIN):
		return false
	var packed := load(MAIN) as PackedScene
	check.call(packed != null, "Main deve carregar")
	if packed == null:
		return false
	var before := Input.joy_connection_changed.get_connections().size()
	for iteration in range(2):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.world_2d = World2D.new()
		tree.root.add_child(viewport)
		var main := packed.instantiate()
		viewport.add_child(main)
		var lab := main.get_node_or_null("MovementLab")
		check.call(lab != null, "Main instancia laboratório")
		if lab == null:
			viewport.free()
			return false
		var player := lab.get_node_or_null("Actors/Player") as CharacterBody2D
		var adapter := lab.get_node_or_null("PlayerInput")
		var camera := lab.get_node_or_null("Actors/Player/Camera2D") as Camera2D
		check.call(player != null and adapter != null and camera != null, "dependências explícitas do laboratório")
		if player == null or adapter == null or camera == null:
			viewport.free()
			return false
		for method: String in ["sample_joypad", "set_focus_active", "_input", "_on_joy_connection_changed"]:
			check.call(adapter.has_method(method), "adaptador oferece rotina normal: " + method)
			if not adapter.has_method(method):
				viewport.free()
				return false
		check.call(adapter.focus_active == adapter.get_window().has_focus(), "cena nasce com foco real da janela, não presume foreground")
		check.call(player.position.is_equal_approx(Vector2(800, 500)), "início com 400x300 livres")
		check.call(camera.zoom == Vector2.ONE and not camera.position_smoothing_enabled
			and not camera.drag_horizontal_enabled and not camera.drag_vertical_enabled
			and camera.ignore_rotation and camera.limit_right == 1600 and camera.limit_bottom == 1000,
			"câmera sem atraso/rotação com limites da arena")
		check.call(player.get_parent().y_sort_enabled and player.z_index == 0, "atores compartilham Y-sort nos pés")
		for prop_name: String in ["LowBlock", "TallProp"]:
			var prop := player.get_parent().get_node_or_null(prop_name) as StaticBody2D
			check.call(prop != null and prop.z_index == player.z_index, "prop contornável ordenável: " + prop_name)
		check.call(Input.joy_connection_changed.get_connections().size() == before + 1, "uma conexão local por cena")
		check.call(await _test_input(tree, lab, player, adapter, camera, check) == true, "entrada deve concluir")
		check.call(await _test_geometry(tree, lab, player, adapter, check) == true, "geometria deve concluir")
		viewport.free()
		await tree.process_frame
		check.call(Input.joy_connection_changed.get_connections().size() == before, "recriação limpa conexão")
	var collection = load("res://tests/fixtures/test_player_input_collection.gd").new()
	check.call(await collection.run(tree, check) == true, "módulo de coleta normal deve concluir explicitamente")
	return true


func _test_input(tree: SceneTree, lab: Node, player: CharacterBody2D, adapter: Node,
		camera: Camera2D, check: Callable) -> bool:
	adapter.set_focus_active(true)
	adapter.sample_joypad(101, Vector2(0.6, 0), Vector2.UP)
	check.call(await _ticks(tree, player, adapter, 1), "tick de analógico parcial")
	check.call(player.velocity.is_equal_approx(Vector2(120, 0)), "deadzone única preserva analógico 0,6 em 120/s")
	check.call(player.aim_direction.is_equal_approx(Vector2.UP), "mira independente do movimento")
	check.call(adapter.aim_source == "gamepad", "controle deliberado seleciona mira")
	var direction: Vector2 = player.aim_direction
	player.position += Vector2(30, 25)
	camera.force_update_scroll()
	check.call(await _ticks(tree, player, adapter, 1), "tick com câmera movida")
	check.call(adapter.aim_source == "gamepad" and player.aim_direction == direction, "câmera/cursor parado não roubam mira")
	_mouse(adapter, Vector2(600, 300), Vector2.ONE)
	_mouse(adapter, Vector2(600.75, 300), Vector2(0.75, 0))
	check.call(await _ticks(tree, player, adapter, 1), "mouse abaixo do limiar")
	check.call(adapter.aim_source == "gamepad", "deslocamento subpixel não reivindica prematuramente")
	_mouse(adapter, Vector2(602, 300), Vector2(1.25, 0))
	adapter.sample_joypad(101, Vector2.ZERO, Vector2.DOWN)
	check.call(await _ticks(tree, player, adapter, 1), "empate mouse/controle")
	check.call(adapter.aim_source == "mouse", "2 pixels acumulados e empate favorecem mouse")
	adapter.sample_joypad(101, Vector2.ZERO, Vector2.DOWN)
	check.call(await _ticks(tree, player, adapter, 1), "amostra estável")
	check.call(adapter.aim_source == "mouse", "stick estável não reivindica novamente")
	adapter.sample_joypad(101, Vector2.ZERO, Vector2(0.02, 0.98))
	check.call(await _ticks(tree, player, adapter, 1), "mudança de mira abaixo0,05")
	check.call(adapter.aim_source == "mouse", "ruído inferior0,05 não troca fonte")
	adapter.sample_joypad(101, Vector2.ZERO, Vector2(0.06, 0.94))
	check.call(await _ticks(tree, player, adapter, 1), "mudança acumulada de mira")
	check.call(adapter.aim_source == "gamepad", "mudança significativa acumulada reivindica controle")
	var mouse_target := Vector2(250, 400)
	_mouse(adapter, mouse_target, Vector2(10, 0))
	check.call(await _ticks(tree, player, adapter, 1), "conversão mouse/câmera")
	var world_target: Vector2 = player.get_canvas_transform().affine_inverse() * mouse_target
	check.call(player.aim_direction.distance_to((world_target - player.global_position).normalized()) < 0.001,
		"mouse usa câmera atual e origem física dos pés")
	player.position += Vector2(40, -50)
	camera.force_update_scroll()
	check.call(await _ticks(tree, player, adapter, 1), "mouse fonte acompanha câmera")
	world_target = player.get_canvas_transform().affine_inverse() * mouse_target
	check.call(player.aim_direction.distance_to((world_target - player.global_position).normalized()) < 0.001,
		"mouse fonte atualiza direção mundial sem gerar atividade")
	adapter.sample_joypad(101, Vector2.RIGHT, Vector2.ZERO)
	adapter.sample_joypad(103, Vector2.LEFT, Vector2.ZERO)
	check.call(await _ticks(tree, player, adapter, 1), "dois controles simultâneos")
	check.call(player.velocity.is_equal_approx(Vector2(-240, 0)) and adapter.active_device == 103,
		"somente último controle deliberado move, sem soma de IDs")
	_key(adapter, KEY_D, true)
	adapter.sample_joypad(102, Vector2.LEFT, Vector2.LEFT)
	check.call(await _ticks(tree, player, adapter, 1), "teclado sobre controle")
	check.call(player.velocity.is_equal_approx(Vector2(240, 0)) and adapter.active_device == 102,
		"teclado recupera e controles não somam")
	_key(adapter, KEY_A, true)
	check.call(await _ticks(tree, player, adapter, 1), "opostos cancelam")
	check.call(player.velocity == Vector2.ZERO, "opostos ativos vencem controle")
	direction = player.aim_direction
	adapter.set_focus_active(false)
	adapter.set_focus_active(false)
	check.call(player.velocity == Vector2.ZERO and player.aim_direction == direction, "perda de foco para imediatamente e preserva mira")
	_key(adapter, KEY_D, true)
	adapter.sample_joypad(102, Vector2.RIGHT, Vector2.RIGHT)
	check.call(await _ticks(tree, player, adapter, 1), "sem foco")
	check.call(player.velocity == Vector2.ZERO and player.aim_direction == direction, "entrada sem foco ignorada")
	adapter.get_window().focus_entered.emit()
	check.call(adapter.focus_active, "sinal real da janela rearma fluxo de foco")
	_key(adapter, KEY_D, true)
	_key(adapter, KEY_A, true)
	adapter.sample_joypad(102, Vector2.RIGHT, Vector2.RIGHT)
	check.call(await _ticks(tree, player, adapter, 1), "retorno retido")
	check.call(player.velocity == Vector2.ZERO and player.aim_direction == direction, "retorno exige rearmamento e preserva mira")
	_key(adapter, KEY_D, false)
	_key(adapter, KEY_A, false)
	_key(adapter, KEY_D, true)
	check.call(await _ticks(tree, player, adapter, 1), "repressão deliberada")
	check.call(player.velocity.x == 240, "soltar/repressionar recupera teclado")
	_key(adapter, KEY_D, false)
	adapter.sample_joypad(102, Vector2.ZERO, Vector2.ZERO)
	adapter.sample_joypad(102, Vector2(0.6, 0), Vector2.DOWN)
	check.call(await _ticks(tree, player, adapter, 1), "sticks rearmados")
	check.call(player.velocity.x == 120 and adapter.aim_source == "gamepad", "neutralização rearma sticks")
	Input.joy_connection_changed.emit(102, false)
	check.call(adapter.active_device == -1 and player.velocity == Vector2.ZERO, "desconexão limpa ativo e velocidade")
	Input.joy_connection_changed.emit(102, true)
	adapter.sample_joypad(102, Vector2.RIGHT, Vector2.RIGHT)
	check.call(await _ticks(tree, player, adapter, 1), "reconexão retida")
	check.call(player.velocity == Vector2.ZERO, "reconectar não recicla intenção retida")
	_key(adapter, KEY_W, true)
	check.call(await _ticks(tree, player, adapter, 1), "recuperação após desconexão")
	check.call(player.velocity.is_equal_approx(Vector2(0, -240)), "teclado recupera após desconexão")
	_key(adapter, KEY_W, false)
	adapter.get_window().focus_exited.emit()
	check.call(not adapter.focus_active, "sinal real da janela para entrada")
	adapter.set_focus_active(true)
	direction = player.aim_direction
	_mouse(adapter, Vector2(100, 100), Vector2(100, 100))
	check.call(await _ticks(tree, player, adapter, 1), "primeiro mouse após foco")
	check.call(player.aim_direction == direction, "primeiro evento só restabelece referência")
	var feet: Vector2 = player.get_global_transform_with_canvas().origin
	_mouse(adapter, feet, feet - Vector2(100, 100))
	check.call(await _ticks(tree, player, adapter, 1), "mouse nos pés")
	check.call(player.aim_direction == direction, "mouse nos pés preserva direção válida")
	adapter.sample_joypad(103, Vector2(NAN, INF), Vector2(INF, NAN))
	check.call(await _ticks(tree, player, adapter, 1), "amostras inválidas")
	check.call(player.velocity.is_finite() and player.aim_direction.is_finite(), "amostras inválidas não chegam à física")
	var state := lab.get_node("HUD/Panel/Margin/Rows/State") as Label
	check.call(state.text.contains("Foco") and state.text.contains("Mira"), "HUD informa foco e fonte efetiva")
	return true


func _test_geometry(tree: SceneTree, lab: Node, player: CharacterBody2D, adapter: Node, check: Callable) -> bool:
	adapter.set_focus_active(false)
	adapter.set_focus_active(true)
	player.position = Vector2(40, 500)
	_key(adapter, KEY_A, true)
	check.call(await _ticks(tree, player, adapter, 20), "limite contínuo")
	check.call(player.position.x >= 9.5 and player.position.x <= 10.5, "limite bloqueia pés com raio10")
	_key(adapter, KEY_A, false)
	player.position = Vector2(1100, 575)
	_key(adapter, KEY_W, true)
	check.call(await _ticks(tree, player, adapter, 20), "colisão do prop alto")
	check.call(player.position.y >= 549.5 and player.position.y <= 550.5, "prop alto bloqueia base, não topo visual")
	_key(adapter, KEY_W, false)
	player.position = Vector2(500, 760)
	_key(adapter, KEY_D, true)
	check.call(await _ticks(tree, player, adapter, 30), "passagem real")
	check.call(absf(player.position.x - 620) < 0.5, "passagem60 permite circulação sem atravessar shapes")
	_key(adapter, KEY_D, false)
	var title := lab.get_node("HUD/Panel/Margin/Rows/Title") as Label
	check.call(title.text == "S1 · Blockout temporário — movimento e mira", "blockout claramente identificado")
	return true


func _ticks(tree: SceneTree, player: Node, adapter: Node, count: int) -> bool:
	var budget := TickBudget.new()
	budget.player = player
	budget.adapter = adapter
	budget.target = count
	budget.process_physics_priority = 100
	tree.root.add_child(budget)
	player.set_physics_process(true)
	adapter.set_physics_process(true)
	await budget.finished
	await tree.process_frame
	var completed := budget.completed == count
	budget.free()
	return completed


func _key(adapter: Node, code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	adapter.get_viewport().push_input(event, true)


func _mouse(adapter: Node, position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = relative
	adapter.get_viewport().push_input(event, true)

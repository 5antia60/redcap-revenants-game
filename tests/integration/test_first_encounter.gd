extends RefCounted
## Detecta conclusão antecipada, sinais velhos, falha aberta e dano após resultado.

const PATH := "res://src/arenas/first_encounter.tscn"
const MAIN := preload("res://src/game/main.tscn")

class LifecycleReads extends "res://tests/fixtures/s3_input_reads.gd":
	# Só instrumenta leitura de hardware. Callbacks/coleta continuam em produção.
	var key_reads := 0
	func _read_physical_key_pressed(key: int) -> bool:
		key_reads += 1
		return super._read_physical_key_pressed(key)

class Budget extends Node:
	signal finished
	var arena: Node
	var count: int
	var observed := 0
	func _physics_process(_delta: float) -> void:
		observed += 1
		if observed == count:
			freeze(arena)
			set_physics_process(false)
			finished.emit()
	func freeze(node: Node) -> void:
		node.set_physics_process(false)
		for child: Node in node.get_children():
			freeze(child)

func run(tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(PATH), "S3: encontro próprio deve existir")
	if not ResourceLoader.exists(PATH):
		return false
	var saved := tree.paused
	check.call(await _cycle(tree, check), "S3: contagem e falhas concluem explicitamente")
	check.call(await _main_cycle(tree, check), "S3: Main real reinicia sem callbacks antigos")
	check.call(await _missing_player(tree, check), "S3: falha sem jogador continua recuperável")
	check.call(await _external_lifecycle(tree, check), "S3: sinais externos não alcançam receptor antigo")
	check.call(await _tie(tree, check), "S3: arbitragem recebe última morte válida reentrante")
	check.call(await _ground_layer(tree, check), "S3: setor hostil pertence ao chão")
	check.call(await _retained(tree, check), "S3: entrada retida não atravessa foco/reinício")
	check.call(await _suspension(tree, check), "S3: fases nativas e suspensão concluem explicitamente")
	tree.paused = saved
	return true

func _retained(tree: SceneTree, check: Callable) -> bool:
	tree.paused = false
	var world := _world(tree)
	var main := MAIN.instantiate()
	# Leituras por ID37 são a única substituição. Coleta/GUI/pausa seguem reais.
	main.child_entered_tree.connect(func(child: Node) -> void:
		if child.name == "FirstEncounter":
			var adapter := child.get_node("PlayerInput")
			adapter.set_script(preload("res://tests/fixtures/s3_input_reads.gd"))
			adapter.player = child.get_node("Actors/Player")
			adapter.buttons = {JOY_BUTTON_X: true})
	world.add_child(main)
	for iteration: int in range(4):
		if iteration > 0:
			main.restart_encounter()
			await tree.process_frame
		var arena := _start(main)
		var player := arena.get_node("Actors/Player")
		var adapter := arena.get_node("PlayerInput")
		var actors: Array[Node] = [adapter, player]
		check.call(await preload("res://tests/fixtures/s3_native_ticks.gd").run(tree, actors, 1), "S3: coleta nativa de botão retido")
		check.call(player.action_state.attack_serial == 0 and player.action_state.phase == 0, "S3: entrada retida no início/três reinícios não ataca")
		adapter.buttons.clear()
		check.call(await preload("res://tests/fixtures/s3_native_ticks.gd").run(tree, actors, 1), "S3: soltura real pela fronteira de leitura")
		adapter.buttons[JOY_BUTTON_X] = true
		check.call(await preload("res://tests/fixtures/s3_native_ticks.gd").run(tree, actors, 1), "S3: nova pressão após soltura")
		check.call(player.action_state.attack_serial == 1 and player.action_state.phase == 1, "S3: nova pressão, não buffer, inicia ação")
		adapter.set_focus_active(false)
		adapter.set_focus_active(true)
		main.set_paused(false)
		check.call(await preload("res://tests/fixtures/s3_native_ticks.gd").run(tree, actors, 1), "S3: retorno com botão ainda retido")
		check.call(player.action_state.attack_serial == 1 and player.action_state.phase == 0, "S3: foco limpa ação e exige nova borda")
	main.get_node("FirstEncounter").shutdown()
	world.free()
	tree.paused = false
	return true

func _world(tree: SceneTree) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(viewport)
	return viewport

func _freeze(node: Node) -> void:
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _start(main: Node) -> Node:
	var arena := main.get_node("FirstEncounter")
	_freeze(arena)
	arena.get_node("PlayerInput").set_focus_active(true)
	main.set_paused(false)
	arena.get_node("Actors/Player").audio_enabled = false
	return arena

func _cycle(tree: SceneTree, check: Callable) -> bool:
	for kind: String in ["victory", "duplicate", "remove", "missing", "duplicate-register", "defeat"]:
		tree.paused = false
		var world := _world(tree)
		var main := MAIN.instantiate()
		var arena := main.get_node("FirstEncounter")
		var events: Array[String] = []
		arena.finished.connect(func(outcome: String) -> void: events.append(outcome))
		if kind == "missing":
			arena.enemy_paths[2] = NodePath("Actors/Missing")
		elif kind == "duplicate-register":
			arena.enemy_paths[2] = arena.enemy_paths[1]
		world.add_child(main)
		_start(main)
		var player := arena.get_node("Actors/Player")
		var enemies: Array[Node] = [arena.get_node("Actors/Enemy1"), arena.get_node("Actors/Enemy2"), arena.get_node("Actors/Enemy3")]
		if kind in ["missing", "duplicate-register"]:
			check.call(arena.state == "failed" and events == ["failed"], "S3: registro inválido falha sem vitória: " + kind)
			check.call(not player.receive_hit(10) and not enemies[0].receive_hit(10), "S3: registro incompleto não habilita combate")
		else:
			check.call(arena.state == "running" and arena.remaining == 3 and events.is_empty(), "S3: três vivos impedem conclusão")
			check.call(player.get_parent().y_sort_enabled and not arena.has_node("DamageZone") and not arena.has_node("Actors/Target1"), "S3: inimigos reais sob Y-sort, sem treino")
			for enemy: Node in enemies:
				check.call(enemy.health.current == 30 and enemy.position.distance_to(player.position) > 60.0, "S3: nascimento visível separado do jogador")
			if kind == "duplicate":
				enemies[0].died.emit()
				check.call(arena.remaining == 3 and events.is_empty(), "S3: sinal de corpo ainda vivo não remove ID")
			if kind == "remove":
				arena.get_node("Actors").remove_child(enemies[0])
				check.call(arena.state == "failed" and events == ["failed"] and not player.receive_hit(10), "S3: remoção inesperada encerra em falha segura")
				enemies[0].free()
			elif kind == "defeat":
				check.call(player.receive_hit(100), "S3: dano letal aceito pelo jogador real")
				check.call(arena.state == "defeat" and events == ["defeat"], "S3: vida já letal prevalece mesmo antes de died: " + kind)
				enemies[2].died.emit()
				check.call(events == ["defeat"] and not enemies[2].receive_hit(30), "S3: derrota nunca vira vitória posterior")
			else:
				for index: int in range(3):
					check.call(enemies[index].receive_hit(30), "S3: morte válida aceita uma vez")
					check.call(arena.remaining == 2 - index, "S3: contagem3/2/1/0 por identidade")
					enemies[index].died.emit()
					check.call(arena.remaining == 2 - index and events.size() == (1 if index == 2 else 0), "S3: duplicata não remove outro ID nem repete resultado")
				check.call(arena.state == "completed" and events == ["completed"], "S3: somente última morte conclui")
				check.call(not player.receive_hit(10), "S3: jogador não recebe dano depois da vitória")
				player.queue_actions(true, true)
				check.call(player.action_state.phase == 0 and not player.active_snapshot, "S3: resultado cancela combate do jogador")
		world.free()
		tree.paused = false
		await tree.process_frame
	return true

func _missing_player(tree: SceneTree, check: Callable) -> bool:
	for kind: String in ["removed", "freed"]:
		tree.paused = false
		var world := _world(tree)
		var main := MAIN.instantiate()
		world.add_child(main)
		var arena := _start(main)
		var old_id := arena.get_instance_id()
		var player := arena.get_node("Actors/Player")
		main.set_process(false)
		if kind == "removed":
			player.get_parent().remove_child(player)
		else:
			player.queue_free()
			await tree.process_frame
		check.call(arena.state == "failed", "S3: ausência do jogador marca falha: " + kind)
		main.set_paused(false)
		main._suspend("Jogador indisponível")
		check.call(tree.paused and main._overlay.visible and not main._continue.visible, "S3: menu sem jogador não oferece continuar: " + kind)
		main._request_restart()
		await tree.process_frame
		var fresh := main.get_node("FirstEncounter")
		check.call(fresh.get_instance_id() != old_id and not main._restarting, "S3: reinício sem jogador troca arena e libera guarda: " + kind)
		if fresh.get_instance_id() != old_id:
			_freeze(fresh)
			check.call(fresh.state == "running" and fresh.remaining == 3 and fresh.get_node("Actors/Player").health.current == 100, "S3: recuperação restaura vida100 e contagem3: " + kind)
		else:
			check.call(false, "S3: nova arena obrigatória depois da falha: " + kind)
		if fresh.get_instance_id() == old_id and not is_instance_valid(player):
			# Só limpeza do RED: as falhas já foram registradas. Repor referência
			# válida antes da desmontagem evita continuar por ponteiros inválidos.
			var cleanup_player := preload("res://src/player/player.tscn").instantiate()
			fresh.get_node("Actors").add_child(cleanup_player)
			fresh.player = cleanup_player
			fresh.get_node("PlayerInput").player = cleanup_player
			fresh._connections.clear()
		world.free()
		if kind == "removed" and is_instance_valid(player):
			player.free()
		tree.paused = false
		await tree.process_frame
	return true

func _tie(tree: SceneTree, check: Callable) -> bool:
	tree.paused = false
	var world := _world(tree)
	var main := MAIN.instantiate()
	var arena := main.get_node("FirstEncounter")
	var player := arena.get_node("Actors/Player")
	var last := arena.get_node("Actors/Enemy3")
	var trace: Array[String] = []
	var results: Array[String] = []
	var callbacks := {"enemy": 0, "player": 0, "death": 0, "player_death": 0, "accepted_player": false, "valid_window": false}
	# A perda letal do inimigo é aceita ENQUANTO o alvo vive. O callback changed
	# causa dano letal real no jogador. Dentro desse changed, antecipar a notificação
	# já devida de Health (morto/vida0), antes de Player.died. A notificação normal
	# repetida ao desenrolar a pilha deve continuar emitindo Enemy.died só uma vez.
	last.died.connect(func() -> void:
		callbacks.death += 1
		callbacks.valid_window = last.health.dead and last.health.current == 0 and player.health.dead and callbacks.player_death == 0
		trace.append("last-died"))
	player.died.connect(func() -> void:
		callbacks.player_death += 1
		trace.append("player-died"))
	arena.finished.connect(func(outcome: String) -> void:
		results.append(outcome)
		trace.append("result:" + outcome))
	last.health.changed.connect(func(life: int, _maximum: int) -> void:
		if life == 0:
			callbacks.enemy += 1
			trace.append("enemy-health-dead")
			callbacks.accepted_player = player.receive_hit(100))
	player.health.changed.connect(func(life: int, _maximum: int) -> void:
		if life == 0:
			callbacks.player += 1
			trace.append("player-health-dead")
			last.health.died.emit())
	world.add_child(main)
	_start(main)
	arena.get_node("Actors/Enemy1").receive_hit(30)
	arena.get_node("Actors/Enemy2").receive_hit(30)
	check.call(arena.remaining == 1 and results.is_empty(), "S3 tie: apenas último ID ainda ativo")
	var accepted: bool = last.receive_hit(30)
	check.call(accepted and callbacks.accepted_player and callbacks.enemy == 1 and callbacks.player == 1, "S3 tie: ambos danos letais realmente aceitos e callbacks executados")
	check.call(last.health.dead and last.health.current == 0 and callbacks.death == 1 and callbacks.player_death == 1 and callbacks.valid_window, "S3 tie: morte válida única na janela anterior a Player.died")
	check.call(trace == ["enemy-health-dead", "player-health-dead", "last-died", "result:defeat", "player-died"], "S3 tie: ordem causal completa: " + str(trace))
	check.call(arena.state == "defeat" and results == ["defeat"], "S3 tie: arbitragem não publica vitória após vida letal")
	check.call(not player.receive_hit(1) and not last.receive_hit(1), "S3 tie: nenhum dano depois do resultado")
	arena.shutdown()
	world.free()
	tree.paused = false
	return true

func _external_counts(window: Window, receiver_id: int) -> Array[int]:
	var counts: Array[int] = []
	for event: Signal in [window.focus_exited, window.focus_entered, Input.joy_connection_changed]:
		var count := 0
		for connection: Dictionary in event.get_connections():
			if connection.callable.get_object_id() == receiver_id:
				count += 1
		counts.append(count)
	return counts

func _emit_external(window: Window) -> void:
	# Emissores reais, não callbacks do adaptador nem Main._suspend manual.
	Input.joy_connection_changed.emit(37, false)
	window.focus_exited.emit()
	window.focus_entered.emit()

func _external_lifecycle(tree: SceneTree, check: Callable, kinds: Array[String] = ["removed", "freed"]) -> bool:
	for kind: String in kinds:
		tree.paused = false
		var world := _world(tree)
		var main := MAIN.instantiate()
		main.child_entered_tree.connect(func(child: Node) -> void:
			if child.name == "FirstEncounter":
				var input := child.get_node("PlayerInput")
				input.set_script(LifecycleReads)
				input.player = child.get_node("Actors/Player"))
		world.add_child(main)
		var arena := _start(main)
		var player := arena.get_node("Actors/Player")
		var adapter := arena.get_node("PlayerInput")
		var window := adapter.get_window()
		var adapter_id := adapter.get_instance_id()
		check.call(_external_counts(window, adapter_id) == [1, 1, 1], "S3 lifecycle: três sinais realmente conectados antes da perda: " + kind)
		var seen := [0, 0, 0]
		var on_exit := func() -> void: seen[0] += 1
		var on_enter := func() -> void: seen[1] += 1
		var on_joy := func(device: int, _connected: bool) -> void:
			if device == 37: seen[2] += 1
		window.focus_exited.connect(on_exit)
		window.focus_entered.connect(on_enter)
		Input.joy_connection_changed.connect(on_joy)
		var old_suspensions := [0]
		adapter.suspension_requested.connect(func(_reason: String) -> void: old_suspensions[0] += 1)
		adapter.sample_joypad(37, Vector2.ZERO, Vector2.ZERO)
		adapter.sample_joypad(37, Vector2.RIGHT, Vector2.RIGHT)
		check.call(adapter.active_device == 37, "S3 lifecycle: controle ativo prepara callback real")
		adapter._attack_edge = true
		adapter._dodge_edge = true
		adapter._button_edges[37] = {"attack": true}
		adapter._keys[KEY_D] = true
		var reads_before_loss: int = adapter.key_reads
		if kind == "removed":
			player.get_parent().remove_child(player)
			# Marcadores após neutralização do dono: nenhum callback tardio pode mudar.
			player.velocity = Vector2(13, 7)
			player.aim_direction = Vector2.LEFT
		else:
			player.queue_free()
			await tree.process_frame
		check.call(_external_counts(window, adapter_id) == [0, 0, 0], "S3 lifecycle: conexões externas antigas ausentes ANTES do reinício: " + kind)
		check.call(adapter.player == null and adapter.active_device == -1, "S3 lifecycle: receptor e seleção antigos neutralizados: " + kind)
		check.call(adapter.key_reads == reads_before_loss and adapter._devices.is_empty() and adapter._keys.is_empty()
			and adapter._button_edges.is_empty() and not adapter._attack_edge and not adapter._dodge_edge,
			"S3 lifecycle: perda limpa pendências sem rearme/coleta no teardown")
		var reads: int = adapter.key_reads
		_emit_external(window)
		check.call(seen == [1, 1, 1], "S3 lifecycle: três emissores externos executados uma vez")
		check.call(adapter.key_reads == reads and old_suspensions[0] == 0, "S3 lifecycle: zero coleta/rearmamento/suspensão antigos após sinais: " + kind)
		if kind == "removed":
			check.call(player.velocity == Vector2(13, 7) and player.aim_direction == Vector2.LEFT and player.health.current == 100, "S3 lifecycle: nenhum movimento/mira/dano no receptor removido")
		else:
			check.call(not is_instance_valid(player), "S3 lifecycle: receptor realmente excluído antes dos sinais")
		check.call(arena.state == "failed" and tree.paused and main._overlay.visible and not main._continue.visible, "S3 lifecycle: menu de falha recuperável depois dos sinais")
		adapter.detach_player()
		adapter.detach_player()
		check.call(_external_counts(window, adapter_id) == [0, 0, 0] and adapter.key_reads == reads, "S3 lifecycle: teardown repetido não reconecta nem rearma")
		for iteration: int in range(3):
			var old_id := arena.get_instance_id()
			main.restart_encounter()
			main.restart_encounter()
			check.call(_external_counts(window, adapter_id) == [0, 0, 0] and adapter.player == null, "S3 lifecycle: desligamento precede deferred e é idempotente")
			await tree.process_frame
			arena = _start(main)
			adapter = arena.get_node("PlayerInput")
			var fresh_player := arena.get_node("Actors/Player")
			check.call(arena.get_instance_id() != old_id and not main._restarting and arena.remaining == 3 and fresh_player.health.current == 100, "S3 lifecycle: três reinícios restauram100/3/flag")
			check.call(_external_counts(window, adapter_id) == [0, 0, 0] and _external_counts(window, adapter.get_instance_id()) == [1, 1, 1], "S3 lifecycle: conexão nova única, antiga não reaparece")
			var suspensions := [0]
			adapter.suspension_requested.connect(func(_reason: String) -> void: suspensions[0] += 1)
			adapter.sample_joypad(37, Vector2.ZERO, Vector2.ZERO)
			adapter.sample_joypad(37, Vector2.RIGHT, Vector2.RIGHT)
			Input.joy_connection_changed.emit(37, false)
			check.call(suspensions[0] == 1 and adapter.disconnected and adapter.active_device == -1 and tree.paused, "S3 lifecycle: desconexão nova funcional, sem callback duplicado")
			window.focus_exited.emit()
			window.focus_entered.emit()
			check.call(suspensions[0] == 2 and adapter.focus_active and adapter.player == fresh_player, "S3 lifecycle: foco externo novo funcional com receptor válido")
			main.set_paused(false)
			adapter_id = adapter.get_instance_id()
		arena.shutdown()
		world.free()
		if kind == "removed" and is_instance_valid(player): player.free()
		window.focus_exited.disconnect(on_exit)
		window.focus_entered.disconnect(on_enter)
		Input.joy_connection_changed.disconnect(on_joy)
		tree.paused = false
		await tree.process_frame
	return true

func _ground_layer(tree: SceneTree, check: Callable) -> bool:
	tree.paused = false
	var world := _world(tree)
	var main := MAIN.instantiate()
	world.add_child(main)
	var arena := _start(main)
	var ground := arena.get_node("Actors/Enemy1").get_node_or_null("GroundSector") as Node2D
	check.call(ground != null, "S3: setor tem CanvasItem nativo separado do corpo")
	if ground != null:
		check.call(not ground.z_as_relative and ground.z_index == -1 and arena.get_node("Floor").z_index < -1, "S3: setor absoluto acima do piso e abaixo dos corpos")
		check.call(arena.get_node("Actors").y_sort_enabled and arena.get_node("Actors/Player").z_index == 0 and arena.get_node("Actors/Enemy1").z_index == 0, "S3: corpos preservam Y-sort e índice0")
	arena.shutdown()
	world.free()
	tree.paused = false
	return true

func _main_cycle(tree: SceneTree, check: Callable) -> bool:
	tree.paused = false
	var world := _world(tree)
	var main := MAIN.instantiate()
	world.add_child(main)
	var arena := _start(main)
	var player := arena.get_node("Actors/Player")
	var connections := Input.joy_connection_changed.get_connections().size()
	main.set_paused(true)
	main._request_restart()
	check.call(main._confirming and main._cancel.visible, "S3: reinício vivo exige confirmação")
	main._cancel.pressed.emit()
	check.call(not main._confirming and main.get_node("FirstEncounter") == arena and player.health.current == 100, "S3: cancelar preserva tentativa e pausa")
	for iteration: int in range(3):
		var id := arena.get_instance_id()
		var old_finished: Array = arena.finished.get_connections()
		main.restart_encounter()
		main.restart_encounter()
		check.call(not player.receive_hit(10) and not arena.get_node("Actors/Enemy1").receive_hit(10), "S3: troca bloqueia ambos antes do deferred")
		for connection: Dictionary in old_finished:
			connection.callable.call("completed")
		check.call(main.pause_reason != "Encontro concluído", "S3: callback antigo invalidado antes da troca")
		await tree.process_frame
		arena = _start(main)
		player = arena.get_node("Actors/Player")
		check.call(arena.get_instance_id() != id and main.get_child_count() == 2 and arena.state == "running" and arena.remaining == 3, "S3: dois pedidos produzem uma arena nova")
		check.call(player.health.current == 100 and player.action_state.attack_serial == 0 and player.action_state.cooldown_remaining == 0.0, "S3: reinício restaura jogador e relógios")
		for name: String in ["Enemy1", "Enemy2", "Enemy3"]:
			var enemy := arena.get_node("Actors/" + name)
			check.call(enemy.health.current == 30 and enemy.action_state.attack_serial == 0 and enemy.action_state.phase == 0, "S3: reinício restaura cada inimigo")
		check.call(Input.joy_connection_changed.get_connections().size() == connections, "S3: três reinícios não acumulam conexões")
	world.free()
	tree.paused = false
	return true

func _ticks(tree: SceneTree, arena: Node, count: int) -> int:
	var observer := Budget.new()
	observer.arena = arena
	observer.count = count
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	observer.process_physics_priority = 100
	tree.root.add_child(observer)
	# O adaptador é exercitado separadamente para não sobrescrever intenção explícita.
	arena.get_node("Actors/Player").set_physics_process(true)
	for name: String in ["Enemy1", "Enemy2", "Enemy3"]:
		arena.get_node("Actors/" + name).set_physics_process(true)
	await observer.finished
	var observed := observer.observed
	await tree.process_frame
	observer.free()
	return observed

func _suspension(tree: SceneTree, check: Callable) -> bool:
	for sample: Dictionary in [{"ticks": 2, "phase": 1}, {"ticks": 38, "phase": 2}, {"ticks": 45, "phase": 3}]:
		tree.paused = false
		var world := _world(tree)
		var main := MAIN.instantiate()
		world.add_child(main)
		var arena := _start(main)
		var player := arena.get_node("Actors/Player")
		var adapter := arena.get_node("PlayerInput")
		var enemy := arena.get_node("Actors/Enemy1")
		enemy.position = player.position + Vector2(45, 0)
		for name: String in ["Enemy2", "Enemy3"]:
			arena.get_node("Actors/" + name).position = Vector2(1400, 200)
		check.call(await _ticks(tree, arena, sample.ticks) == sample.ticks and enemy.action_state.phase == sample.phase, "S3: fase preparada por callbacks físicos nativos: %s" % sample)
		var serial: int = enemy.action_state.attack_serial
		var life: int = player.health.current
		main.set_paused(true)
		check.call(await _ticks(tree, arena, 3) == 3 and enemy.action_state.phase == sample.phase and player.health.current == life, "S3: pausa manual congela fase e dano")
		main.set_paused(false)
		check.call(enemy.action_state.phase == sample.phase and enemy.action_state.attack_serial == serial, "S3: retorno manual conserva ação")
		adapter.active_device = 37
		Input.joy_connection_changed.emit(37, false)
		check.call(tree.paused and enemy.action_state.phase == 0 and not enemy.active_snapshot, "S3: desconexão cancela cada fase sincronamente")
		main.set_paused(false)
		check.call(await _ticks(tree, arena, sample.ticks) == sample.ticks and enemy.action_state.phase == sample.phase, "S3: fase recriada nativamente depois da desconexão")
		serial = enemy.action_state.attack_serial
		life = player.health.current
		adapter.set_focus_active(false)
		check.call(tree.paused and enemy.action_state.phase == 0 and not enemy.active_snapshot, "S3: foco cancela inimigos sincronamente antes de suspender")
		adapter.set_focus_active(true)
		main.set_paused(false)
		check.call(await _ticks(tree, arena, 35) == 35 and player.health.current == life and enemy.action_state.phase == 1, "S3: nova preparação ainda sem dano no tick35")
		check.call(await _ticks(tree, arena, 1) == 1 and player.health.current == life and enemy.action_state.phase == 2 and not enemy.active_snapshot, "S3: limite0,60 não inventa duração positiva")
		check.call(await _ticks(tree, arena, 1) == 1 and player.health.current == life - 10 and enemy.action_state.attack_serial == serial + 1, "S3: somente nova janela integral aplica próximo dano")
		adapter.active_device = 37
		Input.joy_connection_changed.emit(37, false)
		check.call(tree.paused and enemy.action_state.phase == 0 and not enemy.active_snapshot, "S3: desconexão interrompe também inimigos")
		world.free()
		tree.paused = false
		await tree.process_frame
	return true

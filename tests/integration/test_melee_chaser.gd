extends RefCounted
## Casos simultâneos em mundos isolados, dirigidos somente por callbacks nativos.
## Detecta broadphase antiga, dano duplicado, bypass de proteção e continuidade reentrante.

const ENEMY := "res://src/enemies/melee_chaser.tscn"
const PLAYER := preload("res://src/player/player.tscn")

class Budget extends Node:
	signal finished
	var tick: int = 0
	var limit: int
	var before: Callable
	var after: Callable
	var actors: Array[Node] = []
	var completed: bool = true
	var expired: bool = false
	func _physics_process(_delta: float) -> void:
		tick += 1
		if after.is_valid():
			completed = (after.call(tick) == true) and completed
		if tick == limit:
			for actor: Node in actors:
				if is_instance_valid(actor):
					actor.set_physics_process(false)
			set_physics_process(false)
			finished.emit()
	func expire() -> void:
		expired = true
		set_physics_process(false)
		finished.emit()

class Before extends Node:
	var budget: Budget
	func _physics_process(_delta: float) -> void:
		if budget.before.is_valid():
			budget.completed = (budget.before.call(budget.tick + 1) == true) and budget.completed


func run(tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(ENEMY), "S3: cena real do perseguidor deve existir")
	if not ResourceLoader.exists(ENEMY):
		return false
	var packed := load(ENEMY) as PackedScene
	if packed == null:
		return false
	check.call(await _combat(tree, packed, check), "S3: combate/ciclo nativo deve concluir")
	check.call(await _baton_and_callbacks(tree, packed, check), "S3: cassetete/reentrância devem concluir")
	check.call(await _moving_sample(tree, packed, check), "S3: amostragem após movimento real deve concluir")
	check.call(await _coarse_step(tree, packed, check), "S3: janela atravessada nativamente deve concluir")
	return true


func _case(tree: SceneTree, packed: PackedScene, offset := Vector2(45, 0), enable: bool = true) -> Dictionary:
	var world := SubViewport.new()
	world.world_2d = World2D.new()
	tree.root.add_child(world)
	var player = PLAYER.instantiate()
	player.position = offset
	player.audio_enabled = false
	player.set_physics_process(false)
	world.add_child(player)
	var enemy = packed.instantiate()
	enemy.set_physics_process(false)
	world.add_child(enemy)
	enemy.set_target(player)
	if enable:
		enemy.set_encounter_enabled(true)
	return {"world": world, "player": player, "enemy": enemy}


func _wall(world: Node, position := Vector2(22, 0)) -> void:
	var wall := StaticBody2D.new()
	wall.position = position
	wall.collision_layer = 1
	wall.collision_mask = 0
	var feet := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 100)
	feet.shape = rectangle
	wall.add_child(feet)
	world.add_child(wall)


func _run_ticks(tree: SceneTree, actors: Array[Node], limit: int,
		before: Callable, after: Callable) -> bool:
	var observer := Budget.new()
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	observer.process_physics_priority = 100
	observer.limit = limit
	observer.actors = actors
	observer.before = before
	observer.after = after
	var driver := Before.new()
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	driver.process_physics_priority = -100
	driver.budget = observer
	tree.root.add_child(driver)
	tree.root.add_child(observer)
	for actor: Node in actors:
		actor.set_physics_process(true)
	var watchdog := tree.create_timer(5.0, true, false, true)
	watchdog.timeout.connect(observer.expire)
	await observer.finished
	for actor: Node in actors:
		if is_instance_valid(actor):
			actor.set_physics_process(false)
	driver.set_physics_process(false)
	await tree.process_frame
	var completed := not observer.expired and observer.tick == limit and observer.completed
	print("S3 native ticks: ", observer.tick, "/", limit)
	watchdog.timeout.disconnect(observer.expire)
	driver.free()
	observer.free()
	return completed


func _combat(tree: SceneTree, packed: PackedScene, check: Callable) -> bool:
	var cases: Dictionary = {}
	var actors: Array[Node] = []
	for key: String in ["hit", "behind", "far", "wall", "protection", "entry", "exit",
		"disabled", "dormant", "invalid", "interrupt", "pause", "dead_player", "removed", "chase", "solid", "two"]:
		var case := _case(tree, packed, Vector2(150, 0) if key in ["chase", "solid", "dormant"] else Vector2(45, 0), key != "dormant")
		cases[key] = case
		actors.append(case.enemy)
		if key == "solid" or key == "wall":
			_wall(case.world)
		if key == "dead_player":
			case.player.receive_hit(100)
		if key == "removed":
			case.world.remove_child(case.player)
		if key == "two":
			var second = packed.instantiate()
			second.set_physics_process(false)
			case.world.add_child(second)
			second.set_target(case.player)
			second.set_encounter_enabled(true)
			case.second = second
			actors.append(second)
	var first = cases.hit.enemy
	check.call(first.process_physics_priority > cases.hit.player.process_physics_priority,
		"S3: jogador resolve antes do perseguidor")
	check.call(first.collision_layer == 4 and first.collision_mask == 3,
		"S3: receptor camada4 colide somente com cenário/jogador")
	check.call(first.health != cases.behind.enemy.health and first.health.current == 30,
		"S3: vida30 independente por instância")
	cases.disabled.enemy.set_encounter_enabled(false)
	check.call(not cases.invalid.enemy.set_target(null), "S3: alvo inválido retorna false e limpa anterior")
	check.call(not cases.invalid.enemy.receive_hit(10) and cases.invalid.enemy.health.current == 30,
		"S3: habilitação sem alvo válido mantém combate desabilitado")
	var disabled_origin: Vector2 = cases.disabled.enemy.position
	var removed_player: Node = cases.removed.player
	var protection_serial := [0]
	var phase_before_pause := [0]
	var result := await _run_ticks(tree, actors, 100, func(tick: int) -> bool:
		if tick == 2:
			cases.behind.player.position = Vector2(-45, 0)
			cases.far.player.position = Vector2(100, 0)
			cases.entry.player.position = Vector2(100, 0)
		if tick == 20:
			cases.interrupt.enemy.interrupt_actions()
		if tick == 30:
			phase_before_pause[0] = cases.pause.enemy.action_state.phase
			tree.paused = true
		if tick == 34:
			check.call(cases.pause.enemy.action_state.phase == phase_before_pause[0]
				and cases.hit.player.health.current == 100, "S3: pausa congela relógio e dano")
			tree.paused = false
		if tick == 40:
			# Ataque terá avançado36ticks após quatro callbacks pausados.
			cases.protection.player.action_state.try_dodge(Vector2.UP)
			protection_serial[0] = cases.protection.enemy.action_state.attack_serial
		if tick == 41:
			cases.entry.player.position = Vector2(45, 0)
			cases.exit.player.position = Vector2(100, 0)
		if tick == 42:
			cases.protection.player.action_state.interrupt()
		return true,
		func(tick: int) -> bool:
			if tick == 39:
				check.call(cases.hit.player.health.current == 100, "S3: preparação não causa dano")
			if tick == 41:
				check.call(cases.hit.player.health.current == 90, "S3: acerto real100 para90")
				check.call(cases.entry.player.health.current == 90 and cases.exit.player.health.current == 100,
					"S3: entrada/saída no mesmo callback usam shapes/transforms atuais")
			if tick == 47:
				check.call(cases.protection.player.health.current == 100
					and cases.protection.enemy.action_state.attack_serial == protection_serial[0],
					"S3: recusa por proteção consome serial até fim da janela")
			if tick == 58:
				check.call(cases.interrupt.player.health.current == 100, "S3: interrupção exige nova preparação0,60")
			if tick == 60:
				check.call(cases.interrupt.player.health.current == 90, "S3: após nova preparação permite acerto")
			return true)
	tree.paused = false
	check.call(result, "S3:100ticks físicos limitados concluídos")
	check.call(cases.hit.player.health.current == 90, "S3: múltiplos ticks/recuperação não duplicam")
	for key: String in ["behind", "far", "wall", "disabled", "dormant", "invalid", "exit"]:
		check.call(cases[key].player.health.current == 100, "S3: sem dano em " + key)
	check.call(cases.disabled.enemy.position == disabled_origin, "S3: desabilitado não move")
	check.call(cases.dormant.enemy.position == Vector2.ZERO, "S3: alvo válido sem habilitação explícita não move")
	check.call(cases.dead_player.player.health.current == 0 and removed_player.health.current == 100,
		"S3: morto/removido não recebem dano")
	check.call(cases.chase.enemy.position.x > 80.0 and cases.chase.enemy.position.x <= 92.1,
		"S3: perseguição120/s para ao entrar em60")
	check.call(cases.solid.enemy.position.x < 11.0, "S3: perseguidor não atravessa parede")
	check.call(cases.two.player.health.current == 80, "S3: inimigos distintos acumulam dano sem iframe novo")
	for key: String in cases:
		cases[key].world.free()
	removed_player.free()
	return result


func _moving_sample(tree: SceneTree, packed: PackedScene, check: Callable) -> bool:
	var entry := _case(tree, packed)
	var exit := _case(tree, packed)
	var result := await _run_ticks(tree, [entry.player, entry.enemy, exit.player, exit.enemy], 43,
		func(tick: int) -> bool:
			if tick == 37:
				entry.player.position = Vector2(71, 0)
				entry.player.apply_intent(Vector2.LEFT, Vector2.RIGHT)
				exit.player.position = Vector2(67, 0)
				exit.player.apply_intent(Vector2.RIGHT, Vector2.RIGHT)
			if tick == 38:
				entry.player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
				exit.player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
			return true,
		func(tick: int) -> bool:
			if tick == 37:
				check.call(entry.player.position.distance_to(Vector2(67, 0)) < 0.001
					and exit.player.position.distance_to(Vector2(71, 0)) < 0.001,
					"S3: movimento nativo240/s conclui quatro unidades antes da consulta")
				check.call(entry.player.health.current == 90 and exit.player.health.current == 100,
					"S3: movimento real entra/sai do alcance sem broadphase antiga")
			return true)
	check.call(entry.player.health.current == 90 and exit.player.health.current == 100,
		"S3: ticks seguintes não duplicam nem acertam quem saiu")
	entry.world.free()
	exit.world.free()
	return result


func _coarse_step(tree: SceneTree, packed: PackedScene, check: Callable) -> bool:
	var case := _case(tree, packed)
	var original_rate := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 2
	var result := await _run_ticks(tree, [case.enemy], 3, Callable(),
		func(tick: int) -> bool:
			check.call(case.player.health.current == (100 if tick == 1 else 90),
				"S3: passo físico0,50 atravessa ativo e tenta somente uma vez: " + str(tick))
			return true)
	Engine.physics_ticks_per_second = original_rate
	check.call(case.enemy.action_state.attack_serial == 1, "S3: passo grande não compensa ataques em rajada")
	case.world.free()
	return result


func _baton_and_callbacks(tree: SceneTree, packed: PackedScene, check: Callable) -> bool:
	var baton := _case(tree, packed, Vector2(-45, 0))
	baton.player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	var actors: Array[Node] = [baton.player, baton.enemy]
	var worlds: Array[Node] = [baton.world]
	var deaths := [0]
	baton.enemy.died.connect(func() -> void: deaths[0] += 1)
	var callbacks: Dictionary = {}
	for effect: String in ["kill", "disable", "remove", "queue_free"]:
		var case := _case(tree, packed)
		worlds.append(case.world)
		actors.append(case.enemy)
		callbacks[effect] = case
		case.callback_count = 0
		case.death_count = 0
		case.actor_ref = weakref(case.enemy)
		case.enemy.died.connect(func() -> void: case.death_count += 1)
		var id: int = case.enemy.get_instance_id()
		case.player.health.changed.connect(func(_current: int, _maximum: int) -> void:
			case.callback_count += 1
			var enemy: Variant = instance_from_id(id)
			if not is_instance_valid(enemy):
				return
			if effect == "kill":
				enemy.receive_hit(30)
			elif effect == "disable":
				enemy.set_encounter_enabled(false)
			elif effect == "remove":
				enemy.get_parent().remove_child(enemy)
			else:
				enemy.queue_free())
	var initial := _case(tree, packed)
	worlds.append(initial.world)
	initial.enemy.set_target(null)
	initial.enemy.set_encounter_enabled(false)
	check.call(not initial.enemy.receive_hit(0) and not initial.enemy.receive_hit(-1)
		and not initial.enemy.receive_hit(1001), "S3: dano inválido recusado")
	var result := await _run_ticks(tree, actors, 80, func(tick: int) -> bool:
		if tick in [1, 20, 39]:
			baton.player.queue_actions(true, false)
		if tick == 30:
			baton.enemy.interrupt_actions()
		return true,
		func(tick: int) -> bool:
			if tick == 6:
				check.call(baton.enemy.health.current == 20
					and baton.enemy.action_state.phase == baton.enemy.action_state.WINDUP,
					"S3: cassetete real10 não interrompe preparação")
			return true)
	check.call(baton.enemy.health.dead and deaths[0] == 1 and baton.enemy.collision_layer == 0,
		"S3: três golpes10 matam30 uma vez e removem colisão")
	check.call(baton.player.health.current == 100 and not baton.enemy.receive_hit(10),
		"S3: morte anterior à resolução cancela dano e novos golpes")
	for effect: String in callbacks:
		var case: Dictionary = callbacks[effect]
		check.call(case.player.health.current == 90,
			"S3: callback " + effect + " não duplica nem continua ataque")
		check.call(case.callback_count == 1, "S3: callback executado uma vez: " + effect)
		# O orçamento já aguardou um process_frame após os callbacks físicos.
		# WeakRef evita ler qualquer propriedade do objeto excluído por queue_free.
		var actor: Variant = case.actor_ref.get_ref()
		var observed := false
		if effect == "queue_free":
			observed = not is_instance_valid(actor) and case.death_count == 0
		elif is_instance_valid(actor):
			if effect == "kill":
				observed = actor.health.dead and actor.health.current == 0 and case.death_count == 1 \
					and actor.collision_layer == 0 and actor.collision_mask == 0
			elif effect == "disable":
				observed = actor.is_inside_tree() and not actor.health.dead and case.death_count == 0 \
					and actor.health.current == 30 and actor.action_state.phase == actor.action_state.CHASE \
					and not actor.active_snapshot and actor.velocity == Vector2.ZERO and not actor.receive_hit(1)
			elif effect == "remove":
				observed = not actor.is_inside_tree() and actor.get_parent() == null and case.death_count == 0
		check.call(observed, "S3: efeito reentrante observado: " + effect)
	var removed: Variant = callbacks.remove.actor_ref.get_ref()
	if is_instance_valid(removed) and not removed.is_inside_tree():
		removed.free()
	for world: Node in worlds:
		world.free()
	return result

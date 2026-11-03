extends RefCounted
## Contatos nativos em mundos isolados; expectativas espaciais independentes do resolver.

const HIT_PATH := "res://src/combat/melee_hit.gd"
const TARGET_PATH := "res://src/arenas/training_target.tscn"


class Receiver extends StaticBody2D:
	var attempts: int = 0
	var total_damage: int = 0
	var accepts: bool = true
	var on_hit: Callable

	func still_active() -> bool:
		return true

	func receive_hit(amount: int) -> bool:
		attempts += 1
		if on_hit.is_valid():
			on_hit.call()
		if accepts:
			total_damage += amount
		return accepts


class Actor extends Node2D:
	var active: bool = true

	func still_active() -> bool:
		return active


class Guard extends Node:
	var calls: int = 0
	var trigger_at: int = 1
	var effect: Callable

	func still_active() -> bool:
		calls += 1
		if calls == trigger_at and effect.is_valid():
			effect.call()
		return true


class PhysicsBudget extends Node:
	signal finished
	var target_ticks: int = 0
	var completed_ticks: int = 0
	var job: Callable
	var expired: bool = false
	var jobs_completed: bool = true

	func _physics_process(_delta: float) -> void:
		completed_ticks += 1
		if job.is_valid():
			var result: Variant = job.call()
			jobs_completed = jobs_completed and result == true
		if completed_ticks == target_ticks:
			set_physics_process(false)
			finished.emit()

	func expire() -> void:
		expired = true
		set_physics_process(false)
		finished.emit()


func run(tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(HIT_PATH), "S2: resolver físico deve existir")
	check.call(ResourceLoader.exists(TARGET_PATH), "S2: alvo real deve existir")
	if not ResourceLoader.exists(HIT_PATH) or not ResourceLoader.exists(TARGET_PATH):
		return false
	var script := load(HIT_PATH) as GDScript
	var packed := load(TARGET_PATH) as PackedScene
	if script == null or not script.can_instantiate() or packed == null:
		return false
	check.call(await _geometry(tree, script, check) == true, "subteste espacial deve concluir")
	check.call(await _dedup_and_walls(tree, script, check) == true, "subteste de identidade e parede deve concluir")
	check.call(await _query_filters(tree, script, check) == true, "subteste de filtros e paginação deve concluir")
	check.call(await _invalid_and_lifecycle(tree, script, check) == true, "subteste de ciclo de vida deve concluir")
	check.call(await _reentrant(tree, script, check) == true, "subteste reentrante deve concluir")
	check.call(await _guard_mutation(tree, script, check) == true, "subteste de mutação no guard deve concluir")
	check.call(await _real_target(tree, script, packed, check) == true, "subteste do alvo real deve concluir")
	check.call(await _death_callbacks(tree, script, packed, check) == true, "subteste de callbacks de morte deve concluir")
	return true


func _world(tree: SceneTree) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	tree.root.add_child(viewport)
	return viewport


func _actor(world: Node) -> Actor:
	var actor := Actor.new()
	world.add_child(actor)
	return actor


func _shape(body: CollisionObject2D, radius: float = 2.0, offset := Vector2.ZERO) -> void:
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	collider.shape = circle
	collider.position = offset
	body.add_child(collider)


func _receiver(world: Node, position: Vector2, radius: float = 2.0) -> Receiver:
	var receiver := Receiver.new()
	receiver.position = position
	receiver.collision_layer = 4
	receiver.collision_mask = 2
	_shape(receiver, radius)
	world.add_child(receiver)
	return receiver


func _ticks(tree: SceneTree, count: int, job: Callable = Callable()) -> bool:
	if count < 1 or count > 8:
		return false
	var budget := PhysicsBudget.new()
	budget.target_ticks = count
	budget.job = job
	budget.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(budget)
	var watchdog := tree.create_timer(2.0, true, false, true)
	watchdog.timeout.connect(budget.expire)
	await budget.finished
	# Nenhum participante nativo continua consultando após o orçamento, mesmo no mesmo frame.
	await tree.process_frame
	var completed := not budget.expired and budget.completed_ticks == count and budget.jobs_completed
	watchdog.timeout.disconnect(budget.expire)
	budget.free()
	return completed


func _geometry(tree: SceneTree, script: GDScript, check: Callable) -> bool:
	# Centro além do arco/lateral, mas círculo sobreposto, deve receber; centro sozinho não basta.
	for case: Array in [
		[Vector2.RIGHT, Vector2(35, 0), 2.0, 1, "cardinal"],
		[Vector2.ONE, Vector2(28, 28), 2.0, 1, "diagonal"],
		[Vector2.UP, Vector2(0, -35), 2.0, 1, "norte"],
		[Vector2.LEFT, Vector2(-35, 0), 2.0, 1, "oeste"],
		[Vector2.DOWN, Vector2(0, 35), 2.0, 1, "sul"],
		[Vector2.RIGHT, Vector2(62, 0), 4.0, 1, "base cruza alcance"],
		[Vector2.RIGHT, Vector2(30, 33), 4.0, 1, "base cruza lateral"],
		[Vector2.RIGHT, Vector2(30, 30), 2.0, 1, "borda 45 graus"],
		[Vector2.RIGHT, Vector2(64, 0), 2.0, 0, "fora do alcance"],
		[Vector2.RIGHT, Vector2(30, 36), 2.0, 0, "fora da lateral"],
		[Vector2.RIGHT, Vector2(-20, 0), 2.0, 0, "atrás"]]:
		var world := _world(tree)
		var actor := _actor(world)
		var target := _receiver(world, case[1], case[2])
		var hit = script.new()
		var accepted := [0]
		check.call(await _ticks(tree, 3) == true, "registro físico: " + case[4])
		check.call(await _ticks(tree, 1, func() -> bool:
			accepted[0] = hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, case[0], 1, actor.still_active)
			return true
		) == true, "query física: " + case[4])
		check.call(accepted[0] == case[3] and target.total_damage == case[3] * 10,
			"contato por shape real: " + case[4])
		world.free()
	var hit = script.new()
	var points: PackedVector2Array = hit.sector_points(Vector2.RIGHT)
	check.call(points.size() == 6, "desenho recebe origem e cinco pontos do arco")
	if points.size() == 6:
		check.call(points[0] == Vector2.ZERO and points[3].distance_to(Vector2(60, 0)) < 0.001,
			"desenho inclui origem e ponta 60")
		check.call(points[1].distance_to(Vector2(42.426407, -42.426407)) < 0.001
			and points[5].distance_to(Vector2(42.426407, 42.426407)) < 0.001, "desenho limita abertura a 90 graus")
		check.call(points[2].distance_to(Vector2(55.432772, -22.961006)) < 0.001
			and points[4].distance_to(Vector2(55.432772, 22.961006)) < 0.001, "pontos intermediários do desenho permanecem no arco")
	return true


func _dedup_and_walls(tree: SceneTree, script: GDScript, check: Callable) -> bool:
	var world := _world(tree)
	var actor := _actor(world)
	var first := _receiver(world, Vector2(35, -8))
	_shape(first, 3.0, Vector2(1, 1))
	var second := _receiver(world, Vector2(35, 8))
	var hit = script.new()
	var accepted := [0]
	check.call(await _ticks(tree, 3) == true, "registrar duas bases e múltiplas shapes")
	var job := func() -> bool:
		accepted[0] += hit.resolve(world.world_2d.direct_space_state, actor, actor.global_position, Vector2.RIGHT, 1, actor.still_active)
		return true
	check.call(await _ticks(tree, 3, job) == true, "três ticks nativos do mesmo golpe")
	check.call(accepted[0] == 2 and first.attempts == 1 and second.attempts == 1,
		"duas shapes e ticks não duplicam; dois receptores recebem uma vez")
	check.call(await _ticks(tree, 1, func() -> bool:
		accepted[0] = hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 2, actor.still_active)
		return true
	) == true, "novo serial nativo")
	check.call(accepted[0] == 2 and first.total_damage == 20 and second.total_damage == 20, "novo serial acerta novamente")
	check.call(await _ticks(tree, 1, func() -> bool:
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, actor.still_active) == 0,
			"serial antigo não revive golpe após serial novo")
		return true
	) == true, "serial obsoleto nativo")
	world.free()
	world = _world(tree)
	actor = _actor(world)
	first = _receiver(world, Vector2(40, 0))
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 2
	wall.position = Vector2(20, 0)
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 80)
	collider.shape = rectangle
	wall.add_child(collider)
	world.add_child(wall)
	hit = script.new()
	accepted[0] = 0
	check.call(await _ticks(tree, 3) == true, "parede registrada")
	check.call(await _ticks(tree, 1, func() -> bool:
		accepted[0] = hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, actor.still_active)
		return true
	) == true, "query contra parede")
	check.call(accepted[0] == 0 and first.attempts == 0, "cenário entre pés bloqueia dano")
	wall.position.y = 200
	check.call(await _ticks(tree, 3) == true, "parede movida no servidor")
	check.call(await _ticks(tree, 1, func() -> bool:
		accepted[0] = hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, actor.still_active)
		return true
	) == true, "mesmo serial com linha livre")
	check.call(accepted[0] == 1 and first.attempts == 1, "parede não consome tentativa futura visível")
	world.free()
	return true


func _invalid_and_lifecycle(tree: SceneTree, script: GDScript, check: Callable) -> bool:
	var world := _world(tree)
	var actor := _actor(world)
	var target := _receiver(world, Vector2(35, 0))
	var hit = script.new()
	check.call(await _ticks(tree, 3) == true, "registrar negativos")
	check.call(await _ticks(tree, 1, func() -> bool:
		for direction: Vector2 in [Vector2.ZERO, Vector2(NAN, 0), Vector2(0, INF)]:
			check.call(hit.sector_points(direction).is_empty(), "direção inválida não produz geometria")
			check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, direction, 1, actor.still_active) == 0,
				"direção inválida não consulta/aplica")
		for origin: Vector2 in [Vector2(NAN, 0), Vector2(INF, 0), Vector2(1e30, 0), Vector2(-1e30, 0)]:
			check.call(hit.resolve(world.world_2d.direct_space_state, actor, origin, Vector2.RIGHT, 1, actor.still_active) == 0,
				"origem não finita ou extrema não consulta/aplica")
		for serial: int in [-1, 0]:
			check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, serial, actor.still_active) == 0,
				"serial não positivo é inválido")
		check.call(hit.resolve(null, actor, Vector2.ZERO, Vector2.RIGHT, 1, actor.still_active) == 0, "espaço nulo")
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, Callable()) == 0, "Callable inválido")
		actor.active = false
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, actor.still_active) == 0, "golpe interrompido")
		actor.active = true
		return true
	) == true, "negativos no tick nativo")
	check.call(target.attempts == 0, "entradas inválidas não chegam ao receptor")
	# Direção finita extrema é normalizada sem overflow e sem alterar alcance.
	check.call(await _ticks(tree, 1, func() -> bool:
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2(1e30, 0), 1, actor.still_active) == 1,
			"direção extrema finita mantém contato seguro")
		return true
	) == true, "normalização robusta nativa")
	world.remove_child(target)
	check.call(await _ticks(tree, 1, func() -> bool:
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 2, actor.still_active) == 0, "alvo fora da árvore")
		return true
	) == true, "remoção antes do contato")
	target.free()
	target = _receiver(world, Vector2(35, 0))
	check.call(await _ticks(tree, 3) == true, "registrar alvo com exclusão pendente")
	check.call(await _ticks(tree, 1, func() -> bool:
		target.queue_free()
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 3, actor.still_active) == 0, "alvo em queue_free")
		return true
	) == true, "queue_free antes da query")
	world.remove_child(actor)
	check.call(await _ticks(tree, 1, func() -> bool:
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 4, actor.still_active) == 0, "atacante fora da árvore")
		return true
	) == true, "atacante removido")
	actor.free()
	world.free()
	return true


func _query_filters(tree: SceneTree, script: GDScript, check: Callable) -> bool:
	var world := _world(tree)
	var actor := _actor(world)
	actor.position = Vector2(200, -100)
	var first := _receiver(world, Vector2(235, -100))
	for index: int in range(80):
		_shape(first, 2.0, Vector2(0, (index % 3) - 1))
	var second := _receiver(world, Vector2(240, -90))
	var crowd: Array[Receiver] = []
	for index: int in range(70):
		crowd.append(_receiver(world, Vector2(235, -106 + (index % 13))))
	var wrong_layer := _receiver(world, Vector2(230, -100))
	wrong_layer.collision_layer = 2
	var area := Area2D.new()
	area.collision_layer = 4
	area.position = Vector2(230, -100)
	_shape(area)
	world.add_child(area)
	var hit = script.new()
	check.call(await _ticks(tree, 3) == true, "registrar muitas shapes, corpo de jogador e área")
	check.call(await _ticks(tree, 1, func() -> bool:
		check.call(hit.resolve(world.world_2d.direct_space_state, actor, actor.global_position, Vector2.RIGHT, 1, actor.still_active) == 72,
			"paginação alcança 72 receptores mesmo com mais de 64 corpos e shapes")
		return true
	) == true, "query transladada e filtrada")
	check.call(first.attempts == 1 and second.attempts == 1 and wrong_layer.attempts == 0,
		"filtro de hit separado da máscara corporal, origem global transladada")
	for receiver: Receiver in crowd:
		check.call(receiver.attempts == 1 and receiver.total_damage == 10, "cada corpo paginado recebe exatamente um dano")
	var replacement := _actor(world)
	replacement.position = actor.position
	check.call(await _ticks(tree, 1, func() -> bool:
		check.call(hit.resolve(world.world_2d.direct_space_state, replacement, replacement.global_position, Vector2.RIGHT, 1, replacement.still_active) == 72,
			"outro instance_id com mesmo serial não herda IDs visitados")
		return true
	) == true, "troca de atacante com identidade explícita")
	world.free()
	world = _world(tree)
	var self_receiver := _receiver(world, Vector2.ZERO, 10.0)
	var victim := _receiver(world, Vector2(35, 0))
	check.call(await _ticks(tree, 3) == true, "registrar atacante que também oferece receive_hit")
	check.call(await _ticks(tree, 1, func() -> bool:
		check.call(hit.resolve(world.world_2d.direct_space_state, self_receiver, Vector2.ZERO, Vector2.RIGHT, 1, self_receiver.still_active) == 1,
			"resolver exclui RID do atacante também receptor")
		return true
	) == true, "query sem autoacerto")
	check.call(self_receiver.attempts == 0 and victim.total_damage == 10, "golpe não acerta próprio atacante")
	world.free()
	return true


func _reentrant(tree: SceneTree, script: GDScript, check: Callable) -> bool:
	for mode: String in ["iframe", "interrupt", "remove_attacker", "queue_attacker", "free_attacker", "remove_target", "queue_target", "free_target", "invalid_callable", "nested_same", "nested_new"]:
		var world := _world(tree)
		var actor := _actor(world)
		var first := _receiver(world, Vector2(35, -8))
		var second := _receiver(world, Vector2(35, 8))
		var hit = script.new()
		var guard_owner := Actor.new()
		world.add_child(guard_owner)
		var guard: Callable = guard_owner.still_active
		var accepted := [0]
		var nested := [0]
		if mode == "iframe":
			first.accepts = false
		else:
			first.on_hit = func() -> void:
				match mode:
					"interrupt": guard_owner.active = false
					"remove_attacker": world.remove_child(actor)
					"queue_attacker": actor.queue_free()
					"free_attacker": actor.free()
					"remove_target": world.remove_child(second)
					"queue_target": second.queue_free()
					"free_target": second.free()
					"invalid_callable": guard_owner.free()
					"nested_same", "nested_new":
						first.on_hit = Callable()
						nested[0] = hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT,
							1 if mode == "nested_same" else 2, guard)
		check.call(await _ticks(tree, 3) == true, "registrar reentrância: " + mode)
		check.call(await _ticks(tree, 1, func() -> bool:
			accepted[0] = hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, guard)
			return true
		) == true, "query reentrante: " + mode)
		if mode == "iframe":
			first.accepts = true
			check.call(await _ticks(tree, 2, func() -> bool:
				hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, guard)
				return true
			) == true, "repetir golpe após iframe")
			check.call(accepted[0] == 1 and first.attempts == 1 and first.total_damage == 0 and second.total_damage == 10,
				"rejeição por iframe consome tentativa sem consumir outro alvo")
		elif mode == "nested_same":
			check.call(accepted[0] == 1 and nested[0] == 1 and first.attempts == 1 and second.attempts == 1,
				"registrar ID antes do callback impede duplicação reentrante")
		elif mode == "nested_new":
			check.call(accepted[0] == 1 and nested[0] == 2 and first.attempts == 2 and second.attempts == 1,
				"novo serial reentrante interrompe aplicação do serial antigo")
		else:
			check.call(accepted[0] == 1 and first.total_damage == 10, "primeiro dano aceito antes da interrupção: " + mode)
			if is_instance_valid(second):
				check.call(second.attempts == 0, "não aplicar no segundo alvo invalidado/interrompido: " + mode)
		if is_instance_valid(actor) and not actor.is_inside_tree():
			actor.free()
		if is_instance_valid(second) and not second.is_inside_tree():
			second.free()
		world.free()
	return true


func _real_target(tree: SceneTree, script: GDScript, packed: PackedScene, check: Callable) -> bool:
	var world := _world(tree)
	var actor := _actor(world)
	var target = packed.instantiate()
	target.position = Vector2(40, 0)
	world.add_child(target)
	var other = packed.instantiate()
	other.position = Vector2(200, 0)
	world.add_child(other)
	var deaths := [0]
	target.died.connect(func() -> void: deaths[0] += 1)
	check.call(target is StaticBody2D and target.collision_layer == 4 and target.collision_mask == 2,
		"alvo real usa base física layer 4 e máscara corporal 2")
	check.call(target.health is RefCounted and target.health.maximum == 30 and target.health != other.health,
		"vida 30 isolada e exposta para leitura")
	check.call(await _ticks(tree, 3) == true, "registrar alvo real")
	var hit = script.new()
	for serial: int in [1, 2, 3]:
		check.call(await _ticks(tree, 1, func() -> bool:
			check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, serial, actor.still_active) == 1,
				"alvo real aceita dano 10 no serial %d" % serial)
			return true
		) == true, "tick com alvo real")
		check.call(target.health.current == 30 - serial * 10, "vida observável após golpe real")
	check.call(target.health.dead and deaths[0] == 1 and not target.receive_hit(10), "morte local única e dano recusado após morte")
	check.call(other.health.current == 30, "instância fora do alcance não perde vida")
	var was_paused := tree.paused
	tree.paused = true
	check.call(not other.receive_hit(10) and other.health.current == 30, "alvo pausado recusa chamada direta de dano")
	check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 4, actor.still_active) == 0,
		"resolver recusa golpe pausado mesmo por chamada direta")
	tree.paused = was_paused
	for amount: int in [-1, 0, 1001]:
		check.call(not other.receive_hit(amount) and other.health.current == 30, "alvo rejeita dano inválido")
	# Remover a subárvore invalida o ator já no mesmo callback, antes de o servidor liberar o corpo.
	var pending_parent := Node2D.new()
	world.add_child(pending_parent)
	var pending = packed.instantiate()
	pending_parent.add_child(pending)
	pending_parent.queue_free()
	check.call(not pending.receive_hit(10) and pending.health.current == 30,
		"alvo sob ancestral em queue_free não aceita dano direto")
	world.free()
	await tree.process_frame
	return true


func _guard_mutation(tree: SceneTree, script: GDScript, check: Callable) -> bool:
	for mode: String in ["remove_entry", "free_before_apply", "remove_target"]:
		var world := _world(tree)
		var actor := _actor(world)
		var target := _receiver(world, Vector2(35, 0))
		var guard := Guard.new()
		guard.trigger_at = 1 if mode == "remove_entry" else 2
		world.add_child(guard)
		guard.effect = func() -> void:
			if mode == "remove_entry":
				world.remove_child(actor)
			elif mode == "free_before_apply":
				actor.free()
			else:
				world.remove_child(target)
		var hit = script.new()
		check.call(await _ticks(tree, 3) == true, "registrar guard com efeito: " + mode)
		check.call(await _ticks(tree, 1, func() -> bool:
			check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, guard.still_active) == 0,
				"revalidar depois do Callable que retorna true: " + mode)
			return true
		) == true, "mutação síncrona do guard: " + mode)
		check.call(target.attempts == 0, "guard não deixa referência inválida chegar ao receptor: " + mode)
		if is_instance_valid(actor) and not actor.is_inside_tree():
			actor.free()
		if not target.is_inside_tree():
			target.free()
		world.free()
	return true


func _death_callbacks(tree: SceneTree, script: GDScript, packed: PackedScene, check: Callable) -> bool:
	for mode: String in ["remove_attacker", "remove_self", "queue_self"]:
		var world := _world(tree)
		var actor := _actor(world)
		var first = packed.instantiate()
		first.position = Vector2(35, -8)
		world.add_child(first)
		var second = packed.instantiate()
		second.position = Vector2(35, 8)
		world.add_child(second)
		check.call(first.receive_hit(20), "preparar alvo real a um golpe da morte")
		var deaths := [0]
		first.died.connect(func() -> void:
			deaths[0] += 1
			if mode == "remove_attacker":
				world.remove_child(actor)
			elif mode == "remove_self":
				world.remove_child(first)
			else:
				# Godot trava o objeto durante sua própria emissão: exclusão deve ser adiada.
				first.queue_free()
		)
		var hit = script.new()
		check.call(await _ticks(tree, 3) == true, "registrar morte reentrante real: " + mode)
		check.call(await _ticks(tree, 1, func() -> bool:
			check.call(hit.resolve(world.world_2d.direct_space_state, actor, Vector2.ZERO, Vector2.RIGHT, 1, actor.still_active)
				== (1 if mode == "remove_attacker" else 2), "accepted count em morte real: " + mode)
			return true
		) == true, "callback de morte real no tick")
		check.call(deaths[0] == 1 and second.health.current == (30 if mode == "remove_attacker" else 20),
			"morte real única, remoção segura e restante do golpe correto: " + mode)
		if is_instance_valid(actor) and not actor.is_inside_tree():
			actor.free()
		if is_instance_valid(first) and not first.is_inside_tree():
			first.free()
		world.free()
	return true

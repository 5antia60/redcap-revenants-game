extends RefCounted
## Exercita a cena real em World2D isolado; não chama callbacks físicos manualmente.

const PLAYER_PATH := "res://src/player/player.tscn"
const TOLERANCE := 0.5

var _observed_multiple_ticks: bool = false


class TickBudget extends Node:
	signal finished
	var player: CharacterBody2D
	var target: int
	var completed_ticks: int = 0
	var multiple_ticks_observed: bool = false
	var _previous_frame: int = -1

	func _physics_process(_delta: float) -> void:
		# Prioridade posterior à do corpo: cada observação corresponde a um tick concluído.
		var frame := Engine.get_process_frames()
		multiple_ticks_observed = multiple_ticks_observed or frame == _previous_frame
		_previous_frame = frame
		completed_ticks += 1
		if completed_ticks == target:
			# Impede avanço extra do corpo nos demais ticks do mesmo frame de renderização.
			player.set_physics_process(false)
			set_physics_process(false)
			finished.emit()


func run(tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(PLAYER_PATH), "S1: cena do corpo deve existir")
	if not ResourceLoader.exists(PLAYER_PATH):
		return false
	var packed := load(PLAYER_PATH) as PackedScene
	check.call(packed != null, "cena do jogador deve carregar")
	if packed == null:
		return false
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	tree.root.add_child(viewport)
	var world := Node2D.new()
	viewport.add_child(world)
	var player := packed.instantiate() as CharacterBody2D
	check.call(player != null, "raiz do jogador deve ser CharacterBody2D")
	if player == null:
		viewport.free()
		return false
	world.add_child(player)
	check.call(player.has_method("apply_intent"), "corpo deve consumir intenção explícita")
	if not player.has_method("apply_intent"):
		viewport.free()
		return false
	check.call(await _ticks(tree, player, 3) == true, "registro físico deve concluir três ticks")
	check.call(player.get_world_2d() == viewport.world_2d, "corpo registrado no mundo físico isolado")
	check.call(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "movimento top-down flutuante")
	var collider := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	check.call(collider != null and collider.shape is CircleShape2D, "colisor circular dos pés")
	if collider != null and collider.shape is CircleShape2D:
		check.call(is_equal_approx(collider.shape.radius, 10.0) and collider.position == Vector2.ZERO,
			"raio 10 centrado na origem dos pés")
	check.call(await _test_free_motion(tree, player, check) == true, "subteste de espaço livre deve concluir")
	check.call(await _test_speed_range(tree, packed, check) == true, "subteste de faixa de velocidade deve concluir")
	check.call(await _test_collisions(tree, world, player, check) == true, "subteste de colisões deve concluir")
	player.apply_intent(Vector2.ZERO, Vector2.ZERO)
	viewport.free()
	await tree.process_frame
	print("S1 timing: multiple_ticks_observed=%s" % str(_observed_multiple_ticks))
	return true


func _test_free_motion(tree: SceneTree, player: CharacterBody2D, check: Callable) -> bool:
	var start := player.position
	player.apply_intent(Vector2.RIGHT, Vector2.UP)
	check.call(await _ticks(tree, player, 15) == true, "ticks cardinais devem concluir")
	var cardinal := player.position - start
	var expected := 240.0 * 15.0 / float(Engine.physics_ticks_per_second)
	check.call(absf(cardinal.x - expected) <= TOLERANCE and absf(cardinal.y) <= TOLERANCE,
		"15 ticks livres deslocam a 240 unidades/s sem delta duplicado: %s" % cardinal)
	check.call(player.velocity.is_equal_approx(Vector2(240, 0)), "velocidade física cardinal 240")
	check.call(is_zero_approx(player.rotation), "mira independente não rotaciona corpo")
	var indicator := player.get_node_or_null("AimIndicator") as Node2D
	check.call(indicator != null, "indicador direcional presente")
	if indicator != null:
		check.call(absf(angle_difference(indicator.rotation, -PI / 2.0)) < 0.001,
			"somente indicador aponta para mira")
	start = player.position
	player.apply_intent(Vector2.ONE, Vector2.ZERO)
	check.call(await _ticks(tree, player, 15) == true, "ticks diagonais devem concluir")
	check.call(absf(player.position.distance_to(start) - expected) <= TOLERANCE,
		"diagonal do corpo não excede velocidade cardinal")
	if indicator != null:
		check.call(absf(angle_difference(indicator.rotation, -PI / 2.0)) < 0.001,
			"mira zero preserva orientação do indicador")
	start = player.position
	player.apply_intent(Vector2(0.5, 0), Vector2.DOWN)
	check.call(await _ticks(tree, player, 15) == true, "ticks de intensidade parcial devem concluir")
	check.call(absf(player.position.distance_to(start) - expected * 0.5) <= TOLERANCE,
		"corpo preserva intensidade parcial sem reaplicar deadzone")
	player.speed = 120.0
	start = player.position
	player.apply_intent(Vector2.RIGHT, Vector2.ZERO)
	check.call(await _ticks(tree, player, 15) == true, "ticks de velocidade ajustada devem concluir")
	check.call(absf(player.position.distance_to(start) - expected * 0.5) <= TOLERANCE,
		"velocidade ajustável altera deslocamento físico")
	player.speed = 240.0
	player.apply_intent(Vector2.ZERO, Vector2.ZERO)
	start = player.position
	check.call(await _ticks(tree, player, 4) == true, "ticks de parada devem concluir")
	check.call(player.position.distance_to(start) < 0.001 and player.velocity == Vector2.ZERO,
		"intenção neutra para sem inércia")
	for invalid: Vector2 in [Vector2(NAN, 0), Vector2(0, INF)]:
		player.apply_intent(invalid, invalid)
		check.call(await _ticks(tree, player, 2) == true, "ticks de entrada inválida devem concluir")
		check.call(player.position.is_finite() and player.position.distance_to(start) < 0.001
			and player.velocity == Vector2.ZERO, "corpo rejeita vetores não finitos")
	check.call(is_zero_approx(player.rotation), "colisor e corpo continuam sem rotação")
	return true


func _test_speed_range(tree: SceneTree, packed: PackedScene, check: Callable) -> bool:
	for case: Array in [[-1.0, 0.0], [NAN, 0.0], [INF, 0.0], [1e100, 0.0],
		[1001.0, 0.0], [0.0, 0.0], [1000.0, 1000.0]]:
		var speed: float = case[0]
		var expected_speed: float = case[1]
		for move: Vector2 in [Vector2.RIGHT, Vector2.ZERO]:
			# Instâncias isoladas impedem que uma regressão numérica contamine os demais casos.
			var viewport := SubViewport.new()
			viewport.world_2d = World2D.new()
			tree.root.add_child(viewport)
			var player = packed.instantiate()
			viewport.add_child(player)
			player.speed = speed
			player.apply_intent(move, Vector2.RIGHT)
			check.call(await _ticks(tree, player, 2) == true, "ticks de velocidade-limite devem concluir")
			var expected_position := move * (expected_speed * 2.0 / float(Engine.physics_ticks_per_second))
			check.call(player.position.is_finite() and player.velocity.is_finite(),
				"posição/velocidade finitas: speed=%s, move=%s" % [speed, move])
			check.call(player.velocity.is_equal_approx(move * expected_speed)
				and player.position.distance_to(expected_position) <= TOLERANCE,
				"somente faixa 0..1000 produz movimento: speed=%s, move=%s, velocity=%s" % [speed, move, player.velocity])
			player.apply_intent(Vector2.ZERO, Vector2.ZERO)
			viewport.free()
	return true


func _test_collisions(tree: SceneTree, world: Node2D, player: CharacterBody2D, check: Callable) -> bool:
	# Faces internas x=100 e y=100; centro do círculo deve parar perto de 90.
	check.call(_add_wall(world, Vector2(110, 0), Vector2(20, 400)) == true, "parede vertical deve concluir registro")
	check.call(_add_wall(world, Vector2(0, 110), Vector2(400, 20)) == true, "parede horizontal deve concluir registro")
	player.position = Vector2.ZERO
	player.apply_intent(Vector2.ZERO, Vector2.ZERO)
	check.call(await _ticks(tree, player, 3) == true, "shapes devem completar registro antes do contato")
	player.apply_intent(Vector2.RIGHT, Vector2.RIGHT)
	check.call(await _ticks(tree, player, 40) == true, "ticks até parede devem concluir")
	check.call(absf(player.position.x - 90.0) <= TOLERANCE and absf(player.position.y) <= TOLERANCE,
		"parede bloqueia no raio dos pés sem atravessar: %s" % player.position)
	check.call(player.get_slide_collision_count() > 0, "bloqueio vem de colisão nativa real")
	var start := player.position
	player.apply_intent(Vector2(1, -1), Vector2.LEFT)
	check.call(await _ticks(tree, player, 12) == true, "ticks de deslizamento devem concluir")
	check.call(absf(player.position.x - 90.0) <= TOLERANCE and player.position.y < start.y - 25.0,
		"intenção diagonal desliza pela parede: %s" % player.position)
	player.apply_intent(Vector2.ONE, Vector2.UP)
	check.call(await _ticks(tree, player, 65) == true, "ticks até canto devem concluir")
	check.call(absf(player.position.x - 90.0) <= TOLERANCE
		and absf(player.position.y - 90.0) <= TOLERANCE,
		"duas paredes limitam canto sem penetração: %s" % player.position)
	start = player.position
	player.apply_intent(-Vector2.ONE, Vector2.DOWN)
	check.call(await _ticks(tree, player, 12) == true, "ticks de saída do canto devem concluir")
	check.call(player.position.x < start.x - 25.0 and player.position.y < start.y - 25.0,
		"nova intenção sai do canto sem aprisionamento: %s" % player.position)
	player.apply_intent(Vector2.ZERO, Vector2.ZERO)
	start = player.position
	check.call(await _ticks(tree, player, 4) == true, "ticks de parada após colisão devem concluir")
	check.call(player.position.distance_to(start) < 0.001 and player.velocity == Vector2.ZERO,
		"parada após colisão não conserva deslizamento")
	return true


func _add_wall(world: Node2D, center: Vector2, size: Vector2) -> bool:
	var wall := StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	wall.position = center
	wall.add_child(collider)
	world.add_child(wall)
	return true


func _ticks(tree: SceneTree, player: CharacterBody2D, count: int) -> bool:
	if count <= 0:
		return false
	var budget := TickBudget.new()
	budget.player = player
	budget.target = count
	budget.process_physics_priority = player.process_physics_priority + 1
	tree.root.add_child(budget)
	player.set_physics_process(true)
	await budget.finished
	# O corpo permanece congelado até o chamador observar os resultados e armar novo orçamento.
	await tree.process_frame
	var completed := budget.completed_ticks == count
	_observed_multiple_ticks = _observed_multiple_ticks or budget.multiple_ticks_observed
	budget.free()
	return completed

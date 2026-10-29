extends RefCounted
## Um resolver por atacante. Apenas IDs sobrevivem entre consultas do mesmo golpe.

const REACH := 60.0
const DAMAGE := 10
const TARGET_LAYER := 4
const SCENERY_LAYER := 1
const QUERY_BATCH := 64
# Limite operacional muito além do laboratório, antes de chegar à física float32.
const MAX_COORDINATE := 1000000.0

var _attacker_id: int = 0
var _serial: int = 0
var _generation: int = 0
var _visited: Dictionary = {}


func sector_points(direction: Vector2) -> PackedVector2Array:
	if not direction.is_finite():
		return PackedVector2Array()
	# Dividir primeiro evita overflow em length_squared para direções finitas extremas.
	var scale := maxf(absf(direction.x), absf(direction.y))
	if scale == 0.0:
		return PackedVector2Array()
	var unit := (direction / scale).normalized()
	var points := PackedVector2Array([Vector2.ZERO])
	for index: int in range(5):
		points.append(unit.rotated(-PI / 4.0 + index * PI / 8.0) * REACH)
	return points


func resolve(space: PhysicsDirectSpaceState2D, attacker: Node2D, origin: Vector2,
		direction: Vector2, attack_serial: int, still_active: Callable) -> int:
	if space == null or attack_serial <= 0 or not _safe_position(origin):
		return 0
	var points := sector_points(direction)
	if points.is_empty() or not _eligible(attacker, still_active):
		return 0
	if space != attacker.get_world_2d().direct_space_state:
		return 0
	var attacker_id := attacker.get_instance_id()
	if attacker_id == _attacker_id and attack_serial < _serial:
		return 0
	if attacker_id != _attacker_id or attack_serial != _serial:
		_attacker_id = attacker_id
		_serial = attack_serial
		_generation += 1
		_visited = {}
	var generation := _generation
	var shape := ConvexPolygonShape2D.new()
	# O chamador desenha exatamente estes mesmos vértices locais, sem um segundo arco.
	shape.points = points
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, origin)
	query.collision_mask = TARGET_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclusions: Array[RID] = []
	if attacker is CollisionObject2D:
		exclusions.append(attacker.get_rid())
	var candidates: Dictionary = {}
	# Paginar por RID evita que muitas shapes do mesmo corpo escondam outro receptor.
	while true:
		query.exclude = exclusions
		var contacts := space.intersect_shape(query, QUERY_BATCH)
		if contacts.is_empty():
			break
		var previous_count := exclusions.size()
		for contact: Dictionary in contacts:
			var rid: RID = contact["rid"]
			if not exclusions.has(rid):
				exclusions.append(rid)
			candidates[int(contact["collider_id"])] = true
		if exclusions.size() == previous_count:
			break
	# Ordem estável não depende da ordem interna das shapes no servidor físico.
	var ids := candidates.keys()
	ids.sort()
	var accepted := 0
	for target_id: int in ids:
		if not _eligible(attacker, still_active) or generation != _generation:
			break
		if space != attacker.get_world_2d().direct_space_state:
			break
		if target_id == attacker_id or _visited.has(target_id):
			continue
		var target: Variant = instance_from_id(target_id)
		if not _live(target) or not target.has_method("receive_hit"):
			continue
		if target.get_world_2d() != attacker.get_world_2d() or not _safe_position(target.global_position):
			continue
		var ray := PhysicsRayQueryParameters2D.create(attacker.global_position,
			target.global_position, SCENERY_LAYER)
		ray.hit_from_inside = true
		var ray_exclusions: Array[RID] = []
		if attacker is CollisionObject2D:
			ray_exclusions.append(attacker.get_rid())
		if target is CollisionObject2D:
			ray_exclusions.append(target.get_rid())
		ray.exclude = ray_exclusions
		if not space.intersect_ray(ray).is_empty():
			continue
		# Nenhum callback entre validação e aplicação. Registrar antes do receptor:
		# iframe e chamadas aninhadas também consomem a tentativa deste serial.
		_visited[target_id] = true
		if target.receive_hit(DAMAGE) == true:
			accepted += 1
	return accepted


func _safe_position(value: Vector2) -> bool:
	return value.is_finite() and absf(value.x) <= MAX_COORDINATE and absf(value.y) <= MAX_COORDINATE


func _live(node: Variant) -> bool:
	if not is_instance_valid(node) or not node is Node2D or not node.is_inside_tree():
		return false
	var ancestor: Node = node
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return true


func _eligible(attacker: Variant, still_active: Callable) -> bool:
	if not _live(attacker) or not still_active.is_valid():
		return false
	if attacker.get_tree().paused or not attacker.can_process() or not _safe_position(attacker.global_position):
		return false
	if still_active.call() != true:
		return false
	# O guard é código local, mas pode causar morte/remoção/reinício síncronos.
	return _live(attacker) and still_active.is_valid() and not attacker.get_tree().paused \
		and attacker.can_process() and _safe_position(attacker.global_position)

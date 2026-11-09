extends CharacterBody2D
## Perseguidor blockout: pés físicos, postura retraída no aviso, braços estendidos
## e setor hachurado no ativo, braços baixos e duas barras na recuperação.
## Paleta areia/verde ressecado/sombra azulada da ART_BIBLE; sem arte final.

const State := preload("res://src/enemies/melee_chaser_state.gd")
const Health := preload("res://src/combat/health.gd")
const Sector := preload("res://src/combat/melee_hit.gd")
const SPEED := 120.0
const DAMAGE := 10
const MAX_COORDINATE := 1000000.0

signal died()

var health := Health.new(30)
var action_state := State.new()
var active_snapshot: bool = false
var _enabled: bool = false
var _target: WeakRef
var _attempt_serial: int = 0
var _attempted: Dictionary = {}
var _death_emitted: bool = false
var _sector := Sector.new()


func _init() -> void:
	health.changed.connect(_on_health_changed)
	health.died.connect(_on_died)


func _ready() -> void:
	process_physics_priority = 10
	# Nenhum ator vira plataforma que transporta o jogador ao encostar.
	platform_floor_layers = 0
	platform_wall_layers = 0


func set_target(value: CharacterBody2D) -> bool:
	interrupt_actions()
	_target = null
	if not _valid_target(value):
		return false
	_target = weakref(value)
	return true


func set_encounter_enabled(value: bool) -> void:
	if _enabled != value or not value:
		interrupt_actions()
	_enabled = value and not health.dead
	queue_redraw()


func interrupt_actions() -> void:
	action_state.interrupt()
	active_snapshot = false
	velocity = Vector2.ZERO
	queue_redraw()


func receive_hit(amount: int) -> bool:
	var target: Variant = _target.get_ref() if _target != null else null
	if not _eligible() or not _valid_target(target) or amount < 1 or amount > 1000:
		return false
	# Health publica callbacks síncronos que podem remover/desabilitar este corpo.
	# Não acessar self depois da aplicação, nem fabricar reação após encerramento.
	return health.apply_damage(amount)


func _on_health_changed(_current: int, _maximum: int) -> void:
	if health.dead:
		_disable_corpse()
	queue_redraw()


func _disable_corpse() -> void:
	_enabled = false
	active_snapshot = false
	velocity = Vector2.ZERO
	action_state.mark_dead()
	collision_layer = 0
	collision_mask = 0


func _on_died() -> void:
	if _death_emitted:
		return
	_death_emitted = true
	_disable_corpse()
	queue_redraw()
	died.emit()


func _exit_tree() -> void:
	_enabled = false
	interrupt_actions()
	_target = null


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
	return _safe_position(node.global_position)


func _valid_target(value: Variant) -> bool:
	if not _live(value) or value == self or not value is CharacterBody2D \
			or not value.has_method("receive_hit") or not _live(self):
		return false
	var target_health: Variant = value.get("health")
	return target_health is Health and not target_health.dead and (value.collision_layer & 2) != 0 \
		and value.get_world_2d() == get_world_2d()


func _eligible() -> bool:
	return _enabled and not health.dead and _live(self) and can_process() and not get_tree().paused


func _physics_process(delta: float) -> void:
	active_snapshot = false
	velocity = Vector2.ZERO
	if not _eligible():
		return
	var target: Variant = _target.get_ref() if _target != null else null
	if not _valid_target(target) or not target.can_process():
		interrupt_actions()
		return
	var offset: Vector2 = target.global_position - global_position
	var was_chasing: bool = action_state.phase == State.CHASE
	var old_serial: int = action_state.attack_serial
	if not action_state.advance(delta, offset) or delta == 0.0:
		return
	active_snapshot = action_state.active_this_step
	if was_chasing and action_state.phase == State.CHASE and action_state.attack_serial == old_serial:
		velocity = offset.normalized() * SPEED
		move_and_slide()
	if active_snapshot:
		_resolve_target(target)
		# O callback pode remover self ou enfileirar exclusão. Nenhum acesso posterior.
		return
	queue_redraw()


func _resolve_target(target: CharacterBody2D) -> void:
	queue_redraw()
	var serial: int = action_state.attack_serial
	if _attempt_serial != serial:
		_attempt_serial = serial
		_attempted.clear()
	var id := target.get_instance_id()
	if _attempted.has(id):
		return
	var shape := ConvexPolygonShape2D.new()
	shape.points = _sector.sector_points(action_state.attack_direction)
	var touching := false
	# Sem broadphase: o jogador já moveu neste tick, inclusive se entrou/saiu agora.
	for owner: int in target.get_shape_owners():
		if target.is_shape_owner_disabled(owner):
			continue
		var transform: Transform2D = target.global_transform * target.shape_owner_get_transform(owner)
		for index in range(target.shape_owner_get_shape_count(owner)):
			var feet: Shape2D = target.shape_owner_get_shape(owner, index)
			if feet != null and shape.collide(Transform2D(0.0, global_position), feet, transform):
				touching = true
	if not touching:
		return
	var ray := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	ray.hit_from_inside = true
	ray.exclude = [get_rid(), target.get_rid()]
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return
	# Registrar antes do callback; proteção e reentrância também consomem tentativa.
	_attempted[id] = true
	target.receive_hit(DAMAGE)


func _draw() -> void:
	_refresh_ground_sector()
	var ink := Color("182d36")
	var light := Color("f4d8a5")
	if health.dead:
		draw_colored_polygon(PackedVector2Array([Vector2(-21, -6), Vector2(-8, -12), Vector2(21, -7), Vector2(15, 0), Vector2(-16, 0)]), Color("59635b"))
		draw_line(Vector2(-12, -12), Vector2(12, 1), light, 2.0)
		draw_line(Vector2(-12, 1), Vector2(12, -12), light, 2.0)
		return
	var phase: int = action_state.phase
	var active := active_snapshot or phase == State.ACTIVE
	var direction: Vector2 = action_state.attack_direction
	_draw_shadow(ink)
	var lean := -3.0 if phase == State.WINDUP else 3.0 if active else 0.0
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -2), Vector2(-14, -24 + lean), Vector2(-7, -31 + lean), Vector2(9, -28 + lean), Vector2(12, -2)]), Color("697654"))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -28 + lean), Vector2(-8, -39 + lean), Vector2(5, -42 + lean), Vector2(9, -29 + lean)]), Color("b8af7c"))
	var shoulder := Vector2(0, -23 + lean)
	for side: float in [-1.0, 1.0]:
		var elbow := shoulder + direction.rotated(side * (1.4 if phase == State.WINDUP else 0.25)) * (13.0 if active else 10.0)
		var hand := shoulder + direction * (29.0 if active else -8.0 if phase == State.WINDUP else 4.0) + Vector2(side * 8, 14 if phase == State.RECOVERY else 0)
		draw_polyline(PackedVector2Array([shoulder + Vector2(side * 9, 0), elbow, hand]), ink, 6.0)
		draw_polyline(PackedVector2Array([shoulder + Vector2(side * 9, 0), elbow, hand]), light, 3.0)
	if phase == State.WINDUP:
		draw_polyline(PackedVector2Array([Vector2(-8, -52), Vector2(0, -59), Vector2(8, -52)]), light, 2.5)
	elif phase == State.RECOVERY:
		for y: float in [-52.0, -47.0]:
			draw_line(Vector2(-8, y), Vector2(8, y), light, 2.5)
	draw_string(ThemeDB.fallback_font, Vector2(-20, -68), "%d/30" % health.current, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, light)


func _refresh_ground_sector() -> void:
	# Somente apresentação. CanvasItems nativos separam chão/corpos sem script
	# novo, relógio próprio, mudança do setor físico ou elevação dos personagens.
	var ground := get_node_or_null("GroundSector") as Node2D
	if ground == null:
		return
	var phase: int = action_state.phase
	var active := active_snapshot or phase == State.ACTIVE
	ground.visible = not health.dead and (phase == State.WINDUP or active)
	if not ground.visible:
		return
	var direction: Vector2 = action_state.attack_direction
	var points: PackedVector2Array = _sector.sector_points(direction)
	var fill := ground.get_node("Fill") as Polygon2D
	fill.visible = active
	fill.polygon = points
	var outline := ground.get_node("Outline") as Line2D
	var closed := points.duplicate()
	closed.append(points[0])
	outline.points = closed
	outline.width = 3.0 if active else 1.5
	for index: int in range(3):
		var hatch := ground.get_node("Hatch%d" % index) as Line2D
		var distance: float = [26.0, 40.0, 54.0][index]
		hatch.visible = active
		hatch.points = PackedVector2Array([direction.rotated(-0.65) * distance, direction.rotated(0.65) * distance])


func _draw_shadow(ink: Color) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		var angle := float(i) * TAU / 16.0
		points.append(Vector2(cos(angle) * 14, sin(angle) * 6))
	draw_colored_polygon(points, ink)

extends CharacterBody2D
## Corpo no plano do chão. A origem e o colisor representam os pés.
## Blockout temporário de combate; apresentação não altera a colisão dos pés.

# Faixa técnica suportada no laboratório; não é balanceamento final.
const MAX_SPEED := 1000.0
const ActionState := preload("res://src/player/action_state.gd")
const Health := preload("res://src/combat/health.gd")
const MeleeHit := preload("res://src/combat/melee_hit.gd")

signal died()

@export_range(0.0, MAX_SPEED, 1.0) var speed: float = 240.0

var aim_direction: Vector2 = Vector2.RIGHT
var _move_intent: Vector2 = Vector2.ZERO
var action_state := ActionState.new()
var health := Health.new(100)
var active_snapshot: bool = false
var control_enabled: bool = true
var audio_enabled: bool = true
var reaction_remaining: float = 0.0
var _attack_pending: bool = false
var _dodge_pending: bool = false
var _generation: int = 0
var _hit := MeleeHit.new()
var _sound: AudioStreamPlayer
var _sounded_serial: int = 0


func _init() -> void:
	health.died.connect(_on_died)


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -20.0
	add_child(_sound)

@onready var _aim_indicator: Node2D = $AimIndicator


func apply_intent(move: Vector2, aim: Vector2) -> void:
	_move_intent = Vector2.ZERO
	if control_enabled and not health.dead and move.is_finite():
		var scale := maxf(absf(move.x), absf(move.y))
		_move_intent = (move / scale).normalized() if scale > 1.0 else move.limit_length(1.0)
	if aim.is_finite() and aim != Vector2.ZERO:
		var scale := maxf(absf(aim.x), absf(aim.y))
		aim_direction = (aim / scale).normalized()
	# A rotação da apresentação não altera o corpo nem a shape de colisão.
	if is_instance_valid(_aim_indicator):
		_aim_indicator.rotation = aim_direction.angle()


func queue_actions(attack_pressed: bool, dodge_pressed: bool) -> void:
	if control_enabled and not health.dead:
		_attack_pending = _attack_pending or attack_pressed
		_dodge_pending = _dodge_pending or dodge_pressed


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled and not health.dead
	_attack_pending = false
	_dodge_pending = false
	_move_intent = Vector2.ZERO
	velocity = Vector2.ZERO


func interrupt_actions() -> void:
	_generation += 1
	action_state.interrupt()
	active_snapshot = false
	set_control_enabled(control_enabled)
	queue_redraw()


func receive_hit(amount: int) -> bool:
	if not _eligible() or action_state.invulnerable or amount < 1 or amount > 1000:
		return false
	reaction_remaining = 0.12
	queue_redraw()
	return health.apply_damage(amount)


func _eligible() -> bool:
	if not control_enabled or health.dead or not is_inside_tree() or is_queued_for_deletion():
		return false
	if get_tree().paused or not can_process():
		return false
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return true


func _on_died() -> void:
	action_state.mark_dead()
	_generation += 1
	active_snapshot = false
	set_control_enabled(false)
	queue_redraw()
	died.emit()


func _physics_process(delta: float) -> void:
	# T1 conserva saídas em advance(0)/inválido. Nunca reutilizar esse snapshot.
	active_snapshot = false
	if not is_finite(delta) or delta <= 0.0 or delta > 10.0 or not _eligible():
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var dodge := _dodge_pending
	var attack := _attack_pending
	_attack_pending = false
	_dodge_pending = false
	var dodged := false
	if dodge:
		dodged = action_state.try_dodge(_move_intent if _move_intent != Vector2.ZERO else aim_direction)
	if attack and not dodged:
		action_state.try_attack(aim_direction)
	action_state.advance(delta)
	var generation := _generation
	var serial: int = action_state.attack_serial
	active_snapshot = action_state.active_this_step
	var safe_speed := speed if is_finite(speed) and speed >= 0.0 and speed <= MAX_SPEED else 0.0
	var dash_time: float = action_state.dodge_seconds_this_step
	velocity = _move_intent * safe_speed if dash_time == 0.0 else (
		action_state.dodge_direction * 800.0 * (dash_time / delta) + _move_intent * safe_speed * ((delta - dash_time) / delta))
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	move_and_slide()
	if active_snapshot:
		var accepted := _hit.resolve(get_world_2d().direct_space_state, self, global_position,
			action_state.attack_direction, serial, func() -> bool:
				return _eligible() and _generation == generation and action_state.attack_serial == serial and action_state.active_this_step)
		if accepted > 0 or _sounded_serial != serial:
			_play_sound(accepted > 0)
			_sounded_serial = serial
	reaction_remaining = maxf(0.0, reaction_remaining - delta)
	queue_redraw()


func _play_sound(impact: bool) -> void:
	if not audio_enabled or not is_instance_valid(_sound):
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(2206)
	for i in range(1103):
		var envelope := pow(1.0 - float(i) / 1103.0, 3.0)
		var value := int(sin(float(i) * (0.24 if impact else 0.08)) * envelope * (10000.0 if impact else 4000.0))
		bytes.encode_s16(i * 2, value)
	stream.data = bytes
	_sound.stream = stream
	_sound.play()


func _draw() -> void:
	if health.dead:
		draw_line(Vector2(-13, -30), Vector2(13, -4), Color("f4d8a5"), 3.0)
		draw_line(Vector2(13, -30), Vector2(-13, -4), Color("f4d8a5"), 3.0)
		return
	if action_state.invulnerable:
		draw_arc(Vector2(0, -18), 25.0, 0, TAU, 32, Color("e8f4df"), 2.0)
		draw_arc(Vector2(0, -18), 29.0, 0, TAU, 32, Color("e8f4df"), 2.0)
	if reaction_remaining > 0.0:
		draw_line(Vector2(-17, -44), Vector2(17, -44), Color("f4d8a5"), 3.0)
	if active_snapshot:
		var points := _hit.sector_points(action_state.attack_direction)
		draw_colored_polygon(points, Color(1.0, 0.86, 0.50, 0.38))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, Color("ffdf91"), 2.0)
	var direction := action_state.attack_direction if action_state.phase in [1, 2, 3] or active_snapshot else aim_direction
	var angle := -0.8 if action_state.phase == 1 else 0.6 if action_state.phase == 3 and not active_snapshot else 0.0
	var hand := direction.rotated(angle) * 16.0 + Vector2(0, -12)
	draw_line(hand, hand + direction.rotated(angle) * 23.0, Color("182d36"), 5.0)

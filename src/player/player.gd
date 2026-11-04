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
var _damage_labels: Array[Label] = []
var _damage_remaining: Array[float] = [0.0, 0.0]
var _damage_order: Array[int] = [0, 0]
var _damage_serial: int = 0
var _feedback_epoch: int = 0


func _init() -> void:
	health.died.connect(_on_died)


func _ready() -> void:
	_sound = AudioStreamPlayer.new()
	_sound.volume_db = -20.0
	add_child(_sound)
	for slot in range(2):
		var label := Label.new()
		label.name = "DamageNumber%d" % (slot + 1)
		# Caixa acima da recomendação inicial para liberar o rótulo da zona;
		# a altura mínima da fonte continua sendo respeitada pelo Label.
		label.position = Vector2(-50, -94 - slot * 24)
		label.size = Vector2(100, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("f4d8a5"))
		label.add_theme_color_override("font_outline_color", Color("182d36"))
		label.add_theme_constant_override("outline_size", 2)
		label.hide()
		add_child(label)
		_damage_labels.append(label)

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
	var next_enabled := enabled and not health.dead
	if next_enabled != control_enabled:
		_feedback_epoch += 1
	control_enabled = next_enabled
	_attack_pending = false
	_dodge_pending = false
	_move_intent = Vector2.ZERO
	velocity = Vector2.ZERO


func interrupt_actions() -> void:
	_generation += 1
	action_state.interrupt()
	active_snapshot = false
	if not control_enabled:
		_clear_damage_feedback()
	set_control_enabled(control_enabled)
	queue_redraw()


func receive_hit(amount: int) -> bool:
	if not _eligible() or action_state.invulnerable or amount < 1 or amount > 1000:
		return false
	# Health atualiza vida antes de callbacks síncronos. Capturar a perda desta
	# chamada, não a diferença ao retornar (que poderia incluir dano aninhado).
	var receiver := health
	var loss := mini(amount, receiver.current)
	var generation := _generation
	var epoch := _feedback_epoch
	_damage_serial += 1
	var serial := _damage_serial
	var accepted := receiver.apply_damage(amount)
	if accepted and health == receiver and _generation == generation and _feedback_epoch == epoch and _eligible():
		_publish_damage(loss, serial)
	return accepted


func _publish_damage(loss: int, serial: int) -> void:
	if _damage_labels.size() != 2:
		return
	var slot := 0 if _damage_remaining[0] == 0.0 else 1 if _damage_remaining[1] == 0.0 else (
		0 if _damage_order[0] < _damage_order[1] else 1)
	# Uma chamada externa pode retornar depois de dois eventos aninhados novos.
	# Não substituir um deles pelo evento antigo nem criar uma fila de efeitos.
	if _damage_remaining[slot] > 0.0 and _damage_order[slot] > serial:
		return
	_damage_order[slot] = serial
	_damage_remaining[slot] = 0.60
	_damage_labels[slot].text = "−%d" % loss
	_damage_labels[slot].show()
	reaction_remaining = 0.20
	queue_redraw()


func _advance_damage_feedback(delta: float) -> void:
	reaction_remaining = maxf(0.0, reaction_remaining - delta)
	if reaction_remaining <= 0.000001:
		reaction_remaining = 0.0
	for slot in range(_damage_labels.size()):
		_damage_remaining[slot] = maxf(0.0, _damage_remaining[slot] - delta)
		if _damage_remaining[slot] <= 0.000001:
			_damage_remaining[slot] = 0.0
			_damage_labels[slot].hide()
			_damage_labels[slot].text = ""


func _clear_damage_feedback() -> void:
	reaction_remaining = 0.0
	for slot in range(_damage_labels.size()):
		_damage_remaining[slot] = 0.0
		_damage_order[slot] = 0
		_damage_labels[slot].hide()
		_damage_labels[slot].text = ""
	queue_redraw()


func _exit_tree() -> void:
	_feedback_epoch += 1
	_clear_damage_feedback()


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
	_clear_damage_feedback()
	queue_redraw()
	died.emit()


func _physics_process(delta: float) -> void:
	# T1 conserva saídas em advance(0)/inválido. Nunca reutilizar esse snapshot.
	active_snapshot = false
	if not is_finite(delta) or delta <= 0.0 or delta > 10.0 or not _eligible():
		velocity = Vector2.ZERO
		queue_redraw()
		return
	_advance_damage_feedback(delta)
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
		for side: float in [-1.0, 1.0]:
			var mark := PackedVector2Array([Vector2(side * 15, -29), Vector2(side * 21, -22), Vector2(side * 15, -15)])
			draw_polyline(mark, Color("182d36"), 4.0)
			draw_polyline(mark, Color("f4d8a5"), 2.0)
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

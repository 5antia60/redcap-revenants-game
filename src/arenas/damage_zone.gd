extends Node2D
## Relógio físico local; desenho e query consomem exatamente o mesmo snapshot.

const RECT := Rect2(-60, -40, 120, 80)
@export var player: CharacterBody2D
var snapshot: Dictionary = {"pulse_serial": 0, "danger_this_step": false, "phase": "warning"}
var _time: float = 0.0
var _attempted: Dictionary = {}
var _attempt_serial: int = -1


func _ready() -> void:
	process_physics_priority = 10


func advance_clock(delta: float) -> Dictionary:
	if not is_finite(delta) or delta < 0.0 or delta > 10.0:
		return {}
	if delta == 0.0:
		return snapshot.duplicate()
	var start := _time
	_time += delta
	# Última janela cujo começo é estritamente anterior ao fim do passo.
	var latest := int(ceil(_time - 0.35)) - 1
	var danger := latest >= 0 and minf(_time, float(latest) + 0.45) > maxf(start, float(latest) + 0.35)
	var cycle := int(floor(_time))
	var local := _time - float(cycle)
	snapshot = {"pulse_serial": latest if danger else cycle, "danger_this_step": danger,
		"phase": "warning" if local < 0.35 else "active" if local < 0.45 else "rest"}
	return snapshot.duplicate()


func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > 10.0 or get_tree().paused or not can_process():
		return
	var step := advance_clock(delta)
	queue_redraw()
	if step.is_empty() or not step.danger_this_step:
		return
	if _attempt_serial != step.pulse_serial:
		_attempt_serial = step.pulse_serial
		_attempted.clear()
	var shape := RectangleShape2D.new()
	shape.size = RECT.size
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_queued_for_deletion() or (player.collision_layer & 2) == 0:
		return
	var feet := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if feet == null or feet.disabled or feet.shape == null:
		return
	# Query nativa entre shapes nos transforms finais. A broadphase do mundo pode
	# ainda conter a posição anterior do CharacterBody movido neste mesmo callback.
	if not shape.collide(global_transform, feet.shape, feet.global_transform):
		return
	var id := player.get_instance_id()
	if _attempted.has(id) or not player.has_method("receive_hit"):
		return
	_attempted[id] = true
	player.receive_hit(25)


func _draw() -> void:
	var danger: bool = snapshot.danger_this_step
	var warning: bool = snapshot.phase == "warning"
	draw_rect(RECT, Color("9b4e30") if danger else Color("746747") if warning else Color("545b50"))
	draw_rect(RECT, Color("ffe2a1"), false, 3.0 if danger else 1.5)
	if danger:
		draw_line(RECT.position, RECT.end, Color("ffe2a1"), 3.0)
		draw_line(Vector2(60, -40), Vector2(-60, 40), Color("ffe2a1"), 3.0)
	elif warning:
		for x in [-40, 0, 40]:
			draw_line(Vector2(x, -22), Vector2(x, 14), Color("ffe2a1"), 3.0)
	var text := "DANO 25" if danger else "AVISO" if warning else "REPOUSO"
	draw_string(ThemeDB.fallback_font, Vector2(-58, -52), "TREINO · " + text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff0ce"))

extends StaticBody2D
## Base lógica nos pés. Blockout de treino, sem IA ou arte final.

signal died()

const Health := preload("res://src/combat/health.gd")
var health: RefCounted:
	get: return _health
var _health := Health.new(30)
var reaction_remaining: float = 0.0


func _init() -> void:
	_health.died.connect(_on_died)
	_health.changed.connect(_on_changed)


func _on_changed(_current: int, _maximum: int) -> void:
	reaction_remaining = 0.12
	queue_redraw()


func _physics_process(delta: float) -> void:
	if reaction_remaining > 0:
		reaction_remaining = maxf(0.0, reaction_remaining - delta)
		queue_redraw()


func receive_hit(amount: int) -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or get_tree().paused or not can_process():
		return false
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	# Agendar antes dos sinais: um ouvinte de morte pode remover esta instância.
	queue_redraw()
	return _health.apply_damage(amount)


func _on_died() -> void:
	died.emit()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 11.0, Color("263338"))
	draw_set_transform(Vector2.ZERO)
	var body_color := Color("9b6554") if _health.dead else Color("c7a675")
	draw_rect(Rect2(-9, -34, 18, 31), body_color)
	draw_line(Vector2(-9, -22), Vector2(9, -22), Color("37474d"), 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-24, -46), "%d/30" % _health.current, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff0ce"))
	if reaction_remaining > 0:
		draw_line(Vector2(-17, -38), Vector2(-12, -43), Color("fff0ce"), 3.0)
		draw_line(Vector2(17, -38), Vector2(12, -43), Color("fff0ce"), 3.0)
	if _health.dead:
		draw_line(Vector2(-12, -34), Vector2(12, -4), Color("182d36"), 3.0)
		draw_line(Vector2(12, -34), Vector2(-12, -4), Color("182d36"), 3.0)

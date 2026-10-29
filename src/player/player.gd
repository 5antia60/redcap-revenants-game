extends CharacterBody2D
## Corpo no plano do chão. A origem e o colisor representam os pés.
## Blockout temporário: silhueta quente, anel dos pés e indicador sem arma.

# Faixa técnica suportada no laboratório; não é balanceamento final.
const MAX_SPEED := 1000.0

@export_range(0.0, MAX_SPEED, 1.0) var speed: float = 240.0

var aim_direction: Vector2 = Vector2.RIGHT
var _move_intent: Vector2 = Vector2.ZERO

@onready var _aim_indicator: Node2D = $AimIndicator


func apply_intent(move: Vector2, aim: Vector2) -> void:
	_move_intent = Vector2.ZERO
	if move.is_finite():
		var scale := maxf(absf(move.x), absf(move.y))
		_move_intent = (move / scale).normalized() if scale > 1.0 else move.limit_length(1.0)
	if aim.is_finite() and aim != Vector2.ZERO:
		var scale := maxf(absf(aim.x), absf(aim.y))
		aim_direction = (aim / scale).normalized()
	# A rotação da apresentação não altera o corpo nem a shape de colisão.
	if is_instance_valid(_aim_indicator):
		_aim_indicator.rotation = aim_direction.angle()


func _physics_process(_delta: float) -> void:
	var safe_speed := speed if is_finite(speed) and speed >= 0.0 and speed <= MAX_SPEED else 0.0
	velocity = _move_intent * safe_speed
	if not velocity.is_finite():
		velocity = Vector2.ZERO
	move_and_slide()

extends RefCounted
## Política local: recebe amostras cruas e atividade já identificada pelo adaptador.
## Atividade do mouse usa pixels do viewport, nunca mudanças da câmera no mundo.

# Usa a mesma precisão das amostras Vector2 no limite radial exato.
const STICK_DEADZONE: float = Vector2(0.2, 0.0).x

var aim_direction: Vector2 = Vector2.RIGHT
var aim_source: String = "mouse"


func movement(keyboard: Vector2, keyboard_active: bool, stick: Vector2) -> Vector2:
	if keyboard_active:
		return _limited(keyboard)
	if not stick.is_finite():
		return Vector2.ZERO
	var bounded := _limited(stick)
	var magnitude := bounded.length()
	if magnitude <= STICK_DEADZONE:
		return Vector2.ZERO
	return bounded / magnitude * ((magnitude - STICK_DEADZONE) / (1.0 - STICK_DEADZONE))


func aim(mouse_world: Vector2, feet_world: Vector2, mouse_activity: bool,
		stick: Vector2, stick_activity: bool) -> Vector2:
	var mouse_direction := Vector2.ZERO
	if mouse_world.is_finite() and feet_world.is_finite():
		mouse_direction = _unit(mouse_world - feet_world)
	var stick_direction := Vector2.ZERO
	if stick.is_finite() and _limited(stick).length() > STICK_DEADZONE:
		stick_direction = _unit(stick)
	# As flags representam intenção significativa, não a presença de uma amostra.
	if mouse_activity and mouse_direction != Vector2.ZERO:
		aim_source = "mouse"
	elif stick_activity and stick_direction != Vector2.ZERO:
		aim_source = "gamepad"
	var direction := mouse_direction if aim_source == "mouse" else stick_direction
	if direction != Vector2.ZERO:
		aim_direction = direction
	return aim_direction


func _limited(value: Vector2) -> Vector2:
	if not value.is_finite():
		return Vector2.ZERO
	# Escalar antes de normalizar também evita overflow para componentes finitos enormes.
	if maxf(absf(value.x), absf(value.y)) > 1.0:
		return _unit(value)
	return value.limit_length(1.0)


func _unit(value: Vector2) -> Vector2:
	if not value.is_finite() or value == Vector2.ZERO:
		return Vector2.ZERO
	var scale := maxf(absf(value.x), absf(value.y))
	return (value / scale).normalized()

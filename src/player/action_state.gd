extends RefCounted
## Relógio local avançado uma vez por tick físico, sem consultar entrada ou pausa.
## O consumidor usa active_this_step mesmo se a fase final já não for ACTIVE.

enum { IDLE, WINDUP, ACTIVE, RECOVERY, DODGE, DEAD }

const WINDUP_END: float = 0.05
const ACTIVE_END: float = 0.13
const ATTACK_END: float = 0.27
const DODGE_END: float = 0.15
const PROTECTION_END: float = 0.10
const DODGE_COOLDOWN: float = 0.75
const CLOCK_EPSILON: float = 0.000001
const MAX_DELTA: float = 10.0

var phase: int:
	get: return _phase
var attack_direction: Vector2:
	get: return _attack_direction
var attack_serial: int:
	get: return _attack_serial
var active_this_step: bool:
	get: return _active_this_step
var dodge_direction: Vector2:
	get: return _dodge_direction
var dodge_seconds_this_step: float:
	get: return _dodge_seconds_this_step
var invulnerable: bool:
	get: return _phase == DODGE and not _clock_ended(_elapsed, PROTECTION_END)
var cooldown_remaining: float:
	get: return _cooldown_remaining

var _phase: int = IDLE
var _attack_direction: Vector2 = Vector2.RIGHT
var _attack_serial: int = 0
var _active_this_step: bool = false
var _dodge_direction: Vector2 = Vector2.RIGHT
var _dodge_seconds_this_step: float = 0.0
var _cooldown_remaining: float = 0.0
var _elapsed: float = 0.0


func try_attack(direction: Vector2) -> bool:
	if _phase != IDLE or not direction.is_finite() or direction == Vector2.ZERO:
		return false
	_attack_direction = _unit(direction)
	_attack_serial += 1
	_begin(WINDUP)
	return true


func try_dodge(direction: Vector2) -> bool:
	if (_phase != IDLE and _phase != RECOVERY) or _cooldown_remaining > 0.0:
		return false
	if not direction.is_finite() or direction == Vector2.ZERO:
		return false
	_dodge_direction = _unit(direction)
	_cooldown_remaining = DODGE_COOLDOWN
	_begin(DODGE)
	return true


func advance(delta: float) -> bool:
	# Rejeição e zero preservam inclusive o snapshot já produzido neste tick.
	if not is_finite(delta) or delta < 0.0 or delta > MAX_DELTA:
		return false
	if delta == 0.0 or _phase == DEAD:
		return true
	_active_this_step = false
	_dodge_seconds_this_step = 0.0
	_cooldown_remaining = 0.0 if _clock_ended(delta, _cooldown_remaining) else _cooldown_remaining - delta
	if _phase == DODGE:
		_dodge_seconds_this_step = minf(delta, DODGE_END - _elapsed)
		_elapsed += delta
		if _clock_ended(_elapsed, DODGE_END):
			_phase = IDLE
	elif _phase == WINDUP or _phase == ACTIVE or _phase == RECOVERY:
		_advance_attack(delta)
	return true


func _advance_attack(delta: float) -> void:
	var start := _elapsed
	_elapsed += delta
	# Três bordas fixas: custo constante mesmo atravessando toda a ação em 10 s.
	for boundary: float in [WINDUP_END, ACTIVE_END, ATTACK_END]:
		# Normaliza só o resto antes da borda; excedente positivo é percurso real.
		if _elapsed < boundary and _clock_ended(_elapsed, boundary):
			_elapsed = boundary
	_active_this_step = minf(_elapsed, ACTIVE_END) > maxf(start, WINDUP_END)
	if _elapsed < WINDUP_END:
		_phase = WINDUP
	elif _elapsed < ACTIVE_END:
		_phase = ACTIVE
	elif _elapsed < ATTACK_END:
		_phase = RECOVERY
	else:
		_phase = IDLE


func interrupt() -> void:
	if _phase != DEAD:
		_begin(IDLE)


func mark_dead() -> void:
	_begin(DEAD)


func _begin(next_phase: int) -> void:
	_phase = next_phase
	_elapsed = 0.0
	_active_this_step = false
	_dodge_seconds_this_step = 0.0


func _clock_ended(elapsed: float, limit: float) -> bool:
	# Compara a borda diretamente: subtrair primeiro o resto pode transformar
	# exatamente 1 microssegundo em 1,00000000003 microssegundos por cancelamento.
	return elapsed >= limit - CLOCK_EPSILON


func _unit(direction: Vector2) -> Vector2:
	# Escalar primeiro evita overflow/underflow para componentes finitos extremos.
	var scale := maxf(absf(direction.x), absf(direction.y))
	return (direction / scale).normalized()

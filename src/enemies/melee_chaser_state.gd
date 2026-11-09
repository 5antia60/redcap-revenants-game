extends RefCounted
## Política local sem entrada/árvore. Um passo pode atravessar uma ação,
## nunca iniciar ações compensatórias com o tempo que sobrar.

enum { CHASE, WINDUP, ACTIVE, RECOVERY, DEAD }
const MAX_DELTA := 10.0
const MAX_COORDINATE := 1000000.0
const CLOCK_EPSILON := 0.000000000001

var phase: int:
	get: return _phase
var attack_direction: Vector2:
	get: return _direction
var attack_serial: int:
	get: return _serial
var active_this_step: bool:
	get: return _active

var _phase: int = CHASE
var _direction := Vector2.RIGHT
var _serial: int = 0
var _elapsed: float = 0.0
var _active: bool = false


func advance(delta: float, target_offset: Vector2) -> bool:
	# Saída efêmera: zero ou rejeição nunca reaplicam um snapshot antigo.
	_active = false
	if not is_finite(delta) or delta < 0.0 or delta > MAX_DELTA:
		return false
	if not target_offset.is_finite() or absf(target_offset.x) > MAX_COORDINATE \
			or absf(target_offset.y) > MAX_COORDINATE:
		return false
	if delta == 0.0 or _phase == DEAD:
		return true
	if _phase == CHASE:
		if target_offset.length() > 60.0:
			return true
		if target_offset != Vector2.ZERO:
			_direction = target_offset.normalized()
		_serial += 1
		_elapsed = 0.0
		_phase = WINDUP
	var start := _elapsed
	_elapsed += delta
	# Normalizar apenas ruído de soma double (36 * 1/60 excede0,60 por2e-16).
	# O limite1e-12 é muito menor que um tick; não amplia janela/proteção S2.
	for boundary: float in [0.60, 0.70, 1.50]:
		if absf(_elapsed - boundary) <= CLOCK_EPSILON:
			_elapsed = boundary
	_active = minf(_elapsed, 0.70) > maxf(start, 0.60)
	_phase = WINDUP if _elapsed < 0.60 else ACTIVE if _elapsed < 0.70 else RECOVERY if _elapsed < 1.50 else CHASE
	return true


func interrupt() -> void:
	_active = false
	_elapsed = 0.0
	if _phase != DEAD:
		_phase = CHASE


func mark_dead() -> void:
	interrupt()
	_phase = DEAD

extends RefCounted
## Vida por receptor; elegibilidade de contato e pausa pertencem ao ator.

signal changed(current: int, maximum: int)
signal died()

var current: int:
	get: return _current
var maximum: int:
	get: return _maximum
var dead: bool:
	get: return _dead

var _current: int = 100
var _maximum: int = 100
var _dead: bool = false


func _init(maximum: int = 100) -> void:
	_maximum = maximum if maximum >= 1 and maximum <= 1000 else 100
	_current = _maximum


func apply_damage(amount: int) -> bool:
	if _dead or amount < 1 or amount > 1000:
		return false
	_current = maxi(0, _current - amount)
	var killed := _current == 0
	_dead = killed
	# Captura a transição desta chamada antes de callbacks síncronos: um changed
	# não letal pode causar morte aninhada, mas não uma segunda morte ao retornar.
	changed.emit(_current, _maximum)
	if killed:
		died.emit()
	return true

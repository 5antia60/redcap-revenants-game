extends "res://src/player/player_input.gd"
## Somente leituras de hardware; coleta, suspensão, arbitragem e bordas são reais.
var buttons: Dictionary = {}
var keys: Dictionary = {}
var mouse_held: bool = false
func _read_connected_joypads() -> PackedInt32Array:
	return PackedInt32Array([37])
func _read_joy_axis(_device: int, _axis: int) -> float:
	return 0.0
func _read_joy_button_pressed(device: int, button: int) -> bool:
	return device == 37 and bool(buttons.get(button, false))
func _read_physical_key_pressed(key: int) -> bool:
	return bool(keys.get(key, false))
func _read_mouse_button_pressed(_button: int) -> bool:
	return mouse_held

extends Node
## Adaptador local. Amostras cruas passam uma única vez pela política de intenção.

const IntentState := preload("res://src/player/input_state.gd")
const MOVE_KEYS := [KEY_A, KEY_D, KEY_W, KEY_S, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
const DEADZONE: float = Vector2(0.2, 0).x

@export var player: CharacterBody2D
var active_device: int = -1
var focus_active: bool = true
var disconnected: bool = false
var aim_source: String:
	get: return _state.aim_source

var _state := IntentState.new()
var _keys: Dictionary = {}
var _blocked_keys: Dictionary = {}
var _devices: Dictionary = {}
var _mouse_position := Vector2.ZERO
var _mouse_reference: bool = false
var _mouse_distance: float = 0.0
var _mouse_activity: bool = false
var _mouse_aim_enabled: bool = false
var _stick_activity: bool = false


func _ready() -> void:
	# Menor prioridade roda antes do corpo, inclusive quando instanciado depois dele.
	process_physics_priority = player.process_physics_priority - 1
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	get_window().focus_exited.connect(set_focus_active.bind(false))
	get_window().focus_entered.connect(set_focus_active.bind(true))
	# A cena pode nascer/reaparecer depois de a janela já ter perdido foco.
	set_focus_active(_read_window_has_focus())
	for device: int in _read_connected_joypads():
		_on_joy_connection_changed(device, true)


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	var window := get_window()
	for focused: bool in [false, true]:
		var callback := set_focus_active.bind(focused)
		var event: Signal = window.focus_entered if focused else window.focus_exited
		if event.is_connected(callback):
			event.disconnect(callback)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode in MOVE_KEYS:
		var code: int = event.physical_keycode
		if not event.pressed:
			_keys.erase(code)
			_blocked_keys.erase(code)
		elif not focus_active:
			_blocked_keys[code] = true
		elif not event.echo and not _blocked_keys.has(code):
			_keys[code] = true
	elif event is InputEventMouseMotion and focus_active and event.position.is_finite():
		if not _mouse_reference:
			_mouse_position = event.position
			_mouse_reference = true
			return
		# position/relative são do viewport. Transformação da câmera nunca é atividade.
		if event.relative.is_finite() and not event.relative.is_zero_approx():
			_mouse_distance += event.position.distance_to(_mouse_position)
			if _mouse_distance >= 2.0:
				_mouse_activity = true
				_mouse_aim_enabled = true
				_mouse_distance = 0.0
		_mouse_position = event.position


func sample_joypad(device: int, movement: Vector2, aim: Vector2) -> void:
	if device < 0:
		return
	if not _devices.has(device):
		_devices[device] = _new_device(focus_active)
	var sample: Dictionary = _devices[device]
	movement = movement.limit_length(1.0) if movement.is_finite() else Vector2.ZERO
	aim = aim.limit_length(1.0) if aim.is_finite() else Vector2.ZERO
	if not focus_active:
		return
	if not sample.armed:
		if movement.length() <= DEADZONE and aim.length() <= DEADZONE:
			sample.armed = true
		return
	var move_activity := movement.length() > DEADZONE and (Vector2(sample.move).length() <= DEADZONE
		or movement.distance_to(sample.move) >= 0.05)
	var aim_activity := aim.length() > DEADZONE and (Vector2(sample.aim_reference).length() <= DEADZONE
		or aim.distance_to(sample.aim_reference) >= 0.05)
	if aim_activity or aim.length() <= DEADZONE:
		sample.aim_reference = aim
	sample.move = movement
	sample.aim = aim
	if move_activity or aim_activity:
		if active_device != device:
			_stick_activity = false
		active_device = device
		disconnected = false
	if active_device == device:
		_stick_activity = _stick_activity or aim_activity


func set_focus_active(focused: bool) -> void:
	if focused == focus_active:
		return
	focus_active = focused
	for key: int in _keys:
		_blocked_keys[key] = true
	for key: int in MOVE_KEYS:
		if _read_physical_key_pressed(key):
			_blocked_keys[key] = true
	_keys.clear()
	for device: int in _devices:
		_devices[device] = _new_device(false)
	active_device = -1
	_mouse_reference = false
	_mouse_aim_enabled = false
	_mouse_distance = 0.0
	_mouse_activity = false
	_stick_activity = false
	_stop_motion()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_devices[device] = _new_device(false)
	else:
		_devices.erase(device)
		if active_device == device:
			active_device = -1
			_stick_activity = false
			disconnected = true
			_stop_motion()


func _physics_process(_delta: float) -> void:
	for device: int in _read_connected_joypads():
		sample_joypad(device, Vector2(_read_joy_axis(device, JOY_AXIS_LEFT_X), _read_joy_axis(device, JOY_AXIS_LEFT_Y)),
			Vector2(_read_joy_axis(device, JOY_AXIS_RIGHT_X), _read_joy_axis(device, JOY_AXIS_RIGHT_Y)))
	if not focus_active:
		_stop_motion()
		return
	var keyboard := Vector2(int(_held(KEY_D, KEY_RIGHT)) - int(_held(KEY_A, KEY_LEFT)),
		int(_held(KEY_S, KEY_DOWN)) - int(_held(KEY_W, KEY_UP)))
	var sample: Dictionary = _devices.get(active_device, _new_device(false))
	var move: Vector2 = _state.movement(keyboard, not _keys.is_empty(), sample.move)
	var feet := player.global_position
	var mouse_world := feet
	if _mouse_aim_enabled:
		mouse_world = player.get_canvas_transform().affine_inverse() * _mouse_position
	var aim: Vector2 = _state.aim(mouse_world, feet, _mouse_activity, sample.aim, _stick_activity)
	player.apply_intent(move, aim)
	_mouse_activity = false
	_stick_activity = false


func _held(first: int, second: int) -> bool:
	return _keys.has(first) or _keys.has(second)


func _stop_motion() -> void:
	player.apply_intent(Vector2.ZERO, _state.aim_direction)
	player.velocity = Vector2.ZERO


func _new_device(armed: bool) -> Dictionary:
	return {"armed": armed, "move": Vector2.ZERO, "aim": Vector2.ZERO, "aim_reference": Vector2.ZERO}


# Fronteira de leitura local: processamento e política continuam acima, compartilhados
# pelo jogo e pelos testes. Não altera InputMap nem o estado global da engine.
func _read_connected_joypads() -> PackedInt32Array:
	return PackedInt32Array(Input.get_connected_joypads())


func _read_joy_axis(device: int, axis: int) -> float:
	return Input.get_joy_axis(device, axis)


func _read_physical_key_pressed(key: int) -> bool:
	return Input.is_physical_key_pressed(key)


func _read_window_has_focus() -> bool:
	return get_window().has_focus()

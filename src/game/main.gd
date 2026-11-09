extends Node2D
## Dono da suspensão e da troca diferida. A arena nunca herda ALWAYS.

const Encounter := preload("res://src/arenas/first_encounter.gd")
var arena_scene: PackedScene = preload("res://src/arenas/first_encounter.tscn")
var arena: Node2D
var _generation: int = 0
var _bindings: Array[Dictionary] = []
var pause_reason: String = "Pausa"
var _restarting: bool = false
var _confirming: bool = false
var _menu: CanvasLayer
var _overlay: Control
var _title: Label
var _continue: Button
var _restart: Button
var _cancel: Button
var _menu_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_menu()
	_bind_arena()


func _bind_arena() -> void:
	arena = get_child(0) as Node2D
	_generation += 1
	var adapter := arena.get_node("PlayerInput")
	_bind(adapter.suspension_requested, _suspend)
	_bind(adapter.pause_requested, _toggle_pause)
	if arena is Encounter:
		_bind(arena.finished, _on_finished.bind(arena.get_instance_id(), _generation))
		if arena.state != "running":
			_on_finished(arena.state, arena.get_instance_id(), _generation)
			return
	else:
		_bind(arena.get_node("Actors/Player").died, _on_died)
	if not adapter.focus_active:
		_suspend("Foco perdido — volte à janela para continuar")
	else:
		set_paused(false)


func _bind(event: Signal, callback: Callable) -> void:
	event.connect(callback)
	_bindings.append({"signal": event, "callback": callback})


func _on_finished(outcome: String, id: int, generation: int) -> void:
	if _restarting or generation != _generation or not is_instance_valid(arena) or arena.get_instance_id() != id:
		return
	pause_reason = {"completed": "Encontro concluído", "defeat": "Derrota · vida 0", "failed": "Encontro interrompido · reinicie"}.get(outcome, "Encontro interrompido · reinicie")
	if is_instance_valid(_overlay) and _overlay.is_inside_tree():
		set_paused(true)


func _ended() -> bool:
	return arena is Encounter and arena.state != "running"


func _current_player() -> Node:
	if not is_instance_valid(arena):
		return null
	var player := arena.get_node_or_null("Actors/Player")
	return player if is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion() else null


func _process(_delta: float) -> void:
	if _restarting or not get_tree().paused or not is_instance_valid(arena):
		return
	var disabled: bool = _current_player() == null or not arena.get_node("PlayerInput").focus_active
	if _continue.disabled != disabled:
		_continue.disabled = disabled
		if not disabled and _continue.visible:
			_continue.grab_focus()


func set_paused(value: bool) -> void:
	if _restarting or not is_instance_valid(arena):
		return
	var player := _current_player()
	var adapter := arena.get_node("PlayerInput")
	var unavailable: bool = player == null or player.health.dead
	if not value and (unavailable or not adapter.focus_active or _ended()):
		value = true
	if player != null:
		adapter.set_gameplay_enabled(not value)
		player.set_control_enabled(not value)
	else:
		adapter.detach_player()
	get_tree().paused = value
	_menu_buttons.clear()
	for device: int in adapter._read_connected_joypads():
		for button: int in [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			if adapter._read_joy_button_pressed(device, button):
				_menu_buttons[Vector2i(device, button)] = true
	arena.refresh_status()
	_overlay.visible = value
	_confirming = false
	_cancel.visible = false
	_continue.visible = not unavailable and not _ended()
	_continue.disabled = unavailable or not adapter.focus_active
	_restart.text = "Reiniciar encontro"
	_title.text = "%s · %s" % [pause_reason if value else "Pausa", ProjectSettings.get_setting("application/config/version", "")]
	if value:
		(_restart if unavailable or _ended() or _continue.disabled else _continue).grab_focus()


func _input(event: InputEvent) -> void:
	# Os bindings de jogo permanecem intactos. Navegação do menu aceita o ID real,
	# sem depender de bindings implícitos de controle das ações ui_* da engine.
	if not event is InputEventJoypadButton or not get_tree().paused or _restarting:
		return
	var action := "ui_accept" if event.button_index == JOY_BUTTON_A else "ui_up" if event.button_index == JOY_BUTTON_DPAD_UP else "ui_down" if event.button_index == JOY_BUTTON_DPAD_DOWN else ""
	if action.is_empty():
		return
	var key := Vector2i(event.device, event.button_index)
	var blocked := _menu_buttons.has(key)
	if not event.pressed:
		_menu_buttons.erase(key)
	elif not blocked:
		_menu_buttons[key] = true
	var forwarded := InputEventAction.new()
	forwarded.action = action
	forwarded.pressed = event.pressed
	get_viewport().set_input_as_handled()
	if not blocked or not event.pressed:
		get_viewport().push_input(forwarded, true)


func _toggle_pause() -> void:
	if _restarting:
		return
	pause_reason = "Pausa"
	set_paused(not get_tree().paused)


func _suspend(reason: String) -> void:
	if _restarting:
		return
	if arena is Encounter:
		arena.interrupt_actions()
	elif _current_player() != null:
		_current_player().interrupt_actions()
	pause_reason = reason
	set_paused(true)


func _on_died() -> void:
	pause_reason = "Tentativa encerrada · vida 0"
	set_paused(true)


func restart_lab() -> void:
	# Alias preservado para regressões que configuram arena_scene antes da árvore.
	restart_encounter()


func restart_encounter() -> void:
	if _restarting:
		return
	_restarting = true
	_generation += 1
	var old := arena
	if old is Encounter:
		old.shutdown()
	var player := _current_player()
	if player != null:
		old.get_node("PlayerInput").set_gameplay_enabled(false)
		player.set_control_enabled(false)
		player.interrupt_actions()
	old.process_mode = Node.PROCESS_MODE_DISABLED
	old.get_node("PlayerInput").detach_player()
	# Sinais não são suspensos pelo process_mode; desconectar antes da troca.
	for connection: Dictionary in _bindings:
		var event: Signal = connection.signal
		if is_instance_valid(event.get_object()) and event.is_connected(connection.callback):
			event.disconnect(connection.callback)
	_bindings.clear()
	_replace_arena.call_deferred()


func _replace_arena() -> void:
	if not is_inside_tree():
		_restarting = false
		return
	var old := arena
	remove_child(old)
	old.free()
	var lab := arena_scene.instantiate()
	add_child(lab)
	move_child(lab, 0)
	_restarting = false
	pause_reason = "Pausa"
	_bind_arena()


func _request_restart() -> void:
	var player := _current_player()
	if player == null or player.health.dead or _ended() or _confirming:
		restart_encounter()
		return
	_confirming = true
	_title.text = "Descartar tentativa atual?"
	_restart.text = "Confirmar reinício"
	_cancel.visible = true
	_cancel.grab_focus()


func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.name = "PauseMenu"
	_menu.layer = 20
	add_child(_menu)
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0.04, 0.09, 0.12, 0.92)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 500
	rows.add_theme_constant_override("separation", 18)
	center.add_child(rows)
	_title = Label.new()
	_title.name = "Reason"
	_title.add_theme_font_size_override("font_size", 25)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_title)
	_continue = _button(rows, "Continuar", func() -> void: set_paused(false))
	_restart = _button(rows, "Reiniciar encontro", _request_restart)
	_cancel = _button(rows, "Cancelar", func() -> void: set_paused(true))
	var help := Label.new()
	help.text = "Solte teclas e botões; neutralize os sticks ao continuar.\nTab / setas / direcional: selecionar · Enter / botão sul: confirmar"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 17)
	rows.add_child(help)
	_overlay.hide()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color("ffe2a1")
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

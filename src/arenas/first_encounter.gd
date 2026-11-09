extends Node2D
## Encontro autoral: registro completo antes de combate, resultado único por geração.
## Blockout areia/terracota e sombras azuladas; HUD recua para a luta nos pés.

signal finished(outcome: String)

const Enemy := preload("res://src/enemies/melee_chaser.gd")
@export var player: CharacterBody2D
@export var adapter: Node
@export var enemy_paths: Array[NodePath] = []
var state: String = "initializing"
var remaining: int:
	get: return _alive.size()
var _generation: int = 0
var _registered: Dictionary = {}
var _alive: Dictionary = {}
var _connections: Array[Dictionary] = []
var _closed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_generation += 1
	if not is_instance_valid(player) or not player.is_inside_tree() or not is_instance_valid(adapter) \
			or adapter.get("player") != player or enemy_paths.size() != 3:
		_finish("failed")
		return
	for path: NodePath in enemy_paths:
		var enemy := get_node_or_null(path) as Enemy
		if enemy == null or not enemy.is_inside_tree() or enemy.is_queued_for_deletion() \
				or enemy.health.dead or _registered.has(enemy.get_instance_id()):
			_finish("failed")
			return
		var id := enemy.get_instance_id()
		_registered[id] = weakref(enemy)
		_alive[id] = true
		if not enemy.set_target(player):
			_finish("failed")
			return
	# Todos os IDs já estão fixados. Callbacks não podem concluir registro parcial.
	for id: int in _registered:
		var enemy: Enemy = _registered[id].get_ref()
		_connect(enemy.died, _on_enemy_died.bind(id, _generation))
		_connect(enemy.tree_exiting, _on_enemy_exiting.bind(id, _generation))
	_connect(player.died, _on_player_died.bind(_generation))
	_connect(player.tree_exiting, _on_player_exiting.bind(_generation))
	state = "running"
	for id: int in _registered:
		_registered[id].get_ref().set_encounter_enabled(true)
	refresh_status()

func _connect(event: Signal, callback: Callable) -> void:
	event.connect(callback)
	_connections.append({"signal": event, "callback": callback})

func _on_enemy_died(id: int, generation: int) -> void:
	if _closed or generation != _generation or state != "running" or not _alive.has(id):
		return
	# Health atualiza vida antes de changed/died: empate reentrante não é vitória.
	if not is_instance_valid(player) or player.health.dead:
		_finish("defeat")
		return
	var enemy: Variant = _registered[id].get_ref()
	if not is_instance_valid(enemy) or not enemy.health.dead:
		return
	_alive.erase(id)
	if _alive.is_empty():
		_finish("completed")
	else:
		refresh_status()

func _on_enemy_exiting(id: int, generation: int) -> void:
	if not _closed and generation == _generation and state == "running" and _alive.has(id):
		_finish("failed")

func _on_player_died(generation: int) -> void:
	if generation == _generation:
		_finish("defeat")

func _on_player_exiting(generation: int) -> void:
	if generation == _generation:
		if is_instance_valid(adapter):
			adapter.detach_player()
		_finish("failed")

func _finish(outcome: String) -> void:
	if _closed or state in ["completed", "defeat", "failed"]:
		return
	state = outcome
	_stop_combat()
	refresh_status()
	finished.emit(outcome)

func interrupt_actions() -> void:
	if is_instance_valid(player):
		player.interrupt_actions()
	for reference: WeakRef in _registered.values():
		var enemy: Variant = reference.get_ref()
		if is_instance_valid(enemy):
			enemy.interrupt_actions()

func _stop_combat() -> void:
	if is_instance_valid(adapter):
		if is_instance_valid(adapter.get("player")):
			adapter.set_gameplay_enabled(false)
		else:
			adapter.detach_player()
	if is_instance_valid(player):
		player.set_control_enabled(false)
		player.interrupt_actions()
	for reference: WeakRef in _registered.values():
		var enemy: Variant = reference.get_ref()
		if is_instance_valid(enemy):
			enemy.set_encounter_enabled(false)

func shutdown() -> void:
	# Invalidação precede desconexão e remoção; sinais ignoram process_mode.
	_closed = true
	_generation += 1
	_stop_combat()
	if is_instance_valid(adapter):
		adapter.detach_player()
	for connection: Dictionary in _connections:
		var event: Signal = connection.signal
		if not event.is_null() and is_instance_valid(event.get_object()) and event.is_connected(connection.callback):
			event.disconnect(connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	shutdown()

func _process(_delta: float) -> void:
	refresh_status()

func refresh_status() -> void:
	if not is_instance_valid(player) or not is_instance_valid(adapter) or not has_node("HUD/Panel/Margin/Rows/Combat"):
		return
	var cooldown: float = player.action_state.cooldown_remaining
	$HUD/Panel/Margin/Rows/Title.text = "Primeiro encontro · %s" % ProjectSettings.get_setting("application/config/version", "")
	$HUD/Panel/Margin/Rows/Combat.text = "Vida %d/100 · %s · Inimigos %d/3" % [player.health.current,
		"Esquiva pronta" if cooldown <= 0.0 else "Esquiva %.1fs" % cooldown, remaining]
	$HUD/Panel/Margin/Rows/State.text = {"initializing": "Preparando encontro", "running": "Elimine os três perseguidores",
		"completed": "Encontro concluído", "defeat": "Derrota · tente novamente", "failed": "Encontro interrompido · reinicie"}[state]
	var paused := get_tree().paused
	$HUD.layer = 21 if paused else 1
	$HUD/Help.offset_top = -106.0 if paused else -56.0
	$HUD/Help/Margin/Rows/Instructions.text = (
		"Analógico esquerdo: mover · Analógico direito: mirar · Oeste: golpear · Sul: esquivar · Start: pausa"
		if adapter.active_device >= 0 else "WASD / setas: mover · Mouse: mirar · LMB: golpear · Espaço: esquivar · Esc: pausa")
	$HUD/Help/Margin/Rows/Recovery.text = "Evite o setor anunciado · Golpe fixa a direção ao iniciar" + (
		"\nFoco: %s · Mira: %s · Controle: %s\nAo voltar: solte teclas e botões; neutralize os sticks." % [
			"ativo" if adapter.focus_active else "perdido", "mouse" if adapter.aim_source == "mouse" else "analógico direito",
			"desconectado" if adapter.disconnected else str(adapter.active_device) if adapter.active_device >= 0 else "nenhum ativo"] if paused else "")

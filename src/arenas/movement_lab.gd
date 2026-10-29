extends Node2D
## Laboratório provisório: diagnóstico local, sem regras de combate.

@onready var _input: Node = $PlayerInput
@onready var _player: CharacterBody2D = $Actors/Player
@onready var _state: Label = $HUD/Panel/Margin/Rows/State
@onready var _marker: Node2D = $PositionMarker


func _process(_delta: float) -> void:
	var focus_text := "ativo" if _input.focus_active else "perdido — movimento parado"
	var device_text := "desconectado — teclado/mouse disponíveis" if _input.disconnected else (
		"ID %d" % _input.active_device if _input.active_device >= 0 else "nenhum ativo")
	_state.text = "Mira: %s   ·   Foco: %s\nControle: %s" % [
		"mouse" if _input.aim_source == "mouse" else "analógico direito", focus_text, device_text]
	_marker.position = _player.position

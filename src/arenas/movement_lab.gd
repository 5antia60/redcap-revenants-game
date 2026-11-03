extends Node2D
## Laboratório provisório: diagnóstico espacial e combate local, sem IA.

@onready var _input: Node = $PlayerInput
@onready var _player: CharacterBody2D = $Actors/Player
@onready var _state: Label = $HUD/Panel/Margin/Rows/State
@onready var _marker: Node2D = $PositionMarker


func _process(_delta: float) -> void:
	refresh_status()


func refresh_status() -> void:
	var focus_text := "ativo" if _input.focus_active else "perdido — movimento parado"
	var device_text := "desconectado — teclado/mouse disponíveis" if _input.disconnected else (
		"ID %d" % _input.active_device if _input.active_device >= 0 else "nenhum ativo")
	_state.text = "Mira (fonte): %s   ·   Foco: %s\nControle: %s" % [
		"mouse" if _input.aim_source == "mouse" else "analógico direito", focus_text, device_text]
	_marker.position = _player.position
	# Não deixar o rótulo flutuar na borda quando o chão da zona está fora da
	# câmera. Só apresentação: o relógio/query físicos continuam inalterados.
	var zone_floor: Rect2 = $DamageZone.get_global_transform_with_canvas() * $DamageZone.RECT
	$DamageZone.visible = get_viewport_rect().intersects(zone_floor)
	var cooldown: float = _player.action_state.cooldown_remaining
	$HUD/Panel/Margin/Rows/Title.text = "S2 · Blockout temporário — cassetete e esquiva · " + str(ProjectSettings.get_setting("application/config/version", ""))
	$HUD/Panel/Margin/Rows/Combat.text = "Vida %d/100 · %s · %s" % [_player.health.current,
		"Esquiva pronta" if cooldown <= 0 else "Esquiva %.2fs" % cooldown,
		["Repouso", "Preparação", "Golpe", "Recuperação", "Esquiva", "Morto"][_player.action_state.phase]]
	$HUD/Help/Margin/Rows/Instructions.text = (
		"Analógico esquerdo: mover · Analógico direito: mirar · Oeste: golpear · Sul: esquivar · Start: pausa"
		if _input.active_device >= 0 else
		"WASD / setas: mover · Mouse: mirar · LMB: golpear · Espaço: esquivar · Esc: pausa")
	var paused := get_tree().paused
	# A ajuda longa só se expande na pausa; fica acima do véu, sem invadir o menu.
	$HUD.layer = 21 if paused else 1
	$HUD/Help.offset_top = -106.0 if paused else -56.0
	$HUD/Help/Margin/Rows/Recovery.text = "Golpe fixa a direção ao iniciar · Esc / Start: pausa e ajuda completa" + (
		"\nAo voltar: solte teclas e botões; neutralize os sticks."
		+ "\nAnel = pés · ponto = diagnóstico · zona TREINO causa dano, não é inimigo" if paused else "")

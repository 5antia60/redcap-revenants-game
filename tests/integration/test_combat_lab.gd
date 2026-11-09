extends RefCounted
## Integração sobre Main real; participantes ficam congelados entre passos observados.

const MAIN := preload("res://tests/fixtures/s3_lab_main.gd")

class PhysicsJob extends Node:
	signal finished
	var job: Callable
	var completed: bool = false
	func _physics_process(_delta: float) -> void:
		set_physics_process(false)
		completed = job.call() == true
		finished.emit()

class FeedbackTicks extends Node:
	signal finished
	var player: Node
	var budget: int
	var observed: int = 0
	func _physics_process(_delta: float) -> void:
		observed += 1
		if observed == budget:
			player.set_physics_process(false)
			set_physics_process(false)
			finished.emit()

func _job(tree: SceneTree, callback: Callable) -> bool:
	var job := PhysicsJob.new()
	job.job = callback
	job.process_mode = Node.PROCESS_MODE_ALWAYS
	job.process_physics_priority = 50
	tree.root.add_child(job)
	await job.finished
	var completed := job.completed
	await tree.process_frame
	job.free()
	return completed

func run(tree: SceneTree, check: Callable) -> bool:
	var saved_pause := tree.paused
	tree.paused = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	tree.root.add_child(viewport)
	var main := MAIN.instantiate()
	main.child_entered_tree.connect(func(child: Node) -> void:
		if child.name == "MovementLab":
			child.ready.connect(func() -> void: _freeze(child)))
	viewport.add_child(main)
	var lab := main.get_node("MovementLab")
	var player := lab.get_node("Actors/Player")
	var adapter := lab.get_node("PlayerInput")
	_freeze(lab)
	var ready := main.has_method("set_paused") and main.has_method("restart_lab") and player.has_method("queue_actions")
	check.call(ready, "S2: Main real deve ligar combate, pausa e reinício")
	if not ready:
		viewport.free()
		tree.paused = saved_pause
		return false
	adapter.set_focus_active(true)
	main.set_paused(false)
	check.call(await _hud_cases(tree, lab, check) == true, "S2: HUD preserva descoberta espacial e ajuda dos dispositivos")
	check.call(main.process_mode == Node.PROCESS_MODE_ALWAYS and lab.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"S2: Main ALWAYS não propaga processamento à arena")
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	check.call(version in ["0.2.0-dev", "0.2.0"]
		and lab.get_node("HUD/Panel/Margin/Rows/Title").text.ends_with(version),
		"S2: consumidor real mostra versão configurada exata, inclusive sufixo de desenvolvimento")
	main.set_paused(true)
	check.call(main._title.text.ends_with(version), "S2: pausa identifica versão configurada exata")
	main.set_paused(false)
	check.call(lab.get_node("Actors").y_sort_enabled, "S2: alvos reais compartilham Y-sort dos pés")
	for target_name: String in ["Target1", "Target2", "Target3"]:
		var target := lab.get_node_or_null("Actors/" + target_name)
		check.call(target is StaticBody2D and target.health.current == 30, "S2: alvo real com vida30: " + target_name)
	var target := lab.get_node("Actors/Target1")
	player.position = target.position - Vector2(45, 0)
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	await tree.physics_frame
	player.queue_actions(true, false)
	player._physics_process(0.04)
	var serial_before: int = player.action_state.attack_serial
	for amount: int in [0, -1, 1001]:
		check.call(not player.receive_hit(amount), "S2: corpo rejeita dano inválido")
	check.call(player.action_state.phase == 1 and target.health.current == 30 and not player.active_snapshot,
		"S2: preparação não aplica dano nem desenha setor ativo")
	player.apply_intent(Vector2.ZERO, Vector2.LEFT)
	player._physics_process(0.20)
	check.call(player.action_state.phase == 3 and player.active_snapshot and target.health.current == 20,
		"S2: janela inteira atravessada resolve dos pés com direção capturada, mesmo em recuperação")
	check.call(target.reaction_remaining > 0.0, "S2: reação visual acompanha vida mesmo sem áudio")
	player._physics_process(0.0)
	player._physics_process(NAN)
	check.call(target.health.current == 20 and not player.active_snapshot, "S2: zero/inválido não reciclam snapshot ativo")
	player._physics_process(0.04)
	player.queue_actions(true, true)
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	var start: Vector2 = player.position
	player._physics_process(0.15)
	check.call(player.action_state.phase == 0 and not player.action_state.invulnerable,
		"S2: esquiva prevalece e termina sem proteção no limite0,15")
	# move_and_slide usa o delta nativo: distância longa é exercitada em ticks reais abaixo.
	check.call(player.position.x > start.x, "S2: esquiva usa corpo nativo")
	var cooldown: float = player.action_state.cooldown_remaining
	main.set_paused(true)
	player.queue_actions(true, true)
	var life: int = player.health.current
	check.call(not player.receive_hit(25), "S2: pausa recusa dano")
	await tree.process_frame
	check.call(player.action_state.cooldown_remaining == cooldown and player.health.current == life,
		"S2: pausa conserva custo e vida")
	main.set_paused(false)
	player.interrupt_actions()
	check.call(player.receive_hit(100) and player.action_state.phase == 5,
		"S2: morte marca DEAD antes dos callbacks")
	check.call(not player.receive_hit(25), "S2: morte não recebe outro dano")
	player.queue_actions(true, true)
	player._physics_process(0.20)
	check.call(player.action_state.phase == 5 and player.action_state.attack_serial == serial_before,
		"S2: morto não aceita ataque/esquiva nem avança ação")
	var connections := Input.joy_connection_changed.get_connections().size()
	for iteration in range(3):
		var old_id := lab.get_instance_id()
		main.restart_lab()
		main.restart_lab()
		check.call(not player.receive_hit(25), "S2: arena antiga fica inelegível antes do deferred")
		await tree.process_frame
		lab = main.get_node("MovementLab")
		_freeze(lab)
		player = lab.get_node("Actors/Player")
		adapter = lab.get_node("PlayerInput")
		adapter.set_focus_active(true)
		main.set_paused(false)
		check.call(lab.get_instance_id() != old_id and main.get_child_count() == 2,
			"S2: dois pedidos recriam exatamente uma arena")
		check.call(player.health.current == 100 and player.action_state.cooldown_remaining == 0.0,
			"S2: reinício recria vida/custos")
		check.call(Input.joy_connection_changed.get_connections().size() == connections,
			"S2: três reinícios não acumulam conexões")
	check.call(await _zone_cases(tree, lab, player, check) == true, "S2: zona física deve concluir")
	check.call(await _body_cases(tree, main, lab, player, check) == true, "S2: corpo nativo e suspensão devem concluir")
	check.call(await _boundary_cases(tree, main, check) == true, "S2: travessias da proteção e do dash devem concluir")
	check.call(_clock_cases(check) == true, "S2: relógio de produção deve concluir")
	check.call(await _feedback_cases(tree, main, check) == true, "S2-feedback: apresentação aceita e ciclo de vida devem concluir")
	viewport.free()
	tree.paused = saved_pause
	return true

func _hud_cases(tree: SceneTree, lab: Node, check: Callable) -> bool:
	lab.refresh_status()
	await tree.process_frame
	lab.get_node("Actors/Player/Camera2D").force_update_scroll()
	for sample: Array in [["Panel/Margin/Rows/Title", 22], ["Panel/Margin/Rows/State", 17],
		["Panel/Margin/Rows/Combat", 18], ["Help/Margin/Rows/Instructions", 16], ["Help/Margin/Rows/Recovery", 16]]:
		check.call(lab.get_node("HUD/" + sample[0]).get_theme_font_size("font_size") >= sample[1],
			"S2: reflow não diminui fonte para ocultar sobreposição: " + sample[0])
	for target_name: String in ["Target1", "Target2", "Target3"]:
		var target := lab.get_node("Actors/" + target_name)
		var proof: Rect2 = target.get_global_transform_with_canvas() * Rect2(-28, -64, 56, 76)
		for panel_name: String in ["Panel", "Help"]:
			check.call(not lab.get_node("HUD/" + panel_name).get_global_rect().intersects(proof),
				"S2: HUD não cobre alvo/vida no nascimento: " + target_name + "/" + panel_name)
	var zone := lab.get_node("DamageZone")
	var zone_proof: Rect2 = zone.get_global_transform_with_canvas() * Rect2(-60, -70, 160, 110)
	for panel_name: String in ["Panel", "Help"]:
		check.call(not lab.get_node("HUD/" + panel_name).get_global_rect().intersects(zone_proof),
			"S2: HUD não cobre zona/rótulo no nascimento: %s panel=%s prova=%s" % [panel_name, lab.get_node("HUD/" + panel_name).get_global_rect(), zone_proof])
	var instructions := lab.get_node("HUD/Help/Margin/Rows/Instructions")
	var recovery := lab.get_node("HUD/Help/Margin/Rows/Recovery")
	check.call(recovery.text.contains("Golpe fixa a direção ao iniciar")
		and lab.get_node("HUD/Panel/Margin/Rows/State").text.contains("fonte"),
		"S2: direção capturada do golpe não se confunde com fonte da mira")
	check.call(instructions.text.contains("WASD") and instructions.text.contains("Mouse")
		and instructions.text.contains("LMB") and instructions.text.contains("Espaço") and instructions.text.contains("Esc"),
		"S2: ajuda descreve movimento/mira/ações de teclado e mouse")
	lab.get_node("PlayerInput").active_device = 37
	lab.refresh_status()
	check.call(instructions.text.contains("Analógico esquerdo") and instructions.text.contains("Analógico direito")
		and instructions.text.contains("Oeste") and instructions.text.contains("Sul") and instructions.text.contains("Start"),
		"S2: ajuda do controle selecionado descreve dois analógicos e ações")
	lab.get_node("PlayerInput").active_device = -1
	lab.refresh_status()
	var player := lab.get_node("Actors/Player")
	var start: Vector2 = player.position
	player.position = Vector2(695, 260)
	player.get_node("Camera2D").force_update_scroll()
	lab.refresh_status()
	check.call(not zone.visible, "S2: zona fora do enquadramento não deixa rótulo solto/cortado sobre a ajuda")
	player.position = start
	player.get_node("Camera2D").force_update_scroll()
	lab.refresh_status()
	check.call(zone.visible, "S2: zona volta a ser visível com seu chão enquadrado no nascimento")
	return true


func _boundary_cases(tree: SceneTree, main: Node, check: Callable) -> bool:
	for sample: Dictionary in [
		{"first": 0.09, "last": 0.01, "offset": 0.0, "life": 75, "protected": false},
		{"first": 0.09, "last": 0.0000005, "offset": 0.0, "life": 100, "protected": true},
		{"first": 0.09, "last": 0.02, "offset": 86.0, "life": 75, "protected": false},
		{"first": 0.09, "last": 0.02, "offset": -56.0, "life": 100, "protected": false},
		{"first": 0.14, "last": 0.02, "offset": 0.0, "life": 75, "protected": false}]:
		main.restart_lab()
		await tree.process_frame
		var lab := main.get_node("MovementLab")
		_freeze(lab)
		var player := lab.get_node("Actors/Player")
		var adapter := lab.get_node("PlayerInput")
		var zone := lab.get_node("DamageZone")
		adapter.set_focus_active(true)
		main.set_paused(false)
		player.audio_enabled = false
		player.position = zone.position + Vector2(sample.offset, 0)
		player.apply_intent(Vector2.ZERO, Vector2.LEFT)
		player.queue_actions(false, true)
		check.call(await _job(tree, func() -> bool:
			player._physics_process(sample.first)
			return true), "S2: primeiro trecho físico antes da consulta")
		zone.advance_clock(0.34)
		var start: Vector2 = player.position
		if sample.offset == 86.0:
			check.call(start.x > 1390.0, "S2: entrada começa sem contato, além da borda1320+60 e raio10")
		elif sample.offset == -56.0:
			check.call(start.x > 1250.0 and start.x < 1260.0, "S2: saída começa com a base sobreposta à borda esquerda")
		check.call(await _job(tree, func() -> bool:
			player._physics_process(sample.last)
			zone._physics_process(0.02)
			return true), "S2: contribuição final do corpo precede query da zona")
		if sample.offset == 86.0:
			check.call(player.position.x < 1380.0 and zone._attempted.has(player.get_instance_id()),
				"S2: entrada no mesmo callback consulta base final, não broadphase anterior")
		elif sample.offset == -56.0:
			check.call(player.position.x < 1250.0 and zone._attempted.is_empty(),
				"S2: saída no mesmo callback não recebe dano pelo contato anterior")
		check.call(player.health.current == sample.life and player.action_state.invulnerable == sample.protected,
			"S2: dano e contorno amostram proteção final: %s; vida=%s proteção=%s pés=%s" % [sample, player.health.current, player.action_state.invulnerable, player.position])
		var distance := 6.666667 if sample.first == 0.14 else 13.333333
		check.call(absf(start.x - player.position.x - distance) < 0.02,
			"S2: último trecho0,15 pondera somente duração efetivamente percorrida no tick nativo")
	return true

func _clock_cases(check: Callable) -> bool:
	var zone = load("res://src/arenas/damage_zone.gd").new()
	var before: Dictionary = zone.snapshot.duplicate()
	for delta: float in [-1.0, NAN, INF, 10.01]:
		check.call(zone.advance_clock(delta).is_empty() and zone.snapshot == before, "S2: relógio recusa delta inválido sem mutação")
	check.call(zone.advance_clock(0.0) == before, "S2: relógio zero preserva snapshot")
	zone.advance_clock(0.30)
	var last: Dictionary = zone.advance_clock(3.0)
	check.call(last.pulse_serial == 2 and last.danger_this_step and last.phase == "warning",
		"S2:0,30+3 considera somente pulso2 completo, não pulso3 futuro")
	zone.free()
	zone = load("res://src/arenas/damage_zone.gd").new()
	check.call(not zone.advance_clock(0.35).danger_this_step, "S2: começo exato de janela não inventa duração positiva")
	check.call(zone.advance_clock(0.00000001).danger_this_step, "S2: janela positiva mínima não desaparece por arredondamento")
	zone.free()
	return true

func _body_cases(tree: SceneTree, main: Node, lab: Node, player: Node, check: Callable) -> bool:
	player.audio_enabled = false
	player.position = Vector2(800, 500)
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	player.queue_actions(false, true)
	var start: Vector2 = player.position
	for tick in range(9):
		check.call(await _job(tree, func() -> bool:
			player._physics_process(1.0 / 60.0)
			return true), "S2: tick nativo de esquiva livre")
	check.call(absf(player.position.x - start.x - 120.0) < 0.02 and absf(player.position.y - start.y) < 0.01,
		"S2: nove ticks nativos percorrem120, sem trecho final extra")
	var endpoint: Vector2 = player.position
	player._physics_process(0.0)
	player._physics_process(11.0)
	check.call(player.position == endpoint, "S2: zero/inválido não reutilizam último trecho da esquiva")
	player._physics_process(0.60)
	player.position = Vector2(25, 500)
	player.apply_intent(Vector2.LEFT, Vector2.RIGHT)
	player.queue_actions(false, true)
	for tick in range(9):
		check.call(await _job(tree, func() -> bool:
			player._physics_process(1.0 / 60.0)
			return true), "S2: tick nativo contra parede")
	check.call(player.position.x >= 9.5 and player.position.x < 10.5,
		"S2: movimento escolhe direção sobre mira e parede encurta esquiva sem atravessar")
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	player._physics_process(0.60)
	for phase: int in [0, 1, 2, 3, 4]:
		player.interrupt_actions()
		player._physics_process(0.75)
		if phase in [1, 2, 3]:
			player.queue_actions(true, false)
			player._physics_process(0.01 if phase == 1 else 0.06 if phase == 2 else 0.15)
		elif phase == 4:
			player.queue_actions(false, true)
			player._physics_process(0.01)
		check.call(player.action_state.phase == phase, "S2: preparar fase real para pausa")
		var cost: float = player.action_state.cooldown_remaining
		var zone_time: float = lab.get_node("DamageZone")._time
		main.set_paused(true)
		check.call(await _job(tree, func() -> bool:
			player.queue_actions(true, true)
			player._physics_process(0.20)
			lab.get_node("DamageZone")._physics_process(0.20)
			return true), "S2: observar suspensão em cada fase")
		check.call(player.action_state.phase == phase and player.action_state.cooldown_remaining == cost
			and lab.get_node("DamageZone")._time == zone_time, "S2: pausa congela fase/custo/zona sem interrupt manual")
		main.set_paused(false)
		check.call(player.action_state.phase == phase, "S2: retomar conserva fase sem nova pressão")
	player.interrupt_actions()
	player._physics_process(0.75)
	player.position = lab.get_node("DamageZone").position
	player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
	check.call(await _job(tree, func() -> bool: return true), "S2: registrar jogador na zona")
	check.call(await _job(tree, func() -> bool: return true), "S2: sincronizar jogador antes de proteção")
	# Instância nova do relógio, com query física de produção sobre o mesmo retângulo.
	var zone = load("res://src/arenas/damage_zone.gd").new()
	zone.position = lab.get_node("DamageZone").position
	zone.player = player
	lab.add_child(zone)
	zone.set_physics_process(false)
	zone.advance_clock(0.34)
	player.queue_actions(false, true)
	check.call(await _job(tree, func() -> bool:
		player._physics_process(0.09)
		zone._physics_process(0.02)
		return true), "S2: corpo primeiro e pulso depois, ainda protegido")
	var life: int = player.health.current
	check.call(player.action_state.invulnerable and life == 50, "S2: proteção final recusa pulso real e mantém contorno")
	check.call(await _job(tree, func() -> bool:
		player._physics_process(0.02)
		zone._physics_process(0.02)
		return true), "S2: cruzar fim0,10 no mesmo pulso")
	check.call(not player.action_state.invulnerable and player.health.current == life,
		"S2: contorno termina no fim0,10; tentativa recusada já consumiu pulso")
	zone.advance_clock(0.96)
	check.call(await _job(tree, func() -> bool:
		player._physics_process(0.05)
		zone._physics_process(0.02)
		return true), "S2: cruzar fim do dash e novo pulso")
	check.call(player.action_state.phase == 0 and not player.action_state.invulnerable and player.health.current == 25,
		"S2: fim0,15 e novo pulso usam posição/proteção finais sem iframe prolongado")
	zone.free()
	return true

func _zone_cases(tree: SceneTree, lab: Node, player: Node, check: Callable) -> bool:
	var zone := lab.get_node("DamageZone")
	check.call(zone.process_physics_priority > player.process_physics_priority, "S2: zona observa pés/proteção finais")
	player.position = zone.position
	check.call(await _job(tree, func() -> bool: return true), "S2: sincronizar posição final na física")
	check.call(await _job(tree, func() -> bool: return true), "S2: registrar retângulo e corpo finais")
	zone.advance_clock(0.30)
	check.call(await _job(tree, func() -> bool:
		zone._physics_process(0.20)
		return true), "S2: resolver perigo dentro do tick físico")
	check.call(zone.snapshot.pulse_serial == 0 and zone.snapshot.danger_this_step and zone.snapshot.phase == "rest",
		"S2:0,30+0,20 publica perigo atravessado e pulso0")
	check.call(player.health.current == 75, "S2: retângulo real aplica25 uma vez")
	zone._physics_process(0.0)
	zone._physics_process(-1.0)
	check.call(player.health.current == 75, "S2: delta zero/inválido não resolve zona")
	zone.advance_clock(0.80)
	zone._physics_process(3.0)
	check.call(zone.snapshot.pulse_serial == 3 and player.health.current == 50,
		"S2: vários ciclos resolvem somente último pulso, não rajada")
	return true

func _freeze(node: Node) -> void:
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)


func _numbers(player: Node) -> Array[String]:
	var result: Array[String] = []
	for child: Node in player.get_children():
		if child is Label and str(child.name).begins_with("DamageNumber") and child.visible:
			result.append(child.text)
	return result


func _fresh(tree: SceneTree, main: Node) -> Node:
	main.restart_lab()
	await tree.process_frame
	var lab := main.get_node("MovementLab")
	_freeze(lab)
	lab.get_node("PlayerInput").set_focus_active(true)
	main.set_paused(false)
	lab.get_node("Actors/Player").audio_enabled = false
	return lab


func _native_feedback_ticks(tree: SceneTree, player: Node, budget: int) -> int:
	var observer := FeedbackTicks.new()
	observer.player = player
	observer.budget = budget
	observer.process_physics_priority = 20
	tree.root.add_child(observer)
	player.set_physics_process(true)
	await observer.finished
	var observed := observer.observed
	await tree.process_frame
	observer.free()
	return observed


func _feedback_cases(tree: SceneTree, main: Node, check: Callable) -> bool:
	# Quebras detectadas: zona sobre atores; número fixo/solicitado; efeito antes
	# da aceitação; relógio estendido; fila ilimitada; publicação após callback.
	var lab := await _fresh(tree, main)
	var player := lab.get_node("Actors/Player")
	var zone := lab.get_node("DamageZone")
	check.call(zone.get_index() < lab.get_node("Actors").get_index() and zone.z_index == 0
		and player.z_index == 0 and lab.get_node("Actors").y_sort_enabled,
		"S2-feedback: chão precede atores sem elevar jogador nem quebrar Y-sort")
	check.call(lab.get_node("PlayerInput").process_physics_priority < player.process_physics_priority
		and player.process_physics_priority < zone.process_physics_priority,
		"S2-feedback: ordem visual não modifica adaptador/corpo/zona físicos")
	player.position = zone.position
	check.call(await _job(tree, func() -> bool:
		player._physics_process(1.0 / 60.0)
		zone._physics_process(0.36)
		return true), "S2-feedback: recepção da zona no processamento físico real")
	check.call(player.health.current == 75 and _numbers(player) == ["−25"],
		"S2-feedback: pulso aceito100→75 publica perda25 no corpo dentro da zona")
	check.call(is_equal_approx(player.reaction_remaining, 0.20), "S2-feedback: marca corporal inicia0,20s")
	check.call(player.receive_hit(7) and player.health.current == 68 and _numbers(player) == ["−25", "−7"],
		"S2-feedback: segundo dano tem número próprio, não texto25 nem soma")
	check.call(player.receive_hit(3) and _numbers(player) == ["−3", "−7"],
		"S2-feedback: terceiro dano substitui somente slot mais antigo")
	var labels := 0
	for child: Node in player.get_children():
		if child is Label and str(child.name).begins_with("DamageNumber"):
			labels += 1
	check.call(labels == 2, "S2-feedback: dois slots fixos, sem armazenamento de nós crescente")
	var phase: int = player.action_state.phase
	for amount: int in [0, -1, 1001]:
		check.call(not player.receive_hit(amount) and _numbers(player) == ["−3", "−7"],
			"S2-feedback: dano inválido não publica nem troca slot")
	main.set_paused(true)
	var reaction: float = player.reaction_remaining
	check.call(not player.receive_hit(9), "S2-feedback: pausa recusa tentativa")
	player._physics_process(0.4)
	await tree.process_frame
	check.call(player.reaction_remaining == reaction and _numbers(player) == ["−3", "−7"],
		"S2-feedback: pausa congela efeitos existentes")
	main.set_paused(false)
	check.call(_numbers(player) == ["−3", "−7"] and player.action_state.phase == phase,
		"S2-feedback: retorno não cria evento nem muda fase")
	for tick in range(12):
		check.call(await _job(tree, func() -> bool:
			player._physics_process(1.0 / 60.0)
			return true), "S2-feedback: tick corporal de expiração")
	check.call(player.reaction_remaining == 0.0 and _numbers(player) == ["−3", "−7"],
		"S2-feedback: marca acaba0,20s, números permanecem")
	for tick in range(24):
		await _job(tree, func() -> bool:
			player._physics_process(1.0 / 60.0)
			return true)
	check.call(_numbers(player).is_empty() and player.health.current == 65,
		"S2-feedback: números acabam0,60s sem novo dano, iframe ou fila atrasada")
	for amount: int in [0, -1, 1001]:
		check.call(not player.receive_hit(amount) and _numbers(player).is_empty() and player.reaction_remaining == 0.0,
			"S2-feedback: inválido não inicia efeito numa apresentação vazia")
	player.queue_actions(false, true)
	await _job(tree, func() -> bool:
		player._physics_process(0.04)
		return true)
	check.call(player.action_state.invulnerable and not player.receive_hit(25)
		and _numbers(player).is_empty() and player.reaction_remaining == 0.0,
		"S2-feedback: proteção recusa dano sem marca/número")
	player.interrupt_actions()
	check.call(player.receive_hit(60) and player.health.current == 5 and _numbers(player) == ["−60"],
		"S2-feedback: sobrevida limitada ainda mostra perda efetiva")
	check.call(player.receive_hit(25) and player.health.current == 0 and _numbers(player).is_empty()
		and player.reaction_remaining == 0.0 and not player.receive_hit(1),
		"S2-feedback: sobreletal limita vida, morte limpa efeitos sem prometer25 de perda")
	lab = await _fresh(tree, main)
	player = lab.get_node("Actors/Player")
	check.call(_numbers(player).is_empty() and player.reaction_remaining == 0.0, "S2-feedback: reinício sem resíduos")
	# Health emite changed sincronamente. Dano aninhado não integra a perda externa.
	var entered := [false]
	player.health.changed.connect(func(_life: int, _maximum: int) -> void:
		if not entered[0]:
			entered[0] = true
			player.receive_hit(7))
	check.call(player.receive_hit(25) and player.health.current == 68 and _numbers(player) == ["−7", "−25"],
		"S2-feedback: callback reentrante não transforma25 em32")
	check.call(player.receive_hit(3) and _numbers(player) == ["−7", "−3"],
		"S2-feedback: ordem causal, não ordem de retorno, define slot mais antigo")
	lab = await _fresh(tree, main)
	player = lab.get_node("Actors/Player")
	var depth := [0]
	player.health.changed.connect(func(_life: int, _maximum: int) -> void:
		if depth[0] < 2:
			depth[0] += 1
			player.receive_hit(7 if depth[0] == 1 else 3))
	check.call(player.receive_hit(25) and player.health.current == 65 and _numbers(player) == ["−3", "−7"],
		"S2-feedback: três eventos reentrantes retêm apenas dois mais recentes, sem publicar25 atrasado")
	check.call(player.receive_hit(2) and _numbers(player) == ["−3", "−2"],
		"S2-feedback: próximo evento substitui7, não o evento3 mais recente")
	# Agora o próprio callback do jogador é agendado pela engine, sem chamada
	# manual: efeitos têm prazos independentes e não estendem proteção/custos.
	lab = await _fresh(tree, main)
	player = lab.get_node("Actors/Player")
	player.position = Vector2(800, 500)
	check.call(player.receive_hit(25), "S2-feedback: preparar relógio nativo")
	check.call(await _native_feedback_ticks(tree, player, 6) == 6, "S2-feedback: seis callbacks reais sem tick extra")
	check.call(player.receive_hit(7), "S2-feedback: dano próximo após0,10s")
	check.call(await _native_feedback_ticks(tree, player, 6) == 6 and player.reaction_remaining > 0.09,
		"S2-feedback: segundo evento reinicia marca sem reiniciar primeiro número")
	check.call(await _native_feedback_ticks(tree, player, 23) == 23 and _numbers(player) == ["−25", "−7"],
		"S2-feedback: primeiro número existe até tick35")
	check.call(await _native_feedback_ticks(tree, player, 1) == 1 and _numbers(player) == ["−7"],
		"S2-feedback: tick36 expira só primeiro número")
	check.call(await _native_feedback_ticks(tree, player, 6) == 6 and _numbers(player).is_empty()
		and player.reaction_remaining == 0.0 and player.health.current == 68 and not player.action_state.invulnerable,
		"S2-feedback: segundo expira no próprio prazo sem proteção/dano extra")
	check.call(player.receive_hit(7), "S2-feedback: preparar resíduo antes do reinício")
	main.restart_lab()
	check.call(_numbers(player).is_empty() and player.reaction_remaining == 0.0 and not player.receive_hit(25),
		"S2-feedback: reinício limpa arena antiga antes da substituição diferida")
	await tree.process_frame
	lab = await _fresh(tree, main)
	player = lab.get_node("Actors/Player")
	player.health.changed.connect(func(_life: int, _maximum: int) -> void: player.set_control_enabled(true))
	check.call(player.receive_hit(25) and _numbers(player) == ["−25"],
		"S2-feedback: reafirmar controle já habilitado não é suspensão nem apaga evento aceito")
	for callback_kind: String in ["pause", "pause-return", "restart", "death", "disable", "replace-health"]:
		lab = await _fresh(tree, main)
		player = lab.get_node("Actors/Player")
		var original_health: RefCounted = player.health
		var fired := [false]
		original_health.changed.connect(func(_life: int, _maximum: int) -> void:
			if fired[0]:
				return
			fired[0] = true
			if callback_kind == "pause":
				main.set_paused(true)
			elif callback_kind == "pause-return":
				main.set_paused(true)
				main.set_paused(false)
			elif callback_kind == "restart":
				main.restart_lab()
			elif callback_kind == "death":
				player.receive_hit(100)
			elif callback_kind == "disable":
				player.set_control_enabled(false)
			elif callback_kind == "replace-health":
				player.health = load("res://src/combat/health.gd").new())
		check.call(player.receive_hit(25) and original_health.current == (0 if callback_kind == "death" else 75),
			"S2-feedback: callback não muda retorno da perda aceita: " + callback_kind)
		check.call(_numbers(player).is_empty() and player.reaction_remaining == 0.0,
			"S2-feedback: callback invalida publicação tardia: " + callback_kind)
		if callback_kind == "restart":
			await tree.process_frame
			player = main.get_node("MovementLab/Actors/Player")
			check.call(player.health.current == 100 and _numbers(player).is_empty(),
				"S2-feedback: arena nova não recebe evento antigo")
	return true

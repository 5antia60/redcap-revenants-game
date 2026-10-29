extends RefCounted
## Detecta perda de janelas atravessadas, proteção atrasada e reembolso de recarga.

const POLICY_PATH := "res://src/player/action_state.gd"


func run(_tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(POLICY_PATH), "S2: regra local de ação deve existir")
	if not ResourceLoader.exists(POLICY_PATH):
		return false
	var script := load(POLICY_PATH) as GDScript
	check.call(script != null and script.can_instantiate(), "ação deve carregar e instanciar")
	if script == null or not script.can_instantiate():
		return false
	var state = script.new()
	check.call(state is RefCounted, "ação deve ser RefCounted local")
	if not state is RefCounted:
		return false
	for method: String in ["try_attack", "try_dodge", "advance", "interrupt", "mark_dead"]:
		check.call(state.has_method(method), "ação deve oferecer: " + method)
		if not state.has_method(method):
			return false
	check.call(_test_attack(script, check) == true, "subteste de ataque deve concluir")
	check.call(_test_traversal(script, check) == true, "subteste de travessia deve concluir")
	check.call(_test_dodge(script, check) == true, "subteste de esquiva deve concluir")
	check.call(_test_invalid(script, check) == true, "subteste de entradas inválidas deve concluir")
	check.call(_test_clock_edges(script, check) == true, "subteste de tolerância temporal deve concluir")
	check.call(_test_interrupt_and_death(script, check) == true,
		"subteste de interrupção e morte deve concluir")
	return true


func _test_attack(script: GDScript, check: Callable) -> bool:
	var state = script.new()
	check.call(state.phase == script.IDLE and state.attack_serial == 0,
		"instância inicia em repouso com serial zero")
	check.call(state.attack_direction == Vector2.RIGHT and state.dodge_direction == Vector2.RIGHT,
		"direções iniciais apontam à direita")
	check.call(not state.active_this_step and not state.invulnerable
		and state.dodge_seconds_this_step == 0.0 and state.cooldown_remaining == 0.0,
		"saídas temporais iniciais são neutras")
	check.call(state.try_attack(Vector2(0, -3)), "repouso aceita ataque")
	check.call(state.phase == script.WINDUP and state.attack_serial == 1
		and state.attack_direction == Vector2.UP, "ataque fixa direção unitária e serial")
	check.call(not state.try_attack(Vector2.LEFT) and not state.try_dodge(Vector2.LEFT),
		"preparação recusa ataque e esquiva")
	check.call(state.attack_serial == 1 and state.attack_direction == Vector2.UP,
		"pedido rejeitado não altera identidade ou direção")
	check.call(state.advance(0.049) and state.phase == script.WINDUP
		and not state.active_this_step, "antes de 0,05 não há janela ativa")
	check.call(state.advance(0.001) and state.phase == script.ACTIVE
		and not state.active_this_step, "chegar exatamente a 0,05 não percorre duração ativa")
	check.call(not state.try_attack(Vector2.LEFT) and not state.try_dodge(Vector2.LEFT),
		"janela ativa não aceita cancelamentos")
	check.call(state.advance(0.08) and state.phase == script.RECOVERY and state.active_this_step,
		"0,08 de janela ativa termina em recuperação sem perder snapshot")
	check.call(not state.try_attack(Vector2.LEFT), "recuperação recusa novo ataque")
	check.call(state.advance(0.14) and state.phase == script.IDLE and not state.active_this_step,
		"recuperação termina aos 0,27 sem tick adicional nem comando enfileirado")
	check.call(state.attack_serial == 1 and state.attack_direction == Vector2.UP,
		"avanços e consultas não criam outro ataque")
	check.call(state.try_attack(Vector2.LEFT) and state.attack_serial == 2
		and state.attack_direction == Vector2.LEFT, "nova pressão aceita outro serial e direção")
	var fresh = script.new()
	check.call(fresh.phase == script.IDLE and fresh.attack_serial == 0
		and fresh.attack_direction == Vector2.RIGHT, "novo atacante não herda estado")
	check.call(fresh.get_instance_id() != state.get_instance_id(),
		"atacantes recriados têm identidade de instância distinta")
	return true


func _test_traversal(script: GDScript, check: Callable) -> bool:
	for sample: Array in [[0.04, script.WINDUP, false], [0.05, script.ACTIVE, false],
		[0.0500005, script.ACTIVE, true], [0.06, script.ACTIVE, true], [0.13, script.RECOVERY, true],
		[0.20, script.RECOVERY, true], [0.27, script.IDLE, true], [10.0, script.IDLE, true]]:
		var state = script.new()
		check.call(state.try_attack(Vector2.RIGHT), "preparar ataque para travessia")
		check.call(state.advance(sample[0]), "delta suportado deve ser aceito")
		check.call(state.phase == sample[1] and state.active_this_step == sample[2],
			"snapshot da janela atravessada com delta %.7f" % sample[0])
		check.call(state.advance(0.01) and state.active_this_step == (sample[0] >= 0.05 and sample[0] < 0.13),
			"snapshot não fica retido no próximo passo positivo")
	var remainder = script.new()
	remainder.try_attack(Vector2.RIGHT)
	check.call(remainder.advance(0.2699995) and remainder.phase == script.IDLE,
		"resto de recuperação de meio microssegundo normaliza a zero")
	var ticks = script.new()
	ticks.try_attack(Vector2.RIGHT)
	for index: int in range(27):
		check.call(ticks.advance(0.01), "passo fracionado de ataque aceito")
	check.call(ticks.phase == script.IDLE, "27 passos de 0,01 não deixam tick residual")
	return true


func _test_dodge(script: GDScript, check: Callable) -> bool:
	var state = script.new()
	check.call(state.try_dodge(Vector2(3, 4)), "repouso aceita esquiva antes de ataque simultâneo")
	check.call(not state.try_attack(Vector2.UP), "chamador prioriza esquiva; ataque subsequente é descartado")
	check.call(state.phase == script.DODGE and state.invulnerable
		and state.dodge_direction.is_equal_approx(Vector2(0.6, 0.8))
		and state.cooldown_remaining == 0.75 and state.dodge_seconds_this_step == 0.0,
		"esquiva fixa direção, proteção inicial e custo desde a aceitação")
	check.call(state.advance(0.09) and state.invulnerable
		and is_equal_approx(state.dodge_seconds_this_step, 0.09), "proteção existe antes de 0,10")
	check.call(not state.try_dodge(Vector2.LEFT) and not state.try_attack(Vector2.UP),
		"esquiva não encadeia ações")
	check.call(state.advance(0.01) and not state.invulnerable and state.phase == script.DODGE,
		"proteção expira no snapshot final de 0,10 sem tick extra")
	check.call(state.advance(0.04) and not state.invulnerable, "último trecho da esquiva não protege")
	check.call(state.advance(0.03) and state.phase == script.IDLE and not state.invulnerable
		and is_equal_approx(state.dodge_seconds_this_step, 0.01),
		"passo além de 0,15 preserva somente o último trecho de movimento")
	check.call(is_equal_approx(state.cooldown_remaining, 0.58) and state.attack_serial == 0,
		"excedente consome recarga, não cria ataque descartado")
	check.call(not state.try_dodge(Vector2.LEFT), "recarga bloqueia nova esquiva em repouso")
	check.call(state.try_attack(Vector2.UP), "recarga de esquiva não bloqueia ataque")
	check.call(state.advance(0.58) and state.cooldown_remaining == 0.0,
		"recarga termina a 0,75 desde o pedido inicial")
	check.call(state.try_dodge(Vector2.LEFT), "esquiva volta exatamente no fim da recarga")
	for delta: float in [0.10, 0.15, 0.20, 10.0]:
		var fresh = script.new()
		fresh.try_dodge(Vector2.RIGHT)
		check.call(fresh.advance(delta) and not fresh.invulnerable,
			"delta %.2f termina sem proteção" % delta)
		check.call(is_equal_approx(fresh.dodge_seconds_this_step, minf(delta, 0.15)),
			"movimento limita duração mesmo atravessando fim da esquiva")
		check.call(fresh.phase == (script.DODGE if delta < 0.15 else script.IDLE),
			"fim de esquiva independe de tick extra")
	var ticks = script.new()
	ticks.try_dodge(Vector2.RIGHT)
	for index: int in range(75):
		check.call(ticks.advance(0.01), "passo fracionado de esquiva aceito")
		if index == 9:
			check.call(not ticks.invulnerable, "dez passos expiram proteção sem arredondamento tardio")
		if index == 14:
			check.call(ticks.phase == script.IDLE, "quinze passos encerram movimento")
	check.call(ticks.cooldown_remaining == 0.0 and ticks.try_dodge(Vector2.UP),
		"75 passos encerram custo sem arredondamento tardio")
	var recovery = script.new()
	recovery.try_attack(Vector2.UP)
	recovery.advance(0.13)
	check.call(recovery.try_dodge(Vector2.LEFT) and recovery.phase == script.DODGE
		and not recovery.active_this_step and recovery.attack_serial == 1,
		"esquiva cancela somente recuperação e elimina snapshot anterior")
	return true


func _snapshot(state: RefCounted) -> Array:
	return [state.phase, state.attack_direction, state.attack_serial, state.active_this_step,
		state.dodge_direction, state.dodge_seconds_this_step, state.invulnerable, state.cooldown_remaining]


func _test_invalid(script: GDScript, check: Callable) -> bool:
	for invalid: Vector2 in [Vector2.ZERO, Vector2(NAN, 0), Vector2(0, NAN),
		Vector2(INF, 1), Vector2(1, -INF)]:
		var state = script.new()
		var before := _snapshot(state)
		check.call(not state.try_attack(invalid) and _snapshot(state) == before,
			"direção inválida de ataque recusa sem alterar estado")
		check.call(not state.try_dodge(invalid) and _snapshot(state) == before,
			"direção inválida de esquiva recusa sem alterar estado")
	for setup: String in ["idle", "attack", "dodge"]:
		var state = script.new()
		if setup == "attack":
			state.try_attack(Vector2.LEFT)
			state.advance(0.06)
		elif setup == "dodge":
			state.try_dodge(Vector2.DOWN)
			state.advance(0.04)
		var before := _snapshot(state)
		check.call(state.advance(0.0) and _snapshot(state) == before,
			"delta zero não avança nem altera snapshot: " + setup)
		for delta: float in [-0.001, NAN, INF, -INF, 10.0001]:
			check.call(not state.advance(delta) and _snapshot(state) == before,
				"delta inválido recusa sem limpar snapshot ou relógios: " + setup)
		# Verifica também relógios internos, não só as propriedades expostas.
		state.advance(0.01)
		check.call(state.phase == (script.IDLE if setup == "idle" else script.ACTIVE if setup == "attack" else script.DODGE),
			"entrada inválida não contamina avanço posterior: " + setup)
	for direction: Vector2 in [Vector2(3.0e38, 3.0e38), Vector2(1.0e-30, 0.0)]:
		var state = script.new()
		check.call(state.try_attack(direction) and state.attack_direction.is_finite()
			and is_equal_approx(state.attack_direction.length(), 1.0),
			"direção finita extrema normaliza sem overflow ou underflow")
		var dodge = script.new()
		check.call(dodge.try_dodge(direction) and dodge.dodge_direction.is_finite()
			and is_equal_approx(dodge.dodge_direction.length(), 1.0),
			"esquiva aceita direção finita extrema")
	return true


func _test_clock_edges(script: GDScript, check: Callable) -> bool:
	for sample: Array in [[0.099998, true], [0.099999, false], [0.0999995, false], [0.10, false]]:
		var state = script.new()
		state.try_dodge(Vector2.RIGHT)
		check.call(state.advance(sample[0]) and state.invulnerable == sample[1],
			"proteção normaliza resto até um microssegundo: %.7f" % sample[0])
	for sample: Array in [[0.149998, script.DODGE], [0.149999, script.IDLE],
		[0.1499995, script.IDLE], [0.15, script.IDLE]]:
		var state = script.new()
		state.try_dodge(Vector2.RIGHT)
		check.call(state.advance(sample[0]) and state.phase == sample[1],
			"fim de movimento normaliza resto até um microssegundo: %.7f" % sample[0])
	for sample: Array in [[0.749998, false], [0.749999, true], [0.7499995, true], [0.75, true]]:
		var state = script.new()
		state.try_dodge(Vector2.RIGHT)
		state.advance(sample[0])
		check.call(state.try_dodge(Vector2.UP) == sample[1],
			"recarga normaliza resto até um microssegundo: %.7f" % sample[0])
	for elapsed: float in [0.05, 0.13, 0.27]:
		var state = script.new()
		state.try_attack(Vector2.RIGHT)
		state.advance(elapsed - 0.000001)
		check.call(state.phase == (script.ACTIVE if elapsed == 0.05 else script.RECOVERY if elapsed == 0.13 else script.IDLE),
			"borda de ataque normaliza um microssegundo restante: %.2f" % elapsed)
	var recovery = script.new()
	recovery.try_attack(Vector2.RIGHT)
	recovery.advance(0.13)
	var before := _snapshot(recovery)
	check.call(not recovery.try_dodge(Vector2.ZERO) and _snapshot(recovery) == before,
		"esquiva inválida na recuperação não cancela snapshot nem assume custo")
	return true


func _test_interrupt_and_death(script: GDScript, check: Callable) -> bool:
	for elapsed: float in [0.0, 0.06, 0.14]:
		var state = script.new()
		state.try_attack(Vector2.UP)
		state.advance(elapsed)
		state.interrupt()
		check.call(state.phase == script.IDLE and not state.active_this_step
			and not state.invulnerable and state.attack_serial == 1,
			"interromper qualquer fase de ataque elimina ação sem criar identidade")
		state.advance(1.0)
		check.call(state.phase == script.IDLE and not state.active_this_step,
			"ataque interrompido não reaparece")
	for elapsed: float in [0.0, 0.05, 0.14, 0.20]:
		var state = script.new()
		state.try_dodge(Vector2.LEFT)
		state.advance(elapsed)
		state.interrupt()
		check.call(state.phase == script.IDLE and not state.invulnerable
			and state.dodge_seconds_this_step == 0.0 and not state.active_this_step
			and is_equal_approx(state.cooldown_remaining, 0.75 - elapsed),
			"interrupção limpa proteção/movimento, não reembolsa custo")
		check.call(not state.try_dodge(Vector2.UP), "interrupção não habilita esquiva em recarga")
		state.advance(0.749 - elapsed)
		check.call(not state.try_dodge(Vector2.UP), "custo interrompido dura até 0,75")
		state.advance(0.001)
		check.call(state.try_dodge(Vector2.UP), "custo interrompido expira no instante original")
	for setup: String in ["idle", "attack", "dodge"]:
		var state = script.new()
		if setup == "attack":
			state.try_attack(Vector2.RIGHT)
			state.advance(0.06)
		elif setup == "dodge":
			state.try_dodge(Vector2.RIGHT)
		state.mark_dead()
		check.call(state.phase == script.DEAD and not state.active_this_step
			and not state.invulnerable and state.dodge_seconds_this_step == 0.0,
			"morte elimina ação, janela e proteção: " + setup)
		check.call(not state.try_attack(Vector2.LEFT) and not state.try_dodge(Vector2.UP),
			"morto recusa ações")
		state.interrupt()
		state.mark_dead()
		check.call(state.advance(10.0) and state.phase == script.DEAD and not state.active_this_step,
			"morte permanece terminal após interrupção, repetição e avanço")
	return true

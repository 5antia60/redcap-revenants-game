extends RefCounted
## Detecta validação ausente, estado compartilhado e morte duplicada por reentrância.

const HEALTH_PATH := "res://src/combat/health.gd"


func run(_tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(HEALTH_PATH), "S2: regra local de vida deve existir")
	if not ResourceLoader.exists(HEALTH_PATH):
		return false
	var script := load(HEALTH_PATH) as GDScript
	check.call(script != null and script.can_instantiate(), "vida deve carregar e instanciar")
	if script == null or not script.can_instantiate():
		return false
	var health = script.new()
	check.call(health is RefCounted and health.has_method("apply_damage"), "vida deve oferecer API local")
	if not health is RefCounted or not health.has_method("apply_damage"):
		return false
	for signal_name: String in ["changed", "died"]:
		check.call(health.has_signal(signal_name), "vida deve oferecer sinal: " + signal_name)
		if not health.has_signal(signal_name):
			return false
	check.call(_test_damage(script, check) == true, "subteste de dano deve concluir")
	check.call(_test_limits(script, check) == true, "subteste de limites deve concluir")
	check.call(_test_reentrant(script, check) == true, "subteste de reentrância deve concluir")
	return true


func _test_damage(script: GDScript, check: Callable) -> bool:
	var health = script.new(30)
	var events: Array = []
	var on_changed := func(current: int, maximum: int) -> void:
		check.call(health.current == current and health.maximum == maximum and health.dead == (current == 0),
			"changed observa estado já atualizado")
		events.append([current, maximum])
	var on_died := func() -> void:
		check.call(health.current == 0 and health.dead, "died observa morte já atualizada")
		events.append("died")
	health.changed.connect(on_changed)
	health.died.connect(on_died)
	for expected: int in [20, 10, 0]:
		check.call(health.apply_damage(10) and health.current == expected,
			"vida 30 recebe três golpes de 10")
	check.call(events == [[20, 30], [10, 30], [0, 30], "died"],
		"cada dano emite mudança; morte emite uma vez após mudança letal")
	check.call(not health.apply_damage(10) and health.current == 0 and health.dead
		and events.size() == 4, "dano após morte não revive ou emite sinais")
	health.changed.disconnect(on_changed)
	health.died.disconnect(on_died)
	var fresh = script.new(30)
	check.call(fresh.current == 30 and not fresh.dead and health.dead,
		"reset recria vida sem reviver instância anterior")
	return true


func _test_limits(script: GDScript, check: Callable) -> bool:
	for maximum: int in [-9223372036854775807, -1, 0, 1001, 9223372036854775807]:
		var health = script.new(maximum)
		check.call(health.maximum == 100 and health.current == 100 and not health.dead,
			"máximo inválido usa 100, não clamp")
	var default_health = script.new()
	check.call(default_health.maximum == 100 and default_health.current == 100,
		"vida padrão é 100")
	for maximum: int in [1, 30, 100, 1000]:
		var health = script.new(maximum)
		var events: Array = []
		var on_changed := func(current: int, limit: int) -> void: events.append([current, limit])
		var on_died := func() -> void: events.append("died")
		health.changed.connect(on_changed)
		health.died.connect(on_died)
		for invalid: int in [-9223372036854775807, -1, 0, 1001, 9223372036854775807]:
			check.call(not health.apply_damage(invalid) and health.current == maximum
				and not health.dead and events.is_empty(), "dano inválido não altera vida nem emite")
		check.call(health.apply_damage(1000) and health.current == 0 and health.dead,
			"dano máximo aceito limita vida a zero sem underflow")
		check.call(events == [[0, maximum], "died"], "overkill também emite uma única morte")
		health.changed.disconnect(on_changed)
		health.died.disconnect(on_died)
	var minimum = script.new(1000)
	check.call(minimum.apply_damage(1) and minimum.current == 999 and not minimum.dead,
		"dano mínimo e máximo de vida são inclusivos")
	var isolated = script.new(30)
	check.call(isolated.current == 30 and not isolated.dead, "instâncias não compartilham vida ou morte")
	return true


func _test_reentrant(script: GDScript, check: Callable) -> bool:
	for lethal_first: bool in [true, false]:
		var health = script.new(30)
		var events: Array = []
		var on_changed := func(current: int, maximum: int) -> void:
			check.call(health.current == current and health.maximum == maximum
				and health.dead == (current == 0), "reentrância vê estado consistente antes de emitir")
			events.append(current)
			if current > 0:
				check.call(health.apply_damage(1000), "callback não letal pode causar dano letal")
			else:
				check.call(not health.apply_damage(1), "callback letal recusa novo dano")
		var on_died := func() -> void:
			events.append("died")
			check.call(health.dead and health.current == 0 and not health.apply_damage(1),
				"callback de morte não causa nova mudança nem morte")
		health.changed.connect(on_changed)
		health.died.connect(on_died)
		check.call(health.apply_damage(30 if lethal_first else 10), "dano externo aceito")
		check.call(events == ([0, "died"] if lethal_first else [20, 0, "died"]),
			"reentrância direta ou letal aninhada não duplica morte")
		check.call(health.dead and health.current == 0, "reentrância não revive receptor")
		health.changed.disconnect(on_changed)
		health.died.disconnect(on_died)
	return true

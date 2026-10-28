extends RefCounted
## Detecta normalização excessiva, soma de dispositivos e troca indevida de mira.

const POLICY_PATH := "res://src/player/input_state.gd"


func run(_tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(POLICY_PATH), "S1: política de intenção deve existir")
	if not ResourceLoader.exists(POLICY_PATH):
		return false
	var script := load(POLICY_PATH) as GDScript
	check.call(script != null and script.can_instantiate(), "política deve ser instanciável")
	if script == null or not script.can_instantiate():
		return false
	var state = script.new()
	check.call(state is RefCounted, "política deve ser RefCounted local")
	if not state is RefCounted:
		return false
	for method: String in ["movement", "aim"]:
		check.call(state.has_method(method), "política deve oferecer método: " + method)
		if not state.has_method(method):
			return false
	check.call(_test_movement(state, check) == true, "subteste de movimento deve concluir")
	check.call(_test_aim(state, check) == true, "subteste de mira deve concluir")
	var fresh = script.new()
	check.call(fresh.aim_direction == Vector2.RIGHT and fresh.aim_source == "mouse",
		"nova instância não herda mira da anterior")
	return true


func _test_movement(state: RefCounted, check: Callable) -> bool:
	check.call(state.movement(Vector2.RIGHT, true, Vector2.ZERO).is_equal_approx(Vector2.RIGHT),
		"cardinal mantém módulo 1")
	check.call(state.movement(Vector2.ONE, true, Vector2.ONE).is_equal_approx(Vector2(0.70710678, 0.70710678)),
		"diagonal não ganha velocidade nem soma dispositivos")
	check.call(state.movement(Vector2.ZERO, false, Vector2(0.1, 0.0)) == Vector2.ZERO,
		"stick 0,1 fica neutro")
	check.call(state.movement(Vector2.ZERO, false, Vector2(0.2, 0.0)) == Vector2.ZERO,
		"limite da deadzone 0,2 fica neutro (módulo recebido %.12f)" % Vector2(0.2, 0).length())
	check.call(state.movement(Vector2.ZERO, false, Vector2(0.6, 0.0)).is_equal_approx(Vector2(0.5, 0.0)),
		"stick 0,6 mantém módulo 0,5 com deadzone aplicada uma vez")
	check.call(state.movement(Vector2.ZERO, false, Vector2(0.36, 0.48)).is_equal_approx(Vector2(0.3, 0.4)),
		"deadzone é radial e preserva direção parcial")
	check.call(state.movement(Vector2.ZERO, false, Vector2.ONE).is_equal_approx(Vector2(0.70710678, 0.70710678)),
		"stick diagonal satura em módulo 1")
	check.call(state.movement(Vector2.LEFT, true, Vector2.RIGHT) == Vector2.LEFT,
		"teclado ativo vence stick sem soma")
	check.call(state.movement(Vector2.ZERO, true, Vector2.RIGHT) == Vector2.ZERO,
		"teclas opostas ativas cancelam mesmo com stick")
	check.call(state.movement(Vector2.LEFT, false, Vector2.RIGHT) == Vector2.RIGHT,
		"teclado inativo não sobrescreve stick")
	for invalid: Vector2 in [Vector2(NAN, 0), Vector2(0, NAN), Vector2(INF, 1), Vector2(1, -INF)]:
		check.call(state.movement(invalid, true, Vector2.RIGHT) == Vector2.ZERO,
			"teclado não finito neutraliza sem fallback")
		check.call(state.movement(Vector2.ZERO, false, invalid) == Vector2.ZERO,
			"stick não finito neutraliza movimento")
		check.call(state.movement(Vector2.RIGHT, true, invalid) == Vector2.RIGHT,
			"stick inválido não contamina teclado válido")
	return true


func _test_aim(state: RefCounted, check: Callable) -> bool:
	check.call(state.aim_direction == Vector2.RIGHT and state.aim_source == "mouse",
		"mira inicia à direita com fonte mouse")
	check.call(state.aim(Vector2.ZERO, Vector2.ZERO, true, Vector2.ZERO, false) == Vector2.RIGHT,
		"mouse nos pés preserva direção inicial")
	check.call(state.aim(Vector2.ZERO, Vector2.ZERO, false, Vector2(0.1, 0), true) == Vector2.RIGHT
		and state.aim_source == "mouse", "drift não reivindica mira")
	check.call(state.aim(Vector2.ZERO, Vector2.ZERO, false, Vector2(0, 0.2), true) == Vector2.RIGHT
		and state.aim_source == "mouse", "limite 0,2 também não reivindica mira")
	check.call(state.aim(Vector2(100, 0), Vector2.ZERO, false, Vector2(0, -0.6), true) == Vector2.UP
		and state.aim_source == "gamepad", "atividade válida do stick reivindica direção unitária")
	check.call(state.aim(Vector2(0, 100), Vector2(10, 10), false, Vector2(0, -0.6), false) == Vector2.UP
		and state.aim_source == "gamepad", "cursor parado e conversão de câmera não roubam mira")
	check.call(state.aim(Vector2(0, 100), Vector2.ZERO, true, Vector2.LEFT, true) == Vector2.DOWN
		and state.aim_source == "mouse", "mouse vence atividade simultânea")
	check.call(state.aim(Vector2(100, 0), Vector2.ZERO, false, Vector2.LEFT, false) == Vector2.RIGHT
		and state.aim_source == "mouse", "amostra estável do stick não recupera fonte")
	check.call(state.aim(Vector2(100, 0), Vector2(100, 100), false, Vector2.ZERO, false) == Vector2.UP,
		"fonte mouse atualiza direção pelos pés atuais sem exigir nova atividade")
	check.call(state.aim(Vector2(100, 100), Vector2(100, 100), true, Vector2.ZERO, false) == Vector2.UP,
		"alvo coincidente preserva última direção válida")
	check.call(state.aim(Vector2.ZERO, Vector2.ZERO, false, Vector2.LEFT, true) == Vector2.LEFT,
		"nova atividade do controle recupera mira")
	check.call(state.aim(Vector2.ZERO, Vector2.ZERO, false, Vector2.ZERO, false) == Vector2.LEFT
		and state.aim_source == "gamepad", "neutro preserva direção e fonte")
	for invalid: Vector2 in [Vector2(NAN, 0), Vector2(INF, 0), Vector2(0, -INF)]:
		check.call(state.aim(invalid, Vector2.ZERO, true, invalid, true) == Vector2.LEFT
			and state.aim_source == "gamepad", "atividade inválida não muda mira ou fonte")
		check.call(state.aim(Vector2.ONE, invalid, true, Vector2.ZERO, false) == Vector2.LEFT,
			"pés não finitos não contaminam mira")
	check.call(state.aim(Vector2(30, 60), Vector2(30, 20), true, Vector2.ZERO, false) == Vector2.DOWN,
		"mouse mundial é relativo aos pés, não à origem da cena")
	return true

extends RefCounted
## Detecta antecipação curta, direção móvel, rajadas atrasadas e snapshots repetidos.

const PATH := "res://src/enemies/melee_chaser_state.gd"


func run(_tree: SceneTree, check: Callable) -> bool:
	check.call(ResourceLoader.exists(PATH), "S3: política local do perseguidor deve existir")
	if not ResourceLoader.exists(PATH):
		return false
	var script := load(PATH) as GDScript
	if script == null or not script.can_instantiate():
		return false
	var state = script.new()
	check.call(state.phase == state.CHASE, "S3: inicia em perseguição")
	check.call(state.advance(0.1, Vector2(61, 0)) and state.phase == state.CHASE,
		"S3: pés além de60 não preparam")
	check.call(state.advance(0.1, Vector2(60, 0)) and state.phase == state.WINDUP
		and state.attack_serial == 1, "S3: pés em60 iniciam preparação")
	check.call(state.advance(0.49, Vector2.UP * 30) and state.phase == state.WINDUP
		and not state.active_this_step and state.attack_direction == Vector2.RIGHT,
		"S3: antes de0,60 não há dano; direção permanece fixada")
	check.call(state.advance(0.01, Vector2.LEFT * 30) and state.phase == state.ACTIVE
		and not state.active_this_step, "S3: borda0,60 inicia fase sem antecipar janela")
	check.call(state.advance(0.05, Vector2.LEFT * 30) and state.active_this_step
		and state.phase == state.ACTIVE, "S3: interior da janela produz snapshot")
	check.call(state.advance(0.05, Vector2.LEFT * 30) and state.active_this_step
		and state.phase == state.RECOVERY, "S3: fim0,70 conserva trecho ativo atravessado")
	check.call(state.advance(0.79, Vector2.UP * 30) and not state.active_this_step
		and state.phase == state.RECOVERY and state.attack_direction == Vector2.RIGHT,
		"S3: recuperação0,80 mantém direção e não causa dano")
	check.call(state.advance(0.01, Vector2.UP * 30) and state.phase == state.CHASE
		and state.attack_serial == 1, "S3: ciclo1,50 termina sem ataque compensatório")
	check.call(state.advance(0.1, Vector2.UP * 30) and state.attack_serial == 2
		and state.attack_direction == Vector2.UP, "S3: próximo tick inicia novo serial/direção")
	state.interrupt()
	check.call(state.phase == state.CHASE and not state.active_this_step,
		"S3: interrupção limpa ação")
	state.advance(0.59, Vector2.DOWN * 30)
	check.call(not state.active_this_step and state.phase == state.WINDUP,
		"S3: retorno exige preparação completa")
	state.interrupt()
	check.call(state.advance(10.0, Vector2(40, 0)) and state.active_this_step
		and state.phase == state.CHASE and state.attack_serial == 4,
		"S3: passo10 atravessa janela uma única vez sem rajada")
	for delta: float in [0.0, -0.1, NAN, INF, -INF, 10.001]:
		var serial: int = state.attack_serial
		var accepted: bool = state.advance(delta, Vector2(40, 0))
		check.call(accepted == (delta == 0.0) and not state.active_this_step
			and state.attack_serial == serial and state.phase == state.CHASE,
			"S3: delta zero/inválido não repete snapshot: " + str(delta))
		var active = script.new()
		active.advance(0.65, Vector2(40, 0))
		check.call(active.active_this_step, "S3: preparar snapshot ativo para recusa de delta")
		active.advance(delta, Vector2(40, 0))
		check.call(not active.active_this_step and active.phase == active.ACTIVE
			and active.attack_serial == 1, "S3: delta recusado/zero não reutiliza ativo nem consome relógio")
	for offset: Vector2 in [Vector2(NAN, 0), Vector2(INF, 0), Vector2(1000001, 0)]:
		check.call(not state.advance(0.1, offset) and not state.active_this_step
			and state.phase == state.CHASE, "S3: alvo inválido não inicia ação")
	state.advance(0.1, Vector2.ZERO)
	check.call(state.phase == state.WINDUP and state.attack_direction.is_finite()
		and state.attack_direction != Vector2.ZERO, "S3: pés coincidentes conservam direção válida")
	var other = script.new()
	check.call(other.attack_serial == 0 and other.phase == other.CHASE, "S3: política por instância")
	for tick in range(36):
		other.advance(1.0 / 60.0, Vector2(45, 0))
	check.call(other.phase == other.ACTIVE and not other.active_this_step,
		"S3:36 passos1/60 chegam a0,60 sem dano antecipado por arredondamento")
	other.advance(1.0 / 60.0, Vector2(45, 0))
	check.call(other.active_this_step, "S3:37º passo1/60 contém janela ativa real")
	state.mark_dead()
	state.interrupt()
	state.advance(10.0, Vector2.RIGHT)
	check.call(state.phase == state.DEAD and not state.active_this_step,
		"S3: morto não revive nem ataca")
	return true

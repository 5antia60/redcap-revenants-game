extends SceneTree
## Runner restrito às negativas isoladas da coleta; produção nunca lê estas fixtures.

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _run() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void:
		printerr("COLLECTION_WATCHDOG")
		quit(1))
	var module = load("res://tests/fixtures/test_player_input_collection.gd").new()
	_check(await module.run(self, _check) == true, "módulo de coleta deve concluir explicitamente")
	print("Input collection: %d verificações, %d falhas" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

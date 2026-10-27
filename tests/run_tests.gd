extends SceneTree
## Verifica a fundação real, sem plugins e sem depender de assert removível.

var failures: Array[String] = []
var checks: int = 0

const MAIN_SCENE := "res://src/game/foundation.tscn"
const EXPECTED_BINDINGS := {
	"move_left": ["key:65", "key:4194321", "axis:0:-1"],
	"move_right": ["key:68", "key:4194323", "axis:0:1"],
	"move_up": ["key:87", "key:4194320", "axis:1:-1"],
	"move_down": ["key:83", "key:4194322", "axis:1:1"],
	"aim_left": ["axis:2:-1"],
	"aim_right": ["axis:2:1"],
	"aim_up": ["axis:3:-1"],
	"aim_down": ["axis:3:1"],
	"attack": ["mouse:1", "button:2"],
	"dodge": ["key:32", "button:0"],
	"pause": ["key:4194305", "button:6"],
}


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var config := ConfigFile.new()
	var result := config.load("res://project.godot")
	check(result == OK, "project.godot deve existir e ser legível")
	if result == OK:
		_test_config(config)
		_test_input(config)
	await _test_scene()
	if "--self-test-failure" in OS.get_cmdline_user_args():
		check(false, "falha deliberada do runner")
	print("S0: %d verificações, %d falhas" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_config(config: ConfigFile) -> void:
	check(config.get_value("application", "run/main_scene", "") == MAIN_SCENE,
		"cena principal deve ser a fundação")
	check(not config.has_section("autoload"), "não deve haver autoloads")
	check(config.get_value("display", "window/size/viewport_width", 0) == 1280,
		"viewport deve ter largura 1280")
	check(config.get_value("display", "window/size/viewport_height", 0) == 720,
		"viewport deve ter altura 720")
	check(config.get_value("display", "window/stretch/mode", "") == "canvas_items",
		"redimensionamento deve preservar a interface")
	check(config.get_value("rendering", "renderer/rendering_method", "") == "gl_compatibility",
		"renderizador deve ser Compatibility")
	check(ProjectSettings.get_setting("application/run/main_scene", "") == MAIN_SCENE,
		"engine deve consumir a cena principal configurada")


func _test_input(config: ConfigFile) -> void:
	check(config.has_section("input"), "InputMap deve estar declarado no projeto")
	if not config.has_section("input"):
		return
	check(config.get_section_keys("input").size() == EXPECTED_BINDINGS.size(),
		"InputMap deve conter somente as 11 ações de diagnóstico")
	for action: String in EXPECTED_BINDINGS:
		check(config.has_section_key("input", action), "ação declarada: " + action)
		check(InputMap.has_action(action), "ação carregada pela engine: " + action)
		if not InputMap.has_action(action):
			continue
		check(is_equal_approx(InputMap.action_get_deadzone(action), 0.2),
			"deadzone 0,2: " + action)
		var actual: Array[String] = []
		for event: InputEvent in InputMap.action_get_events(action):
			actual.append(_event_signature(event))
			# Godot 4.7 reserva 16 para teclado e 32 para mouse; controles
			# usam -1 no InputMap para aceitar qualquer dispositivo conectado.
			var expected_device := 16 if event is InputEventKey else 32 if event is InputEventMouseButton else -1
			check(event.device == expected_device,
				"dispositivo correto: %s (device=%d, tipo=%s)" % [action, event.device, event.get_class()])
		actual.sort()
		var expected: Array = EXPECTED_BINDINGS[action].duplicate()
		expected.sort()
		check(actual == expected, "bindings de %s: %s" % [action, actual])


func _event_signature(event: InputEvent) -> String:
	if event is InputEventKey:
		# Posições físicas WASD permanecem estáveis em layouts de teclado diferentes.
		return "key:%d" % event.physical_keycode
	if event is InputEventJoypadMotion:
		return "axis:%d:%d" % [event.axis, int(event.axis_value)]
	if event is InputEventJoypadButton:
		return "button:%d" % event.button_index
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	return "evento não previsto"


func _test_scene() -> void:
	check(ResourceLoader.exists(MAIN_SCENE), "cena de fundação deve existir")
	if not ResourceLoader.exists(MAIN_SCENE):
		return
	var packed := load(MAIN_SCENE) as PackedScene
	check(packed != null, "cena deve carregar como PackedScene")
	if packed == null:
		return
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var instance := packed.instantiate()
		check(instance is Control, "raiz da fundação deve ser Control")
		viewport.add_child(instance)
		await process_frame
		await process_frame
		_check_diagnostic_tree(instance)
		for label_name: String in ["Title", "Status"]:
			var label := instance.find_child(label_name, true, false) as Label
			check(label != null, "diagnóstico presente: " + label_name)
			if label == null:
				continue
			var expected_text := "Último Sol — Fundação S0" if label_name == "Title" else "Sem gameplay implementado"
			check(label.text == expected_text, "texto de diagnóstico: " + label_name)
			check(label.is_visible_in_tree(), "diagnóstico visível: " + label_name)
			check(label.size.x >= label.get_minimum_size().x and label.size.y >= label.get_minimum_size().y,
				"texto sem recorte geométrico: " + label_name)
			check(Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(label.get_global_rect()),
				"texto dentro do viewport %s: %s" % [viewport_size, label_name])
		viewport.free()


func _check_diagnostic_tree(node: Node) -> void:
	check(node is Control, "fundação contém somente nós de interface: " + str(node.name))
	check(node.get_script() == null, "fundação não contém scripts: " + str(node.name))
	for child: Node in node.get_children():
		_check_diagnostic_tree(child)

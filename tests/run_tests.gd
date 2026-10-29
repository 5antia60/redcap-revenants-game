extends SceneTree
## Verifica a fundação e o movimento real, sem plugins ou assert removível.

var failures: Array[String] = []
var checks: int = 0

const MAIN_SCENE := "res://src/game/main.tscn"
const FOUNDATION_SCENE := "res://src/game/foundation.tscn"
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
	var watchdog := create_timer(30.0, true, false, true)
	watchdog.timeout.connect(func() -> void:
		printerr("FAIL: watchdog do runner excedeu 30 segundos")
		quit(1)
	)
	var config := ConfigFile.new()
	var result := config.load("res://project.godot")
	check(result == OK, "project.godot deve existir e ser legível")
	if result == OK:
		check(_test_config(config) == true, "configuração deve concluir")
		check(_test_input(config) == true, "InputMap deve concluir")
	check(_test_export_preset() == true, "preset deve concluir")
	check(await _test_scene() == true, "cena de fundação deve concluir")
	for module_path: String in ["res://tests/unit/test_input_state.gd",
		"res://tests/integration/test_player_motion.gd", "res://tests/integration/test_movement_lab.gd"]:
		check(await _run_module(module_path) == true, "chamada do módulo deve concluir: " + module_path)
	if "--self-test-failure" in OS.get_cmdline_user_args():
		check(false, "falha deliberada do runner")
	print("S0 + S1: %d verificações, %d falhas" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _run_module(path: String) -> bool:
	check(ResourceLoader.exists(path), "módulo de teste deve existir: " + path)
	if not ResourceLoader.exists(path):
		return false
	var script := load(path) as GDScript
	check(script != null and script.can_instantiate(), "módulo deve carregar: " + path)
	if script == null or not script.can_instantiate():
		return false
	var module = script.new()
	check(module is RefCounted and module.has_method("run"), "módulo deve oferecer run: " + path)
	if module is RefCounted and module.has_method("run"):
		var completed: Variant = await module.run(self, check)
		check(completed == true, "módulo deve retornar conclusão explícita: " + path)
		return completed == true
	return false


func _test_config(config: ConfigFile) -> bool:
	check(config.get_value("application", "run/main_scene", "") == MAIN_SCENE,
		"cena principal deve ser Main S1")
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
	return true


func _test_export_preset() -> bool:
	var preset := ConfigFile.new()
	check(preset.load("res://export_presets.cfg") == OK, "preset de export deve ser legível")
	check(preset.get_value("preset.0", "name", "") == "Windows S0", "preset Windows S0")
	check(preset.get_value("preset.0", "platform", "") == "Windows Desktop", "plataforma Windows")
	check(preset.get_value("preset.0", "export_filter", "") == "scenes", "export somente de cenas selecionadas")
	check(preset.get_value("preset.0", "export_files", PackedStringArray()) == PackedStringArray([MAIN_SCENE]),
		"somente Main deve iniciar a seleção de dependências")
	check(preset.get_value("preset.0", "script_export_mode", -1) == 0, "scripts devem ser texto auditável")
	check(ProjectSettings.get_setting("editor/export/convert_text_resources_to_binary", true) == false,
		"cenas devem preservar texto auditável")
	check(preset.get_value("preset.0", "include_filter", "invalid") == "src/player/input_state.gd",
		"incluir explicitamente somente input_state sem wildcard de scripts")
	var exclusions: String = preset.get_value("preset.0", "exclude_filter", "")
	for path: String in ["docs/brief.md", "tests/run_tests.gd", "tests/.generated/probe.tscn",
		"scripts/export.ps1", ".tools/probe.tscn", "builds/probe.tscn", ".git/config", "README.md", "AGENTS.md"]:
		var excluded := false
		for pattern: String in exclusions.split(",", false):
			if path.matchn(pattern.strip_edges()):
				excluded = true
		check(excluded, "filtro deve excluir desenvolvimento: " + path)
	for mode: String in ["debug", "release"]:
		check(preset.get_value("preset.0.options", "custom_template/" + mode, "") ==
			".tools/templates/4.7.2.stable/windows_%s_x86_64.exe" % mode, "template local explícito: " + mode)
	check(preset.get_value("preset.0.options", "binary_format/architecture", "") == "x86_64", "arquitetura x86_64")
	check(preset.get_value("preset.0.options", "binary_format/embed_pck", true) == false, "PCK externo auditável")
	check(preset.get_value("preset.0.options", "codesign/enable", true) == false, "sem assinatura")
	check(preset.get_value("preset.0", "encrypt_pck", true) == false, "sem criptografia de pack")
	check(preset.get_value("preset.0", "encrypt_directory", true) == false, "sem criptografia de diretório")
	return true


func _test_input(config: ConfigFile) -> bool:
	check(config.has_section("input"), "InputMap deve estar declarado no projeto")
	if not config.has_section("input"):
		return false
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
	return true


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


func _test_scene() -> bool:
	check(ResourceLoader.exists(FOUNDATION_SCENE), "cena de fundação deve existir")
	if not ResourceLoader.exists(FOUNDATION_SCENE):
		return false
	var packed := load(FOUNDATION_SCENE) as PackedScene
	check(packed != null, "cena deve carregar como PackedScene")
	if packed == null:
		return false
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var instance := packed.instantiate()
		check(instance is Control, "raiz da fundação deve ser Control")
		viewport.add_child(instance)
		await process_frame
		await process_frame
		check(_check_diagnostic_tree(instance) == true, "árvore de diagnóstico deve concluir")
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
	return true


func _check_diagnostic_tree(node: Node) -> bool:
	check(node is Control, "fundação contém somente nós de interface: " + str(node.name))
	check(node.get_script() == null, "fundação não contém scripts: " + str(node.name))
	for child: Node in node.get_children():
		check(_check_diagnostic_tree(child) == true, "filho de diagnóstico deve concluir: " + str(child.name))
	return true

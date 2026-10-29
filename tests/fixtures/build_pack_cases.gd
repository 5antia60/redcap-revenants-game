extends SceneTree
## PCKs locais inertes, construídos de fontes conhecidas. Não recebe packs externos.

const SOURCES := ["src/player/input_state.gd", "src/player/player_input.gd", "src/player/player.gd",
	"src/arenas/movement_lab.gd", "src/game/main.tscn", "src/player/player.tscn", "src/arenas/movement_lab.tscn"]
const CASES := ["valid", "extra_script", "orphan_gdc", "foreign_remap", "external_remap", "cycle_remap",
	"alias", "traversal_remap", "test_file", "tool_file", "docs_file", "env_file", "addon",
	"missing_authorized", "changed_script", "embedded_script", "tool_annotation", "opaque_scene"]
var failed: bool = false


func _initialize() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void:
		printerr("FIXTURE_WATCHDOG")
		quit(1))
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].begins_with("res://.tools/s1/pack-cases-") or ".." in args[0] or "\\" in args[0]:
		quit(1)
		return
	var destination: String = args[0]
	if DirAccess.dir_exists_absolute(destination):
		printerr("Destino de fixtures já existe; preservado.")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		quit(1)
		return
	var binary := destination.path_join("project.binary")
	if ProjectSettings.save_custom(binary) != OK:
		quit(1)
		return
	for case_name: String in CASES:
		_build(destination, binary, case_name)
	print("FIXTURES: %d packs inertes; falha=%s" % [CASES.size(), failed])
	quit(1 if failed else 0)


func _build(destination: String, binary: String, case_name: String) -> void:
	var pack := PCKPacker.new()
	if pack.pck_start(destination.path_join(case_name + ".pck")) != OK:
		failed = true
		return
	_add(pack, "project.binary", binary)
	if case_name == "valid":
		_add(pack, ".godot/global_script_class_cache.cfg", _write(destination.path_join("empty-global-cache.txt"), "list=[]\n".to_utf8_buffer()))
		var uid := StreamPeerBuffer.new()
		uid.put_u32(1)
		uid.put_u64(1)
		var path := "res://src/player/player.gd".to_utf8_buffer()
		uid.put_u32(path.size())
		uid.put_data(path)
		_add(pack, ".godot/uid_cache.bin", _write(destination.path_join("allowed-uid-cache.bin"), uid.data_array))
	for relative: String in SOURCES:
		if case_name == "missing_authorized" and relative == "src/player/player.gd":
			continue
		var source := "res://" + relative
		var replacement := ""
		if relative == "src/player/player.gd":
			if case_name == "changed_script":
				replacement = FileAccess.get_file_as_string(source) + "\n# Alteração inerte conhecida.\n"
			elif case_name == "tool_annotation":
				replacement = "@tool\n" + FileAccess.get_file_as_string(source)
		if relative == "src/game/main.tscn" and case_name == "embedded_script":
			replacement = '[gd_scene load_steps=2 format=3]\n[sub_resource type="GDScript" id="Inert"]\nscript/source = "extends Node2D\\n"\n[node name="Main" type="Node2D"]\nscript = SubResource("Inert")\n'
		if not replacement.is_empty():
			source = _write(destination.path_join(case_name + ".txt"), replacement.to_utf8_buffer())
		_add(pack, relative, source)
	var extra := ""
	var bytes := "Fixture inerte, sem dados reais.\n".to_utf8_buffer()
	match case_name:
		"extra_script": extra = "src/player/extra.gd"; bytes = "extends RefCounted\n".to_utf8_buffer()
		"orphan_gdc": extra = "src/player/orphan.gdc"
		"foreign_remap": extra = "src/player/extra.gd.remap"; bytes = '[remap]\npath="res://src/player/player.gd"\n'.to_utf8_buffer()
		"external_remap": extra = "src/player/player.gd.remap"; bytes = '[remap]\npath="user://inert.gdc"\n'.to_utf8_buffer()
		"cycle_remap": extra = "src/game/main.tscn.remap"; bytes = '[remap]\npath="res://src/game/main.tscn.remap"\n'.to_utf8_buffer()
		"traversal_remap": extra = "src/player/player.gd.remap"; bytes = '[remap]\npath="res://src/player/../../inert.gdc"\n'.to_utf8_buffer()
		"alias": extra = "src/player/Player.gd"
		"test_file": extra = "tests/inert.gd"
		"tool_file": extra = ".tools/inert.txt"
		"docs_file": extra = "docs/inert.md"
		"env_file": extra = ".env"
		"addon": extra = "addons/inert/plugin.cfg"
		"opaque_scene": extra = ".godot/exported/inert.scn"
	if not extra.is_empty():
		_add(pack, extra, _write(destination.path_join(case_name + "-extra.txt"), bytes))
	if pack.flush() != OK:
		failed = true


func _write(path: String, bytes: PackedByteArray) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failed = true
	else:
		file.store_buffer(bytes)
		file.close()
	return path


func _add(pack: PCKPacker, path: String, source: String) -> void:
	if pack.add_file("res://" + path, source) != OK:
		failed = true

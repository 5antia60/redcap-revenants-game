extends SceneTree
## Somente PCK local de procedência conhecida, hash externo verificado antes da engine.
## Identidade do texto vem da fonte congelada/revisada, não de regex nem do próprio pack.
## project.binary já foi consumido por ProjectSettings: este auditor não é uma sandbox.

const MAIN_SCENE := "res://src/game/main.tscn"
const SCRIPTS := ["res://src/player/input_state.gd", "res://src/player/player_input.gd",
	"res://src/player/player.gd", "res://src/arenas/movement_lab.gd"]
const SCENES := [MAIN_SCENE, "res://src/player/player.tscn", "res://src/arenas/movement_lab.tscn"]
# Caches observados/decodificados offline antes da engine; sem wildcard .godot/**.
const METADATA := ["res://project.binary", "res://.godot/global_script_class_cache.cfg", "res://.godot/uid_cache.bin"]
var failures: Array[String] = []
var files: Array[String] = []
var _manifest: Dictionary = {}
var _metadata_manifest: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	create_timer(15.0, true, false, true).timeout.connect(func() -> void:
		printerr("AUDIT_WATCHDOG: 15 segundos")
		quit(1))
	var directory := DirAccess.open("res://")
	_check(directory != null and directory.get_filesystem_type() == "PCK", "res deve ser PCK, nunca fonte")
	_check(_read_manifest(), "manifesto externo deve ser válido e completo")
	if failures.is_empty():
		_enumerate("res://", 0)
		files.sort()
		for path: String in files:
			print("PACK: ", path)
			_check(path in SCRIPTS or path in SCENES or path in METADATA, "arquivo fora da allowlist exata: " + path)
		for path: String in SCRIPTS + SCENES:
			_check(path in files, "recurso autorizado ausente: " + path)
			if path in files:
				_check(_matches_source(path), "bytes divergem da fonte revisada: " + path)
		for path: String in METADATA:
			_check(path in files, "metadado obrigatório ausente: " + path)
			if path in files:
				_check(_metadata_manifest.has(path), "metadado sem atestado semântico externo: " + path)
				if _metadata_manifest.has(path):
					_check(_matches_identity(path, _metadata_manifest[path]), "metadado diverge da inspeção externa: " + path)
		_check("res://project.binary" in files, "project.binary obrigatório")
		for path: String in _metadata_manifest:
			_check(path in files, "metadado inspecionado ausente: " + path)
	if not failures.is_empty():
		printerr("INVENTORY_REJECT: %d falhas; nenhum ResourceLoader autorizado" % failures.size())
		quit(1)
		return
	print("INVENTORY_OK: quatro scripts/três cenas com identidade SHA256 externa")
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == MAIN_SCENE, "configuração deve selecionar Main")
	for property: Dictionary in ProjectSettings.get_property_list():
		_check(not String(property.name).begins_with("autoload/"), "autoload proibido")
	if not failures.is_empty():
		printerr("CONFIG_REJECT")
		quit(1)
		return
	print("RESOURCE_LOAD_BEGIN")
	for path: String in SCRIPTS:
		var script := ResourceLoader.load(path, "GDScript") as GDScript
		_check(script != null and script.can_instantiate() and not script.is_tool(), "script próprio deve carregar sem @tool: " + path)
	var packed := ResourceLoader.load(MAIN_SCENE, "PackedScene") as PackedScene
	_check(packed != null, "Main deve carregar")
	if packed != null:
		var instance := packed.instantiate()
		_check(instance is Node2D and instance.has_node("MovementLab/Actors/Player"), "Main compõe laboratório e jogador")
		# Não entra na árvore: auditoria de composição não joga nem conecta dispositivos.
		instance.free()
	print("Audit: %d arquivos empacotados, %d falhas" % [files.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _read_manifest() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or args[0] != "--manifest" or args[2] != "--pack-attestation":
		return false
	var path: String = args[1]
	if not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var data: Variant = json.data
	if not data is Dictionary or data.size() != 2 or data.get("version") != 1 or not data.get("resources") is Array:
		return false
	var entries: Array = data.resources
	if entries.size() != 7:
		return false
	for entry: Variant in entries:
		if not entry is Dictionary or entry.size() != 3 or not entry.get("path") is String:
			return false
		var relative: String = entry.path
		if relative not in SCRIPTS + SCENES or _manifest.has(relative):
			return false
		var size: Variant = entry.get("size")
		if (not size is float and not size is int) or not is_finite(float(size)) or size <= 0 or size > 1048576 or float(size) != floorf(float(size)):
			return false
		var digest: Variant = entry.get("sha256")
		if not digest is String or digest.length() != 64:
			return false
		for character: String in digest:
			if character not in "0123456789abcdef":
				return false
		_manifest[relative] = entry
	return _manifest.size() == 7 and _read_pack_attestation(args[3], FileAccess.get_sha256(path))


func _read_pack_attestation(path: String, source_hash: String) -> bool:
	if not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var data: Variant = json.data
	if not data is Dictionary or data.size() != 7 or data.get("version") != 1 or data.get("pck_format") != 4:
		return false
	if data.get("engine") != "4.7.2.stable.official.ed1daf0bf" or data.get("source_manifest_sha256") != source_hash:
		return false
	var size: Variant = data.get("pck_size")
	if (not size is float and not size is int) or not is_finite(float(size)) or size < 108 or size > 8388608 or float(size) != floorf(float(size)):
		return false
	if not _valid_digest(data.get("pck_sha256")) or not data.get("metadata") is Array:
		return false
	var entries: Array = data.metadata
	if entries.size() != 3:
		return false
	for entry: Variant in entries:
		if not entry is Dictionary or entry.size() != 3 or not entry.get("path") is String:
			return false
		var relative: String = entry.path
		if relative not in METADATA or _metadata_manifest.has(relative):
			return false
		var length: Variant = entry.get("size")
		if (not length is float and not length is int) or not is_finite(float(length)) or length <= 0 or length > 1048576 or float(length) != floorf(float(length)):
			return false
		if not _valid_digest(entry.get("sha256")):
			return false
		_metadata_manifest[relative] = entry
	return _metadata_manifest.has("res://project.binary")


func _valid_digest(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _matches_source(path: String) -> bool:
	return _matches_identity(path, _manifest[path])


func _matches_identity(path: String, expected: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	return file.get_length() == int(expected.size) and FileAccess.get_sha256(path) == expected.sha256


func _enumerate(path: String, depth: int) -> void:
	if depth > 8 or files.size() > 128:
		_check(false, "inventário excede limite do laboratório")
		return
	var directory := DirAccess.open(path)
	_check(directory != null, "diretório empacotado deve abrir: " + path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.include_navigational = false
	for file: String in directory.get_files():
		files.append(path.path_join(file))
	for child: String in directory.get_directories():
		_enumerate(path.path_join(child), depth + 1)

extends SceneTree
## Executar com --main-pack e este script por caminho absoluto, nunca dentro do pack.

const MAIN_SCENE := "res://src/game/foundation.tscn"
const FORBIDDEN_DIRECTORIES := ["docs", "tests", "scripts", ".tools", "builds", ".git", ".generated"]
var failures: Array[String] = []
var files: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var directory := DirAccess.open("res://")
	# Godot consome --main-pack antes de OS.get_cmdline_args(). O comando externo
	# registra sua seleção; a prova de isolamento aqui é o filesystem virtual PCK.
	_check(directory != null, "res deve abrir")
	if directory != null:
		print("Audit res filesystem: ", directory.get_filesystem_type())
		_check(directory.get_filesystem_type() == "PCK", "res deve ser PCK, nunca filesystem da fonte")
	if not failures.is_empty():
		quit(1)
		return
	_enumerate("res://")
	files.sort()
	for path: String in files:
		print("PACK: ", path)
		var relative := path.trim_prefix("res://").to_lower()
		for segment: String in relative.split("/"):
			_check(segment not in FORBIDDEN_DIRECTORIES, "diretório de desenvolvimento no pack: " + path)
		_check(relative.get_extension() not in ["md", "ps1", "cs", "gd", "gdc", "exe", "pck", "tpz"],
			"arquivo de desenvolvimento no pack: " + path)
		_check(relative.get_file() not in ["project.godot", "export_presets.cfg", ".env", "credentials.json"],
			"fonte/configuração de desenvolvimento no pack: " + path)
	_check("res://project.binary" in files, "configuração exportada project.binary deve estar no pack")
	_check(not FileAccess.file_exists("res://project.godot"), "fonte project.godot deve estar ausente")
	_check(not DirAccess.dir_exists_absolute("res://tests"), "tests deve estar ausente")
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == MAIN_SCENE, "configuração deve selecionar fundação")
	# Cenas podem estar convertidas e remapped: não exigir o .tscn bruto no PCK.
	_check(ResourceLoader.exists(MAIN_SCENE, "PackedScene"), "cena deve existir via ResourceLoader no pack")
	if ResourceLoader.exists(MAIN_SCENE, "PackedScene"):
		var packed := ResourceLoader.load(MAIN_SCENE, "PackedScene") as PackedScene
		_check(packed != null, "cena empacotada deve carregar")
		if packed != null:
			var instance := packed.instantiate()
			_check(instance is Control, "cena empacotada deve instanciar a interface")
			instance.free()
	print("Audit: %d arquivos empacotados, %d falhas" % [files.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _enumerate(path: String) -> void:
	var directory := DirAccess.open(path)
	_check(directory != null, "diretório empacotado deve abrir: " + path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.include_navigational = false
	for file: String in directory.get_files():
		files.append(path.path_join(file))
	for child: String in directory.get_directories():
		_enumerate(path.path_join(child))

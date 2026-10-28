extends SceneTree
## Captura somente a textura da fundação, sem desktop e sem redimensionar a imagem.

const TARGET := Vector2i(1920, 1080)
const BASE := Vector2i(1280, 720)
const MAIN_SCENE := "res://src/game/foundation.tscn"
const OUTPUT := "res://.tools/s0/captures/task2-window-1920x1080.png"
const OFFSCREEN_OUTPUT := "res://.tools/s0/captures/task2-offscreen-1920x1080.png"
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	var method := RenderingServer.get_current_rendering_method()
	var adapter := RenderingServer.get_video_adapter_name()
	print("Capture display=%s renderer=%s adapter=%s" % [DisplayServer.get_name(), method, adapter])
	_check(DisplayServer.get_name() != "headless" and not adapter.is_empty(), "captura exige renderer gráfico real, não dummy/headless")
	_check(method == "gl_compatibility", "captura exige Compatibility real")
	_check(root.content_scale_size == BASE, "content_scale_size deve permanecer 1280x720")
	_check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "canvas_items deve permanecer inalterado")
	_check(ResourceLoader.exists(MAIN_SCENE, "PackedScene"), "fundação deve existir")
	if not failures.is_empty():
		quit(1)
		return
	# Somente o harness altera a janela; configuração e cena de produção são preservadas.
	root.mode = Window.MODE_WINDOWED
	root.current_screen = 0
	root.borderless = true
	root.position = DisplayServer.screen_get_position(0)
	root.size = TARGET
	var packed := ResourceLoader.load(MAIN_SCENE, "PackedScene") as PackedScene
	_check(packed != null, "fundação deve carregar")
	if packed == null:
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	# Aguardar layout, eventos da janela e desenho real; watchdog evita travar sem desenho.
	create_timer(15.0).timeout.connect(func() -> void:
		printerr("FAIL: captura não terminou em 15 segundos")
		quit(1))
	for frame in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var client := DisplayServer.window_get_size(root.get_window_id())
	var viewport := root.get_visible_rect().size
	print("Capture window=%s client=%s viewport=%s image=%s base=%s scale_mode=%d screen=%d borderless=%s" %
		[root.size, client, viewport, image.get_size(), root.content_scale_size,
		root.content_scale_mode, root.current_screen, root.borderless])
	_check_layout(instance, root.get_visible_rect())
	_check(root.content_scale_size == BASE and root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,
		"escala base deve permanecer inalterada após desenho")
	var window_ok := root.size == TARGET and client == TARGET and image.get_size() == TARGET
	if window_ok:
		_save(image, OUTPUT)
	else:
		printerr("Janela1080 indisponível; produzindo evidência offscreen separada, sem validar janela1080.")
		var offscreen := SubViewport.new()
		offscreen.size = TARGET
		offscreen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(offscreen)
		var separate := packed.instantiate()
		offscreen.add_child(separate)
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var texture := offscreen.get_texture().get_image()
		print("Capture OFFSCREEN viewport=%s image=%s (não é janela1080)" % [offscreen.size, texture.get_size()])
		_check(texture.get_size() == TARGET, "textura offscreen deve ser 1920x1080")
		_check_layout(separate, offscreen.get_visible_rect())
		if texture.get_size() == TARGET:
			_save(texture, OFFSCREEN_OUTPUT)
		offscreen.free()
	_check(window_ok, "janela cliente e imagem devem medir 1920x1080; offscreen não satisfaz este critério")
	print("Capture: %d falhas" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _check_layout(instance: Node, bounds: Rect2) -> void:
	for label_name: String in ["Title", "Status"]:
		var label := instance.find_child(label_name, true, false) as Label
		_check(label != null, "texto deve estar presente: " + label_name)
		if label == null:
			continue
		_check(label.is_visible_in_tree(), "texto deve estar visível: " + label_name)
		_check(label.size.x >= label.get_minimum_size().x and label.size.y >= label.get_minimum_size().y,
			"texto deve caber no controle: " + label_name)
		_check(bounds.encloses(label.get_global_rect()), "texto deve caber no viewport: " + label_name)


func _save(image: Image, path: String) -> void:
	_check(not FileAccess.file_exists(path), "captura preexistente deve ser preservada: " + path)
	if FileAccess.file_exists(path):
		return
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) == OK,
		"diretório de captura deve ser criado")
	var result := image.save_png(path)
	_check(result == OK, "PNG deve ser salvo: " + path)
	if result == OK:
		var decoded := Image.load_from_file(path)
		_check(decoded != null and decoded.get_size() == TARGET, "PNG decodificado deve ser 1920x1080")
		print("Capture PNG: %s dimensions=%s" % [ProjectSettings.globalize_path(path), decoded.get_size()])

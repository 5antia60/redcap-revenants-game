extends SceneTree
## Captura automatizada da janela gráfica real da FONTE, não de export/hardware manual.

const BASE := Vector2i(1280, 720)
var _failed: bool = false
var _destination: String


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("CAPTURE_FAIL: ", message)


func _run() -> void:
	create_timer(30.0, true, false, true).timeout.connect(func() -> void:
		printerr("CAPTURE_WATCHDOG")
		quit(1))
	var args := OS.get_cmdline_user_args()
	_check(args.size() == 1 and args[0] in ["720", "1080"], "escolha explícita720/1080")
	_check(DisplayServer.get_name() != "headless" and not RenderingServer.get_video_adapter_name().is_empty(), "exige janela/renderer reais")
	_check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "Compatibility real")
	if _failed:
		quit(1)
		return
	var target := BASE if args[0] == "720" else Vector2i(1920, 1080)
	_destination = "res://.tools/s1/captures/task2-%s-%s" % [args[0], Time.get_ticks_usec()]
	_check(not DirAccess.dir_exists_absolute(_destination), "destino novo sem sobrescrita")
	_check(DirAccess.make_dir_recursive_absolute(_destination) == OK, "diretório novo de captura")
	root.mode = Window.MODE_WINDOWED
	root.borderless = true
	root.current_screen = 0
	root.position = DisplayServer.screen_get_position(0)
	root.size = target
	var main := load("res://src/game/main.tscn").instantiate() as Node2D
	root.add_child(main)
	var lab := main.get_node("MovementLab")
	var player := lab.get_node("Actors/Player") as CharacterBody2D
	var adapter := lab.get_node("PlayerInput")
	var camera := player.get_node("Camera2D") as Camera2D
	var annotation := Label.new()
	annotation.text = "CAPTURA AUTOMATIZADA DA FONTE · ENTRADA SINTÉTICA · NÃO É ACEITE MANUAL"
	annotation.position = Vector2(24, 677)
	annotation.add_theme_font_size_override("font_size", 16)
	annotation.add_theme_color_override("font_color", Color(1, 0.93, 0.72))
	annotation.add_theme_color_override("font_shadow_color", Color(0.05, 0.1, 0.13))
	annotation.add_theme_constant_override("shadow_offset_x", 1)
	annotation.add_theme_constant_override("shadow_offset_y", 1)
	lab.get_node("HUD").add_child(annotation)
	for stage: Dictionary in [
		{"name": "01-start", "position": Vector2(800, 500)},
		{"name": "02-behind", "position": Vector2(1100, 485)},
		{"name": "03-side", "position": Vector2(1020, 520)},
		{"name": "04-front", "position": Vector2(1100, 565)},
		{"name": "05-focus-lost", "position": Vector2(800, 500)},
		{"name": "06-disconnected", "position": Vector2(800, 500)}]:
		adapter.set_focus_active(true)
		player.position = stage.position
		player.apply_intent(Vector2.ZERO, Vector2.RIGHT)
		if stage.name == "05-focus-lost":
			adapter.set_focus_active(false)
		elif stage.name == "06-disconnected":
			adapter.sample_joypad(901, Vector2.ZERO, Vector2.UP)
			adapter._on_joy_connection_changed(901, false)
		camera.force_update_scroll()
		for frame in range(8):
			await process_frame
			await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var client := DisplayServer.window_get_size(root.get_window_id())
		print("CAPTURE stage=%s window=%s client=%s image=%s base=%s display=%s renderer=%s adapter=%s feet=%s camera=%s" % [
			stage.name, root.size, client, image.get_size(), root.content_scale_size,
			DisplayServer.get_name(), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(),
			player.global_position, camera.get_screen_center_position()])
		_check(root.size == target and client == target and image.get_size() == target, "dimensão real de janela/cliente/imagem")
		_check(root.content_scale_size == BASE and root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "base lógica preservada")
		if stage.name in ["02-behind", "03-side", "04-front"]:
			var prop := lab.get_node("Actors/TallProp") as Node2D
			var silhouette := prop.get_global_transform_with_canvas() * Rect2(-60, -180, 120, 200)
			for panel_name: String in ["Panel", "Help"]:
				var panel := lab.get_node_or_null("HUD/" + panel_name) as Control
				if panel != null:
					_check(not panel.get_global_rect().intersects(silhouette), "HUD não encobre silhueta integral do prop: " + String(stage.name))
		if stage.name in ["02-behind", "04-front"]:
			# Amostra em sobreposição real: o prop oculta o corpo atrás; a cabeça
			# aparece na frente. O ponto diagnóstico nos pés não participa da prova.
			var local := Vector2(0, -20) if stage.name == "02-behind" else Vector2(0, -34)
			# A textura nativa inclui o stretch da janela; o transform do ator é lógico.
			var pixel := Vector2i(root.get_stretch_transform() * player.get_global_transform_with_canvas() * local)
			var actual := image.get_pixelv(pixel)
			var expected := Color(0.56, 0.29, 0.19) if stage.name == "02-behind" else Color(0.94, 0.7, 0.4)
			_check(absf(actual.r - expected.r) < 0.02 and absf(actual.g - expected.g) < 0.02
				and absf(actual.b - expected.b) < 0.02, "oclusão real do corpo por Y-sort: " + String(stage.name))
			print("CAPTURE_OCCLUSION: stage=%s pixel=%s color=%s expected=%s" % [stage.name, pixel, actual, expected])
		for label_name: String in ["Title", "Instructions", "State", "Recovery"]:
			var label := lab.get_node("HUD").find_child(label_name, true, false) as Label
			_check(label.is_visible_in_tree() and label.size.x >= label.get_minimum_size().x
				and label.size.y >= label.get_minimum_size().y, "texto sem recorte: " + label_name)
			_check(Rect2(Vector2.ZERO, Vector2(BASE)).encloses(label.get_global_rect()), "texto dentro da base lógica: " + label_name)
		var recovery := lab.get_node("HUD").find_child("Recovery", true, false) as Label
		_check(recovery.text.contains("pressione novamente"), "recuperação explica nova pressão de tecla")
		if not _failed:
			var path := _destination.path_join(stage.name + ".png")
			_check(not FileAccess.file_exists(path), "preservar captura existente")
			if not FileAccess.file_exists(path):
				_check(image.save_png(path) == OK, "salvar PNG sem redimensionamento")
				var decoded := Image.load_from_file(path)
				_check(decoded != null and decoded.get_size() == target, "PNG decodificado em dimensão nativa")
				print("CAPTURE_PNG: ", ProjectSettings.globalize_path(path))
	main.free()
	print("CAPTURE_RESULT: failed=%s" % _failed)
	quit(1 if _failed else 0)

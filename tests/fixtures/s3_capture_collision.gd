extends "res://tests/capture_first_encounter.gd"
## Exercita a mesma gravação PNG do harness, não uma cópia da guarda.
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_valid_identifier():
		quit(1)
		return
	destination = "res://.tools/s3/unit2-capture-" + args[0]
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var accepted := _write_png(image, destination.path_join("11-reinicio-final.png"))
	print("LATE_PNG_GUARD accepted=", accepted)
	quit(0 if accepted else 1)

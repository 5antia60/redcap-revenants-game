extends RefCounted
## Injeta somente composição legada; pausa/menu/reinício continuam sendo Main real.

static func instantiate() -> Node2D:
	var main := preload("res://src/game/main.tscn").instantiate()
	var initial := main.get_node("FirstEncounter")
	main.remove_child(initial)
	initial.free()
	main.arena_scene = preload("res://src/arenas/movement_lab.tscn")
	main.add_child(main.arena_scene.instantiate())
	return main

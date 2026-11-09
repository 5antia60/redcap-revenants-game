extends RefCounted
## Orçamento exato de callbacks nativos; nunca chama física de atores manualmente.
class Budget extends Node:
	signal finished
	var actors: Array[Node] = []
	var budget: int
	var observed := 0
	func _physics_process(_delta: float) -> void:
		observed += 1
		if observed == budget:
			for actor: Node in actors:
				if is_instance_valid(actor):
					actor.set_physics_process(false)
			set_physics_process(false)
			finished.emit()

static func run(tree: SceneTree, actors: Array[Node], count: int) -> bool:
	if count < 1 or count > 600 or actors.is_empty():
		return false
	var observer := Budget.new()
	observer.actors = actors
	observer.budget = count
	observer.process_mode = Node.PROCESS_MODE_ALWAYS
	observer.process_physics_priority = 100
	tree.root.add_child(observer)
	for actor: Node in actors:
		actor.set_physics_process(true)
	await observer.finished
	var completed := observer.observed == count
	await tree.process_frame
	observer.free()
	return completed

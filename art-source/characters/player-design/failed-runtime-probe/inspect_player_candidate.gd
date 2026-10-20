extends SceneTree

func _init() -> void:
	var scene: Node = load("res://assets/characters/original-procedural-office-characters/original_player_candidate.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_print_tree(scene, 0)
	quit()

func _print_tree(node: Node, depth: int) -> void:
	print("  ".repeat(depth), node.name, " [", node.get_class(), "]")
	for child in node.get_children():
		_print_tree(child, depth + 1)

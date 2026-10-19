extends SceneTree

const ASSET_PATH := "res://assets/characters/quaternius-superhero-male/character.glb"

func _init() -> void:
	var packed := load(ASSET_PATH)
	if not packed is PackedScene:
		push_error("Quaternius 候选不是 PackedScene：" + ASSET_PATH)
		quit(1)
		return
	var root: Node = packed.instantiate()
	print("候选根节点：", root.name, " 类型：", root.get_class())
	_print_tree(root, 0)
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	for item in skeletons:
		var skeleton := item as Skeleton3D
		print("骨骼：", skeleton.get_path(), " 数量：", skeleton.get_bone_count())
		for bone_index in range(skeleton.get_bone_count()):
			print("  骨骼[", bone_index, "]：", skeleton.get_bone_name(bone_index))
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	for item in meshes:
		var mesh := item as MeshInstance3D
		print("网格：", mesh.get_path(), " 包围盒：", mesh.get_aabb())
		if mesh.mesh != null:
			for surface_index in range(mesh.mesh.get_surface_count()):
				print("  表面[", surface_index, "] 材质：", mesh.mesh.surface_get_material(surface_index))
	var animation_players := root.find_children("*", "AnimationPlayer", true, false)
	for item in animation_players:
		var player := item as AnimationPlayer
		print("动画播放器：", player.get_path(), " 动画库：", player.get_animation_list())
	root.free()
	quit(0)

func _print_tree(node: Node, depth: int) -> void:
	var prefix := "  ".repeat(depth)
	print(prefix, node.name, " [", node.get_class(), "]")
	for child in node.get_children():
		_print_tree(child, depth + 1)

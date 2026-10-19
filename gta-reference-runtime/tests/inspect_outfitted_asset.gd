extends SceneTree

const ASSET_PATH := "res://assets/characters/quaternius-superhero-male/character_outfitted.glb"

func _init() -> void:
	var packed := load(ASSET_PATH)
	if not packed is PackedScene:
		push_error("原创服装候选没有导入为 PackedScene：" + ASSET_PATH)
		quit(1)
		return
	var root: Node = packed.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	var outfit_meshes := meshes.filter(func(item: Node) -> bool: return str(item.name).begins_with("Outfit_"))
	var names := outfit_meshes.map(func(item: Node) -> String: return str(item.name))
	print("原创服装候选：网格 ", meshes.size(), "；骨骼 ", skeletons.size(), "；服装对象 ", names)
	if skeletons.size() != 1 or outfit_meshes.size() < 10:
		push_error("原创服装候选缺少骨骼或服装网格")
		root.free()
		quit(1)
		return
	var skeleton := skeletons[0] as Skeleton3D
	for required_bone in ["spine_02", "spine_03", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r", "foot_l", "foot_r", "Head"]:
		if skeleton.find_bone(required_bone) < 0:
			push_error("原创服装候选缺少运行时骨骼：" + required_bone)
			root.free()
			quit(1)
			return
	root.free()
	print("原创服装候选导入与骨骼契约验证通过")
	quit(0)

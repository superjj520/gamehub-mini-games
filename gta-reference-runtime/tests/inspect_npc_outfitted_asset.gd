extends SceneTree

const ASSET_PATH := "res://assets/characters/quaternius-superhero-male/character_npc_outfitted.glb"

func _init() -> void:
	var packed := load(ASSET_PATH)
	if not packed is PackedScene:
		push_error("NPC 制服候选没有导入为 PackedScene：" + ASSET_PATH)
		quit(1)
		return
	var root: Node = packed.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	var outfit_meshes := meshes.filter(func(item: Node) -> bool: return str(item.name).begins_with("Outfit_"))
	var names := outfit_meshes.map(func(item: Node) -> String: return str(item.name))
	print("NPC 制服候选：网格 ", meshes.size(), "；骨骼 ", skeletons.size(), "；服装对象 ", names)
	if skeletons.size() != 1 or outfit_meshes.size() < 10 or names.has("Outfit_Backpack"):
		push_error("NPC 制服候选缺少骨骼、服装网格或意外带入背包")
		root.free()
		quit(1)
		return
	root.free()
	print("NPC 制服候选导入与角色差异契约验证通过")
	quit(0)

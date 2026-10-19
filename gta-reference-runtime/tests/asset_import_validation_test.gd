extends SceneTree

const ASSETS := [
	{
		"id": "b_small",
		"path": "res://assets/environment/quaternius-downtown/b_small.glb",
		"height_min": 16.0,
		"height_max": 18.0,
		"triangle_max": 20000,
	},
	{
		"id": "b_medium",
		"path": "res://assets/environment/quaternius-downtown/b_medium.glb",
		"height_min": 24.0,
		"height_max": 26.0,
		"triangle_max": 24000,
	},
	{
		"id": "b_large",
		"path": "res://assets/environment/quaternius-downtown/b_large.glb",
		"height_min": 27.0,
		"height_max": 29.0,
		"triangle_max": 36000,
	},
	{
		"id": "prop_ac",
		"path": "res://assets/environment/quaternius-downtown/prop_ac.glb",
		"height_min": 0.5,
		"height_max": 0.7,
		"triangle_max": 4000,
	},
]

func _init() -> void:
	var all_valid := true
	for asset in ASSETS:
		if not _validate_asset(asset):
			all_valid = false
	if all_valid:
		print("城市资产导入门禁通过：", ASSETS.size(), " 个 GLB；单位、底面原点、网格数量和三角面预算符合候选规范")
		quit(0)
	else:
		push_error("城市资产导入门禁失败；候选资产不得进入正式资产槽位")
		quit(1)

func _validate_asset(asset: Dictionary) -> bool:
	var asset_path := str(asset["path"])
	var packed := load(asset_path)
	if not packed is PackedScene:
		push_error("城市资产没有导入为 PackedScene：" + asset_path)
		return false
	var root: Node = packed.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_error("城市资产没有 MeshInstance3D：" + asset_path)
		root.free()
		return false
	var combined := AABB()
	var has_bounds := false
	var triangle_count := 0
	for item in meshes:
		var mesh_instance := item as MeshInstance3D
		var bounds := mesh_instance.transform * mesh_instance.get_aabb()
		if not has_bounds:
			combined = bounds
			has_bounds = true
		else:
			combined = combined.merge(bounds)
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
				var indices = arrays[Mesh.ARRAY_INDEX]
				var vertices = arrays[Mesh.ARRAY_VERTEX]
				triangle_count += int(indices.size() / 3) if indices is PackedInt32Array and not indices.is_empty() else int(vertices.size() / 3)
	var valid := true
	if combined.position.y < -0.05:
		push_error("%s 底面原点低于允许误差：%s" % [asset["id"], combined.position.y])
		valid = false
	if combined.size.y < float(asset["height_min"]) or combined.size.y > float(asset["height_max"]):
		push_error("%s 高度不在米制探针范围：%s" % [asset["id"], combined.size.y])
		valid = false
	if triangle_count > int(asset["triangle_max"]):
		push_error("%s 三角面超出候选预算：%d" % [asset["id"], triangle_count])
		valid = false
	print("  ", asset["id"], " bounds=", combined, " meshes=", meshes.size(), " triangles=", triangle_count)
	root.free()
	return valid

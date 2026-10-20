extends SceneTree

const ASSET_PATHS := [
	"res://assets/environment/quaternius-downtown/b_small.glb",
	"res://assets/environment/quaternius-downtown/b_medium.glb",
	"res://assets/environment/quaternius-downtown/b_large.glb",
	"res://assets/environment/quaternius-downtown/prop_ac.glb",
]

func _init() -> void:
	for asset_path in ASSET_PATHS:
		var packed := load(asset_path)
		if not packed is PackedScene:
			push_error("城市资产不是 PackedScene：" + asset_path)
			quit(1)
			return
		var root: Node = packed.instantiate()
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		var combined := AABB()
		var has_bounds := false
		for item in meshes:
			var mesh := item as MeshInstance3D
			var world_bounds := mesh.transform * mesh.get_aabb()
			if not has_bounds:
				combined = world_bounds
				has_bounds = true
			else:
				combined = combined.merge(world_bounds)
		print(asset_path, " meshes=", meshes.size(), " bounds=", combined)
		root.free()
	quit(0)

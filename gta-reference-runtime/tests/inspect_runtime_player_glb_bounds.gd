extends SceneTree

const ASSET_PATH := "res://assets/characters/original-procedural-office-characters/original_player_visual_v1.glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(ASSET_PATH) as PackedScene
	assert(packed != null, "无法加载运行时原创主角 GLB")
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var mesh_nodes := instance.find_children("*", "MeshInstance3D", true, false)
	var merged := AABB()
	var first := true
	for item in mesh_nodes:
		var mesh_instance := item as MeshInstance3D
		var local_box := mesh_instance.get_aabb()
		var world_box := mesh_instance.global_transform * local_box
		merged = world_box if first else merged.merge(world_box)
		first = false
	print("原创主角 GLB 节点=%d 包围盒位置=%s 大小=%s" % [mesh_nodes.size(), merged.position, merged.size])
	instance.free()
	quit(0)

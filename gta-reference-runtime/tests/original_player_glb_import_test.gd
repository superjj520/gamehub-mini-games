extends SceneTree

const ASSET_PATH := "res://tests/assets/original_player_visual_v1.glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(ASSET_PATH)
	assert(packed is PackedScene, "原创主角 GLB 候选没有被 Godot 导入为 PackedScene")
	var instance := (packed as PackedScene).instantiate()
	root.add_child(instance)
	await process_frame
	var mesh_nodes := instance.find_children("*", "MeshInstance3D", true, false)
	assert(mesh_nodes.size() == 43, "原创主角 GLB 候选网格数量不符合结构证据")
	var material_names: Dictionary = {}
	for item in mesh_nodes:
		var mesh_instance := item as MeshInstance3D
		assert(mesh_instance.mesh != null, "原创主角 GLB 候选存在空网格：" + mesh_instance.name)
		for surface_index in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface_index)
			assert(material != null, "原创主角 GLB 候选存在空材质：" + mesh_instance.name)
			material_names[str(material.resource_name)] = true
	assert(material_names.size() == 12, "原创主角 GLB 候选材质数量不符合结构证据")
	assert(ASSET_PATH.begins_with("res://tests/"), "原创主角 GLB 导入测试不得读取正式运行时资产")
	instance.free()
	print("原创主角 GLB 候选 Godot 导入验证通过：%d 个网格、%d 个材质" % [mesh_nodes.size(), material_names.size()])
	quit(0)


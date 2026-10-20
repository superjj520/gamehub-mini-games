extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://metal_office_desk_1k.glb") as PackedScene
	assert(packed != null, "Poly Haven 办公桌 glTF 没有作为 PackedScene 导入")
	var instance := packed.instantiate()
	get_root().add_child(instance)
	await process_frame
	await process_frame
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 9, "办公桌网格数量异常：%d" % meshes.size())
	var triangle_count := 0
	var material_count := 0
	var bounds := AABB()
	var has_bounds := false
	for item in meshes:
		var mesh_instance := item as MeshInstance3D
		assert(mesh_instance.mesh != null, "办公桌存在无网格节点：%s" % item.name)
		var item_bounds := mesh_instance.get_aabb()
		item_bounds.position += mesh_instance.position
		if not has_bounds:
			bounds = item_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(item_bounds)
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material = mesh_instance.get_active_material(surface_index)
			assert(material != null, "办公桌表面材质缺失：%s/%d" % [item.name, surface_index])
			material_count += 1
			triangle_count += mesh_instance.mesh.get_faces().size() / 3
	assert(triangle_count > 0, "办公桌三角面统计失败")
	assert(material_count > 0, "办公桌材质槽统计失败")
	assert(absf(bounds.position.y) < 0.05, "办公桌底面原点偏离 Y=0：%f" % bounds.position.y)
	assert(bounds.size.x > 1.8 and bounds.size.x < 2.2, "办公桌宽度不符合米制尺寸：%s" % bounds.size)
	assert(bounds.size.y > 0.7 and bounds.size.y < 0.9, "办公桌高度不符合米制尺寸：%s" % bounds.size)
	print("Poly Haven 办公桌候选导入通过：网格 %d；三角面 %d；材质槽 %d" % [meshes.size(), triangle_count, material_count])
	instance.free()
	await process_frame
	var candidate_scene := load("res://office_desk_candidate.tscn") as PackedScene
	assert(candidate_scene != null, "办公桌候选封装场景导入失败")
	var candidate := candidate_scene.instantiate()
	get_root().add_child(candidate)
	await process_frame
	assert(candidate.get_node_or_null("Geometry") != null, "办公桌候选缺少 Geometry 节点")
	assert(candidate.get_node_or_null("近似碰撞体") != null, "办公桌候选缺少近似碰撞体")
	assert(candidate.get_node_or_null("交互挂点") != null, "办公桌候选缺少交互挂点")
	assert(candidate.get_node_or_null("显示器挂点") != null, "办公桌候选缺少显示器挂点")
	var collision := candidate.get_node("近似碰撞体") as CollisionShape3D
	assert(collision.shape is BoxShape3D, "办公桌候选碰撞体不是 BoxShape3D")
	assert((collision.shape as BoxShape3D).size.y > 0.8, "办公桌候选碰撞高度不符合米制尺寸")
	print("Poly Haven 办公桌候选场景封装通过：视觉、碰撞和挂点完整")
	candidate.free()
	await process_frame
	var composition_scene := load("res://office_desk_composition.tscn") as PackedScene
	assert(composition_scene != null, "办公室工位组合场景导入失败")
	var composition := composition_scene.instantiate()
	get_root().add_child(composition)
	await process_frame
	var desks := composition.find_children("*", "StaticBody3D", true, false)
	assert(desks.size() == 10, "办公室工位组合数量异常：%d" % desks.size())
	var center_workstation_found := false
	for candidate in composition.find_children("*", "Node3D", true, false):
		if str(candidate.get_meta("candidate_workstation_role", "")) == "office_10_center":
			center_workstation_found = true
			break
	assert(center_workstation_found, "办公室工位组合缺少与正式 office-10 交互坐标对齐的中心候选工位")
	assert(composition.get_node_or_null("固定审阅镜头") != null, "办公室工位组合缺少固定审阅镜头")
	assert(composition.get_node_or_null("办公室主光") != null, "办公室工位组合缺少主光")
	print("办公室工位组合候选通过：10 个工位、中心 office-10 对齐标记、固定镜头和灯光完整")
	composition.free()
	await process_frame
	quit(0)

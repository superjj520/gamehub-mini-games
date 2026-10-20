extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://interaction_props_kit.glb") as PackedScene
	if scene == null:
		_fail("原创交互道具 GLB 无法作为 PackedScene 加载")
		return
	var instance := scene.instantiate()
	get_root().add_child(instance)
	for _frame in range(3):
		await process_frame
	var root: Node = instance if instance.name == "InteractionPropsKit" else instance.get_node_or_null("InteractionPropsKit")
	if root == null or root.name != "InteractionPropsKit":
		_fail("GLB 缺少 InteractionPropsKit 根节点")
		return
	for required_name in ["EggTray_Interaction", "ScanBoard_Interaction", "DeliveryMarker_Interaction", "ShopBasket_Interaction"]:
		if root.get_node_or_null(required_name) == null:
			_fail("GLB 缺少表现分组：%s" % required_name)
			return
	var bounds := _bounds(instance)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		_fail("GLB 尺寸探针无效：%s" % bounds)
		return
	if bounds.size.y > 3.0 or bounds.size.x > 5.0 or bounds.size.z > 5.0:
		_fail("交互道具候选尺寸超过小型道具预算：%s" % bounds)
		return
	print("原创交互道具候选 GLB 导入与命名/尺寸契约通过：%s" % bounds)
	instance.free()
	quit(0)

func _bounds(node: Node) -> AABB:
	var result := AABB()
	var initialized := false
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local_box := mesh.mesh.get_aabb()
		var world_box := mesh.global_transform * local_box
		if not initialized:
			result = world_box
			initialized = true
		else:
			result = result.merge(world_box)
	return result

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

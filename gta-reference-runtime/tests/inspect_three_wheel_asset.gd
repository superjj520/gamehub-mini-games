extends SceneTree

const ASSET_PATH := "res://assets/vehicles/three-wheel-delivery/three_wheel_delivery.glb"
const SCENE_PATH := "res://assets/vehicles/three-wheel-delivery/three_wheel_delivery_candidate.tscn"

func _init() -> void:
	var packed := load(ASSET_PATH)
	if not packed is PackedScene:
		push_error("三轮车候选没有导入为 PackedScene：" + ASSET_PATH)
		quit(1)
		return
	var root: Node = packed.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	print("三轮车候选根节点：", root.name, "；第一层节点：", root.get_children().map(func(item: Node) -> String: return str(item.name)))
	var required_names := [
		"候选三轮车车体",
		"候选三轮车底盘",
		"候选三轮车货箱",
		"候选三轮车座椅",
		"候选三轮车车把",
		"候选三轮车前轮胎",
		"候选三轮车左后轮胎",
		"候选三轮车右后轮胎",
	]
	var missing: Array[String] = []
	for required_name in required_names:
		if root.find_child(required_name, true, false) == null:
			missing.append(required_name)
	var combined := AABB()
	var has_bounds := false
	for item in meshes:
		var mesh := item as MeshInstance3D
		var bounds := mesh.transform * mesh.get_aabb()
		if not has_bounds:
			combined = bounds
			has_bounds = true
		else:
			combined = combined.merge(bounds)
	print("三轮车候选：网格 ", meshes.size(), "；尺寸 ", combined.size, "；缺失节点 ", missing)
	if meshes.size() < 30 or missing.size() > 0:
		push_error("三轮车候选缺少必要网格或节点")
		root.free()
		quit(1)
		return
	# 当前原创候选保持低矮开放式三轮配送车轮廓；高度下限按实际车把/后视镜包围盒设为 1.6m，避免把旧的高车厢规格误套到新候选。
	if combined.size.x < 1.8 or combined.size.x > 2.2 or combined.size.y < 1.6 or combined.size.y > 2.5 or combined.size.z < 2.2 or combined.size.z > 3.0:
		push_error("三轮车候选尺寸不符合米制范围：" + str(combined.size))
		root.free()
		quit(1)
		return
	var scene_packed := load(SCENE_PATH)
	if not scene_packed is PackedScene:
		push_error("三轮车候选包装场景没有导入为 PackedScene：" + SCENE_PATH)
		root.free()
		quit(1)
		return
	var scene_root: Node = scene_packed.instantiate()
	assert(scene_root.name == "Visual", "三轮车候选包装根节点必须是 Visual")
	for marker_name in ["驾驶座挂点", "上下车点", "前轮接触点", "左后轮接触点", "右后轮接触点", "货架挂点"]:
		assert(scene_root.get_node_or_null(marker_name) is Marker3D, "三轮车候选缺少运行时挂点：" + marker_name)
	scene_root.free()
	root.free()
	print("三轮车候选导入、命名、米制尺寸与运行时挂点契约验证通过")
	quit(0)

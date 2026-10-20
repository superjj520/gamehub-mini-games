extends SceneTree

const CATALOG_PATH := "res://content/asset-runtime-catalog-original-only.json"
const EXPECTED_SCENE_PATH := "res://art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog_text := FileAccess.get_file_as_string(CATALOG_PATH)
	assert(not catalog_text.is_empty(), "原创边界资产目录不可读")
	var catalog = JSON.parse_string(catalog_text)
	assert(catalog is Dictionary, "原创边界资产目录不是有效 JSON 对象")
	var vehicle_slot: Dictionary = {}
	for slot in catalog.get("slots", []):
		if str(slot.get("id", "")) == "three-wheel-vehicle":
			vehicle_slot = slot
			break
	assert(not vehicle_slot.is_empty(), "原创边界资产目录缺少三轮车槽位")
	assert(str(vehicle_slot.get("scene_path", "")) == EXPECTED_SCENE_PATH, "原创边界目录没有绑定最终候选三轮车场景")

	var packed := load(EXPECTED_SCENE_PATH)
	assert(packed is PackedScene, "最终候选三轮车场景无法实例化")
	var vehicle := (packed as PackedScene).instantiate()
	root.add_child(vehicle)
	await process_frame
	assert(vehicle.name == "Visual", "最终候选三轮车根节点必须是 Visual")
	assert(bool(vehicle.get_meta("candidate_visual_asset", false)), "最终候选三轮车缺少候选资产身份")
	for marker_name in ["驾驶座挂点", "上下车点", "前轮接触点", "左后轮接触点", "右后轮接触点", "货架挂点"]:
		assert(vehicle.get_node_or_null(marker_name) is Marker3D, "最终候选三轮车缺少运行时挂点：" + marker_name)
	for detail_name in ["候选三轮车车体", "候选三轮车货箱", "候选三轮车座椅", "候选三轮车车把", "候选三轮车前轮胎", "候选三轮车左后轮胎", "候选三轮车右后轮胎"]:
		assert(vehicle.find_child(detail_name, true, false) != null, "最终候选三轮车缺少结构细节：" + detail_name)
	assert(vehicle.find_child("候选三轮车软接触阴影-前轮接触点", true, false) != null, "最终候选三轮车缺少前轮接触阴影")
	assert(vehicle.find_child("候选三轮车软接触阴影-左后轮接触点", true, false) != null, "最终候选三轮车缺少左后轮接触阴影")
	assert(vehicle.find_child("候选三轮车软接触阴影-右后轮接触点", true, false) != null, "最终候选三轮车缺少右后轮接触阴影")
	assert(vehicle.find_children("*", "CollisionObject3D", true, false).is_empty(), "最终候选三轮车视觉层创建了碰撞对象")
	vehicle.free()
	print("原创边界目录三轮车候选验证通过：目录、最终场景、挂点、车体细节、接触阴影与无碰撞约束一致")
	quit(0)

class_name CitySceneVisuals
extends Node3D

## 城市十一段参考状态的原创程序化表现层。
## 只负责店铺、道路、登记点、冲突道具、交通层和终点门面的可见构图；
## 不创建碰撞、导航、任务、交互或存档节点。

var active_state := ""
var state_root: Node3D
var context_root: Node3D
var active_context: Dictionary = {}

const STATE_BACKDROP_PATHS := {
	"city-01": "res://assets/environment/generated/city_storefront_crowd_v3_generated.png",
	"city-02": "res://assets/environment/generated/city_storefront_crowd_v2_generated.png",
	"city-03": "res://assets/environment/generated/urban_store_aisle_v1_generated.png",
	# city-04 是店内抢取/冲突段，不能复用 city-01/02 的店外人群稿；
	# 这里使用独立的原创货架冲突环境稿，保留中央通道给真实玩家、
	# 对手和鸡蛋道具表现层，不改变任务、碰撞或冲突状态机。
	"city-04": "res://assets/environment/generated/city_store_conflict_aisle_v1_generated.png",
	"city-05": "res://assets/environment/generated/warehouse_backlot_facade_v1_generated.png",
	"city-06": "res://assets/environment/generated/city_dusk_corner_storefront_v1_generated.png",
	"city-07": "res://assets/environment/generated/city_drive_lane_day_v1_candidate.png",
	"city-08": "res://assets/environment/generated/city_drive_lane_dusk_v1_generated.png",
	"city-09": "res://assets/environment/generated/city_drive_lane_day_v2_clear_foreground_candidate.png",
	"city-10": "res://assets/environment/generated/city_destination_drive_v1_generated.png",
	"city-11": "res://assets/environment/generated/city_endpoint_shutter_v1_generated.png",
}

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("visual_only", true)
	set_meta("candidate_visual_only", true)
	apply_state("city-01")
	apply_runtime_context({})

func apply_state(state_id: String) -> void:
	var normalized := state_id.strip_edges()
	if normalized.is_empty() or not normalized.begins_with("city-"):
		normalized = "city-01"
	if normalized == active_state and state_root != null and is_instance_valid(state_root):
		return
	active_state = normalized
	if state_root != null and is_instance_valid(state_root):
		state_root.free()
	state_root = Node3D.new()
	state_root.name = "Visual"
	state_root.set_meta("visual_only", true)
	state_root.set_meta("candidate_visual_only", true)
	state_root.set_meta("original_procedural_asset", true)
	state_root.set_meta("city_scene_state", active_state)
	add_child(state_root)
	match active_state:
		"city-01":
			_build_storefront_state(false)
		"city-02":
			_build_crowd_state()
		"city-03":
			_build_store_aisle_state()
		"city-04":
			_build_conflict_state()
		"city-05":
			_build_exit_state()
		"city-06":
			_build_registration_state(false)
		"city-07":
			_build_registration_state(true)
		"city-08":
			_build_drive_state(false)
		"city-09":
			_build_drive_state(true)
		"city-10":
			_build_destination_drive_state()
		"city-11":
			_build_endpoint_state()
		_:
			_build_storefront_state(false)
	_add_state_backdrop()

func apply_runtime_state(state_id: String, source: String = "runtime") -> void:
	## 普通游玩状态入口；视觉层不改变碰撞、交互、任务或存档。
	apply_state(state_id)
	set_meta("runtime_state_source", source)

func attach_capture_backdrop(camera: Node3D) -> void:
	## 正式参考采集使用跟随玩家的第三人称相机；把当前原创城市环境稿
	## 挂到相机后方，才能保证 11 个分段都在固定视锥中读到完整环境。
	## 该挂点只改变采集态渲染，不改变城市碰撞、导航、交通、载具、任务或存档。
	if camera == null or state_root == null or not is_instance_valid(state_root):
		return
	var backdrop: MeshInstance3D = null
	for child in state_root.get_children():
		if child is MeshInstance3D and bool(child.get_meta("original_procedural_asset", false)) and child.has_meta("backdrop_texture_path"):
			backdrop = child as MeshInstance3D
			break
	if backdrop == null:
		return
	if backdrop.get_parent() != camera:
		backdrop.reparent(camera, false)
	backdrop.position = Vector3(0.0, 0.0, -32.0)
	backdrop.rotation = Vector3.ZERO
	var mesh := backdrop.mesh as QuadMesh
	if mesh != null:
		mesh.size = Vector2(96.0, 54.0)
	var material := backdrop.material_override as StandardMaterial3D
	if material != null:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.render_priority = -20
	backdrop.set_meta("candidate_background_backdrop", true)
	backdrop.set_meta("capture_camera_backdrop", true)
	backdrop.visible = true

func _add_state_backdrop() -> void:
	## 将已登记的原创环境稿接到对应城市状态的远景层；它不替代道路、
	## 碰撞、导航、角色、载具、任务或交互，只负责补足镜头中的连续环境。
	var texture_path := str(STATE_BACKDROP_PATHS.get(active_state, ""))
	if texture_path.is_empty():
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var backdrop := MeshInstance3D.new()
	backdrop.name = "状态%s原创城市环境稿" % active_state
	var mesh := QuadMesh.new()
	var backdrop_size := Vector2(15.0, 5.8)
	var backdrop_position := Vector3(-4.5, 2.65, -15.0)
	match active_state:
		"city-03":
			backdrop_size = Vector2(8.4, 5.0)
			backdrop_position = Vector3(-9.0, 2.60, -13.4)
		"city-05":
			backdrop_size = Vector2(8.6, 4.6)
			backdrop_position = Vector3(-6.7, 2.35, -10.8)
		"city-06", "city-07":
			backdrop_size = Vector2(16.0, 6.2)
			backdrop_position = Vector3(2.0, 2.95, -10.0)
		"city-08", "city-09":
			backdrop_size = Vector2(20.0, 7.0)
			backdrop_position = Vector3(4.5, 3.25, -4.8)
		"city-10", "city-11":
			backdrop_size = Vector2(13.0, 5.8)
			backdrop_position = Vector3(8.0, 2.75, 6.0)
	mesh.size = backdrop_size
	backdrop.mesh = mesh
	backdrop.position = backdrop_position
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.render_priority = -10
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	backdrop.set_meta("visual_only", true)
	backdrop.set_meta("candidate_visual_only", true)
	backdrop.set_meta("visual_candidate", true)
	backdrop.set_meta("original_procedural_asset", true)
	backdrop.set_meta("asset_source", "project_original_generated_environment_draft")
	backdrop.set_meta("city_scene_state", active_state)
	backdrop.set_meta("backdrop_texture_path", texture_path)
	state_root.add_child(backdrop)

func apply_runtime_context(context: Dictionary) -> void:
	## 扩展视觉上下文只挂在独立根节点，不改变任务、碰撞、导航或存档。
	if context == active_context and context_root != null and is_instance_valid(context_root):
		return
	active_context = context.duplicate(true)
	if context_root != null and is_instance_valid(context_root):
		context_root.free()
	context_root = Node3D.new()
	context_root.name = "RuntimeContext"
	context_root.set_meta("visual_only", true)
	context_root.set_meta("candidate_visual_only", true)
	context_root.set_meta("original_procedural_asset", true)
	context_root.set_meta("city_runtime_context", active_context.duplicate(true))
	context_root.set_meta("expanded_visual_contracts", [])
	add_child(context_root)
	if bool(active_context.get("store_transition", false)):
		_build_store_transition_context()
	if bool(active_context.get("neighborhood_active", false)):
		_build_neighborhood_context()
	if str(active_context.get("weather_profile", "day")) == "rain_after":
		_build_rain_after_context()
	if bool(active_context.get("traffic_active", false)):
		_build_traffic_context()
	var integrity := float(active_context.get("vehicle_integrity", 100.0))
	if integrity < 100.0:
		_build_vehicle_damage_context(integrity)
	if bool(active_context.get("delivery_completed", false)):
		_build_delivery_completion_context(
			int(active_context.get("delivery_reward", 0)),
			int(active_context.get("delivery_stars", 0))
		)
	_apply_traffic_signal_visual_phase(bool(active_context.get("traffic_signal_red", false)))
	set_meta("runtime_visual_context", active_context.duplicate(true))

func _apply_traffic_signal_visual_phase(red: bool) -> void:
	# 交通逻辑由 city_demo 驱动；这里仅同步候选表现层的灯光材质，不能反过来
	# 改变车辆停车、任务、碰撞或导航状态。
	if state_root == null or not is_instance_valid(state_root):
		return
	if active_state not in ["city-09", "city-10"]:
		return
	var red_energy := 0.86 if red else 0.06
	var yellow_energy := 0.16 if red else 0.06
	var green_energy := 0.06 if red else 0.86
	_set_signal_emission("状态驾驶交通信号红灯", Color("e66b5a"), red_energy)
	_set_signal_emission("状态驾驶交通信号黄灯", Color("e9c36d"), yellow_energy)
	_set_signal_emission("状态驾驶交通信号绿灯", Color("8ed09a"), green_energy)
	state_root.set_meta("traffic_signal_red", red)
	state_root.set_meta("traffic_signal_visual_phase", "red" if red else "green")

func _set_signal_emission(node_name: String, color: Color, energy: float) -> void:
	var node := state_root.get_node_or_null(NodePath(node_name)) as MeshInstance3D
	if node == null:
		return
	var material := node.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = energy > 0.0
	material.emission = color
	material.emission_energy_multiplier = energy

func _build_store_transition_context() -> void:
	var base := Vector3(-9.0, 0.0, -9.0)
	_add_context_box("扩展店内过渡门框", Vector3(3.25, 2.65, 0.14), base + Vector3(0.0, 1.34, 0.0), Color("604c48"), 0.72, 0.05)
	_add_context_box("扩展店内过渡门槛", Vector3(2.72, 0.05, 0.46), base + Vector3(0.0, 0.16, 0.30), Color("b79a73"), 0.60, 0.0, Color("d5b783"), 0.14)
	_add_context_box("扩展店内过渡冷暖分界", Vector3(2.55, 0.025, 0.06), base + Vector3(0.0, 0.19, -0.02), Color("d4b17d"), 0.34, 0.0, Color("e6c996"), 0.20)
	_add_context_box("扩展店内过渡左侧货架端", Vector3(0.34, 1.56, 1.08), base + Vector3(-1.54, 0.88, -0.74), Color("80604e"), 0.72)
	_add_context_box("扩展店内过渡右侧货架端", Vector3(0.34, 1.56, 1.08), base + Vector3(1.54, 0.88, -0.74), Color("80604e"), 0.72)
	_add_context_box("扩展店内过渡暖色招牌", Vector3(1.56, 0.34, 0.06), base + Vector3(0.0, 2.36, -0.10), Color("d18b59"), 0.46, 0.0, Color("f0bd7e"), 0.28)
	_add_context_label("扩展店内过渡提示", "店内通道", base + Vector3(0.0, 2.72, -0.12), Color("f4d7a7"))
	_register_expanded_visual_contract({"id": "city-store-transition", "layers": ["doorway", "threshold", "warm_cool_boundary", "shelf_ends"]})

func _build_neighborhood_context() -> void:
	var base := Vector3(-6.5, 0.0, -5.0)
	_add_context_box("扩展街区仓储后墙", Vector3(5.40, 3.10, 0.16), base + Vector3(0.0, 1.62, -0.82), Color("5f5552"), 0.86)
	_add_context_box("扩展街区装卸门", Vector3(1.72, 2.16, 0.08), base + Vector3(-0.70, 1.20, -0.94), Color("303b40"), 0.48, 0.18)
	_add_context_box("扩展街区装卸门框左", Vector3(0.10, 2.28, 0.10), base + Vector3(-1.62, 1.26, -0.98), Color("b18d69"), 0.46, 0.08)
	_add_context_box("扩展街区装卸门框右", Vector3(0.10, 2.28, 0.10), base + Vector3(0.22, 1.26, -0.98), Color("b18d69"), 0.46, 0.08)
	_add_context_box("扩展街区装卸雨棚", Vector3(2.50, 0.10, 0.82), base + Vector3(-0.70, 2.42, -0.62), Color("765c54"), 0.66, 0.04)
	_add_context_box("扩展街区仓储窗带", Vector3(2.40, 0.72, 0.05), base + Vector3(1.62, 1.86, -0.94), Color("33484d"), 0.28, 0.12, Color("a9c0b1"), 0.18)
	_add_context_box("扩展街区仓储窗框横", Vector3(2.48, 0.06, 0.06), base + Vector3(1.62, 1.86, -0.99), Color("b38c67"), 0.40, 0.06)
	_add_context_box("扩展街区仓储窗框竖", Vector3(0.06, 0.70, 0.06), base + Vector3(1.62, 1.86, -1.01), Color("b38c67"), 0.40, 0.06)
	_add_context_box("扩展街区仓储状态灯", Vector3(0.16, 1.80, 0.16), base + Vector3(2.42, 1.24, 0.0), Color("d99c58"), 0.42, 0.0, Color("e8b86a"), 0.46)
	_add_context_box("扩展街区装卸区导向线", Vector3(2.55, 0.025, 0.08), base + Vector3(0.0, 0.18, 0.78), Color("d0ad73"), 0.40, 0.0, Color("e7c88f"), 0.16)
	_add_context_box("扩展街区装卸区托盘", Vector3(1.44, 0.12, 0.86), base + Vector3(1.62, 0.28, 0.74), Color("7b5e43"), 0.82)
	_add_context_box("扩展街区装卸区货箱左", Vector3(0.56, 0.54, 0.54), base + Vector3(1.22, 0.60, 0.70), Color("a0714d"), 0.78)
	_add_context_box("扩展街区装卸区货箱右", Vector3(0.56, 0.42, 0.54), base + Vector3(1.92, 0.54, 0.70), Color("65715e"), 0.78)
	_add_context_box("扩展街区装卸区警示边", Vector3(2.42, 0.035, 0.05), base + Vector3(0.0, 0.22, 0.34), Color("d19a58"), 0.34, 0.0, Color("e5b872"), 0.18)
	_add_context_label("扩展街区状态", "后场仓储区", base + Vector3(0.0, 3.62, -0.08), Color("f1d4a1"))
	_register_expanded_visual_contract({"id": "city-neighborhood-extension", "layers": ["warehouse_facade", "loading_door", "warehouse_status", "loading_guidance", "cargo_props", "district_landmark"]})

func _build_rain_after_context() -> void:
	for index in range(5):
		var z := -11.0 + float(index) * 1.35
		_add_context_box("扩展雨后地面反光-%02d" % index, Vector3(5.0, 0.018, 0.16), Vector3(-6.0, 0.19, z), Color("78949a"), 0.18, 0.0, Color("b9d5d1"), 0.12)
	_add_context_box("扩展雨后主路积水面", Vector3(4.80, 0.012, 2.10), Vector3(-6.0, 0.185, -5.80), Color("506a70"), 0.08, 0.34, Color("9ec2c0"), 0.10)
	_add_context_box("扩展雨后积水高光左", Vector3(2.20, 0.016, 0.035), Vector3(-6.78, 0.205, -5.74), Color("b9d5d1"), 0.10, 0.42, Color("d6eeea"), 0.22)
	_add_context_box("扩展雨后积水高光右", Vector3(1.46, 0.016, 0.035), Vector3(-5.32, 0.205, -6.12), Color("b9d5d1"), 0.10, 0.42, Color("d6eeea"), 0.18)
	_add_context_box("扩展雨后排水沟", Vector3(0.22, 0.030, 7.0), Vector3(-3.50, 0.21, -5.5), Color("35484d"), 0.62, 0.22)
	_add_context_box("扩展雨后排水沟边缘", Vector3(0.06, 0.035, 7.0), Vector3(-3.34, 0.22, -5.5), Color("8aa7a4"), 0.24, 0.08, Color("a9c7c5"), 0.12)
	_add_context_box("扩展雨后路缘水带", Vector3(0.14, 0.026, 7.0), Vector3(-3.72, 0.20, -5.5), Color("6d8a90"), 0.16, 0.0, Color("a9c7c5"), 0.12)
	_register_expanded_visual_contract({"id": "city-weather-lighting-extension", "layers": ["wet_ground", "puddle_surface", "puddle_highlight", "drainage", "curb_reflection", "cool_ambient"]})

func _build_traffic_context() -> void:
	for index in range(3):
		var x := -8.0 + float(index) * 2.0
		_add_context_box("扩展交通车道反光-%02d" % index, Vector3(0.08, 0.022, 1.35), Vector3(x, 0.18, -5.5), Color("d4b679"), 0.44, 0.0, Color("f0d495"), 0.12)
	_add_context_box("扩展交通近失停止线", Vector3(8.80, 0.026, 0.12), Vector3(-4.0, 0.19, -4.15), Color("c6bda5"), 0.72, 0.0, Color("d8cfb6"), 0.10)
	_add_context_box("扩展交通近失警示三角左", Vector3(0.06, 0.035, 1.18), Vector3(-5.02, 0.21, -3.60), Color("d99c58"), 0.40, 0.0, Color("e8b86a"), 0.26)
	_add_context_box("扩展交通近失警示三角右", Vector3(0.06, 0.035, 1.18), Vector3(-2.98, 0.21, -3.60), Color("d99c58"), 0.40, 0.0, Color("e8b86a"), 0.26)
	_add_context_box("扩展交通近失警示三角底", Vector3(2.08, 0.035, 0.06), Vector3(-4.0, 0.21, -4.18), Color("d99c58"), 0.40, 0.0, Color("e8b86a"), 0.26)
	_add_context_box("扩展交通近失路缘反光", Vector3(0.16, 0.028, 4.80), Vector3(0.72, 0.20, -5.0), Color("8fa7a0"), 0.22, 0.10, Color("b9d5d1"), 0.16)
	_add_context_label("扩展交通近失提示", "注意来车", Vector3(-4.0, 1.04, -4.30), Color("f1d4a1"))
	_register_expanded_visual_contract({"id": "city-traffic-near-miss", "layers": ["lane_reflection", "stop_line", "near_miss_warning", "curb_reflection", "traffic_readability"]})

func _build_vehicle_damage_context(integrity: float) -> void:
	var damage_ratio := clampf(1.0 - integrity / 100.0, 0.0, 1.0)
	var warning_color := Color("e05252") if integrity < 35.0 else Color("e0b252")
	_add_context_box("扩展载具损伤路面警示", Vector3(0.08 + damage_ratio * 0.12, 0.035, 1.52), Vector3(-6.0, 0.21, 5.0), warning_color, 0.34, 0.0, warning_color, 0.18 + damage_ratio * 0.24)
	_add_context_box("扩展载具损伤刮擦痕左", Vector3(0.06 + damage_ratio * 0.04, 0.022, 1.10), Vector3(-6.48, 0.205, 5.48), warning_color, 0.34, 0.0, warning_color, 0.10 + damage_ratio * 0.16)
	_add_context_box("扩展载具损伤刮擦痕右", Vector3(0.06 + damage_ratio * 0.04, 0.022, 0.84), Vector3(-5.54, 0.205, 4.58), warning_color, 0.34, 0.0, warning_color, 0.10 + damage_ratio * 0.16)
	_add_context_box("扩展载具损伤检修标", Vector3(0.68, 0.035, 0.06), Vector3(-6.0, 0.23, 4.32), warning_color, 0.42, 0.0, warning_color, 0.18 + damage_ratio * 0.20)
	_add_context_label("扩展载具损伤提示", "载具完整度 %d%%" % roundi(integrity), Vector3(-6.0, 0.76, 4.20), warning_color)
	_register_expanded_visual_contract({"id": "city-vehicle-damage-feedback", "layers": ["damage_warning", "damage_scratches", "service_marker", "damage_ratio"], "integrity": integrity})

func _build_delivery_completion_context(reward: int, stars: int) -> void:
	## 任务系统已经判定成功后才显示；这里只提供终点附近的结算构图。
	## 不创建交互、碰撞、导航或新的任务状态，避免视觉层反向改变玩法。
	var base := Vector3(10.0, 0.0, 13.25)
	var completion_color := Color("8fe0a2")
	_add_context_box("扩展交付完成结算牌", Vector3(3.80, 0.92, 0.08), base + Vector3(0.0, 1.62, 0.0), Color("263b35"), 0.48, 0.04, Color("4f9d72"), 0.24)
	_add_context_box("扩展交付完成结算牌边框", Vector3(3.98, 0.08, 0.05), base + Vector3(0.0, 2.10, -0.05), completion_color, 0.34, 0.0, completion_color, 0.34)
	_add_context_box("扩展交付完成结算牌底沿", Vector3(3.98, 0.08, 0.05), base + Vector3(0.0, 1.14, -0.05), completion_color, 0.34, 0.0, completion_color, 0.28)
	_add_context_box("扩展交付完成路线终点", Vector3(2.80, 0.025, 0.16), base + Vector3(0.0, 0.19, -0.94), Color("8fcba2"), 0.34, 0.0, Color("a8e0b7"), 0.20)
	for light_index in range(3):
		_add_context_box("扩展交付完成状态灯-%02d" % light_index, Vector3(0.18, 0.18, 0.08), base + Vector3(-1.18 + float(light_index) * 1.18, 2.30, -0.08), completion_color, 0.26, 0.0, completion_color, 0.62)
	_add_context_label("扩展交付完成标题", "任务完成", base + Vector3(0.0, 1.88, -0.10), Color("d9f6df"))
	_add_context_label("扩展交付完成奖励", "奖励 ¥%d · 星级 %d" % [reward, stars], base + Vector3(0.0, 1.38, -0.10), Color("b9e8c7"))
	_register_expanded_visual_contract({
		"id": "city-delivery-completion",
		"layers": ["completion_board", "completion_lights", "route_endpoint", "reward_feedback"],
		"reward": reward,
		"stars": stars,
	})

func _register_expanded_visual_contract(contract: Dictionary) -> void:
	if context_root == null or not is_instance_valid(context_root):
		return
	var contracts: Array = context_root.get_meta("expanded_visual_contracts", []).duplicate(true)
	contracts.append(contract.duplicate(true))
	context_root.set_meta("expanded_visual_contracts", contracts)
	# 保留单数元数据兼容旧工具；正式验收使用聚合数组，避免多层上下文互相覆盖。
	context_root.set_meta("expanded_visual_contract", contract.duplicate(true))

func _add_context_box(node_name: String, size: Vector3, at: Vector3, color: Color, roughness := 0.82, metallic := 0.0, emission := Color(0.0, 0.0, 0.0, 0.0), emission_energy := 0.0) -> MeshInstance3D:
	var node := _make_box(node_name, size, color, roughness, metallic, emission, emission_energy)
	node.position = at
	context_root.add_child(node)
	return node

func _add_context_label(node_name: String, label_text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = label_text
	label.position = at
	label.modulate = color
	label.font_size = 24
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.set_meta("visual_only", true)
	label.set_meta("candidate_visual_only", true)
	label.set_meta("original_procedural_asset", true)
	context_root.add_child(label)

func _build_storefront_state(crowd_heavy: bool) -> void:
	var base := Vector3(-9.0, 0.0, -8.0)
	_add_box("状态01店铺门面", Vector3(6.8, 3.65, 0.18), base + Vector3(0.0, 1.82, 0.0), Color("8b4f45"), 0.78)
	_add_storefront_detail(base, "状态01")
	_add_storefront_depth(base, crowd_heavy)
	# 参考 city-01 的识别主体是红色门头、暖色檐灯、卷帘门和店前拥挤
	# 的前后景。这里补的是可撤回的视觉层，不替代真实店铺碰撞、交互目标
	# 或人群逻辑。
	_add_box("状态01店铺红色门头", Vector3(6.10, 0.72, 0.10), base + Vector3(0.0, 3.18, -0.16), Color("bd3f35"), 0.56, 0.02, Color("7f1715"), 0.16)
	_add_box("状态01店铺遮雨篷", Vector3(6.35, 0.52, 0.72), base + Vector3(0.0, 2.55, 0.26), Color("963f39"), 0.72, 0.02)
	_add_box("状态01店铺遮雨篷前沿", Vector3(6.38, 0.10, 0.12), base + Vector3(0.0, 2.28, 0.60), Color("d6a06f"), 0.52, 0.04, Color("b46a43"), 0.18)
	_add_box("状态01卷帘门", Vector3(3.10, 2.35, 0.08), base + Vector3(0.0, 1.18, -0.13), Color("39444c"), 0.52, 0.22)
	for shutter_row in range(7):
		_add_box("状态01卷帘门横槽-%02d" % shutter_row, Vector3(3.04, 0.035, 0.035), base + Vector3(0.0, 0.36 + float(shutter_row) * 0.30, -0.19), Color("6e7b80"), 0.38, 0.16)
	_add_box("状态01卷帘门左导轨", Vector3(0.08, 2.34, 0.08), base + Vector3(-1.58, 1.18, -0.20), Color("707b7e"), 0.40, 0.14)
	_add_box("状态01卷帘门右导轨", Vector3(0.08, 2.34, 0.08), base + Vector3(1.58, 1.18, -0.20), Color("707b7e"), 0.40, 0.14)
	_add_box("状态01卷帘门底导轨", Vector3(3.12, 0.06, 0.08), base + Vector3(0.0, 0.28, -0.21), Color("a08d72"), 0.34, 0.10)
	_add_box("状态01卷帘门门把手", Vector3(0.28, 0.08, 0.06), base + Vector3(0.0, 0.42, -0.24), Color("c5a06e"), 0.28, 0.0, Color("dfbd83"), 0.18)
	_add_box("状态01店铺玻璃展窗左", Vector3(1.18, 1.20, 0.06), base + Vector3(-2.10, 1.55, -0.20), Color("788b8b"), 0.24, 0.08, Color("a6c8c0"), 0.10)
	_add_box("状态01店铺玻璃展窗右", Vector3(1.18, 1.20, 0.06), base + Vector3(2.10, 1.55, -0.20), Color("788b8b"), 0.24, 0.08, Color("a6c8c0"), 0.10)
	_add_box("状态01店铺左侧灯箱", Vector3(0.12, 1.58, 0.10), base + Vector3(-3.02, 1.98, -0.18), Color("e0a25f"), 0.40, 0.0, Color("e0a25f"), 0.44)
	_add_box("状态01店铺右侧灯箱", Vector3(0.12, 1.58, 0.10), base + Vector3(3.02, 1.98, -0.18), Color("e0a25f"), 0.40, 0.0, Color("e0a25f"), 0.44)
	_add_box("状态01门头灯带", Vector3(5.8, 0.12, 0.10), base + Vector3(0.0, 3.20, -0.16), Color("e3a86b"), 0.35, 0.0, Color("e3a86b"), 0.58)
	_add_box("状态01店铺入口地垫", Vector3(3.55, 0.025, 1.05), base + Vector3(0.0, 0.13, 0.64), Color("4a5050"), 0.88)
	_add_box("状态01门头识别牌底板", Vector3(3.72, 0.46, 0.06), base + Vector3(0.0, 3.54, -0.30), Color("5a2424"), 0.46, 0.06, Color("8d302b"), 0.18)
	for sign_index in range(3):
		_add_box("状态01门头识别牌字块-%02d" % sign_index, Vector3(0.42, 0.18, 0.035), base + Vector3(-0.82 + float(sign_index) * 0.82, 3.54, -0.36), Color("f0c487"), 0.36, 0.0, Color("f0c487"), 0.28)
	for awning_index in range(5):
		_add_box("状态01遮雨篷条纹-%02d" % awning_index, Vector3(0.72, 0.035, 0.56), base + Vector3(-2.56 + float(awning_index) * 1.28, 2.53, 0.62), Color("d6a06f") if awning_index % 2 == 0 else Color("6f3130"), 0.58, 0.02)
	_add_box("状态01左展窗竖框", Vector3(0.045, 1.16, 0.05), base + Vector3(-2.10, 1.55, -0.25), Color("b7c7bd"), 0.28, 0.0, Color("e1c38e"), 0.14)
	_add_box("状态01右展窗竖框", Vector3(0.045, 1.16, 0.05), base + Vector3(2.10, 1.55, -0.25), Color("b7c7bd"), 0.28, 0.0, Color("e1c38e"), 0.14)
	_add_box("状态01门头电缆盒", Vector3(0.38, 0.18, 0.12), base + Vector3(-2.66, 3.20, -0.22), Color("343b3d"), 0.42, 0.10)
	_add_box("状态01店前台阶边缘", Vector3(4.20, 0.08, 0.16), base + Vector3(0.0, 0.17, 1.18), Color("6d6259"), 0.74)
	_add_box("状态01左侧周转筐", Vector3(0.56, 0.42, 0.48), base + Vector3(-3.22, 0.34, 0.72), Color("755744"), 0.80)
	_add_box("状态01右侧周转筐", Vector3(0.56, 0.42, 0.48), base + Vector3(3.22, 0.34, 0.72), Color("5d6b5c"), 0.80)
	_add_crowd_marker(base + Vector3(-3.2, 0.0, 0.65), 0)
	_add_crowd_marker(base + Vector3(3.0, 0.0, 0.85), 1)
	# 参考首店镜头的识别重点是“主角被人群包围、门面仍可读”。
	# 普通首帧也保留两层人群，避免店铺变成空旷的孤立方块；city-02
	# 再追加前景遮挡层。这里只改变视觉节点数量，不改变真实行人数量。
	var crowd_count := 18 if crowd_heavy else 14
	for index in range(2, crowd_count):
		var crowd_x := -3.60 + float(index % 7) * 1.20
		var crowd_z := 0.92 + float(index / 7) * 0.68
		_add_crowd_marker(base + Vector3(crowd_x, 0.0, crowd_z), index)
	_add_light("状态01店铺门头暖光", base + Vector3(0.0, 2.95, 0.55), Color("e2a171"), 0.22, 4.2)
	set_meta("visual_state_contract", {"state": "city-01", "required_layers": ["storefront", "shutter", "entrance", "crowd", "sidewalk_depth", "shop_lighting"]})

func _build_crowd_state() -> void:
	_build_storefront_state(true)
	# city-02 是卷帘门前的近景拥挤状态；补出横槽、导轨和底部反光，
	# 让镜头从人群缝隙中仍能读出目标门面。这里只增加视觉层，不复制真实碰撞。
	for shutter_row in range(8):
		_add_box("状态02卷帘门近景横槽-%02d" % shutter_row, Vector3(3.34, 0.035, 0.035), Vector3(-9.0, 0.42 + float(shutter_row) * 0.27, -8.24), Color("78848a"), 0.40, 0.18)
	_add_box("状态02卷帘门近景左导轨", Vector3(0.08, 2.34, 0.08), Vector3(-10.72, 1.42, -8.25), Color("7f8b8f"), 0.42, 0.16)
	_add_box("状态02卷帘门近景右导轨", Vector3(0.08, 2.34, 0.08), Vector3(-7.28, 1.42, -8.25), Color("7f8b8f"), 0.42, 0.16)
	_add_box("状态02卷帘门近景底部反光", Vector3(3.26, 0.06, 0.06), Vector3(-9.0, 0.30, -8.28), Color("b09b7a"), 0.32, 0.0, Color("d3b887"), 0.18)
	_add_box("状态02拥挤导视线", Vector3(4.8, 0.028, 0.06), Vector3(-9.0, 0.14, -6.45), Color("d18b59"), 0.44, 0.0, Color("d18b59"), 0.32)
	_add_box("状态02拥挤缓冲线", Vector3(0.06, 0.028, 2.6), Vector3(-6.65, 0.14, -7.60), Color("d18b59"), 0.44, 0.0, Color("d18b59"), 0.32)
	_add_box("状态02拥挤近景导流台", Vector3(3.80, 0.52, 0.16), Vector3(-9.0, 0.42, -5.95), Color("6f5146"), 0.72, 0.10)
	for post_index in range(3):
		_add_box("状态02拥挤隔离柱-%02d" % post_index, Vector3(0.13, 0.70, 0.13), Vector3(-10.55 + float(post_index) * 1.55, 0.50, -5.72), Color("4d5758"), 0.62, 0.14)
	_add_box("状态02拥挤排队牌", Vector3(0.72, 0.58, 0.05), Vector3(-7.72, 1.18, -5.72), Color("7d5148"), 0.42, 0.04, Color("d6a06f"), 0.18)
	_add_box("状态02拥挤排队牌边框", Vector3(0.78, 0.06, 0.08), Vector3(-7.72, 1.47, -5.70), Color("d7b27a"), 0.34, 0.0, Color("e9cb91"), 0.22)
	_add_box("状态02拥挤隔离绳高光", Vector3(4.52, 0.035, 0.035), Vector3(-9.0, 0.96, -5.72), Color("d9a45e"), 0.32, 0.0, Color("f1cb83"), 0.20)
	_add_box("状态02拥挤导流台标签", Vector3(1.32, 0.20, 0.04), Vector3(-9.0, 0.70, -6.04), Color("d9b47f"), 0.40, 0.0, Color("edcf98"), 0.18)
	_add_box("状态02拥挤人群前景遮挡带", Vector3(5.20, 0.16, 0.10), Vector3(-9.0, 1.16, -5.48), Color("574b49"), 0.78, 0.18)
	_add_crowd_marker(Vector3(-7.15, 0.0, -5.24), 16)
	_add_crowd_marker(Vector3(-10.10, 0.0, -5.20), 17)
	set_meta("visual_state_contract", {"state": "city-02", "required_layers": ["storefront", "crowd_density", "crowd_buffer", "sidewalk_depth", "shop_lighting"]})

func _add_storefront_depth(base: Vector3, crowd_heavy: bool) -> void:
	# 店铺入口的首帧需要有前景人行道、门口照明和邻店纵深；节点仅是视觉层。
	_add_box("状态01前景人行道", Vector3(8.40, 0.035, 2.70), base + Vector3(0.0, 0.16, 1.88), Color("77716b"), 0.94)
	for tile_index in range(8):
		var tile_x := -3.50 + float(tile_index % 4) * 2.34
		var tile_z := 1.12 + float(tile_index / 4) * 1.40
		_add_box("状态01人行道拼缝-%02d" % tile_index, Vector3(1.90, 0.012, 0.020), base + Vector3(tile_x, 0.185, tile_z), Color("9b9084"), 0.98)
	_add_box("状态01入口门槛", Vector3(3.30, 0.06, 0.16), base + Vector3(0.0, 0.20, 0.70), Color("b49a79"), 0.62, 0.12)
	_add_box("状态01店铺入口左门框", Vector3(0.10, 2.16, 0.08), base + Vector3(-1.58, 1.28, -0.26), Color("c5aa84"), 0.44, 0.06)
	_add_box("状态01店铺入口右门框", Vector3(0.10, 2.16, 0.08), base + Vector3(1.58, 1.28, -0.26), Color("c5aa84"), 0.44, 0.06)
	_add_box("状态01店铺入口横梁", Vector3(3.26, 0.10, 0.08), base + Vector3(0.0, 2.34, -0.26), Color("c5aa84"), 0.44, 0.06)
	for awning_index in range(6):
		var awning_x := -2.50 + float(awning_index) * 1.00
		_add_box("状态01遮雨篷条纹-%02d" % awning_index, Vector3(0.54, 0.035, 0.66), base + Vector3(awning_x, 2.50, 0.48), Color("d9b178" if awning_index % 2 == 0 else "8d3836"), 0.70)
	_add_box("状态01左邻店轮廓", Vector3(1.05, 2.85, 0.12), base + Vector3(-4.05, 1.42, 0.10), Color("5f6767"), 0.84)
	_add_box("状态01右邻店轮廓", Vector3(1.05, 2.85, 0.12), base + Vector3(4.05, 1.42, 0.10), Color("59636a"), 0.84)
	_add_box("状态01店铺门口灯串", Vector3(4.80, 0.05, 0.05), base + Vector3(0.0, 2.82, 0.52), Color("e5bf7b"), 0.32, 0.0, Color("e5bf7b"), 0.58)
	for lamp_index in range(5):
		_add_box("状态01店铺门口灯点-%02d" % lamp_index, Vector3(0.08, 0.08, 0.08), base + Vector3(-2.0 + float(lamp_index) * 1.0, 2.76, 0.55), Color("fff0c7"), 0.24, 0.0, Color("fff0c7"), 0.76)
	if crowd_heavy:
		_add_box("状态02人群前景接触暗部", Vector3(5.80, 0.018, 1.20), base + Vector3(0.0, 0.19, 1.18), Color("34383a"), 0.99)

func _build_store_aisle_state() -> void:
	var base := Vector3(-9.0, 0.0, -10.0)
	for side in [-1.0, 1.0]:
		var side_label := "左" if side < 0.0 else "右"
		_add_box("状态03货架侧体", Vector3(0.42, 1.75, 3.6), base + Vector3(side * 1.85, 0.98, 0.0), Color("65584f"), 0.70, 0.05)
		for row in range(3):
			_add_box("状态03货架层板", Vector3(0.55, 0.07, 3.05), base + Vector3(side * 1.55, 0.50 + float(row) * 0.48, 0.0), Color("9a765a"), 0.65, 0.08)
			_add_box("状态03商品色块", Vector3(0.10, 0.22, 2.55), base + Vector3(side * 1.25, 0.64 + float(row) * 0.48, 0.0), Color("c47a52" if row % 2 == 0 else "6b9092"), 0.66)
			for pack in range(3):
				var pack_z := -1.02 + float(pack) * 0.82
				_add_box("状态03商品包装-%s-%02d-%02d" % [side_label, row, pack], Vector3(0.16, 0.24, 0.34), base + Vector3(side * 1.15, 0.66 + float(row) * 0.48, pack_z), Color("d6a06f" if (row + pack) % 2 == 0 else "7fa5a4"), 0.54, 0.02)
				_add_box("状态03商品包装标签-%s-%02d-%02d" % [side_label, row, pack], Vector3(0.17, 0.045, 0.18), base + Vector3(side * 1.055, 0.68 + float(row) * 0.48, pack_z), Color("f0d39d"), 0.38, 0.0, Color("f0d39d"), 0.10)
	_add_box("状态03通道地面", Vector3(2.80, 0.025, 3.90), base + Vector3(0.0, 0.13, 0.0), Color("6a625d"), 0.92)
	for floor_line in range(4):
		_add_box("状态03通道地砖缝-%02d" % floor_line, Vector3(2.76, 0.012, 0.018), base + Vector3(0.0, 0.16, -1.48 + float(floor_line) * 0.98), Color("9a8e83"), 0.98)
	for reflection_index in range(2):
		_add_box("状态03通道地面反光带-%02d" % reflection_index, Vector3(0.32, 0.014, 3.48), base + Vector3(-0.62 + float(reflection_index) * 1.24, 0.18, 0.0), Color("b7aca0"), 0.30, 0.0, Color("d9d0c1"), 0.08)
	for shelf_post_index in range(4):
		var post_z := -1.42 + float(shelf_post_index) * 0.94
		_add_box("状态03左货架端部立柱-%02d" % shelf_post_index, Vector3(0.08, 1.86, 0.08), base + Vector3(-1.08, 1.02, post_z), Color("a88361"), 0.52, 0.04)
		_add_box("状态03右货架端部立柱-%02d" % shelf_post_index, Vector3(0.08, 1.86, 0.08), base + Vector3(1.08, 1.02, post_z), Color("a88361"), 0.52, 0.04)
	_add_box("状态03通道尽端冷光", Vector3(1.46, 1.16, 0.04), base + Vector3(0.0, 1.52, -1.86), Color("d6eee5"), 0.28, 0.0, Color("e4fff3"), 0.28)
	_add_box("状态03左货架价签轨", Vector3(0.08, 0.08, 3.10), base + Vector3(-1.18, 0.78, 0.0), Color("d8b36f"), 0.42, 0.02)
	_add_box("状态03右货架价签轨", Vector3(0.08, 0.08, 3.10), base + Vector3(1.18, 0.78, 0.0), Color("d8b36f"), 0.42, 0.02)
	_add_box("状态03通道尽端堆头", Vector3(1.82, 1.55, 0.36), base + Vector3(0.0, 0.90, -1.62), Color("7c5447"), 0.76)
	_add_box("状态03通道尽端商品带", Vector3(1.46, 0.72, 0.04), base + Vector3(0.0, 1.12, -1.84), Color("c88855"), 0.54, 0.0, Color("c88855"), 0.12)
	_add_box("状态03店内冷白灯板", Vector3(1.52, 0.035, 0.46), base + Vector3(0.0, 2.65, -0.98), Color("d9e2dc"), 0.32, 0.02, Color("eef8ed"), 0.60)
	_add_box("状态03通道吊牌", Vector3(0.72, 0.38, 0.04), base + Vector3(0.0, 2.18, -0.24), Color("b86c4f"), 0.50, 0.0, Color("b86c4f"), 0.16)
	_add_box("状态03通道吊牌左吊杆", Vector3(0.035, 0.42, 0.035), base + Vector3(-0.26, 2.44, -0.24), Color("4b4542"), 0.46, 0.12)
	_add_box("状态03通道吊牌右吊杆", Vector3(0.035, 0.42, 0.035), base + Vector3(0.26, 2.44, -0.24), Color("4b4542"), 0.46, 0.12)
	_add_box("状态03左货架端头护条", Vector3(0.08, 1.82, 0.12), base + Vector3(-1.08, 1.02, -1.70), Color("b38357"), 0.48, 0.04)
	_add_box("状态03右货架端头护条", Vector3(0.08, 1.82, 0.12), base + Vector3(1.08, 1.02, -1.70), Color("b38357"), 0.48, 0.04)
	_add_box("状态03鸡蛋货架标识", Vector3(0.52, 0.08, 0.18), base + Vector3(0.0, 1.25, -1.45), Color("dfb36f"), 0.40, 0.0, Color("dfb36f"), 0.30)
	for ceiling_index in range(4):
		var ceiling_z := -1.52 + float(ceiling_index) * 1.02
		_add_box("状态03通道顶灯-%02d" % ceiling_index, Vector3(0.78, 0.045, 0.30), base + Vector3(0.0, 2.65, ceiling_z), Color("d9e2dc"), 0.28, 0.02, Color("eef8ed"), 0.72)
	_add_box("状态03左货架顶板", Vector3(0.66, 0.10, 3.18), base + Vector3(-1.55, 1.98, 0.0), Color("7b6251"), 0.70, 0.04)
	_add_box("状态03右货架顶板", Vector3(0.66, 0.10, 3.18), base + Vector3(1.55, 1.98, 0.0), Color("7b6251"), 0.70, 0.04)
	_add_box("状态03通道尽端鸡蛋海报", Vector3(1.18, 0.74, 0.035), base + Vector3(0.0, 1.78, -1.92), Color("d8b36f"), 0.42, 0.0, Color("e8c985"), 0.12)
	_add_box("状态03通道尽端海报边框", Vector3(1.28, 0.05, 0.045), base + Vector3(0.0, 2.16, -1.94), Color("9b5d48"), 0.42, 0.0)
	_add_box("状态03通道地面导向箭头-00", Vector3(0.42, 0.018, 0.08), base + Vector3(0.0, 0.19, 0.82), Color("d6b477"), 0.34, 0.0, Color("d6b477"), 0.16)
	_add_box("状态03通道地面导向箭头-01", Vector3(0.24, 0.018, 0.08), base + Vector3(0.0, 0.19, 1.12), Color("d6b477"), 0.34, 0.0, Color("d6b477"), 0.16)
	_add_box("状态03通道天花横梁", Vector3(2.72, 0.08, 0.10), base + Vector3(0.0, 2.86, -0.74), Color("4c5658"), 0.58, 0.12)
	_add_light("状态03店内顶灯", base + Vector3(0.0, 2.65, -0.20), Color("ffe0b0"), 0.24, 3.6)
	set_meta("visual_state_contract", {"state": "city-03", "required_layers": ["shelves", "product_bands", "floor", "store_light"]})

func _build_conflict_state() -> void:
	_build_store_aisle_state()
	var base := Vector3(-9.0, 0.0, -10.0)
	_add_box("状态04鸡蛋托盘", Vector3(0.72, 0.14, 0.46), base + Vector3(0.0, 1.02, -0.75), Color("c89a63"), 0.66)
	for index in range(6):
		_add_box("状态04鸡蛋-%02d" % index, Vector3(0.12, 0.12, 0.12), base + Vector3(-0.22 + float(index % 3) * 0.22, 1.14, -0.86 + float(index / 3) * 0.22), Color("e8d0a1"), 0.42)
	_add_box("状态04冲突展示台", Vector3(2.20, 0.82, 0.72), base + Vector3(0.0, 0.52, -0.18), Color("a4443f"), 0.68, 0.02)
	_add_box("状态04冲突展示台台面", Vector3(2.28, 0.08, 0.78), base + Vector3(0.0, 0.96, -0.18), Color("d2a068"), 0.58, 0.04)
	_add_box("状态04鸡蛋堆头红色前板", Vector3(2.42, 0.72, 0.08), base + Vector3(0.0, 0.56, 0.18), Color("a4443f"), 0.68, 0.02)
	_add_box("状态04鸡蛋堆头上层托盘", Vector3(1.94, 0.12, 0.62), base + Vector3(0.0, 1.16, -0.18), Color("c89a63"), 0.60)
	for tray_index in range(3):
		_add_box("状态04鸡蛋堆头托盘-%02d" % tray_index, Vector3(0.52, 0.10, 0.48), base + Vector3(-0.62 + float(tray_index) * 0.62, 1.27, -0.18), Color("e0b97c"), 0.54, 0.0, Color("f0d39d"), 0.10)
	for display_row in range(2):
		for display_index in range(5):
			_add_box("状态04鸡蛋堆头前排-%02d-%02d" % [display_row, display_index], Vector3(0.22, 0.12, 0.18), base + Vector3(-0.88 + float(display_index) * 0.44, 1.38 + float(display_row) * 0.18, -0.48 + float(display_row) * 0.18), Color("ead3a4"), 0.38, 0.0, Color("f4e2bd"), 0.10)
	_add_box("状态04鸡蛋堆头商品标签", Vector3(1.16, 0.12, 0.035), base + Vector3(0.0, 1.86, -0.34), Color("f0d39d"), 0.34, 0.0, Color("fff0c7"), 0.18)
	_add_box("状态04鸡蛋托盘边框", Vector3(0.80, 0.05, 0.52), base + Vector3(0.0, 1.10, -0.75), Color("f0d39d"), 0.48, 0.0)
	_add_box("状态04冲突对象脚边暗部", Vector3(0.90, 0.018, 0.56), base + Vector3(0.82, 0.18, -0.22), Color("3b3432"), 0.99)
	_add_box("状态04保安拦截带", Vector3(2.52, 0.06, 0.04), base + Vector3(0.0, 1.02, 0.55), Color("d45157"), 0.34, 0.0, Color("d45157"), 0.48)
	_add_box("状态04冲突警戒带", Vector3(2.30, 0.035, 0.07), base + Vector3(0.0, 0.15, 0.28), Color("c83f4d"), 0.34, 0.0, Color("c83f4d"), 0.52)
	_add_box("状态04隔离柱左", Vector3(0.12, 0.92, 0.12), base + Vector3(-1.12, 0.58, 0.50), Color("4b4542"), 0.46, 0.18)
	_add_box("状态04隔离柱右", Vector3(0.12, 0.92, 0.12), base + Vector3(1.12, 0.58, 0.50), Color("4b4542"), 0.46, 0.18)
	_add_box("状态04隔离柱底座左", Vector3(0.32, 0.08, 0.32), base + Vector3(-1.12, 0.14, 0.50), Color("373234"), 0.82, 0.12)
	_add_box("状态04隔离柱底座右", Vector3(0.32, 0.08, 0.32), base + Vector3(1.12, 0.14, 0.50), Color("373234"), 0.82, 0.12)
	_add_box("状态04隔离绳左段", Vector3(1.00, 0.045, 0.045), base + Vector3(-0.62, 0.82, 0.50), Color("d45157"), 0.38, 0.0, Color("d45157"), 0.30)
	_add_box("状态04隔离绳右段", Vector3(1.00, 0.045, 0.045), base + Vector3(0.62, 0.82, 0.50), Color("d45157"), 0.38, 0.0, Color("d45157"), 0.30)
	_add_box("状态04冲突警示牌", Vector3(0.62, 0.42, 0.045), base + Vector3(1.46, 1.14, 0.48), Color("e4b45f"), 0.42, 0.0, Color("e4b45f"), 0.20)
	_add_box("状态04冲突警示牌立杆", Vector3(0.045, 0.68, 0.045), base + Vector3(1.46, 0.70, 0.48), Color("4b4542"), 0.46, 0.12)
	_add_box("状态04散落鸡蛋盒", Vector3(0.46, 0.08, 0.30), base + Vector3(-0.72, 0.20, -0.34), Color("c89a63"), 0.66)
	_add_box("状态04散落物反光片", Vector3(0.20, 0.018, 0.08), base + Vector3(-0.76, 0.25, -0.34), Color("e8d0a1"), 0.34, 0.0, Color("e8d0a1"), 0.24)
	_add_box("状态04冲突展示台左侧板", Vector3(0.08, 0.72, 0.64), base + Vector3(-1.08, 0.56, -0.18), Color("8b3838"), 0.68, 0.02)
	_add_box("状态04冲突展示台右侧板", Vector3(0.08, 0.72, 0.64), base + Vector3(1.08, 0.56, -0.18), Color("8b3838"), 0.68, 0.02)
	_add_box("状态04鸡蛋堆头竖分隔-00", Vector3(0.035, 0.72, 0.05), base + Vector3(-0.32, 1.54, -0.35), Color("f0d39d"), 0.34, 0.0)
	_add_box("状态04鸡蛋堆头竖分隔-01", Vector3(0.035, 0.72, 0.05), base + Vector3(0.32, 1.54, -0.35), Color("f0d39d"), 0.34, 0.0)
	_add_box("状态04冲突警示牌顶沿", Vector3(0.68, 0.05, 0.06), base + Vector3(1.46, 1.38, 0.46), Color("f2cd76"), 0.30, 0.0, Color("f2cd76"), 0.22)
	_add_box("状态04冲突地面接触带", Vector3(3.00, 0.018, 0.18), base + Vector3(0.0, 0.18, 0.68), Color("383133"), 0.96)
	_add_light("状态04冲突红光", base + Vector3(0.0, 1.85, -0.15), Color("d45157"), 0.18, 3.2)
	set_meta("visual_state_contract", {"state": "city-04", "required_layers": ["store_aisle", "egg_tray", "eggs", "conflict_feedback"]})

func _build_exit_state() -> void:
	_add_box("状态05离店道路", Vector3(8.6, 0.03, 4.8), Vector3(-9.0, 0.13, -5.5), Color("5b6060"), 0.92)
	_add_city_facade("状态05左侧街屋", Vector3(-13.0, 0.0, -5.5), Color("6f5957"), Color("d09a69"), -1.0)
	_add_city_facade("状态05右侧街屋", Vector3(-5.0, 0.0, -5.5), Color("56666c"), Color("7aa1a1"), 1.0)
	for x in [-11.0, -9.0, -7.0]:
		_add_box("状态05道路标线", Vector3(0.12, 0.025, 1.10), Vector3(x, 0.16, -5.5), Color("d8c28d"), 0.62, 0.0, Color("d8c28d"), 0.18)
	_add_box("状态05后场装卸台", Vector3(2.8, 0.42, 1.20), Vector3(-6.8, 0.36, -4.85), Color("a77f61"), 0.76)
	_add_box("状态05后场装卸台边缘反光条", Vector3(2.86, 0.05, 0.08), Vector3(-6.8, 0.59, -4.22), Color("d1a66e"), 0.48, 0.0, Color("d1a66e"), 0.20)
	_add_box("状态05卸货木托盘", Vector3(1.55, 0.12, 0.90), Vector3(-7.55, 0.32, -4.20), Color("8f6a4f"), 0.82)
	_add_box("状态05卸货纸箱-00", Vector3(0.42, 0.44, 0.42), Vector3(-7.18, 0.60, -4.28), Color("a87d57"), 0.86)
	_add_box("状态05卸货纸箱-01", Vector3(0.36, 0.36, 0.36), Vector3(-7.72, 0.54, -4.00), Color("c09363"), 0.86)
	_add_box("状态05后场排水沟", Vector3(3.20, 0.035, 0.18), Vector3(-8.45, 0.17, -3.18), Color("303b3f"), 0.98, 0.18)
	_add_box("状态05排水沟格栅-00", Vector3(0.08, 0.045, 0.24), Vector3(-9.35, 0.20, -3.18), Color("8d8174"), 0.72, 0.12)
	_add_box("状态05排水沟格栅-01", Vector3(0.08, 0.045, 0.24), Vector3(-8.82, 0.20, -3.18), Color("8d8174"), 0.72, 0.12)
	_add_box("状态05排水沟格栅-02", Vector3(0.08, 0.045, 0.24), Vector3(-8.28, 0.20, -3.18), Color("8d8174"), 0.72, 0.12)
	_add_box("状态05装卸区警示牌", Vector3(0.06, 1.20, 0.06), Vector3(-6.05, 0.78, -4.24), Color("4d5758"), 0.52, 0.18)
	_add_box("状态05装卸区警示牌面", Vector3(0.58, 0.42, 0.04), Vector3(-6.05, 1.34, -4.20), Color("d6a259"), 0.42, 0.0, Color("edc674"), 0.16)
	_add_box("状态05纸箱标签-00", Vector3(0.18, 0.14, 0.02), Vector3(-7.18, 0.72, -4.50), Color("e4c98f"), 0.28, 0.0)
	_add_box("状态05纸箱标签-01", Vector3(0.16, 0.12, 0.02), Vector3(-7.72, 0.68, -4.20), Color("e4c98f"), 0.28, 0.0)
	_add_box("状态05装卸棚支撑左", Vector3(0.12, 2.40, 0.12), Vector3(-8.10, 1.34, -4.18), Color("4c5556"), 0.56, 0.18)
	_add_box("状态05装卸棚支撑右", Vector3(0.12, 2.40, 0.12), Vector3(-5.50, 1.34, -4.18), Color("4c5556"), 0.56, 0.18)
	_add_box("状态05后场门缝", Vector3(1.70, 1.82, 0.035), Vector3(-10.80, 0.98, -5.02), Color("30383b"), 0.48, 0.0)
	_add_box("状态05巷道导视牌", Vector3(0.08, 1.62, 0.08), Vector3(-11.65, 0.82, -3.86), Color("4d5758"), 0.52, 0.20)
	_add_box("状态05巷道导视牌面", Vector3(0.92, 0.50, 0.05), Vector3(-11.65, 1.46, -3.84), Color("c29a63"), 0.46, 0.0, Color("c29a63"), 0.18)
	_add_box("状态05街边电线", Vector3(5.60, 0.035, 0.035), Vector3(-9.0, 3.18, -5.02), Color("242a2d"), 0.92)
	_add_box("状态05街角暖光", Vector3(0.12, 2.45, 0.12), Vector3(-5.35, 1.30, -5.9), Color("d59b54"), 0.42, 0.0, Color("d59b54"), 0.40)
	for crossing_index in range(5):
		_add_box("状态05街口斑马线-%02d" % crossing_index, Vector3(0.62, 0.026, 3.20), Vector3(-12.55 + float(crossing_index) * 1.30, 0.17, -5.50), Color("c9c0a9"), 0.74, 0.0, Color("c9c0a9"), 0.08)
	_add_box("状态05街口路缘反光边", Vector3(8.70, 0.045, 0.08), Vector3(-9.0, 0.20, -3.12), Color("b8956b"), 0.42, 0.0, Color("d6b078"), 0.16)
	_add_box("状态05街口裸树树干", Vector3(0.20, 2.60, 0.20), Vector3(-4.35, 1.30, -4.12), Color("3b332f"), 0.94)
	_add_box("状态05街口裸树左枝", Vector3(0.10, 0.10, 1.24), Vector3(-4.35, 2.05, -4.54), Color("493d37"), 0.94)
	_add_box("状态05街口裸树右枝", Vector3(0.10, 0.10, 1.08), Vector3(-4.35, 1.78, -3.72), Color("493d37"), 0.94)
	_add_box("状态05后场门楣", Vector3(1.82, 0.10, 0.08), Vector3(-10.80, 1.96, -5.04), Color("765846"), 0.62, 0.04)
	_add_box("状态05装卸棚顶沿", Vector3(3.04, 0.12, 0.74), Vector3(-6.80, 2.54, -4.18), Color("566166"), 0.64, 0.10)
	_add_box("状态05装卸台左侧挡板", Vector3(0.10, 0.46, 1.16), Vector3(-8.16, 0.42, -4.84), Color("80614d"), 0.72)
	_add_box("状态05纸箱封带-00", Vector3(0.44, 0.025, 0.05), Vector3(-7.18, 0.84, -4.28), Color("e0bd79"), 0.36, 0.0, Color("e0bd79"), 0.14)
	_add_box("状态05纸箱封带-01", Vector3(0.38, 0.025, 0.05), Vector3(-7.72, 0.78, -4.00), Color("e0bd79"), 0.36, 0.0, Color("e0bd79"), 0.14)
	_add_box("状态05街口电线下垂段", Vector3(0.035, 0.72, 0.035), Vector3(-7.20, 2.84, -5.02), Color("242a2d"), 0.92)
	_add_drive_vehicle_detail("状态05街口远景车辆", Vector3(-5.95, 0.0, -5.70), Color("65737c"), 90.0)
	_add_light("状态05夕阳边光", Vector3(-9.0, 2.20, -4.2), Color("e09b79"), 0.20, 5.0)
	set_meta("visual_state_contract", {"state": "city-05", "required_layers": ["road", "lane_marking", "backlot", "dusk_light"]})

func _build_registration_state(scanned: bool) -> void:
	var base := Vector3(7.0, 0.0, 5.5)
	_add_registration_attendant(base + Vector3(2.18, 0.0, 0.42), scanned)
	_add_box("状态登记点后墙", Vector3(4.20, 2.80, 0.14), base + Vector3(0.0, 1.40, -1.18), Color("46545a"), 0.78)
	_add_box("状态登记点遮雨篷", Vector3(4.45, 0.16, 1.05), base + Vector3(0.0, 2.72, -0.65), Color("6f4f47"), 0.62, 0.04)
	_add_box("状态登记点边框左", Vector3(0.14, 2.55, 0.16), base + Vector3(-2.08, 1.30, -0.58), Color("b28b68"), 0.52, 0.08)
	_add_box("状态登记点边框右", Vector3(0.14, 2.55, 0.16), base + Vector3(2.08, 1.30, -0.58), Color("b28b68"), 0.52, 0.08)
	_add_box("状态登记台", Vector3(1.45, 1.05, 0.70), base + Vector3(0.0, 0.62, -0.65), Color("53656a"), 0.58, 0.12)
	_add_box("状态登记台面", Vector3(1.58, 0.08, 0.76), base + Vector3(0.0, 1.18, -0.65), Color("7f928f"), 0.46, 0.10)
	_add_box("状态登记扫描垫", Vector3(0.58, 0.035, 0.34), base + Vector3(-0.22, 1.24, -0.68), Color("283a3f"), 0.30, 0.0, Color("78c890"), 0.16)
	_add_box("状态登记扫描器", Vector3(0.18, 0.12, 0.12), base + Vector3(0.40, 1.30, -0.68), Color("2e383b"), 0.34, 0.08)
	_add_box("状态登记牌", Vector3(0.86, 1.50, 0.10), base + Vector3(0.0, 1.45, -0.96), Color("253038"), 0.42, 0.20)
	_add_box("状态登记牌标题条", Vector3(0.68, 0.10, 0.025), base + Vector3(0.0, 2.05, -1.03), Color("c29a63"), 0.28, 0.0, Color("d8b879"), 0.18)
	_add_box("状态登记二维码边框", Vector3(0.58, 0.58, 0.025), base + Vector3(0.0, 1.48, -1.05), Color("c5bda9"), 0.30, 0.0)
	_add_box("状态登记二维码", Vector3(0.48, 0.48, 0.03), base + Vector3(0.0, 1.48, -1.03), Color("d9d1bd"), 0.55, 0.0, Color("d9d1bd"), 0.12)
	_add_box("状态登记二维码格-00", Vector3(0.14, 0.09, 0.035), base + Vector3(-0.17, 1.68, -1.07), Color("253038"), 0.34, 0.0)
	_add_box("状态登记二维码格-01", Vector3(0.09, 0.16, 0.035), base + Vector3(0.12, 1.68, -1.07), Color("253038"), 0.34, 0.0)
	_add_box("状态登记二维码格-02", Vector3(0.18, 0.08, 0.035), base + Vector3(-0.10, 1.50, -1.07), Color("253038"), 0.34, 0.0)
	_add_box("状态登记二维码格-03", Vector3(0.10, 0.13, 0.035), base + Vector3(0.16, 1.47, -1.07), Color("253038"), 0.34, 0.0)
	_add_box("状态登记二维码格-04", Vector3(0.10, 0.08, 0.035), base + Vector3(-0.18, 1.30, -1.07), Color("253038"), 0.34, 0.0)
	_add_box("状态登记二维码格-05", Vector3(0.16, 0.07, 0.035), base + Vector3(0.10, 1.33, -1.07), Color("253038"), 0.34, 0.0)
	_add_box("状态登记牌支柱", Vector3(0.10, 0.62, 0.10), base + Vector3(0.0, 0.55, -0.96), Color("3b4649"), 0.56, 0.12)
	_add_box("状态登记牌底座", Vector3(0.42, 0.08, 0.24), base + Vector3(0.0, 0.20, -0.96), Color("343e41"), 0.58, 0.14)
	_add_box("状态登记引导线", Vector3(2.60, 0.025, 0.06), base + Vector3(0.0, 0.14, 0.95), Color("c29a63"), 0.46, 0.0, Color("c29a63"), 0.22)
	_add_box("状态登记排队标记-左", Vector3(0.10, 0.026, 0.52), base + Vector3(-1.05, 0.15, 0.45), Color("d1b47b"), 0.38, 0.0, Color("d1b47b"), 0.16)
	_add_box("状态登记排队标记-右", Vector3(0.10, 0.026, 0.52), base + Vector3(1.05, 0.15, 0.45), Color("d1b47b"), 0.38, 0.0, Color("d1b47b"), 0.16)
	_add_box("状态登记隔离柱左", Vector3(0.12, 0.68, 0.12), base + Vector3(-1.30, 0.48, 0.55), Color("4a5555"), 0.62, 0.16)
	_add_box("状态登记隔离柱右", Vector3(0.12, 0.68, 0.12), base + Vector3(1.30, 0.48, 0.55), Color("4a5555"), 0.62, 0.16)
	_add_box("状态登记隔离绳", Vector3(2.60, 0.045, 0.045), base + Vector3(0.0, 0.82, 0.55), Color("b77b57"), 0.34, 0.0)
	var lamp_color := Color("78c890") if scanned else Color("e3a86b")
	_add_box("状态登记反馈灯", Vector3(0.18, 0.18, 0.05), base + Vector3(0.0, 2.20, -1.02), lamp_color, 0.30, 0.0, lamp_color, 0.72)
	_add_box("状态登记点顶棚灯带", Vector3(3.62, 0.06, 0.08), base + Vector3(0.0, 2.62, -0.52), Color("d7b078"), 0.34, 0.0, Color("e8b47d"), 0.34)
	_add_box("状态登记台脚左", Vector3(0.10, 0.52, 0.10), base + Vector3(-0.50, 0.27, -0.65), Color("354247"), 0.72, 0.12)
	_add_box("状态登记台脚右", Vector3(0.10, 0.52, 0.10), base + Vector3(0.50, 0.27, -0.65), Color("354247"), 0.72, 0.12)
	_add_box("状态登记文件盒", Vector3(0.34, 0.20, 0.26), base + Vector3(0.48, 1.18, -0.68), Color("8c6752"), 0.70)
	_add_box("状态登记边缘反光条", Vector3(1.50, 0.04, 0.05), base + Vector3(0.0, 1.16, -1.02), lamp_color, 0.30, 0.0, lamp_color, 0.40)
	_add_box("状态登记点道路背景", Vector3(8.40, 0.025, 5.20), base + Vector3(0.0, 0.13, 2.18), Color("4b5357"), 0.94)
	_add_box("状态登记点人行道", Vector3(8.40, 0.035, 0.92), base + Vector3(0.0, 0.16, 0.72), Color("8b8178"), 0.88)
	_add_box("状态登记点路缘边", Vector3(8.20, 0.045, 0.08), base + Vector3(0.0, 0.19, 1.18), Color("b3a28e"), 0.42, 0.0, Color("d7bd94"), 0.16)
	_add_box("状态登记点道路标线", Vector3(0.10, 0.026, 2.40), base + Vector3(-2.40, 0.17, 2.25), Color("d4c38e"), 0.62, 0.0, Color("d4c38e"), 0.14)
	_add_box("状态登记点路边树干", Vector3(0.18, 2.30, 0.18), base + Vector3(2.85, 1.15, 1.38), Color("3d3531"), 0.92)
	_add_box("状态登记点路边树枝", Vector3(0.08, 0.08, 1.10), base + Vector3(2.85, 1.84, 0.98), Color("493d37"), 0.92)
	var feedback_band_color := Color("78c890") if scanned else Color("e3a86b")
	_add_box("状态登记反馈光带", Vector3(0.72, 0.045, 0.035), base + Vector3(0.0, 1.82, -1.08), feedback_band_color, 0.24, 0.0, feedback_band_color, 0.72)
	_add_box("状态登记点遮雨篷前沿", Vector3(4.50, 0.07, 0.10), base + Vector3(0.0, 2.56, -0.12), Color("b68463"), 0.52, 0.04, Color("d39a6d"), 0.16)
	_add_box("状态登记牌底部高光", Vector3(0.72, 0.05, 0.035), base + Vector3(0.0, 0.76, -1.03), lamp_color, 0.28, 0.0, lamp_color, 0.28)
	_add_box("状态登记点左侧信息板", Vector3(0.72, 0.92, 0.05), base + Vector3(-1.54, 1.34, -1.02), Color("34444a"), 0.44, 0.10)
	_add_box("状态登记点信息板标题条", Vector3(0.50, 0.07, 0.025), base + Vector3(-1.54, 1.82, -1.06), Color("d6b277"), 0.30, 0.0, Color("d6b277"), 0.18)
	_add_box("状态登记反馈灯外圈", Vector3(0.28, 0.035, 0.035), base + Vector3(0.0, 2.20, -1.06), lamp_color, 0.24, 0.0, lamp_color, 0.40)
	if scanned:
		_add_box("状态登记成功提示牌", Vector3(1.20, 0.28, 0.035), base + Vector3(0.0, 2.30, -1.08), Color("4d9b74"), 0.36, 0.0, Color("78c890"), 0.52)
		_add_label("状态登记成功文字", "登记成功", base + Vector3(0.0, 2.30, -1.12), Color("e0ffe8"))
	else:
		_add_box("状态登记待扫描提示牌", Vector3(1.20, 0.28, 0.035), base + Vector3(0.0, 2.30, -1.08), Color("765c4d"), 0.42, 0.0, Color("d9a36b"), 0.22)
		_add_label("状态登记待扫描文字", "请扫码登记", base + Vector3(0.0, 2.30, -1.12), Color("ffe2b4"))
	_add_light("状态登记点光", base + Vector3(0.0, 2.30, -0.30), lamp_color, 0.18, 3.2)
	set_meta("visual_state_contract", {"state": "city-07" if scanned else "city-06", "required_layers": ["registration_desk", "qr_panel", "feedback_light"], "scanned": scanned})

func _add_registration_attendant(at: Vector3, scanned: bool) -> void:
	# city-06/07 参考帧的右侧主体是穿红色背心的登记工作人员；
	# 这里补充可读轮廓和扫码动作道具，只属于视觉候选层。
	var root := Node3D.new()
	root.name = "状态登记工作人员"
	root.position = at
	root.rotation_degrees.y = -18.0
	root.set_meta("visual_only", true)
	root.set_meta("candidate_visual_only", true)
	root.set_meta("crowd_role", "登记工作人员")
	root.set_meta("crowd_pose", "扫码" if not scanned else "登记确认")
	state_root.add_child(root)
	var body := _make_capsule("状态登记工作人员身体", 0.23, 0.98, Color("a84545"), 0.72)
	body.position = Vector3(0.0, 0.66, 0.0)
	root.add_child(body)
	var vest := _make_rounded_box("状态登记工作人员背心", Vector3(0.38, 0.58, 0.06), Vector3(0.0, 0.72, -0.235), Color("d75b4d"), 0.50)
	root.add_child(vest)
	var shirt := _make_rounded_box("状态登记工作人员内衬", Vector3(0.30, 0.46, 0.04), Vector3(0.0, 0.74, -0.275), Color("e7dfd0"), 0.62)
	root.add_child(shirt)
	var head := _make_sphere("状态登记工作人员头部", 0.20, Color("b78968"), 0.70)
	head.position = Vector3(0.0, 1.38, 0.0)
	root.add_child(head)
	var hair := _make_sphere("状态登记工作人员发型", 0.205, Color("24272a"), 0.84)
	hair.scale = Vector3(1.0, 0.44, 0.94)
	hair.position = Vector3(0.0, 1.54, 0.0)
	root.add_child(hair)
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var arm := _make_capsule("状态登记工作人员手臂-" + suffix, 0.055, 0.44, Color("e7dfd0"), 0.74)
		arm.position = Vector3(side * 0.27, 0.70, -0.02)
		arm.rotation_degrees.z = -22.0 * side
		root.add_child(arm)
		var shoe := _make_rounded_box("状态登记工作人员鞋子-" + suffix, Vector3(0.18, 0.10, 0.30), Vector3(side * 0.12, 0.12, -0.06), Color("252a2c"), 0.84)
		root.add_child(shoe)
	var scanner := _make_box("状态登记工作人员扫码器", Vector3(0.11, 0.18, 0.04), Color("2e383b"), 0.34, 0.08)
	scanner.position = Vector3(0.29, 0.74, -0.23)
	root.add_child(scanner)
	var light_color := Color("78c890") if scanned else Color("e3a86b")
	var scanner_light := _make_box("状态登记工作人员扫码灯", Vector3(0.045, 0.045, 0.012), light_color, 0.24, 0.0, light_color, 0.72)
	scanner_light.position = Vector3(0.29, 0.80, -0.255)
	root.add_child(scanner_light)

func _build_drive_state(traffic: bool) -> void:
	var z := 3.0 if not traffic else 1.0
	_add_box("状态驾驶道路", Vector3(9.6, 0.025, 12.0), Vector3(4.5, 0.13, z), Color("4b5357"), 0.94)
	_add_box("状态驾驶左侧人行道", Vector3(1.45, 0.035, 12.0), Vector3(-1.05, 0.16, z), Color("8b8178"), 0.88)
	_add_box("状态驾驶右侧人行道", Vector3(1.45, 0.035, 12.0), Vector3(10.05, 0.16, z), Color("8b8178"), 0.88)
	_add_box("状态驾驶左侧建筑", Vector3(3.20, 4.60, 11.0), Vector3(-2.65, 2.30, z - 0.25), Color("765d57"), 0.82)
	_add_box("状态驾驶右侧建筑", Vector3(3.20, 4.20, 11.0), Vector3(11.65, 2.10, z + 0.40), Color("6b6f72"), 0.84)
	for block_index in range(3):
		var block_z := z - 4.30 + float(block_index) * 4.30
		_add_city_facade("状态驾驶左侧立面-%02d" % block_index, Vector3(-2.65, 0.0, block_z), Color("765d57"), Color("d59b79"), -1.0)
		_add_city_facade("状态驾驶右侧立面-%02d" % block_index, Vector3(11.65, 0.0, block_z + 0.35), Color("626d70"), Color("87a7a4"), 1.0)
		_add_box("状态驾驶左侧立面窗格-%02d" % block_index, Vector3(0.08, 0.82, 1.34), Vector3(-1.04, 2.42, block_z - 0.18), Color("344a50"), 0.22, 0.06, Color("92b6b2"), 0.14)
		_add_box("状态驾驶右侧立面窗格-%02d" % block_index, Vector3(0.08, 0.78, 1.18), Vector3(10.18, 2.30, block_z + 0.18), Color("35484b"), 0.22, 0.06, Color("d6a06f"), 0.18)
		# 参考 city-08 的右侧不是一整面平墙，而是连续的临街楼层、阳台和
		# 遮雨篷。补齐这些横向比例线，帮助车尾镜头读出街道深度；节点仍
		# 只属于 visual_only 表现层，不创建碰撞、导航或任务状态。
		_add_box("状态驾驶右侧立面阳台板-%02d" % block_index, Vector3(0.30, 0.06, 2.26), Vector3(9.98, 0.92, block_z + 0.18), Color("554b49"), 0.72, 0.04)
		_add_box("状态驾驶右侧立面阳台栏杆-%02d-左" % block_index, Vector3(0.08, 0.46, 0.08), Vector3(9.86, 1.16, block_z - 0.78), Color("9c846d"), 0.46, 0.12)
		_add_box("状态驾驶右侧立面阳台栏杆-%02d-中" % block_index, Vector3(0.08, 0.46, 0.08), Vector3(9.86, 1.16, block_z + 0.18), Color("9c846d"), 0.46, 0.12)
		_add_box("状态驾驶右侧立面阳台栏杆-%02d-右" % block_index, Vector3(0.08, 0.46, 0.08), Vector3(9.86, 1.16, block_z + 1.14), Color("9c846d"), 0.46, 0.12)
		_add_box("状态驾驶右侧街铺遮雨篷-%02d" % block_index, Vector3(0.34, 0.08, 2.46), Vector3(9.92, 1.76, block_z + 0.18), Color("8e6258"), 0.62, 0.04)
		_add_box("状态驾驶右侧街铺遮雨篷边-%02d" % block_index, Vector3(0.08, 0.10, 2.50), Vector3(9.74, 1.70, block_z + 0.18), Color("c18c63"), 0.42, 0.02, Color("d6a06f"), 0.14)
		_add_box("状态驾驶右侧街铺底部收口-%02d" % block_index, Vector3(0.16, 0.22, 2.58), Vector3(9.82, 0.56, block_z + 0.18), Color("514b4b"), 0.58, 0.04)
		_add_label("状态驾驶右侧街铺招牌-%02d" % block_index, "晨光杂货", Vector3(9.48, 2.16, block_z + 0.16), Color("f0c38c"))
	for tree_index in range(2):
		var tree_z := z - 3.5 + float(tree_index) * 5.6
		_add_box("状态驾驶裸树树干-%02d" % tree_index, Vector3(0.16, 2.30, 0.16), Vector3(-0.25, 1.15, tree_z), Color("3d3531"), 0.92)
		_add_box("状态驾驶裸树左枝-%02d" % tree_index, Vector3(0.10, 0.10, 1.10), Vector3(-0.25, 1.82, tree_z - 0.38), Color("493d37"), 0.92)
		_add_box("状态驾驶裸树右枝-%02d" % tree_index, Vector3(0.10, 0.10, 0.94), Vector3(-0.25, 1.64, tree_z + 0.34), Color("493d37"), 0.92)
		_add_box("状态驾驶裸树上层枝-%02d-左" % tree_index, Vector3(0.075, 0.075, 1.42), Vector3(-0.25, 2.28, tree_z - 0.62), Color("493d37"), 0.92)
		_add_box("状态驾驶裸树上层枝-%02d-右" % tree_index, Vector3(0.075, 0.075, 1.22), Vector3(-0.25, 2.12, tree_z + 0.64), Color("493d37"), 0.92)
		_add_box("状态驾驶裸树侧枝-%02d-远" % tree_index, Vector3(0.90, 0.075, 0.075), Vector3(-0.67, 2.00, tree_z - 0.18), Color("493d37"), 0.92)
	_add_box("状态驾驶右侧暖窗带", Vector3(0.06, 1.25, 8.60), Vector3(10.02, 2.65, z + 0.38), Color("c98d63"), 0.42, 0.0, Color("e8b47d"), 0.24)
	for x in [1.2, 4.5, 7.8]:
		_add_box("状态驾驶车道线", Vector3(0.10, 0.025, 1.70), Vector3(x, 0.16, z - 3.2), Color("d4c38e"), 0.62, 0.0, Color("d4c38e"), 0.16)
	var lane_index := 0
	for lane_x in [1.55, 7.45]:
		for segment in range(5):
			_add_box("状态驾驶纵向虚线-%02d-%02d" % [lane_index, segment], Vector3(0.08, 0.026, 0.72), Vector3(lane_x, 0.17, z - 5.0 + float(segment) * 2.40), Color("d8c58e"), 0.60, 0.0, Color("d8c58e"), 0.14)
		lane_index += 1
	for crossing in range(4):
		_add_box("状态驾驶近景斑马线-%02d" % crossing, Vector3(8.80, 0.028, 0.16), Vector3(4.5, 0.18, z + 4.10 + float(crossing) * 0.32), Color("c6bda5"), 0.72, 0.0, Color("c6bda5"), 0.10)
	_add_box("状态驾驶近景方向箭头", Vector3(0.18, 0.028, 0.86), Vector3(4.5, 0.19, z + 2.20), Color("d9c993"), 0.62, 0.0, Color("d9c993"), 0.12)
	_add_box("状态驾驶近景方向箭头头", Vector3(0.62, 0.028, 0.18), Vector3(4.5, 0.19, z + 2.58), Color("d9c993"), 0.62, 0.0, Color("d9c993"), 0.12)
	_add_box("状态驾驶路面反光钉中", Vector3(0.08, 0.025, 0.08), Vector3(4.5, 0.19, z + 1.05), Color("e7c77d"), 0.26, 0.0, Color("e7c77d"), 0.42)
	_add_box("状态驾驶主车接触阴影", Vector3(1.46, 0.018, 2.26), Vector3(4.5, 0.155, z + 0.72), Color("252a2d"), 0.88)
	_add_box("状态驾驶路口导视牌杆", Vector3(0.10, 2.10, 0.10), Vector3(0.08, 1.05, z + 3.72), Color("4f595a"), 0.50, 0.18)
	_add_box("状态驾驶路口导视牌面", Vector3(0.72, 0.46, 0.05), Vector3(0.08, 2.04, z + 3.72), Color("b18a5d"), 0.42, 0.0, Color("d9b27b"), 0.12)
	_add_label("状态驾驶路口导视牌文字", "南城路 · 西街", Vector3(0.08, 2.04, z + 3.64), Color("fff0c7"))
	_add_box("状态驾驶街角电缆", Vector3(4.30, 0.035, 0.035), Vector3(0.08, 2.86, z + 3.72), Color("242a2d"), 0.92)
	for side in [-1.0, 1.0]:
		var side_label := "左" if side < 0.0 else "右"
		_add_box("状态驾驶路缘", Vector3(0.22, 0.16, 12.0), Vector3(4.5 + side * 5.0, 0.22, z), Color("7c7069"), 0.86)
		for seam in range(4):
			_add_box("状态驾驶人行道拼缝-%s-%02d" % [side_label, seam], Vector3(0.04, 0.025, 1.60), Vector3(4.5 + side * 4.88, 0.205, z - 4.2 + float(seam) * 2.8), Color("6f6762"), 0.62)
		_add_box("状态驾驶街灯", Vector3(0.10, 2.80, 0.10), Vector3(4.5 + side * 4.10, 1.40, z - 2.8), Color("4f5b60"), 0.44, 0.22)
		_add_box("状态驾驶灯头", Vector3(0.44, 0.10, 0.18), Vector3(4.5 + side * 4.10, 2.72, z - 2.8), Color("e3a86b"), 0.34, 0.0, Color("e3a86b"), 0.45)
		for bollard in range(3):
			_add_box("状态驾驶人行道隔离柱-%s-%02d" % [str(side), bollard], Vector3(0.12, 0.66, 0.12), Vector3(4.5 + side * 4.35, 0.48, z - 4.0 + float(bollard) * 3.0), Color("4d5758"), 0.70, 0.18)
	if traffic:
		_add_drive_vehicle_detail("状态驾驶远景车辆左", Vector3(2.3, 0.0, z - 5.0), Color("6a7883"), 0.0)
		_add_drive_vehicle_detail("状态驾驶远景车辆右", Vector3(6.7, 0.0, z - 6.7), Color("9b665b"), 180.0)
		_add_box("状态驾驶路口停止线", Vector3(8.80, 0.028, 0.14), Vector3(4.5, 0.18, z - 1.18), Color("c6bda5"), 0.72, 0.0, Color("c6bda5"), 0.10)
		_add_box("状态驾驶路口转向箭头竖", Vector3(0.16, 0.028, 0.74), Vector3(4.5, 0.19, z + 1.68), Color("d9c993"), 0.62, 0.0, Color("d9c993"), 0.12)
		_add_box("状态驾驶路口转向箭头头", Vector3(0.58, 0.028, 0.16), Vector3(4.5, 0.19, z + 2.04), Color("d9c993"), 0.62, 0.0, Color("d9c993"), 0.12)
		_add_box("状态驾驶交通信号杆", Vector3(0.12, 3.40, 0.12), Vector3(8.92, 1.70, z - 1.80), Color("3f494b"), 0.58, 0.18)
		_add_box("状态驾驶交通信号横臂", Vector3(1.70, 0.12, 0.12), Vector3(8.20, 3.26, z - 1.80), Color("3f494b"), 0.58, 0.18)
		_add_box("状态驾驶交通信号红灯", Vector3(0.20, 0.20, 0.08), Vector3(7.52, 3.03, z - 1.80), Color("b4473e"), 0.30, 0.0, Color("e66b5a"), 0.46)
		_add_box("状态驾驶交通信号黄灯", Vector3(0.20, 0.20, 0.08), Vector3(7.52, 2.76, z - 1.80), Color("b98c43"), 0.30, 0.0, Color("e9c36d"), 0.26)
		_add_box("状态驾驶交通信号绿灯", Vector3(0.20, 0.20, 0.08), Vector3(7.52, 2.49, z - 1.80), Color("4d8a61"), 0.30, 0.0, Color("8ed09a"), 0.18)
		_add_box("状态驾驶交通信号灯罩", Vector3(0.34, 0.90, 0.06), Vector3(7.52, 2.76, z - 1.76), Color("252d31"), 0.40, 0.18)
		_add_box("状态驾驶交通信号灯罩顶沿", Vector3(0.42, 0.08, 0.08), Vector3(7.52, 3.24, z - 1.76), Color("151b1e"), 0.52, 0.18)
		_add_box("状态驾驶路口转角路缘", Vector3(2.20, 0.16, 0.22), Vector3(8.55, 0.22, z - 1.18), Color("766d68"), 0.78)
		_add_box("状态驾驶路口横向车流接触带", Vector3(0.10, 0.018, 3.20), Vector3(8.10, 0.155, z - 1.46), Color("292f32"), 0.86)
		_add_box("状态驾驶路面反光钉左", Vector3(0.08, 0.025, 0.08), Vector3(1.55, 0.19, z - 0.80), Color("e7c77d"), 0.26, 0.0, Color("e7c77d"), 0.42)
		_add_box("状态驾驶路面反光钉右", Vector3(0.08, 0.025, 0.08), Vector3(7.45, 0.19, z - 0.80), Color("e7c77d"), 0.26, 0.0, Color("e7c77d"), 0.42)
	else:
		# city-08 仍要保留黄昏驾驶段的远景交通层，避免主车成为孤立物体。
		_add_drive_vehicle_detail("状态驾驶远景车辆左", Vector3(2.1, 0.0, z - 5.3), Color("65737c"), 0.0)
		_add_drive_vehicle_detail("状态驾驶远景车辆右", Vector3(6.9, 0.0, z - 6.9), Color("8e6258"), 180.0)
		_add_box("状态驾驶主车路径反光带", Vector3(0.08, 0.025, 4.10), Vector3(4.5, 0.19, z - 1.10), Color("d4b476"), 0.30, 0.0, Color("e8c985"), 0.12)
	_add_light("状态驾驶黄昏光", Vector3(4.5, 2.4, z - 4.0), Color("e09b79"), 0.18, 6.0)
	set_meta("visual_state_contract", {"state": "city-09" if traffic else "city-08", "required_layers": ["road", "lane_marking", "curb", "street_lights", "traffic" if traffic else "vehicle_path"]})

func _add_drive_vehicle_detail(prefix: String, at: Vector3, body_color: Color, yaw: float) -> void:
	var root := Node3D.new()
	root.name = prefix + "细节"
	root.position = at
	root.rotation_degrees.y = yaw
	root.set_meta("visual_only", true)
	root.set_meta("candidate_visual_only", true)
	root.set_meta("original_procedural_asset", true)
	state_root.add_child(root)
	_add_box_to(root, prefix + "车身", Vector3(1.32, 0.58, 2.12), Vector3(0.0, 0.48, 0.0), body_color, 0.58, 0.12)
	_add_box_to(root, prefix + "车顶", Vector3(1.08, 0.26, 0.92), Vector3(0.0, 0.90, -0.12), body_color.lightened(0.10), 0.48, 0.08)
	_add_box_to(root, prefix + "前挡风玻璃", Vector3(0.88, 0.20, 0.05), Vector3(0.0, 0.86, -0.60), Color("33464e"), 0.24, 0.22)
	_add_box_to(root, prefix + "后挡风玻璃", Vector3(0.88, 0.20, 0.05), Vector3(0.0, 0.84, 0.38), Color("33464e"), 0.24, 0.22)
	_add_box_to(root, prefix + "前灯左", Vector3(0.22, 0.12, 0.05), Vector3(-0.42, 0.55, -1.08), Color("f4d9a5"), 0.24, 0.0, Color("f4d9a5"), 0.40)
	_add_box_to(root, prefix + "前灯右", Vector3(0.22, 0.12, 0.05), Vector3(0.42, 0.55, -1.08), Color("f4d9a5"), 0.24, 0.0, Color("f4d9a5"), 0.40)
	for wheel_side in [-0.62, 0.62]:
		_add_box_to(root, prefix + "车轮" + ("左" if wheel_side < 0.0 else "右"), Vector3(0.16, 0.34, 0.42), Vector3(wheel_side, 0.28, -0.56), Color("24292b"), 0.94, 0.0)
	set_meta("drive_vehicle_visual_detail", true)

func _build_destination_drive_state() -> void:
	_build_drive_state(true)
	_add_box("状态10目标门面远景", Vector3(4.80, 3.40, 0.16), Vector3(10.0, 1.70, 10.80), Color("76594d"), 0.78)
	_add_box("状态10目标门面入口", Vector3(1.24, 2.24, 0.08), Vector3(9.05, 1.12, 10.66), Color("29363b"), 0.42, 0.18)
	_add_box("状态10目标门面入口门框左", Vector3(0.10, 2.36, 0.10), Vector3(8.40, 1.18, 10.60), Color("b28b68"), 0.42, 0.12)
	_add_box("状态10目标门面入口门框右", Vector3(0.10, 2.36, 0.10), Vector3(9.70, 1.18, 10.60), Color("b28b68"), 0.42, 0.12)
	_add_box("状态10目标门面橱窗左", Vector3(1.18, 1.36, 0.05), Vector3(11.00, 1.52, 10.65), Color("32464c"), 0.28, 0.12, Color("86aeb0"), 0.12)
	_add_box("状态10目标门面橱窗右", Vector3(1.18, 1.36, 0.05), Vector3(12.28, 1.52, 10.65), Color("32464c"), 0.28, 0.12, Color("86aeb0"), 0.12)
	_add_box("状态10目标门面橱窗横档", Vector3(2.56, 0.08, 0.06), Vector3(11.64, 1.52, 10.61), Color("9a765f"), 0.34, 0.08)
	_add_box("状态10目标灯带", Vector3(3.80, 0.12, 0.08), Vector3(10.0, 3.05, 10.66), Color("e3a86b"), 0.34, 0.0, Color("e3a86b"), 0.55)
	_add_box("状态10目标门面遮雨篷", Vector3(4.92, 0.12, 0.64), Vector3(10.0, 2.58, 10.42), Color("8e6557"), 0.62, 0.04)
	_add_box("状态10目标门面遮雨篷支撑左", Vector3(0.10, 1.12, 0.10), Vector3(7.78, 2.04, 10.43), Color("4b5556"), 0.48, 0.14)
	_add_box("状态10目标门面遮雨篷支撑右", Vector3(0.10, 1.12, 0.10), Vector3(12.22, 2.04, 10.43), Color("4b5556"), 0.48, 0.14)
	_add_box("状态10目标门面识别牌", Vector3(2.42, 0.72, 0.06), Vector3(10.0, 2.20, 10.58), Color("bd3f35"), 0.46, 0.0, Color("e3a86b"), 0.28)
	_add_box("状态10目标门面识别牌边框", Vector3(2.58, 0.08, 0.035), Vector3(10.0, 2.56, 10.55), Color("e1b878"), 0.28, 0.0, Color("f0cf8d"), 0.18)
	for sign_index in range(4):
		_add_box("状态10目标门面识别牌字块-%02d" % sign_index, Vector3(0.34, 0.16, 0.035), Vector3(9.28 + float(sign_index) * 0.48, 2.24, 10.50), Color("ffe2b4"), 0.34, 0.0, Color("ffe2b4"), 0.22)
	_add_box("状态10目标门面台阶", Vector3(2.10, 0.14, 0.52), Vector3(9.05, 0.20, 11.04), Color("85756c"), 0.64)
	_add_box("状态10目标门面台阶反光边", Vector3(2.14, 0.035, 0.05), Vector3(9.05, 0.30, 10.80), Color("d5a86d"), 0.30, 0.0, Color("e6b981"), 0.18)
	_add_box("状态10目标门面地面引导标", Vector3(1.72, 0.025, 0.06), Vector3(9.05, 0.18, 11.72), Color("c59b64"), 0.46, 0.0, Color("d4b276"), 0.18)
	_add_box("状态10目标门面门口灯", Vector3(0.12, 0.36, 0.08), Vector3(9.05, 2.08, 10.52), Color("e3a86b"), 0.28, 0.0, Color("f1c37f"), 0.56)
	_add_box("状态10目标门面招牌下沿", Vector3(2.50, 0.10, 0.08), Vector3(10.0, 1.82, 10.54), Color("6d3b39"), 0.46, 0.02, Color("b7775c"), 0.16)
	_add_box("状态10目标门面入口门把手", Vector3(0.08, 0.16, 0.08), Vector3(9.44, 1.08, 10.48), Color("d1a66b"), 0.30, 0.0, Color("f0c687"), 0.24)
	_add_box("状态10目标门面橱窗竖分格左", Vector3(0.06, 1.30, 0.06), Vector3(11.64, 1.52, 10.56), Color("9a765f"), 0.34, 0.08)
	_add_box("状态10目标门面橱窗竖分格右", Vector3(0.06, 1.30, 0.06), Vector3(12.28, 1.52, 10.56), Color("9a765f"), 0.34, 0.08)
	_add_box("状态10目标门面台阶侧边", Vector3(0.10, 0.18, 0.58), Vector3(7.98, 0.22, 11.04), Color("625b58"), 0.64)
	_add_box("状态10目标门面门前碎纸", Vector3(0.34, 0.018, 0.22), Vector3(8.10, 0.16, 11.62), Color("c7b08b"), 0.48)
	_add_label("状态10目标门面文字", "下一站：旺铺", Vector3(10.0, 2.26, 10.50), Color("ffe2b4"))
	_add_light("状态10目标门面暖光", Vector3(10.0, 2.30, 10.24), Color("e09b79"), 0.18, 3.8)
	set_meta("visual_state_contract", {"state": "city-10", "required_layers": ["drive", "traffic", "destination_facade"]})

func _build_endpoint_state() -> void:
	var base := Vector3(10.0, 0.0, 11.0)
	_add_box("状态11终点店铺门面", Vector3(5.20, 3.60, 0.18), base + Vector3(0.0, 1.80, 0.0), Color("7f554a"), 0.78)
	_add_storefront_detail(base, "状态11")
	_add_box("状态11终点卷帘门", Vector3(2.80, 2.22, 0.08), base + Vector3(0.0, 1.12, -0.14), Color("3a454b"), 0.48, 0.20)
	for shutter_row in range(7):
		_add_box("状态11卷帘门横槽-%02d" % shutter_row, Vector3(2.66, 0.035, 0.035), base + Vector3(0.0, 0.30 + float(shutter_row) * 0.27, -0.20), Color("647178"), 0.40, 0.18)
	_add_box("状态11终点门把手", Vector3(0.24, 0.10, 0.06), base + Vector3(0.0, 0.58, -0.26), Color("c29a63"), 0.36, 0.20)
	_add_box("状态11侧面转让海报", Vector3(0.64, 1.05, 0.035), base + Vector3(2.18, 1.38, -0.22), Color("d4b77c"), 0.56, 0.0, Color("d4b77c"), 0.12)
	_add_box("状态11旺铺转让招牌底板", Vector3(3.42, 0.58, 0.06), base + Vector3(0.0, 3.48, -0.28), Color("6b2e2c"), 0.48, 0.04, Color("9c4439"), 0.20)
	for sign_index in range(4):
		_add_box("状态11旺铺转让字块-%02d" % sign_index, Vector3(0.42, 0.18, 0.035), base + Vector3(-1.18 + float(sign_index) * 0.78, 3.50, -0.35), Color("f1c782"), 0.36, 0.0, Color("f1c782"), 0.30)
	_add_label("状态11旺铺转让文字", "旺铺转让", base + Vector3(0.0, 3.50, -0.40), Color("fff0c7"))
	_add_box("状态11卷帘门左导轨", Vector3(0.08, 2.30, 0.08), base + Vector3(-1.48, 1.18, -0.22), Color("7f8b8f"), 0.42, 0.16)
	_add_box("状态11卷帘门右导轨", Vector3(0.08, 2.30, 0.08), base + Vector3(1.48, 1.18, -0.22), Color("7f8b8f"), 0.42, 0.16)
	_add_box("状态11卷帘门顶部卷轴盒", Vector3(2.92, 0.16, 0.10), base + Vector3(0.0, 2.32, -0.22), Color("283136"), 0.54, 0.16)
	_add_box("状态11卷帘门底部导轨", Vector3(2.82, 0.08, 0.12), base + Vector3(0.0, 0.22, -0.26), Color("9a8d7e"), 0.48, 0.16)
	_add_box("状态11终点门槛反光边", Vector3(2.90, 0.035, 0.08), base + Vector3(0.0, 0.16, 0.02), Color("c49b66"), 0.30, 0.0, Color("e4bc7b"), 0.18)
	_add_box("状态11侧面转让海报边框", Vector3(0.70, 1.11, 0.025), base + Vector3(2.18, 1.38, -0.24), Color("b78e62"), 0.40, 0.0, Color("d7b67f"), 0.16)
	_add_box("状态11门面左侧灯箱", Vector3(0.16, 1.42, 0.08), base + Vector3(-2.42, 1.92, -0.26), Color("d18a5d"), 0.40, 0.0, Color("e9b276"), 0.22)
	_add_box("状态11终点人行道拼缝", Vector3(4.10, 0.025, 0.055), base + Vector3(0.0, 0.15, 1.74), Color("9c8e7e"), 0.70)
	for bollard_index in range(2):
		_add_box("状态11交付隔离柱-%02d" % bollard_index, Vector3(0.12, 0.62, 0.12), base + Vector3(-1.72 + float(bollard_index) * 3.44, 0.48, 1.52), Color("4d5758"), 0.66, 0.16)
	_add_box("状态11终点目标灯", Vector3(4.30, 0.11, 0.08), base + Vector3(0.0, 3.16, -0.16), Color("e3a86b"), 0.34, 0.0, Color("e3a86b"), 0.60)
	_add_box("状态11交付地面标记", Vector3(3.20, 0.025, 0.06), base + Vector3(0.0, 0.14, 1.18), Color("c29a63"), 0.46, 0.0, Color("c29a63"), 0.24)
	_add_label("状态11交付地面文字", "交付点 · 12", base + Vector3(0.0, 0.24, 1.18), Color("fff0c7"))
	_add_box("状态11终点门前碎纸左", Vector3(0.38, 0.018, 0.24), base + Vector3(-1.42, 0.16, 1.04), Color("c7b08b"), 0.46)
	_add_box("状态11终点门前碎纸右", Vector3(0.24, 0.018, 0.16), base + Vector3(1.22, 0.16, 1.28), Color("b79f7c"), 0.46)
	_add_box("状态11终点门面暖光边", Vector3(4.40, 0.05, 0.06), base + Vector3(0.0, 2.92, -0.24), Color("e3a86b"), 0.30, 0.0, Color("f0bd77"), 0.52)
	_add_label("状态11终点取货提示", "配送取货", base + Vector3(-2.42, 2.70, -0.32), Color("ffe0a8"))
	_add_light("状态11终点暖光", base + Vector3(0.0, 2.60, 0.45), Color("e09b79"), 0.22, 4.2)
	set_meta("visual_state_contract", {"state": "city-11", "required_layers": ["endpoint_facade", "shutter", "delivery_mark", "warm_light"]})

func _add_storefront_detail(base: Vector3, prefix: String) -> void:
	_add_box(prefix + "门面左立柱", Vector3(0.18, 3.25, 0.20), base + Vector3(-3.12, 1.62, -0.16), Color("4d4544"), 0.58, 0.08)
	_add_box(prefix + "门面右立柱", Vector3(0.18, 3.25, 0.20), base + Vector3(3.12, 1.62, -0.16), Color("4d4544"), 0.58, 0.08)
	for window_index in range(3):
		var x := -2.20 + float(window_index) * 2.20
		_add_box(prefix + "门面窗框横-%02d" % window_index, Vector3(1.48, 0.06, 0.08), base + Vector3(x, 2.10, -0.27), Color("c6b29a"), 0.44, 0.06)
		_add_box(prefix + "门面窗内光-%02d" % window_index, Vector3(1.20, 0.78, 0.035), base + Vector3(x, 1.58, -0.27), Color("b77857" if window_index % 2 == 0 else "718f90"), 0.40, 0.0, Color("c7835a"), 0.16)
	_add_box(prefix + "门头装饰短旗", Vector3(0.10, 0.64, 0.06), base + Vector3(-2.74, 2.84, -0.42), Color("d9b36e"), 0.50, 0.0, Color("d9b36e"), 0.22)
	_add_box(prefix + "门头装饰短旗右", Vector3(0.10, 0.64, 0.06), base + Vector3(2.74, 2.84, -0.42), Color("d9b36e"), 0.50, 0.0, Color("d9b36e"), 0.22)
	_add_label(prefix + "原创门店标识", "新潮生活", base + Vector3(0.0, 3.45, -0.24), Color("ffe2b4"))
	if prefix == "状态01":
		_add_label("状态01任务门头标识", "免费领取鸡蛋", base + Vector3(0.0, 3.16, -0.26), Color("fff0c7"))

func _add_city_facade(node_prefix: String, base: Vector3, wall_color: Color, window_color: Color, side: float) -> void:
	_add_box(node_prefix + "墙体", Vector3(3.05, 4.55, 2.55), base + Vector3(0.0, 2.28, 0.0), wall_color, 0.86)
	_add_box(node_prefix + "檐口", Vector3(3.20, 0.16, 2.70), base + Vector3(0.0, 4.48, -0.05), wall_color.darkened(0.20), 0.70)
	for row in range(2):
		for column in range(2):
			var x := -0.82 + float(column) * 1.64
			var y := 2.20 + float(row) * 1.18
			_add_box(node_prefix + "窗户-%02d-%02d" % [row, column], Vector3(0.88, 0.56, 0.05), base + Vector3(x, y, -1.30), window_color, 0.34, 0.02, window_color, 0.14)
	_add_box(node_prefix + "底部门头", Vector3(2.60, 0.58, 0.08), base + Vector3(0.0, 0.88, -1.32), Color("7e5148" if side < 0.0 else "536a6f"), 0.70)
	_add_box(node_prefix + "底部门头遮雨篷", Vector3(2.72, 0.10, 0.56), base + Vector3(0.0, 1.34, -1.48), Color("9f765d"), 0.62, 0.02)

func _add_label(node_name: String, label_text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = label_text
	label.position = at
	label.modulate = color
	label.font_size = 28
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.set_meta("visual_only", true)
	label.set_meta("candidate_visual_only", true)
	label.set_meta("original_procedural_asset", true)
	state_root.add_child(label)

func _add_crowd_marker(at: Vector3, index: int) -> void:
	var root := Node3D.new()
	root.name = "状态人群标记-%02d" % index
	root.position = at
	var role_index := index % 3
	var body_index := index % 5
	var body_colors := [Color("526879"), Color("8a6259"), Color("6d765d"), Color("6e5f78"), Color("a16d4f")]
	var skin_colors := [Color("b78968"), Color("c79673"), Color("9d6d54"), Color("d0a07b"), Color("a8795d")]
	var hair_colors := [Color("1f252b"), Color("302523"), Color("4b3428"), Color("202b32"), Color("3a2d30")]
	var body_color: Color = body_colors[body_index]
	var skin_color: Color = skin_colors[body_index]
	var hair_color: Color = hair_colors[body_index]
	var crowd_role: String = ["店员", "顾客", "配送员"][role_index]
	root.rotation_degrees.y = -8.0 if index % 2 == 0 else 7.0
	var scale_value := 0.88 + float(index % 4) * 0.06
	root.scale = Vector3(scale_value, scale_value, scale_value)
	root.set_meta("visual_only", true)
	root.set_meta("candidate_visual_only", true)
	root.set_meta("crowd_role", crowd_role)
	root.set_meta("crowd_pose", ["迎宾", "提袋", "扫码"][role_index])
	root.set_meta("crowd_variant", body_index)
	state_root.add_child(root)
	var body := _make_capsule("状态人群身体", 0.22, 0.92, body_color, 0.76)
	body.position = Vector3(0.0, 0.62, 0.0)
	body.rotation_degrees.z = -4.0 if index % 2 == 0 else 4.0
	root.add_child(body)
	var head := _make_sphere("状态人群头部", 0.19, skin_color, 0.70)
	head.position = Vector3(0.0, 1.30, 0.0)
	root.add_child(head)
	var hair := _make_sphere("状态人群发型", 0.195, hair_color, 0.84)
	var hair_height := 0.38 + float(index % 3) * 0.05
	hair.scale = Vector3(1.0, hair_height, 0.94)
	hair.position = Vector3(0.0, 1.46, 0.0)
	root.add_child(hair)
	var left_arm := _make_capsule("状态人群左臂", 0.055, 0.42, body_color, 0.78)
	left_arm.position = Vector3(-0.27, 0.62, 0.0)
	left_arm.rotation_degrees.z = -18.0
	root.add_child(left_arm)
	var right_arm := _make_capsule("状态人群右臂", 0.055, 0.42, body_color, 0.78)
	right_arm.position = Vector3(0.27, 0.62, 0.0)
	right_arm.rotation_degrees.z = 18.0
	root.add_child(right_arm)
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var shoe := _make_rounded_box("状态人群鞋子-" + suffix, Vector3(0.18, 0.10, 0.30), Vector3(side * 0.12, 0.12, -0.06), Color("252a2c"), 0.84)
		root.add_child(shoe)
	var identity_pin := _make_rounded_box("状态人群身份牌", Vector3(0.10, 0.12, 0.025), Vector3(0.18, 0.79, -0.21), Color("d8b36f"), 0.50)
	root.add_child(identity_pin)
	var bag := _make_rounded_box("状态人群肩包", Vector3(0.22, 0.34, 0.14), Vector3(0.26, 0.52, 0.12), Color("29373d") if body_index % 2 == 0 else Color("704e42"), 0.78)
	root.add_child(bag)
	var collar := _make_rounded_box("状态人群衣领", Vector3(0.24, 0.10, 0.045), Vector3(0.0, 1.02, -0.22), skin_color.darkened(0.28), 0.58)
	root.add_child(collar)
	# 近景人群不再全部使用同一套轮廓：店员、顾客、配送员分别承担
	# 迎宾、提袋、扫码三个可读动作。它们只属于视觉候选层，不接入交互或任务状态。
	match role_index:
		0:
			var apron := _make_rounded_box("状态人群围裙", Vector3(0.32, 0.52, 0.035), Vector3(0.0, 0.66, -0.235), Color("d5a46c"), 0.52)
			root.add_child(apron)
			var cap := _make_rounded_box("状态人群店员帽", Vector3(0.34, 0.09, 0.24), Vector3(0.0, 1.50, -0.01), Color("b33f36"), 0.46)
			root.add_child(cap)
			var greeting_hand := _make_rounded_box("状态人群迎宾手牌", Vector3(0.16, 0.24, 0.035), Vector3(0.32, 0.82, -0.18), Color("ecd09a"), 0.40)
			root.add_child(greeting_hand)
		1:
			var tote := _make_rounded_box("状态人群购物袋", Vector3(0.26, 0.34, 0.16), Vector3(-0.28, 0.43, -0.06), Color("c47a52"), 0.72)
			root.add_child(tote)
			var tote_handle := _make_rounded_box("状态人群购物袋提手", Vector3(0.20, 0.045, 0.035), Vector3(-0.28, 0.64, -0.06), Color("e2bd80"), 0.42)
			root.add_child(tote_handle)
		2:
			var delivery_box := _make_rounded_box("状态人群配送背箱", Vector3(0.38, 0.42, 0.26), Vector3(0.0, 0.75, 0.20), Color("647b72"), 0.76)
			root.add_child(delivery_box)
			var scanner := _make_rounded_box("状态人群配送扫码器", Vector3(0.10, 0.18, 0.04), Vector3(0.30, 0.68, -0.18), Color("d7b36d"), 0.34)
			root.add_child(scanner)
			var scanner_light := _make_rounded_box("状态人群配送扫码灯", Vector3(0.045, 0.045, 0.012), Vector3(0.30, 0.70, -0.205), Color("f0c56e"), 0.24)
			root.add_child(scanner_light)

func _add_box_to(parent: Node3D, node_name: String, size: Vector3, at: Vector3, color: Color, roughness := 0.82, metallic := 0.0, emission := Color(0.0, 0.0, 0.0, 0.0), emission_energy := 0.0) -> MeshInstance3D:
	var node := _make_box(node_name, size, color, roughness, metallic, emission, emission_energy)
	node.position = at
	parent.add_child(node)
	return node

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color, roughness := 0.82, metallic := 0.0, emission := Color(0.0, 0.0, 0.0, 0.0), emission_energy := 0.0) -> MeshInstance3D:
	var node := _make_box(node_name, size, color, roughness, metallic, emission, emission_energy)
	node.position = at
	state_root.add_child(node)
	return node

func _make_box(node_name: String, size: Vector3, color: Color, roughness: float, metallic: float, emission := Color(0.0, 0.0, 0.0, 0.0), emission_energy := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	node.material_override = material
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("city_scene_state", active_state)
	return node

func _make_capsule(node_name: String, radius: float, height: float, color: Color, roughness: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.rings = 8
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	node.material_override = material
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	node.set_meta("original_procedural_asset", true)
	return node

func _make_sphere(node_name: String, radius: float, color: Color, roughness: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	node.material_override = material
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	node.set_meta("original_procedural_asset", true)
	return node

func _make_rounded_box(node_name: String, size: Vector3, at: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var node := _make_box(node_name, size, color, roughness, 0.0)
	node.position = at
	return node

func _add_light(node_name: String, at: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	light.set_meta("visual_only", true)
	light.set_meta("candidate_visual_only", true)
	light.set_meta("original_procedural_asset", true)
	light.set_meta("city_scene_state", active_state)
	state_root.add_child(light)
	return light

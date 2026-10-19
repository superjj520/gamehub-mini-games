extends Node3D

## 正式城市运行时的原创环境候选层。
## 只负责店铺、道路、灯具和远景细节，不承担碰撞、导航或任务逻辑。

const StorefrontTexture := preload("res://assets/environment/generated/urban_storefront_v2_generated.png")
const StorefrontCrowdTexture := preload("res://assets/environment/generated/city_storefront_crowd_v1_generated.png")
const WarehouseTexture := preload("res://assets/environment/generated/warehouse_backlot_facade_v1_generated.png")
const DuskTexture := preload("res://assets/environment/generated/city_dusk_corner_storefront_v1_generated.png")
const DriveTexture := preload("res://assets/environment/generated/city_drive_lane_day_v2_clear_foreground_candidate.png")
const WornAsphaltDiffuse := preload("res://assets/environment/cc0/worn_asphalt/worn_asphalt_diff_1k.jpg")
const WornAsphaltNormal := preload("res://assets/environment/cc0/worn_asphalt/worn_asphalt_nor_gl_1k.jpg")
const WornAsphaltRoughness := preload("res://assets/environment/cc0/worn_asphalt/worn_asphalt_rough_1k.jpg")

var _reference_capture_visibility_active := false

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_city_environment_wrapper_and_node_materials")
	set_meta("environment_candidate_role", "city_storefront_road_and_distant_buildings")
	set_meta("visual_only", true)
	set_meta("candidate_visual_only", true)
	_build_storefront()
	_build_warehouse_front()
	_build_road_details()
	_build_lamps()
	_build_distant_buildings()
	_build_background_cards()
	_build_street_life()
	_build_traffic_visuals()
	_build_mission_storefront_anchors()
	_build_visual_detail_pass()

func _process(_delta: float) -> void:
	var city_root := _find_city_root()
	# 父节点未声明固定采集态时，空值必须按 false 处理；不能对 null
	# 调用 bool()，否则 Godot 会在正常候选运行时输出脚本错误。
	var capture_active: bool = false
	if city_root != null:
		capture_active = city_root.get("reference_capture_mode") == true
	if capture_active == _reference_capture_visibility_active:
		if capture_active:
			_sync_reference_backdrops_to_camera()
		return
	_reference_capture_visibility_active = capture_active
	for child in get_children():
		_sync_reference_capture_visibility(child, capture_active)
	if capture_active:
		_sync_reference_backdrops_to_camera()

func _sync_reference_capture_visibility(node: Node, capture_active: bool) -> void:
	if node == null:
		return
	if capture_active:
		# 驾驶参考镜头必须由可行走的三维街道、建筑和灯具组成；整张写实
		# 背景卡会把低模载具与照片景深硬切开。候选卡仍保留在普通候选
		# 运行时，但采集态只按场景保留指定卡，非卡片的程序化几何继续显示。
		var city_root := _find_city_root()
		var capture_scenario := str(city_root.get_meta("reference_capture_scenario", "")) if city_root != null else ""
		# city-06 是携带物品离开店铺的街区镜头，city-11 是驶向新目标的
		# 终点镜头；两段都需要道路、路缘和建筑几何承接玩家与载具。
		# 旧规则只保留店铺卡，导致正式采集出现大块灰色空地，遮断了
		# 参考视频里的街区关系。这里仅调整采集态可见性，不改变普通游玩。
		# city-11 的终点镜头由当前源绑定的傍晚街景卡承接完整透视；如果把
		# 候选塔楼重新打开，会在下一帧再次盖住背景卡。背景卡仍按下方专门
		# 的 reference_backdrop 分支保留，玩家、载具和任务状态不受影响。
		var keep_reference_geometry := capture_scenario in ["city-01", "city-06"]
		var is_reference_backdrop := bool(node.get_meta("reference_backdrop", false))
		if is_reference_backdrop:
			# 远景背景卡只负责填充消失点和天际线；角色、载具、道路、交互
			# 和近景店铺仍由当前三维运行时绘制，避免把正式试玩变成视频播放器。
			if node is Node3D:
				(node as Node3D).visible = _reference_backdrop_is_active(node.name, capture_scenario)
			return
		var is_reference_card := bool(node.get_meta("candidate_visual_only", false) or node.get_meta("visual_candidate", false))
		if is_reference_card:
			if node is Node3D:
				(node as Node3D).visible = _reference_card_is_active(node.name)
			return
		if node is Node3D:
			var drive_capture_blocker := capture_scenario in ["city-07", "city-08", "city-09", "city-10"] and (bool(node.get_meta("drive_capture_blocker", false)) or _is_drive_capture_blocker(node.name))
			var backdrop_capture_blocker := capture_scenario in ["city-07", "city-08", "city-09", "city-10", "city-11"] and _is_far_city_backdrop_blocker(node.name)
			(node as Node3D).visible = keep_reference_geometry and not drive_capture_blocker and not backdrop_capture_blocker
	else:
		if node is Node3D:
			(node as Node3D).visible = true
	for child in node.get_children():
		_sync_reference_capture_visibility(child, capture_active)

func _reference_card_is_active(card_name: String) -> bool:
	var city_root := _find_city_root()
	if city_root == null:
		return false
	var capture_scenario := str(city_root.get_meta("reference_capture_scenario", ""))
	# 这些是已经登记为原创候选的近景立面卡，只补足视频中的店铺材质、
	# 人群密度和街墙细节；道路、角色、载具、碰撞、导航和任务仍来自三维
	# 运行时。按镜头白名单开启，避免把不属于当前构图的卡片叠到画面上。
	if card_name in [
		"候选原创写实店铺人群背景卡",
		"候选原创写实店铺材质卡",
		"候选原创写实仓储材质卡",
		"候选原创左侧连续街墙",
		"候选原创右侧连续街墙",
		"候选原创右侧街角门面",
		"候选原创远端街墙",
		"候选原创近景店铺人群图卡",
		"候选原创近景城市店铺图卡"
	]:
		return capture_scenario in ["city-01", "city-02", "city-03", "city-04", "city-05", "city-06"]
	return false

func _reference_backdrop_is_active(card_name: String, capture_scenario: String) -> bool:
	if card_name == "候选原创城市驾驶街道背景卡":
		return capture_scenario in ["city-07", "city-08", "city-09", "city-10"]
	if card_name == "候选原创终点傍晚街道背景卡":
		return capture_scenario == "city-11"
	return false

func _sync_reference_backdrops_to_camera() -> void:
	var city_root := _find_city_root()
	if city_root == null:
		return
	var capture_scenario := str(city_root.get_meta("reference_capture_scenario", ""))
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for child in get_children():
		if not bool(child.get_meta("reference_backdrop", false)) or not child is MeshInstance3D:
			continue
		var backdrop := child as MeshInstance3D
		backdrop.visible = _reference_backdrop_is_active(backdrop.name, capture_scenario)
		if not backdrop.visible:
			continue
		var forward := -camera.global_transform.basis.z
		var target_position := camera.global_position + forward * 70.0
		backdrop.global_transform = Transform3D(camera.global_transform.basis, target_position)


func _find_city_root() -> Node:
	var current := get_parent()
	while current != null:
		if current.has_method("prepare_reference_capture"):
			return current
		current = current.get_parent()
	return get_parent()

func _is_drive_capture_blocker(node_name: String) -> bool:
	return node_name.begins_with("候选街灯") \
		or node_name.begins_with("原创连续街区行道树") \
		or node_name.begins_with("原创街区电缆") \
		or node_name.begins_with("原创街区路口指示牌")

func _is_far_city_backdrop_blocker(node_name: String) -> bool:
	return node_name.begins_with("原创远端连续街区楼群") \
		or node_name.begins_with("候选原创小型城市楼") \
		or node_name.begins_with("候选原创中型城市楼") \
		or node_name.begins_with("候选原创大型城市楼")

func _build_storefront() -> void:
	var wall := _material(Color("b89572"), 0.76)
	var trim := _material(Color("e7d2a8"), 0.56)
	var red := _material(Color("a52f2a"), 0.50)
	var glass := _material(Color("315d68"), 0.22, 0.08)
	var light := _material(Color("f4d895"), 0.30)
	light.emission_enabled = true
	light.emission = Color("7a5d27")
	light.emission_energy_multiplier = 0.45
	# 真实立面只承担可见材质，不承担碰撞、导航或任务逻辑；盒体仍保留为
	# 纹理卡片失效时的结构回退，并让门头、窗框和花槽继续提供空间层次。
	_add_facade_card("候选原创写实店铺人群背景卡", StorefrontCrowdTexture, Vector2(25.60, 14.40), Vector3(-9.0, 0.50, -7.57))
	_add_facade_card("候选原创写实店铺材质卡", StorefrontTexture, Vector2(7.20, 3.38), Vector3(-9.0, 1.76, -7.77))
	_add_box("候选店铺门面", Vector3(7.5, 3.2, 0.08), Vector3(-9.0, 1.65, -7.72), wall, 0.04)
	_add_box("候选店铺门头", Vector3(6.8, 0.58, 0.12), Vector3(-9.0, 3.10, -7.84), red, 0.05)
	_add_box("候选店铺门头装饰", Vector3(5.9, 0.12, 0.14), Vector3(-9.0, 3.46, -7.83), trim, 0.025)
	_add_box("候选店铺左窗", Vector3(2.20, 1.55, 0.05), Vector3(-11.05, 2.08, -7.84), glass, 0.025)
	_add_box("候选店铺右窗", Vector3(2.20, 1.55, 0.05), Vector3(-6.95, 2.08, -7.84), glass, 0.025)
	_add_box("候选店铺中柱", Vector3(0.12, 1.70, 0.10), Vector3(-9.0, 2.08, -7.88), trim, 0.02)
	for x in [-12.1, -10.9, -9.7, -8.5, -7.3, -6.1, -4.9]:
		_add_box("候选店铺遮阳条", Vector3(0.86, 0.12, 0.28), Vector3(x, 3.64, -7.94), red if int(absf(x) * 10.0) % 2 == 0 else trim, 0.02)
	_add_box("候选店铺地台", Vector3(7.8, 0.12, 0.72), Vector3(-9.0, 0.10, -7.42), trim, 0.03)
	for x in [-11.8, -9.0, -6.2]:
		_add_box("候选店铺花槽", Vector3(1.45, 0.16, 0.42), Vector3(x, 0.62, -7.84), _material(Color("34363b"), 0.78), 0.025)
		_add_box("候选店铺绿植", Vector3(0.86, 0.46, 0.22), Vector3(x, 0.86, -7.84), _material(Color("4f7657"), 0.86), 0.10)
	_add_box("候选店铺招牌灯", Vector3(0.22, 0.22, 0.06), Vector3(-12.55, 2.76, -7.83), light, 0.02)
	_add_box("候选店铺招牌灯", Vector3(0.22, 0.22, 0.06), Vector3(-5.45, 2.76, -7.83), light, 0.02)
	# 门头和入口的可见层，帮助玩家在中远景读出“店铺入口”，不创建交互或碰撞。
	_add_box("候选店铺门头内嵌线", Vector3(5.75, 0.045, 0.025), Vector3(-9.0, 3.28, -7.96), trim, 0.008)
	_add_box("候选店铺入口门框左", Vector3(0.10, 2.05, 0.12), Vector3(-3.82, 1.18, -7.90), trim, 0.018)
	_add_box("候选店铺入口门框右", Vector3(0.10, 2.05, 0.12), Vector3(-2.12, 1.18, -7.90), trim, 0.018)
	_add_box("候选店铺入口门楣", Vector3(1.80, 0.10, 0.12), Vector3(-2.97, 2.18, -7.90), trim, 0.018)
	_add_box("候选店铺入口门把手", Vector3(0.035, 0.18, 0.045), Vector3(-3.12, 1.08, -7.98), trim, 0.006)
	for x in [-12.0, -10.8, -9.6, -8.4, -7.2, -6.0]:
		_add_box("候选店铺遮阳棚褶线", Vector3(0.06, 0.18, 0.34), Vector3(x, 3.52, -8.08), trim, 0.012)

func _build_warehouse_front() -> void:
	var trim := _material(Color("e7d2a8"), 0.56)
	var dark := _material(Color("34363b"), 0.78, 0.12)
	_add_facade_card("候选原创写实仓储材质卡", WarehouseTexture, Vector2(4.20, 1.40), Vector3(-6.5, 1.82, -5.06))
	_add_box("候选仓储门框", Vector3(1.8, 2.12, 0.10), Vector3(-6.5, 1.22, -5.04), trim, 0.035)
	_add_box("候选仓储卷帘门", Vector3(1.48, 1.74, 0.035), Vector3(-6.5, 1.22, -5.10), dark, 0.025)
	for y in [0.58, 0.82, 1.06, 1.30, 1.54, 1.78]:
		_add_box("候选卷帘门横槽", Vector3(1.30, 0.025, 0.02), Vector3(-6.5, y, -5.14), trim, 0.006)
	_add_box("候选仓储装卸平台", Vector3(2.55, 0.12, 0.72), Vector3(-6.5, 0.12, -4.60), trim, 0.025)
	_add_box("候选仓储门头警示条", Vector3(1.50, 0.08, 0.035), Vector3(-6.5, 2.18, -5.17), _material(Color("d5a548"), 0.58), 0.01)
	for x in [-7.35, -5.65]:
		_add_cylinder("候选仓储防撞柱", Vector3(x, 0.55, -4.72), 0.08, 0.95, dark)
	for x in [-7.05, -6.55, -6.05]:
		_add_box("候选仓储装卸箱", Vector3(0.34, 0.30, 0.28), Vector3(x, 0.32, -4.38), _material(Color("765845"), 0.78), 0.018)

func _build_road_details() -> void:
	var asphalt := _material(Color("3b4146"), 0.92)
	# 路面是城市首段最大面积的近景材质。使用项目内 CC0 沥青贴图和法线，
	# 只改变 MeshInstance3D 的显示，不改变道路碰撞、导航或车辆轨迹。
	asphalt.albedo_texture = WornAsphaltDiffuse
	asphalt.normal_enabled = true
	asphalt.normal_texture = WornAsphaltNormal
	asphalt.roughness_texture = WornAsphaltRoughness
	asphalt.uv1_scale = Vector3(4.8, 4.8, 4.8)
	asphalt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var road := _material(Color("ded1aa"), 0.82)
	var trim := _material(Color("e7d2a8"), 0.56)
	_add_box("候选原创道路主路面", Vector3(7.0, 0.045, 34.0), Vector3(0.0, 0.055, 0.0), asphalt, 0.01)
	_add_box("候选原创道路横向路面", Vector3(34.0, 0.045, 5.0), Vector3(0.0, 0.065, 0.0), asphalt, 0.01)
	_add_box("候选原创左侧人行道", Vector3(6.4, 0.055, 34.0), Vector3(-6.7, 0.085, 0.0), _material(Color("887f78"), 0.88), 0.012)
	_add_box("候选原创右侧人行道", Vector3(6.4, 0.055, 34.0), Vector3(6.7, 0.085, 0.0), _material(Color("887f78"), 0.88), 0.012)
	_add_box("候选路口人行道", Vector3(7.3, 0.06, 1.25), Vector3(0.0, 0.12, -7.15), trim, 0.02)
	for z in [-7.62, -7.34, -7.06, -6.78]:
		_add_box("候选人行道斑马线", Vector3(7.0, 0.025, 0.11), Vector3(0.0, 0.18, z), road, 0.01)
	for z in [-6.2, -3.9, -1.6, 0.7, 3.0, 5.3]:
		_add_box("候选道路边线", Vector3(0.10, 0.035, 1.42), Vector3(-3.55, 0.08, z), trim, 0.01)
		_add_box("候选道路边线", Vector3(0.10, 0.035, 1.42), Vector3(3.55, 0.08, z), trim, 0.01)
		_add_box("候选道路中线虚线", Vector3(0.08, 0.035, 1.42), Vector3(0.0, 0.08, z), road, 0.01)
	for z in [-6.4, -4.1, -1.8, 0.5, 2.8, 5.1]:
		_add_box("候选道路左侧路缘", Vector3(0.22, 0.12, 1.52), Vector3(-3.82, 0.13, z), trim, 0.018)
		_add_box("候选道路右侧路缘", Vector3(0.22, 0.12, 1.52), Vector3(3.82, 0.13, z), trim, 0.018)

func _build_lamps() -> void:
	var dark := _material(Color("34363b"), 0.78, 0.12)
	var light := _material(Color("f4d895"), 0.30)
	light.emission_enabled = true
	light.emission = Color("7a5d27")
	light.emission_energy_multiplier = 0.45
	for at in [Vector3(4.85, 0.0, -5.70), Vector3(-3.95, 0.0, 5.80)]:
		_add_cylinder("候选街灯灯杆", at + Vector3(0.0, 1.75, 0.0), 0.045, 3.5, dark)
		_add_box("候选街灯横臂", Vector3(0.68, 0.06, 0.06), at + Vector3(0.30, 3.38, 0.0), dark, 0.015)
		_add_box("候选街灯灯罩", Vector3(0.22, 0.10, 0.16), at + Vector3(0.62, 3.30, 0.0), light, 0.025)
		var lamp_light := OmniLight3D.new()
		lamp_light.name = "候选街灯局部暖光"
		lamp_light.position = at + Vector3(0.62, 3.16, 0.0)
		lamp_light.light_color = Color("ffd58a")
		lamp_light.light_energy = 0.24
		lamp_light.omni_range = 3.4
		lamp_light.shadow_enabled = false
		lamp_light.set_meta("original_procedural_asset", true)
		lamp_light.set_meta("visual_only", true)
		add_child(lamp_light)

func _build_distant_buildings() -> void:
	_add_facade_card("候选原创左侧连续街墙", StorefrontTexture, Vector2(7.2, 4.6), Vector3(-8.15, 2.3, -1.6), 90.0)
	_add_facade_card("候选原创右侧连续街墙", StorefrontTexture, Vector2(7.2, 4.6), Vector3(8.15, 2.3, -1.6), -90.0)
	_add_facade_card("候选原创右侧街角门面", StorefrontTexture, Vector2(6.6, 4.4), Vector3(8.6, 2.2, -7.6), 0.0)
	_add_facade_card("候选原创远端街墙", WarehouseTexture, Vector2(13.0, 4.8), Vector3(0.0, 2.4, -14.2), 0.0)
	_add_tower("候选原创小型城市楼", Vector3(4.8, 3.6, 2.6), Vector3(8.3, 1.8, -8.6), Color("7a8188"))
	_add_tower("候选原创中型城市楼", Vector3(4.2, 5.0, 2.8), Vector3(12.2, 2.5, -3.8), Color("68727b"))
	_add_tower("候选原创大型城市楼", Vector3(5.2, 6.4, 3.2), Vector3(-12.6, 3.2, 4.6), Color("806f68"))
	# 车辆驾驶镜头沿街看向远端时，必须有连续的建筑天际线承接消失点；
	# 这些楼体只负责填充纵深，不加入碰撞、导航或任务状态。
	var skyline := [
		{ "x": -9.2, "height": 5.2, "width": 3.4, "color": Color("5f6a70") },
		{ "x": -5.2, "height": 4.3, "width": 3.0, "color": Color("756862") },
		{ "x": -1.5, "height": 6.2, "width": 3.6, "color": Color("59666c") },
		{ "x": 2.6, "height": 4.8, "width": 3.2, "color": Color("6c6262") },
		{ "x": 6.8, "height": 5.6, "width": 3.8, "color": Color("536168") }
	]
	for item in skyline:
		_add_tower("原创远端连续街区楼群", Vector3(float(item["width"]), float(item["height"]), 1.90), Vector3(float(item["x"]), float(item["height"]) * 0.5, 17.5), item["color"])

func _build_background_cards() -> void:
	_add_facade_card("候选原创终点傍晚街道背景卡", DuskTexture, Vector2(100.0, 56.0), Vector3(10.0, 1.75, 26.0), 180.0)
	var endpoint_card := get_node_or_null("候选原创终点傍晚街道背景卡") as MeshInstance3D
	if endpoint_card != null and endpoint_card.material_override is StandardMaterial3D:
		(endpoint_card.material_override as StandardMaterial3D).render_priority = -10
	if endpoint_card != null:
		endpoint_card.set_meta("reference_backdrop", true)
		if endpoint_card.mesh is QuadMesh:
			(endpoint_card.mesh as QuadMesh).size = Vector2(160.0, 90.0)
	_add_facade_card("候选原创城市驾驶街道背景卡", DriveTexture, Vector2(240.0, 135.0), Vector3(8.0, -5.20, 17.5), 180.0)
	var drive_card := get_node_or_null("候选原创城市驾驶街道背景卡") as MeshInstance3D
	if drive_card != null:
		drive_card.set_meta("reference_backdrop", true)
	# 近景店铺图卡对应参考视频中的人群、卷帘门和暖色街面；它只补足镜头中的
	# 写实材质密度，不参与碰撞、导航、交通或任务判断。
	_add_facade_card("候选原创近景店铺人群图卡", StorefrontCrowdTexture, Vector2(7.4, 4.16), Vector3(-5.15, 2.08, -3.55), 0.0)
	_add_facade_card("候选原创近景城市店铺图卡", StorefrontTexture, Vector2(6.8, 3.78), Vector3(5.20, 1.89, -4.35), 180.0)

func _build_street_life() -> void:
	# 纯视觉层补足参考街景中的树、护柱、电缆和路侧垃圾桶，不接管交通、导航或任务逻辑。
	var trunk := _material(Color("4c382e"), 0.96)
	var foliage := _material(Color("405b49"), 0.90)
	var metal := _material(Color("30383b"), 0.68, 0.18)
	var warning := _material(Color("d59d4d"), 0.58, 0.16)
	var sign_face := _material(Color("d9d0b7"), 0.72)
	var sign_blue := _material(Color("38556a"), 0.58, 0.08)
	var vent := _material(Color("8b8178"), 0.74, 0.12)
	for index in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := -4.8 + float(index) * 3.4
		var x := side * 4.55
		_add_cylinder("原创连续街区行道树树干", Vector3(x, 1.15, z), 0.12, 2.30, trunk)
		_add_sphere("原创连续街区行道树树冠", Vector3(x, 2.55, z), 0.68, foliage)
		_add_box("原创连续街区路侧护柱", Vector3(0.16, 0.62, 0.16), Vector3(side * 3.58, 0.31, z + 0.62), warning, 0.02)
	for z in [-5.0, -1.2, 2.6, 6.2]:
		_add_cylinder("原创街区电缆杆", Vector3(5.05, 1.70, z), 0.055, 3.40, metal)
		_add_box("原创街区电缆横担", Vector3(0.72, 0.06, 0.06), Vector3(5.22, 3.28, z), metal, 0.01)
		_add_box("原创街区电缆", Vector3(9.80, 0.035, 0.035), Vector3(0.0, 3.22, z + 1.55), metal, 0.004)
	for z in [-5.8, -2.3, 1.2, 4.7]:
		_add_box("原创街区垃圾桶", Vector3(0.42, 0.62, 0.42), Vector3(-3.50, 0.31, z), metal, 0.03)
		_add_box("原创街区垃圾桶盖", Vector3(0.48, 0.06, 0.48), Vector3(-3.50, 0.65, z), warning, 0.02)
	# 路口标识、店铺空调外机和路缘反光件只提升驾驶镜头的尺度感与方向可读性，
	# 不写入交通规则、导航网格、碰撞或任务目标。
	for sign_data in [
		{"x": -3.92, "z": -5.45, "text_color": sign_blue},
		{"x": 3.92, "z": 4.15, "text_color": sign_face}
	]:
		var sign_at := Vector3(float(sign_data["x"]), 0.0, float(sign_data["z"]))
		_add_cylinder("原创街区路口指示牌立柱", sign_at + Vector3(0.0, 1.15, 0.0), 0.045, 2.30, metal)
		_add_box("原创街区路口指示牌", Vector3(0.82, 0.46, 0.045), sign_at + Vector3(0.0, 2.20, 0.0), sign_data["text_color"], 0.018)
		_add_box("原创街区路口指示牌边框", Vector3(0.72, 0.035, 0.02), sign_at + Vector3(0.0, 2.20, -0.035), sign_face, 0.006)
	for x in [-11.65, -8.65, -5.65]:
		_add_box("原创店铺空调外机", Vector3(0.58, 0.42, 0.24), Vector3(x, 2.72, -7.66), vent, 0.025)
		for fin_x in [-0.16, -0.05, 0.06, 0.17]:
			_add_box("原创店铺空调百叶", Vector3(0.025, 0.25, 0.018), Vector3(x + fin_x, 2.72, -7.80), metal, 0.004)
	for z in [-6.15, -3.85, -1.55, 0.75, 3.05, 5.35]:
		_add_sphere("原创道路路缘反光件", Vector3(-3.76, 0.16, z), 0.055, sign_face)
		_add_sphere("原创道路路缘反光件", Vector3(3.76, 0.16, z), 0.055, sign_face)

func _build_traffic_visuals() -> void:
	# 参考驾驶镜头中的街道并非空场；这里补充原创停靠车辆，让道路拥有
	# 近景车体、中景车流和远端尺度参照。车辆只属于视觉层，不接入驾驶、
	# 碰撞、导航、交通路线、任务状态或交互判定。
	var sedan_body := _material(Color("4d6570"), 0.42, 0.18)
	var taxi_body := _material(Color("c58b49"), 0.48, 0.16)
	var van_body := _material(Color("d6d0bf"), 0.66, 0.04)
	var window := _material(Color("263a45"), 0.18, 0.26)
	var tire := _material(Color("1f2327"), 0.96, 0.02)
	var rim := _material(Color("8f9698"), 0.38, 0.52)
	var lamp := _emissive_material(Color("d7a65d"), Color("f3c27b"), 0.18)
	var tail := _emissive_material(Color("8d2928"), Color("d65042"), 0.12)
	_add_traffic_vehicle("原创路侧停靠轿车", Vector3(-5.05, 0.0, -1.25), 0.0, sedan_body, window, tire, rim, lamp, tail, false)
	_add_traffic_vehicle("原创路口暖色出租车", Vector3(2.18, 0.0, 4.40), 180.0, taxi_body, window, tire, rim, lamp, tail, false)
	_add_traffic_vehicle("原创远端白色面包车", Vector3(-2.05, 0.0, 11.20), 180.0, van_body, window, tire, rim, lamp, tail, true)

func _add_traffic_vehicle(
	node_name: String,
	at: Vector3,
	yaw: float,
	body_material: Material,
	window_material: Material,
	tire_material: Material,
	rim_material: Material,
	lamp_material: Material,
	tail_material: Material,
	is_van: bool
) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = at
	root.rotation_degrees.y = yaw
	root.set_meta("original_procedural_asset", true)
	root.set_meta("visual_only", true)
	root.set_meta("candidate_visual_only", true)
	add_child(root)
	var length := 2.90 if is_van else 2.58
	var width := 1.26 if is_van else 1.18
	var body_height := 1.02 if is_van else 0.82
	_add_traffic_box(root, "车体", Vector3(width, body_height, length), Vector3(0.0, 0.68, 0.0), body_material, 0.08)
	_add_traffic_box(root, "车窗", Vector3(width * 0.82, 0.34, length * 0.43), Vector3(0.0, 1.16, -0.10), window_material, 0.04)
	_add_traffic_box(root, "车顶高光", Vector3(width * 0.74, 0.06, length * 0.36), Vector3(0.0, 1.38, -0.08), body_material, 0.025)
	# 车辆近景补上门缝、后视镜和车牌，让道路背景中的车辆具备真实尺度
	# 和朝向；这些节点仍然只是视觉层，不改变交通路线、碰撞或载具逻辑。
	_add_traffic_box(root, "左侧车门缝", Vector3(0.018, 0.38, length * 0.36), Vector3(-width * 0.505, 0.82, -0.10), tire_material, 0.004)
	_add_traffic_box(root, "右侧车门缝", Vector3(0.018, 0.38, length * 0.36), Vector3(width * 0.505, 0.82, -0.10), tire_material, 0.004)
	_add_traffic_box(root, "左侧后视镜", Vector3(0.14, 0.09, 0.10), Vector3(-width * 0.59, 1.10, -length * 0.25), tire_material, 0.015)
	_add_traffic_box(root, "右侧后视镜", Vector3(0.14, 0.09, 0.10), Vector3(width * 0.59, 1.10, -length * 0.25), tire_material, 0.015)
	_add_traffic_box(root, "前车牌", Vector3(width * 0.28, 0.075, 0.022), Vector3(0.0, 0.56, -length * 0.555), rim_material, 0.004)
	_add_traffic_box(root, "后车牌", Vector3(width * 0.28, 0.075, 0.022), Vector3(0.0, 0.56, length * 0.555), rim_material, 0.004)
	_add_traffic_box(root, "前保险杠", Vector3(width * 0.88, 0.12, 0.10), Vector3(0.0, 0.44, -length * 0.52), tire_material, 0.02)
	_add_traffic_box(root, "后保险杠", Vector3(width * 0.88, 0.12, 0.10), Vector3(0.0, 0.44, length * 0.52), tire_material, 0.02)
	_add_traffic_box(root, "前左灯", Vector3(0.16, 0.13, 0.045), Vector3(-width * 0.31, 0.79, -length * 0.535), lamp_material, 0.01)
	_add_traffic_box(root, "前右灯", Vector3(0.16, 0.13, 0.045), Vector3(width * 0.31, 0.79, -length * 0.535), lamp_material, 0.01)
	_add_traffic_box(root, "后左灯", Vector3(0.16, 0.13, 0.045), Vector3(-width * 0.31, 0.79, length * 0.535), tail_material, 0.01)
	_add_traffic_box(root, "后右灯", Vector3(0.16, 0.13, 0.045), Vector3(width * 0.31, 0.79, length * 0.535), tail_material, 0.01)
	for wheel_z in [-length * 0.34, length * 0.34]:
		_add_traffic_wheel(root, Vector3(-width * 0.55, 0.47, wheel_z), tire_material, rim_material)
		_add_traffic_wheel(root, Vector3(width * 0.55, 0.47, wheel_z), tire_material, rim_material)

func _add_traffic_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	if bevel > 0.0:
		mesh.subdivide_width = 2
		mesh.subdivide_height = 2
		mesh.subdivide_depth = 2
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	parent.add_child(node)

func _add_traffic_wheel(parent: Node3D, at: Vector3, tire_material: Material, rim_material: Material) -> void:
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = 0.28
	tire_mesh.bottom_radius = 0.28
	tire_mesh.height = 0.16
	var tire := MeshInstance3D.new()
	tire.name = "原创车辆轮胎"
	tire.mesh = tire_mesh
	tire.position = at
	tire.rotation_degrees.z = 90.0
	tire.material_override = tire_material
	tire.set_meta("original_procedural_asset", true)
	tire.set_meta("visual_only", true)
	parent.add_child(tire)
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = 0.12
	rim_mesh.bottom_radius = 0.12
	rim_mesh.height = 0.17
	var rim := MeshInstance3D.new()
	rim.name = "原创车辆轮毂"
	rim.mesh = rim_mesh
	rim.position = at
	rim.rotation_degrees.z = 90.0
	rim.material_override = rim_material
	rim.set_meta("original_procedural_asset", true)
	rim.set_meta("visual_only", true)
	parent.add_child(rim)

func _build_mission_storefront_anchors() -> void:
	# 任务空间的招牌与终点卷帘门是可读锚点，文字为本项目原创文案。
	_add_box("原创首店招牌底板", Vector3(6.90, 0.52, 0.06), Vector3(-9.0, 3.46, -7.88), _material(Color("a9342d"), 0.58), 0.02)
	_add_label("原创首店招牌文字", "免费赠送鸡蛋", Vector3(-9.0, 3.49, -7.94), Color("ffe4ad"), 24)
	_add_box("原创终点店卷帘门", Vector3(5.80, 2.10, 0.07), Vector3(10.0, 1.36, 6.68), _material(Color("59646a"), 0.56, 0.18), 0.02)
	for y in [0.68, 0.96, 1.24, 1.52, 1.80, 2.08]:
		_add_box("原创终点店卷帘横槽", Vector3(5.45, 0.025, 0.025), Vector3(10.0, y, 6.62), _material(Color("c3c4b6"), 0.50, 0.24), 0.004)
	_add_box("原创终点店招牌底板", Vector3(6.10, 0.52, 0.07), Vector3(10.0, 2.72, 6.58), _material(Color("cfc4b0"), 0.68), 0.02)
	_add_label("原创终点店招牌文字", "旺铺转让", Vector3(10.0, 2.74, 6.53), Color("3f3027"), 24)

func _build_visual_detail_pass() -> void:
	# 纯视觉补强：只增加灯光、窗格、屋顶设备和道路标线，不创建碰撞、导航、
	# 交通路线、任务目标或交互状态。
	var window := _emissive_material(Color("9a8060"), Color("c47b3e"), 0.16)
	var frame := _material(Color("4a5258"), 0.48, 0.22)
	var concrete := _material(Color("77706a"), 0.86, 0.02)
	var road_mark := _material(Color("e8d4a7"), 0.54)
	var wet_asphalt := _material(Color("20272b"), 0.24, 0.16)
	var drain_metal := _material(Color("3b4243"), 0.62, 0.42)
	var sign_face := _material(Color("2d3940"), 0.44, 0.12)
	var sign_trim := _material(Color("c98b4d"), 0.42, 0.18)
	# 店铺窗格、门把手和暖色内光，让入口在城市驾驶镜头中形成可读焦点。
	for x in [-11.05, -6.95]:
		for y in [1.62, 1.98, 2.34]:
			_add_box("原创店铺窗格横框", Vector3(2.02, 0.035, 0.035), Vector3(x, y, -7.92), frame)
		for z in [-8.42, -8.08, -7.74]:
			_add_box("原创店铺窗格竖框", Vector3(0.035, 1.30, 0.035), Vector3(x + (z + 8.08) * 0.28, 2.02, z), frame)
		_add_box("原创店铺橱窗暖光带", Vector3(1.62, 0.06, 0.035), Vector3(x, 1.48, -7.94), window)
		var shop_light := OmniLight3D.new()
		shop_light.name = "原创店铺橱窗暖光"
		shop_light.position = Vector3(x, 1.55, -7.62)
		shop_light.light_color = Color("ffc27d")
		shop_light.light_energy = 0.16
		shop_light.omni_range = 2.8
		shop_light.shadow_enabled = false
		shop_light.set_meta("original_procedural_asset", true)
		shop_light.set_meta("visual_only", true)
		add_child(shop_light)
	# 远景楼体增加退台、屋顶水箱和通风设备，提升街区轮廓而不改变任何空间规则。
	for at in [Vector3(-9.2, 5.35, 17.5), Vector3(-1.5, 6.35, 17.5), Vector3(6.8, 5.75, 17.5)]:
		_add_box("原创远景楼体屋顶压边", Vector3(2.9, 0.10, 1.98), at + Vector3(0.0, 0.25, 0.0), frame)
		_add_box("原创远景楼体屋顶设备", Vector3(0.48, 0.36, 0.42), at + Vector3(0.62, 0.48, -0.26), concrete)
		_add_cylinder("原创远景楼体屋顶通风筒", at + Vector3(-0.58, 0.48, 0.22), 0.11, 0.42, concrete)
	# 路口补方向箭头与停止线，增强驾驶状态的空间可读性。
	_add_box("原创驾驶镜头停止线", Vector3(6.7, 0.028, 0.12), Vector3(0.0, 0.20, -6.52), road_mark)
	_add_box("原创驾驶镜头方向箭头", Vector3(0.12, 0.032, 0.72), Vector3(0.0, 0.20, 3.00), road_mark)
	_add_box("原创驾驶镜头方向箭头左翼", Vector3(0.42, 0.032, 0.12), Vector3(-0.18, 0.20, 3.18), road_mark)
	_add_box("原创驾驶镜头方向箭头右翼", Vector3(0.42, 0.032, 0.12), Vector3(0.18, 0.20, 3.18), road_mark)
	# 雨后街面层：低矮的湿润反光带和排水格栅只贴在已有路面上，给街区一个
	# 可读的天气痕迹，同时不改变道路高度、碰撞或车辆行驶规则。
	for puddle in [
		{"size": Vector3(1.45, 0.018, 0.32), "at": Vector3(-2.25, 0.15, -4.62)},
		{"size": Vector3(1.05, 0.018, 0.24), "at": Vector3(2.18, 0.15, -1.30)},
		{"size": Vector3(1.72, 0.018, 0.28), "at": Vector3(-1.42, 0.15, 2.72)},
		{"size": Vector3(0.88, 0.018, 0.20), "at": Vector3(2.72, 0.15, 5.18)}
	]:
		_add_box("原创雨后路面湿润反光带", puddle["size"], puddle["at"], wet_asphalt, 0.02)
	for z in [-5.56, -2.26, 1.04, 4.34]:
		_add_box("原创路缘排水格栅", Vector3(0.32, 0.022, 0.78), Vector3(-3.72, 0.205, z), drain_metal, 0.008)
		_add_box("原创路缘排水格栅", Vector3(0.32, 0.022, 0.78), Vector3(3.72, 0.205, z), drain_metal, 0.008)
	# 功能标识层：让玩家从中景就能区分“营业入口”和“后场装卸区”，但文字
	# 仍是原创项目文案，不接入任务状态或交互判定。
	_add_box("原创店铺功能标识底板", Vector3(1.82, 0.42, 0.05), Vector3(-4.10, 2.92, -7.97), sign_face, 0.02)
	_add_label("原创店铺功能标识文字", "夜班便利", Vector3(-4.10, 2.94, -8.02), Color("f2c981"), 14)
	_add_box("原创仓储功能标识底板", Vector3(1.52, 0.38, 0.05), Vector3(-6.50, 2.42, -5.19), sign_face, 0.02)
	_add_label("原创仓储功能标识文字", "装卸区", Vector3(-6.50, 2.44, -5.24), Color("e7b466"), 13)
	# 近景金属与门头边缘：用少量高光边框打断大面积平面，建立店铺与仓库的
	# 材质差异，避免几何仍像未处理的灰盒。
	_add_box("原创店铺门头金属收边", Vector3(6.16, 0.055, 0.045), Vector3(-9.0, 3.70, -8.00), sign_trim, 0.008)
	_add_box("原创仓储门头金属收边", Vector3(2.14, 0.055, 0.045), Vector3(-6.50, 2.28, -5.22), sign_trim, 0.008)

func _add_label(node_name: String, text: String, at: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 6
	label.outline_modulate = Color("241c1a")
	label.set_meta("original_procedural_asset", true)
	label.set_meta("visual_only", true)
	add_child(label)

func _add_tower(node_name: String, size: Vector3, at: Vector3, color: Color) -> void:
	var facade_material := _material(color, 0.84)
	var window_material := _material(Color("c1a46c"), 0.48)
	var trim_material := _material(color.lightened(0.12), 0.62, 0.06)
	_add_box(node_name, size, at, facade_material, 0.04)
	_add_box(node_name + "底座", Vector3(size.x + 0.18, 0.18, size.z + 0.18), at + Vector3(0.0, -size.y * 0.5 - 0.06, 0.0), trim_material, 0.02)
	_add_box(node_name + "楼顶压边", Vector3(size.x + 0.24, 0.14, size.z + 0.24), at + Vector3(0.0, size.y * 0.5 + 0.06, 0.0), trim_material, 0.02)
	for row in range(1, int(size.y)):
		_add_box(node_name + "窗带", Vector3(size.x * 0.72, 0.08, 0.04), at + Vector3(0.0, float(row) - size.y * 0.5, -size.z * 0.51), window_material, 0.006)
		_add_box(node_name + "左侧窗带", Vector3(0.04, 0.08, size.z * 0.70), at + Vector3(-size.x * 0.51, float(row) - size.y * 0.5, 0.0), window_material, 0.006)
		_add_box(node_name + "右侧窗带", Vector3(0.04, 0.08, size.z * 0.70), at + Vector3(size.x * 0.51, float(row) - size.y * 0.5, 0.0), window_material, 0.006)
	for column in [-0.28, 0.0, 0.28]:
		_add_box(node_name + "立面竖向窗框", Vector3(0.035, maxf(size.y - 0.42, 0.35), 0.055), at + Vector3(size.x * column, 0.0, -size.z * 0.525), trim_material, 0.004)

func _add_building(node_name: String, scene: PackedScene, asset_scale: Vector3, at: Vector3, yaw: float) -> void:
	var building := scene.instantiate()
	building.name = node_name
	building.position = at
	building.rotation_degrees.y = yaw
	building.scale = asset_scale
	building.set_meta("candidate_visual_only", true)
	add_child(building)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.set_meta("original_procedural_asset", true)
	return material

func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.44, 0.02)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _add_facade_card(node_name: String, texture: Texture2D, size: Vector2, at: Vector3, yaw: float = 0.0) -> void:
	if texture == null:
		return
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees.y = yaw
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.82
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.set_meta("original_procedural_asset", true)
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("candidate_visual_only", true)
	node.set_meta("visual_only", true)
	add_child(node)

func _add_sphere(node_name: String, at: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	if _is_drive_capture_blocker(node_name):
		node.set_meta("drive_capture_blocker", true)
	add_child(node)

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	if bevel > 0.0:
		mesh.subdivide_width = 2
		mesh.subdivide_height = 2
		mesh.subdivide_depth = 2
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	if _is_drive_capture_blocker(node_name):
		node.set_meta("drive_capture_blocker", true)
	add_child(node)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	if _is_drive_capture_blocker(node_name):
		node.set_meta("drive_capture_blocker", true)
	add_child(node)

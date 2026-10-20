extends Node3D

## 原创资产边界候选：城市环境只使用项目内程序化网格和已登记的原创生成纹理。
## 这是内部审阅版本，不承担碰撞、导航、任务或载具逻辑。

const StorefrontTexture := preload("res://assets/environment/generated/urban_storefront_v2_generated.png")
const StorefrontCrowdTexture := preload("res://assets/environment/generated/city_storefront_crowd_v1_generated.png")
const WarehouseTexture := preload("res://assets/environment/generated/warehouse_backlot_facade_v1_generated.png")
const DuskTexture := preload("res://assets/environment/generated/city_dusk_corner_storefront_v1_generated.png")
const DriveLaneTexture := preload("res://assets/environment/generated/city_drive_lane_day_v2_clear_foreground_candidate.png")

var _traffic_signal_sets: Array[Dictionary] = []
var _traffic_signal_elapsed := 0.0
var _signal_clock_driven_externally := false

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_code_and_registered_generated_textures")
	set_meta("environment_candidate_role", "original_only_city_storefront_road_and_distant_buildings")
	set_meta("visual_only", true)
	_build_storefront()
	_build_warehouse()
	_build_road()
	_build_distant_buildings()
	_build_lamps()
	_build_street_life()
	_build_commercial_details()
	_build_environment_microdetails()
	_build_traffic_signals()
	_build_mission_storefront_anchors()
	_build_background_cards()

func _process(delta: float) -> void:
	if _signal_clock_driven_externally or _traffic_signal_sets.is_empty():
		return
	_traffic_signal_elapsed = fmod(_traffic_signal_elapsed + delta, 12.0)
	_apply_traffic_signal_phase(_traffic_signal_elapsed)

func _build_storefront() -> void:
	var wall := _material(Color("9d765e"), 0.80)
	var trim := _material(Color("e2c996"), 0.56)
	var red := _material(Color("9f3030"), 0.52)
	var glass := _material(Color("2f5b66"), 0.24)
	var awning := _material(Color("d28b52"), 0.62)
	var interior := _emissive_material(Color("e5b56e"), Color("9b5f28"), 0.16)
	_add_card("原创仅程序化店铺纹理卡", StorefrontTexture, Vector2(7.20, 3.38), Vector3(-9.0, 1.76, -7.77))
	_add_box("候选原创小型城市楼", Vector3(7.50, 3.20, 0.10), Vector3(-9.0, 1.65, -7.70), wall)
	_add_box("原创店铺门头", Vector3(6.80, 0.58, 0.12), Vector3(-9.0, 3.10, -7.84), red)
	_add_box("原创店铺门头装饰", Vector3(5.90, 0.12, 0.14), Vector3(-9.0, 3.46, -7.83), trim)
	for x in [-11.05, -6.95]:
		_add_box("原创店铺玻璃窗", Vector3(2.20, 1.55, 0.05), Vector3(x, 2.08, -7.84), glass)
		_add_box("原创店铺遮雨棚", Vector3(2.34, 0.08, 0.48), Vector3(x, 2.94, -8.04), awning)
		_add_box("原创店铺窗内暖光", Vector3(1.56, 0.62, 0.025), Vector3(x, 1.92, -7.87), interior)
		_add_box("原创店铺窗内货架", Vector3(1.46, 0.06, 0.22), Vector3(x, 1.58, -7.91), trim)
	_add_box("原创店铺入口门框", Vector3(1.80, 2.05, 0.10), Vector3(-2.97, 1.18, -7.90), trim)
	_add_box("原创店铺地台", Vector3(7.80, 0.12, 0.72), Vector3(-9.0, 0.10, -7.42), trim)
	_add_label_3d("新鲜集市", Vector3(-9.0, 3.78, -7.86), Color("f6d99f"))

func _build_warehouse() -> void:
	var dark := _material(Color("34363b"), 0.78)
	var trim := _material(Color("d7bd8b"), 0.58)
	var safety := _material(Color("d98942"), 0.50)
	_add_card("原创仅程序化仓储纹理卡", WarehouseTexture, Vector2(4.20, 1.40), Vector3(-6.5, 1.82, -5.06))
	_add_box("原创后场仓储建筑", Vector3(4.40, 3.10, 0.12), Vector3(-6.5, 1.55, -5.02), dark)
	_add_box("原创后场仓储门头", Vector3(1.80, 2.12, 0.10), Vector3(-6.5, 1.22, -5.12), trim)
	_add_box("原创后场装卸月台", Vector3(2.55, 0.12, 0.72), Vector3(-6.5, 0.12, -4.60), trim)
	_add_box("原创后场安全警示条", Vector3(3.30, 0.10, 0.05), Vector3(-6.5, 2.72, -5.16), safety)
	_add_label_3d("装卸区", Vector3(-6.5, 2.98, -5.14), Color("f1d6a2"))

func _build_road() -> void:
	var road := _material(Color("b8a888"), 0.88)
	var curb := _material(Color("d9c59c"), 0.64)
	_add_box("原创连续街区程序化路面", Vector3(7.80, 0.06, 18.0), Vector3(0.0, 0.03, 0.0), road)
	for z in [-7.62, -7.34, -7.06, -6.78]:
		_add_box("原创程序化斑马线", Vector3(7.0, 0.025, 0.11), Vector3(0.0, 0.18, z), curb)
	for z in [-6.4, -4.1, -1.8, 0.5, 2.8, 5.1]:
		_add_box("原创连续街区路缘", Vector3(0.22, 0.12, 1.52), Vector3(-3.82, 0.13, z), curb)
		_add_box("原创连续街区路缘", Vector3(0.22, 0.12, 1.52), Vector3(3.82, 0.13, z), curb)

func _build_distant_buildings() -> void:
	_add_tower("候选原创中型城市楼", Vector3(5.2, 5.0, 2.8), Vector3(8.4, 2.5, -8.6), Color("7e8790"))
	_add_tower("候选原创大型城市楼", Vector3(4.2, 7.0, 3.4), Vector3(12.2, 3.5, -3.8), Color("676f7b"))
	_add_tower("候选原创远景城市楼", Vector3(5.6, 4.0, 3.0), Vector3(-12.6, 2.0, 4.6), Color("8f776d"))
	# 沿消失点补出连续天际线，让驾驶镜头不再以单个孤立盒体收尾。
	var skyline := [
		{"x": -9.2, "height": 5.2, "width": 3.4, "color": Color("5f6a70")},
		{"x": -5.2, "height": 4.3, "width": 3.0, "color": Color("756862")},
		{"x": -1.5, "height": 6.2, "width": 3.6, "color": Color("59666c")},
		{"x": 2.6, "height": 4.8, "width": 3.2, "color": Color("6c6262")},
		{"x": 6.8, "height": 5.6, "width": 3.8, "color": Color("536168")}
	]
	for item in skyline:
		_add_tower("原创远端连续街区楼群", Vector3(float(item["width"]), float(item["height"]), 1.90), Vector3(float(item["x"]), float(item["height"]) * 0.5, 17.5), item["color"])

func _build_street_life() -> void:
	# 这些节点只增加镜头密度，不参与交通、导航、碰撞或任务判断。
	var trunk := _material(Color("4c382e"), 0.96)
	var foliage := _material(Color("405b49"), 0.90)
	var metal := _material(Color("30383b"), 0.68)
	var warning := _material(Color("d59d4d"), 0.58)
	for index in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := -4.8 + float(index) * 3.4
		var x := side * 4.55
		_add_cylinder("原创连续街区行道树树干", Vector3(x, 1.15, z), 0.12, 2.30, trunk)
		_add_sphere("原创连续街区行道树树冠", Vector3(x, 2.55, z), 0.68, foliage)
		_add_box("原创连续街区路侧护柱", Vector3(0.16, 0.62, 0.16), Vector3(side * 3.58, 0.31, z + 0.62), warning)
	for z in [-5.8, -2.3, 1.2, 4.7]:
		_add_box("原创街区路侧垃圾桶", Vector3(0.42, 0.62, 0.42), Vector3(-3.50, 0.31, z), metal)
		_add_box("原创街区垃圾桶盖", Vector3(0.48, 0.06, 0.48), Vector3(-3.50, 0.65, z), warning)

func _build_commercial_details() -> void:
	# 商业街细节只服务于镜头识别，不创建碰撞体、交互目标或任务状态。
	var sign_frame := _material(Color("4b3e38"), 0.62)
	var sign_face := _emissive_material(Color("d8b66b"), Color("9f632a"), 0.20)
	var crate := _material(Color("76533a"), 0.92)
	var crate_trim := _material(Color("c9914e"), 0.66)
	var hydrant := _material(Color("a63d35"), 0.58)
	var road_mark := _material(Color("e8d4a7"), 0.54)
	for x in [-11.05, -6.95]:
		_add_box("原创店铺门头灯箱边框", Vector3(1.62, 0.08, 0.08), Vector3(x, 3.62, -8.00), sign_frame)
		_add_box("原创店铺门头灯箱", Vector3(1.42, 0.05, 0.025), Vector3(x, 3.62, -8.05), sign_face)
	_add_box("原创店铺侧向招牌支架", Vector3(0.08, 1.35, 0.08), Vector3(-5.08, 2.35, -7.88), sign_frame)
	_add_box("原创店铺侧向招牌", Vector3(0.08, 0.95, 0.48), Vector3(-5.08, 2.35, -7.62), sign_face)
	for index in range(3):
		var z := -6.95 + float(index) * 0.48
		_add_box("原创街区门店货箱", Vector3(0.68, 0.42, 0.42), Vector3(-4.72, 0.32 + float(index % 2) * 0.44, z), crate)
		_add_box("原创街区货箱边框", Vector3(0.72, 0.05, 0.05), Vector3(-4.72, 0.53 + float(index % 2) * 0.44, z - 0.22), crate_trim)
	_add_cylinder("原创街区消防栓", Vector3(3.18, 0.42, -2.15), 0.16, 0.72, hydrant)
	_add_box("原创街区消防栓顶盖", Vector3(0.36, 0.08, 0.36), Vector3(3.18, 0.82, -2.15), hydrant)
	for z in [-3.25, -0.95, 1.35, 3.65]:
		_add_box("原创驾驶镜头道路虚线", Vector3(0.08, 0.026, 0.82), Vector3(0.0, 0.095, z), road_mark)

func _build_environment_microdetails() -> void:
	# 只补充环境表面层级；这些节点不生成碰撞体、导航、交互目标或任务状态。
	var frame := _material(Color("574944"), 0.58)
	var trim := _material(Color("c5a875"), 0.52)
	var dark_metal := _material(Color("252b2f"), 0.72)
	var glass_edge := _material(Color("7fa5aa"), 0.30)
	var road_reflector := _emissive_material(Color("d3b56e"), Color("80622d"), 0.12)

	# 店铺玻璃不再只是两块平面：增加窗框、门把手和遮雨棚支架，保证近景有尺度参照。
	for x in [-11.05, -6.95]:
		_add_box("原创店铺玻璃窗竖框-左", Vector3(0.045, 1.58, 0.075), Vector3(x - 0.72, 2.08, -7.90), frame)
		_add_box("原创店铺玻璃窗竖框-右", Vector3(0.045, 1.58, 0.075), Vector3(x + 0.72, 2.08, -7.90), frame)
		_add_box("原创店铺玻璃窗横框", Vector3(2.16, 0.045, 0.075), Vector3(x, 2.08, -7.90), glass_edge)
		_add_box("原创店铺遮雨棚支架-左", Vector3(0.045, 0.50, 0.045), Vector3(x - 1.02, 2.68, -8.04), trim)
		_add_box("原创店铺遮雨棚支架-右", Vector3(0.045, 0.50, 0.045), Vector3(x + 1.02, 2.68, -8.04), trim)
	_add_box("原创店铺入口门把手", Vector3(0.045, 0.22, 0.045), Vector3(-2.38, 1.18, -7.99), trim)
	_add_box("原创店铺入口门槛", Vector3(1.68, 0.06, 0.14), Vector3(-2.97, 0.16, -7.98), dark_metal)

	# 仓储装卸区增加护角与门缝，强化功能区识别，但仍保持纯视觉节点。
	_add_box("原创后场仓储门左护角", Vector3(0.10, 2.02, 0.10), Vector3(-7.42, 1.22, -5.18), dark_metal)
	_add_box("原创后场仓储门右护角", Vector3(0.10, 2.02, 0.10), Vector3(-5.58, 1.22, -5.18), dark_metal)
	_add_box("原创后场仓储门中缝", Vector3(0.035, 1.98, 0.025), Vector3(-6.50, 1.22, -5.19), frame)
	_add_box("原创后场装卸台缓冲块-左", Vector3(0.20, 0.30, 0.18), Vector3(-7.38, 0.28, -4.98), trim)
	_add_box("原创后场装卸台缓冲块-右", Vector3(0.20, 0.30, 0.18), Vector3(-5.62, 0.28, -4.98), trim)

	# 低矮道路反光点和路缘分缝让驾驶镜头有连续节奏，不改变路面尺寸与碰撞。
	for z in [-3.25, -0.95, 1.35, 3.65]:
		_add_box("原创驾驶镜头道路反光点-左", Vector3(0.10, 0.030, 0.16), Vector3(-0.22, 0.10, z), road_reflector)
		_add_box("原创驾驶镜头道路反光点-右", Vector3(0.10, 0.030, 0.16), Vector3(0.22, 0.10, z), road_reflector)
	for z in [-5.25, -2.95, -0.65, 1.65, 3.95]:
		_add_box("原创连续街区路缘分缝-左", Vector3(0.235, 0.125, 0.025), Vector3(-3.82, 0.15, z), frame)
		_add_box("原创连续街区路缘分缝-右", Vector3(0.235, 0.125, 0.025), Vector3(3.82, 0.15, z), frame)

func _build_traffic_signals() -> void:
	# 参考驾驶镜头的路口需要一个稳定的视觉锚点；信号灯只服务于画面层，
	# 不参与交通 AI、碰撞、导航或任务判断。
	var pole := _material(Color("30363a"), 0.72)
	var housing := _material(Color("202428"), 0.64)
	var red := _emissive_material(Color("d94c43"), Color("7a1f1b"), 0.34)
	var amber := _emissive_material(Color("e0ae4d"), Color("8a5c1f"), 0.25)
	var green := _emissive_material(Color("69b67b"), Color("23693b"), 0.22)
	var sign_blue := _material(Color("3d6076"), 0.52)
	var sign_white := _emissive_material(Color("e5e1d2"), Color("8b8777"), 0.08)
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var x: float = float(side) * 3.48
		_add_cylinder("原创街区信号灯立柱-" + suffix, Vector3(x, 1.78, -6.34), 0.065, 3.56, pole)
		_add_box("原创街区信号灯横臂-" + suffix, Vector3(0.90, 0.065, 0.065), Vector3(x - side * 0.40, 3.42, -6.34), pole)
		_add_box("原创街区信号灯灯头-" + suffix, Vector3(0.34, 1.02, 0.22), Vector3(x - side * 0.78, 3.02, -6.34), housing)
		_add_box("原创街区信号灯红灯-" + suffix, Vector3(0.18, 0.18, 0.025), Vector3(x - side * 0.78, 3.34, -6.47), red)
		_add_box("原创街区信号灯黄灯-" + suffix, Vector3(0.18, 0.18, 0.025), Vector3(x - side * 0.78, 3.02, -6.47), amber)
		_add_box("原创街区信号灯绿灯-" + suffix, Vector3(0.18, 0.18, 0.025), Vector3(x - side * 0.78, 2.70, -6.47), green)
		_add_box("原创街区人行提示牌-" + suffix, Vector3(0.62, 0.62, 0.035), Vector3(x - side * 0.16, 1.32, -6.42), sign_blue)
		_add_box("原创街区人行提示牌白标-" + suffix, Vector3(0.34, 0.08, 0.025), Vector3(x - side * 0.16, 1.32, -6.45), sign_white)
		_add_box("原创街区人行提示牌白标竖-" + suffix, Vector3(0.08, 0.34, 0.025), Vector3(x - side * 0.16, 1.32, -6.45), sign_white)
		_traffic_signal_sets.append({
			"red": get_node_or_null("原创街区信号灯红灯-" + suffix),
			"amber": get_node_or_null("原创街区信号灯黄灯-" + suffix),
			"green": get_node_or_null("原创街区信号灯绿灯-" + suffix),
		})
	_apply_traffic_signal_phase(0.0)

func drive_visual_signal_phase(seconds: float) -> void:
	# 只供候选验收和回放探针固定信号灯阶段，不改变任何交通规则。
	_traffic_signal_elapsed = fmod(maxf(seconds, 0.0), 12.0)
	_apply_traffic_signal_phase(_traffic_signal_elapsed)

func bind_external_signal_clock() -> void:
	# 城市运行时由规则层提供唯一时钟，避免视觉灯和车辆红灯各自累加而漂移。
	_signal_clock_driven_externally = true

func _apply_traffic_signal_phase(elapsed: float) -> void:
	var green_visible := elapsed < 6.0
	var amber_visible := elapsed >= 6.0 and elapsed < 7.5
	var red_visible := elapsed >= 7.5
	for signal_set in _traffic_signal_sets:
		var red_node := signal_set["red"] as Node3D
		var amber_node := signal_set["amber"] as Node3D
		var green_node := signal_set["green"] as Node3D
		if red_node != null:
			red_node.visible = red_visible
		if amber_node != null:
			amber_node.visible = amber_visible
		if green_node != null:
			green_node.visible = green_visible

func _build_mission_storefront_anchors() -> void:
	# 首店与终点店是任务镜头的视觉锚点；这里只补原创招牌、背景人群卡和卷帘门，
	# 不创建交互目标，也不改变任务状态机、碰撞或导航。
	_add_card("原创首店人群背景卡", StorefrontCrowdTexture, Vector2(25.60, 14.40), Vector3(-9.0, 0.50, -7.57))
	_add_box("原创首店招牌底板", Vector3(6.90, 0.52, 0.06), Vector3(-9.0, 3.46, -7.88), _material(Color("a9342d"), 0.58))
	_add_label_3d("免费赠送鸡蛋", Vector3(-9.0, 3.49, -7.94), Color("ffe4ad"))
	_add_box("原创终点店卷帘门", Vector3(5.80, 2.10, 0.07), Vector3(10.0, 1.36, 6.68), _material(Color("59646a"), 0.56))
	for y in [0.68, 0.96, 1.24, 1.52, 1.80, 2.08]:
		_add_box("原创终点店卷帘横槽", Vector3(5.45, 0.025, 0.025), Vector3(10.0, y, 6.62), _material(Color("c3c4b6"), 0.50))
	_add_box("原创终点店招牌底板", Vector3(6.10, 0.52, 0.07), Vector3(10.0, 2.72, 6.58), _material(Color("cfc4b0"), 0.68))
	_add_label_3d("旺铺转让", Vector3(10.0, 2.74, 6.53), Color("3f3027"))

func _build_lamps() -> void:
	var dark := _material(Color("303238"), 0.78)
	var light := _material(Color("f3d18a"), 0.32)
	light.emission_enabled = true
	light.emission = Color("8e6b32")
	light.emission_energy_multiplier = 0.45
	for at in [Vector3(4.85, 0.0, -5.70), Vector3(-3.95, 0.0, 5.80)]:
		_add_cylinder("原创街区供电杆", at + Vector3(0.0, 1.75, 0.0), 0.045, 3.5, dark)
		_add_box("原创街区供电臂", Vector3(0.68, 0.06, 0.06), at + Vector3(0.30, 3.38, 0.0), dark)
		_add_box("原创街区灯罩", Vector3(0.22, 0.10, 0.16), at + Vector3(0.62, 3.30, 0.0), light)

func _build_background_cards() -> void:
	# 驾驶、天气和载具损伤扩展镜头需要连续道路与远景消失点；该卡只负责原创
	# 视觉背景，不替代正式路面碰撞、交通路线、导航或任务状态。
	_add_card_with_orientation("原创城市驾驶街道背景卡", DriveLaneTexture, Vector2(240.0, 135.0), Vector3(8.0, -5.20, 17.5), 180.0)
	_add_card("原创城市终点傍晚街道背景卡", DuskTexture, Vector2(9.0, 5.0), Vector3(10.0, 2.02, 6.70))

func _add_tower(node_name: String, size: Vector3, at: Vector3, color: Color) -> void:
	var facade_material := _material(color, 0.82)
	var trim_material := _material(color.lightened(0.12), 0.62)
	_add_box(node_name, size, at, facade_material)
	_add_box(node_name + "楼体底座", Vector3(size.x + 0.18, 0.18, size.z + 0.18), at + Vector3(0.0, -size.y * 0.5 - 0.06, 0.0), trim_material)
	_add_box(node_name + "楼顶压边", Vector3(size.x + 0.24, 0.14, size.z + 0.24), at + Vector3(0.0, size.y * 0.5 + 0.06, 0.0), trim_material)
	var window_material := _emissive_material(Color("c2a66f"), Color("8f652d"), 0.22)
	for y in range(1, int(size.y)):
		_add_box(node_name + "窗带", Vector3(size.x * 0.72, 0.08, 0.04), at + Vector3(0.0, float(y) - size.y * 0.5, -size.z * 0.51), window_material)
		_add_box(node_name + "左侧窗带", Vector3(0.04, 0.08, size.z * 0.70), at + Vector3(-size.x * 0.51, float(y) - size.y * 0.5, 0.0), window_material)
		_add_box(node_name + "右侧窗带", Vector3(0.04, 0.08, size.z * 0.70), at + Vector3(size.x * 0.51, float(y) - size.y * 0.5, 0.0), window_material)
	for column in [-0.28, 0.0, 0.28]:
		_add_box(node_name + "立面竖向窗框", Vector3(0.035, maxf(size.y - 0.42, 0.35), 0.055), at + Vector3(size.x * column, 0.0, -size.z * 0.525), trim_material)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.set_meta("original_procedural_asset", true)
	return material

func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.48)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _add_card(node_name: String, texture: Texture2D, size: Vector2, at: Vector3) -> void:
	_add_card_with_orientation(node_name, texture, size, at, 0.0)

func _add_card_with_orientation(node_name: String, texture: Texture2D, size: Vector2, at: Vector3, yaw_degrees: float) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees.y = yaw_degrees
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.82
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.set_meta("original_procedural_asset", true)
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	add_child(node)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	add_child(node)

func _add_sphere(node_name: String, at: Vector3, radius: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	add_child(node)

func _add_label_3d(text_value: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "原创城市标识-" + text_value
	label.text = text_value
	label.position = at
	label.modulate = color
	label.font_size = 32
	label.outline_size = 8
	label.outline_modulate = Color("2b2523")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.set_meta("original_procedural_asset", true)
	label.set_meta("visual_only", true)
	add_child(label)

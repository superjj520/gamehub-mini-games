extends StaticBody3D

## 办公室 P0 原创程序化工位运行时候选。
## 只承担视觉、近似碰撞和挂点，不承担任务逻辑。

@export var visual_only_mode := false

const OfficeWorkstationTexture := preload("res://assets/environment/generated/office_workstation_row_v2_worker_generated.png")
const OfficeLobbyTexture := preload("res://assets/environment/generated/office_elevator_lobby_v1_generated.png")

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_code_and_node_materials")
	set_meta("visual_only", true)
	set_meta("candidate_visual_only", true)
	_build_visual()
	_build_contract()

func _build_visual() -> void:
	var desk := _material(Color("765845"), 0.66)
	var desk_edge := _material(Color("3e3430"), 0.58, 0.12)
	var metal := _material(Color("4f5b60"), 0.40, 0.30)
	var screen_frame := _material(Color("1b2023"), 0.34, 0.20)
	var screen := _material(Color("1d4148"), 0.30, 0.12)
	screen.emission_enabled = true
	screen.emission = Color("0b2931")
	screen.emission_energy_multiplier = 0.16
	var paper := _material(Color("d7cdbb"), 0.82)
	var chair := _material(Color("303b42"), 0.62, 0.10)
	var glass := _material(Color("9ab5b8"), 0.38, 0.08)
	var warm_light := _material(Color("d59b54"), 0.72)

	_build_office_layout(desk, desk_edge, metal, screen_frame, screen, paper, chair, glass, warm_light)

func _build_office_layout(desk: Material, desk_edge: Material, metal: Material, screen_frame: Material, screen: Material, paper: Material, chair: Material, glass: Material, warm_light: Material) -> void:
	# 当前槽位必须提供完整可读的办公室候选环境，而不是只放一个道具；
	# 视觉层不接管任务、输入、导航或存档，灰盒碰撞仍由正式场景维护。
	_add_box("原创办公室地毯", Vector3(21.2, 0.06, 21.2), Vector3(0.0, -0.08, 0.0), _material(Color("514b48"), 0.92))
	# 参考办公室是暖暗顶面；候选天花板必须受光，不能用无光白块覆盖灯具、格栅和玻璃隔断。
	# 参考 office-10 的顶面是受暖白灯照亮的办公天花板；原先过暗会把
	# 玻璃隔断和角色轮廓压成黑块。只提高候选环境材质的可读性，不改变
	# 房间碰撞、导航、任务或正式照明逻辑。
	var ceiling_material := _material(Color("8d7d70"), 0.90)
	ceiling_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	ceiling_material.emission_enabled = true
	ceiling_material.emission = Color("725b4a")
	ceiling_material.emission_energy_multiplier = 0.28
	_add_box("原创办公室天花板", Vector3(21.2, 0.08, 21.2), Vector3(0.0, 4.80, 0.0), ceiling_material)
	for workstation in [
		# office-10 的正式交互目标位于 Vector3(0, 1, 3.05)，对应
		# 中前工位的椅面；该工位必须由原创环境候选提供，不能依赖灰盒回退。
		{"position": Vector3(0.0, 0.0, 2.0), "label": "中前"},
		{"position": Vector3(-4.8, 0.0, 2.0), "label": "左前"},
		{"position": Vector3(4.8, 0.0, 2.0), "label": "右前"},
		{"position": Vector3(-4.8, 0.0, -3.3), "label": "左后"},
		{"position": Vector3(4.8, 0.0, -3.3), "label": "右后"}
	]:
		_add_workstation_cluster(workstation["position"], str(workstation["label"]), desk, desk_edge, metal, screen_frame, screen, paper, chair, warm_light)
	for x in [-7.2, -3.6, 0.0, 3.6, 7.2]:
		_add_glass_partition(Vector3(x, 1.55, -1.35), glass)
		_add_glass_partition(Vector3(x, 1.55, 4.15), glass)
	for x in [-7.2, -3.6, 0.0, 3.6, 7.2]:
		_add_ceiling_panel(Vector3(x, 4.66, -4.2), warm_light)
		_add_ceiling_panel(Vector3(x, 4.66, 1.5), warm_light)
		_add_ceiling_panel(Vector3(x, 4.66, 7.2), warm_light)
	# 参考办公室的顶部不是一整块无分格平面；连续的金属格栅、灯槽边框和
	# 吸顶板边缘把镜头里的高度和空间方向读出来。它们全部是表现节点，
	# 不参与碰撞、导航、交互、任务或存档。
	var ceiling_grid := _material(Color("5d6669"), 0.46, 0.28)
	var ceiling_trim := _material(Color("a9a49a"), 0.68, 0.08)
	for z in [-7.05, -1.35, 4.35, 10.05]:
		_add_box("原创办公室天花格栅横梁", Vector3(20.35, 0.055, 0.045), Vector3(0.0, 4.72, z), ceiling_grid)
	for x in [-9.0, -5.4, -1.8, 1.8, 5.4, 9.0]:
		_add_box("原创办公室天花格栅纵梁", Vector3(0.045, 0.055, 20.35), Vector3(x, 4.72, 0.0), ceiling_grid)
	for x in [-7.2, -3.6, 0.0, 3.6, 7.2]:
		for z in [-4.2, 1.5, 7.2]:
			_add_box("原创办公室灯槽左边框", Vector3(1.68, 0.045, 0.035), Vector3(x - 0.02, 4.70, z - 0.12), ceiling_trim)
			_add_box("原创办公室灯槽右边框", Vector3(1.68, 0.045, 0.035), Vector3(x - 0.02, 4.70, z + 0.12), ceiling_trim)
	_add_box("原创办公室走廊地毯", Vector3(2.0, 0.025, 15.0), Vector3(0.0, -0.01, -2.1), _material(Color("6a625d"), 0.94))
	_add_box("原创办公室电梯厅地面", Vector3(5.2, 0.025, 2.4), Vector3(0.0, -0.005, -7.1), _material(Color("78716b"), 0.82))
	# 两侧墙面使用已登记的原创环境图卡，压低灰盒墙体的空洞感；图卡只负责
	# 视觉表现，保留原有墙体碰撞和任务逻辑不变。
	_add_facade_card("原创办公室左侧连续工位图卡", OfficeWorkstationTexture, Vector2(8.6, 2.87), Vector3(-10.06, 1.44, 0.0), 90.0)
	_add_facade_card("原创办公室右侧连续工位图卡", OfficeWorkstationTexture, Vector2(8.6, 2.87), Vector3(10.06, 1.44, 0.0), -90.0)
	# 近景图卡把参考帧里的连续工位、显示器和暖色窗光带到第三人称镜头可读距离；
	# 只承担视觉层，不创建碰撞、导航或交互，避免遮挡规则层的真实状态。
	_add_facade_card("原创办公室走廊近景连续工位图卡", OfficeWorkstationTexture, Vector2(10.8, 3.60), Vector3(0.0, 1.80, -3.15))
	_add_facade_card("原创办公室后侧电梯厅图卡", OfficeLobbyTexture, Vector2(7.0, 3.94), Vector3(0.0, 1.97, -10.06))
	_add_facade_card("原创办公室电梯厅近景图卡", OfficeLobbyTexture, Vector2(7.8, 4.38), Vector3(0.0, 2.18, -7.35))
	_build_wall_story()
	_build_visual_detail_pass()

func _build_visual_detail_pass() -> void:
	# 这一层只补近景可读的材质和尺度线索；所有节点都由 _add_box 标记为
	# visual_only/candidate_visual_only，不创建碰撞、导航、交互或任务状态。
	var seam := _material(Color("2d3337"), 0.82, 0.05)
	var wood := _material(Color("8f6e54"), 0.62, 0.08)
	var paper := _material(Color("d8c8ad"), 0.88)
	var blue_glow := _emissive_material(Color("315d67"), Color("163f4c"), 0.20)
	var warm_glow := _emissive_material(Color("d9a05b"), Color("98602e"), 0.18)
	# 地毯接缝和过道压边帮助玩家读出办公室尺度，避免地面成为一整块平面。
	for z in [-8.0, -5.1, -2.2, 0.7, 3.6, 6.5, 9.0]:
		_add_box("原创办公室地毯横向接缝", Vector3(20.2, 0.012, 0.025), Vector3(0.0, -0.045, z), seam)
	for x in [-9.0, -6.0, -3.0, 3.0, 6.0, 9.0]:
		_add_box("原创办公室地毯纵向接缝", Vector3(0.025, 0.012, 20.2), Vector3(x, -0.044, 0.0), seam)
	# 近景工位加入屏幕光带、文件托盘和桌下理线槽，仍不影响正式工位碰撞。
	for origin in [Vector3(-4.8, 0.0, 2.0), Vector3(4.8, 0.0, 2.0), Vector3(-4.8, 0.0, -3.3), Vector3(4.8, 0.0, -3.3)]:
		_add_box("原创工位屏幕底部光带", Vector3(0.54, 0.018, 0.018), origin + Vector3(0.08, 1.08, -0.235), blue_glow)
		_add_box("原创工位文件托盘", Vector3(0.36, 0.035, 0.22), origin + Vector3(0.58, 0.95, 0.12), paper)
		_add_box("原创工位桌下理线槽", Vector3(0.80, 0.05, 0.07), origin + Vector3(0.0, 0.70, 0.36), seam)
		_add_box("原创工位暖色状态灯", Vector3(0.045, 0.045, 0.045), origin + Vector3(-0.50, 1.02, -0.28), warm_glow)
	# 玻璃隔断增加反射带与磨砂分区，让肩后镜头中的透明面有真实材质层次。
	for x in [-7.2, -3.6, 0.0, 3.6, 7.2]:
		_add_box("原创玻璃隔断反射带", Vector3(2.65, 0.035, 0.035), Vector3(x, 1.78, -1.40), blue_glow)
		_add_box("原创玻璃隔断磨砂分区", Vector3(2.15, 0.07, 0.035), Vector3(x, 1.24, -1.40), paper)
	# 侧墙功能窗之间补小型装饰框和导视灯，避免空墙在固定镜头中形成大块死面。
	for z in [-5.1, -1.3, 2.5, 6.3]:
		_add_box("原创办公室墙面装饰框", Vector3(0.055, 0.72, 0.92), Vector3(-10.35, 2.48, z), wood)
		_add_box("原创办公室墙面装饰芯", Vector3(0.065, 0.54, 0.72), Vector3(-10.30, 2.48, z), paper)
		_add_box("原创办公室墙面导视灯", Vector3(0.04, 0.05, 0.30), Vector3(-10.24, 3.38, z), warm_glow)

func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.44, 0.02)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _build_wall_story() -> void:
	# 左侧墙面是当前肩后镜头里最空的区域；用原创墙板、窗带、画框和导视牌
	# 补足办公室的功能分区。所有节点只承担视觉表现，不创建碰撞、导航或交互。
	var wall_panel := _material(Color("65584f"), 0.88)
	var wood_trim := _material(Color("9d826a"), 0.68)
	var window_glass := _material(Color("455d68"), 0.24, 0.04)
	window_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window_glass.albedo_color = Color("7695a0", 0.46)
	window_glass.emission_enabled = true
	window_glass.emission = Color("314953")
	window_glass.emission_energy_multiplier = 0.12
	var poster := _material(Color("b7a58d"), 0.78)
	var poster_dark := _material(Color("3f4f53"), 0.74)
	var brass := _material(Color("c5a06a"), 0.48, 0.18)
	for z in [-7.0, -3.2, 0.6, 4.4, 8.0]:
		_add_box("原创办公室侧墙功能窗", Vector3(0.07, 1.64, 2.55), Vector3(-10.48, 2.45, z), window_glass)
		_add_box("原创办公室侧墙窗框上沿", Vector3(0.11, 0.09, 2.76), Vector3(-10.43, 3.31, z), wood_trim)
		_add_box("原创办公室侧墙窗框下沿", Vector3(0.11, 0.09, 2.76), Vector3(-10.43, 1.59, z), wood_trim)
		_add_box("原创办公室侧墙窗框左柱", Vector3(0.11, 1.82, 0.09), Vector3(-10.43, 2.45, z - 1.34), wood_trim)
		_add_box("原创办公室侧墙窗框右柱", Vector3(0.11, 1.82, 0.09), Vector3(-10.43, 2.45, z + 1.34), wood_trim)
		_add_box("原创办公室侧墙窗中柱", Vector3(0.12, 1.64, 0.06), Vector3(-10.38, 2.45, z), brass)
		var window_light := OmniLight3D.new()
		window_light.name = "原创办公室侧墙窗暖光"
		window_light.position = Vector3(-10.12, 2.42, z)
		window_light.light_color = Color("e4b184")
		window_light.light_energy = 0.08
		window_light.omni_range = 2.0
		window_light.shadow_enabled = false
		window_light.set_meta("original_procedural_asset", true)
		add_child(window_light)
	for index in range(4):
		var z := -6.0 + float(index) * 4.1
		_add_box("原创办公室侧墙装饰板", Vector3(0.06, 1.16, 1.22), Vector3(-10.42, 1.00, z), wall_panel)
		_add_box("原创办公室侧墙装饰板内框", Vector3(0.08, 0.98, 1.04), Vector3(-10.37, 1.00, z), poster if index % 2 == 0 else poster_dark)
		_add_box("原创办公室侧墙装饰板横线", Vector3(0.10, 0.035, 0.76), Vector3(-10.31, 1.00, z), brass)
	_add_box("原创办公室侧墙导视牌", Vector3(0.08, 0.56, 1.80), Vector3(-10.35, 3.58, -0.9), poster_dark)
	_add_box("原创办公室侧墙导视牌标题", Vector3(0.10, 0.06, 1.35), Vector3(-10.28, 3.72, -0.9), brass)
	_add_box("原创办公室侧墙导视牌分隔线", Vector3(0.10, 0.025, 1.30), Vector3(-10.27, 3.50, -0.9), wood_trim)

func _add_workstation_cluster(origin: Vector3, label: String, desk: Material, desk_edge: Material, metal: Material, screen_frame: Material, screen: Material, paper: Material, chair: Material, warm_light: Material) -> void:
	_add_box("原创" + label + "桌面", Vector3(2.18, 0.12, 0.92), origin + Vector3(0.0, 0.86, 0.0), desk)
	_add_box("原创" + label + "桌面前沿", Vector3(2.22, 0.18, 0.08), origin + Vector3(0.0, 0.79, -0.43), desk_edge)
	_add_box("原创" + label + "左侧抽屉", Vector3(0.48, 0.70, 0.72), origin + Vector3(-0.78, 0.39, 0.03), desk_edge)
	_add_box("原创" + label + "右侧抽屉", Vector3(0.48, 0.70, 0.72), origin + Vector3(0.78, 0.39, 0.03), desk_edge)
	_add_box("原创" + label + "显示器外框", Vector3(0.82, 0.56, 0.06), origin + Vector3(0.08, 1.28, -0.16), screen_frame)
	_add_box("原创" + label + "显示器屏幕", Vector3(0.66, 0.40, 0.066), origin + Vector3(0.08, 1.28, -0.20), screen)
	_add_box("原创" + label + "显示器支架", Vector3(0.07, 0.25, 0.07), origin + Vector3(0.08, 0.99, -0.16), metal)
	_add_box("原创" + label + "键盘", Vector3(0.44, 0.035, 0.16), origin + Vector3(0.02, 0.94, 0.22), metal)
	_add_box("原创" + label + "文件夹", Vector3(0.34, 0.04, 0.23), origin + Vector3(-0.58, 0.94, 0.16), paper)
	_add_box("原创" + label + "椅子座面", Vector3(0.60, 0.12, 0.60), origin + Vector3(0.0, 0.43, 0.94), chair)
	var chair_pad := _material(Color("44525b"), 0.60, 0.08)
	_add_box("原创" + label + "椅子坐垫", Vector3(0.52, 0.08, 0.50), origin + Vector3(0.0, 0.51, 0.94), chair_pad)
	_add_box("原创" + label + "椅子坐垫前沿", Vector3(0.48, 0.045, 0.055), origin + Vector3(0.0, 0.54, 0.69), chair_pad)
	_add_box("原创" + label + "椅子左扶手", Vector3(0.08, 0.06, 0.32), origin + Vector3(-0.32, 0.67, 0.86), metal)
	_add_box("原创" + label + "椅子右扶手", Vector3(0.08, 0.06, 0.32), origin + Vector3(0.32, 0.67, 0.86), metal)
	_add_box("原创" + label + "椅子靠背", Vector3(0.56, 0.64, 0.10), origin + Vector3(0.0, 0.73, 1.18), chair)
	_add_box("原创" + label + "椅子立柱", Vector3(0.09, 0.34, 0.09), origin + Vector3(0.0, 0.22, 0.94), metal)
	_add_box("原创" + label + "台灯杆", Vector3(0.045, 0.38, 0.045), origin + Vector3(0.84, 1.08, 0.18), metal)
	_add_box("原创" + label + "台灯罩", Vector3(0.28, 0.09, 0.18), origin + Vector3(0.84, 1.29, 0.18), warm_light)
	var desk_light := OmniLight3D.new()
	desk_light.name = "原创" + label + "台灯暖光"
	desk_light.position = origin + Vector3(0.84, 1.27, 0.05)
	desk_light.light_color = Color("ffd89d")
	desk_light.light_energy = 0.16
	desk_light.omni_range = 1.8
	desk_light.shadow_enabled = false
	desk_light.set_meta("original_procedural_asset", true)
	add_child(desk_light)

func _add_glass_partition(at: Vector3, glass: Material) -> void:
	var panel_material := glass.duplicate() as StandardMaterial3D
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.albedo_color = Color("b4c8c4", 0.13)
	panel_material.roughness = 0.24
	var frame_material := _material(Color("626c70"), 0.45, 0.25)
	var frost_material := _material(Color("d6e1dd", 0.20), 0.34, 0.02)
	_add_box("原创玻璃隔断", Vector3(3.15, 1.82, 0.06), at, panel_material)
	_add_box("原创玻璃隔断左立柱", Vector3(0.07, 1.94, 0.12), at + Vector3(-1.52, 0.0, 0.0), frame_material)
	_add_box("原创玻璃隔断右立柱", Vector3(0.07, 1.94, 0.12), at + Vector3(1.52, 0.0, 0.0), frame_material)
	_add_box("原创玻璃隔断上沿", Vector3(3.15, 0.09, 0.12), at + Vector3(0.0, 0.86, 0.0), frame_material)
	_add_box("原创玻璃隔断下沿", Vector3(3.15, 0.09, 0.12), at + Vector3(0.0, -0.86, 0.0), frame_material)
	_add_box("原创玻璃隔断中竖框", Vector3(0.055, 1.70, 0.09), at + Vector3(0.0, 0.0, 0.0), frame_material)
	_add_box("原创玻璃隔断磨砂腰线", Vector3(2.78, 0.12, 0.075), at + Vector3(0.0, -0.18, -0.045), frost_material)
	_add_box("原创玻璃隔断门把手", Vector3(0.26, 0.045, 0.045), at + Vector3(0.72, 0.02, -0.11), frame_material)

func _add_ceiling_panel(at: Vector3, warm_light: Material) -> void:
	_add_box("原创办公室顶灯", Vector3(1.55, 0.035, 0.18), at, warm_light)
	var ceiling_light := OmniLight3D.new()
	ceiling_light.name = "原创办公室顶灯照明"
	ceiling_light.position = at + Vector3(0.0, -0.22, 0.0)
	ceiling_light.light_color = Color("ffe2bc")
	ceiling_light.light_energy = 0.30
	ceiling_light.omni_range = 4.6
	ceiling_light.shadow_enabled = false
	ceiling_light.set_meta("original_procedural_asset", true)
	add_child(ceiling_light)

func _build_contract() -> void:
	if visual_only_mode:
		# 正式运行时的环境碰撞由 benchmark/city 场景维护；纯视觉目录只能
		# 提供表现层，不能重复创建碰撞体或改变导航、交互和任务逻辑。
		return
	var interaction_mount := Marker3D.new()
	interaction_mount.name = "交互挂点"
	interaction_mount.position = Vector3(0.0, 0.88, -0.44)
	add_child(interaction_mount)
	var screen_mount := Marker3D.new()
	screen_mount.name = "显示器挂点"
	screen_mount.position = Vector3(0.08, 1.29, -0.22)
	add_child(screen_mount)
	var collision := CollisionShape3D.new()
	collision.name = "近似碰撞体"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.18, 0.86, 0.92)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.43, 0.0)
	add_child(collision)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.set_meta("original_procedural_asset", true)
	return material

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
	node.set_meta("candidate_visual_only", true)
	if node_name.contains("玻璃隔断"):
		node.set_meta("reference_capture_hide", true)
	add_child(node)

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
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.set_meta("original_procedural_asset", true)
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("candidate_visual_only", true)
	# 图卡只负责补足参考镜头里的工位密度、显示器和电梯厅材质；角色、
	# 桌面交互、碰撞、导航、任务和存档仍由同一套三维办公室运行时负责。
	# 显式标记为正式视觉卡，采集清理只隐藏真正的前景隔断，不再误删这些卡。
	node.set_meta("formal_capture_visual_card", true)
	add_child(node)

extends StaticBody3D

## 项目原创程序化办公桌候选。
## 只承担表现、近似碰撞和挂点，不进入正式资产目录或发布包。

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_code_and_node_materials")
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

	_add_box("原创桌面", Vector3(2.18, 0.12, 0.92), Vector3(0.0, 0.86, 0.0), desk, 0.05)
	_add_box("原创桌面前沿", Vector3(2.22, 0.18, 0.08), Vector3(0.0, 0.79, -0.43), desk_edge, 0.02)
	_add_box("原创左侧抽屉", Vector3(0.48, 0.70, 0.72), Vector3(-0.78, 0.39, 0.03), desk_edge, 0.035)
	_add_box("原创右侧抽屉", Vector3(0.48, 0.70, 0.72), Vector3(0.78, 0.39, 0.03), desk_edge, 0.035)
	# 参考帧的隔断位于人物右前方，而不是横贯人物胸口；降低并右移后，
	# 保留“桌面—显示器—隔断”的办公语义，同时让坐姿人物和双手保持可见。
	_add_box("原创桌面后挡板", Vector3(0.82, 0.32, 0.055), Vector3(0.88, 0.96, 0.40), metal, 0.018)
	_add_box("原创显示器外框", Vector3(0.82, 0.56, 0.06), Vector3(0.08, 1.28, -0.16), screen_frame, 0.025)
	_add_box("原创显示器屏幕", Vector3(0.66, 0.40, 0.066), Vector3(0.08, 1.28, -0.20), screen, 0.018)
	_add_box("原创显示器支架", Vector3(0.07, 0.25, 0.07), Vector3(0.08, 0.99, -0.16), metal, 0.012)
	_add_box("原创键盘", Vector3(0.44, 0.035, 0.16), Vector3(0.02, 0.94, 0.22), metal, 0.012)
	_add_box("原创文件夹", Vector3(0.34, 0.04, 0.23), Vector3(-0.58, 0.94, 0.16), paper, 0.01)
	_add_box("原创桌面台灯杆", Vector3(0.045, 0.38, 0.045), Vector3(0.84, 1.08, 0.18), metal, 0.01)
	_add_box("原创桌面台灯罩", Vector3(0.28, 0.09, 0.18), Vector3(0.84, 1.29, 0.18), Color("d59b54"), 0.025)
	_add_box("原创椅子座面", Vector3(0.60, 0.12, 0.60), Vector3(0.0, 0.43, 0.94), chair, 0.07)
	_add_box("原创椅子靠背", Vector3(0.56, 0.64, 0.10), Vector3(0.0, 0.73, 1.18), chair, 0.05)
	_add_cylinder("原创椅子立柱", Vector3(0.0, 0.22, 0.94), 0.045, 0.34, metal)
	for leg_index in range(5):
		var angle := TAU * float(leg_index) / 5.0
		_add_box("原创椅子支脚", Vector3(0.34, 0.035, 0.055), Vector3(cos(angle) * 0.18, 0.055, 0.94 + sin(angle) * 0.18), metal, 0.012)
	_build_surface_details()

func _build_surface_details() -> void:
	# 只增加近景可读的办公用品和材质分层，不改变正式碰撞体与交互挂点。
	var screen_detail := _material(Color("5fadb0"), 0.28, 0.08)
	screen_detail.emission_enabled = true
	screen_detail.emission = Color("1b5a5c")
	screen_detail.emission_energy_multiplier = 0.10
	var dark_metal := _material(Color("252c30"), 0.36, 0.34)
	var warm_metal := _material(Color("b18754"), 0.42, 0.42)
	var paper_edge := _material(Color("a69b8c"), 0.78)
	var mug := _material(Color("9a5144"), 0.48, 0.06)
	var chair_detail := _material(Color("52636c"), 0.56, 0.10)

	# 显示器增加状态条、光标和底部指示灯，使近景不再是单色平面。
	_add_box("原创显示器界面状态条", Vector3(0.42, 0.025, 0.012), Vector3(0.08, 1.43, -0.239), screen_detail, 0.004)
	_add_box("原创显示器界面侧栏", Vector3(0.025, 0.26, 0.012), Vector3(-0.19, 1.27, -0.239), screen_detail, 0.004)
	_add_box("原创显示器界面光标", Vector3(0.08, 0.025, 0.014), Vector3(0.18, 1.18, -0.240), screen_detail, 0.004)
	_add_box("原创显示器电源指示灯", Vector3(0.045, 0.018, 0.014), Vector3(0.38, 1.05, -0.240), warm_metal, 0.004)

	# 键盘用三排键帽和掌托区分出输入设备，仍然是静态表现网格。
	for row in range(3):
		_add_box("原创键盘键列", Vector3(0.36 - float(row) * 0.03, 0.018, 0.026), Vector3(0.02, 0.965 + float(row) * 0.012, 0.16 + float(row) * 0.045), dark_metal, 0.004)
	_add_box("原创键盘掌托", Vector3(0.40, 0.020, 0.038), Vector3(0.02, 0.965, 0.285), paper_edge, 0.006)

	# 抽屉把手、桌面线缆孔和一只杯子为构图提供尺度与生活痕迹。
	_add_box("原创左侧抽屉把手", Vector3(0.20, 0.035, 0.035), Vector3(-0.78, 0.48, -0.345), warm_metal, 0.008)
	_add_box("原创右侧抽屉把手", Vector3(0.20, 0.035, 0.035), Vector3(0.78, 0.48, -0.345), warm_metal, 0.008)
	_add_cylinder("原创桌面线缆孔", Vector3(0.72, 0.935, 0.31), 0.065, 0.018, dark_metal)
	_add_cylinder("原创桌面咖啡杯", Vector3(-0.82, 0.99, 0.20), 0.075, 0.14, mug)
	_add_cylinder("原创桌面咖啡杯口", Vector3(-0.82, 1.065, 0.20), 0.058, 0.012, dark_metal)

	# 椅子扶手和靠背中缝强化人体尺度，但不创建新的碰撞体。
	_add_box("原创椅子扶手-左", Vector3(0.075, 0.065, 0.34), Vector3(-0.34, 0.70, 0.98), chair_detail, 0.018)
	_add_box("原创椅子扶手-右", Vector3(0.075, 0.065, 0.34), Vector3(0.34, 0.70, 0.98), chair_detail, 0.018)
	_add_box("原创椅子靠背中缝", Vector3(0.018, 0.50, 0.018), Vector3(0.0, 0.73, 1.125), chair_detail, 0.004)

func _build_contract() -> void:
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
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, color_or_material: Variant, bevel: float) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	if bevel > 0.0:
		mesh.subdivide_width = 2
		mesh.subdivide_height = 2
		mesh.subdivide_depth = 2
	node.mesh = mesh
	node.position = at
	node.material_override = color_or_material if color_or_material is Material else _material(color_or_material, 0.72)
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
	add_child(node)

extends Node3D

## P0 办公室环境候选细节，仅用于隔离覆盖测试，不承担碰撞和导航。

func _ready() -> void:
	_build_wall_details()
	_build_desk_details()
	_build_partition_details()
	_build_corridor_details()
	_build_ceiling_details()

func _build_wall_details() -> void:
	var panel := _material(Color("6d756f"), 0.78)
	var frame := _material(Color("cbbca9"), 0.60)
	var glass := _material(Color("6e9ca2"), 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.38
	var sign := _material(Color("b64237"), 0.52)
	for x in [-7.2, -3.6, 0.0, 3.6, 7.2]:
		_add_box("候选墙面窗台", Vector3(2.45, 0.08, 0.16), Vector3(x, 1.62, -10.12), frame, 0.02)
		_add_box("候选墙面装饰板", Vector3(1.55, 0.58, 0.035), Vector3(x, 3.55, -10.06), panel, 0.025)
		_add_box("候选墙面玻璃分格", Vector3(2.05, 1.22, 0.035), Vector3(x, 2.32, -10.07), glass, 0.018)
		_add_box("候选墙面踢脚线", Vector3(21.0, 0.12, 0.10), Vector3(0.0, 0.30, -10.10), frame, 0.02)
	_add_box("候选办公室出口标牌", Vector3(1.12, 0.30, 0.045), Vector3(8.1, 3.08, -10.08), sign, 0.025)
	_add_box("候选办公室出口箭头", Vector3(0.32, 0.06, 0.055), Vector3(8.1, 3.08, -10.13), frame, 0.012)

func _build_desk_details() -> void:
	var wood := _material(Color("9a684d"), 0.68)
	var dark_wood := _material(Color("4e3c35"), 0.72)
	var screen := _material(Color("4f8796"), 0.30)
	screen.emission_enabled = true
	screen.emission = Color("1a3945")
	screen.emission_energy_multiplier = 0.55
	for location in [Vector3(-4.8, 0.0, 2.0), Vector3(0.0, 0.0, 2.0), Vector3(4.8, 0.0, 2.0), Vector3(-4.8, 0.0, -3.3), Vector3(4.8, 0.0, -3.3)]:
		var desk := Node3D.new()
		desk.name = "候选工位细节"
		desk.position = location
		add_child(desk)
		_add_child_box(desk, "候选桌面", Vector3(2.52, 0.07, 0.96), Vector3(0.0, 0.08, 0.0), wood, 0.035)
		_add_child_box(desk, "候选抽屉", Vector3(0.42, 0.48, 0.70), Vector3(-0.82, -0.28, 0.16), dark_wood, 0.025)
		_add_child_box(desk, "候选显示器", Vector3(0.66, 0.48, 0.055), Vector3(0.0, 0.42, 0.05), screen, 0.025)
		_add_child_box(desk, "候选显示器支架", Vector3(0.07, 0.25, 0.07), Vector3(0.0, 0.21, 0.05), dark_wood, 0.01)
		_add_child_box(desk, "候选文件夹", Vector3(0.28, 0.035, 0.22), Vector3(0.58, 0.14, 0.28), _material(Color("d4b47e"), 0.68), 0.01)
		_add_child_box(desk, "候选键盘", Vector3(0.30, 0.025, 0.13), Vector3(0.0, 0.14, 0.30), dark_wood, 0.012)
		_add_child_box(desk, "候选办公椅座", Vector3(0.52, 0.12, 0.52), Vector3(0.0, -0.04, 0.76), dark_wood, 0.06)
		_add_child_box(desk, "候选办公椅靠背", Vector3(0.48, 0.62, 0.10), Vector3(0.0, 0.28, 0.98), dark_wood, 0.04)
		_add_child_cylinder(desk, "候选办公椅立柱", Vector3(0.0, -0.22, 0.76), 0.035, 0.36, dark_wood)
		_add_child_box(desk, "候选桌下电源盒", Vector3(0.20, 0.18, 0.28), Vector3(0.82, -0.08, -0.22), dark_wood, 0.02)

func _build_partition_details() -> void:
	var frame := _material(Color("87918d"), 0.60)
	var frosted := _material(Color("b4c3bd"), 0.48)
	frosted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frosted.albedo_color.a = 0.32
	for location in [Vector3(-7.2, 1.45, 0.0), Vector3(-2.4, 1.45, 0.0), Vector3(2.4, 1.45, 0.0), Vector3(7.2, 1.45, 0.0)]:
		_add_box("候选工位玻璃隔断", Vector3(0.08, 2.25, 2.30), location, frosted, 0.018)
		_add_box("候选工位隔断顶框", Vector3(0.14, 0.10, 2.38), location + Vector3(0.0, 1.14, 0.0), frame, 0.02)
		_add_box("候选工位隔断侧框", Vector3(0.14, 2.28, 0.10), location + Vector3(0.0, 0.0, 1.16), frame, 0.02)
		_add_box("候选工位隔断侧框", Vector3(0.14, 2.28, 0.10), location + Vector3(0.0, 0.0, -1.16), frame, 0.02)

func _build_corridor_details() -> void:
	var metal := _material(Color("59636a"), 0.42, 0.28)
	var blue := _material(Color("476e7c"), 0.34)
	var plant := _material(Color("5a8057"), 0.86)
	_add_box("候选电梯左门", Vector3(1.18, 2.55, 0.06), Vector3(8.18, 1.58, -8.12), metal, 0.025)
	_add_box("候选电梯右门", Vector3(1.18, 2.55, 0.06), Vector3(9.42, 1.58, -8.12), metal, 0.025)
	_add_box("候选电梯门框", Vector3(2.72, 0.12, 0.10), Vector3(8.80, 2.90, -8.10), blue, 0.025)
	_add_box("候选电梯呼叫面板", Vector3(0.20, 0.52, 0.05), Vector3(10.08, 1.56, -8.05), blue, 0.018)
	_add_box("候选电梯楼层显示", Vector3(0.30, 0.14, 0.055), Vector3(8.80, 2.72, -8.08), _material(Color("e4b65f"), 0.35), 0.015)
	_add_box("候选走廊储物柜", Vector3(2.20, 1.44, 0.60), Vector3(-9.10, 0.98, -7.72), metal, 0.04)
	for x in [-9.65, -9.10, -8.55]:
		_add_box("候选储物柜门缝", Vector3(0.025, 1.12, 0.02), Vector3(x, 0.98, -8.04), blue, 0.006)
	_add_box("候选绿植花盆", Vector3(0.54, 0.44, 0.54), Vector3(-9.0, 0.45, -4.8), metal, 0.04)
	_add_box("候选绿植叶冠", Vector3(0.80, 0.62, 0.80), Vector3(-9.0, 1.00, -4.8), plant, 0.16)

func _build_ceiling_details() -> void:
	var light_material := _material(Color("fff0cc"), 0.24)
	light_material.emission_enabled = true
	light_material.emission = Color("fff0cc")
	light_material.emission_energy_multiplier = 0.65
	for x in [-7.2, -3.6, 0.0, 3.6, 7.2]:
		_add_box("候选暖色灯板", Vector3(2.05, 0.055, 0.28), Vector3(x, 3.86, -1.5), light_material, 0.015)
		_add_box("候选后排灯板", Vector3(2.05, 0.055, 0.28), Vector3(x, 3.86, 5.6), light_material, 0.015)
		_add_warm_omni("候选暖色局部灯", Vector3(x, 3.50, -1.5))
		_add_warm_omni("候选后排局部灯", Vector3(x, 3.50, 5.6))

func _add_warm_omni(node_name: String, at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = Color("ffd9ae")
	light.light_energy = 0.62
	light.omni_range = 3.6
	light.shadow_enabled = false
	add_child(light)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float) -> void:
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
	node.material_override = material
	add_child(node)

func _add_child_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float) -> void:
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
	node.material_override = material
	parent.add_child(node)

func _add_child_cylinder(parent: Node3D, node_name: String, at: Vector3, radius: float, height: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)

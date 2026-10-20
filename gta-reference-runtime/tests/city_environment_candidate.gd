extends Node3D

## P0 城市环境候选细节，仅用于覆盖测试，不承担碰撞和导航。

func _ready() -> void:
	var wall := _material(Color("b89572"), 0.76)
	var trim := _material(Color("e7d2a8"), 0.56)
	var red := _material(Color("a52f2a"), 0.50)
	var glass := _material(Color("315d68"), 0.22, 0.08)
	var road := _material(Color("d2c29d"), 0.82)
	var dark := _material(Color("34363b"), 0.78, 0.12)
	var green := _material(Color("4f7657"), 0.86)
	var light := _material(Color("f4d895"), 0.30)
	light.emission_enabled = true
	light.emission = Color("7a5d27")
	light.emission_energy_multiplier = 0.45
	_add_box("候选店铺门面", Vector3(7.5, 3.2, 0.08), Vector3(-9.0, 1.65, -7.72), wall, 0.04)
	_add_box("候选店铺门头", Vector3(6.8, 0.58, 0.12), Vector3(-9.0, 3.10, -7.84), red, 0.05)
	_add_box("候选店铺门头装饰", Vector3(5.9, 0.12, 0.14), Vector3(-9.0, 3.46, -7.83), trim, 0.025)
	_add_box("候选店铺左窗", Vector3(2.20, 1.55, 0.05), Vector3(-11.05, 2.08, -7.84), glass, 0.025)
	_add_box("候选店铺右窗", Vector3(2.20, 1.55, 0.05), Vector3(-6.95, 2.08, -7.84), glass, 0.025)
	_add_box("候选店铺中柱", Vector3(0.12, 1.70, 0.10), Vector3(-9.0, 2.08, -7.88), trim, 0.02)
	for x in [-12.1, -10.9, -9.7, -8.5, -7.3, -6.1, -4.9]:
		_add_box("候选店铺遮阳条", Vector3(0.86, 0.12, 0.28), Vector3(x, 3.64, -7.94), red if int(abs(x) * 10.0) % 2 == 0 else trim, 0.02)
	for z in [-6.2, -3.9, -1.6, 0.7, 3.0, 5.3]:
		_add_box("候选道路边线", Vector3(0.10, 0.035, 1.42), Vector3(-3.55, 0.08, z), trim, 0.01)
		_add_box("候选道路边线", Vector3(0.10, 0.035, 1.42), Vector3(3.55, 0.08, z), trim, 0.01)
	_add_box("候选店铺地台", Vector3(7.8, 0.12, 0.72), Vector3(-9.0, 0.10, -7.42), road, 0.03)
	_add_box("候选仓储门框", Vector3(1.8, 2.12, 0.10), Vector3(-6.5, 1.22, -5.04), trim, 0.035)
	_add_box("候选仓储卷帘门", Vector3(1.48, 1.74, 0.035), Vector3(-6.5, 1.22, -5.10), dark, 0.025)
	for y in [0.58, 0.82, 1.06, 1.30, 1.54, 1.78]:
		_add_box("候选卷帘门横槽", Vector3(1.30, 0.025, 0.02), Vector3(-6.5, y, -5.14), trim, 0.006)
	_add_box("候选店铺招牌灯", Vector3(0.22, 0.22, 0.06), Vector3(-12.55, 2.76, -7.83), light, 0.02)
	_add_box("候选店铺招牌灯", Vector3(0.22, 0.22, 0.06), Vector3(-5.45, 2.76, -7.83), light, 0.02)
	for x in [-11.8, -9.0, -6.2]:
		_add_box("候选店铺花槽", Vector3(1.45, 0.16, 0.42), Vector3(x, 0.62, -7.84), dark, 0.025)
		_add_box("候选店铺绿植", Vector3(0.86, 0.46, 0.22), Vector3(x, 0.86, -7.84), green, 0.10)
	_add_box("候选路口人行道", Vector3(7.3, 0.06, 1.25), Vector3(0.0, 0.12, -7.15), trim, 0.02)
	for z in [-7.62, -7.34, -7.06, -6.78]:
		_add_box("候选人行道斑马线", Vector3(7.0, 0.025, 0.11), Vector3(0.0, 0.18, z), road, 0.01)
	_build_lamp(Vector3(4.85, 0.0, -5.70), dark, light)
	_build_lamp(Vector3(-3.95, 0.0, 5.80), dark, light)
	_build_traffic_sign(Vector3(3.15, 0.0, -6.12), trim, red)
	_add_box("候选远景楼体", Vector3(4.3, 7.2, 0.32), Vector3(8.0, 3.6, -8.65), wall, 0.06)
	_add_box("候选远景楼体窗带", Vector3(3.5, 0.26, 0.04), Vector3(8.0, 4.8, -8.84), glass, 0.02)
	_add_box("候选远景楼体窗带", Vector3(3.5, 0.26, 0.04), Vector3(8.0, 3.8, -8.84), glass, 0.02)
	_add_box("候选远景楼体窗带", Vector3(3.5, 0.26, 0.04), Vector3(8.0, 2.8, -8.84), glass, 0.02)

func _build_lamp(at: Vector3, dark: Material, light: Material) -> void:
	_add_cylinder("候选街灯灯杆", at + Vector3(0.0, 1.75, 0.0), 0.045, 3.5, dark)
	_add_box("候选街灯横臂", Vector3(0.68, 0.06, 0.06), at + Vector3(0.30, 3.38, 0.0), dark, 0.015)
	_add_box("候选街灯灯罩", Vector3(0.22, 0.10, 0.16), at + Vector3(0.62, 3.30, 0.0), light, 0.025)

func _build_traffic_sign(at: Vector3, trim: Material, red: Material) -> void:
	_add_cylinder("候选交通标志杆", at + Vector3(0.0, 1.15, 0.0), 0.035, 2.3, trim)
	_add_box("候选交通标志牌", Vector3(0.50, 0.50, 0.06), at + Vector3(0.0, 2.35, 0.0), red, 0.05)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float) -> void:
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
	add_child(node)

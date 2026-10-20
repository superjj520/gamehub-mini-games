extends Node3D

## P0 三轮车候选外观，仅用于城市运行时覆盖测试。

func _ready() -> void:
	var blue := _material(Color("1d6285"), 0.42, 0.18)
	var blue_dark := _material(Color("123b52"), 0.50, 0.10)
	var yellow := _material(Color("e1a83e"), 0.34, 0.05)
	var rubber := _material(Color("11161b"), 0.88, 0.0)
	var metal := _material(Color("6f7b84"), 0.28, 0.55)
	var glass := _material(Color("8bc5d1"), 0.18, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.62
	var fabric := _material(Color("d6b36a"), 0.82, 0.0)
	var indicator := _material(Color("f0c452"), 0.24, 0.0)
	indicator.emission_enabled = true
	indicator.emission = Color("8a5b12")
	indicator.emission_energy_multiplier = 0.35

	_add_box("候选三轮车车体", Vector3(1.72, 0.58, 2.42), Vector3(0.0, 0.02, 0.0), blue, 0.12)
	_add_box("候选三轮车底盘", Vector3(1.52, 0.18, 2.62), Vector3(0.0, -0.32, 0.03), blue_dark, 0.06)
	_add_box("候选三轮车前挡板", Vector3(1.20, 0.42, 0.62), Vector3(0.0, 0.46, -0.76), yellow, 0.10)
	_add_box("候选三轮车挡风玻璃", Vector3(0.94, 0.45, 0.05), Vector3(0.0, 0.92, -0.70), glass, 0.025)
	_add_box("候选三轮车货架", Vector3(1.36, 0.18, 0.86), Vector3(0.0, 0.58, 0.65), blue_dark, 0.05)
	_add_box("候选三轮车货架左栏", Vector3(0.08, 0.46, 0.86), Vector3(-0.64, 0.80, 0.65), metal, 0.02)
	_add_box("候选三轮车货架右栏", Vector3(0.08, 0.46, 0.86), Vector3(0.64, 0.80, 0.65), metal, 0.02)
	_add_box("候选三轮车货架后栏", Vector3(1.36, 0.46, 0.08), Vector3(0.0, 0.80, 1.08), metal, 0.02)
	_add_box("候选三轮车货箱", Vector3(1.12, 0.52, 0.70), Vector3(0.0, 0.74, 0.66), blue, 0.07)
	_add_box("候选三轮车货箱门缝", Vector3(0.86, 0.025, 0.015), Vector3(0.0, 0.72, 1.015), metal, 0.005)
	_add_box("候选三轮车顶篷", Vector3(1.52, 0.08, 1.22), Vector3(0.0, 1.65, 0.38), fabric, 0.05)
	for x in [-0.64, 0.64]:
		_add_cylinder("候选三轮车顶篷支柱", Vector3(x, 1.20, 0.78), 0.035, 0.92, metal)
		_add_cylinder("候选三轮车顶篷前支柱", Vector3(x, 1.20, -0.30), 0.035, 0.92, metal)
	_add_box("候选三轮车座椅", Vector3(0.68, 0.16, 0.56), Vector3(0.0, 0.62, 0.02), _material(Color("332a29"), 0.72, 0.0), 0.06)
	_add_box("候选三轮车靠背", Vector3(0.68, 0.46, 0.10), Vector3(0.0, 0.84, 0.34), _material(Color("332a29"), 0.72, 0.0), 0.04)
	_add_cylinder("候选三轮车车把立柱", Vector3(0.0, 1.02, -0.76), 0.045, 0.58, metal)
	_add_box("候选三轮车车把", Vector3(0.92, 0.08, 0.08), Vector3(0.0, 1.30, -0.80), metal, 0.02)
	_add_box("候选三轮车前灯", Vector3(0.42, 0.16, 0.08), Vector3(0.0, 0.70, -1.08), yellow, 0.025)
	_add_box("候选三轮车左转向灯", Vector3(0.13, 0.11, 0.06), Vector3(-0.58, 0.56, -1.10), indicator, 0.015)
	_add_box("候选三轮车右转向灯", Vector3(0.13, 0.11, 0.06), Vector3(0.58, 0.56, -1.10), indicator, 0.015)
	_add_box("候选三轮车左后视镜", Vector3(0.16, 0.12, 0.035), Vector3(-0.62, 1.20, -0.92), glass, 0.018)
	_add_box("候选三轮车右后视镜", Vector3(0.16, 0.12, 0.035), Vector3(0.62, 1.20, -0.92), glass, 0.018)
	_add_cylinder("候选三轮车左后视镜杆", Vector3(-0.56, 1.13, -0.88), 0.018, 0.26, metal, Vector3(0.0, 0.0, -28.0))
	_add_cylinder("候选三轮车右后视镜杆", Vector3(0.56, 1.13, -0.88), 0.018, 0.26, metal, Vector3(0.0, 0.0, 28.0))
	_add_box("候选三轮车车牌", Vector3(0.34, 0.14, 0.025), Vector3(0.0, 0.34, -1.08), _material(Color("f0e4bf"), 0.58, 0.0), 0.01)
	_add_box("候选三轮车后保险杠", Vector3(1.34, 0.12, 0.12), Vector3(0.0, 0.16, 1.27), metal, 0.02)
	for location in [Vector3(-0.88, -0.38, 0.70), Vector3(0.88, -0.38, 0.70), Vector3(0.0, -0.38, -0.96)]:
		_add_cylinder("候选三轮车轮胎", location, 0.30, 0.16, rubber, Vector3(0.0, 0.0, 90.0))
		_add_cylinder("候选三轮车轮毂", location + Vector3(0.0, 0.0, -0.085), 0.13, 0.03, metal, Vector3(0.0, 0.0, 90.0))

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

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = material
	add_child(node)

extends Node3D

## P0 城市原创程序化交互道具候选层。
## 可用于正式空目录的内部候选和隔离覆盖预览；不承担碰撞、导航、任务判定或生产权利声明。

func _ready() -> void:
	var shelf_dark := _material(Color("3d4547"), 0.72)
	var shelf_edge := _material(Color("d4b06e"), 0.60)
	var carton := _material(Color("c98e4e"), 0.84)
	var egg := _material(Color("f0e2bd"), 0.68)
	var cyan := _emissive_material(Color("60b9c0"), Color("1a5960"), 0.55)
	var paper := _material(Color("f0e0bc"), 0.88)
	var warning := _emissive_material(Color("ef9a4e"), Color("7b321e"), 0.35)

	_build_egg_shelf(Vector3(-10.55, 0.0, -9.35), shelf_dark, shelf_edge, carton, egg)
	_build_egg_shelf(Vector3(-7.55, 0.0, -9.35), shelf_dark, shelf_edge, carton, egg)
	_build_scan_counter(Vector3(8.5, 0.0, 5.5), shelf_dark, cyan, paper)
	_build_delivery_marker(Vector3(-6.5, 0.0, -4.80), warning, paper)
	_build_shop_basket(Vector3(-8.8, 0.0, -8.65), carton, egg)

func _build_egg_shelf(at: Vector3, dark: Material, edge: Material, carton: Material, egg: Material) -> void:
	var shelf := Node3D.new()
	shelf.name = "候选鸡蛋货架"
	shelf.position = at
	add_child(shelf)
	_add_box(shelf, "货架侧板-左", Vector3(0.08, 1.55, 0.46), Vector3(-0.76, 0.78, 0.0), dark, 0.02)
	_add_box(shelf, "货架侧板-右", Vector3(0.08, 1.55, 0.46), Vector3(0.76, 0.78, 0.0), dark, 0.02)
	for level in [0.22, 0.72, 1.22]:
		_add_box(shelf, "货架层板", Vector3(1.58, 0.07, 0.52), Vector3(0.0, level, 0.0), edge, 0.015)
		_add_box(shelf, "蛋盒", Vector3(0.92, 0.12, 0.32), Vector3(0.0, level + 0.10, -0.02), carton, 0.025)
		for column in range(4):
			_add_sphere(shelf, "鸡蛋", 0.055, Vector3(-0.29 + float(column) * 0.19, level + 0.18, -0.10), egg)
	_add_box(shelf, "货架顶板", Vector3(1.74, 0.10, 0.58), Vector3(0.0, 1.62, 0.0), dark, 0.02)

func _build_scan_counter(at: Vector3, dark: Material, cyan: Material, paper: Material) -> void:
	var counter := Node3D.new()
	counter.name = "候选扫码台"
	counter.position = at
	add_child(counter)
	_add_box(counter, "扫码台桌面", Vector3(1.55, 0.10, 0.82), Vector3(0.0, 0.94, 0.0), dark, 0.03)
	_add_box(counter, "扫码台支架", Vector3(0.12, 1.06, 0.12), Vector3(0.0, 1.44, 0.0), dark, 0.02)
	_add_box(counter, "扫码屏幕", Vector3(0.62, 0.42, 0.05), Vector3(0.0, 1.94, -0.02), cyan, 0.025)
	_add_box(counter, "扫码提示牌", Vector3(0.72, 0.28, 0.035), Vector3(0.0, 1.22, -0.43), paper, 0.01)
	for index in range(5):
		_add_box(counter, "二维码模块", Vector3(0.055, 0.055, 0.02), Vector3(-0.22 + float(index % 3) * 0.16, 1.32 + float(index / 3) * 0.08, -0.455), dark, 0.005)

func _build_delivery_marker(at: Vector3, warning: Material, paper: Material) -> void:
	var marker := Node3D.new()
	marker.name = "候选配送标记"
	marker.position = at
	add_child(marker)
	_add_box(marker, "配送台", Vector3(1.65, 0.16, 0.72), Vector3(0.0, 0.20, 0.0), warning, 0.035)
	_add_box(marker, "配送牌支柱", Vector3(0.08, 1.18, 0.08), Vector3(0.0, 0.84, 0.0), warning, 0.015)
	_add_box(marker, "配送牌", Vector3(0.80, 0.42, 0.06), Vector3(0.0, 1.48, 0.0), paper, 0.02)
	_add_box(marker, "配送牌色带", Vector3(0.64, 0.08, 0.02), Vector3(0.0, 1.51, -0.04), warning, 0.005)

func _build_shop_basket(at: Vector3, carton: Material, egg: Material) -> void:
	var basket := Node3D.new()
	basket.name = "候选购物篮"
	basket.position = at
	add_child(basket)
	_add_box(basket, "购物篮底", Vector3(0.64, 0.10, 0.44), Vector3(0.0, 0.18, 0.0), carton, 0.025)
	_add_box(basket, "购物篮前框", Vector3(0.64, 0.42, 0.06), Vector3(0.0, 0.40, -0.19), carton, 0.02)
	_add_box(basket, "购物篮后框", Vector3(0.64, 0.42, 0.06), Vector3(0.0, 0.40, 0.19), carton, 0.02)
	for column in range(3):
		_add_sphere(basket, "篮中鸡蛋", 0.07, Vector3(-0.18 + float(column) * 0.18, 0.33, 0.0), egg)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.48)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

func _add_box(parent: Node, node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float) -> void:
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
	parent.add_child(node)

func _add_sphere(parent: Node, node_name: String, radius: float, at: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)

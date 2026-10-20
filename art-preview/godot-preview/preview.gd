extends Node3D

const OUTPUT_PATH := "../visual-direction-preview.png"

var skin := Color("b86e4c")
var dark := Color("151a22")
var jacket := Color("27313c")
var shirt := Color("d7cdbb")
var red := Color("a32624")
var cream := Color("e4c77f")
var wall := Color("806e5c")
var glass := Color("315565")

func _ready() -> void:
	_build_lighting()
	_build_ground()
	_build_diorama(Vector3(-4.2, 0.0, 0.0), true)
	_build_diorama(Vector3(4.2, 0.0, 0.0), false)
	_build_camera()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		print("当前为无头渲染，仅验证预览场景可解析；图像截图需要图形窗口。")
		queue_free()
		await get_tree().process_frame
		get_tree().quit()
		return
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		print("当前无头渲染后端没有可读视口纹理；仅完成场景解析，不生成视觉证据。")
		get_tree().quit()
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		print("当前渲染后端没有有效像素；仅完成场景解析，不生成视觉证据。")
		get_tree().quit()
		return
	var output_path := ProjectSettings.globalize_path("res://../visual-direction-preview.png")
	image.save_png(output_path)
	print("视觉方向预览已输出：", output_path)
	get_tree().quit()

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("242a31")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("aeb9c2")
	settings.ambient_light_energy = 0.72
	environment.environment = settings
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_color = Color("ffd5a3")
	key.light_energy = 1.2
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 4.0, 5.0)
	fill.light_color = Color("9fc6e5")
	fill.light_energy = 4.0
	fill.omni_range = 18.0
	add_child(fill)

func _build_ground() -> void:
	var ground := _box(Vector3(18.0, 0.25, 10.0), Vector3(0.0, -0.15, 0.0), Color("34393b"), 0.04)
	ground.name = "预览地面"

func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.8, 12.6)
	camera.fov = 52.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.55, 0.0), Vector3.UP)
	camera.current = true

func _build_diorama(origin: Vector3, detailed: bool) -> void:
	var root := Node3D.new()
	root.name = "写实中等细节" if detailed else "低多边形写实"
	root.position = origin
	add_child(root)
	if detailed:
		_build_detailed_store(root)
		_build_detailed_player(root, Vector3(0.0, 0.0, 2.0))
		for index in range(6):
			var crowd_position := Vector3(-2.2 + float(index) * 0.86, 0.0, 2.25 + float(index % 2) * 0.35)
			_build_detailed_person(root, crowd_position, index)
	else:
		_build_simple_store(root)
		_build_simple_player(root, Vector3(0.0, 0.0, 2.0))
		for index in range(6):
			var crowd_position := Vector3(-2.2 + float(index) * 0.86, 0.0, 2.25 + float(index % 2) * 0.35)
			_build_simple_person(root, crowd_position, index)
		var border := _box(Vector3(8.0, 0.06, 0.06), Vector3(0.0, 0.03, 4.25), Color("bca36b"), 0.01)
		border.name = "低多边形边界"

func _build_detailed_store(root: Node3D) -> void:
	_root_box(root, Vector3(7.5, 4.2, 0.3), Vector3(0.0, 2.1, -0.8), wall, 0.10)
	_root_box(root, Vector3(0.28, 4.2, 0.55), Vector3(-3.65, 2.1, -0.45), cream, 0.04)
	_root_box(root, Vector3(0.28, 4.2, 0.55), Vector3(3.65, 2.1, -0.45), cream, 0.04)
	_root_box(root, Vector3(7.25, 0.62, 0.28), Vector3(0.0, 3.78, -0.48), red, 0.06)
	for index in range(6):
		var stripe_color := red if index % 2 == 0 else cream
		_root_box(root, Vector3(0.92, 0.16, 0.55), Vector3(-2.8 + float(index) * 1.12, 3.47, -0.58), stripe_color, 0.03)
	_root_box(root, Vector3(2.3, 1.8, 0.08), Vector3(-2.25, 2.0, -0.60), glass, 0.03)
	_root_box(root, Vector3(2.3, 1.8, 0.08), Vector3(2.25, 2.0, -0.60), glass, 0.03)
	_root_box(root, Vector3(0.10, 1.92, 0.12), Vector3(0.0, 2.0, -0.65), cream, 0.01)
	_root_box(root, Vector3(5.45, 2.45, 0.12), Vector3(0.0, 1.35, -0.58), Color("4a5053"), 0.03)
	for y in [0.45, 0.80, 1.15, 1.50, 1.85, 2.20]:
		_root_box(root, Vector3(5.45, 0.035, 0.04), Vector3(0.0, y, -0.66), Color("1c2022"), 0.005)
	_root_box(root, Vector3(5.6, 0.42, 0.08), Vector3(0.0, 4.0, -0.62), cream, 0.03)
	_add_sign(root, "鲜蛋铺", Vector3(0.0, 4.02, -0.67), dark)
	for x in [-1.7, 0.0, 1.7]:
		_root_box(root, Vector3(1.0, 0.32, 0.70), Vector3(x, 0.28, -0.72), Color("b58a46"), 0.08)
		for dx in [-0.24, 0.0, 0.24]:
			_root_sphere(root, Vector3(x + dx, 0.52, -0.72), 0.10, cream, Vector3(0.85, 1.05, 1.1))

func _build_simple_store(root: Node3D) -> void:
	_root_box(root, Vector3(7.5, 4.2, 0.4), Vector3(0.0, 2.1, -0.8), Color("8c806f"), 0.0)
	_root_box(root, Vector3(7.0, 0.70, 0.25), Vector3(0.0, 3.75, -0.50), Color("bb3e34"), 0.0)
	_root_box(root, Vector3(5.8, 2.3, 0.12), Vector3(0.0, 1.4, -0.58), Color("5b6062"), 0.0)
	_root_box(root, Vector3(5.0, 0.32, 0.12), Vector3(0.0, 4.0, -0.62), Color("e4c77f"), 0.0)

func _build_detailed_player(root: Node3D, at: Vector3) -> void:
	var actor := Node3D.new()
	actor.position = at
	root.add_child(actor)
	_child_box(actor, Vector3(0.68, 0.82, 0.42), Vector3(0.0, 1.10, 0.0), jacket, 0.08)
	_child_box(actor, Vector3(0.25, 0.5, 0.04), Vector3(0.0, 1.12, -0.23), shirt, 0.01)
	_child_box(actor, Vector3(0.50, 0.64, 0.18), Vector3(0.0, 1.10, 0.28), Color("1b466b"), 0.06)
	for side in [-1.0, 1.0]:
		_child_capsule(actor, Vector3(side * 0.46, 1.10, 0.0), 0.11, 0.72, jacket, Vector3(0.0, 0.0, side * 90.0))
		_child_sphere(actor, Vector3(side * 0.82, 1.10, 0.0), 0.12, skin, Vector3(1.0, 0.85, 0.9))
		_child_box(actor, Vector3(0.22, 0.72, 0.24), Vector3(side * 0.18, 0.50, 0.0), dark, 0.04)
		_child_box(actor, Vector3(0.28, 0.16, 0.42), Vector3(side * 0.18, 0.12, -0.08), Color("101319"), 0.04)
	_child_sphere(actor, Vector3(0.0, 1.77, 0.0), 0.245, skin, Vector3(0.92, 1.0, 0.88))
	_child_sphere(actor, Vector3(0.0, 1.94, -0.02), 0.255, Color("171519"), Vector3(1.0, 0.46, 0.95))

func _build_simple_player(root: Node3D, at: Vector3) -> void:
	var actor := Node3D.new()
	actor.position = at
	root.add_child(actor)
	_child_box(actor, Vector3(0.8, 0.9, 0.45), Vector3(0.0, 1.1, 0.0), Color("b94036"), 0.0)
	for side in [-1.0, 1.0]:
		_child_box(actor, Vector3(0.22, 0.75, 0.25), Vector3(side * 0.20, 0.48, 0.0), Color("202631"), 0.0)
		_child_sphere(actor, Vector3(side * 0.52, 1.10, 0.0), 0.14, skin, Vector3.ONE)
	_child_sphere(actor, Vector3(0.0, 1.82, 0.0), 0.27, skin, Vector3.ONE)
	_child_sphere(actor, Vector3(0.0, 1.98, 0.0), 0.28, Color("20232a"), Vector3(1.0, 0.42, 1.0))

func _build_detailed_person(root: Node3D, at: Vector3, index: int) -> void:
	var actor := Node3D.new()
	actor.position = at
	root.add_child(actor)
	var coat: Color = [Color("4f5966"), Color("6e594e"), Color("3e5366")][index % 3]
	_child_box(actor, Vector3(0.60, 0.78, 0.36), Vector3(0.0, 1.08, 0.0), coat, 0.06)
	_child_sphere(actor, Vector3(0.0, 1.72, 0.0), 0.22, skin, Vector3(0.92, 1.0, 0.9))
	_child_sphere(actor, Vector3(0.0, 1.87, -0.02), 0.23, Color("25272b"), Vector3(1.0, 0.45, 0.94))
	for side in [-1.0, 1.0]:
		_child_box(actor, Vector3(0.20, 0.70, 0.22), Vector3(side * 0.16, 0.48, 0.0), dark, 0.035)

func _build_simple_person(root: Node3D, at: Vector3, index: int) -> void:
	var actor := Node3D.new()
	actor.position = at
	root.add_child(actor)
	_child_box(actor, Vector3(0.72, 0.86, 0.42), Vector3(0.0, 1.08, 0.0), Color("586777") if index % 2 == 0 else Color("806454"), 0.0)
	_child_sphere(actor, Vector3(0.0, 1.75, 0.0), 0.24, skin, Vector3.ONE)
	_child_sphere(actor, Vector3(0.0, 1.92, 0.0), 0.25, Color("20232a"), Vector3(1.0, 0.42, 1.0))

func _add_sign(root: Node3D, text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 28
	label.modulate = color
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)

func _root_box(root: Node3D, size: Vector3, at: Vector3, color: Color, bevel: float) -> void:
	root.add_child(_box(size, at, color, bevel))

func _root_sphere(root: Node3D, at: Vector3, radius: float, color: Color, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color, 0.68)
	root.add_child(node)

func _child_box(root: Node3D, size: Vector3, at: Vector3, color: Color, bevel: float) -> void:
	root.add_child(_box(size, at, color, bevel))

func _child_sphere(root: Node3D, at: Vector3, radius: float, color: Color, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color, 0.68)
	root.add_child(node)

func _child_capsule(root: Node3D, at: Vector3, radius: float, height: float, color: Color, rotation: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = _material(color, 0.68)
	root.add_child(node)

func _box(size: Vector3, at: Vector3, color: Color, bevel: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color, 0.72)
	return node

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

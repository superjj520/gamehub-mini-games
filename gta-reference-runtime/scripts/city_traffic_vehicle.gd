extends CharacterBody3D

@export var travel_speed := 2.8
@export var signal_stop_distance := 2.4
@export var signal_braking := 10.0
@export var pursuit_speed := 4.8
@export var pursuit_acceleration := 9.0

var route: Array[Vector3] = []
var route_index := 0
var wheel_nodes: Array[Node3D] = []
var signal_stop_point := Vector3.ZERO
var has_signal_stop_point := false
var signal_red := false
var pursuit_target: Node3D
var pursuit_enabled := false
var police_visual := false
var police_light_nodes: Array[MeshInstance3D] = []
var police_light_elapsed := 0.0
const WHEEL_RADIUS := 0.26

func _physics_process(delta: float) -> void:
	if police_visual:
		_update_police_lights(delta)
	if pursuit_enabled:
		_process_pursuit(delta)
		return
	if route.is_empty():
		return
	var target := route[route_index]
	var offset := target - global_position
	if offset.length() < 0.2:
		route_index = (route_index + 1) % route.size()
		return
	var forward := offset.normalized()
	if signal_red and has_signal_stop_point:
		var to_signal := signal_stop_point - global_position
		var distance_ahead := to_signal.dot(forward)
		var lateral_distance := (to_signal - forward * distance_ahead).length()
		if distance_ahead >= -0.2 and distance_ahead <= signal_stop_distance and lateral_distance <= 1.5:
			velocity = velocity.move_toward(Vector3.ZERO, signal_braking * maxf(delta, 0.0))
			move_and_slide()
			if velocity.length() > 0.01:
				look_at(Vector3(signal_stop_point.x, global_position.y, signal_stop_point.z), Vector3.UP)
				_spin_wheels(velocity.length() * delta)
			else:
				_reset_wheels()
			return
	velocity = forward * travel_speed
	move_and_slide()
	look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)
	_spin_wheels(velocity.length() * delta)

func configure_path(points: Array[Vector3]) -> void:
	route = points
	if not route.is_empty():
		position = route[0]

func configure_signal_stop(point: Vector3) -> void:
	signal_stop_point = point
	has_signal_stop_point = true

func set_signal_red(is_red: bool) -> void:
	signal_red = is_red

func configure_pursuit(target: Node3D, configured_speed := -1.0) -> void:
	pursuit_target = target
	pursuit_enabled = is_instance_valid(target)
	if configured_speed > 0.0:
		pursuit_speed = configured_speed
	signal_red = false

func stop_pursuit() -> void:
	pursuit_enabled = false
	pursuit_target = null
	velocity = Vector3.ZERO

func _process_pursuit(delta: float) -> void:
	if not is_instance_valid(pursuit_target):
		stop_pursuit()
		return
	var offset := pursuit_target.global_position - global_position
	offset.y = 0.0
	if offset.length() <= 0.12:
		velocity = velocity.move_toward(Vector3.ZERO, pursuit_acceleration * maxf(delta, 0.0))
		move_and_slide()
		return
	var forward := offset.normalized()
	velocity = velocity.move_toward(forward * pursuit_speed, pursuit_acceleration * maxf(delta, 0.0))
	move_and_slide()
	look_at(Vector3(pursuit_target.global_position.x, global_position.y, pursuit_target.global_position.z), Vector3.UP)
	_spin_wheels(velocity.length() * maxf(delta, 0.0))

func prepare_reference_capture() -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	route_index = 0
	_reset_wheels()
	if not route.is_empty():
		global_position = route[0]
		if route.size() > 1:
			look_at(Vector3(route[1].x, global_position.y, route[1].z), Vector3.UP)

func add_body(color: Color) -> void:
	var body := MeshInstance3D.new()
	body.name = "远景车辆车身"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.45, 0.7, 2.4)
	body.mesh = body_mesh
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = color
	body.material_override = body_material
	add_child(body)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.0, 0.42, 0.95)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 0.5, 0.12)
	var cabin_material := StandardMaterial3D.new()
	cabin_material.albedo_color = Color("283342")
	cabin.material_override = cabin_material
	add_child(cabin)
	_add_visual_details(color)
	var collision := CollisionShape3D.new()
	collision.name = "交通碰撞体"
	var box := BoxShape3D.new()
	box.size = Vector3(1.45, 0.7, 2.4)
	collision.shape = box
	add_child(collision)

func add_police_body() -> void:
	police_visual = true
	add_body(Color("26313a"))
	police_light_nodes.append(_add_police_light("警车红灯", Vector3(0.30, 0.10, 0.18), Vector3(-0.18, 0.86, 0.05), Color("d84b55")))
	police_light_nodes.append(_add_police_light("警车蓝灯", Vector3(0.30, 0.10, 0.18), Vector3(0.20, 0.86, 0.05), Color("4b8fe8")))
	_update_police_lights(0.0)

func _add_police_light(node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _emissive_material(color)
	add_child(node)
	return node

func _update_police_lights(delta: float) -> void:
	police_light_elapsed = fmod(police_light_elapsed + maxf(delta, 0.0), 0.8)
	var red_active := police_light_elapsed < 0.4
	for light_index in range(police_light_nodes.size()):
		var light := police_light_nodes[light_index]
		if is_instance_valid(light):
			light.visible = red_active if light_index == 0 else not red_active

func _add_visual_details(body_color: Color) -> void:
	var dark := _material(Color("1c232a"), 0.82)
	var glass := _material(Color("304957"), 0.26, 0.05)
	var red := _emissive_material(Color("bd4545"))
	var amber := _emissive_material(Color("e1a245"))
	var chrome := _material(Color("aab1b5"), 0.34, 0.18)
	var plate := _material(Color("d8d2bd"), 0.72)
	var roof := MeshInstance3D.new()
	roof.name = "远景车辆车顶"
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.12, 0.08, 1.08)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 0.76, 0.12)
	roof.material_override = glass
	add_child(roof)
	for side in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		wheel.name = "远景车辆车轮-" + ("左" if side < 0.0 else "右")
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.26
		wheel_mesh.bottom_radius = 0.26
		wheel_mesh.height = 0.12
		wheel.mesh = wheel_mesh
		wheel.position = Vector3(side * 0.68, -0.28, 0.72)
		wheel.rotation_degrees.x = 90.0
		wheel.material_override = dark
		add_child(wheel)
		wheel_nodes.append(wheel)
		var front_wheel := wheel.duplicate()
		front_wheel.name = "远景车辆前轮-" + ("左" if side < 0.0 else "右")
		front_wheel.position.z = -0.72
		add_child(front_wheel)
		wheel_nodes.append(front_wheel)
		_add_box("远景车辆后视镜-" + ("左" if side < 0.0 else "右"), Vector3(0.08, 0.16, 0.22), Vector3(side * 0.61, 0.53, -0.44), dark)
		_add_box("远景车辆后视镜面-" + ("左" if side < 0.0 else "右"), Vector3(0.025, 0.11, 0.15), Vector3(side * 0.655, 0.53, -0.44), chrome)
	_add_box("远景车辆左尾灯", Vector3(0.18, 0.12, 0.05), Vector3(-0.48, 0.24, 1.23), red)
	_add_box("远景车辆右尾灯", Vector3(0.18, 0.12, 0.05), Vector3(0.48, 0.24, 1.23), red)
	_add_box("远景车辆前灯", Vector3(0.18, 0.12, 0.05), Vector3(-0.48, 0.24, -1.23), amber)
	_add_box("远景车辆前灯", Vector3(0.18, 0.12, 0.05), Vector3(0.48, 0.24, -1.23), amber)
	_add_box("远景车辆前保险杠", Vector3(1.25, 0.10, 0.08), Vector3(0.0, 0.08, -1.27), chrome)
	_add_box("远景车辆后保险杠", Vector3(1.25, 0.10, 0.08), Vector3(0.0, 0.08, 1.27), chrome)
	_add_box("远景车辆后车牌", Vector3(0.38, 0.16, 0.025), Vector3(0.0, 0.23, 1.265), plate)
	_add_box("远景车辆前车牌", Vector3(0.38, 0.16, 0.025), Vector3(0.0, 0.23, -1.265), plate)
	_add_box("远景车辆挡风玻璃左框", Vector3(0.05, 0.34, 0.04), Vector3(-0.43, 0.51, -0.34), dark)
	_add_box("远景车辆挡风玻璃右框", Vector3(0.05, 0.34, 0.04), Vector3(0.43, 0.51, -0.34), dark)
	_add_box("远景车辆腰线", Vector3(1.50, 0.06, 0.08), Vector3(0.0, 0.20, 0.0), _material(body_color.lightened(0.16), 0.46, 0.08))

func _spin_wheels(distance: float) -> void:
	if distance <= 0.0:
		return
	var angle := distance / WHEEL_RADIUS
	for wheel in wheel_nodes:
		if is_instance_valid(wheel):
			wheel.rotate_x(-angle)

func _reset_wheels() -> void:
	for wheel in wheel_nodes:
		if is_instance_valid(wheel):
			wheel.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.42, 0.05)
	material.emission_enabled = true
	material.emission = color.darkened(0.22)
	material.emission_energy_multiplier = 0.5
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)

extends Node3D

## P0 办公室 NPC 候选外观，仅用于隔离接入和视觉候选截图。

var _animation_player: AnimationPlayer

func _ready() -> void:
	_build_visual()
	_build_mount_points()
	_build_animation_library()

func _build_visual() -> void:
	var jacket := Color("596879")
	var shirt := Color("d9d2c4")
	var pants := Color("252d3a")
	var skin := Color("a96247")
	var hair := Color("181b22")
	var badge := Color("d7a74f")
	_add_box("候选NPC身体", Vector3(0.62, 0.74, 0.38), Vector3(0.0, 0.0, 0.0), jacket, 0.10)
	_add_box("候选NPC衬衣", Vector3(0.22, 0.42, 0.05), Vector3(0.0, 0.02, -0.22), shirt, 0.02)
	_add_box("候选NPC胸牌", Vector3(0.10, 0.12, 0.025), Vector3(0.19, 0.10, -0.255), badge, 0.01)
	_add_cylinder("候选NPC颈部", Vector3(0.0, 0.45, 0.0), 0.11, 0.15, skin)
	_add_sphere("候选NPC头部", Vector3(0.0, 0.68, 0.0), 0.22, skin, Vector3(0.92, 1.0, 0.88))
	_add_sphere("候选NPC头发", Vector3(0.0, 0.84, 0.0), 0.225, hair, Vector3(1.0, 0.40, 0.94))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_add_capsule("候选NPC上臂" + suffix, Vector3(side * 0.39, -0.08, 0.0), 0.085, 0.36, jacket, Vector3(0.0, 0.0, side * -10.0))
		_add_capsule("候选NPC前臂" + suffix, Vector3(side * 0.52, -0.22, -0.01), 0.075, 0.30, jacket, Vector3(0.0, 0.0, side * -20.0))
		_add_sphere("候选NPC手部" + suffix, Vector3(side * 0.61, -0.34, -0.02), 0.09, skin, Vector3(1.0, 0.86, 0.9))
		_add_capsule("候选NPC腿部" + suffix, Vector3(side * 0.16, -0.57, 0.0), 0.11, 0.58, pants, Vector3.ZERO)
		_add_box("候选NPC鞋子" + suffix, Vector3(0.24, 0.14, 0.36), Vector3(side * 0.16, -0.90, -0.07), Color("101319"), 0.04)

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ["idle_default", "walk_default", "search_default", "alert_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(animation_name, animation)
	_add_animation_track(library.get_animation("idle_default"), "候选NPC头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 2.5, 0.0))
	_add_animation_track(library.get_animation("walk_default"), "候选NPC上臂-左:rotation_degrees", Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, 12.0))
	_add_animation_track(library.get_animation("walk_default"), "候选NPC上臂-右:rotation_degrees", Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -12.0))
	_add_animation_track(library.get_animation("search_default"), "候选NPC头部:rotation_degrees", Vector3(0.0, -18.0, 0.0), Vector3(0.0, 18.0, 0.0))
	_add_animation_track(library.get_animation("search_default"), "候选NPC身体:rotation_degrees", Vector3.ZERO, Vector3(0.0, 0.0, -3.0))
	_add_animation_track(library.get_animation("alert_default"), "候选NPC头部:rotation_degrees", Vector3(0.0, 0.0, 0.0), Vector3(-8.0, 0.0, 0.0))
	_add_animation_track(library.get_animation("alert_default"), "候选NPC上臂-左:rotation_degrees", Vector3(0.0, 0.0, -10.0), Vector3(-8.0, 0.0, -18.0))
	_add_animation_track(library.get_animation("alert_default"), "候选NPC上臂-右:rotation_degrees", Vector3(0.0, 0.0, 10.0), Vector3(-8.0, 0.0, 18.0))
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

func _build_mount_points() -> void:
	var mounts := {
		"视线起点": Vector3(0.0, 0.72, -0.18),
		"搜索目标点": Vector3(0.0, 0.90, -0.32),
		"警觉标记点": Vector3(0.0, 1.02, -0.04),
		"脚底碰撞参考点": Vector3(0.0, -0.98, 0.0)
	}
	for mount_name in mounts:
		var marker := Marker3D.new()
		marker.name = mount_name
		marker.position = mounts[mount_name]
		add_child(marker)

func drive_candidate_state(state_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)

func _add_animation_track(animation: Animation, property_path: String, first_value: Vector3, second_value: Vector3) -> void:
	if animation == null:
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(property_path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, first_value)
	animation.track_insert_key(track, 0.5, second_value)
	animation.track_insert_key(track, 1.0, first_value)

func _material(color: Color, roughness: float = 0.70) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color, bevel: float) -> void:
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
	node.material_override = _material(color)
	add_child(node)

func _add_sphere(node_name: String, at: Vector3, radius: float, color: Color, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	add_child(node)

func _add_capsule(node_name: String, at: Vector3, radius: float, height: float, color: Color, rotation: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = _material(color)
	add_child(node)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color)
	add_child(node)

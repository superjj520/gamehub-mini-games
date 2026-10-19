extends Node3D

## P0 主角候选外观，仅用于资产替换链路测试，不代表最终发布资产。

var _animation_player: AnimationPlayer
var _state := "idle_default"

func _ready() -> void:
	_build_visual()
	_build_mount_points()
	_build_animation_library()

func _build_visual() -> void:
	var jacket := Color("30363b")
	var jacket_highlight := Color("4b5358")
	var skin := Color("b27d69")
	var hair := Color("24272a")
	var backpack := Color("20272b")
	var backpack_trim := Color("5f6a6f")
	var shirt := Color("e3ded2")
	var pants := Color("24282d")
	var sole := Color("101316")

	_add_box("候选主角身体", Vector3(0.58, 0.72, 0.36), Vector3(0.0, 1.10, 0.0), shirt, 0.11)
	_add_box("候选主角马甲前片", Vector3(0.42, 0.58, 0.07), Vector3(0.0, 1.12, -0.205), jacket, 0.045)
	_add_box("候选主角马甲后片", Vector3(0.44, 0.54, 0.06), Vector3(0.0, 1.12, 0.205), jacket, 0.04)
	_add_box("候选主角夹克下摆", Vector3(0.54, 0.18, 0.34), Vector3(0.0, 0.76, 0.0), jacket_highlight, 0.06)
	_add_box("候选主角衬衣", Vector3(0.24, 0.44, 0.05), Vector3(0.0, 1.15, -0.22), shirt, 0.02)
	_add_box("候选主角衬衣领口", Vector3(0.32, 0.08, 0.06), Vector3(0.0, 1.48, -0.215), shirt, 0.018)
	_add_box("候选主角腰带", Vector3(0.52, 0.075, 0.40), Vector3(0.0, 0.78, 0.0), jacket, 0.02)
	_add_box("候选主角背包", Vector3(0.36, 0.52, 0.12), Vector3(0.0, 1.13, 0.25), backpack, 0.08)
	_add_box("候选主角背包翻盖", Vector3(0.32, 0.10, 0.14), Vector3(0.0, 1.40, 0.21), backpack_trim, 0.04)
	_add_box("候选主角背包底部", Vector3(0.30, 0.07, 0.14), Vector3(0.0, 0.88, 0.22), backpack_trim, 0.025)
	_add_box("候选主角背包肩带-左", Vector3(0.055, 0.48, 0.035), Vector3(-0.20, 1.18, 0.20), backpack_trim, 0.012)
	_add_box("候选主角背包肩带-右", Vector3(0.055, 0.48, 0.035), Vector3(0.20, 1.18, 0.20), backpack_trim, 0.012)
	_add_cylinder("候选主角颈部", Vector3(0.0, 1.56, 0.0), 0.10, 0.15, skin)
	_add_sphere("候选主角头部", Vector3(0.0, 1.76, 0.0), 0.205, skin, Vector3(0.92, 1.0, 0.88))
	_add_sphere("候选主角头发", Vector3(0.0, 1.91, 0.0), 0.215, hair, Vector3(1.0, 0.38, 0.94))
	_add_sphere("候选主角耳朵-左", Vector3(-0.195, 1.76, 0.0), 0.048, skin, Vector3(1.0, 1.0, 0.72))
	_add_sphere("候选主角耳朵-右", Vector3(0.195, 1.76, 0.0), 0.048, skin, Vector3(1.0, 1.0, 0.72))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_add_capsule("候选主角上臂" + suffix, Vector3(side * 0.37, 1.00, 0.0), 0.075, 0.36, jacket, Vector3(0.0, 0.0, side * -10.0))
		_add_capsule("候选主角前臂" + suffix, Vector3(side * 0.49, 0.84, -0.015), 0.065, 0.30, jacket_highlight, Vector3(0.0, 0.0, side * -24.0))
		_add_sphere("候选主角手部" + suffix, Vector3(side * 0.59, 0.70, -0.03), 0.085, skin, Vector3(1.0, 0.86, 0.9))
		_add_capsule("候选主角腿部" + suffix, Vector3(side * 0.15, 0.46, 0.0), 0.10, 0.62, pants, Vector3.ZERO)
		_add_box("候选主角鞋子" + suffix, Vector3(0.22, 0.13, 0.36), Vector3(side * 0.15, 0.11, -0.08), sole, 0.05)
		_add_box("候选主角鞋底" + suffix, Vector3(0.24, 0.04, 0.38), Vector3(side * 0.15, 0.035, -0.08), Color("333b43"), 0.015)
	_add_box("候选主角工牌", Vector3(0.10, 0.14, 0.025), Vector3(0.0, 1.28, -0.255), Color("d8b66a"), 0.01)
	_add_box("候选主角工牌挂绳", Vector3(0.025, 0.20, 0.02), Vector3(0.0, 1.42, -0.245), Color("5a6672"), 0.006)
	_add_sphere("候选主角鼻梁", Vector3(0.0, 1.76, -0.218), 0.035, skin, Vector3(0.72, 0.8, 1.2))
	_add_sphere("候选主角眼睛-左", Vector3(-0.078, 1.80, -0.202), 0.018, Color("14191e"), Vector3(1.0, 0.75, 0.55))
	_add_sphere("候选主角眼睛-右", Vector3(0.078, 1.80, -0.202), 0.018, Color("14191e"), Vector3(1.0, 0.75, 0.55))

func _build_mount_points() -> void:
	var mounts := {
		"交互手部挂点": Vector3(0.0, 0.78, -0.28),
		"载具挂点": Vector3(0.0, 0.92, 0.30),
		"视线起点": Vector3(0.0, 1.78, -0.12),
		"脚底碰撞参考点": Vector3(0.0, 0.04, 0.0)
	}
	for mount_name in mounts:
		var marker := Marker3D.new()
		marker.name = mount_name
		marker.position = mounts[mount_name]
		add_child(marker)

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ["idle_default", "walk_default", "crouch_default", "interact_default", "vehicle_default", "hit_default", "fail_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if animation_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		library.add_animation(animation_name, animation)
	_add_animation_track(library.get_animation("idle_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 1.0, 0.0))
	_add_animation_track(library.get_animation("walk_default"), "候选主角上臂-左:rotation_degrees", Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, 18.0))
	_add_animation_track(library.get_animation("walk_default"), "候选主角上臂-右:rotation_degrees", Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -18.0))
	_add_animation_track(library.get_animation("interact_default"), "候选主角前臂-右:rotation_degrees", Vector3(0.0, 0.0, -24.0), Vector3(-28.0, 0.0, -6.0))
	_add_animation_track(library.get_animation("vehicle_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 8.0, 0.0))
	_add_animation_track(library.get_animation("hit_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, -12.0, 0.0))
	_add_animation_track(library.get_animation("crouch_default"), "候选主角身体:position", Vector3(0.0, 1.10, 0.0), Vector3(0.0, 0.92, 0.0))
	_add_animation_track(library.get_animation("fail_default"), "候选主角身体:rotation_degrees", Vector3.ZERO, Vector3(0.0, 0.0, -12.0))
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

func drive_candidate_state(state_name: String) -> void:
	_state = state_name
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
	_apply_state_pose()

func _apply_state_pose() -> void:
	var body := get_node_or_null("候选主角身体") as Node3D
	if body == null:
		return
	body.position.y = -0.75 if _state == "vehicle_default" else (0.92 if _state == "crouch_default" else 1.10)
	body.position.z = -0.65 if _state == "vehicle_default" else 0.0

func _add_animation_track(animation: Animation, property_path: String, first_value: Vector3, second_value: Vector3) -> void:
	if animation == null:
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(property_path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, first_value)
	animation.track_insert_key(track, 0.5, second_value)
	animation.track_insert_key(track, 1.0, first_value)

func _material(color: Color, roughness: float = 0.68) -> StandardMaterial3D:
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

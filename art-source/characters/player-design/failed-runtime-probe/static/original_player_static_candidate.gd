extends Node3D

## MakeHuman 静态人物候选：验证无蒙皮写实网格能否进入运行时。
## 只提供固定镜头外观和根节点状态，不宣称动画或视觉通过。

const STATES := ["idle_default", "walk_default", "crouch_default", "interact_default", "vehicle_default", "hit_default", "fail_default"]
var _animation_player: AnimationPlayer
var _state := "idle_default"

func _ready() -> void:
	set_meta("original_candidate_asset", true)
	set_meta("asset_source", "MakeHuman_CC0_static_suit_visual_probe")
	set_meta("visual_status", "candidate_only")
	var character := get_node_or_null("候选主角身体") as Node3D
	if character == null:
		push_error("静态人物候选缺少候选主角身体")
		return
	_style_meshes(character)
	_build_backpack_and_jacket_layers()
	_build_mount_points()
	_build_animation_library()

func drive_candidate_state(state_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
	_state = state_name
	_apply_pose()

func _style_meshes(character: Node3D) -> void:
	# 静态探针保留嵌入纹理，只对粗糙度做轻微统一，不覆盖原始服装纹理。
	for item in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		for surface_index in range(mesh.get_surface_override_material_count()):
			mesh.set_surface_override_material(surface_index, null)

func _build_backpack_and_jacket_layers() -> void:
	var jacket := _material(Color("242d33"), 0.80)
	var trim := _material(Color("5b6469"), 0.66)
	var red := _material(Color("743b3b"), 0.80)
	_add_box("候选静态背包", Vector3(0.42, 0.54, 0.15), Vector3(0.0, 1.04, 0.27), jacket, 0.06)
	_add_box("候选静态背包翻盖", Vector3(0.34, 0.09, 0.18), Vector3(0.0, 1.35, 0.23), trim, 0.03)
	_add_box("候选静态夹克肩线左", Vector3(0.20, 0.10, 0.10), Vector3(-0.25, 1.41, 0.02), jacket, 0.02)
	_add_box("候选静态夹克肩线右", Vector3(0.20, 0.10, 0.10), Vector3(0.25, 1.41, 0.02), jacket, 0.02)
	_add_box("候选静态红色内层", Vector3(0.16, 0.14, 0.04), Vector3(0.0, 1.45, -0.22), red, 0.01)
	_add_box("候选静态工牌", Vector3(0.08, 0.10, 0.025), Vector3(-0.12, 1.25, -0.22), trim, 0.006)

func _build_mount_points() -> void:
	for item in {"交互手部挂点": Vector3(0.0, 0.86, -0.30), "载具挂点": Vector3(0.0, 0.86, 0.30), "视线起点": Vector3(0.0, 1.60, -0.10)}:
		var marker := Marker3D.new()
		marker.name = item
		marker.position = {"交互手部挂点": Vector3(0.0, 0.86, -0.30), "载具挂点": Vector3(0.0, 0.86, 0.30), "视线起点": Vector3(0.0, 1.60, -0.10)}[item]
		add_child(marker)

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for state_name in STATES:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if state_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		library.add_animation(state_name, animation)
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

func _apply_pose() -> void:
	var body := get_node_or_null("候选主角身体") as Node3D
	if body == null:
		return
	body.position.y = -0.60 if _state == "vehicle_default" else (-0.16 if _state == "crouch_default" else 0.0)
	body.position.z = -0.45 if _state == "vehicle_default" else 0.0
	body.rotation_degrees.x = -8.0 if _state in ["crouch_default", "vehicle_default"] else 0.0

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
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

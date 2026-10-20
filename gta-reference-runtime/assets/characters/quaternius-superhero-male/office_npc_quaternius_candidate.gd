extends Node3D

## P0 办公室 NPC 候选：复用已核对的 CC0 骨骼，使用原创制服覆盖和状态姿态。

const ANIMATION_NAMES := ["idle_default", "walk_default", "search_default", "alert_default"]
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _base_rotations: Dictionary = {}
var _phase := 0.0

func _ready() -> void:
	_skeleton = get_node_or_null("Character/Armature/Skeleton3D") as Skeleton3D
	_style_imported_meshes()
	_build_uniform()
	_build_animation_library()
	_cache_bone_rotations()

func _process(delta: float) -> void:
	_phase += delta
	_apply_pose()

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ANIMATION_NAMES:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(animation_name, animation)
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

func _cache_bone_rotations() -> void:
	if _skeleton == null:
		return
	for bone_index in range(_skeleton.get_bone_count()):
		_base_rotations[bone_index] = _skeleton.get_bone_pose_rotation(bone_index)

func _apply_pose() -> void:
	if _skeleton == null:
		return
	for bone_index in _base_rotations:
		_skeleton.set_bone_pose_rotation(int(bone_index), _base_rotations[bone_index])
	var state: String = _animation_player.current_animation if _animation_player != null else "idle_default"
	var walk_amount: float = sin(_phase * 5.0) if state == "walk_default" else 0.0
	_apply_bone_rotation("upperarm_l", Vector3(0.0, 0.0, -1.12 + walk_amount * 0.12))
	_apply_bone_rotation("upperarm_r", Vector3(0.0, 0.0, 1.12 - walk_amount * 0.12))
	_apply_bone_rotation("lowerarm_l", Vector3(0.0, 0.0, -0.10))
	_apply_bone_rotation("lowerarm_r", Vector3(0.0, 0.0, 0.10))
	if state == "search_default":
		_apply_bone_rotation("spine_02", Vector3(-0.10, 0.0, 0.0))
		_apply_bone_rotation("head", Vector3(0.08, 0.12, 0.0))
	if state == "alert_default":
		_apply_bone_rotation("spine_02", Vector3(-0.20, 0.0, 0.0))
		_apply_bone_rotation("head", Vector3(-0.05, 0.0, 0.0))

func _apply_bone_rotation(bone_name: String, euler_rotation: Vector3) -> void:
	if _skeleton == null:
		return
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index < 0 or not _base_rotations.has(bone_index):
		return
	_skeleton.set_bone_pose_rotation(bone_index, _base_rotations[bone_index] * Quaternion.from_euler(euler_rotation))

func drive_candidate_state(state_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)

func _style_imported_meshes() -> void:
	var body := get_node_or_null("Character/Armature/Skeleton3D/SuperHero_Male") as MeshInstance3D
	if body != null:
		body.material_override = _material(Color("b9856d"), 0.68, 0.0)
	var eyes := get_node_or_null("Character/Armature/Skeleton3D/Eyes") as MeshInstance3D
	if eyes != null:
		eyes.material_override = _material(Color("202832"), 0.30, 0.05)
	var eyebrows := get_node_or_null("Character/Armature/Skeleton3D/Eyebrows") as MeshInstance3D
	if eyebrows != null:
		eyebrows.material_override = _material(Color("1b2027"), 0.76, 0.0)

func _build_uniform() -> void:
	if get_node_or_null("Character/Armature/Skeleton3D/Outfit_Torso") != null:
		return
	var uniform := _material(Color("56687a"), 0.62, 0.02)
	var trim := _material(Color("c6a15b"), 0.38, 0.16)
	var shirt := _material(Color("d2d9d6"), 0.72, 0.0)
	var trousers := _material(Color("252c38"), 0.76, 0.02)
	var shoes := _material(Color("111820"), 0.62, 0.12)
	var hair := _material(Color("20252b"), 0.82, 0.0)
	_add_box("候选NPC身体", Vector3(0.62, 0.74, 0.50), Vector3(0.0, 1.08, 0.0), uniform, 0.06)
	_add_box("候选NPC制服肩部", Vector3(0.60, 0.34, 0.48), Vector3(0.0, 1.50, 0.0), uniform, 0.05)
	_add_box("候选NPC衬衣前襟", Vector3(0.32, 0.40, 0.035), Vector3(0.0, 1.12, -0.315), shirt, 0.018)
	_add_box("候选NPC衬衣领口", Vector3(0.20, 0.08, 0.045), Vector3(0.0, 1.34, -0.32), shirt, 0.012)
	_add_box("候选NPC制服下摆", Vector3(0.56, 0.17, 0.26), Vector3(0.0, 0.81, -0.02), trim, 0.04)
	_add_box("候选NPC制服腰带", Vector3(0.52, 0.07, 0.30), Vector3(0.0, 0.92, -0.23), uniform, 0.018)
	_add_capsule("候选NPC左袖", Vector3(-0.40, 0.96, -0.01), 0.14, 0.66, uniform)
	_add_capsule("候选NPC右袖", Vector3(0.40, 0.96, -0.01), 0.14, 0.66, uniform)
	_add_box("候选NPC胸牌", Vector3(0.12, 0.13, 0.035), Vector3(0.18, 1.18, -0.27), trim, 0.012)
	_add_capsule("候选NPC左裤腿", Vector3(-0.15, 0.46, 0.0), 0.13, 0.62, trousers)
	_add_capsule("候选NPC右裤腿", Vector3(0.15, 0.46, 0.0), 0.13, 0.62, trousers)
	_add_box("候选NPC左鞋", Vector3(0.24, 0.14, 0.40), Vector3(-0.15, 0.09, -0.08), shoes, 0.04)
	_add_box("候选NPC右鞋", Vector3(0.24, 0.14, 0.40), Vector3(0.15, 0.09, -0.08), shoes, 0.04)
	var hair_cap := MeshInstance3D.new()
	hair_cap.name = "候选NPC短发"
	var hair_mesh := CapsuleMesh.new()
	hair_mesh.radius = 0.22
	hair_mesh.height = 0.34
	hair_cap.mesh = hair_mesh
	hair_cap.scale = Vector3(1.04, 0.62, 1.04)
	hair_cap.position = Vector3(0.0, 1.82, 0.0)
	hair_cap.material_override = hair
	add_child(hair_cap)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
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

func _add_capsule(node_name: String, at: Vector3, radius: float, height: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)

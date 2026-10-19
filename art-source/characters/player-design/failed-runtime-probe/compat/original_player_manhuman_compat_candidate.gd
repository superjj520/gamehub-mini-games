extends Node3D

## MakeHuman 清洗版兼容候选：只验证真实人体网格、材质覆盖和状态驱动。
## 未完成可见窗口验收前，不接入正式 player-character 槽位。

const STATES := ["idle_default", "walk_default", "crouch_default", "interact_default", "vehicle_default", "hit_default", "fail_default"]
var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _state := "idle_default"
var _base_rotations: Dictionary = {}

func _ready() -> void:
	set_meta("original_candidate_asset", true)
	set_meta("asset_source", "MakeHuman_CC0_sanitized_import_compatibility_probe")
	set_meta("visual_status", "candidate_only")
	var character := get_node_or_null("候选主角身体") as Node3D
	if character == null:
		push_error("兼容候选缺少候选主角身体")
		return
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	_style_meshes(character)
	_build_mount_points()
	_build_animation_library()
	_cache_bones()

func drive_candidate_state(state_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
	_state = state_name
	_apply_pose()

func _style_meshes(character: Node3D) -> void:
	var skin := _material(Color("9c6a54"), 0.72)
	var hair := _material(Color("171c22"), 0.48)
	var jacket := _material(Color("30383f"), 0.82)
	var pants := _material(Color("1c2329"), 0.88)
	var shoes := _material(Color("11161b"), 0.62)
	for item in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		var mesh_name := mesh.name.to_lower()
		if mesh_name.contains("worksuit") or mesh_name.contains("elegantsuit"):
			mesh.material_override = jacket
		elif mesh_name.contains("shoes"):
			mesh.material_override = shoes
		elif mesh_name.contains("short") or mesh_name.contains("hair") or mesh_name.contains("eyebrow"):
			mesh.material_override = hair
		elif mesh_name.contains("body") or mesh_name.contains("low-poly") or mesh_name.contains("eyelash"):
			mesh.material_override = skin
		else:
			mesh.material_override = pants

func _build_mount_points() -> void:
	for item in {"交互手部挂点": Vector3(0.0, 0.92, -0.30), "载具挂点": Vector3(0.0, 0.86, 0.30), "视线起点": Vector3(0.0, 1.55, -0.10)}:
		var marker := Marker3D.new()
		marker.name = item
		marker.position = {"交互手部挂点": Vector3(0.0, 0.92, -0.30), "载具挂点": Vector3(0.0, 0.86, 0.30), "视线起点": Vector3(0.0, 1.55, -0.10)}[item]
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

func _cache_bones() -> void:
	if _skeleton == null:
		return
	for bone_index in range(_skeleton.get_bone_count()):
		_base_rotations[bone_index] = _skeleton.get_bone_pose_rotation(bone_index)

func _apply_pose() -> void:
	var body := get_node_or_null("候选主角身体") as Node3D
	if body != null:
		body.position.y = -0.70 if _state == "vehicle_default" else (-0.24 if _state == "crouch_default" else 0.0)
		body.position.z = -0.58 if _state == "vehicle_default" else 0.0
	if _skeleton == null:
		return
	for bone_index in _base_rotations:
		_skeleton.set_bone_pose_rotation(int(bone_index), _base_rotations[bone_index])
	if _state == "crouch_default":
		_apply_bone("spine_02", Vector3(0.30, 0.0, 0.0))
		_apply_bone("spine_03", Vector3(0.14, 0.0, 0.0))
		_apply_bone("thigh_l", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("calf_l", Vector3(1.04, 0.0, 0.0))
		_apply_bone("calf_r", Vector3(1.04, 0.0, 0.0))
	elif _state == "vehicle_default":
		_apply_bone("spine_02", Vector3(0.24, 0.0, 0.0))
		_apply_bone("spine_03", Vector3(0.10, 0.0, 0.0))
		_apply_bone("upperarm_l", Vector3(-1.20, 0.0, -2.20))
		_apply_bone("upperarm_r", Vector3(-1.20, 0.0, 2.20))
		_apply_bone("thigh_l", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("calf_l", Vector3(1.04, 0.0, 0.0))
		_apply_bone("calf_r", Vector3(1.04, 0.0, 0.0))

func _apply_bone(bone_name: String, euler_rotation: Vector3) -> void:
	if _skeleton == null:
		return
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index >= 0 and _base_rotations.has(bone_index):
		_skeleton.set_bone_pose_rotation(bone_index, _base_rotations[bone_index] * Quaternion.from_euler(euler_rotation))

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

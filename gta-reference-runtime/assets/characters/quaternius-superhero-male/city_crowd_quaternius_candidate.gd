extends Node3D

## 城市人群内部候选：只提供外观和姿态，不承担碰撞、路线或任务逻辑。

const STATES := ["idle_default", "walk_default", "displaced_default", "hit_default"]
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _base_rotations: Dictionary = {}
var _phase := 0.0
var _state := "idle_default"

func _ready() -> void:
	_skeleton = get_node_or_null("Character/Armature/Skeleton3D") as Skeleton3D
	_style_character()
	_cache_bones()
	_build_animation_library()

func _process(delta: float) -> void:
	_phase += delta
	_apply_pose()

func drive_candidate_state(state_name: String) -> void:
	if _animation_player == null:
		return
	_state = state_name if state_name in STATES else "idle_default"
	_animation_player.play(_state)

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
	_animation_player.play(_state)

func _cache_bones() -> void:
	if _skeleton == null:
		return
	for bone_index in range(_skeleton.get_bone_count()):
		_base_rotations[bone_index] = _skeleton.get_bone_pose_rotation(bone_index)

func _apply_pose() -> void:
	if _skeleton == null:
		return
	for bone_index in _base_rotations:
		_skeleton.set_bone_pose_rotation(int(bone_index), _base_rotations[bone_index])
	var walk_wave := sin(_phase * 5.4)
	_apply_bone("upperarm_l", Vector3(0.0, 0.0, -1.30 + (0.16 * walk_wave if _state == "walk_default" else 0.0)))
	_apply_bone("upperarm_r", Vector3(0.0, 0.0, 1.30 - (0.16 * walk_wave if _state == "walk_default" else 0.0)))
	if _state == "walk_default":
		_apply_bone("thigh_l", Vector3(0.20 * walk_wave, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.20 * walk_wave, 0.0, 0.0))
	elif _state == "displaced_default":
		_apply_bone("spine_02", Vector3(-0.16, 0.0, 0.12))
		_apply_bone("head", Vector3(0.0, 0.0, -0.10))
	elif _state == "hit_default":
		_apply_bone("spine_02", Vector3(0.20, 0.0, 0.0))
		_apply_bone("head", Vector3(-0.12, 0.0, 0.0))

func _apply_bone(bone_name: String, euler_rotation: Vector3) -> void:
	if _skeleton == null:
		return
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index >= 0 and _base_rotations.has(bone_index):
		_skeleton.set_bone_pose_rotation(bone_index, _base_rotations[bone_index] * Quaternion.from_euler(euler_rotation))

func _style_character() -> void:
	var body := get_node_or_null("Character/Armature/Skeleton3D/SuperHero_Male") as MeshInstance3D
	if body != null:
		body.material_override = _material(Color("657586"), 0.70, 0.0)
	var eyes := get_node_or_null("Character/Armature/Skeleton3D/Eyes") as MeshInstance3D
	if eyes != null:
		eyes.material_override = _material(Color("202832"), 0.30, 0.05)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

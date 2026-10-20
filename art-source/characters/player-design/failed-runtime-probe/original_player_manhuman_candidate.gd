extends Node3D

## MakeHuman 玩家视觉候选：只替换隔离运行时的玩家外观，不接管移动、碰撞、镜头或存档。

const ANIMATION_NAMES := [
	"idle_default",
	"walk_default",
	"crouch_default",
	"interact_default",
	"vehicle_default",
	"hit_default",
	"fail_default",
]

var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _base_rotations: Dictionary = {}
var _state := "idle_default"
var _phase := 0.0

func _ready() -> void:
	set_meta("original_candidate_asset", true)
	set_meta("asset_source", "MakeHuman_CC0_candidate_with_original_gameplay_wrapper")
	set_meta("visual_status", "candidate_only")
	set_meta("reference_board", "art-source/characters/player-design/new-era-awakener-player-turnaround-v1-generated.png")
	var character := get_node_or_null("候选主角身体") as Node3D
	if character == null:
		push_error("MakeHuman 玩家候选缺少候选主角身体")
		return
	var skeleton_nodes := character.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeleton_nodes[0] as Skeleton3D if not skeleton_nodes.is_empty() else null
	_style_meshes(character)
	_build_backpack_contract()
	_build_reference_shirt_layers()
	_build_reference_outer_layers()
	_build_animation_library()
	_cache_bone_rotations()

func _process(delta: float) -> void:
	_phase += delta
	if _animation_player != null and not _animation_player.current_animation.is_empty():
		_state = _animation_player.current_animation
	_apply_pose()

func drive_candidate_state(state_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
		_state = state_name
		_apply_pose()

func _style_meshes(character: Node3D) -> void:
	for item in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		var mesh_name := mesh.name.to_lower()
		if mesh_name.contains("shoes"):
			mesh.material_override = _material(Color("151c21"), 0.66, 0.04)
		elif mesh_name.contains("elegantsuit") or mesh_name.contains("male_elegantsuit"):
			# 参考办公室帧需要保留浅色衬衣、深色裤装和领带的分区纹理；
			# 不再用单一灰色覆盖整个蒙皮网格，否则会把衬衣和裤装压成一块暗色。
			mesh.material_override = null
		elif mesh_name.contains("male_worksuit") or mesh_name.contains("worksuit"):
			mesh.visible = false

func _build_backpack_contract() -> void:
	# 保留旧候选契约节点，便于行为回放确认背包挂载仍存在；真实网格挂在 spine_02 上。
	var contract_marker := Node3D.new()
	contract_marker.name = "候选主角背包"
	contract_marker.set_meta("attachment_bone", "spine_02")
	add_child(contract_marker)
	if _skeleton == null or _skeleton.find_bone("spine_02") < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "MakeHuman 玩家背包骨骼挂点"
	attachment.bone_name = "spine_02"
	_skeleton.add_child(attachment)
	# 参考帧中的背包应是中等尺寸的背部轮廓，不能吞掉肩膀和腰线。
	attachment.scale = Vector3(0.48, 0.52, 0.48)
	_add_box(attachment, "MakeHuman 玩家背包主体", Vector3(0.31, 0.43, 0.14), Vector3(0.0, 0.04, -0.18), _material(Color("121b1e"), 0.84, 0.02), 0.045)
	_add_box(attachment, "MakeHuman 玩家背包翻盖", Vector3(0.27, 0.08, 0.15), Vector3(0.0, 0.28, -0.16), _material(Color("284044"), 0.74, 0.02), 0.025)
	_add_box(attachment, "MakeHuman 玩家背包前袋", Vector3(0.20, 0.10, 0.032), Vector3(0.0, -0.035, -0.25), _material(Color("315b62"), 0.66, 0.02), 0.009)
	_add_box(attachment, "MakeHuman 玩家背包反光条", Vector3(0.17, 0.024, 0.016), Vector3(0.0, 0.05, -0.275), _material(Color("a9b39c"), 0.52, 0.02), 0.003)
	_add_box(attachment, "MakeHuman 玩家背包肩带左", Vector3(0.044, 0.39, 0.028), Vector3(-0.155, 0.065, -0.135), _material(Color("1d3033"), 0.80, 0.02), 0.008)
	_add_box(attachment, "MakeHuman 玩家背包肩带右", Vector3(0.044, 0.39, 0.028), Vector3(0.155, 0.065, -0.135), _material(Color("1d3033"), 0.80, 0.02), 0.008)

func _build_reference_shirt_layers() -> void:
	# 参考视频中的主角有可辨识的浅色衬衣与胸前细节；这些节点只附着在骨骼上，不参与碰撞和任务逻辑。
	if _skeleton == null:
		return
	var chest_bone := "spine_03" if _skeleton.find_bone("spine_03") >= 0 else "spine_02"
	var attachment := BoneAttachment3D.new()
	attachment.name = "MakeHuman 玩家衬衣骨骼挂点"
	attachment.bone_name = chest_bone
	_skeleton.add_child(attachment)
	var shirt := _material(Color("c8d0ce"), 0.86, 0.0)
	var shirt_edge := _material(Color("aeb9b7"), 0.78, 0.0)
	var tie := _material(Color("243239"), 0.70, 0.02)
	var badge := _material(Color("d7b76c"), 0.46, 0.04)
	_add_box(attachment, "MakeHuman 玩家衬衣前片", Vector3(0.30, 0.28, 0.035), Vector3(0.0, 0.03, 0.19), shirt, 0.015)
	_add_box(attachment, "MakeHuman 玩家衬衣左领", Vector3(0.10, 0.055, 0.045), Vector3(-0.075, 0.20, 0.205), shirt_edge, 0.008)
	_add_box(attachment, "MakeHuman 玩家衬衣右领", Vector3(0.10, 0.055, 0.045), Vector3(0.075, 0.20, 0.205), shirt_edge, 0.008)
	_add_box(attachment, "MakeHuman 玩家领带", Vector3(0.035, 0.16, 0.028), Vector3(0.0, 0.08, 0.218), tie, 0.006)
	_add_box(attachment, "MakeHuman 玩家工牌", Vector3(0.075, 0.07, 0.018), Vector3(-0.12, 0.03, 0.221), badge, 0.004)

func _build_reference_outer_layers() -> void:
	# 在写实基础人物上补足参考板可辨识的连帽夹克肩线和袖袋；
	# 这些节点附着在胸骨，不进入碰撞，也不改变玩家控制器。
	if _skeleton == null:
		return
	var chest_bone := "spine_02" if _skeleton.find_bone("spine_02") >= 0 else "spine_03"
	var attachment := BoneAttachment3D.new()
	attachment.name = "MakeHuman 玩家连帽夹克骨骼挂点"
	attachment.bone_name = chest_bone
	_skeleton.add_child(attachment)
	var jacket := _material(Color("222b31"), 0.82, 0.01)
	var edge := _material(Color("4d5a60"), 0.68, 0.02)
	var red := _material(Color("743a38"), 0.80, 0.0)
	_add_box(attachment, "MakeHuman 玩家夹克肩线左", Vector3(0.25, 0.09, 0.08), Vector3(-0.25, 0.21, 0.02), jacket, 0.025)
	_add_box(attachment, "MakeHuman 玩家夹克肩线右", Vector3(0.25, 0.09, 0.08), Vector3(0.25, 0.21, 0.02), jacket, 0.025)
	_add_box(attachment, "MakeHuman 玩家夹克胸前左片", Vector3(0.06, 0.28, 0.04), Vector3(-0.21, 0.04, 0.205), edge, 0.012)
	_add_box(attachment, "MakeHuman 玩家夹克胸前右片", Vector3(0.06, 0.28, 0.04), Vector3(0.21, 0.04, 0.205), edge, 0.012)
	_add_box(attachment, "MakeHuman 玩家红色内层露口", Vector3(0.16, 0.12, 0.045), Vector3(0.0, 0.22, 0.205), red, 0.012)
	_add_box(attachment, "MakeHuman 玩家夹克兜帽后沿", Vector3(0.42, 0.08, 0.10), Vector3(0.0, 0.31, -0.07), jacket, 0.025)

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
	var backpack_mount := find_child("MakeHuman 玩家背包骨骼挂点", true, false) as Node3D
	if backpack_mount != null:
		# 参考视频中的驾驶员没有巨型背包遮住躯干；保留背包挂点契约，但在驾驶状态隐藏表现层。
		backpack_mount.visible = _state != "vehicle_default"
	var body := get_node_or_null("候选主角身体") as Node3D
	if body != null:
		# MakeHuman 蒙皮原点高于旧角色挂点；载具状态需落到正式驾驶座下方，避免站在顶篷上。
		body.position.y = -0.75 if _state == "vehicle_default" else (-0.30 if _state == "crouch_default" else 0.0)
		body.position.z = -0.65 if _state == "vehicle_default" else 0.0
	for bone_index in _base_rotations:
		_skeleton.set_bone_pose_rotation(int(bone_index), _base_rotations[bone_index])
	var walk_wave := sin(_phase * 6.5)
	# MakeHuman 导入姿态的手臂基线接近张臂，必须先收回到自然垂落，再叠加状态动作。
	var arm_wave := 0.12 * walk_wave if _state in ["walk_default", "vehicle_default"] else 0.0
	_apply_bone("upperarm_l", Vector3(0.0, 0.0, -1.48 - arm_wave))
	_apply_bone("upperarm_r", Vector3(0.0, 0.0, 1.48 + arm_wave))
	_apply_bone("lowerarm_l", Vector3(0.0, 0.0, -0.26))
	_apply_bone("lowerarm_r", Vector3(0.0, 0.0, 0.26))
	if _state == "walk_default":
		_apply_bone("upperarm_l", Vector3(0.0, 0.0, -1.48 - arm_wave))
		_apply_bone("upperarm_r", Vector3(0.0, 0.0, 1.48 + arm_wave))
		_apply_bone("thigh_l", Vector3(0.24 * walk_wave, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.24 * walk_wave, 0.0, 0.0))
	elif _state == "vehicle_default":
		_apply_bone("spine_02", Vector3(0.24, 0.0, 0.0))
		_apply_bone("spine_03", Vector3(0.10, 0.0, 0.0))
		_apply_bone("upperarm_l", Vector3(-1.20, 0.0, -2.20))
		_apply_bone("upperarm_r", Vector3(-1.20, 0.0, 2.20))
		_apply_bone("lowerarm_l", Vector3(-0.65, 0.0, -0.26))
		_apply_bone("lowerarm_r", Vector3(-0.65, 0.0, 0.26))
		_apply_bone("thigh_l", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("calf_l", Vector3(1.04, 0.0, 0.0))
		_apply_bone("calf_r", Vector3(1.04, 0.0, 0.0))
	elif _state == "crouch_default":
		_apply_bone("spine_02", Vector3(0.30, 0.0, 0.0))
		_apply_bone("spine_03", Vector3(0.14, 0.0, 0.0))
		_apply_bone("thigh_l", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.78, 0.0, 0.0))
		_apply_bone("calf_l", Vector3(1.04, 0.0, 0.0))
		_apply_bone("calf_r", Vector3(1.04, 0.0, 0.0))
	elif _state == "interact_default":
		_apply_bone("upperarm_l", Vector3(-0.42, 0.0, -0.20))
		_apply_bone("upperarm_r", Vector3(-0.42, 0.0, 0.20))
	elif _state == "hit_default":
		_apply_bone("spine_02", Vector3(-0.18, 0.0, 0.0))
	elif _state == "fail_default":
		_apply_bone("spine_02", Vector3(0.38, 0.0, 0.0))
		_apply_bone("head", Vector3(0.18, 0.0, 0.0))

func _apply_bone(bone_name: String, euler_rotation: Vector3) -> void:
	if _skeleton == null:
		return
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index < 0 or not _base_rotations.has(bone_index):
		return
	_skeleton.set_bone_pose_rotation(bone_index, _base_rotations[bone_index] * Quaternion.from_euler(euler_rotation))

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float) -> void:
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
	parent.add_child(node)

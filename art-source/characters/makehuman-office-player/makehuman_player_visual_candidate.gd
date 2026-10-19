extends Node3D

## MakeHuman 玩家视觉候选：只替换隔离运行时的玩家外观，不接管移动、碰撞、镜头或存档。

const ANIMATION_NAMES := [
	"idle_default",
	"walk_default",
	"crouch_default",
	"interact_default",
	"typing_default",
	"vehicle_default",
	"hit_default",
	"fail_default",
]

var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _base_rotations: Dictionary = {}
var _state := "idle_default"
var _candidate_context := "office"
var _phase := 0.0
var _ground_contact_shadows: Array[MeshInstance3D] = []

func _ready() -> void:
	var character := get_node_or_null("候选主角身体") as Node3D
	if character == null:
		push_error("MakeHuman 玩家候选缺少候选主角身体")
		return
	var skeleton_nodes := character.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeleton_nodes[0] as Skeleton3D if not skeleton_nodes.is_empty() else null
	_style_meshes(character)
	if _candidate_context == "city":
		_apply_city_outerwear_context(character)
	_build_backpack_contract()
	_build_reference_shirt_layers()
	_build_animation_library()
	_cache_bone_rotations()
	_build_typing_contact_contract()
	_build_ground_contact_shadows(character)

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

func set_candidate_context(context_name: String) -> void:
	_candidate_context = context_name.strip_edges().to_lower()
	var character := get_node_or_null("候选主角身体") as Node3D
	if character == null or _candidate_context != "city":
		return
	_apply_city_outerwear_context(character)

func _apply_city_outerwear_context(character: Node3D) -> void:
	# 城市参考帧的玩家识别色是砖红色外套；办公室仍保留浅衬衣/深色裤装。
	# 只给 MakeHuman 外套网格套一层按纹理明暗分离的材质，保留衬衣、领带、
	# 皮肤、头发和鞋子的原始纹理，不改变骨骼、碰撞、载具或任务状态。
	var jacket := character.find_child("Human_male_elegantsuit01_skinned_export", true, false) as MeshInstance3D
	if jacket == null or jacket.get_meta("city_outerwear_applied", false):
		return
	var source_material := jacket.get_active_material(0) as StandardMaterial3D
	if source_material == null or source_material.albedo_texture == null:
		return
	var shader := Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode cull_back, diffuse_burley, specular_schlick_ggx;
	uniform sampler2D base_texture : source_color;
	uniform vec4 jacket_tint : source_color = vec4(0.62, 0.10, 0.07, 1.0);

	void fragment() {
		vec4 texel = texture(base_texture, UV);
		float luminance = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
		float dark_fabric = 1.0 - smoothstep(0.18, 0.48, luminance);
		float upper_body_region = 1.0 - smoothstep(0.42, 0.56, UV.y);
		float jacket_mask = dark_fabric * upper_body_region;
		vec3 recolored = mix(texel.rgb, texel.rgb * jacket_tint.rgb * 1.75, jacket_mask * 0.82);
		ALBEDO = recolored;
		METALLIC = 0.02;
		ROUGHNESS = 0.68;
		ALPHA = texel.a;
	}
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_texture", source_material.albedo_texture)
	material.set_shader_parameter("jacket_tint", Color("a52f28"))
	jacket.material_override = material
	jacket.set_meta("city_outerwear_applied", true)
	jacket.set_meta("visual_only", true)

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
	# 参考首帧中的背包只占肩宽的一部分；收窄体积，避免把主角背部读成一整块箱体。
	attachment.scale = Vector3(0.38, 0.44, 0.38)
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

func _build_typing_contact_contract() -> void:
	if _skeleton == null:
		return
	# 这些是不可见的骨骼接触探针，只服务于候选层验收：
	# 让测试能够证明坐姿时臀部、左右手腕确实随蒙皮骨骼移动，
	# 而不是仅凭“typing_default”动画名称推断接触成立。
	var contacts := {
		"候选打字骨盆接触点": "pelvis",
		"候选打字左手接触点": "hand_l",
		"候选打字右手接触点": "hand_r",
	}
	for marker_name in contacts:
		var bone_name: String = contacts[marker_name]
		if _skeleton.find_bone(bone_name) < 0:
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = marker_name + "骨骼挂点"
		attachment.bone_name = bone_name
		var probe := Marker3D.new()
		probe.name = marker_name
		if marker_name == "候选打字骨盆接触点":
			# typing_default 已将表现层根节点下沉到候选椅面，骨盆骨骼中心
			# 可直接作为坐垫接触参考，不再额外伪造世界坐标偏移。
			probe.position = Vector3.ZERO
			probe.set_meta("contact_kind", "seat_surface_proxy")
		else:
			# 手腕骨骼在表现层根节点下沉后处于键盘高度；接触探针
			# 保持在骨骼中心，避免用固定世界偏移掩盖姿态错位。
			probe.position = Vector3.ZERO
			probe.set_meta("contact_kind", "keyboard_hand_proxy")
		probe.visible = false
		attachment.set_meta("candidate_contact_probe", true)
		probe.set_meta("candidate_contact_probe", true)
		attachment.add_child(probe)
		_skeleton.add_child(attachment)

func _apply_pose() -> void:
	if _skeleton == null:
		return
	var backpack_mount := find_child("MakeHuman 玩家背包骨骼挂点", true, false) as Node3D
	if backpack_mount != null:
		# 参考办公室帧的主角坐下后背部由椅背承担轮廓；隐藏背包，避免背包与椅背
		# 叠成一块黑色体积，遮住肩线、手臂和键盘接触关系。驾驶状态同样隐藏，
		# 但背包挂点和城市行走表现仍保留，不改变碰撞、交互或任务逻辑。
		backpack_mount.visible = _state not in ["vehicle_default", "typing_default"]
	var body := get_node_or_null("候选主角身体") as Node3D
	if body != null:
		# MakeHuman 蒙皮原点高于旧角色挂点；载具状态需落到正式驾驶座下方，避免站在顶篷上。
		# 真实骨骼人物的原点在脚底，旧程序化角色的蹲伏下沉量不能直接复用。
		# -0.30 会让 office-01 的头肩整体沉入工位隔断；这里仅收回表现层
		# 的额外下沉，保持碰撞体、玩家根节点和输入状态完全不变。
		# glTF 人物原点位于脚底；上一版 typing_default 下沉到 -1.45，
		# 使整个人物落到桌后隔断以下，截图中只剩办公室而没有主体。
		# 参考办公镜头里的观察姿态是轻微屈膝，不是整个人坐到地面；
		# 视觉层只做小幅下沉，保持脚底与桌边的接触关系可读。
		body.position.y = -0.75 if _state == "vehicle_default" else (-0.70 if _state == "typing_default" else (-0.18 if _state == "crouch_default" else 0.0))
		body.position.z = -0.65 if _state == "vehicle_default" else (-0.25 if _state == "typing_default" else (0.06 if _state == "crouch_default" else 0.0))
	_update_ground_contact_shadow_visibility()
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
	elif _state == "typing_default":
		# office-10 的候选坐姿：骨盆落到椅垫高度，脊柱向桌面前倾，
		# 大腿与小腿形成坐姿折线，前臂落向键盘。只改变蒙皮骨骼，
		# 不改变玩家根节点、碰撞体、交互挂点、任务或存档坐标。
		_apply_bone("spine_02", Vector3(0.30, 0.0, 0.0))
		_apply_bone("spine_03", Vector3(0.16, 0.0, 0.0))
		# 骨骼落点探针确认：旧组合让双手停在 y=1.03、z=0.28，
		# 视觉上像垂手而不是贴近键盘。新的上臂外展与前臂折线把
		# 双手推进到约 y=0.98、z=0.38，贴近原创工位键盘的前缘；
		# 仍只改蒙皮骨骼，不改玩家根节点、碰撞体或交互坐标。
		_apply_bone("upperarm_l", Vector3(-1.30, 0.0, -2.60))
		_apply_bone("upperarm_r", Vector3(-1.30, 0.0, 2.60))
		_apply_bone("lowerarm_l", Vector3(0.50, 0.0, -0.22))
		_apply_bone("lowerarm_r", Vector3(0.50, 0.0, 0.22))
		# MakeHuman 网格带有独立腕部和三节手指骨骼；只收前臂会形成
		# “伸手”而不是“打字”。这里把腕部压向桌面，并让指节形成
		# 轻微弧线，保持自然接触，不改变根节点、碰撞或交互逻辑。
		_apply_bone("hand_l", Vector3(0.18, 0.0, -0.12))
		_apply_bone("hand_r", Vector3(0.18, 0.0, 0.12))
		for finger_name in ["index", "middle", "ring", "pinky"]:
			_apply_bone(finger_name + "_01_l", Vector3(0.16, 0.0, -0.03))
			_apply_bone(finger_name + "_02_l", Vector3(0.22, 0.0, -0.02))
			_apply_bone(finger_name + "_03_l", Vector3(0.18, 0.0, -0.01))
			_apply_bone(finger_name + "_01_r", Vector3(0.16, 0.0, 0.03))
			_apply_bone(finger_name + "_02_r", Vector3(0.22, 0.0, 0.02))
			_apply_bone(finger_name + "_03_r", Vector3(0.18, 0.0, 0.01))
		_apply_bone("thumb_01_l", Vector3(0.12, 0.0, -0.04))
		_apply_bone("thumb_02_l", Vector3(0.16, 0.0, -0.03))
		_apply_bone("thumb_03_l", Vector3(0.12, 0.0, -0.02))
		_apply_bone("thumb_01_r", Vector3(0.12, 0.0, 0.04))
		_apply_bone("thumb_02_r", Vector3(0.16, 0.0, 0.03))
		_apply_bone("thumb_03_r", Vector3(0.12, 0.0, 0.02))
		_apply_bone("thigh_l", Vector3(-1.02, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-1.02, 0.0, 0.0))
		_apply_bone("calf_l", Vector3(1.20, 0.0, 0.0))
		_apply_bone("calf_r", Vector3(1.20, 0.0, 0.0))
		_apply_bone("head", Vector3(0.06, 0.0, 0.0))
	elif _state == "crouch_default":
		# MakeHuman 蒙皮的基础腿姿势已经带有轻微弯曲；叠加完整坐姿角度会
		# 让 office-01 变成漂浮的深蹲。这里收紧为参考视频里的观察屈膝。
		_apply_bone("spine_02", Vector3(0.22, 0.0, 0.0))
		_apply_bone("spine_03", Vector3(0.11, 0.0, 0.0))
		_apply_bone("thigh_l", Vector3(-0.52, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.52, 0.0, 0.0))
		_apply_bone("calf_l", Vector3(0.76, 0.0, 0.0))
		_apply_bone("calf_r", Vector3(0.76, 0.0, 0.0))
	elif _state == "interact_default":
		_apply_bone("upperarm_l", Vector3(-0.42, 0.0, -0.20))
		_apply_bone("upperarm_r", Vector3(-0.42, 0.0, 0.20))
	elif _state == "hit_default":
		_apply_bone("spine_02", Vector3(-0.18, 0.0, 0.0))
	elif _state == "fail_default":
		_apply_bone("spine_02", Vector3(0.38, 0.0, 0.0))
		_apply_bone("head", Vector3(0.18, 0.0, 0.0))

func _build_ground_contact_shadows(character: Node3D) -> void:
	# 影子挂在 MakeHuman 表现根上，随办公室坐姿和城市行走上下文移动；
	# 它不参与碰撞、导航、任务、输入或存档。
	var shadow_material := _soft_shadow_material()
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var shadow := MeshInstance3D.new()
		shadow.name = "候选主角" + suffix + "脚软接触阴影"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.28, 0.42)
		shadow.mesh = mesh
		shadow.position = Vector3(side * 0.16, 0.018, 0.08)
		shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		shadow.material_override = shadow_material.duplicate()
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		shadow.set_meta("visual_only", true)
		shadow.set_meta("candidate_visual_only", true)
		shadow.set_meta("ground_contact_visual", true)
		shadow.set_meta("original_procedural_asset", true)
		character.add_child(shadow)
		_ground_contact_shadows.append(shadow)

func _soft_shadow_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.015, 0.019, 0.022, 0.30),
		Color(0.015, 0.019, 0.022, 0.0),
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 64
	gradient_texture.height = 64
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = gradient_texture
	material.albedo_color = Color.WHITE
	return material

func _update_ground_contact_shadow_visibility() -> void:
	for shadow in _ground_contact_shadows:
		if is_instance_valid(shadow):
			shadow.visible = _state != "vehicle_default" and _state != "typing_default"

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

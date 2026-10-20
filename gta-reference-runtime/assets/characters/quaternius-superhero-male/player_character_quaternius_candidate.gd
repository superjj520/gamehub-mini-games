extends Node3D

## P0 主角视觉候选：CC0 基础网格 + 本项目原创服装覆盖和程序化动作。
## 该资产仍是候选，不改变任务、碰撞、镜头和存档状态的所有权。

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
var _phase := 0.0
var _state := "idle_default"
var _state_until := 0.0
var _ground_contact_shadows: Array[MeshInstance3D] = []

func _ready() -> void:
	_skeleton = get_node_or_null("Character/Armature/Skeleton3D") as Skeleton3D
	_style_imported_meshes()
	_build_outfit()
	_build_ground_contact_shadows()
	_build_animation_library()
	_cache_bone_rotations()

func _process(delta: float) -> void:
	_phase += delta
	if _animation_player != null and not _animation_player.current_animation.is_empty():
		_state = _animation_player.current_animation
	if Time.get_ticks_msec() / 1000.0 > _state_until and _state in ["hit_default", "fail_default", "interact_default"]:
		_state = "idle_default"
	_apply_pose()
	_update_ground_contact_shadow_visibility()

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
	var walk_amount := 0.0
	if _state == "walk_default" or _state == "vehicle_default":
		walk_amount = sin(_phase * 7.0)
	var idle_amount := sin(_phase * 2.1) * 0.025
	var crouch_amount := 0.0
	if _state == "crouch_default":
		crouch_amount = -0.22
	_apply_bone_rotation("spine_02", Vector3(idle_amount, 0.0, 0.0))
	_apply_bone_rotation("upperarm_l", Vector3(0.0, 0.0, -1.12 + walk_amount * 0.18))
	_apply_bone_rotation("upperarm_r", Vector3(0.0, 0.0, 1.12 - walk_amount * 0.18))
	_apply_bone_rotation("lowerarm_l", Vector3(0.0, 0.0, -0.10))
	_apply_bone_rotation("lowerarm_r", Vector3(0.0, 0.0, 0.10))
	_apply_bone_rotation("thigh_l", Vector3(walk_amount * 0.30 + crouch_amount, 0.0, 0.0))
	_apply_bone_rotation("thigh_r", Vector3(-walk_amount * 0.30 + crouch_amount, 0.0, 0.0))
	if _state == "hit_default":
		_apply_bone_rotation("spine_02", Vector3(-0.18, 0.0, 0.0))
	if _state == "fail_default":
		_apply_bone_rotation("spine_02", Vector3(0.48, 0.0, 0.0))
		_apply_bone_rotation("head", Vector3(0.24, 0.0, 0.0))

func _apply_bone_rotation(bone_name: String, euler_rotation: Vector3) -> void:
	if _skeleton == null:
		return
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index < 0 or not _base_rotations.has(bone_index):
		return
	var delta := Quaternion.from_euler(euler_rotation)
	_skeleton.set_bone_pose_rotation(bone_index, _base_rotations[bone_index] * delta)

func _build_ground_contact_shadows() -> void:
	# 接地阴影是候选表现层，不参与角色碰撞、导航、输入或任务状态。
	var shadow_material := _soft_shadow_material()
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var shadow := MeshInstance3D.new()
		shadow.name = "候选主角" + suffix + "脚软接触阴影"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.30, 0.44)
		shadow.mesh = mesh
		shadow.position = Vector3(side * 0.15, 0.018, -0.08)
		shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		shadow.material_override = shadow_material.duplicate()
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		shadow.set_meta("visual_only", true)
		shadow.set_meta("candidate_visual_only", true)
		shadow.set_meta("ground_contact_visual", true)
		shadow.set_meta("original_procedural_asset", true)
		add_child(shadow)
		_ground_contact_shadows.append(shadow)

func _soft_shadow_material() -> StandardMaterial3D:
	# 用 Godot 原生径向渐变纹理表达软边缘，避免候选运行时依赖自定义着色器。
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
	material.set_meta("original_procedural_asset", true)
	return material

func _update_ground_contact_shadow_visibility() -> void:
	for shadow in _ground_contact_shadows:
		if is_instance_valid(shadow):
			shadow.visible = _state != "vehicle_default"

func drive_candidate_state(state_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
	_state = state_name
	_state_until = Time.get_ticks_msec() / 1000.0 + 1.0

func _style_imported_meshes() -> void:
	var body := get_node_or_null("Character/Armature/Skeleton3D/SuperHero_Male") as MeshInstance3D
	if body != null:
		var skin := _material(Color("c89072"), 0.68, 0.0)
		body.material_override = skin
	var eyes := get_node_or_null("Character/Armature/Skeleton3D/Eyes") as MeshInstance3D
	if eyes != null:
		eyes.material_override = _material(Color("202832"), 0.30, 0.05)
	var eyebrows := get_node_or_null("Character/Armature/Skeleton3D/Eyebrows") as MeshInstance3D
	if eyebrows != null:
		eyebrows.material_override = _material(Color("1b2027"), 0.76, 0.0)

func _build_outfit() -> void:
	if get_node_or_null("Character/Armature/Skeleton3D/Outfit_Torso") != null:
		return
	# city-01 的构图锚点是画面中央的砖红色背影；背面镜头不能被深蓝外套吞掉。
	# 颜色只作用于候选视觉网格，不改变角色状态、碰撞、输入、载具或任务逻辑。
	var jacket := _material(Color("9f302d"), 0.62, 0.03)
	var trim := _material(Color("c05a48"), 0.48, 0.05)
	var shirt := _material(Color("d7e0de"), 0.72, 0.0)
	var backpack := _material(Color("202a2d"), 0.72, 0.05)
	var badge := _material(Color("d6aa57"), 0.36, 0.22)
	var trousers := _material(Color("202934"), 0.76, 0.02)
	var shoes := _material(Color("111820"), 0.62, 0.12)
	var hair := _material(Color("1b2027"), 0.82, 0.0)
	_add_box("候选主角身体", Vector3(0.62, 0.72, 0.50), Vector3(0.0, 1.10, 0.0), jacket, 0.06)
	_add_box("原创夹克肩部", Vector3(0.60, 0.34, 0.48), Vector3(0.0, 1.50, 0.0), jacket, 0.05)
	_add_box("原创衬衣前襟", Vector3(0.30, 0.38, 0.035), Vector3(0.0, 1.12, -0.315), shirt, 0.018)
	_add_box("原创衬衣领口", Vector3(0.20, 0.08, 0.045), Vector3(0.0, 1.34, -0.32), shirt, 0.012)
	_add_box("原创夹克下摆", Vector3(0.58, 0.18, 0.27), Vector3(0.0, 0.82, -0.02), trim, 0.04)
	_add_box("原创夹克腰带", Vector3(0.50, 0.07, 0.30), Vector3(0.0, 0.92, -0.23), jacket, 0.018)
	_add_box("候选主角背包", Vector3(0.44, 0.56, 0.16), Vector3(0.0, 1.10, 0.22), backpack, 0.07)
	_add_box("原创背包翻盖", Vector3(0.43, 0.12, 0.21), Vector3(0.0, 1.42, 0.19), trim, 0.04)
	_add_box("原创背包肩带左", Vector3(0.055, 0.54, 0.035), Vector3(-0.22, 1.18, -0.12), trim, 0.012)
	_add_box("原创背包肩带右", Vector3(0.055, 0.54, 0.035), Vector3(0.22, 1.18, -0.12), trim, 0.012)
	_add_box("原创胸牌", Vector3(0.12, 0.13, 0.035), Vector3(0.18, 1.20, -0.27), badge, 0.012)
	_add_capsule("原创左袖", Vector3(-0.40, 0.96, -0.01), 0.14, 0.66, jacket, Vector3(0.0, 0.0, -18.0))
	_add_capsule("原创右袖", Vector3(0.40, 0.96, -0.01), 0.14, 0.66, jacket, Vector3(0.0, 0.0, 18.0))
	_add_capsule("原创左裤腿", Vector3(-0.15, 0.46, 0.0), 0.13, 0.62, trousers, Vector3.ZERO)
	_add_capsule("原创右裤腿", Vector3(0.15, 0.46, 0.0), 0.13, 0.62, trousers, Vector3.ZERO)
	_add_box("原创左鞋", Vector3(0.24, 0.14, 0.40), Vector3(-0.15, 0.09, -0.08), shoes, 0.04)
	_add_box("原创右鞋", Vector3(0.24, 0.14, 0.40), Vector3(0.15, 0.09, -0.08), shoes, 0.04)
	var hair_cap := MeshInstance3D.new()
	hair_cap.name = "原创主角短发"
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

func _add_capsule(node_name: String, at: Vector3, radius: float, height: float, material: Material, rotation: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = material
	add_child(node)

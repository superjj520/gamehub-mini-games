extends Node3D

## 只用于隔离候选预览：统一服装色调、补视觉叠层和真实骨骼姿态，不进入正式运行时。

const ANIMATION_STATES := ["idle_default", "walk_default", "search_default", "alert_default"]

var _skeleton: Skeleton3D
var _base_rotations: Dictionary = {}
var _state := "idle_default"
var _phase := 0.0
var _badge: MeshInstance3D
var _radio: MeshInstance3D
var _badge_idle_material: StandardMaterial3D
var _badge_alert_material: StandardMaterial3D
var _radio_idle_material: StandardMaterial3D
var _radio_search_material: StandardMaterial3D
var _radio_alert_material: StandardMaterial3D
var _role := "supervisor"

func _ready() -> void:
	var character: Node3D = get_node_or_null("Character") as Node3D
	if character == null:
		# MakeHuman 清洗 GLB 的根节点是 Human.rig_export，不使用旧版 Character 包装名。
		# 以当前 Visual 根作为隔离返工父节点，避免在正式运行时加入路径特判。
		character = self
	var preserve_imported_materials := bool(get_meta("preserve_imported_materials", false))
	var reference_office_materials := bool(get_meta("reference_office_materials", false))
	var use_elegant_suit_candidate := bool(get_meta("use_elegant_suit_candidate", false))
	var use_elegant_suit_skinned := bool(get_meta("use_elegant_suit_skinned", false))
	_role = _resolve_role()
	set_meta("candidate_role", _role)
	var suit_material := _material(Color("59656b") if _role == "supervisor" else Color("516a77"), 0.76)
	var shirt_material := _material(Color("c7cbc8"), 0.86)
	var strap_material := _material(Color("30383b"), 0.78)
	var shoe_material := _material(Color("252a2c"), 0.88)
	var hair_material := _material(Color("1c1d1e"), 0.75)
	var skin_material := _material(Color("b47d68"), 0.72)
	var teeth_material := _material(Color("e7ded0"), 0.64)
	if use_elegant_suit_skinned:
		# 蒙皮西装模式必须优先于默认材质覆盖分支，否则仅打开蒙皮开关时原工装会继续可见。
		for item in character.find_children("*", "MeshInstance3D", true, false):
			var mesh := item as MeshInstance3D
			if _mesh_has_token(mesh, ["male_worksuit01", "worksuit"]):
				mesh.visible = false
			elif _mesh_has_token(mesh, ["male_elegantsuit", "elegantsuit"]):
				# 保留蒙皮图集中的衬衣、领带和裤装分区，避免单色覆盖破坏参考帧层次。
				mesh.material_override = null
			elif _mesh_has_token(mesh, ["shoes02", "shoes"]):
				mesh.material_override = _material(Color("e8e8e3"), 0.82)
	elif not preserve_imported_materials:
		for item in character.find_children("*", "MeshInstance3D", true, false):
			var mesh := item as MeshInstance3D
			if _mesh_has_token(mesh, ["male_worksuit01", "worksuit"]):
				mesh.material_override = suit_material
			elif _mesh_has_token(mesh, ["shoes02", "shoes"]):
				mesh.material_override = shoe_material
			elif _mesh_has_token(mesh, ["short02", "hair"]):
				mesh.material_override = hair_material
			elif _mesh_has_token(mesh, ["teeth"]):
				mesh.material_override = teeth_material
			elif _mesh_has_token(mesh, ["body", "low-poly", "skin"]):
				mesh.material_override = skin_material
	elif use_elegant_suit_candidate or use_elegant_suit_skinned:
		for item in character.find_children("*", "MeshInstance3D", true, false):
			var mesh := item as MeshInstance3D
			if _mesh_has_token(mesh, ["male_worksuit01", "worksuit"]):
				mesh.visible = false
			elif _mesh_has_token(mesh, ["shoes02", "shoes"]):
				mesh.material_override = _material(Color("e8e8e3"), 0.82)
	elif reference_office_materials:
		var reference_suit_material := _material(Color("626b70"), 0.74)
		var reference_shoe_material := _material(Color("e8e8e3"), 0.82)
		for item in character.find_children("*", "MeshInstance3D", true, false):
			var mesh := item as MeshInstance3D
			if _mesh_has_token(mesh, ["male_worksuit01", "worksuit"]):
				# 只替换服装底色，皮肤与头发继续使用候选原始纹理。
				mesh.material_override = reference_suit_material
			elif _mesh_has_token(mesh, ["shoes02", "shoes"]):
				mesh.material_override = reference_shoe_material
	var skeleton_nodes := character.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeleton_nodes[0] as Skeleton3D if not skeleton_nodes.is_empty() else null
	_cache_skeleton()
	_build_office_identity_layers(character)
	_build_formal_animation_bridge(character)
	if use_elegant_suit_candidate and not use_elegant_suit_skinned:
		_mount_elegant_suit_candidate(character)
	_build_reference_shirt(character, shirt_material, strap_material, reference_office_materials)
	# 背包只属于主角；办公室 NPC 保持清晰的管理/巡查轮廓，避免与主角视觉混淆。
	if _role != "supervisor":
		_build_backpack(character)
	_bind_reference_parts_to_bones(character)

func _process(delta: float) -> void:
	_phase += delta
	_apply_candidate_pose()
	_update_state_visual()

func drive_candidate_state(state_name: String) -> void:
	if state_name in ANIMATION_STATES:
		_state = state_name

func _cache_skeleton() -> void:
	if _skeleton == null:
		return
	for bone_index in range(_skeleton.get_bone_count()):
		_base_rotations[bone_index] = _skeleton.get_bone_pose_rotation(bone_index)

func _apply_candidate_pose() -> void:
	if _skeleton == null:
		return
	for bone_index in _base_rotations:
		_skeleton.set_bone_pose_rotation(int(bone_index), _base_rotations[bone_index])
	var walk_wave := sin(_phase * 6.0)
	# MakeHuman 导入的默认手臂接近张臂；先收回到办公人员自然垂落姿态，再叠加状态动作。
	var arm_wave := 0.10 * walk_wave if _state == "walk_default" else 0.0
	_apply_bone("upperarm_l", Vector3(0.0, 0.0, arm_wave))
	_apply_bone("upperarm_r", Vector3(0.0, 0.0, -arm_wave))
	_apply_bone("lowerarm_l", Vector3.ZERO)
	_apply_bone("lowerarm_r", Vector3.ZERO)
	if _state == "walk_default":
		_apply_bone("thigh_l", Vector3(0.32 * walk_wave, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.32 * walk_wave, 0.0, 0.0))
		_apply_bone("calf_l", Vector3(-0.18 * maxf(walk_wave, 0.0), 0.0, 0.0))
		_apply_bone("calf_r", Vector3(-0.18 * maxf(-walk_wave, 0.0), 0.0, 0.0))
	elif _state == "search_default":
		_apply_bone("spine_02", Vector3(-0.08, 0.10, 0.0))
		_apply_bone("head", Vector3(0.04, 0.18 * sin(_phase * 1.4), 0.0))
		_apply_bone("upperarm_l", Vector3.ZERO)
		_apply_bone("upperarm_r", Vector3.ZERO)
	elif _state == "alert_default":
		_apply_bone("spine_02", Vector3(-0.18, 0.0, 0.0))
		_apply_bone("spine_03", Vector3(-0.08, 0.0, 0.0))
		_apply_bone("head", Vector3(-0.10, 0.0, 0.0))
		_apply_bone("upperarm_l", Vector3.ZERO)
		_apply_bone("upperarm_r", Vector3.ZERO)
	else:
		_apply_bone("spine_02", Vector3(-0.018 * sin(_phase * 2.0), 0.0, 0.0))

func _apply_bone(bone_name: String, euler_rotation: Vector3) -> void:
	if _skeleton == null:
		return
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index < 0 or not _base_rotations.has(bone_index):
		return
	_skeleton.set_bone_pose_rotation(bone_index, _base_rotations[bone_index] * Quaternion.from_euler(euler_rotation))

func _build_reference_shirt(parent: Node3D, shirt_material: StandardMaterial3D, strap_material: StandardMaterial3D, reference_office_materials: bool = false) -> void:
	# 参考帧中人物是浅色长袖、深色背包肩带和深色长裤；这里仅做隔离预览叠层。
	if reference_office_materials:
		# 蒙皮西装继续保留原始轮廓，只补一块薄衬衣前片和领口，让 NPC 与主角的身份差异可读。
		_add_box(parent, "视觉返工衬衣前片", Vector3(0.28, 0.24, 0.032), Vector3(0.0, 1.18, -0.258), shirt_material, 0.012)
		_add_box(parent, "视觉返工衬衣左领", Vector3(0.10, 0.055, 0.038), Vector3(-0.075, 1.35, -0.274), shirt_material, 0.006)
		_add_box(parent, "视觉返工衬衣右领", Vector3(0.10, 0.055, 0.038), Vector3(0.075, 1.35, -0.274), shirt_material, 0.006)
		_add_box(parent, "视觉返工主管领带", Vector3(0.035, 0.14, 0.024), Vector3(0.0, 1.24, -0.279), strap_material, 0.004)
		return
	var sleeve_radius := 0.060 if reference_office_materials else 0.095
	var sleeve_height := 0.46 if reference_office_materials else 0.56
	_add_capsule(parent, "视觉返工左长袖", Vector3(-0.33, 1.10, -0.01), sleeve_radius, sleeve_height, shirt_material, PI / 2.0)
	_add_capsule(parent, "视觉返工右长袖", Vector3(0.33, 1.10, -0.01), sleeve_radius, sleeve_height, shirt_material, -PI / 2.0)
	var front_z := 0.22 if reference_office_materials else -0.20
	_add_box(parent, "视觉返工衬衣领口", Vector3(0.16 if reference_office_materials else 0.24, 0.04 if reference_office_materials else 0.06, 0.03 if reference_office_materials else 0.05), Vector3(0.0, 1.40 if reference_office_materials else 1.43, front_z), shirt_material, 0.008)
	if reference_office_materials:
		# 参考模式不绘制大面积腰带/肩带，避免把背包提示层渲染成胸前方框。
		_add_box(parent, "视觉返工左肩带细线", Vector3(0.022, 0.30, 0.018), Vector3(-0.105, 1.25, front_z), strap_material, 0.004)
		_add_box(parent, "视觉返工右肩带细线", Vector3(0.022, 0.30, 0.018), Vector3(0.105, 1.25, front_z), strap_material, 0.004)
	else:
		_add_box(parent, "视觉返工左肩带", Vector3(0.045, 0.54, 0.035), Vector3(-0.14, 1.16, front_z), strap_material, 0.008)
		_add_box(parent, "视觉返工右肩带", Vector3(0.045, 0.54, 0.035), Vector3(0.14, 1.16, front_z), strap_material, 0.008)
		_add_box(parent, "视觉返工腰带", Vector3(0.48, 0.055, 0.30), Vector3(0.0, 0.86, front_z), strap_material, 0.01)

func _mount_elegant_suit_candidate(parent: Node3D) -> void:
	var packed_scene := load("res://assets/characters/makehuman-office-worker/male_elegantsuit01_unskinned.glb") as PackedScene
	if packed_scene == null:
		push_error("未找到未蒙皮 male_elegantsuit01 服装探针")
		return
	var suit := packed_scene.instantiate() as Node3D
	suit.name = "MakeHuman 男性西装未蒙皮视觉探针"
	parent.add_child(suit)

func _build_backpack(parent: Node3D) -> void:
	var bag_material := _material(Color("1f292d"), 0.86)
	var trim_material := _material(Color("53656a"), 0.72)
	var detail_material := _material(Color("2d5962"), 0.58)
	var backpack_parent: Node3D = parent
	if _skeleton != null and _skeleton.find_bone("spine_02") >= 0:
		var attachment := BoneAttachment3D.new()
		attachment.name = "视觉返工背包骨骼挂点"
		attachment.bone_name = "spine_02"
		_skeleton.add_child(attachment)
		backpack_parent = attachment
		backpack_parent.scale = Vector3(0.88, 0.90, 0.88)
		_add_box(backpack_parent, "视觉返工背包", Vector3(0.34, 0.52, 0.16), Vector3(0.0, 0.04, -0.18), bag_material, 0.06)
		_add_box(backpack_parent, "视觉返工背包翻盖", Vector3(0.30, 0.10, 0.18), Vector3(0.0, 0.31, -0.15), trim_material, 0.03)
		_add_box(backpack_parent, "视觉返工背包前袋", Vector3(0.24, 0.13, 0.035), Vector3(0.0, -0.04, -0.273), detail_material, 0.01)
		_add_box(backpack_parent, "视觉返工背包反光条", Vector3(0.20, 0.028, 0.018), Vector3(0.0, 0.045, -0.296), trim_material, 0.004)
		_add_box(backpack_parent, "视觉返工背包肩带左", Vector3(0.055, 0.48, 0.035), Vector3(-0.19, 0.08, -0.14), trim_material, 0.01)
		_add_box(backpack_parent, "视觉返工背包肩带右", Vector3(0.055, 0.48, 0.035), Vector3(0.19, 0.08, -0.14), trim_material, 0.01)
		return
	_add_box(backpack_parent, "视觉返工背包", Vector3(0.34, 0.52, 0.16), Vector3(0.0, 1.08, 0.22), bag_material, 0.06)
	_add_box(backpack_parent, "视觉返工背包翻盖", Vector3(0.30, 0.10, 0.18), Vector3(0.0, 1.37, 0.19), trim_material, 0.03)
	_add_box(backpack_parent, "视觉返工背包前袋", Vector3(0.24, 0.13, 0.035), Vector3(0.0, 1.00, 0.305), detail_material, 0.01)
	_add_box(backpack_parent, "视觉返工背包反光条", Vector3(0.20, 0.028, 0.018), Vector3(0.0, 1.085, 0.328), trim_material, 0.004)
	_add_box(backpack_parent, "视觉返工背包肩带左", Vector3(0.055, 0.48, 0.035), Vector3(-0.19, 1.15, 0.16), trim_material, 0.01)
	_add_box(backpack_parent, "视觉返工背包肩带右", Vector3(0.055, 0.48, 0.035), Vector3(0.19, 1.15, 0.16), trim_material, 0.01)

func _build_office_identity_layers(parent: Node3D) -> void:
	# 工牌和对讲机只承担办公室 NPC 的身份/警觉可读性，不写入正式感知数值。
	_badge_idle_material = _material(Color("d2ad5d"), 0.44)
	_badge_alert_material = _material(Color("c9564d"), 0.38)
	_badge_alert_material.emission_enabled = true
	_badge_alert_material.emission = Color("8f2f2a")
	_badge_alert_material.emission_energy_multiplier = 0.16
	_radio_idle_material = _material(Color("263137"), 0.72, 0.02)
	_radio_search_material = _material(Color("4d8a91"), 0.48, 0.03)
	_radio_search_material.emission_enabled = true
	_radio_search_material.emission = Color("32676d")
	_radio_search_material.emission_energy_multiplier = 0.10
	_radio_alert_material = _material(Color("a23a35"), 0.44, 0.02)
	_radio_alert_material.emission_enabled = true
	_radio_alert_material.emission = Color("ff4d45")
	_radio_alert_material.emission_energy_multiplier = 0.22
	_add_box(parent, "参考服装工牌", Vector3(0.11, 0.14, 0.025), Vector3(0.13, 1.29, -0.245), _badge_idle_material, 0.008)
	_add_box(parent, "视觉返工对讲机", Vector3(0.10, 0.16, 0.05), Vector3(-0.22, 1.13, -0.23), _radio_idle_material, 0.012)
	if _role == "supervisor":
		_add_box(parent, "主管领口金属夹", Vector3(0.06, 0.10, 0.022), Vector3(-0.10, 1.40, -0.24), _badge_idle_material, 0.004)
	else:
		_add_box(parent, "巡查肩章", Vector3(0.16, 0.08, 0.028), Vector3(0.28, 1.24, -0.20), _radio_search_material, 0.006)
	_badge = parent.get_node_or_null("参考服装工牌") as MeshInstance3D
	_radio = parent.get_node_or_null("视觉返工对讲机") as MeshInstance3D

func _update_state_visual() -> void:
	if _badge == null or _radio == null:
		return
	if _state == "alert_default":
		_badge.material_override = _badge_alert_material
		_radio.material_override = _radio_alert_material
	elif _state == "search_default":
		_badge.material_override = _badge_idle_material
		_radio.material_override = _radio_search_material
	else:
		_badge.material_override = _badge_idle_material
		_radio.material_override = _radio_idle_material

func _bind_reference_parts_to_bones(parent: Node3D) -> void:
	if _skeleton == null:
		return
	_bind_part(parent, "视觉返工左长袖", "upperarm_l")
	_bind_part(parent, "视觉返工右长袖", "upperarm_r")
	_bind_part(parent, "视觉返工衬衣领口", "spine_03")
	_bind_part(parent, "视觉返工衬衣前片", "spine_03")
	_bind_part(parent, "视觉返工衬衣左领", "spine_03")
	_bind_part(parent, "视觉返工衬衣右领", "spine_03")
	_bind_part(parent, "视觉返工主管领带", "spine_03")
	_bind_part(parent, "视觉返工左肩带", "upperarm_l")
	_bind_part(parent, "视觉返工右肩带", "upperarm_r")
	_bind_part(parent, "视觉返工左肩带细线", "upperarm_l")
	_bind_part(parent, "视觉返工右肩带细线", "upperarm_r")
	_bind_part(parent, "视觉返工腰带", "spine_02")
	_bind_part(parent, "参考服装工牌", "spine_03")
	_bind_part(parent, "视觉返工对讲机", "spine_02")
	_bind_part(parent, "主管领口金属夹", "spine_03")
	_bind_part(parent, "巡查肩章", "upperarm_r")

func _resolve_role() -> String:
	var owner := get_parent()
	if owner != null and owner.name.contains("走廊"):
		return "patrol"
	return "supervisor"

func _bind_part(parent: Node3D, node_name: String, bone_name: String) -> void:
	var part := parent.get_node_or_null(node_name) as Node3D
	if part == null or _skeleton.find_bone(bone_name) < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "视觉返工骨骼挂点-%s" % node_name
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	part.reparent(attachment, true)

func _mesh_has_token(mesh: MeshInstance3D, tokens: Array[String]) -> bool:
	if mesh == null:
		return false
	var haystack := mesh.name.to_lower()
	if mesh.mesh != null:
		for surface_index in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface_index)
			if material != null:
				haystack += " " + material.resource_name.to_lower()
	for token in tokens:
		if haystack.contains(token):
			return true
	return false

func _build_formal_animation_bridge(parent: Node3D) -> void:
	if _skeleton == null or parent.get_node_or_null("AnimationPlayer") != null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "正式动画桥接骨骼挂点"
	attachment.bone_name = "head" if _skeleton.find_bone("head") >= 0 else "spine_02"
	_skeleton.add_child(attachment)
	var probe := Node3D.new()
	probe.name = "正式动画桥接探针"
	attachment.add_child(probe)
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	parent.add_child(animation_player)
	var library := AnimationLibrary.new()
	for state_name in ANIMATION_STATES:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if state_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("%s/%s:rotation_degrees" % [parent.get_path_to(attachment), probe.name]))
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		animation.track_insert_key(track, 0.0, Vector3.ZERO)
		animation.track_insert_key(track, 0.5, Vector3(0.0, 8.0, 0.0))
		animation.track_insert_key(track, 1.0, Vector3.ZERO)
		library.add_animation(state_name, animation)
	animation_player.add_animation_library("", library)

func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: StandardMaterial3D, bevel: float) -> void:
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
	node.material_override = material
	parent.add_child(node)

func _add_capsule(parent: Node3D, node_name: String, at: Vector3, radius: float, height: float, material: StandardMaterial3D, rotation_z: float) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation.z = rotation_z
	node.material_override = material
	parent.add_child(node)

extends Node3D

## 城市人群视觉候选：复用已登记 CC0 基础人物和原创制服网格。
## 只承担视觉、状态姿态和确定性变体，不承担碰撞、路线或任务逻辑。

const ANIMATION_STATES := ["idle_default", "walk_default", "displaced_default", "hit_default"]
const VARIANT_COLORS := [Color("596879"), Color("8a6d5d"), Color("647a70")]
const VARIANT_ROLES := ["delivery", "shopper", "worker", "patrol"]
const VISUAL_LOD_END_DISTANCE := 48.0
const VISUAL_LOD_END_MARGIN := 4.0

var _skeleton: Skeleton3D
var _animation_player: AnimationPlayer
var _base_rotations: Dictionary = {}
var _state := "idle_default"
var _phase := 0.0
var _variant_index := 0
var _city_accessory_root: Node3D

func _ready() -> void:
	var owner := get_parent()
	if owner != null and str(owner.name).contains("冲突"):
		_variant_index = VARIANT_ROLES.size() - 1
	else:
		var owner_suffix := str(owner.name).get_slice("_", 1) if owner != null else ""
		_variant_index = int(owner_suffix) % VARIANT_ROLES.size() if owner_suffix.is_valid_int() else absi(int(round(global_position.x * 7.0 + global_position.z * 11.0))) % VARIANT_ROLES.size()
	set_meta("city_role", VARIANT_ROLES[_variant_index % VARIANT_ROLES.size()])
	set_meta("city_variant_index", _variant_index)
	set_meta("city_variant_contract", "deterministic_suit_skin_hair_palette")
	set_meta("city_role_scale", 0.96 + float(_variant_index % 4) * 0.025)
	set_meta("visual_lod_end_distance", VISUAL_LOD_END_DISTANCE)
	set_meta("visual_lod_end_margin", VISUAL_LOD_END_MARGIN)
	set_meta("visual_only", true)
	set_meta("candidate_visual_only", true)
	set_meta("asset_source", "cc0_quaternius_base_with_original_city_accessory_layers")
	var character := get_node_or_null("Character")
	if character == null:
		return
	scale = Vector3.ONE * float(get_meta("city_role_scale", 1.0))
	_style_character(character)
	_build_accessory_layers(character)
	var skeleton_nodes := character.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeleton_nodes[0] as Skeleton3D if not skeleton_nodes.is_empty() else null
	_cache_skeleton()
	_build_animation_library()
	_configure_city_visual_lod()

func _process(delta: float) -> void:
	_phase += delta
	if _animation_player != null and not _animation_player.current_animation.is_empty():
		_state = _animation_player.current_animation
	_apply_candidate_pose()

func drive_candidate_state(state_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
		_state = state_name

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for state_name in ANIMATION_STATES:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if state_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		library.add_animation(state_name, animation)
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

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
	# 导入角色的默认姿态是张臂姿态；先收回到自然下垂，再叠加行走摆臂。
	_apply_bone("upperarm_l", Vector3(0.0, 0.0, -1.42))
	_apply_bone("upperarm_r", Vector3(0.0, 0.0, 1.42))
	_apply_bone("lowerarm_l", Vector3(0.0, 0.0, -0.24))
	_apply_bone("lowerarm_r", Vector3(0.0, 0.0, 0.24))
	if _state == "walk_default":
		_apply_bone("upperarm_l", Vector3(0.0, 0.0, -0.22 * walk_wave))
		_apply_bone("upperarm_r", Vector3(0.0, 0.0, 0.22 * walk_wave))
		_apply_bone("thigh_l", Vector3(0.28 * walk_wave, 0.0, 0.0))
		_apply_bone("thigh_r", Vector3(-0.28 * walk_wave, 0.0, 0.0))
	elif _state == "displaced_default":
		_apply_bone("spine_02", Vector3(-0.16, 0.0, 0.10))
		_apply_bone("head", Vector3(0.0, 0.0, -0.10))
	elif _state == "hit_default":
		_apply_bone("spine_02", Vector3(0.20, 0.0, 0.0))
		_apply_bone("head", Vector3(-0.12, 0.0, 0.0))
	else:
		_apply_bone("spine_02", Vector3(-0.012 * sin(_phase * 2.0), 0.0, 0.0))

func _apply_bone(bone_name: String, euler_rotation: Vector3) -> void:
	if _skeleton == null:
		return
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index < 0 or not _base_rotations.has(bone_index):
		return
	_skeleton.set_bone_pose_rotation(bone_index, _base_rotations[bone_index] * Quaternion.from_euler(euler_rotation))

func _style_character(character: Node) -> void:
	var jacket := _material(VARIANT_COLORS[_variant_index % VARIANT_COLORS.size()], 0.68)
	var trim := _material(Color("c6a15b"), 0.42, 0.10)
	var shirt := _material(Color("d2d9d6"), 0.76)
	var trousers := _material(Color("252c38"), 0.78, 0.02)
	var shoes := _material(Color("111820"), 0.64, 0.10)
	var skin := _material(Color("b9856d"), 0.70)
	var hair := _material(Color("252128"), 0.86, 0.0)
	for item in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if str(item.name).begins_with("SuperHero_Male"):
			mesh.material_override = skin
		elif item.name == "Outfit_Hair":
			mesh.material_override = hair
		elif item.name in ["Outfit_Torso", "Outfit_ShoulderShell", "Outfit_Sleeve_L", "Outfit_Sleeve_R"]:
			mesh.material_override = jacket
		elif item.name == "Outfit_ShirtFront" or item.name == "Outfit_ShirtCollar":
			mesh.material_override = shirt
		elif item.name.begins_with("Outfit_Trousers"):
			mesh.material_override = trousers
		elif item.name.begins_with("Outfit_Shoe"):
			mesh.material_override = shoes
		elif item.name == "Outfit_Badge" or item.name == "Outfit_WaistTrim":
			mesh.material_override = trim

func _build_accessory_layers(character: Node) -> void:
	var identity_root := Node3D.new()
	identity_root.name = "城市身份配件"
	identity_root.set_meta("role", str(get_meta("city_role", "city_variant")))
	identity_root.set_meta("visual_only", true)
	identity_root.set_meta("candidate_visual_only", true)
	_city_accessory_root = identity_root
	add_child(identity_root)
	var skeleton_nodes := character.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeleton_nodes[0] as Skeleton3D if not skeleton_nodes.is_empty() else null
	if skeleton == null:
		var fallback_badge := MeshInstance3D.new()
		fallback_badge.name = "城市身份降级标记"
		var fallback_mesh := BoxMesh.new()
		fallback_mesh.size = Vector3(0.14, 0.08, 0.026)
		fallback_badge.mesh = fallback_mesh
		fallback_badge.position = Vector3(0.0, 1.18, -0.28)
		fallback_badge.material_override = _material(Color("d7b45e"), 0.32, 0.04)
		identity_root.add_child(fallback_badge)
		return
	var accessory_root := Node3D.new()
	accessory_root.name = "候选人群视觉配件"
	identity_root.add_child(accessory_root)
	var cap_material := _material(Color("202732") if _variant_index != 1 else Color("6b3029"), 0.72, 0.02)
	var cap_brim_material := _material(Color("11161d"), 0.82, 0.0)
	var bag_material := _material(Color("27333c") if _variant_index == 0 else Color("5b4738"), 0.78, 0.02)
	var reflective_material := _material(Color("d7b45e"), 0.32, 0.04)
	reflective_material.emission_enabled = true
	reflective_material.emission = Color("7b5a2f")
	reflective_material.emission_energy_multiplier = 0.08

	var head_attachment := BoneAttachment3D.new()
	head_attachment.name = "候选人群头部挂点"
	head_attachment.bone_name = "head"
	skeleton.add_child(head_attachment)
	var cap := MeshInstance3D.new()
	cap.name = "候选人群帽体"
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.22
	cap_mesh.bottom_radius = 0.24
	cap_mesh.height = 0.10
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 0.15, 0.0)
	cap.material_override = cap_material
	head_attachment.add_child(cap)
	var brim := MeshInstance3D.new()
	brim.name = "候选人群帽檐"
	var brim_mesh := BoxMesh.new()
	brim_mesh.size = Vector3(0.28, 0.035, 0.16)
	brim.mesh = brim_mesh
	brim.position = Vector3(0.0, 0.10, -0.16)
	brim.material_override = cap_brim_material
	head_attachment.add_child(brim)

	var torso_attachment := BoneAttachment3D.new()
	torso_attachment.name = "候选人群躯干挂点"
	torso_attachment.bone_name = "spine_02"
	skeleton.add_child(torso_attachment)
	var bag := MeshInstance3D.new()
	bag.name = "候选人群肩包"
	var bag_mesh := BoxMesh.new()
	bag_mesh.size = Vector3(0.24, 0.34, 0.12)
	bag.mesh = bag_mesh
	bag.position = Vector3(0.30, -0.08, 0.10)
	bag.rotation_degrees = Vector3(0.0, 12.0, -12.0)
	bag.material_override = bag_material
	torso_attachment.add_child(bag)
	var band := MeshInstance3D.new()
	band.name = "候选人群反光腰带"
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.38, 0.035, 0.30)
	band.mesh = band_mesh
	band.position = Vector3(0.0, -0.10, -0.16)
	band.material_override = reflective_material
	torso_attachment.add_child(band)

func _configure_city_visual_lod() -> void:
	for geometry_node in find_children("*", "GeometryInstance3D", true, false):
		var geometry := geometry_node as GeometryInstance3D
		if geometry == null:
			continue
		geometry.visibility_range_end = VISUAL_LOD_END_DISTANCE
		geometry.visibility_range_end_margin = VISUAL_LOD_END_MARGIN
		geometry.set_meta("visual_lod_end_distance", VISUAL_LOD_END_DISTANCE)
		geometry.set_meta("visual_lod_end_margin", VISUAL_LOD_END_MARGIN)
		geometry.set_meta("visual_only", true)
		geometry.set_meta("candidate_visual_only", true)

func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

extends "res://art-source/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd"

## 城市人群写实候选：复用已通过 NPC 技术预算的 MakeHuman 蒙皮资产。
## 只承担城市人群视觉与状态姿态，不接管路线、碰撞、感知或任务逻辑。

const CITY_ROLES := ["delivery", "shopper", "worker", "patrol"]
const CITY_ROLE_LABELS := {
	"delivery": "配送员",
	"shopper": "行人",
	"worker": "店员",
	"patrol": "巡查员",
}
const CITY_ROLE_COLORS := {
	"delivery": Color("3d6472"),
	"shopper": Color("795b57"),
	"worker": Color("5d705f"),
	"patrol": Color("4b5964"),
}
const CITY_ROLE_COLOR_VARIANTS := {
	"delivery": [Color("3d6472"), Color("536f62"), Color("765d52")],
	"shopper": [Color("795b57"), Color("4d6372"), Color("756d4e")],
	"worker": [Color("5d705f"), Color("6d5e75"), Color("7a644c")],
	"patrol": [Color("4b5964"), Color("5c6556"), Color("6d5960")],
}
const CITY_ROLE_SKIN_COLORS := {
	"delivery": Color("b47d68"),
	"shopper": Color("9f6b58"),
	"worker": Color("c18b72"),
	"patrol": Color("875a4e"),
}
const CITY_ROLE_SKIN_VARIANTS := {
	"delivery": [Color("b47d68"), Color("c08f76"), Color("8f604f")],
	"shopper": [Color("9f6b58"), Color("c18d72"), Color("7d5145")],
	"worker": [Color("c18b72"), Color("a96e5d"), Color("d09b7c")],
	"patrol": [Color("875a4e"), Color("b57b63"), Color("70463f")],
}
const CITY_HAIR_VARIANTS := [Color("1c1d1e"), Color("3b2a25"), Color("5a4030")]
const CITY_ROLE_SCALES := {
	"delivery": 1.02,
	"shopper": 0.95,
	"worker": 0.99,
	"patrol": 1.05,
}
const VISUAL_LOD_END_DISTANCE := 48.0
const VISUAL_LOD_END_MARGIN := 4.0

var _city_role := "delivery"
var _city_variant_index := 0
var _city_role_material: StandardMaterial3D
var _city_role_trim_material: StandardMaterial3D
var _city_role_light: MeshInstance3D
var _city_accessory_root: Node3D

func _ready() -> void:
	super._ready()
	_apply_city_role_materials()
	_apply_city_role_scale()
	_ensure_city_animation_contract()
	# MakeHuman 蒙皮资产的局部包围盒底部约为 -0.0143；把这个事实登记给
	# 城市运行时的通用贴地层，避免候选人群沿用旧程序化角色的 -1.075 偏移而漂浮。
	set_meta("city_makehuman_asset", true)
	set_meta("city_makehuman_foot_origin_y", -0.0143)
	set_meta("city_ground_contact_contract", "makehuman_bounds_min_y_scaled")
	var visual_layers := Node3D.new()
	visual_layers.name = "候选人群视觉配件"
	visual_layers.set_meta("source_candidate", "makehuman_elegant_suit_skinned_512_atlas")
	visual_layers.set_meta("city_role", _city_role)
	visual_layers.set_meta("city_role_label", CITY_ROLE_LABELS.get(_city_role, "行人"))
	set_meta("city_variant_index", _city_variant_index)
	set_meta("city_variant_contract", "deterministic_suit_skin_hair_palette")
	add_child(visual_layers)
	_build_city_accessory_layers()
	_configure_city_visual_lod()

func _resolve_role() -> String:
	# 城市人群使用父节点的确定性编号产生身份差异；冲突对象固定使用巡查轮廓。
	var owner := get_parent()
	var crowd_index := 0
	if owner != null:
		if str(owner.name).contains("冲突"):
			_city_role = "patrol"
		else:
			var suffix := str(owner.name).get_slice("_", 1)
			if suffix.is_valid_int():
				crowd_index = int(suffix)
			_city_variant_index = absi(crowd_index) % 3
			_city_role = CITY_ROLES[absi(crowd_index) % CITY_ROLES.size()]
	# 父类只区分“主管”和“非主管”，这里借用该分支决定是否挂载通勤包。
	return "patrol" if _city_role in ["delivery", "patrol"] else "supervisor"

func _build_office_identity_layers(parent: Node3D) -> void:
	# 城市人群不复用办公室工牌/对讲机组合，换成街区身份配件。
	_city_role_material = _material(CITY_ROLE_COLORS.get(_city_role, Color("59656b")), 0.78)
	_city_role_trim_material = _material(Color("d2b365"), 0.42)
	_city_role_light = _add_city_box(parent, "城市身份提示灯", Vector3(0.045, 0.045, 0.025), Vector3(-0.20, 1.26, -0.27), _city_role_trim_material, 0.004)
	if _city_role == "delivery":
		_add_city_box(parent, "配送员胸前编号", Vector3(0.12, 0.08, 0.026), Vector3(0.12, 1.30, -0.27), _city_role_trim_material, 0.006)
		_add_city_box(parent, "配送员肩带", Vector3(0.035, 0.44, 0.026), Vector3(-0.14, 1.12, -0.26), _city_role_trim_material, 0.006)
	elif _city_role == "shopper":
		_add_city_box(parent, "行人衣襟标记", Vector3(0.10, 0.05, 0.026), Vector3(0.13, 1.33, -0.27), _city_role_trim_material, 0.004)
	elif _city_role == "worker":
		_add_city_box(parent, "店员胸前标记", Vector3(0.15, 0.075, 0.026), Vector3(0.12, 1.30, -0.27), _city_role_trim_material, 0.006)
		_add_city_box(parent, "店员腰部反光条", Vector3(0.38, 0.032, 0.026), Vector3(0.0, 0.93, -0.27), _city_role_trim_material, 0.004)
	else:
		_add_city_box(parent, "巡查员胸前标记", Vector3(0.12, 0.08, 0.026), Vector3(0.12, 1.30, -0.27), _city_role_trim_material, 0.006)
		_add_city_box(parent, "巡查员肩章", Vector3(0.16, 0.07, 0.028), Vector3(0.28, 1.24, -0.25), _city_role_trim_material, 0.006)
	_badge = parent.get_node_or_null("城市身份提示灯") as MeshInstance3D
	_radio = parent.get_node_or_null("城市身份提示灯") as MeshInstance3D

func _build_backpack(_parent: Node3D) -> void:
	# 城市人群不继承办公室主角背包；城市角色使用下方按身份生成的轻量配件。
	# 继承的办公室背包会遮挡躯干并放大 MakeHuman 候选的比例误差。
	return

func _apply_candidate_pose() -> void:
	# MakeHuman 导入姿态接近张臂姿态；城市候选必须先收回到自然垂臂，
	# 再交给父类叠加行走、搜索和警戒状态，否则街景会出现伸展白色肢体。
	if _skeleton == null:
		return
	for bone_index in _base_rotations:
		_skeleton.set_bone_pose_rotation(int(bone_index), _base_rotations[bone_index])
	_apply_bone("upperarm_l", Vector3(0.0, 0.0, -1.42))
	_apply_bone("upperarm_r", Vector3(0.0, 0.0, 1.42))
	_apply_bone("lowerarm_l", Vector3(0.0, 0.0, -0.24))
	_apply_bone("lowerarm_r", Vector3(0.0, 0.0, 0.24))
	if _state == "walk_default":
		var walk_wave := sin(_phase * 6.0)
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

func _apply_city_role_materials() -> void:
	var character: Node3D = get_node_or_null("Character") as Node3D
	if character == null:
		character = self
	var suit_variants: Array = CITY_ROLE_COLOR_VARIANTS.get(_city_role, [Color("59656b")])
	var skin_variants: Array = CITY_ROLE_SKIN_VARIANTS.get(_city_role, [Color("b47d68")])
	var suit_material := _material(suit_variants[_city_variant_index % suit_variants.size()], 0.76)
	var skin_material := _material(skin_variants[_city_variant_index % skin_variants.size()], 0.80)
	var hair_material := _material(CITY_HAIR_VARIANTS[_city_variant_index % CITY_HAIR_VARIANTS.size()], 0.74)
	var shoe_material := _material(Color("252a2c"), 0.86)
	for item in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if _mesh_has_token(mesh, ["backpack", "back_pack"]):
			# 蒙皮西装 GLB 自带的完整背包比例过大；城市角色只保留按身份生成的轻量侧挂配件。
			mesh.visible = false
		elif _mesh_has_token(mesh, ["male_elegantsuit", "male_worksuit01", "worksuit", "elegantsuit"]):
			mesh.material_override = suit_material
		elif _mesh_has_token(mesh, ["body", "low-poly", "skin", "arms", "hands"]):
			# 蒙皮西装候选不能依赖 GLB 的默认白色材质；城市近景里手臂和小腿必须先回到统一肤色。
			mesh.material_override = skin_material
		elif _mesh_has_token(mesh, ["short02", "hair"]):
			mesh.material_override = hair_material
		elif _mesh_has_token(mesh, ["shoes02", "shoes", "boots"]):
			mesh.material_override = shoe_material

func _apply_city_role_scale() -> void:
	# 只改变候选 Visual 根节点的体型比例，不改变行人控制器、碰撞、路线或感知半径。
	var role_scale := float(CITY_ROLE_SCALES.get(_city_role, 1.0))
	scale = Vector3.ONE * role_scale
	set_meta("city_role_scale", role_scale)

func _add_city_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: StandardMaterial3D, bevel: float) -> MeshInstance3D:
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
	return node

func _build_city_accessory_layers() -> void:
	var accessory_root := Node3D.new()
	accessory_root.name = "城市身份配件"
	accessory_root.set_meta("role", _city_role)
	accessory_root.set_meta("visual_only", true)
	accessory_root.set_meta("candidate_visual_only", true)
	_city_accessory_root = accessory_root
	add_child(accessory_root)
	# 蒙皮资源正常导入时，配件挂到骨骼；如果导入器暂时没有提供骨骼，
	# 仍保留确定性的身份层和一个根节点级标记，避免候选接入在采集前
	# 因契约缺失直接失败。这个降级层只负责视觉，不接管路线、碰撞或任务。
	if _skeleton == null:
		var fallback_material := _material(CITY_ROLE_COLORS.get(_city_role, Color("59656b")), 0.74)
		var fallback_badge := _add_city_box(accessory_root, "城市身份降级标记", Vector3(0.14, 0.08, 0.026), Vector3(0.0, 1.18, -0.28), fallback_material, 0.004)
		fallback_badge.set_meta("visual_only", true)
		fallback_badge.set_meta("candidate_visual_only", true)
		return
	var dark_material := _material(Color("1e2a31"), 0.78)
	var cloth_material := _material(CITY_ROLE_COLORS.get(_city_role, Color("59656b")), 0.74)
	var light_material := _material(Color("d9bd68"), 0.38)

	if _city_role in ["delivery", "worker", "patrol"]:
		var head_attachment := _city_bone_attachment("城市身份头部挂点", "head")
		if head_attachment != null:
			var cap := MeshInstance3D.new()
			cap.name = "城市身份帽体"
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.205
			cap_mesh.bottom_radius = 0.235
			cap_mesh.height = 0.09
			cap.mesh = cap_mesh
			cap.position = Vector3(0.0, 0.145, 0.0)
			cap.material_override = cloth_material
			head_attachment.add_child(cap)
			var brim := MeshInstance3D.new()
			brim.name = "城市身份帽檐"
			var brim_mesh := BoxMesh.new()
			brim_mesh.size = Vector3(0.26, 0.028, 0.14)
			brim.mesh = brim_mesh
			brim.position = Vector3(0.0, 0.10, -0.14)
			brim.material_override = dark_material
			head_attachment.add_child(brim)

	if _city_role == "delivery":
		var delivery_attachment := _city_bone_attachment("配送员肩包挂点", "spine_02")
		if delivery_attachment != null:
			_add_city_box(delivery_attachment, "配送员侧挂包", Vector3(0.25, 0.30, 0.12), Vector3(0.30, -0.08, 0.12), dark_material, 0.035)
			_add_city_box(delivery_attachment, "配送员侧挂包标记", Vector3(0.13, 0.08, 0.026), Vector3(0.30, -0.05, 0.185), light_material, 0.004)
	elif _city_role == "shopper":
		var shopper_attachment := _city_bone_attachment("行人手提袋挂点", "spine_02")
		if shopper_attachment != null:
			_add_city_box(shopper_attachment, "行人手提袋", Vector3(0.23, 0.30, 0.12), Vector3(0.30, -0.16, 0.06), cloth_material, 0.035)
			_add_city_box(shopper_attachment, "行人手提袋提手", Vector3(0.18, 0.035, 0.035), Vector3(0.30, 0.035, 0.06), light_material, 0.008)
	elif _city_role == "worker":
		var worker_attachment := _city_bone_attachment("店员反光背心挂点", "spine_02")
		if worker_attachment != null:
			_add_city_box(worker_attachment, "店员反光背心左条", Vector3(0.035, 0.42, 0.026), Vector3(-0.12, 0.05, -0.26), light_material, 0.004)
			_add_city_box(worker_attachment, "店员反光背心右条", Vector3(0.035, 0.42, 0.026), Vector3(0.12, 0.05, -0.26), light_material, 0.004)
			_add_city_box(worker_attachment, "店员腰部色带", Vector3(0.36, 0.035, 0.026), Vector3(0.0, -0.16, -0.26), light_material, 0.004)
	else:
		var patrol_attachment := _city_bone_attachment("巡查员识别挂点", "spine_02")
		if patrol_attachment != null:
			_add_city_box(patrol_attachment, "巡查员肩部对讲机", Vector3(0.09, 0.15, 0.07), Vector3(-0.24, 0.10, -0.20), dark_material, 0.012)
			_add_city_box(patrol_attachment, "巡查员肩部信号条", Vector3(0.16, 0.028, 0.026), Vector3(0.26, 0.08, -0.26), light_material, 0.004)

func _configure_city_visual_lod() -> void:
	# MakeHuman 蒙皮角色没有依赖导入器自动生成 LOD；在候选包装层统一登记
	# 近景完整细节、远景裁剪边界。这个契约只作用于 GeometryInstance3D，
	# 不触碰行人控制器、碰撞体、路线、感知或任务状态。
	set_meta("visual_lod_end_distance", VISUAL_LOD_END_DISTANCE)
	set_meta("visual_lod_end_margin", VISUAL_LOD_END_MARGIN)
	set_meta("visual_only", true)
	set_meta("candidate_visual_only", true)
	set_meta("city_visual_lod_contract", "near_full_detail_far_culled")
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

func _city_bone_attachment(node_name: String, bone_name: String) -> BoneAttachment3D:
	if _skeleton == null or _skeleton.find_bone(bone_name) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	attachment.bone_name = bone_name
	_skeleton.add_child(attachment)
	return attachment

func _ensure_city_animation_contract() -> void:
	if get_node_or_null("AnimationPlayer") != null:
		return
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	for state_name in ["idle_default", "walk_default", "displaced_default", "hit_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if state_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		library.add_animation(state_name, animation)
	animation_player.add_animation_library("", library)
	add_child(animation_player)
	move_child(animation_player, 0)
	animation_player.play("idle_default")

func drive_candidate_state(state_name: String) -> void:
	super.drive_candidate_state(state_name)
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null and animation_player.has_animation(state_name):
		animation_player.play(state_name)

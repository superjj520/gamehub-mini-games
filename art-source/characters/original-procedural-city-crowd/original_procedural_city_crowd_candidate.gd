extends Node3D

## 原创程序化城市人群候选。
## 这是可替换的视觉资产，不承担路线、碰撞、感知或任务逻辑。
## 所有网格由项目内代码生成，不读取外部 GLB、纹理或商业资产。

const ROLE_ORDER := ["courier", "office_worker", "shopper", "street_vendor"]
const ROLE_COLORS := {
	"courier": Color("3f6874"),
	"office_worker": Color("5d6677"),
	"shopper": Color("796052"),
	"street_vendor": Color("7a6244"),
	"conflict": Color("873e46"),
}
const ROLE_SKIN_COLORS := {
	"courier": Color("b47d68"),
	"office_worker": Color("c18b72"),
	"shopper": Color("9f6b58"),
	"street_vendor": Color("c28a70"),
	"conflict": Color("8f5b4d"),
}
const ROLE_SCALES := {
	"courier": 1.02,
	"office_worker": 0.98,
	"shopper": 0.94,
	"street_vendor": 1.05,
	"conflict": 1.04,
}

var _role := "courier"
var _state := "idle_default"
var _phase := 0.0
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _body: Node3D
var _head: Node3D

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_code_and_node_materials")
	_role = _resolve_role()
	set_meta("city_role", _role)
	set_meta("city_role_scale", float(ROLE_SCALES.get(_role, 1.0)))
	scale = Vector3.ONE * float(ROLE_SCALES.get(_role, 1.0))
	_build_character()
	_build_role_accessories()
	_build_animation_contract()

func _process(delta: float) -> void:
	_phase += delta
	_apply_candidate_pose()

func _resolve_role() -> String:
	var owner := get_parent()
	if owner != null and str(owner.name).contains("冲突"):
		return "conflict"
	var suffix := str(owner.name).get_slice("_", 1) if owner != null else "0"
	var index := int(suffix) if suffix.is_valid_int() else 0
	return ROLE_ORDER[absi(index) % ROLE_ORDER.size()]

func _build_character() -> void:
	var character := Node3D.new()
	character.name = "Character"
	character.set_meta("original_procedural_asset", true)
	add_child(character)

	var jacket_material := _material(ROLE_COLORS.get(_role, Color("59656b")), 0.78)
	var pants_material := _material(Color("303641" if _role != "street_vendor" else "4b4038"), 0.86)
	var skin_material := _material(ROLE_SKIN_COLORS.get(_role, Color("b47d68")), 0.82)
	var hair_material := _material(Color("20232b"), 0.76)
	var shoe_material := _material(Color("252a2c"), 0.90)

	# 人群角色必须先有连续的身体轮廓，再用配件区分身份；避免近景出现横向手臂和积木躯干。
	_body = _capsule(character, "原创程序化上衣", 0.34, 1.04, Vector3(0.0, 0.05, 0.0), jacket_material)
	_body.scale = Vector3(0.88, 1.0, 0.58)
	# 颈部和腰胯把身体从“球形躯干”连成完整的人体轮廓；它们是视觉节点，
	# 不参与城市行人的逻辑碰撞或路线计算。
	_cylinder(character, "原创程序化颈部", 0.11, 0.18, Vector3(0.0, 0.48, 0.0), skin_material)
	var pelvis := _capsule(character, "原创程序化腰胯", 0.28, 0.42, Vector3(0.0, -0.42, 0.0), pants_material)
	pelvis.scale = Vector3(0.95, 0.72, 0.78)
	_left_arm = _capsule(character, "原创程序化左臂", 0.12, 0.72, Vector3(-0.46, 0.0, 0.0), jacket_material)
	_right_arm = _capsule(character, "原创程序化右臂", 0.12, 0.72, Vector3(0.46, 0.0, 0.0), jacket_material)
	_left_arm.rotation_degrees.z = -27.0
	_right_arm.rotation_degrees.z = 27.0
	_capsule(character, "原创程序化左手", 0.095, 0.19, Vector3(-0.56, -0.13, -0.02), skin_material)
	_capsule(character, "原创程序化右手", 0.095, 0.19, Vector3(0.56, -0.13, -0.02), skin_material)
	_sphere(character, "原创程序化左肩", 0.13, Vector3(-0.29, 0.34, 0.0), jacket_material)
	_sphere(character, "原创程序化右肩", 0.13, Vector3(0.29, 0.34, 0.0), jacket_material)
	_head = _capsule(character, "原创程序化头部", 0.205, 0.41, Vector3(0.0, 0.91, 0.0), skin_material)
	var hair := _sphere(character, "原创程序化发型", 0.25, Vector3(0.0, 0.84, -0.02), hair_material)
	hair.scale = Vector3(1.0, 0.38, 0.93)
	# 发际线、耳侧和下巴阴影让近景角色不再只有一个光滑球面。
	_sphere(character, "原创程序化左耳侧发束", 0.075, Vector3(-0.19, 0.87, -0.01), hair_material)
	_sphere(character, "原创程序化右耳侧发束", 0.075, Vector3(0.19, 0.87, -0.01), hair_material)
	_box(character, "原创程序化领口", Vector3(0.30, 0.06, 0.05), Vector3(0.0, 0.34, -0.22), _material(Color("d5c3a3"), 0.62))
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var leg := _capsule(character, "原创程序化" + suffix + "腿", 0.10, 0.68, Vector3(side * 0.15, -0.64, 0.0), pants_material)
		leg.scale = Vector3(0.90, 1.0, 0.78)
		if side < 0.0:
			_left_leg = leg
		else:
			_right_leg = leg
		_box(character, "原创程序化" + suffix + "鞋", Vector3(0.21, 0.10, 0.34), Vector3(side * 0.15, -1.00, -0.06), shoe_material)
		_box(character, "原创程序化" + suffix + "鞋底", Vector3(0.23, 0.04, 0.38), Vector3(side * 0.15, -1.075, -0.06), shoe_material)

func _build_role_accessories() -> void:
	var accessories := Node3D.new()
	accessories.name = "城市身份配件"
	accessories.set_meta("role", _role)
	add_child(accessories)
	var trim := _material(Color("d9bd68"), 0.42)
	var dark := _material(Color("1e2a31"), 0.82)
	var role_color := _material(ROLE_COLORS.get(_role, Color("59656b")), 0.76)
	if _role == "courier":
		_cylinder(accessories, "配送员帽", 0.29, 0.08, Vector3(0.0, 0.92, 0.0), role_color)
		_box(accessories, "配送员肩包", Vector3(0.28, 0.34, 0.14), Vector3(0.34, -0.06, 0.16), dark)
		_box(accessories, "配送员编号", Vector3(0.13, 0.08, 0.03), Vector3(0.12, 0.20, -0.24), trim)
	elif _role == "office_worker":
		_box(accessories, "上班族领带", Vector3(0.11, 0.36, 0.05), Vector3(0.0, 0.05, -0.23), trim)
		_box(accessories, "上班族工牌", Vector3(0.18, 0.14, 0.04), Vector3(0.23, 0.12, -0.23), trim)
	elif _role == "shopper":
		_box(accessories, "居民手提袋", Vector3(0.30, 0.38, 0.18), Vector3(-0.55, -0.30, -0.04), role_color)
		_box(accessories, "居民手提袋提手", Vector3(0.04, 0.25, 0.04), Vector3(-0.55, -0.02, -0.04), trim)
	elif _role == "street_vendor":
		_box(accessories, "摊主围裙", Vector3(0.50, 0.48, 0.04), Vector3(0.0, -0.13, -0.24), trim)
		_cylinder(accessories, "摊主遮阳帽", 0.28, 0.10, Vector3(0.0, 0.92, 0.0), role_color)
	else:
		_box(accessories, "冲突对象警示带", Vector3(0.76, 0.12, 0.46), Vector3(0.0, 0.10, -0.02), _material(Color("e05252"), 0.66))
		_cylinder(accessories, "冲突对象警示标记", 0.16, 0.06, Vector3(0.0, 1.02, 0.0), trim)

	var visual_accessories := Node3D.new()
	visual_accessories.name = "候选人群视觉配件"
	visual_accessories.set_meta("source_candidate", "original_procedural_city_crowd")
	visual_accessories.set_meta("city_role", _role)
	add_child(visual_accessories)

	# 统一补齐远近景都能读到的服装边界；这些节点只属于视觉层，不创建碰撞、导航或感知状态。
	var seam := _material(Color("d7c5a0"), 0.56)
	var clothing_trim := _material(ROLE_COLORS.get(_role, Color("59656b")).lightened(0.16), 0.70)
	_box(visual_accessories, "人群上衣领口", Vector3(0.28, 0.055, 0.045), Vector3(0.0, 0.34, -0.22), seam)
	_box(visual_accessories, "人群左袖口", Vector3(0.045, 0.16, 0.18), Vector3(-0.46, -0.02, -0.02), clothing_trim)
	_box(visual_accessories, "人群右袖口", Vector3(0.045, 0.16, 0.18), Vector3(0.46, -0.02, -0.02), clothing_trim)
	_box(visual_accessories, "人群左鞋面侧条", Vector3(0.05, 0.055, 0.30), Vector3(-0.18, -1.08, -0.23), seam)
	_box(visual_accessories, "人群右鞋面侧条", Vector3(0.05, 0.055, 0.30), Vector3(0.18, -1.08, -0.23), seam)
	var strap := _box(visual_accessories, "人群斜挎背带", Vector3(0.045, 0.62, 0.035), Vector3(-0.25, 0.02, -0.23), clothing_trim)
	strap.rotation_degrees.z = -18.0
	var skin_detail := _material(ROLE_SKIN_COLORS.get(_role, Color("b47d68")).lightened(0.12), 0.84)
	var shoe_detail := _material(Color("56636a"), 0.78)
	_box(visual_accessories, "人群颈部衣领", Vector3(0.18, 0.12, 0.18), Vector3(0.0, 0.47, 0.0), skin_detail)
	_box(visual_accessories, "人群外套下摆", Vector3(0.58, 0.045, 0.36), Vector3(0.0, -0.34, -0.01), clothing_trim)
	_box(visual_accessories, "人群裤腰边线", Vector3(0.44, 0.045, 0.28), Vector3(0.0, -0.32, -0.02), seam)
	_box(visual_accessories, "人群左鞋面高光", Vector3(0.18, 0.035, 0.16), Vector3(-0.18, -1.12, -0.13), shoe_detail)
	_box(visual_accessories, "人群右鞋面高光", Vector3(0.18, 0.035, 0.16), Vector3(0.18, -1.12, -0.13), shoe_detail)
	_box(visual_accessories, "人群左鞋带", Vector3(0.16, 0.018, 0.026), Vector3(-0.18, -1.09, -0.255), seam)
	_box(visual_accessories, "人群右鞋带", Vector3(0.16, 0.018, 0.026), Vector3(0.18, -1.09, -0.255), seam)
	_box(visual_accessories, "人群左肩缝线", Vector3(0.20, 0.018, 0.026), Vector3(-0.30, 0.31, -0.215), clothing_trim)
	_box(visual_accessories, "人群右肩缝线", Vector3(0.20, 0.018, 0.026), Vector3(0.30, 0.31, -0.215), clothing_trim)
	_sphere(visual_accessories, "人群左眼", 0.018, Vector3(-0.075, 0.73, -0.225), _material(Color("171b21"), 0.52))
	_sphere(visual_accessories, "人群右眼", 0.018, Vector3(0.075, 0.73, -0.225), _material(Color("171b21"), 0.52))
	_box(visual_accessories, "人群眉线-左", Vector3(0.09, 0.018, 0.022), Vector3(-0.075, 0.765, -0.226), dark)
	_box(visual_accessories, "人群眉线-右", Vector3(0.09, 0.018, 0.022), Vector3(0.075, 0.765, -0.226), dark)
	if _role == "courier":
		_box(visual_accessories, "配送员背包外壳", Vector3(0.38, 0.50, 0.14), Vector3(0.0, -0.03, 0.22), dark)
		_box(visual_accessories, "配送员背包反光条", Vector3(0.24, 0.045, 0.025), Vector3(0.0, 0.02, 0.145), trim)

func _build_animation_contract() -> void:
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
	animation_player.play(_state)

func drive_candidate_state(state_name: String) -> void:
	_state = state_name
	var animation_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null and animation_player.has_animation(state_name):
		animation_player.play(state_name)

func _apply_candidate_pose() -> void:
	if _left_arm == null:
		return
	# 近景人群保留轻微呼吸、肩线和视线变化；所有变化都局限在表现节点。
	var idle_sway := sin(_phase * 1.35 + float(get_instance_id() % 17))
	if _body != null:
		_body.rotation_degrees = Vector3(0.0, idle_sway * 0.8, idle_sway * 0.55)
	if _head != null:
		_head.rotation_degrees = Vector3(sin(_phase * 1.1 + 0.7) * 0.8, idle_sway * 2.2, 0.0)
	var wave := sin(_phase * 6.0) if _state == "walk_default" else 0.0
	# 胳膊围绕自然下垂基线摆动，步行时仍有节奏但不会回到 T 形姿态。
	_left_arm.rotation_degrees = Vector3(0.0, 0.0, -49.0 + wave * 8.0)
	_right_arm.rotation_degrees = Vector3(0.0, 0.0, 49.0 - wave * 8.0)
	if _state == "walk_default":
		_left_leg.rotation_degrees.x = rad_to_deg(0.28 * wave)
		_right_leg.rotation_degrees.x = rad_to_deg(-0.28 * wave)
	else:
		_left_leg.rotation_degrees.x = 0.0
		_right_leg.rotation_degrees.x = 0.0

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.set_meta("original_procedural_asset", true)
	return material

func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	parent.add_child(node)
	return node

func _capsule(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	mesh.rings = 8
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, node_name: String, radius: float, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	parent.add_child(node)
	return node

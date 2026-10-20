extends Node3D

## 原创程序化城市人群候选。
## 这是正式运行时的内部可玩视觉候选，不承担路线、碰撞、感知或任务逻辑。
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
const VISUAL_LOD_END_DISTANCE := 48.0
const VISUAL_LOD_END_MARGIN := 4.0

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
	set_meta("visual_lod_end_distance", VISUAL_LOD_END_DISTANCE)
	set_meta("visual_lod_end_margin", VISUAL_LOD_END_MARGIN)
	_role = _resolve_role()
	set_meta("city_role", _role)
	set_meta("city_role_scale", float(ROLE_SCALES.get(_role, 1.0)))
	scale = Vector3.ONE * float(ROLE_SCALES.get(_role, 1.0))
	_build_character()
	_build_role_accessories()
	_build_role_surface_details()
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

	var jacket_material := _material(ROLE_COLORS.get(_role, Color("59656b")), 0.90)
	var pants_material := _material(Color("303641" if _role != "street_vendor" else "4b4038"), 0.94)
	var skin_material := _material(ROLE_SKIN_COLORS.get(_role, Color("b47d68")), 0.88)
	var hair_material := _material(Color("20232b"), 0.92)
	var shoe_material := _material(Color("252a2c"), 0.96)
	var accent_material := _material(Color("e7e1d6" if _role == "office_worker" else "d9bd68"), 0.82)
	var eye_material := _material(Color("17191d"), 0.70)
	var mouth_material := _material(Color("5b3030"), 0.84)

	# 角色表现层使用连续软轮廓和自然下垂的手臂，避免远景出现“横向
	# 十字架人群”。这些位置只影响渲染，不改变行人节点的路线和碰撞。
	_body = _scaled_capsule(character, "原创程序化上衣", 0.34, 1.04, Vector3(0.0, 0.05, 0.0), jacket_material, Vector3(0.88, 1.0, 0.58))
	_cylinder(character, "原创程序化颈部", 0.11, 0.16, Vector3(0.0, 0.61, 0.0), skin_material)
	_left_arm = _capsule(character, "原创程序化左臂", 0.095, 0.58, Vector3(-0.43, 0.13, 0.0), jacket_material)
	_right_arm = _capsule(character, "原创程序化右臂", 0.095, 0.58, Vector3(0.43, 0.13, 0.0), jacket_material)
	_left_arm.rotation_degrees.z = -27.0
	_right_arm.rotation_degrees.z = 27.0
	_capsule(character, "原创程序化左手", 0.095, 0.19, Vector3(-0.56, -0.13, -0.02), skin_material)
	_capsule(character, "原创程序化右手", 0.095, 0.19, Vector3(0.56, -0.13, -0.02), skin_material)
	_sphere(character, "原创程序化左肩", 0.13, Vector3(-0.29, 0.34, 0.0), jacket_material)
	_sphere(character, "原创程序化右肩", 0.13, Vector3(0.29, 0.34, 0.0), jacket_material)
	_box(character, "原创程序化左袖口", Vector3(0.13, 0.075, 0.15), Vector3(-0.53, -0.10, 0.0), accent_material)
	_box(character, "原创程序化右袖口", Vector3(0.13, 0.075, 0.15), Vector3(0.53, -0.10, 0.0), accent_material)
	_head = _capsule(character, "原创程序化头部", 0.205, 0.41, Vector3(0.0, 0.91, 0.0), skin_material)
	for side in [-1.0, 1.0]:
		_sphere(character, "原创程序化耳部细节-" + ("左" if side < 0.0 else "右"), 0.060, Vector3(side * 0.182, 0.92, -0.01), skin_material)
	var nose := _capsule(character, "原创程序化鼻部细节", 0.040, 0.09, Vector3(0.0, 0.91, -0.208), skin_material)
	nose.rotation_degrees.x = 90.0
	_box(character, "原创程序化嘴部细节", Vector3(0.10, 0.022, 0.016), Vector3(0.0, 0.82, -0.212), mouth_material)
	var hair := _sphere(character, "原创程序化发型", 0.215, Vector3(0.0, 1.075, -0.02), hair_material)
	hair.scale = Vector3(1.0, 0.38, 0.93)
	_box(character, "原创程序化胸前服装层", Vector3(0.30, 0.46, 0.03), Vector3(0.0, 0.12, -0.215), accent_material)
	_box(character, "原创程序化领口", Vector3(0.19, 0.085, 0.038), Vector3(0.0, 0.43, -0.225), accent_material)
	_box(character, "原创程序化左前襟", Vector3(0.045, 0.21, 0.022), Vector3(-0.105, 0.27, -0.235), accent_material)
	_box(character, "原创程序化右前襟", Vector3(0.045, 0.21, 0.022), Vector3(0.105, 0.27, -0.235), accent_material)
	_box(character, "原创程序化夹克下摆", Vector3(0.48, 0.12, 0.26), Vector3(0.0, -0.31, 0.0), jacket_material)
	_box(character, "原创程序化腰带", Vector3(0.44, 0.055, 0.03), Vector3(0.0, -0.38, -0.19), accent_material)
	_box(character, "原创程序化发型后片", Vector3(0.34, 0.17, 0.10), Vector3(0.0, 0.90, 0.13), hair_material)
	for side in [-1.0, 1.0]:
		_sphere(character, "原创程序化眼部细节", 0.026, Vector3(side * 0.072, 0.95, -0.19), eye_material)
		var suffix := "左" if side < 0.0 else "右"
		var leg := _scaled_capsule(character, "原创程序化" + suffix + "腿", 0.10, 0.68, Vector3(side * 0.15, -0.64, 0.0), pants_material, Vector3(0.90, 1.0, 0.78))
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
		_box(accessories, "配送员反光胸带", Vector3(0.54, 0.045, 0.025), Vector3(0.0, -0.02, -0.26), trim)
	elif _role == "office_worker":
		_box(accessories, "上班族领带", Vector3(0.11, 0.36, 0.05), Vector3(0.0, 0.05, -0.23), trim)
		_box(accessories, "上班族工牌", Vector3(0.18, 0.14, 0.04), Vector3(0.23, 0.12, -0.23), trim)
		_box(accessories, "上班族眼镜左框", Vector3(0.095, 0.045, 0.018), Vector3(-0.07, 0.84, -0.248), dark)
		_box(accessories, "上班族眼镜右框", Vector3(0.095, 0.045, 0.018), Vector3(0.07, 0.84, -0.248), dark)
		_box(accessories, "上班族眼镜鼻梁", Vector3(0.055, 0.018, 0.018), Vector3(0.0, 0.84, -0.248), dark)
	elif _role == "shopper":
		_box(accessories, "居民手提袋", Vector3(0.30, 0.38, 0.18), Vector3(-0.55, -0.30, -0.04), role_color)
		_box(accessories, "居民手提袋提手", Vector3(0.04, 0.25, 0.04), Vector3(-0.55, -0.02, -0.04), trim)
		_box(accessories, "居民斜挎带", Vector3(0.055, 0.76, 0.035), Vector3(0.27, 0.03, -0.25), trim)
	elif _role == "street_vendor":
		_box(accessories, "摊主围裙", Vector3(0.50, 0.48, 0.04), Vector3(0.0, -0.13, -0.24), trim)
		_cylinder(accessories, "摊主遮阳帽", 0.28, 0.10, Vector3(0.0, 0.92, 0.0), role_color)
		_box(accessories, "摊主围裙口袋", Vector3(0.18, 0.12, 0.025), Vector3(0.0, -0.14, -0.265), dark)
	else:
		_box(accessories, "冲突对象警示带", Vector3(0.76, 0.12, 0.46), Vector3(0.0, 0.10, -0.02), _material(Color("e05252"), 0.66))
		_cylinder(accessories, "冲突对象警示标记", 0.16, 0.06, Vector3(0.0, 1.02, 0.0), trim)

	var visual_accessories := Node3D.new()
	visual_accessories.name = "候选人群视觉配件"
	visual_accessories.set_meta("source_candidate", "original_procedural_city_crowd")
	visual_accessories.set_meta("city_role", _role)
	add_child(visual_accessories)

func _build_role_surface_details() -> void:
	# 人群近景需要看出“这是一个具体的人”，而不是只有颜色不同的胶囊。
	# 这些网格全部属于表现层，不改变行人路线、碰撞、感知或任务状态。
	var seam := _material(Color("222932"), 0.78)
	var light_trim := _material(Color("b8b4a1"), 0.54)
	var role_color := _material(ROLE_COLORS.get(_role, Color("59656b")), 0.70)
	var dark := _material(Color("1e252b"), 0.84)
	var character := get_node_or_null("Character") as Node3D
	if character == null:
		return
	_box(character, "原创程序化胸口缝线", Vector3(0.018, 0.34, 0.016), Vector3(0.0, 0.10, -0.235), seam)
	_box(character, "原创程序化左裤线", Vector3(0.016, 0.46, 0.016), Vector3(-0.15, -0.65, -0.12), seam)
	_box(character, "原创程序化右裤线", Vector3(0.016, 0.46, 0.016), Vector3(0.15, -0.65, -0.12), seam)
	_box(character, "原创程序化左鞋带", Vector3(0.13, 0.018, 0.024), Vector3(-0.15, -0.99, -0.245), light_trim)
	_box(character, "原创程序化右鞋带", Vector3(0.13, 0.018, 0.024), Vector3(0.15, -0.99, -0.245), light_trim)
	_box(character, "原创程序化左眉线", Vector3(0.060, 0.014, 0.014), Vector3(-0.072, 1.005, -0.205), dark)
	_box(character, "原创程序化右眉线", Vector3(0.060, 0.014, 0.014), Vector3(0.072, 1.005, -0.205), dark)

	match _role:
		"courier":
			_box(character, "配送员手持扫码器", Vector3(0.10, 0.16, 0.06), Vector3(-0.57, -0.19, -0.12), dark)
			_box(character, "配送员扫码器状态灯", Vector3(0.028, 0.028, 0.010), Vector3(-0.57, -0.15, -0.155), light_trim)
			_box(character, "配送员包体分格", Vector3(0.16, 0.018, 0.018), Vector3(0.34, -0.06, 0.235), role_color)
		"office_worker":
			_box(character, "上班族袖口缝线-左", Vector3(0.13, 0.018, 0.018), Vector3(-0.53, -0.10, -0.085), light_trim)
			_box(character, "上班族袖口缝线-右", Vector3(0.13, 0.018, 0.018), Vector3(0.53, -0.10, -0.085), light_trim)
			_box(character, "上班族胸牌夹", Vector3(0.045, 0.08, 0.022), Vector3(0.23, 0.22, -0.255), dark)
		"shopper":
			_box(character, "居民手提袋标记", Vector3(0.12, 0.08, 0.018), Vector3(-0.55, -0.30, -0.135), light_trim)
			_box(character, "居民手提袋侧缝", Vector3(0.018, 0.26, 0.018), Vector3(-0.70, -0.30, -0.04), dark)
		"street_vendor":
			_box(character, "摊主围裙肩带-左", Vector3(0.045, 0.40, 0.022), Vector3(-0.17, 0.10, -0.255), role_color)
			_box(character, "摊主围裙肩带-右", Vector3(0.045, 0.40, 0.022), Vector3(0.17, 0.10, -0.255), role_color)
			_box(character, "摊主胸前毛巾", Vector3(0.16, 0.10, 0.025), Vector3(0.18, 0.22, -0.265), light_trim)
		"conflict":
			_box(character, "冲突对象肩部警示片-左", Vector3(0.16, 0.10, 0.035), Vector3(-0.30, 0.34, -0.13), role_color)
			_box(character, "冲突对象肩部警示片-右", Vector3(0.16, 0.10, 0.035), Vector3(0.30, 0.34, -0.13), role_color)

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
	# 近景人群不能像一排静态模型：保留很小的呼吸、肩线和视线变化，
	# 只改变表现节点，不改变行人路线、碰撞、感知或任务状态。
	var idle_sway := sin(_phase * 1.35 + float(get_instance_id() % 17))
	if _body != null:
		_body.rotation_degrees = Vector3(0.0, idle_sway * 0.8, idle_sway * 0.55)
	if _head != null:
		_head.rotation_degrees = Vector3(sin(_phase * 1.1 + 0.7) * 0.8, idle_sway * 2.2, 0.0)
	var wave := sin(_phase * 6.0) if _state == "walk_default" else 0.0
	# 胳膊围绕自然下垂基线摆动，保留步行动势但不回到 T 形姿态。
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
	_configure_visual_lod(node)
	parent.add_child(node)
	return node

func _capsule(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	_configure_visual_lod(node)
	parent.add_child(node)
	return node

func _scaled_capsule(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: StandardMaterial3D, scale: Vector3) -> MeshInstance3D:
	var node := _capsule(parent, node_name, radius, height, at, material)
	node.scale = scale
	return node

func _sphere(parent: Node3D, node_name: String, radius: float, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	_configure_visual_lod(node)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	_configure_visual_lod(node)
	parent.add_child(node)
	return node

func _configure_visual_lod(node: GeometryInstance3D) -> void:
	# 城市人群是纯表现层；远距离不再提交全部面片，同时保留近景固定镜头
	# 的完整细节。该属性不影响路线、碰撞、感知或任务状态。
	node.visibility_range_end = VISUAL_LOD_END_DISTANCE
	node.visibility_range_end_margin = VISUAL_LOD_END_MARGIN
	node.set_meta("visual_lod_end_distance", VISUAL_LOD_END_DISTANCE)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)

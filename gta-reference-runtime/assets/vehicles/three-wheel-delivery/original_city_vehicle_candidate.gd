extends Node3D

## 正式城市运行时的原创三轮配送车候选包装。
## 只负责视觉材质、灯光和候选损伤面板，不接管载具移动、碰撞或任务逻辑。

var damage_overlay: MeshInstance3D
var damage_scratch_left: MeshInstance3D
var damage_scratch_right: MeshInstance3D
var damage_warning_light: MeshInstance3D
var damage_smoke: GPUParticles3D
var headlight_glow: OmniLight3D
var ground_contact_shadows: Array[MeshInstance3D] = []

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_vehicle_wrapper_over_generated_mesh")
	set_meta("vehicle_candidate_role", "city_three_wheel_delivery")
	_build_candidate_body_details()
	_build_candidate_reflective_details()
	_build_candidate_lighting()
	_build_candidate_damage_overlay()
	_build_ground_contact_shadows()

func _process(_delta: float) -> void:
	_update_candidate_feedback()

func set_candidate_damage_state(integrity: float) -> void:
	_apply_candidate_feedback(integrity)

func _build_candidate_body_details() -> void:
	# 只补充载具可见轮廓和货架细节；这些节点不加入碰撞层，也不改变驾驶挂点。
	var body := _material(Color("244a62"), 0.48, 0.18)
	var trim := _material(Color("b6c4c7"), 0.38, 0.42)
	var dark := _material(Color("1c252b"), 0.72, 0.08)
	var cargo := _material(Color("a87945"), 0.82)
	var accent := _material(Color("4f8aa0"), 0.46, 0.16)
	var seat_material := _material(Color("3b2d2a"), 0.74)
	var seat_pad := _material(Color("574341"), 0.66, 0.02)
	var rubber := _material(Color("11171a"), 0.92, 0.02)
	var turn_signal := _tail_light_material(Color("e08a3a"))
	var plate := _material(Color("d9d5c1"), 0.52, 0.18)
	var strap := _material(Color("392f29"), 0.86)
	var glass := _glass_material()
	var headlight := _tail_light_material(Color("f4d28b"))
	_add_box("候选三轮车顶棚", Vector3(1.18, 0.08, 0.92), Vector3(0.0, 1.62, 0.26), body)
	_add_box("候选三轮车前挡风框", Vector3(1.02, 0.06, 0.08), Vector3(0.0, 1.20, -0.42), trim)
	_add_box("候选三轮车前挡风玻璃", Vector3(0.92, 0.025, 0.54), Vector3(0.0, 1.40, -0.39), glass)
	_add_box("候选三轮车驾驶台", Vector3(0.76, 0.08, 0.30), Vector3(0.0, 1.02, -0.54), dark)
	_add_box("候选三轮车驾驶台饰条", Vector3(0.60, 0.035, 0.035), Vector3(0.0, 1.08, -0.70), accent)
	_add_box("候选三轮车座椅坐垫", Vector3(0.68, 0.10, 0.54), Vector3(0.0, 0.96, 0.16), seat_material)
	# 座椅中间的明暗分层和前沿只用于读出驾驶员落座位置，不改变驾驶挂点或碰撞。
	_add_box("候选三轮车座椅坐垫高光", Vector3(0.56, 0.035, 0.42), Vector3(0.0, 1.025, 0.16), seat_pad)
	_add_box("候选三轮车座椅前沿", Vector3(0.62, 0.05, 0.06), Vector3(0.0, 1.015, -0.12), seat_pad)
	_add_box("候选三轮车座椅靠背", Vector3(0.68, 0.42, 0.10), Vector3(0.0, 1.16, 0.42), seat_material)
	_add_box("候选三轮车方向盘", Vector3(0.46, 0.045, 0.045), Vector3(0.0, 1.28, -0.76), trim)
	_add_cylinder("候选三轮车方向盘轮圈", Vector3(0.0, 1.28, -0.76), 0.18, 0.035, trim, Vector3(90.0, 0.0, 0.0))
	_add_box("候选三轮车脚踏板", Vector3(0.62, 0.045, 0.28), Vector3(0.0, 0.56, -0.58), dark)
	_add_box("候选三轮车仪表屏", Vector3(0.24, 0.12, 0.025), Vector3(0.0, 1.18, -0.72), accent)
	_add_box("候选三轮车左前灯", Vector3(0.18, 0.12, 0.05), Vector3(-0.34, 0.88, -1.16), headlight)
	_add_box("候选三轮车右前灯", Vector3(0.18, 0.12, 0.05), Vector3(0.34, 0.88, -1.16), headlight)
	_add_box("候选三轮车左后视镜", Vector3(0.08, 0.08, 0.22), Vector3(-0.64, 1.22, -0.38), trim)
	_add_box("候选三轮车右后视镜", Vector3(0.08, 0.08, 0.22), Vector3(0.64, 1.22, -0.38), trim)
	_add_box("候选三轮车左后视镜支臂", Vector3(0.035, 0.035, 0.32), Vector3(-0.62, 1.18, -0.28), trim)
	_add_box("候选三轮车右后视镜支臂", Vector3(0.035, 0.035, 0.32), Vector3(0.62, 1.18, -0.28), trim)
	_add_box("候选三轮车左转向灯", Vector3(0.10, 0.08, 0.045), Vector3(-0.52, 0.88, -1.15), turn_signal)
	_add_box("候选三轮车右转向灯", Vector3(0.10, 0.08, 0.045), Vector3(0.52, 0.88, -1.15), turn_signal)
	_add_box("候选三轮车左把手胶套", Vector3(0.18, 0.06, 0.06), Vector3(-0.35, 1.28, -0.76), rubber)
	_add_box("候选三轮车右把手胶套", Vector3(0.18, 0.06, 0.06), Vector3(0.35, 1.28, -0.76), rubber)
	_add_box("候选三轮车左侧裙", Vector3(0.08, 0.32, 0.78), Vector3(-0.72, 0.48, 0.02), body)
	_add_box("候选三轮车右侧裙", Vector3(0.08, 0.32, 0.78), Vector3(0.72, 0.48, 0.02), body)
	_add_box("候选三轮车左侧挡泥板", Vector3(0.10, 0.18, 0.72), Vector3(-0.92, 0.36, 0.28), dark)
	_add_box("候选三轮车右侧挡泥板", Vector3(0.10, 0.18, 0.72), Vector3(0.92, 0.36, 0.28), dark)
	for x in [-0.55, 0.55]:
		_add_cylinder("候选三轮车篷架支柱", Vector3(x, 1.34, 0.26), 0.035, 0.58, trim)
	for x in [-0.42, 0.0, 0.42]:
		_add_box("候选三轮车货架横梁", Vector3(0.08, 0.08, 0.92), Vector3(x, 1.10, 0.66), trim)
	_add_box("候选三轮车货架", Vector3(1.02, 0.07, 0.10), Vector3(0.0, 1.16, 0.66), trim)
	for x in [-0.30, 0.30]:
		_add_box("候选三轮车货箱", Vector3(0.42, 0.34, 0.34), Vector3(x, 1.02, 0.68), cargo)
	_add_box("候选三轮车货箱左固定带", Vector3(0.055, 0.40, 0.08), Vector3(-0.30, 1.22, 0.68), strap)
	_add_box("候选三轮车货箱右固定带", Vector3(0.055, 0.40, 0.08), Vector3(0.30, 1.22, 0.68), strap)
	_add_box("候选三轮车货箱中缝", Vector3(0.045, 0.30, 0.035), Vector3(0.0, 1.02, 0.86), trim)
	_add_box("候选三轮车后尾灯", Vector3(0.34, 0.10, 0.06), Vector3(0.0, 0.85, 1.28), _tail_light_material(Color("b6423c")))
	_add_box("候选三轮车后牌照", Vector3(0.34, 0.14, 0.025), Vector3(0.0, 0.74, 1.30), plate)
	_add_cylinder("候选三轮车前轮毂", Vector3(0.0, 0.38, -0.96), 0.13, 0.035, trim, Vector3(0.0, 0.0, 90.0))
	_add_cylinder("候选三轮车左后轮毂", Vector3(-0.88, 0.38, 0.70), 0.13, 0.035, trim, Vector3(0.0, 0.0, 90.0))
	_add_cylinder("候选三轮车右后轮毂", Vector3(0.88, 0.38, 0.70), 0.13, 0.035, trim, Vector3(0.0, 0.0, 90.0))
	_add_cylinder("候选三轮车前轮胎侧壁", Vector3(0.0, 0.38, -0.98), 0.26, 0.055, rubber, Vector3(0.0, 0.0, 90.0))
	_add_cylinder("候选三轮车左后轮胎侧壁", Vector3(-0.90, 0.38, 0.70), 0.26, 0.055, rubber, Vector3(0.0, 0.0, 90.0))
	_add_cylinder("候选三轮车右后轮胎侧壁", Vector3(0.90, 0.38, 0.70), 0.26, 0.055, rubber, Vector3(0.0, 0.0, 90.0))

func _build_candidate_reflective_details() -> void:
	# 参考帧的后视角需要在运动中读出尾部宽度、货斗边界和车轮落点；
	# 这些节点只补充可见轮廓，不加入碰撞、输入、导航或载具数值。
	var metal := _material(Color("9ca9ad"), 0.34, 0.48)
	var dark := _material(Color("20272c"), 0.78, 0.05)
	var amber := _tail_light_material(Color("e7a243"))
	var red := _tail_light_material(Color("c43f43"))
	_add_box("候选三轮车后挡板", Vector3(1.24, 0.42, 0.07), Vector3(0.0, 0.54, 1.30), dark)
	_add_box("候选三轮车后挡板反光带", Vector3(0.92, 0.06, 0.025), Vector3(0.0, 0.66, 1.345), amber)
	_add_box("候选三轮车后牌照", Vector3(0.34, 0.16, 0.025), Vector3(0.0, 0.50, 1.35), metal)
	_add_box("候选三轮车左尾灯组", Vector3(0.18, 0.14, 0.05), Vector3(-0.48, 0.72, 1.34), red)
	_add_box("候选三轮车右尾灯组", Vector3(0.18, 0.14, 0.05), Vector3(0.48, 0.72, 1.34), red)
	_add_box("候选三轮车货斗后固定带", Vector3(1.04, 0.045, 0.045), Vector3(0.0, 1.36, 1.08), amber)
	_add_box("候选三轮车底盘后防护条", Vector3(1.20, 0.08, 0.08), Vector3(0.0, 0.28, 1.36), metal)
	_add_box("候选三轮车左后挡泥片", Vector3(0.08, 0.18, 0.34), Vector3(-0.88, 0.18, 0.92), dark)
	_add_box("候选三轮车右后挡泥片", Vector3(0.08, 0.18, 0.34), Vector3(0.88, 0.18, 0.92), dark)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.set_meta("original_procedural_asset", true)
	return material

func _tail_light_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.42, 0.12)
	material.emission_enabled = true
	material.emission = color.darkened(0.25)
	material.emission_energy_multiplier = 0.45
	return material

func _glass_material() -> StandardMaterial3D:
	var material := _material(Color("739ba3"), 0.18, 0.08)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.30
	material.metallic_specular = 0.78
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
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
	add_child(node)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _build_candidate_lighting() -> void:
	var headlight := find_child("候选三轮车前灯", true, false) as Node3D
	if headlight == null:
		return
	headlight_glow = OmniLight3D.new()
	headlight_glow.name = "候选前灯光晕"
	headlight_glow.light_color = Color("ffdca1")
	headlight_glow.light_energy = 0.42
	headlight_glow.omni_range = 3.0
	headlight_glow.position = headlight.position + Vector3(0.0, 0.0, -0.12)
	add_child(headlight_glow)

func _build_candidate_damage_overlay() -> void:
	damage_overlay = MeshInstance3D.new()
	damage_overlay.name = "候选三轮车损伤面板"
	var panel := BoxMesh.new()
	panel.size = Vector3(1.08, 0.05, 0.08)
	damage_overlay.mesh = panel
	damage_overlay.position = Vector3(0.0, 1.18, -1.30)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("741f25")
	material.emission_enabled = true
	material.emission = Color("2b0808")
	material.emission_energy_multiplier = 0.35
	damage_overlay.material_override = material
	damage_overlay.visible = false
	damage_overlay.set_meta("original_procedural_asset", true)
	damage_overlay.set_meta("visual_only", true)
	damage_overlay.set_meta("candidate_visual_only", true)
	add_child(damage_overlay)

	# 分级损伤只表达已经发生的碰撞结果，不写入载具耐久，也不参与碰撞。
	# 左右刮痕和后部警示灯让 city-08 至 city-10 的驾驶反馈能被固定镜头读到，
	# 同时保持与最终候选包装器一致的节点语义。
	var scratch_material := _material(Color("6f2830"), 0.62, 0.0)
	scratch_material.emission_enabled = true
	scratch_material.emission = Color("27080c")
	scratch_material.emission_energy_multiplier = 0.18
	damage_scratch_left = _make_damage_detail(
		"候选三轮车损伤刮痕-左",
		Vector3(0.10, 0.035, 0.72),
		Vector3(-0.76, 0.20, -0.04),
		scratch_material,
	)
	damage_scratch_right = _make_damage_detail(
		"候选三轮车损伤刮痕-右",
		Vector3(0.10, 0.035, 0.72),
		Vector3(0.76, 0.20, -0.04),
		scratch_material,
	)
	var warning_material := _material(Color("d16b3d"), 0.36, 0.0)
	warning_material.emission_enabled = true
	warning_material.emission = Color("5b1609")
	warning_material.emission_energy_multiplier = 0.65
	damage_warning_light = _make_damage_detail(
		"候选三轮车损伤警示灯",
		Vector3(0.18, 0.12, 0.05),
		Vector3(0.0, 0.68, 1.37),
		warning_material,
	)
	_build_damage_smoke()

func _build_damage_smoke() -> void:
	# 烟雾只表达车辆已经受损的视觉反馈，不参与碰撞、驾驶、导航或任务状态。
	# 用原生粒子材质生成低密度灰烟，避免引入外部纹理和第三方特效依赖。
	damage_smoke = GPUParticles3D.new()
	damage_smoke.name = "候选三轮车损伤烟雾"
	damage_smoke.amount = 18
	damage_smoke.lifetime = 1.35
	damage_smoke.preprocess = 0.35
	damage_smoke.emitting = false
	damage_smoke.local_coords = true
	damage_smoke.visibility_aabb = AABB(Vector3(-0.75, 0.7, 0.3), Vector3(1.5, 2.0, 1.1))
	damage_smoke.position = Vector3(0.0, 0.95, 0.98)
	damage_smoke.set_meta("original_procedural_asset", true)
	damage_smoke.set_meta("visual_only", true)
	damage_smoke.set_meta("candidate_visual_only", true)
	damage_smoke.set_meta("feedback_layer", "vehicle_damage")
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radial_segments = 8
	smoke_mesh.rings = 4
	smoke_mesh.radius = 0.10
	smoke_mesh.height = 0.20
	var smoke_material := StandardMaterial3D.new()
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.albedo_color = Color(0.25, 0.28, 0.29, 0.34)
	smoke_material.emission_enabled = true
	smoke_material.emission = Color(0.08, 0.09, 0.09)
	smoke_material.emission_energy_multiplier = 0.12
	smoke_mesh.material = smoke_material
	damage_smoke.draw_pass_1 = smoke_mesh
	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0.0, 1.0, 0.0)
	particle_material.spread = 18.0
	particle_material.initial_velocity_min = 0.22
	particle_material.initial_velocity_max = 0.48
	particle_material.gravity = Vector3(0.0, 0.12, 0.0)
	particle_material.scale_min = 0.55
	particle_material.scale_max = 1.05
	damage_smoke.process_material = particle_material
	add_child(damage_smoke)

func _build_ground_contact_shadows() -> void:
	# 软阴影只表达三只轮胎与路面的接触，不创建碰撞，也不参与车辆逻辑。
	# 使用正式候选场景中的接触挂点，避免车辆模型缩放或换装后阴影漂移。
	var shadow_material := _soft_shadow_material()
	for contact_name in ["前轮接触点", "左后轮接触点", "右后轮接触点"]:
		var contact := get_node_or_null(NodePath(contact_name)) as Node3D
		if contact == null:
			continue
		var shadow := MeshInstance3D.new()
		shadow.name = "候选三轮车软接触阴影-%s" % contact_name
		var quad := QuadMesh.new()
		quad.size = Vector2(0.92, 0.48) if contact_name == "前轮接触点" else Vector2(0.74, 0.46)
		shadow.mesh = quad
		shadow.rotation_degrees.x = -90.0
		shadow.position = contact.position + Vector3.UP * 0.012
		shadow.material_override = shadow_material
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		shadow.set_meta("original_procedural_asset", true)
		shadow.set_meta("visual_only", true)
		shadow.set_meta("candidate_visual_only", true)
		shadow.set_meta("ground_contact_visual", true)
		add_child(shadow)
		ground_contact_shadows.append(shadow)

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

func _update_candidate_feedback() -> void:
	_apply_candidate_feedback(_read_vehicle_integrity())

func _apply_candidate_feedback(integrity: float) -> void:
	if damage_overlay != null:
		damage_overlay.visible = integrity < 100.0
		if damage_overlay.material_override is StandardMaterial3D:
			var material := damage_overlay.material_override as StandardMaterial3D
			material.emission_energy_multiplier = clampf((100.0 - integrity) / 45.0, 0.35, 1.6)
	if damage_scratch_left != null:
		damage_scratch_left.visible = integrity < 86.0
	if damage_scratch_right != null:
		damage_scratch_right.visible = integrity < 66.0
	if damage_warning_light != null:
		damage_warning_light.visible = integrity < 52.0
	if damage_smoke != null:
		damage_smoke.emitting = integrity < 72.0
		damage_smoke.amount_ratio = clampf((86.0 - integrity) / 34.0, 0.0, 1.0)

func _make_damage_detail(node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.visible = false
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)
	return node

func _read_vehicle_integrity() -> float:
	var cursor: Node = self
	while cursor != null:
		var value = cursor.get("vehicle_integrity")
		if value is float or value is int:
			return float(value)
		cursor = cursor.get_parent()
	return 100.0

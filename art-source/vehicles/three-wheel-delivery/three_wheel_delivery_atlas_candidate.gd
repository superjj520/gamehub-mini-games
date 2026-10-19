extends Node3D

## 三轮配送车材质图集候选的纯视觉增强层。
## 不改变正式载具控制器、碰撞体、任务、存档或数值逻辑。

const WHEEL_NAMES := ["候选三轮车左后轮胎", "候选三轮车右后轮胎", "候选三轮车前轮胎"]

var damage_overlay: MeshInstance3D
var damage_scratch_left: MeshInstance3D
var damage_scratch_right: MeshInstance3D
var damage_warning_light: MeshInstance3D
var headlight_glow: OmniLight3D
var left_signal_glow: OmniLight3D
var right_signal_glow: OmniLight3D
var base_damage_emission := Color("2b0808")
var ground_contact_shadows: Array[MeshInstance3D] = []

func _ready() -> void:
	set_meta("candidate_visual_asset", true)
	set_meta("candidate_id", "city-vehicle-three-wheel-delivery-atlas-candidate")
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_vehicle_geometry_and_material_atlas")
	_build_driver_contact_details()
	_build_candidate_lighting()
	_build_candidate_damage_overlay()
	_build_ground_contact_shadows()

func _process(_delta: float) -> void:
	_update_candidate_feedback()

func refresh_feedback() -> void:
	"""供确定性集成测试立即刷新表现层；不修改载具耐久或碰撞状态。"""
	_update_candidate_feedback()

func _build_driver_contact_details() -> void:
	# 最终候选车体沿用运行时驾驶姿态的握把挂点，保证角色手部、车把和镜头接触关系一致。
	# 这些节点只有表现用途，不创建碰撞，也不参与车辆控制。
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var grip := MeshInstance3D.new()
		grip.name = "候选三轮车%s把手胶套" % suffix
		var grip_mesh := BoxMesh.new()
		grip_mesh.size = Vector3(0.18, 0.06, 0.06)
		grip.mesh = grip_mesh
		grip.position = Vector3(side * 0.35, 1.28, -0.76)
		var grip_material := StandardMaterial3D.new()
		grip_material.albedo_color = Color("11161b")
		grip_material.roughness = 0.82
		grip.material_override = grip_material
		grip.set_meta("original_procedural_asset", true)
		grip.set_meta("visual_only", true)
		grip.set_meta("candidate_visual_only", true)
		grip.set_meta("driver_contact_visual", true)
		add_child(grip)

func _build_candidate_lighting() -> void:
	var headlight := find_child("候选三轮车前灯", true, false) as Node3D
	var left_signal := find_child("候选三轮车左转向灯", true, false) as Node3D
	var right_signal := find_child("候选三轮车右转向灯", true, false) as Node3D
	if headlight != null:
		headlight_glow = OmniLight3D.new()
		headlight_glow.name = "候选前灯光晕"
		headlight_glow.light_color = Color("ffdca1")
		headlight_glow.light_energy = 0.55
		headlight_glow.omni_range = 3.2
		headlight_glow.position = headlight.position + Vector3(0.0, 0.0, -0.12)
		add_child(headlight_glow)
	if left_signal != null:
		left_signal_glow = _make_signal_light("候选左转向灯光晕", Color("f39a44"), left_signal.position)
	if right_signal != null:
		right_signal_glow = _make_signal_light("候选右转向灯光晕", Color("f39a44"), right_signal.position)

func _make_signal_light(light_name: String, light_color: Color, light_position: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.light_color = light_color
	light.light_energy = 0.0
	light.omni_range = 1.2
	light.position = light_position
	add_child(light)
	return light

func _build_candidate_damage_overlay() -> void:
	damage_overlay = MeshInstance3D.new()
	damage_overlay.name = "候选三轮车损伤面板"
	var panel := BoxMesh.new()
	panel.size = Vector3(1.1, 0.05, 0.08)
	damage_overlay.mesh = panel
	damage_overlay.position = Vector3(0.0, 1.18, -1.30)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("741f25")
	material.emission_enabled = true
	material.emission = base_damage_emission
	material.emission_energy_multiplier = 0.35
	damage_overlay.material_override = material
	damage_overlay.visible = false
	add_child(damage_overlay)

	var scratch_material := StandardMaterial3D.new()
	scratch_material.albedo_color = Color("6f2830")
	scratch_material.roughness = 0.62
	scratch_material.emission_enabled = true
	scratch_material.emission = Color("27080c")
	scratch_material.emission_energy_multiplier = 0.18
	damage_scratch_left = _make_damage_detail("候选三轮车损伤刮痕-左", Vector3(0.10, 0.035, 0.72), Vector3(-0.76, 0.20, -0.04), scratch_material)
	damage_scratch_right = _make_damage_detail("候选三轮车损伤刮痕-右", Vector3(0.10, 0.035, 0.72), Vector3(0.76, 0.20, -0.04), scratch_material)
	var warning_material := StandardMaterial3D.new()
	warning_material.albedo_color = Color("d16b3d")
	warning_material.roughness = 0.36
	warning_material.emission_enabled = true
	warning_material.emission = Color("5b1609")
	warning_material.emission_energy_multiplier = 0.65
	damage_warning_light = _make_damage_detail("候选三轮车损伤警示灯", Vector3(0.18, 0.12, 0.05), Vector3(0.0, 0.68, 1.37), warning_material)

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

func _make_damage_detail(node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	node.visible = false
	node.set_meta("visual_only", true)
	add_child(node)
	return node

func _update_candidate_feedback() -> void:
	var integrity := _read_vehicle_integrity()
	if damage_overlay != null:
		damage_overlay.visible = integrity < 100.0
		if damage_overlay.material_override is StandardMaterial3D:
			var damage_material := damage_overlay.material_override as StandardMaterial3D
			damage_material.emission_energy_multiplier = clampf((100.0 - integrity) / 45.0, 0.35, 1.6)
	if damage_scratch_left != null:
		damage_scratch_left.visible = integrity < 86.0
	if damage_scratch_right != null:
		damage_scratch_right.visible = integrity < 66.0
	if damage_warning_light != null:
		damage_warning_light.visible = integrity < 52.0
	var blink_on := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.34
	if left_signal_glow != null:
		left_signal_glow.light_energy = 0.42 if blink_on else 0.0
	if right_signal_glow != null:
		right_signal_glow.light_energy = 0.42 if blink_on else 0.0

func _read_vehicle_integrity() -> float:
	var cursor: Node = self
	while cursor != null:
		var value = cursor.get("vehicle_integrity")
		if value is float or value is int:
			return float(value)
		cursor = cursor.get_parent()
	return 100.0

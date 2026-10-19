extends Node3D

## P0 办公室 NPC 原创程序化候选。
## 这是正式运行时的内部可玩视觉候选，不代表最终发布资产。

var _animation_player: AnimationPlayer
var _search_feedback: MeshInstance3D
var _alert_feedback: MeshInstance3D
var _search_feedback_ring: MeshInstance3D
var _alert_feedback_ring: MeshInstance3D
var _search_beam: SpotLight3D
var _alert_beam: SpotLight3D
var _presentation_root: Node3D
var _candidate_state := "idle_default"
var _feedback_time := 0.0

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_code_and_node_materials")
	set_meta("reference_board", "art-source/characters/office-npc-design/new-era-awakener-office-npc-turnaround-v1-generated.png")
	set_meta("visual_direction", "原创写实_中等细节")
	_presentation_root = Node3D.new()
	_presentation_root.name = "候选NPC表现根"
	_presentation_root.set_meta("visual_only", true)
	_presentation_root.set_meta("candidate_visual_only", true)
	add_child(_presentation_root)
	_build_visual()
	_build_mount_points()
	_build_animation_library()
	_build_state_feedback()

func _process(delta: float) -> void:
	if _candidate_state != "search_default" and _candidate_state != "alert_default":
		return
	_feedback_time += delta
	var frequency := 5.0 if _candidate_state == "search_default" else 8.0
	var pulse := 1.0 + sin(_feedback_time * frequency) * 0.08
	var ring := _search_feedback_ring if _candidate_state == "search_default" else _alert_feedback_ring
	if ring != null and ring.visible:
		ring.scale = Vector3.ONE * (0.72 * pulse)

func _build_visual() -> void:
	var jacket := Color("3e4448")
	var shirt := Color("65747d")
	var pants := Color("25292d")
	var skin := Color("a96247")
	var hair := Color("181b22")
	var badge := Color("d7a74f")
	var lanyard := Color("28343a")
	var shoe_highlight := Color("3a4148")
	var shirt_detail := Color("8a989c")
	var tablet_edge := Color("4d5b61")
	# 参考镜头里的办公室 NPC 不是一块矩形障碍物；保留稳定的身体节点名，
	# 但用上下收分的原创程序化外形建立肩线、胸腔和腰部层次。所有节点
	# 都只属于表现根，不改变 NPC 根节点、感知射线、碰撞或任务状态。
	_add_tapered_cylinder("候选NPC身体", 0.27, 0.34, 0.74, Vector3(0.0, 0.0, 0.0), jacket, Vector3(1.12, 1.0, 0.72))
	_add_box("候选NPC肩部结构-左", Vector3(0.18, 0.16, 0.30), Vector3(-0.28, 0.24, 0.0), jacket, 0.045)
	_add_box("候选NPC肩部结构-右", Vector3(0.18, 0.16, 0.30), Vector3(0.28, 0.24, 0.0), jacket, 0.045)
	_add_box("候选NPC夹克下摆", Vector3(0.56, 0.16, 0.34), Vector3(0.0, -0.30, 0.0), Color("333a40"), 0.045)
	_add_box("候选NPC左衣襟", Vector3(0.075, 0.34, 0.035), Vector3(-0.12, 0.08, -0.268), Color("56636a"), 0.012)
	_add_box("候选NPC右衣襟", Vector3(0.075, 0.34, 0.035), Vector3(0.12, 0.08, -0.268), Color("56636a"), 0.012)
	_add_box("候选NPC左胸袋", Vector3(0.16, 0.045, 0.028), Vector3(-0.20, -0.01, -0.265), Color("68767c"), 0.008)
	_add_box("候选NPC右胸袋", Vector3(0.16, 0.045, 0.028), Vector3(0.20, -0.01, -0.265), Color("68767c"), 0.008)
	_add_box("候选NPC衬衣", Vector3(0.22, 0.42, 0.05), Vector3(0.0, 0.02, -0.22), shirt, 0.02)
	_add_box("候选NPC左衣领", Vector3(0.13, 0.20, 0.035), Vector3(-0.08, 0.18, -0.245), shirt, 0.012)
	_add_box("候选NPC右衣领", Vector3(0.13, 0.20, 0.035), Vector3(0.08, 0.18, -0.245), shirt, 0.012)
	_add_box("候选NPC胸牌挂绳", Vector3(0.025, 0.28, 0.025), Vector3(0.0, 0.05, -0.255), lanyard, 0.008)
	_add_box("候选NPC胸牌挂绳左侧", Vector3(0.020, 0.17, 0.022), Vector3(-0.055, 0.13, -0.253), lanyard, 0.006)
	_add_box("候选NPC胸牌挂绳右侧", Vector3(0.020, 0.17, 0.022), Vector3(0.055, 0.13, -0.253), lanyard, 0.006)
	_add_box("候选NPC衬衣纽扣", Vector3(0.025, 0.025, 0.018), Vector3(0.0, 0.16, -0.262), shirt_detail, 0.004)
	_add_box("候选NPC腰带", Vector3(0.54, 0.07, 0.34), Vector3(0.0, -0.30, 0.0), jacket, 0.018)
	_add_box("候选NPC胸牌", Vector3(0.10, 0.12, 0.025), Vector3(0.19, 0.10, -0.255), badge, 0.01)
	_add_cylinder("候选NPC颈部", Vector3(0.0, 0.45, 0.0), 0.11, 0.15, skin)
	_add_sphere("候选NPC头部", Vector3(0.0, 0.68, 0.0), 0.22, skin, Vector3(0.92, 1.0, 0.88))
	_add_sphere("候选NPC头发", Vector3(0.0, 0.84, 0.0), 0.225, hair, Vector3(1.0, 0.40, 0.94))
	_add_sphere("候选NPC鼻梁", Vector3(0.0, 0.68, -0.232), 0.034, skin, Vector3(0.72, 0.78, 1.2))
	_add_box("候选NPC嘴部阴影", Vector3(0.10, 0.018, 0.018), Vector3(0.0, 0.59, -0.215), Color("773f3e"), 0.006)
	_add_sphere("候选NPC眼睛-左", Vector3(-0.078, 0.72, -0.210), 0.018, Color("12171b"), Vector3(1.0, 0.72, 0.55))
	_add_sphere("候选NPC眼睛-右", Vector3(0.078, 0.72, -0.210), 0.018, Color("12171b"), Vector3(1.0, 0.72, 0.55))
	# 近景识别不能只靠眼睛和鼻梁；补上眉线、下巴轮廓和领口缝线，
	# 让 NPC 在办公室侧后肩镜头中有稳定的面部朝向和服装边界。
	_add_box("候选NPC眉毛-左", Vector3(0.072, 0.018, 0.020), Vector3(-0.078, 0.785, -0.218), hair, 0.005)
	_add_box("候选NPC眉毛-右", Vector3(0.072, 0.018, 0.020), Vector3(0.078, 0.785, -0.218), hair, 0.005)
	_add_sphere("候选NPC下巴轮廓", Vector3(0.0, 0.57, -0.190), 0.045, skin, Vector3(0.92, 0.55, 0.72))
	_add_box("候选NPC领口缝线", Vector3(0.24, 0.022, 0.022), Vector3(0.0, 0.255, -0.272), shirt_detail, 0.005)
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_add_capsule("候选NPC上臂" + suffix, Vector3(side * 0.39, -0.08, 0.0), 0.085, 0.36, jacket, Vector3(0.0, 0.0, side * -10.0))
		_add_capsule("候选NPC前臂" + suffix, Vector3(side * 0.52, -0.22, -0.01), 0.075, 0.30, jacket, Vector3(0.0, 0.0, side * -20.0))
		_add_box("候选NPC袖口" + suffix, Vector3(0.16, 0.055, 0.16), Vector3(side * 0.52, -0.22, -0.01), shirt_detail, 0.012)
		_add_sphere("候选NPC手部" + suffix, Vector3(side * 0.61, -0.34, -0.02), 0.09, skin, Vector3(1.0, 0.86, 0.9))
		_add_capsule("候选NPC腿部" + suffix, Vector3(side * 0.16, -0.57, 0.0), 0.11, 0.58, pants, Vector3.ZERO)
		_add_box("候选NPC鞋子" + suffix, Vector3(0.24, 0.14, 0.36), Vector3(side * 0.16, -0.90, -0.07), Color("101319"), 0.04)
		_add_box("候选NPC鞋面" + suffix, Vector3(0.20, 0.045, 0.22), Vector3(side * 0.16, -0.82, -0.14), shoe_highlight, 0.018)
		_add_box("候选NPC鞋底" + suffix, Vector3(0.26, 0.04, 0.38), Vector3(side * 0.16, -0.985, -0.07), Color("20262b"), 0.012)
	_add_box("候选NPC平板外框", Vector3(0.34, 0.40, 0.055), Vector3(0.52, -0.35, -0.08), tablet_edge, 0.028)
	_add_box("候选NPC手持平板", Vector3(0.30, 0.36, 0.045), Vector3(0.52, -0.35, -0.10), Color("252c31"), 0.025)
	_add_box("候选NPC平板屏幕", Vector3(0.24, 0.27, 0.012), Vector3(0.52, -0.35, -0.128), Color("66777b"), 0.012)
	_add_box("候选NPC平板状态灯", Vector3(0.035, 0.025, 0.018), Vector3(0.62, -0.19, -0.139), Color("8ac7a4"), 0.004)
	_add_box("候选NPC平板顶部摄像头", Vector3(0.035, 0.022, 0.014), Vector3(0.52, -0.19, -0.139), Color("151b20"), 0.004)
	_add_box("候选NPC平板屏幕分栏-上", Vector3(0.18, 0.018, 0.006), Vector3(0.50, -0.27, -0.138), Color("94afb0"), 0.003)
	_add_box("候选NPC平板屏幕分栏-下", Vector3(0.12, 0.018, 0.006), Vector3(0.47, -0.39, -0.138), Color("789192"), 0.003)
	_add_capsule("候选NPC平板触控笔", Vector3(0.66, -0.39, -0.145), 0.010, 0.19, Color("d1b071"), Vector3(0.0, 0.0, 78.0))
	_build_surface_details()

func _build_surface_details() -> void:
	# 只增加 NPC 服装和设备的近景可读性，不改动感知、动画、挂点或任务状态。
	var seam := Color("242b30")
	var jacket_detail := Color("68757b")
	var metal := Color("b99b67")
	var shoe_detail := Color("b7c1c2")
	var tablet_ui := _material(Color("7bb5b2"), 0.26)
	tablet_ui.emission_enabled = true
	tablet_ui.emission = Color("235c5b")
	tablet_ui.emission_energy_multiplier = 0.10

	# 夹克翻领、前襟缝线、袖口和腰带扣是办公室 NPC 的近景识别特征。
	_add_box("候选NPC夹克翻领-左", Vector3(0.16, 0.22, 0.035), Vector3(-0.10, 0.25, -0.255), jacket_detail, 0.012)
	_add_box("候选NPC夹克翻领-右", Vector3(0.16, 0.22, 0.035), Vector3(0.10, 0.25, -0.255), jacket_detail, 0.012)
	_add_box("候选NPC夹克前襟缝线-左", Vector3(0.018, 0.42, 0.014), Vector3(-0.20, 0.0, -0.205), seam, 0.004)
	_add_box("候选NPC夹克前襟缝线-右", Vector3(0.018, 0.42, 0.014), Vector3(0.20, 0.0, -0.205), seam, 0.004)
	_add_box("候选NPC袖口-左", Vector3(0.16, 0.09, 0.17), Vector3(-0.50, -0.31, -0.015), jacket_detail, 0.018)
	_add_box("候选NPC袖口-右", Vector3(0.16, 0.09, 0.17), Vector3(0.50, -0.31, -0.015), jacket_detail, 0.018)
	_add_box("候选NPC腰带扣", Vector3(0.10, 0.075, 0.035), Vector3(0.0, -0.30, -0.185), metal, 0.010)
	_add_box("候选NPC夹克下摆口袋-左", Vector3(0.18, 0.06, 0.035), Vector3(-0.22, -0.18, -0.205), jacket_detail, 0.010)
	_add_box("候选NPC夹克下摆口袋-右", Vector3(0.18, 0.06, 0.035), Vector3(0.22, -0.18, -0.205), jacket_detail, 0.010)

	# 手腕和设备接触层，让平板不再像悬浮在身体旁边的图标。
	_add_torus("候选NPC左腕手表", Vector3(-0.55, -0.31, -0.01), 0.062, 0.012, metal)
	_add_box("候选NPC平板手带", Vector3(0.045, 0.28, 0.022), Vector3(0.61, -0.35, -0.145), Color("1b2226"), 0.006)
	_add_box("候选NPC平板界面进度条", Vector3(0.16, 0.014, 0.008), Vector3(0.50, -0.34, -0.144), Color("9ad6c2"), 0.002)
	_add_box("候选NPC平板界面警示点", Vector3(0.028, 0.028, 0.008), Vector3(0.60, -0.42, -0.144), Color("d7a74f"), 0.003)
	_add_box("候选NPC裤线-左", Vector3(0.018, 0.48, 0.018), Vector3(-0.16, -0.60, -0.115), seam, 0.004)
	_add_box("候选NPC裤线-右", Vector3(0.018, 0.48, 0.018), Vector3(0.16, -0.60, -0.115), seam, 0.004)
	_add_box("候选NPC鞋带-左", Vector3(0.15, 0.018, 0.028), Vector3(-0.16, -0.82, -0.205), shoe_detail, 0.004)
	_add_box("候选NPC鞋带-右", Vector3(0.15, 0.018, 0.028), Vector3(0.16, -0.82, -0.205), shoe_detail, 0.004)
	_add_box("候选NPC耳机-左", Vector3(0.026, 0.07, 0.026), Vector3(-0.205, 0.70, -0.02), Color("2a3338"), 0.006)
	_add_box("候选NPC耳机线", Vector3(0.012, 0.22, 0.012), Vector3(-0.20, 0.48, -0.02), Color("2a3338"), 0.003)

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ["idle_default", "walk_default", "search_default", "alert_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(animation_name, animation)
	_add_animation_track(library.get_animation("idle_default"), "候选NPC表现根/候选NPC头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 2.5, 0.0))
	_add_animation_track(library.get_animation("walk_default"), "候选NPC表现根/候选NPC上臂-左:rotation_degrees", Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, 12.0))
	_add_animation_track(library.get_animation("walk_default"), "候选NPC表现根/候选NPC上臂-右:rotation_degrees", Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -12.0))
	_add_animation_track(library.get_animation("search_default"), "候选NPC表现根/候选NPC头部:rotation_degrees", Vector3(0.0, -18.0, 0.0), Vector3(0.0, 18.0, 0.0))
	_add_animation_track(library.get_animation("search_default"), "候选NPC表现根/候选NPC身体:rotation_degrees", Vector3.ZERO, Vector3(0.0, 0.0, -3.0))
	_add_animation_track(library.get_animation("search_default"), "候选NPC表现根/候选NPC手持平板:rotation_degrees", Vector3(0.0, 0.0, -4.0), Vector3(0.0, 0.0, 6.0))
	_add_animation_track(library.get_animation("alert_default"), "候选NPC表现根/候选NPC头部:rotation_degrees", Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_add_animation_track(library.get_animation("alert_default"), "候选NPC表现根/候选NPC上臂-左:rotation_degrees", Vector3(0.0, 0.0, -10.0), Vector3(-8.0, 0.0, -18.0))
	_add_animation_track(library.get_animation("alert_default"), "候选NPC表现根/候选NPC上臂-右:rotation_degrees", Vector3(0.0, 0.0, 10.0), Vector3(-8.0, 0.0, 18.0))
	_add_animation_track(library.get_animation("alert_default"), "候选NPC表现根/候选NPC手持平板:rotation_degrees", Vector3(0.0, 0.0, 8.0), Vector3(0.0, 0.0, -5.0))
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

func _build_mount_points() -> void:
	var mounts := {
		"视线起点": Vector3(0.0, 0.72, -0.18),
		"搜索目标点": Vector3(0.0, 0.90, -0.32),
		"警觉标记点": Vector3(0.0, 1.02, -0.04),
		"脚底碰撞参考点": Vector3(0.0, -0.98, 0.0)
	}
	for mount_name in mounts:
		var marker := Marker3D.new()
		marker.name = mount_name
		marker.position = mounts[mount_name]
		add_child(marker)

func drive_candidate_state(state_name: String) -> void:
	_candidate_state = state_name
	_feedback_time = 0.0
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
	_apply_state_feedback(state_name)

func _build_state_feedback() -> void:
	# 只提供候选视觉层的状态可读性，不替代正式 NPC 感知状态、视线检测或任务判定。
	_search_feedback = _make_feedback_box("候选NPC搜索状态灯", Vector3(0.14, 0.07, 0.035), Vector3(0.0, 1.04, -0.26), Color("d7a74f"))
	_alert_feedback = _make_feedback_box("候选NPC警觉状态灯", Vector3(0.18, 0.09, 0.035), Vector3(0.0, 1.08, -0.26), Color("c84d4d"))
	# 状态灯在远景中不够清楚；这两个环只在搜索/警觉状态显示，帮助玩家
	# 读取 NPC 当前状态。环属于表现层，不参与视线、碰撞、导航或任务判定。
	_search_feedback_ring = _make_feedback_ring("候选NPC搜索状态环", Vector3(0.0, 1.08, 0.0), Color("d7a74f"))
	_alert_feedback_ring = _make_feedback_ring("候选NPC警觉状态环", Vector3(0.0, 1.10, 0.0), Color("c84d4d"))
	_search_beam = _make_state_beam("候选NPC搜索探照束", Color("e7c36f"), 0.34, 7.0, 18.0)
	_alert_beam = _make_state_beam("候选NPC警觉探照束", Color("d65c58"), 0.42, 8.0, 22.0)
	_search_feedback.visible = false
	_alert_feedback.visible = false
	_search_feedback_ring.visible = false
	_alert_feedback_ring.visible = false
	_search_beam.visible = false
	_alert_beam.visible = false

func _apply_state_feedback(state_name: String) -> void:
	if _search_feedback == null or _alert_feedback == null or _search_feedback_ring == null or _alert_feedback_ring == null or _search_beam == null or _alert_beam == null:
		return
	_search_feedback.visible = state_name == "search_default"
	_alert_feedback.visible = state_name == "alert_default"
	_search_feedback_ring.visible = state_name == "search_default"
	_alert_feedback_ring.visible = state_name == "alert_default"
	_search_beam.visible = state_name == "search_default"
	_alert_beam.visible = state_name == "alert_default"

func _make_state_beam(node_name: String, color: Color, energy: float, beam_range: float, angle: float) -> SpotLight3D:
	var beam := SpotLight3D.new()
	beam.name = node_name
	beam.position = Vector3(0.0, 0.98, -0.16)
	beam.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
	beam.light_color = color
	beam.light_energy = energy
	beam.spot_range = beam_range
	beam.spot_angle = angle
	beam.spot_attenuation = 1.4
	beam.shadow_enabled = false
	beam.set_meta("original_procedural_asset", true)
	beam.set_meta("visual_only", true)
	beam.set_meta("candidate_visual_only", true)
	beam.set_meta("feedback_layer", "npc_perception")
	_presentation_root.add_child(beam)
	return beam

func _add_animation_track(animation: Animation, property_path: String, first_value: Vector3, second_value: Vector3) -> void:
	if animation == null:
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(property_path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, first_value)
	animation.track_insert_key(track, 0.5, second_value)
	animation.track_insert_key(track, 1.0, first_value)

func _material(color: Color, roughness: float = 0.70) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.set_meta("original_procedural_asset", true)
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color, bevel: float) -> void:
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
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)

func _add_tapered_cylinder(node_name: String, top_radius: float, bottom_radius: float, height: float, at: Vector3, color: Color, scale: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)

func _make_feedback_box(node_name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	var material := _material(color, 0.34)
	material.emission_enabled = true
	material.emission = color.darkened(0.35)
	material.emission_energy_multiplier = 0.55
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)
	return node

func _make_feedback_ring(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.18
	mesh.outer_radius = 0.22
	mesh.rings = 24
	mesh.ring_segments = 10
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = Vector3(0.72, 0.72, 0.72)
	var material := _material(color, 0.34)
	material.emission_enabled = true
	material.emission = color.darkened(0.25)
	material.emission_energy_multiplier = 0.70
	node.material_override = material
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)
	return node

func _add_sphere(node_name: String, at: Vector3, radius: float, color: Color, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)

func _add_capsule(node_name: String, at: Vector3, radius: float, height: float, color: Color, rotation: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)

func _add_torus(node_name: String, at: Vector3, inner_radius: float, outer_radius: float, color: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = inner_radius + outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	node.material_override = _material(color, 0.34)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	_visual_parent().add_child(node)

func _visual_parent() -> Node:
	return _presentation_root if _presentation_root != null else self

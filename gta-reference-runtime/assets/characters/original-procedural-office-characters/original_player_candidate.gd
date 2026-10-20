extends Node3D

## P0 主角原创程序化候选。
## 这是正式运行时的内部可玩视觉候选，不代表最终发布资产。

const OriginalPlayerHighDetailScene := preload("res://assets/characters/original-procedural-office-characters/original_player_visual_v1.glb")

var _animation_player: AnimationPlayer
var _state := "idle_default"
var _typing_motion_time := 0.0
var _candidate_context := "office"
var _ground_contact_shadows: Array[MeshInstance3D] = []
var _high_detail_visual: Node3D
var _high_detail_base_position := Vector3.ZERO
var _high_detail_base_rotation := Vector3.ZERO
var _high_detail_state_offset := Vector3.ZERO

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_code_and_node_materials")
	set_meta("reference_board", "art-source/characters/player-design/new-era-awakener-player-turnaround-v1-generated.png")
	set_meta("visual_direction", "原创写实_中等细节")
	_build_visual()
	_build_mount_points()
	_build_ground_contact_shadows()
	_build_animation_library()
	_mount_high_detail_visual()
	_apply_state_pose()

func _process(delta: float) -> void:
	if _high_detail_visual != null:
		_update_high_detail_motion(delta)
	if _state != "typing_default":
		return
	# 坐姿打字不能只靠一张静态姿势：参考镜头里手腕、手指和肩线会有
	# 很轻的交替运动。这里只更新表现节点，不改变玩家根节点、碰撞、
	# 交互挂点、任务状态或存档数据。
	_typing_motion_time += delta
	var beat := _typing_motion_time * 7.5
	var left_phase := sin(beat)
	var right_phase := sin(beat + PI)
	for side_data in [
		{"side": -1.0, "phase": left_phase},
		{"side": 1.0, "phase": right_phase},
	]:
		var side := float(side_data["side"])
		var phase := float(side_data["phase"])
		var suffix := "-左" if side < 0.0 else "-右"
		var hand := get_node_or_null("候选主角手部" + suffix) as Node3D
		if hand != null:
			hand.position = Vector3(side * 0.43, -0.04 + phase * 0.014, -0.84 + absf(phase) * 0.012)
		var forearm := get_node_or_null("候选主角前臂" + suffix) as Node3D
		if forearm != null:
			forearm.rotation_degrees = Vector3(-68.0 - phase * 2.5, 0.0, side * -10.0)
		for finger_index in range(3):
			var finger := get_node_or_null("候选主角指节-%s-%d" % [suffix, finger_index]) as Node3D
			if finger != null:
				var finger_offset := float(finger_index - 1) * 0.032
				finger.position = Vector3(side * (0.43 + finger_offset), -0.08 + phase * 0.010, -0.96 + absf(phase) * 0.010)
	var head := get_node_or_null("候选主角头部") as Node3D
	if head != null:
		head.rotation_degrees = Vector3(-12.0 + sin(beat * 0.5) * 0.9, 0.0, 0.0)

func _build_visual() -> void:
	# 参考视频的办公室近景是偏灰的写实工装，不是高饱和积木色；
	# 这里仍然只使用项目内程序化材质，但把明度和体积控制在更接近
	# 人体比例的范围，避免背包、头发和肩部成为第一视觉主体。
	var jacket := Color("4a5154")
	var jacket_highlight := Color("6e7978")
	var skin := Color("9f6d5d")
	var hair := Color("24272a")
	var backpack := Color("20272b")
	var backpack_trim := Color("5f6a6f")
	var shirt := Color("b7b0a4")
	var shirt_edge := Color("e2d9c8")
	var office_knit := Color("c7c0b5")
	var driver_red := Color("9d3d37")
	var pants := Color("24282d")
	var sole := Color("101316")
	var seam := Color("68757a")
	var accent := Color("b89a68")

	# 躯干和外套使用上宽下窄的分段圆台，肩线、胸腔和腰部不再合并成蛋形；
	# 仍然只影响表现节点，不改变玩家根节点、碰撞、挂点或状态机。
	_add_tapered_cylinder("候选主角身体", 0.25, 0.31, 0.78, Vector3(0.0, 1.08, 0.0), shirt, Vector3(1.12, 1.0, 0.72))
	_add_tapered_cylinder("候选主角夹克外套", 0.28, 0.35, 0.82, Vector3(0.0, 1.07, 0.015), jacket, Vector3(1.12, 1.0, 0.76))
	_add_scaled_capsule("候选主角腰胯结构", 0.29, 0.42, Vector3(0.0, 0.73, 0.0), jacket, Vector3(1.16, 0.82, 0.70))
	_add_box("候选主角胸前护片", Vector3(0.39, 0.30, 0.055), Vector3(0.0, 1.27, -0.255), jacket_highlight, 0.035)
	_add_box("候选主角背部拼接", Vector3(0.38, 0.25, 0.07), Vector3(0.0, 1.30, 0.225), jacket_highlight, 0.028)
	_add_box("候选主角肩胛带-左", Vector3(0.07, 0.30, 0.04), Vector3(-0.20, 1.22, 0.255), seam, 0.012)
	_add_box("候选主角肩胛带-右", Vector3(0.07, 0.30, 0.04), Vector3(0.20, 1.22, 0.255), seam, 0.012)
	_add_box("候选主角马甲前片", Vector3(0.36, 0.54, 0.06), Vector3(0.0, 1.10, -0.185), jacket, 0.045)
	_add_box("候选主角马甲后片", Vector3(0.38, 0.50, 0.055), Vector3(0.0, 1.10, 0.185), jacket, 0.04)
	_add_box("候选主角夹克下摆", Vector3(0.48, 0.16, 0.30), Vector3(0.0, 0.75, 0.0), jacket_highlight, 0.06)
	_add_box("候选主角衬衣", Vector3(0.24, 0.44, 0.05), Vector3(0.0, 1.15, -0.22), shirt, 0.02)
	_add_box("候选主角衬衣领口", Vector3(0.32, 0.08, 0.06), Vector3(0.0, 1.48, -0.215), shirt_edge, 0.018)
	_add_box("候选主角内层拉链", Vector3(0.025, 0.30, 0.018), Vector3(0.0, 1.22, -0.252), shirt_edge, 0.006)
	_add_box("候选主角腰带", Vector3(0.52, 0.075, 0.40), Vector3(0.0, 0.78, 0.0), jacket, 0.02)
	# 背包必须读作柔软的通勤包，而不是覆盖整个躯干的装甲盒；
	# 缩窄并后移后，肩线、手臂和腰胯能在肩后镜头中重新连成完整人体轮廓。
	_add_box("候选主角背包", Vector3(0.31, 0.50, 0.095), Vector3(0.0, 1.11, 0.285), backpack, 0.08)
	_add_box("候选主角背包翻盖", Vector3(0.27, 0.085, 0.11), Vector3(0.0, 1.36, 0.245), backpack_trim, 0.04)
	_add_box("候选主角背包底部", Vector3(0.26, 0.06, 0.11), Vector3(0.0, 0.87, 0.255), backpack_trim, 0.025)
	_add_box("候选主角背包肩带-左", Vector3(0.045, 0.46, 0.030), Vector3(-0.18, 1.17, 0.235), backpack_trim, 0.012)
	_add_box("候选主角背包肩带-右", Vector3(0.045, 0.46, 0.030), Vector3(0.18, 1.17, 0.235), backpack_trim, 0.012)
	# 参考设计中的连帽夹克和工装裤轮廓是主角身份的关键识别点；
	# 这些节点只补足视觉轮廓，不参与碰撞、导航或交互。
	_add_box("候选主角肩部夹克-左", Vector3(0.12, 0.09, 0.21), Vector3(-0.24, 1.32, 0.07), jacket, 0.025)
	_add_box("候选主角肩部夹克-右", Vector3(0.12, 0.09, 0.21), Vector3(0.24, 1.32, 0.07), jacket, 0.025)
	_add_box("候选主角夹克前襟-左", Vector3(0.06, 0.44, 0.035), Vector3(-0.13, 1.22, -0.255), seam, 0.012)
	_add_box("候选主角夹克前襟-右", Vector3(0.06, 0.44, 0.035), Vector3(0.13, 1.22, -0.255), seam, 0.012)
	_add_scaled_capsule("候选主角连帽外壳", 0.22, 0.30, Vector3(0.0, 1.66, 0.09), jacket_highlight, Vector3(1.02, 0.78, 0.72))
	# 参考设计板的连帽不是一个覆盖头部的实心球；领口内圈必须留下
	# 头颈与外套之间的暗部，否则近景会像硬质护具。这个环只属于
	# 表现层，不参与碰撞、导航、交互或存档。
	_add_torus("候选主角连帽内圈", 0.115, 0.205, Vector3(0.0, 1.59, 0.075), Color("171b1e"), Vector3(1.0, 1.0, 0.78))
	_add_box("候选主角帽绳-左", Vector3(0.018, 0.18, 0.018), Vector3(-0.10, 1.59, -0.06), accent, 0.006)
	_add_box("候选主角帽绳-右", Vector3(0.018, 0.18, 0.018), Vector3(0.10, 1.59, -0.06), accent, 0.006)
	_add_scaled_capsule("候选主角左肩圆角", 0.085, 0.23, Vector3(-0.25, 1.24, 0.02), jacket, Vector3(1.0, 0.68, 0.82))
	_add_scaled_capsule("候选主角右肩圆角", 0.085, 0.23, Vector3(0.25, 1.24, 0.02), jacket, Vector3(1.0, 0.68, 0.82))
	_add_box("候选主角袖口-左", Vector3(0.14, 0.09, 0.16), Vector3(-0.49, 0.69, -0.01), jacket, 0.025)
	_add_box("候选主角袖口-右", Vector3(0.14, 0.09, 0.16), Vector3(0.49, 0.69, -0.01), jacket, 0.025)
	_add_box("候选主角背包侧袋-左", Vector3(0.055, 0.12, 0.07), Vector3(-0.18, 1.07, 0.305), backpack, 0.015)
	_add_box("候选主角背包侧袋-右", Vector3(0.055, 0.12, 0.07), Vector3(0.18, 1.07, 0.305), backpack, 0.015)
	_add_box("候选主角背包扣带-左", Vector3(0.030, 0.060, 0.022), Vector3(-0.105, 1.25, 0.315), seam, 0.006)
	_add_box("候选主角背包扣带-右", Vector3(0.030, 0.060, 0.022), Vector3(0.105, 1.25, 0.315), seam, 0.006)
	# 两套参考镜头服装只在对应状态显示：办公室近景使用浅色针织上衣，
	# 驾驶近景使用红色后片和肩线；它们是表现层叠加，不改变角色碰撞或挂点。
	# 办公室近景只保留连续的针织躯干；前后平板会在侧后肩镜头中
	# 形成两块脱离身体的白色墙面，破坏胸腔、手臂和椅背的接触关系。
	# 前片/后片节点仍保留，便于后续换成真正布料网格，但当前状态不显示。
	_add_box("候选主角办公室针织前片", Vector3(0.34, 0.46, 0.028), Vector3(0.0, 1.10, -0.255), office_knit, 0.035)
	_add_box("候选主角办公室针织后片", Vector3(0.36, 0.48, 0.028), Vector3(0.0, 1.10, 0.255), office_knit, 0.035)
	_add_tapered_cylinder("候选主角办公室针织主体", 0.245, 0.305, 0.70, Vector3(0.0, 1.08, 0.0), office_knit, Vector3(1.04, 1.0, 0.74))
	_add_box("候选主角办公室针织领口", Vector3(0.28, 0.075, 0.045), Vector3(0.0, 1.42, -0.275), shirt_edge, 0.018)
	_add_box("候选主角载具红色前片", Vector3(0.43, 0.56, 0.045), Vector3(0.0, 1.10, -0.29), driver_red, 0.040)
	_add_scaled_capsule("候选主角载具红色后片", 0.22, 0.58, Vector3(0.0, 1.10, 0.29), driver_red, Vector3(1.10, 1.0, 0.65))
	_add_box("候选主角载具红色肩线-左", Vector3(0.16, 0.10, 0.22), Vector3(-0.27, 1.29, 0.08), driver_red, 0.025)
	_add_box("候选主角载具红色肩线-右", Vector3(0.16, 0.10, 0.22), Vector3(0.27, 1.29, 0.08), driver_red, 0.025)
	_add_cylinder("候选主角颈部", Vector3(0.0, 1.56, 0.0), 0.10, 0.15, skin)
	_add_sphere("候选主角头部", Vector3(0.0, 1.76, 0.0), 0.205, skin, Vector3(0.92, 1.0, 0.88))
	_add_sphere("候选主角头发", Vector3(0.0, 1.91, 0.0), 0.215, hair, Vector3(1.0, 0.38, 0.94))
	_add_sphere("候选主角耳朵-左", Vector3(-0.195, 1.76, 0.0), 0.048, skin, Vector3(1.0, 1.0, 0.72))
	_add_sphere("候选主角耳朵-右", Vector3(0.195, 1.76, 0.0), 0.048, skin, Vector3(1.0, 1.0, 0.72))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_add_capsule("候选主角上臂" + suffix, Vector3(side * 0.37, 1.00, 0.0), 0.075, 0.36, jacket, Vector3(0.0, 0.0, side * -10.0))
		_add_capsule("候选主角前臂" + suffix, Vector3(side * 0.49, 0.84, -0.015), 0.065, 0.30, jacket_highlight, Vector3(0.0, 0.0, side * -24.0))
		_add_sphere("候选主角手部" + suffix, Vector3(side * 0.59, 0.70, -0.03), 0.085, skin, Vector3(1.0, 0.86, 0.9))
		# 手掌之外补三枚低面数指节，避免近景中手部只剩孤立球体；
		# 它们仍属于表现层，不参与交互射线、碰撞或输入判定。
		for finger_index in range(3):
			var finger_offset := float(finger_index - 1) * 0.032
			_add_capsule("候选主角指节-%s-%d" % [suffix, finger_index], Vector3(side * (0.59 + finger_offset), 0.68, -0.12), 0.018, 0.10, skin, Vector3(90.0, 0.0, 0.0))
		_add_capsule("候选主角腿部" + suffix, Vector3(side * 0.15, 0.46, 0.0), 0.10, 0.62, pants, Vector3.ZERO)
		_add_box("候选主角工装裤袋" + suffix, Vector3(0.18, 0.18, 0.08), Vector3(side * 0.23, 0.48, -0.08), pants, 0.025)
		_add_box("候选主角膝部拼接" + suffix, Vector3(0.16, 0.08, 0.08), Vector3(side * 0.15, 0.36, -0.105), jacket_highlight, 0.018)
		_add_box("候选主角鞋子" + suffix, Vector3(0.22, 0.13, 0.36), Vector3(side * 0.15, 0.11, -0.08), sole, 0.05)
		_add_box("候选主角鞋面侧条" + suffix, Vector3(0.20, 0.055, 0.06), Vector3(side * 0.15, 0.16, -0.25), seam, 0.015)
		_add_box("候选主角鞋底" + suffix, Vector3(0.24, 0.04, 0.38), Vector3(side * 0.15, 0.035, -0.08), Color("333b43"), 0.015)
	_add_box("候选主角工牌", Vector3(0.10, 0.14, 0.025), Vector3(0.0, 1.28, -0.255), Color("d8b66a"), 0.01)
	_add_box("候选主角工牌挂绳", Vector3(0.025, 0.20, 0.02), Vector3(0.0, 1.42, -0.245), Color("5a6672"), 0.006)
	_add_sphere("候选主角鼻梁", Vector3(0.0, 1.76, -0.218), 0.035, skin, Vector3(0.72, 0.8, 1.2))
	_add_box("候选主角眉毛-左", Vector3(0.070, 0.018, 0.022), Vector3(-0.078, 1.835, -0.211), hair, 0.006)
	_add_box("候选主角眉毛-右", Vector3(0.070, 0.018, 0.022), Vector3(0.078, 1.835, -0.211), hair, 0.006)
	_add_sphere("候选主角眼睛-左", Vector3(-0.078, 1.80, -0.202), 0.018, Color("14191e"), Vector3(1.0, 0.75, 0.55))
	_add_sphere("候选主角眼睛-右", Vector3(0.078, 1.80, -0.202), 0.018, Color("14191e"), Vector3(1.0, 0.75, 0.55))
	_add_box("候选主角嘴部", Vector3(0.085, 0.018, 0.022), Vector3(0.0, 1.695, -0.208), accent, 0.006)
	_build_surface_details()

func _build_surface_details() -> void:
	# 只增加原创服装识别细节；这些节点在坐姿打字镜头中隐藏，避免漂浮。
	var seam := Color("1f2529")
	var metal := Color("b89a68")
	var hair := Color("1b1e21")
	var skin_shadow := Color("9b685a")
	var jacket_detail := Color("6b757a")
	_add_box("候选主角细节胸袋-左", Vector3(0.15, 0.045, 0.032), Vector3(-0.22, 1.30, -0.244), jacket_detail, 0.010)
	_add_box("候选主角细节胸袋-右", Vector3(0.15, 0.045, 0.032), Vector3(0.22, 1.30, -0.244), jacket_detail, 0.010)
	_add_box("候选主角细节拉链头", Vector3(0.052, 0.072, 0.030), Vector3(0.0, 1.04, -0.266), metal, 0.010)
	_add_box("候选主角细节背包中央扣", Vector3(0.09, 0.065, 0.035), Vector3(0.0, 1.22, 0.326), metal, 0.012)
	_add_sphere("候选主角细节下巴", Vector3(0.0, 1.68, -0.175), 0.082, skin_shadow, Vector3(0.95, 0.58, 0.62))
	_add_sphere("候选主角细节额前发束-左", Vector3(-0.092, 1.93, -0.145), 0.10, hair, Vector3(0.58, 0.72, 0.95))
	_add_sphere("候选主角细节额前发束-右", Vector3(0.092, 1.93, -0.145), 0.10, hair, Vector3(0.58, 0.72, 0.95))
	_add_box("候选主角细节鞋带-左", Vector3(0.17, 0.018, 0.026), Vector3(-0.15, 0.17, -0.265), metal, 0.006)
	_add_box("候选主角细节鞋带-右", Vector3(0.17, 0.018, 0.026), Vector3(0.15, 0.17, -0.265), metal, 0.006)

func _build_mount_points() -> void:
	var mounts := {
		"交互手部挂点": Vector3(0.0, 0.78, -0.28),
		"载具挂点": Vector3(0.0, 0.92, 0.30),
		"视线起点": Vector3(0.0, 1.78, -0.12),
		"脚底碰撞参考点": Vector3(0.0, 0.04, 0.0)
	}
	for mount_name in mounts:
		var marker := Marker3D.new()
		marker.name = mount_name
		marker.position = mounts[mount_name]
		add_child(marker)

func _build_ground_contact_shadows() -> void:
	# 接地阴影只表达人物与地面的视觉接触，不创建碰撞、导航或任务逻辑。
	var shadow_material := _soft_shadow_material()
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var shadow := MeshInstance3D.new()
		shadow.name = "候选主角" + suffix + "脚软接触阴影"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.28, 0.42)
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

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ["idle_default", "walk_default", "crouch_default", "interact_default", "typing_default", "vehicle_default", "attack_default", "dodge_default", "hit_default", "fail_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if animation_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		library.add_animation(animation_name, animation)
	_add_animation_track(library.get_animation("idle_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 1.0, 0.0))
	_add_animation_track(library.get_animation("walk_default"), "候选主角上臂-左:rotation_degrees", Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, 18.0))
	_add_animation_track(library.get_animation("walk_default"), "候选主角上臂-右:rotation_degrees", Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -18.0))
	_add_animation_track(library.get_animation("interact_default"), "候选主角前臂-右:rotation_degrees", Vector3(0.0, 0.0, -24.0), Vector3(-28.0, 0.0, -6.0))
	_add_animation_track(library.get_animation("typing_default"), "候选主角前臂-左:rotation_degrees", Vector3(-58.0, 0.0, -8.0), Vector3(-66.0, 0.0, -12.0))
	_add_animation_track(library.get_animation("typing_default"), "候选主角前臂-右:rotation_degrees", Vector3(-58.0, 0.0, 8.0), Vector3(-66.0, 0.0, 12.0))
	_add_animation_track(library.get_animation("vehicle_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 8.0, 0.0))
	_add_animation_track(library.get_animation("attack_default"), "候选主角前臂-右:rotation_degrees", Vector3(0.0, 0.0, -18.0), Vector3(-54.0, 0.0, -8.0))
	_add_animation_track(library.get_animation("attack_default"), "候选主角上臂-右:rotation_degrees", Vector3(0.0, 0.0, 12.0), Vector3(0.0, 0.0, -30.0))
	_add_animation_track(library.get_animation("dodge_default"), "候选主角身体:rotation_degrees", Vector3.ZERO, Vector3(0.0, 0.0, 22.0))
	_add_animation_track(library.get_animation("dodge_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, -8.0, 0.0))
	_add_animation_track(library.get_animation("hit_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, -12.0, 0.0))
	_add_animation_track(library.get_animation("crouch_default"), "候选主角身体:position", Vector3(0.0, 1.10, 0.0), Vector3(0.0, 0.92, 0.0))
	_add_animation_track(library.get_animation("fail_default"), "候选主角身体:rotation_degrees", Vector3.ZERO, Vector3(0.0, 0.0, -12.0))
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

func drive_candidate_state(state_name: String) -> void:
	_state = state_name
	if _state == "typing_default":
		_typing_motion_time = 0.0
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
	_apply_state_pose()
	_update_high_detail_pose()

func set_candidate_context(context_name: String) -> void:
	# 城市首店参考帧中的主角穿红色外套，办公室则保持灰色工装。
	# 上下文只改 Visual 节点的材质和叠加层，不改变控制器、碰撞、
	# 任务、导航、交互挂点或存档数据。
	_candidate_context = "city" if context_name == "city" else "office"
	set_meta("candidate_context", _candidate_context)
	_apply_candidate_context_materials()
	_set_state_specific_clothing_visibility()
	_update_high_detail_pose()

func _mount_high_detail_visual() -> void:
	# GLB 是同一原创角色的高细节静态部件集合：不接管玩家根节点、碰撞、
	# 任务或存档。原有程序化节点继续保留，作为动画状态和旧平台回退层；
	# 正常可见画面优先显示 GLB，避免把低细节几何误当成最终角色表现。
	if _high_detail_visual != null or OriginalPlayerHighDetailScene == null:
		return
	_high_detail_visual = OriginalPlayerHighDetailScene.instantiate() as Node3D
	if _high_detail_visual == null:
		return
	_high_detail_visual.name = "原创主角高细节视觉"
	_high_detail_visual.set_meta("original_procedural_asset", true)
	_high_detail_visual.set_meta("asset_source", "project_original_generated_glb")
	_high_detail_visual.set_meta("visual_candidate", true)
	_high_detail_visual.set_meta("visual_only", true)
	add_child(_high_detail_visual)
	for mesh in _high_detail_visual.find_children("*", "MeshInstance3D", true, false):
		# 导入的 GLB 子网格也属于同一候选视觉层；统一标记，避免
		# 资产验收把高细节网格误判为可参与碰撞或逻辑的实体节点。
		mesh.set_meta("visual_only", true)
		mesh.set_meta("candidate_visual_only", true)
		mesh.set_meta("original_procedural_asset", true)
	_high_detail_base_position = _high_detail_visual.position
	_high_detail_base_rotation = _high_detail_visual.rotation_degrees
	# 仍保留原有程序化节点树，供状态契约、测试和低能力设备回退使用；
	# 只关闭其可见网格，避免同一角色重叠渲染两层。
	for child in get_children():
		if child == _high_detail_visual or child is AnimationPlayer or child is Marker3D:
			continue
		if child is MeshInstance3D and not bool(child.get_meta("ground_contact_visual", false)):
			(child as MeshInstance3D).visible = false
	_update_high_detail_pose()

func _update_high_detail_motion(_delta: float) -> void:
	if _high_detail_visual == null:
		return
	var motion_phase := Time.get_ticks_msec() * 0.001 * (8.0 if _state == "walk_default" else 2.2)
	var bob := sin(motion_phase) * (0.018 if _state == "walk_default" else 0.006)
	_high_detail_visual.position = _high_detail_base_position + _high_detail_state_offset + Vector3(0.0, bob, 0.0)
	if _state == "dodge_default":
		_high_detail_visual.rotation_degrees = _high_detail_base_rotation + Vector3(0.0, 0.0, sin(motion_phase) * 5.0)
	else:
		_high_detail_visual.rotation_degrees = _high_detail_base_rotation + Vector3(-10.0 if _state == "typing_default" else 0.0, 0.0, 0.0)

func _update_high_detail_pose() -> void:
	if _high_detail_visual == null:
		return
	var crouched := _state == "crouch_default"
	var driving := _state == "vehicle_default"
	var typing := _state == "typing_default"
	# 高细节 GLB 也必须进入办公室坐姿；只调整表现层根节点，不改变玩家
	# 根节点、碰撞体、交互挂点、任务状态或存档坐标。此前这里只处理了
	# 头部和前臂，躯干仍保持站立高度，导致桌面、椅背和人物接触关系断裂。
	_high_detail_visual.scale = Vector3(1.0, 0.88 if crouched else (0.86 if typing else (0.82 if driving else 1.0)), 1.0)
	_high_detail_state_offset = Vector3(
		0.0,
		-0.20 if typing else (-0.12 if crouched else (-0.23 if driving else 0.0)),
		-0.06 if typing else 0.0
	)
	_high_detail_visual.position = _high_detail_base_position + _high_detail_state_offset
	_high_detail_visual.rotation_degrees = _high_detail_base_rotation + Vector3(-10.0 if typing else 0.0, 0.0, 0.0)
	var model_head := _high_detail_visual.find_child("AdvancedHead", true, false) as Node3D
	if model_head != null:
		model_head.rotation_degrees = Vector3(-7.0 if typing else 0.0, 0.0, 0.0)
	var left_forearm := _high_detail_visual.find_child("AdvancedForearmL", true, false) as Node3D
	var right_forearm := _high_detail_visual.find_child("AdvancedForearmR", true, false) as Node3D
	if left_forearm != null:
		left_forearm.rotation_degrees = Vector3(-12.0 if typing else 0.0, 0.0, -4.0 if typing else 0.0)
	if right_forearm != null:
		right_forearm.rotation_degrees = Vector3(-12.0 if typing else 0.0, 0.0, 4.0 if typing else 0.0)

func _apply_candidate_context_materials() -> void:
	if _candidate_context != "city":
		return
	var outer_names := [
		"候选主角夹克外套", "候选主角腰胯结构", "候选主角胸前护片",
		"候选主角背部拼接", "候选主角马甲前片", "候选主角马甲后片",
		"候选主角夹克下摆", "候选主角夹克前襟-左", "候选主角夹克前襟-右",
		"候选主角肩部夹克-左", "候选主角肩部夹克-右",
		"候选主角左肩圆角", "候选主角右肩圆角",
		"候选主角上臂-左", "候选主角上臂-右",
		"候选主角前臂-左", "候选主角前臂-右",
	]
	for node_name in outer_names:
		var mesh := get_node_or_null(node_name) as MeshInstance3D
		if mesh == null or not mesh.material_override is StandardMaterial3D:
			continue
		var material := (mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		# 城市参考帧的红色外套必须连贯覆盖肩膀和前臂；此前只染躯干，
		# 会让角色从背面看成“红色躯干加灰色机械臂”。手部仍保持皮肤色，
		# 办公室上下文不进入这里，因此不会污染办公室灰色工装。
		material.albedo_color = Color("873b36") if node_name.contains("背部") or node_name.contains("下摆") else Color("a3443d")
		material.roughness = 0.78
		mesh.material_override = material

func _apply_state_pose() -> void:
	var body := get_node_or_null("候选主角身体") as Node3D
	if body == null:
		return
	var crouched := _state == "crouch_default"
	body.position.y = -0.75 if _state == "vehicle_default" else (0.92 if crouched else 1.10)
	body.position.z = -0.65 if _state == "vehicle_default" else 0.0
	_pose_node("候选主角腰胯结构", Vector3(0.0, 0.73, 0.0), Vector3(0.0, 0.61, -0.01), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0), Vector3(1.16, 0.82, 0.70), Vector3(1.16, 0.76, 0.70))
	_pose_node("候选主角胸前护片", Vector3(0.0, 1.27, -0.255), Vector3(0.0, 1.09, -0.275), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背部拼接", Vector3(0.0, 1.30, 0.225), Vector3(0.0, 1.12, 0.245), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角肩胛带-左", Vector3(-0.20, 1.22, 0.255), Vector3(-0.20, 1.04, 0.275), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角肩胛带-右", Vector3(0.20, 1.22, 0.255), Vector3(0.20, 1.04, 0.275), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	# 参考帧中的蹲伏不是单纯的整体缩放：背包、头部、手臂和腿都要
	# 同步降低并略微前倾，才能在偏肩近景里保持完整的人体轮廓。
	_pose_node("候选主角马甲前片", Vector3(0.0, 1.12, -0.205), Vector3(0.0, 0.94, -0.235), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角马甲后片", Vector3(0.0, 1.12, 0.205), Vector3(0.0, 0.94, 0.225), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角夹克外套", Vector3(0.0, 1.10, 0.015), Vector3(0.0, 0.94, -0.01), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0), Vector3.ONE, Vector3(1.02, 0.94, 0.76))
	_pose_node("候选主角夹克下摆", Vector3(0.0, 0.76, 0.0), Vector3(0.0, 0.64, -0.01), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角衬衣", Vector3(0.0, 1.15, -0.22), Vector3(0.0, 0.97, -0.25), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角衬衣领口", Vector3(0.0, 1.48, -0.215), Vector3(0.0, 1.29, -0.235), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角内层拉链", Vector3(0.0, 1.22, -0.252), Vector3(0.0, 1.04, -0.275), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角腰带", Vector3(0.0, 0.78, 0.0), Vector3(0.0, 0.66, -0.01), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包", Vector3(0.0, 1.11, 0.285), Vector3(0.0, 0.96, 0.30), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包翻盖", Vector3(0.0, 1.36, 0.245), Vector3(0.0, 1.20, 0.26), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包底部", Vector3(0.0, 0.87, 0.255), Vector3(0.0, 0.75, 0.27), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包肩带-左", Vector3(-0.18, 1.17, 0.235), Vector3(-0.18, 1.01, 0.25), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包肩带-右", Vector3(0.18, 1.17, 0.235), Vector3(0.18, 1.01, 0.25), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角肩部夹克-左", Vector3(-0.27, 1.38, 0.08), Vector3(-0.27, 1.20, 0.04), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角肩部夹克-右", Vector3(0.27, 1.38, 0.08), Vector3(0.27, 1.20, 0.04), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角夹克前襟-左", Vector3(-0.13, 1.22, -0.255), Vector3(-0.13, 1.04, -0.275), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角夹克前襟-右", Vector3(0.13, 1.22, -0.255), Vector3(0.13, 1.04, -0.275), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角连帽外壳", Vector3(0.0, 1.73, 0.105), Vector3(0.0, 1.51, 0.05), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0), Vector3(1.10, 0.86, 0.82), Vector3(1.10, 0.80, 0.82))
	_pose_node("候选主角连帽内圈", Vector3(0.0, 1.59, 0.075), Vector3(0.0, 1.37, 0.025), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.78), Vector3(1.0, 0.90, 0.78))
	_pose_node("候选主角帽绳-左", Vector3(-0.10, 1.59, -0.06), Vector3(-0.10, 1.39, -0.08), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角帽绳-右", Vector3(0.10, 1.59, -0.06), Vector3(0.10, 1.39, -0.08), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角左肩圆角", Vector3(-0.30, 1.30, 0.02), Vector3(-0.30, 1.12, -0.02), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0), Vector3.ONE, Vector3(1.0, 0.72, 0.90))
	_pose_node("候选主角右肩圆角", Vector3(0.30, 1.30, 0.02), Vector3(0.30, 1.12, -0.02), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0), Vector3.ONE, Vector3(1.0, 0.72, 0.90))
	_pose_node("候选主角袖口-左", Vector3(-0.49, 0.69, -0.01), Vector3(-0.49, 0.57, -0.12), Vector3.ZERO, Vector3(0.0, 0.0, -34.0))
	_pose_node("候选主角袖口-右", Vector3(0.49, 0.69, -0.01), Vector3(0.49, 0.57, -0.12), Vector3.ZERO, Vector3(0.0, 0.0, 34.0))
	_pose_node("候选主角背包侧袋-左", Vector3(-0.18, 1.07, 0.305), Vector3(-0.18, 0.91, 0.325), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包侧袋-右", Vector3(0.18, 1.07, 0.305), Vector3(0.18, 0.91, 0.325), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包扣带-左", Vector3(-0.105, 1.25, 0.315), Vector3(-0.105, 1.09, 0.335), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包扣带-右", Vector3(0.105, 1.25, 0.315), Vector3(0.105, 1.09, 0.335), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角颈部", Vector3(0.0, 1.56, 0.0), Vector3(0.0, 1.37, -0.03), Vector3.ZERO, Vector3.ZERO)
	_pose_node("候选主角头部", Vector3(0.0, 1.76, 0.0), Vector3(0.0, 1.54, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角头发", Vector3(0.0, 1.91, 0.0), Vector3(0.0, 1.69, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角额前碎发", Vector3(0.0, 1.88, -0.17), Vector3(0.0, 1.66, -0.225), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角耳朵-左", Vector3(-0.195, 1.76, 0.0), Vector3(-0.195, 1.54, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角耳朵-右", Vector3(0.195, 1.76, 0.0), Vector3(0.195, 1.54, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角鼻梁", Vector3(0.0, 1.76, -0.218), Vector3(0.0, 1.54, -0.273), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眉毛-左", Vector3(-0.078, 1.835, -0.211), Vector3(-0.078, 1.615, -0.266), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眉毛-右", Vector3(0.078, 1.835, -0.211), Vector3(0.078, 1.615, -0.266), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眼睛-左", Vector3(-0.078, 1.80, -0.202), Vector3(-0.078, 1.58, -0.257), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眼睛-右", Vector3(0.078, 1.80, -0.202), Vector3(0.078, 1.58, -0.257), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角嘴部", Vector3(0.0, 1.695, -0.208), Vector3(0.0, 1.475, -0.263), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_pose_node("候选主角上臂" + suffix, Vector3(side * 0.37, 1.00, 0.0), Vector3(side * 0.37, 0.84, -0.045), Vector3(0.0, 0.0, side * -10.0), Vector3(0.0, 0.0, side * -18.0))
		_pose_node("候选主角前臂" + suffix, Vector3(side * 0.49, 0.84, -0.015), Vector3(side * 0.49, 0.69, -0.095), Vector3(0.0, 0.0, side * -24.0), Vector3(0.0, 0.0, side * -34.0))
		_pose_node("候选主角手部" + suffix, Vector3(side * 0.59, 0.70, -0.03), Vector3(side * 0.59, 0.58, -0.13), Vector3.ZERO, Vector3.ZERO)
		for finger_index in range(3):
			var finger_offset := float(finger_index - 1) * 0.032
			_pose_node("候选主角指节-%s-%d" % [suffix, finger_index], Vector3(side * (0.59 + finger_offset), 0.68, -0.12), Vector3(side * (0.59 + finger_offset), 0.56, -0.22), Vector3(90.0, 0.0, 0.0), Vector3(90.0, 0.0, 0.0))
		_pose_node("候选主角腿部" + suffix, Vector3(side * 0.15, 0.46, 0.0), Vector3(side * 0.15, 0.34, -0.035), Vector3.ZERO, Vector3(-18.0, 0.0, 0.0), Vector3.ONE, Vector3(1.0, 0.86, 1.0))
		_pose_node("候选主角工装裤袋" + suffix, Vector3(side * 0.15, 0.49, 0.14), Vector3(side * 0.15, 0.38, 0.10), Vector3.ZERO, Vector3(-18.0, 0.0, 0.0))
		_pose_node("候选主角工装裤袋盖" + suffix, Vector3(side * 0.15, 0.61, 0.13), Vector3(side * 0.15, 0.50, 0.09), Vector3.ZERO, Vector3(-18.0, 0.0, 0.0))
		_pose_node("候选主角膝部拼接" + suffix, Vector3(side * 0.15, 0.36, -0.105), Vector3(side * 0.15, 0.25, -0.13), Vector3.ZERO, Vector3(-18.0, 0.0, 0.0))
		_pose_node("候选主角鞋子" + suffix, Vector3(side * 0.15, 0.11, -0.08), Vector3(side * 0.15, 0.08, -0.18), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
		_pose_node("候选主角鞋面侧条" + suffix, Vector3(side * 0.15, 0.16, -0.25), Vector3(side * 0.15, 0.12, -0.35), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
		_pose_node("候选主角鞋底" + suffix, Vector3(side * 0.15, 0.035, -0.08), Vector3(side * 0.15, 0.02, -0.18), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
		_pose_node("候选主角细节鞋带" + suffix, Vector3(side * 0.15, 0.17, -0.265), Vector3(side * 0.15, 0.12, -0.35), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
	_pose_node("候选主角工牌", Vector3(0.0, 1.28, -0.255), Vector3(0.0, 1.10, -0.29), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角工牌挂绳", Vector3(0.0, 1.42, -0.245), Vector3(0.0, 1.24, -0.27), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角细节下巴", Vector3(0.0, 1.68, -0.175), Vector3(0.0, 1.48, -0.23), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角细节额前发束-左", Vector3(-0.092, 1.93, -0.145), Vector3(-0.092, 1.71, -0.20), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角细节额前发束-右", Vector3(0.092, 1.93, -0.145), Vector3(0.092, 1.71, -0.20), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_set_typing_visibility(_state == "typing_default")
	_set_finger_detail_visibility(_state == "typing_default" or _state == "vehicle_default")
	_set_crouch_limb_visibility(_state != "crouch_default")
	_set_state_specific_clothing_visibility()
	if _state == "typing_default":
		_apply_typing_pose()
	if _state == "vehicle_default":
		_apply_vehicle_pose()
	_update_ground_contact_shadow_visibility()

func _update_ground_contact_shadow_visibility() -> void:
	for shadow in _ground_contact_shadows:
		if is_instance_valid(shadow):
			shadow.visible = _state != "vehicle_default"

func _set_typing_visibility(typing: bool) -> void:
	for node_name in ["候选主角背包", "候选主角背包翻盖", "候选主角背包底部", "候选主角背包肩带-左", "候选主角背包肩带-右", "候选主角背包侧袋-左", "候选主角背包侧袋-右", "候选主角背包扣带-左", "候选主角背包扣带-右", "候选主角细节胸袋-左", "候选主角细节胸袋-右", "候选主角细节拉链头", "候选主角细节背包中央扣", "候选主角细节下巴", "候选主角细节额前发束-左", "候选主角细节额前发束-右", "候选主角细节鞋带-左", "候选主角细节鞋带-右"]:
		var node := get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = not typing

func _set_state_specific_clothing_visibility() -> void:
	var typing := _state == "typing_default"
	var driving := _state == "vehicle_default"
	for node_name in ["候选主角办公室针织主体", "候选主角办公室针织领口"]:
		var node := get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = typing
	for node_name in ["候选主角办公室针织前片", "候选主角办公室针织后片"]:
		var panel := get_node_or_null(node_name) as Node3D
		if panel != null:
			panel.visible = typing
	for node_name in ["候选主角夹克外套", "候选主角腰胯结构", "候选主角胸前护片", "候选主角背部拼接", "候选主角马甲前片", "候选主角马甲后片", "候选主角夹克下摆", "候选主角衬衣", "候选主角衬衣领口", "候选主角内层拉链", "候选主角夹克前襟-左", "候选主角夹克前襟-右"]:
		var base_clothing := get_node_or_null(node_name) as Node3D
		if base_clothing != null:
			base_clothing.visible = not typing
	for node_name in ["候选主角载具红色前片", "候选主角载具红色后片", "候选主角载具红色肩线-左", "候选主角载具红色肩线-右"]:
		var node := get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = driving or (_candidate_context == "city" and not typing)
	# 两个参考近景都不需要城市背包遮住人体轮廓；自由行走状态仍保留它。
	for node_name in ["候选主角背包", "候选主角背包翻盖", "候选主角背包底部", "候选主角背包肩带-左", "候选主角背包肩带-右", "候选主角背包侧袋-左", "候选主角背包侧袋-右", "候选主角背包扣带-左", "候选主角背包扣带-右"]:
		var node := get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = not typing and not driving

func _set_finger_detail_visibility(visible: bool) -> void:
	for side in ["-左", "-右"]:
		for finger_index in range(3):
			var node := get_node_or_null("候选主角指节-%s-%d" % [side, finger_index]) as Node3D
			if node != null:
				node.visible = visible

func _set_crouch_limb_visibility(visible: bool) -> void:
	for side in ["-左", "-右"]:
		for part in ["上臂", "前臂", "手部", "袖口"]:
			var node := get_node_or_null("候选主角" + part + side) as Node3D
			if node != null:
				node.visible = visible

func _apply_typing_pose() -> void:
	# 参考 office-10 是工位侧面的坐姿打字镜头；这里只改表现节点，
	# 不改变玩家根节点、碰撞体、交互挂点、任务状态或存档坐标。
	# 坐姿接触采用分段收拢：胯部压到坐垫高度，胸腔向桌面前倾，
	# 前臂和手部仍保持在键盘坐标上，避免“臀部悬空”或“手离开键盘”。
	_set_visual_pose("候选主角身体", Vector3(0.0, 0.62, 0.02), Vector3(-18.0, 0.0, 0.0), Vector3(1.08, 0.96, 0.72))
	_set_visual_pose("候选主角腰胯结构", Vector3(0.0, 0.22, 0.02), Vector3(-12.0, 0.0, 0.0), Vector3(1.16, 0.78, 0.70))
	_set_visual_pose("候选主角胸前护片", Vector3(0.0, 0.68, -0.27), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角背部拼接", Vector3(0.0, 0.71, 0.24), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角肩胛带-左", Vector3(-0.20, 0.63, 0.27), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角肩胛带-右", Vector3(0.20, 0.63, 0.27), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角夹克外套", Vector3(0.0, 0.66, 0.02), Vector3(-18.0, 0.0, 0.0), Vector3(1.08, 0.96, 0.76))
	_set_visual_pose("候选主角马甲前片", Vector3(0.0, 0.68, -0.20), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角马甲后片", Vector3(0.0, 0.68, 0.22), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角夹克下摆", Vector3(0.0, 0.40, 0.02), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角衬衣", Vector3(0.0, 0.72, -0.22), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角衬衣领口", Vector3(0.0, 1.04, -0.22), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角内层拉链", Vector3(0.0, 0.80, -0.25), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角腰带", Vector3(0.0, 0.40, 0.02), Vector3(-10.0, 0.0, 0.0))
	# 办公室针织前后片必须与主体使用同一套坐姿下沉，否则薄片会留在
	# 站立高度，形成漂浮衣片并破坏胸腔、椅背和桌面的接触关系。
	_set_visual_pose("候选主角办公室针织前片", Vector3(0.0, 0.80, -0.255), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角办公室针织后片", Vector3(0.0, 0.80, 0.255), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角办公室针织主体", Vector3(0.0, 0.80, 0.0), Vector3(-10.0, 0.0, 0.0), Vector3(1.02, 0.98, 0.74))
	_set_visual_pose("候选主角办公室针织领口", Vector3(0.0, 1.05, -0.255), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角夹克前襟-左", Vector3(-0.13, 0.80, -0.27), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角夹克前襟-右", Vector3(0.13, 0.80, -0.27), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角肩部夹克-左", Vector3(-0.27, 0.95, 0.04), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角肩部夹克-右", Vector3(0.27, 0.95, 0.04), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角左肩圆角", Vector3(-0.30, 0.88, -0.02), Vector3(-30.0, 0.0, 0.0), Vector3(1.0, 0.78, 0.90))
	_set_visual_pose("候选主角右肩圆角", Vector3(0.30, 0.88, -0.02), Vector3(-30.0, 0.0, 0.0), Vector3(1.0, 0.78, 0.90))
	_set_visual_pose("候选主角连帽外壳", Vector3(0.0, 1.42, 0.05), Vector3(-10.0, 0.0, 0.0), Vector3(1.08, 0.82, 0.78))
	_set_visual_pose("候选主角帽绳-左", Vector3(-0.10, 1.35, -0.08), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角帽绳-右", Vector3(0.10, 1.35, -0.08), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角颈部", Vector3(0.0, 1.19, -0.02), Vector3.ZERO)
	_set_visual_pose("候选主角头部", Vector3(0.0, 1.36, -0.08), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角头发", Vector3(0.0, 1.45, -0.06), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角额前碎发", Vector3(0.0, 1.53, -0.22), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角耳朵-左", Vector3(-0.195, 1.39, -0.08), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角耳朵-右", Vector3(0.195, 1.39, -0.08), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角鼻梁", Vector3(0.0, 1.37, -0.29), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角眼睛-左", Vector3(-0.078, 1.41, -0.27), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角眼睛-右", Vector3(0.078, 1.41, -0.27), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角眉毛-左", Vector3(-0.078, 1.45, -0.29), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角眉毛-右", Vector3(0.078, 1.45, -0.29), Vector3(-12.0, 0.0, 0.0))
	_set_visual_pose("候选主角嘴部", Vector3(0.0, 1.29, -0.28), Vector3(-12.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_set_visual_pose("候选主角上臂" + suffix, Vector3(side * 0.34, 0.72, -0.14), Vector3(-42.0, 0.0, side * -12.0))
		# 工位候选键盘顶面约为 y=0.96；_set_visual_pose 会额外下沉
		# typing_default 的表现层 0.62 米，因此手部局部 y 取 0.58，
		# 让手掌落到键盘上方，而不是悬在桌面上方约 20 厘米。
		_set_visual_pose("候选主角前臂" + suffix, Vector3(side * 0.42, 0.74, -0.55), Vector3(-68.0, 0.0, side * -10.0))
		_set_visual_pose("候选主角手部" + suffix, Vector3(side * 0.43, 0.58, -0.84), Vector3.ZERO)
		for finger_index in range(3):
			var finger_offset := float(finger_index - 1) * 0.032
			_set_visual_pose("候选主角指节-%s-%d" % [suffix, finger_index], Vector3(side * (0.43 + finger_offset), 0.54, -0.96), Vector3(90.0, 0.0, 0.0))
		_set_visual_pose("候选主角袖口" + suffix, Vector3(side * 0.46, 0.68, -0.52), Vector3(-52.0, 0.0, side * -12.0))
		_set_visual_pose("候选主角腿部" + suffix, Vector3(side * 0.15, 0.22, -0.23), Vector3(-82.0, 0.0, 0.0), Vector3(1.0, 0.90, 1.0))
		_set_visual_pose("候选主角工装裤袋" + suffix, Vector3(side * 0.15, 0.20, -0.16), Vector3(-82.0, 0.0, 0.0))
		_set_visual_pose("候选主角工装裤袋盖" + suffix, Vector3(side * 0.15, 0.31, -0.15), Vector3(-82.0, 0.0, 0.0))
		_set_visual_pose("候选主角膝部拼接" + suffix, Vector3(side * 0.15, 0.04, -0.52), Vector3(-82.0, 0.0, 0.0))
		_set_visual_pose("候选主角鞋子" + suffix, Vector3(side * 0.15, 0.11, -0.75), Vector3(-5.0, 0.0, 0.0))
		_set_visual_pose("候选主角鞋面侧条" + suffix, Vector3(side * 0.15, 0.16, -0.91), Vector3(-5.0, 0.0, 0.0))
		_set_visual_pose("候选主角鞋底" + suffix, Vector3(side * 0.15, 0.035, -0.75), Vector3(-5.0, 0.0, 0.0))
	_set_visual_pose("候选主角工牌", Vector3(0.0, 1.08, -0.28), Vector3(-10.0, 0.0, 0.0))
	_set_visual_pose("候选主角工牌挂绳", Vector3(0.0, 1.22, -0.27), Vector3(-10.0, 0.0, 0.0))

func _set_visual_pose(node_name: String, position: Vector3, rotation: Vector3, scale := Vector3.ONE) -> void:
	var node := get_node_or_null(node_name) as Node3D
	if node == null:
		return
	if _state == "typing_default":
		# 玩家根节点仍保持站立碰撞高度；只有表现节点下沉到工位椅面，
		# 让手部能与键盘同高，同时不改变移动、碰撞和交互挂点。
		position.y -= 0.62
	node.position = position
	node.rotation_degrees = rotation
	node.scale = scale

func _apply_vehicle_pose() -> void:
	# 载具挂载点位于座椅上方；所有表现节点必须一起下沉并向车把
	# 前倾，否则只移动躯干会形成“站在车顶”的错误视觉。
	_set_vehicle_pose("候选主角身体", Vector3(0.0, -0.15, -0.32), Vector3(-8.0, 0.0, 0.0), Vector3(1.02, 0.90, 0.70))
	_set_vehicle_pose("候选主角腰胯结构", Vector3(0.0, -0.37, -0.30), Vector3(-8.0, 0.0, 0.0), Vector3(1.16, 0.76, 0.70))
	_set_vehicle_pose("候选主角胸前护片", Vector3(0.0, -0.05, -0.57), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背部拼接", Vector3(0.0, -0.02, -0.08), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角肩胛带-左", Vector3(-0.20, -0.07, 0.24), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角肩胛带-右", Vector3(0.20, -0.07, 0.24), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角夹克外套", Vector3(0.0, -0.15, -0.30), Vector3(-8.0, 0.0, 0.0), Vector3(1.04, 0.90, 0.74))
	_set_vehicle_pose("候选主角马甲前片", Vector3(0.0, -0.15, -0.53), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角马甲后片", Vector3(0.0, -0.15, -0.12), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角夹克下摆", Vector3(0.0, -0.37, -0.30), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角衬衣", Vector3(0.0, -0.13, -0.55), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角衬衣领口", Vector3(0.0, 0.19, -0.52), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角内层拉链", Vector3(0.0, -0.05, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角腰带", Vector3(0.0, -0.37, -0.30), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角载具红色前片", Vector3(0.0, -0.15, -0.59), Vector3(-8.0, 0.0, 0.0))
	# 车尾参考镜头中的红色上衣只应覆盖肩到腰的短袖轮廓；上一版纵向
	# 拉伸过度，形成了整块红色长方体。压回短上衣比例，并略微下沉，
	# 仍不改变玩家根节点或驾驶挂点。
	_set_vehicle_pose("候选主角载具红色后片", Vector3(0.0, 0.23, 0.48), Vector3(-8.0, 0.0, 0.0), Vector3(1.06, 1.28, 0.92))
	_set_vehicle_pose("候选主角载具红色肩线-左", Vector3(-0.25, 0.31, 0.40), Vector3(-8.0, 0.0, 0.0), Vector3(0.94, 1.28, 0.94))
	_set_vehicle_pose("候选主角载具红色肩线-右", Vector3(0.25, 0.31, 0.40), Vector3(-8.0, 0.0, 0.0), Vector3(0.94, 1.28, 0.94))
	_set_vehicle_pose("候选主角背包", Vector3(0.0, -0.13, 0.31), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包翻盖", Vector3(0.0, 0.14, 0.29), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包底部", Vector3(0.0, -0.37, 0.31), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包肩带-左", Vector3(-0.18, -0.07, 0.27), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包肩带-右", Vector3(0.18, -0.07, 0.27), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角肩部夹克-左", Vector3(-0.27, -0.08, 0.08), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角肩部夹克-右", Vector3(0.27, -0.08, 0.08), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角夹克前襟-左", Vector3(-0.13, -0.05, -0.30), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角夹克前襟-右", Vector3(0.13, -0.05, -0.30), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角连帽外壳", Vector3(0.0, 0.57, -0.28), Vector3(-8.0, 0.0, 0.0), Vector3(1.10, 0.78, 0.82))
	_set_vehicle_pose("候选主角连帽内圈", Vector3(0.0, 0.42, -0.28), Vector3(-8.0, 0.0, 0.0), Vector3(1.0, 0.90, 0.78))
	_set_vehicle_pose("候选主角帽绳-左", Vector3(-0.10, 0.42, -0.36), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角帽绳-右", Vector3(0.10, 0.42, -0.36), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角左肩圆角", Vector3(-0.30, 0.07, -0.10), Vector3(-38.0, 0.0, 0.0), Vector3(1.0, 0.70, 0.90))
	_set_vehicle_pose("候选主角右肩圆角", Vector3(0.30, 0.07, -0.10), Vector3(-38.0, 0.0, 0.0), Vector3(1.0, 0.70, 0.90))
	_set_vehicle_pose("候选主角袖口-左", Vector3(-0.42, -0.32, -0.62), Vector3(-30.0, 0.0, -16.0))
	_set_vehicle_pose("候选主角袖口-右", Vector3(0.42, -0.32, -0.62), Vector3(-30.0, 0.0, 16.0))
	_set_vehicle_pose("候选主角背包侧袋-左", Vector3(-0.18, -0.07, 0.34), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包侧袋-右", Vector3(0.18, -0.07, 0.34), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包扣带-左", Vector3(-0.105, 0.09, 0.35), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包扣带-右", Vector3(0.105, 0.09, 0.35), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角颈部", Vector3(0.0, 0.25, -0.32), Vector3.ZERO)
	_set_vehicle_pose("候选主角头部", Vector3(0.0, 0.57, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角头发", Vector3(0.0, 0.74, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角额前碎发", Vector3(0.0, 0.70, -0.55), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角耳朵-左", Vector3(-0.195, 0.57, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角耳朵-右", Vector3(0.195, 0.57, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角鼻梁", Vector3(0.0, 0.57, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眉毛-左", Vector3(-0.078, 0.61, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眉毛-右", Vector3(0.078, 0.61, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眼睛-左", Vector3(-0.078, 0.61, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眼睛-右", Vector3(0.078, 0.61, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角嘴部", Vector3(0.0, 0.53, -0.58), Vector3(-8.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_set_vehicle_pose("候选主角上臂" + suffix, Vector3(side * 0.34, 0.29, -0.50), Vector3(-30.0, 0.0, side * -16.0))
		_set_vehicle_pose("候选主角前臂" + suffix, Vector3(side * 0.40, 0.14, -0.70), Vector3(-42.0, 0.0, side * -10.0))
		_set_vehicle_pose("候选主角手部" + suffix, Vector3(side * 0.42, 0.08, -0.86), Vector3.ZERO)
		for finger_index in range(3):
			var finger_offset := float(finger_index - 1) * 0.032
			_set_vehicle_pose("候选主角指节-%s-%d" % [suffix, finger_index], Vector3(side * (0.42 + finger_offset), 0.06, -0.98), Vector3(90.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角腿部" + suffix, Vector3(side * 0.18, -1.02, 0.02), Vector3(-72.0, 0.0, 0.0), Vector3(1.0, 0.88, 1.0))
		_set_vehicle_pose("候选主角工装裤袋" + suffix, Vector3(side * 0.18, -0.96, 0.12), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角工装裤袋盖" + suffix, Vector3(side * 0.18, -0.82, 0.10), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角膝部拼接" + suffix, Vector3(side * 0.18, -0.88, -0.12), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角鞋子" + suffix, Vector3(side * 0.20, -1.18, -0.30), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角鞋面侧条" + suffix, Vector3(side * 0.20, -1.12, -0.50), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角鞋底" + suffix, Vector3(side * 0.20, -1.22, -0.34), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角细节鞋带" + suffix, Vector3(side * 0.20, -1.10, -0.51), Vector3(-72.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角工牌", Vector3(0.0, 0.03, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角工牌挂绳", Vector3(0.0, 0.21, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角细节下巴", Vector3(0.0, 0.42, -0.53), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角细节额前发束-左", Vector3(-0.092, 0.70, -0.55), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角细节额前发束-右", Vector3(0.092, 0.70, -0.55), Vector3(-8.0, 0.0, 0.0))

func _set_vehicle_pose(node_name: String, position: Vector3, rotation: Vector3, scale := Vector3.ONE) -> void:
	var node := get_node_or_null(node_name) as Node3D
	if node == null:
		return
	node.position = position
	node.rotation_degrees = rotation
	node.scale = scale

func _pose_node(node_name: String, standing_position: Vector3, crouch_position: Vector3, standing_rotation: Vector3, crouch_rotation: Vector3, standing_scale := Vector3.ONE, crouch_scale := Vector3.ONE) -> void:
	var node := get_node_or_null(node_name) as Node3D
	if node == null:
		return
	var crouched := _state == "crouch_default"
	node.position = crouch_position if crouched else standing_position
	node.rotation_degrees = crouch_rotation if crouched else standing_rotation
	node.scale = crouch_scale if crouched else standing_scale

func _add_animation_track(animation: Animation, property_path: String, first_value: Vector3, second_value: Vector3) -> void:
	if animation == null:
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(property_path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, first_value)
	animation.track_insert_key(track, 0.5, second_value)
	animation.track_insert_key(track, 1.0, first_value)

func _material(color: Color, roughness: float = 0.68) -> StandardMaterial3D:
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
	add_child(node)

func _add_sphere(node_name: String, at: Vector3, radius: float, color: Color, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_capsule(node_name: String, at: Vector3, radius: float, height: float, color: Color, rotation: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_scaled_capsule(node_name: String, radius: float, height: float, at: Vector3, color: Color, scale: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_scaled_sphere(node_name: String, radius: float, at: Vector3, color: Color, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_tapered_cylinder(node_name: String, top_radius: float, bottom_radius: float, height: float, at: Vector3, color: Color, scale: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 4
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_scaled_cylinder(node_name: String, radius: float, height: float, at: Vector3, color: Color, scale: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.rings = 4
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

func _add_torus(node_name: String, inner_radius: float, outer_radius: float, at: Vector3, color: Color, scale: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 32
	mesh.ring_segments = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color, 0.84)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	add_child(node)

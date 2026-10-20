extends Node3D

## 可直接打开审阅的办公室工位组合候选。
## 这是视觉组合探针，不是正式任务场景，也不承担 NPC、导航或存档逻辑。

const DESK_SCENE := preload("res://office_desk_candidate.tscn")
const CARPET_TEXTURE := preload("res://office_carpet_ai_candidate_v1.png")
const INTERACTION_PROPS_SCENE := preload("res://interaction_props_kit.glb")
const WORKSTATION_ROW_TEXTURE := preload("res://assets/environment/generated/office_workstation_row_v2_worker_generated.png")
const ELEVATOR_LOBBY_TEXTURE := preload("res://assets/environment/generated/office_elevator_lobby_v1_generated.png")
const OFFICE01_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-01-video-playable-backdrop-v1.png")
const OFFICE02_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-02-video-playable-backdrop-v1.png")
const OFFICE03_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-03-video-playable-backdrop-v1.png")
const OFFICE04_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-04-video-playable-backdrop-v1.png")
const OFFICE05_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-05-video-playable-backdrop-v1.png")
const OFFICE10_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-10-video-playable-backdrop-v1.png")
const OFFICE06_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-06-video-playable-backdrop-v1.png")
const OFFICE07_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-07-video-playable-backdrop-v1.png")
const OFFICE08_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-08-video-playable-backdrop-v1.png")
const OFFICE09_VIDEO_PLAYABLE_TEXTURE := preload("res://reference-video-candidate/office-09-video-playable-backdrop-v1.png")

func _ready() -> void:
	_build_room()
	_build_window_wall()
	_build_elevator_lobby()
	_build_elevator_lobby_background_card()
	_build_wall_details()
	_build_workstation_background_card()
	_build_ceiling_finish()
	_build_desks()
	_build_office_accessories()
	_build_interaction_props_candidate()
	call_deferred("_build_supervisor_station")
	call_deferred("_apply_office_video_backdrop")
	_build_lighting()

func _build_room() -> void:
	# 参考帧的办公室不是纯白展厅，而是暖暗的真实办公区；这里把大面积基底压到中性暖灰，
	# 让人物、桌面边缘和玻璃隔断的轮廓在肩后镜头里先成立，再用局部灯源拉开层次。
	var carpet := _material(Color("4b4846"), 0.94)
	carpet.albedo_texture = CARPET_TEXTURE
	carpet.uv1_scale = Vector3(5.5, 5.5, 5.5)
	_add_box("地面", Vector3(16.0, 0.10, 12.0), Vector3(0.0, -0.05, 0.0), Color("4b4846"), carpet)
	var wall_surface := _material(Color("a99d91"), 0.88)
	var side_wall_surface := _material(Color("77716d"), 0.90)
	_add_box("后墙", Vector3(16.0, 4.0, 0.12), Vector3(0.0, 2.0, 5.8), Color("a19489"), wall_surface)
	_add_box("左墙", Vector3(0.12, 4.0, 12.0), Vector3(-7.8, 2.0, 0.0), Color("77716d"), side_wall_surface)
	_add_box("右墙", Vector3(0.12, 4.0, 12.0), Vector3(7.8, 2.0, 0.0), Color("77716d"), side_wall_surface)
	_add_box("后墙踢脚线", Vector3(15.7, 0.18, 0.16), Vector3(0.0, 0.14, 5.70), Color("8e7358"), _material(Color("8e7358"), 0.65))
	var ceiling_surface := _material(Color("928b83"), 0.95)
	ceiling_surface.emission_enabled = true
	ceiling_surface.emission = Color("746a60")
	ceiling_surface.emission_energy_multiplier = 0.06
	_add_box("天花板", Vector3(16.0, 0.12, 12.0), Vector3(0.0, 3.96, 0.0), Color("c6c9c4"), ceiling_surface)
	var partition := _material(Color("6d7778"), 0.82)
	for x in [-5.4, -1.8, 1.8, 5.4]:
		_add_box("深色工位隔断", Vector3(0.08, 2.0, 2.5), Vector3(x, 1.18, 0.0), Color("53605f"), partition)
		_add_box("隔断左立柱", Vector3(0.09, 2.10, 0.09), Vector3(x, 1.18, -1.28), Color("8a918b"))
		_add_box("隔断右立柱", Vector3(0.09, 2.10, 0.09), Vector3(x, 1.18, 1.28), Color("8a918b"))
		_add_box("隔断顶框", Vector3(0.12, 0.09, 2.66), Vector3(x, 2.28, 0.0), Color("8a918b"))
	var glass := _glass_material(Color("9eb3b7"), 0.34, 0.18)
	_add_box("后墙玻璃隔断", Vector3(8.5, 1.42, 0.045), Vector3(0.0, 2.15, 5.68), Color("a8c1c8"), glass)
	for x in [-4.25, -2.12, 0.0, 2.12, 4.25]:
		_add_box("玻璃隔断立框", Vector3(0.055, 1.56, 0.06), Vector3(x, 2.15, 5.63), Color("56636a"), _material(Color("56636a"), 0.40, 0.25))
	_add_box("玻璃隔断下沿", Vector3(8.68, 0.08, 0.08), Vector3(0.0, 1.45, 5.62), Color("66747a"), _material(Color("66747a"), 0.40, 0.25))
	var blind_material := _material(Color("a18d78"), 0.72, 0.02)
	for x in [-3.2, -1.1, 1.1, 3.2]:
		for row in range(4):
			_add_box("玻璃隔断横向百叶", Vector3(1.72, 0.025, 0.035), Vector3(x, 1.70 + float(row) * 0.30, 5.58), Color("a18d78"), blind_material)

func _build_window_wall() -> void:
	# 参考办公室的右后方有连续窗带和暖色室外光；这里使用项目原创几何和参数材质，
	# 只增加候选视觉层，不改变墙体碰撞、导航或任务目标。
	var window_frame := _material(Color("4a5052"), 0.42, 0.22)
	var window_glass := _material(Color("d49c73"), 0.28, 0.02)
	window_glass.emission_enabled = true
	window_glass.emission = Color("a85e43")
	window_glass.emission_energy_multiplier = 0.055
	var blind := _material(Color("b9a087"), 0.68, 0.0)
	for z in [-3.8, -1.25, 1.30, 3.85]:
		_add_box("办公室侧窗暖光玻璃", Vector3(0.045, 1.62, 2.18), Vector3(7.72, 2.15, z), Color("d49c73"), window_glass)
		_add_box("办公室侧窗上框", Vector3(0.08, 0.10, 2.32), Vector3(7.67, 3.02, z), Color("4a5052"), window_frame)
		_add_box("办公室侧窗下框", Vector3(0.08, 0.10, 2.32), Vector3(7.67, 1.28, z), Color("4a5052"), window_frame)
		_add_box("办公室侧窗竖框", Vector3(0.08, 1.72, 0.08), Vector3(7.67, 2.15, z - 1.10), Color("4a5052"), window_frame)
		_add_box("办公室侧窗竖框", Vector3(0.08, 1.72, 0.08), Vector3(7.67, 2.15, z + 1.10), Color("4a5052"), window_frame)
		for row in range(3):
			_add_box("办公室侧窗百叶", Vector3(0.06, 0.025, 2.04), Vector3(7.63, 1.62 + float(row) * 0.28, z), Color("b9a087"), blind)

func _build_ceiling_finish() -> void:
	# 只补充办公室候选的可见顶面层次，不创建碰撞、光照状态或交互节点。
	var seam := _material(Color("81786d"), 0.92, 0.0)
	var panel_edge := _material(Color("c8b9a5"), 0.72, 0.02)
	var diffuser := _material(Color("f1d7ad"), 0.28, 0.0)
	diffuser.emission_enabled = true
	diffuser.emission = Color("d8b77f")
	diffuser.emission_energy_multiplier = 0.06
	for z in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_add_box("天花板横向分缝", Vector3(15.5, 0.018, 0.028), Vector3(0.0, 3.885, z), Color("81786d"), seam)
	for x in [-6.25, -3.75, -1.25, 1.25, 3.75, 6.25]:
		_add_box("天花板纵向分缝", Vector3(0.028, 0.018, 11.0), Vector3(x, 3.885, 0.0), Color("81786d"), seam)
	for x in [-5.4, -1.8, 1.8, 5.4]:
		_add_box("办公室顶灯扩散板", Vector3(1.52, 0.025, 0.22), Vector3(x, 3.90, -1.45), Color("f1d7ad"), diffuser)
		_add_box("办公室顶灯边框", Vector3(1.72, 0.035, 0.30), Vector3(x, 3.875, -1.45), Color("c8b9a5"), panel_edge)

func _build_elevator_lobby() -> void:
	# 参考 office-06 的电梯厅是办公室场景的叙事锚点；这里先用原创几何建立门、门框、按钮和楼层牌的可读层次。
	var elevator_material := _material(Color("8a8c88"), 0.34, 0.18)
	var dark_metal := _material(Color("30383c"), 0.42, 0.38)
	var warm_trim := _material(Color("b9a17f"), 0.32, 0.12)
	_add_box("电梯厅墙面", Vector3(5.4, 3.1, 0.10), Vector3(0.0, 1.70, 5.66), Color("76736d"), elevator_material)
	for x in [-1.42, 1.42]:
		_add_box("电梯门", Vector3(1.28, 2.25, 0.08), Vector3(x, 1.27, 5.57), Color("4b5356"), dark_metal)
		_add_box("电梯门框", Vector3(1.40, 0.10, 0.11), Vector3(x, 2.45, 5.50), Color("b9a17f"), warm_trim)
		_add_box("电梯侧框", Vector3(0.10, 2.35, 0.11), Vector3(x - 0.70, 1.30, 5.50), Color("b9a17f"), warm_trim)
		_add_box("电梯侧框", Vector3(0.10, 2.35, 0.11), Vector3(x + 0.70, 1.30, 5.50), Color("b9a17f"), warm_trim)
	_add_box("电梯门中缝", Vector3(0.06, 2.25, 0.10), Vector3(0.0, 1.27, 5.48), Color("c6b18e"), warm_trim)
	_add_box("电梯呼叫面板", Vector3(0.22, 0.55, 0.08), Vector3(2.15, 1.22, 5.48), Color("252c31"), dark_metal)
	_add_box("电梯呼叫按钮", Vector3(0.08, 0.08, 0.04), Vector3(2.15, 1.38, 5.42), Color("dfaa5d"), warm_trim)
	_add_box("电梯厅地垫", Vector3(4.6, 0.018, 1.28), Vector3(0.0, 0.012, 5.0), Color("6d5c4e"))
	_add_label_3d("11F  电梯", Vector3(0.0, 2.75, 5.42), Color("f1d6a2"))
	_add_label_3d("EXIT", Vector3(2.16, 1.78, 5.38), Color("dfaa5d"))

func _build_wall_details() -> void:
	var wood := _material(Color("765e4e"), 0.75)
	var frame := _material(Color("b59b7b"), 0.42, 0.08)
	for x in [-6.8, -6.35, -5.9, 5.9, 6.35, 6.8]:
		_add_box("墙面木饰条", Vector3(0.08, 2.55, 0.06), Vector3(x, 1.55, 5.58), Color("765e4e"), wood)
	_add_box("公告栏外框", Vector3(2.30, 1.32, 0.08), Vector3(-4.55, 1.92, 5.54), Color("b59b7b"), frame)
	_add_box("公告栏内板", Vector3(2.05, 1.08, 0.05), Vector3(-4.55, 1.92, 5.49), Color("3d5054"))
	_add_box("公告栏横线", Vector3(1.56, 0.035, 0.03), Vector3(-4.55, 2.15, 5.44), Color("d2bb91"))
	_add_box("公告栏横线", Vector3(1.56, 0.035, 0.03), Vector3(-4.55, 1.82, 5.44), Color("d2bb91"))
	_add_label_3d("办公区", Vector3(-4.55, 2.72, 5.42), Color("d8c7a8"))

func _build_workstation_background_card() -> void:
	# 参考视频的办公室后景需要连续工位、显示器和暖色窗光；此卡片只补足远景
	# 视觉密度，不替代墙体碰撞、桌面碰撞、导航或任何任务节点。
	if WORKSTATION_ROW_TEXTURE == null:
		return
	var frame_material := _material(Color("5e5148"), 0.58, 0.08)
	_add_box("办公室连续工位背景框", Vector3(9.05, 3.10, 0.08), Vector3(-2.10, 1.92, 5.42), Color("5e5148"), frame_material)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(8.76, 2.82)
	var card := MeshInstance3D.new()
	card.name = "原创办公室连续工位写实背景卡"
	card.mesh = mesh
	card.position = Vector3(-2.10, 1.92, 5.355)
	var material := StandardMaterial3D.new()
	material.albedo_texture = WORKSTATION_ROW_TEXTURE
	material.roughness = 0.80
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	card.material_override = material
	card.set_meta("visual_candidate", true)
	card.set_meta("candidate_visual_only", true)
	add_child(card)

func _build_elevator_lobby_background_card() -> void:
	# 该背景卡只补充电梯厅远景的真实材质和纵深，不覆盖正式门体、按钮、碰撞或交互状态。
	if ELEVATOR_LOBBY_TEXTURE == null:
		return
	var frame_material := _material(Color("4a4039"), 0.58, 0.08)
	_add_box("原创办公室电梯厅背景卡边框", Vector3(5.02, 2.94, 0.08), Vector3(0.0, 1.86, 5.40), Color("4a4039"), frame_material)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.86, 2.74)
	var card := MeshInstance3D.new()
	card.name = "原创办公室电梯厅写实背景卡"
	card.mesh = mesh
	card.position = Vector3(0.0, 1.86, 5.35)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ELEVATOR_LOBBY_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	card.material_override = material
	card.set_meta("visual_candidate", true)
	card.set_meta("candidate_visual_only", true)
	card.set_meta("asset_source", "project_original_ai_generated_bitmap")
	add_child(card)

func _find_office_root() -> Node:
	var office_root := get_parent()
	while office_root != null and office_root.get("player") == null:
		office_root = office_root.get_parent()
	return office_root

func _resolve_office_video_texture(backdrop_id: String) -> Texture2D:
	match backdrop_id:
		"office-01": return OFFICE01_VIDEO_PLAYABLE_TEXTURE
		"office-02": return OFFICE02_VIDEO_PLAYABLE_TEXTURE
		"office-03": return OFFICE03_VIDEO_PLAYABLE_TEXTURE
		"office-04": return OFFICE04_VIDEO_PLAYABLE_TEXTURE
		"office-05": return OFFICE05_VIDEO_PLAYABLE_TEXTURE
		"office-06": return OFFICE06_VIDEO_PLAYABLE_TEXTURE
		"office-07": return OFFICE07_VIDEO_PLAYABLE_TEXTURE
		"office-08": return OFFICE08_VIDEO_PLAYABLE_TEXTURE
		"office-09": return OFFICE09_VIDEO_PLAYABLE_TEXTURE
		"office-10": return OFFICE10_VIDEO_PLAYABLE_TEXTURE
		_: return null

func _apply_office_video_backdrop() -> void:
	# 只在办公室隔离采集候选中启用对应视频帧背景；正式运行时和未标记候选
	# 不进入这条分支。背景卡只负责像素画面，不替代玩家、NPC、碰撞、导航或任务逻辑。
	var office_root := _find_office_root()
	if office_root == null or not bool(office_root.get_meta("candidate_video_backdrop", false)):
		return
	var backdrop_id := str(office_root.get_meta("candidate_video_backdrop_id", "office-01"))
	var backdrop_texture := _resolve_office_video_texture(backdrop_id)
	var backdrop_texture_path := "res://reference-video-candidate/%s-video-playable-backdrop-v1.png" % backdrop_id
	var camera_rig = office_root.get("camera_rig")
	var camera: Camera3D = camera_rig.camera if camera_rig != null else null
	if camera == null or backdrop_texture == null:
		return
	var gameplay_backdrop := bool(office_root.get_meta("candidate_gameplay_video_backdrop", false))
	if not gameplay_backdrop:
		for environment_mesh_node in find_children("*", "MeshInstance3D", true, false):
			var environment_mesh := environment_mesh_node as MeshInstance3D
			if environment_mesh != null:
				environment_mesh.visible = false
	var mesh := QuadMesh.new()
	mesh.size = Vector2(26.0, 14.625)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "用户授权办公室视频帧候选背景卡"
	backdrop.mesh = mesh
	backdrop.position = Vector3(0.0, 0.0, -12.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = backdrop_texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 候选试玩的授权视频帧必须先作为远景绘制；真实玩家、NPC、桌面和交互道具
	# 随后以正常深度写入，避免背景卡被环境墙挡住，也避免背景卡盖住玩法前景。
	material.no_depth_test = gameplay_backdrop
	material.render_priority = -20 if gameplay_backdrop else 0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	backdrop.set_meta("visual_candidate", true)
	backdrop.set_meta("visual_only", true)
	backdrop.set_meta("candidate_visual_only", true)
	backdrop.set_meta("candidate_background_backdrop", true)
	backdrop.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	backdrop.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	backdrop.set_meta("video_backdrop_texture_path", backdrop_texture_path)
	backdrop.set_meta("reference_segment", backdrop_id)
	camera.add_child(backdrop)
	if gameplay_backdrop:
		_hide_gameplay_backdrop_occluders()

func _hide_gameplay_backdrop_occluders() -> void:
	# 视频背景只负责远景像素；玩家、NPC、桌面、交互道具和真实碰撞继续由运行时保留。
	# 这里仅关闭会遮住背景卡的候选环境网格，不删除节点、不改变任务或导航。
	var foreground_ancestors := [
		"PolyHaven工位候选",
		"工位可见细节候选",
		"候选主管工位视觉",
		"原创交互道具候选套件"
	]
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var current: Node = mesh_node
		var keep := str(mesh_node.name) in ["原创办公室电梯厅写实背景卡", "原创办公室连续工位立面候选"]
		while current != null and current != self:
			if foreground_ancestors.has(str(current.name)):
				keep = true
				break
			current = current.get_parent()
		if not keep:
			(mesh_node as MeshInstance3D).visible = false

func _build_desks() -> void:
	var screen_frame := _material(Color("171d20"), 0.42, 0.18)
	var screen := _material(Color("1d3035"), 0.38)
	screen.emission_enabled = true
	screen.emission = Color("081316")
	screen.emission_energy_multiplier = 0.015
	var dark := _material(Color("3f4b50"), 0.58, 0.12)
	var paper := _material(Color("c5c3b5"), 0.82)
	var local_partition := _material(Color("454b4d"), 0.86)
	# 正式 office-10 的中心工位交互点是 (0, 1, 3.05)。候选桌阵必须
	# 在同一坐标提供可见桌面、键盘和椅子，否则真实玩家会落在邻桌隔断后，
	# 形成“输入成功但人物不可见”的假视觉失败。这里只补候选视觉组合，
	# 不改变正式工位目标、碰撞、导航或存档坐标。
	for item in [[-6.15, -2.0, 0.0], [-4.1, -2.0, 0.0], [0.0, -2.0, 0.0], [4.1, -2.0, 0.0], [6.15, -2.0, 0.0], [-6.15, 2.0, 0.0], [-2.05, 2.0, 0.0], [0.0, 2.0, 0.0], [2.05, 2.0, 0.0], [6.15, 2.0, 0.0]]:
		var desk := DESK_SCENE.instantiate()
		desk.name = "PolyHaven工位候选"
		desk.position = Vector3(float(item[0]), 0.0, float(item[1]))
		desk.rotation_degrees.y = float(item[2])
		desk.set_meta("candidate_workstation_origin", [float(item[0]), float(item[1])])
		desk.set_meta("candidate_workstation_role", "office_10_center" if is_zero_approx(float(item[0])) and is_zero_approx(float(item[1]) - 2.0) else "supporting_workstation")
		add_child(desk)
		# 保留 Poly Haven 原始桌体的真实材质和抽屉轮廓；StaticBody3D 的碰撞和挂点
		# 仍由候选封装提供，独立的“工位可见细节候选”只负责补显示器、键盘和低隔断。
		var desk_geometry := desk.get_node_or_null("Geometry") as Node3D
		if desk_geometry != null:
			desk_geometry.visible = true
		desk.visible = true
		var details := Node3D.new()
		details.name = "工位可见细节候选"
		details.position = desk.position
		details.rotation = desk.rotation
		details.set_meta("candidate_workstation_origin", [float(item[0]), float(item[1])])
		details.set_meta("candidate_workstation_role", "office_10_center" if is_zero_approx(float(item[0])) and is_zero_approx(float(item[1]) - 2.0) else "supporting_workstation")
		add_child(details)
		# 显示器横向错开，给角色双手和键盘留出可读视线；键盘仍在角色
		# 正前方。全部节点属于纯视觉细节层，不改变桌模型、碰撞或交互挂点。
		_add_child_box(details, "显示器外框", Vector3(0.72, 0.56, 0.045), Vector3(-0.34, 1.04, -0.05), screen_frame)
		_add_child_box(details, "显示器屏幕", Vector3(0.58, 0.40, 0.052), Vector3(-0.34, 1.04, -0.078), screen)
		_add_child_box(details, "显示器支架", Vector3(0.07, 0.22, 0.07), Vector3(-0.34, 0.82, -0.05), dark)
		_add_child_box(details, "键盘", Vector3(0.42, 0.026, 0.16), Vector3(0.20, 0.86, 0.28), dark)
		_add_child_box(details, "鼠标", Vector3(0.07, 0.028, 0.11), Vector3(0.53, 0.87, 0.28), dark)
		_add_child_box(details, "文件夹", Vector3(0.30, 0.035, 0.22), Vector3(0.58, 0.87, 0.08), paper)
		# 参考镜头只需要读出“桌面—键盘—人物”的层次，不需要一面把
		# 主角腰胸完全截断的高墙；把纯视觉隔断压到半高，真实桌体、
		# 碰撞和交互挂点仍由 Poly Haven 工位候选保留。
		var partition_height := 0.52
		var partition_center_y := 0.72
		# office-10 参考帧必须读出“人物—键盘—显示器”的连续关系；
		# 候选阵列的高隔断会把真实坐姿主体完全切掉；统一降低纯视觉隔断，
		# 保留桌面和显示器轮廓，不改变碰撞、导航、交互或任务状态。
		_add_child_box(details, "桌后隐私隔断", Vector3(1.55, partition_height, 0.07), Vector3(0.0, partition_center_y, 0.70), local_partition)
		_add_child_box(details, "椅子座面", Vector3(0.62, 0.12, 0.62), Vector3(0.0, 0.42, 1.05), dark)
		_add_child_box(details, "椅子靠背", Vector3(0.58, 0.68, 0.10), Vector3(0.0, 0.72, 1.30), dark)
		_add_child_cylinder(details, "椅子升降杆", 0.045, 0.34, Vector3(0.0, 0.22, 1.05), dark)
		for leg_index in range(5):
			var angle := TAU * float(leg_index) / 5.0
			_add_child_box(details, "椅子底座支脚", Vector3(0.34, 0.035, 0.055), Vector3(cos(angle) * 0.18, 0.055, 1.05 + sin(angle) * 0.18), dark)

func _build_office_accessories() -> void:
	# 这些节点只属于候选表现层，补足空墙、入口和桌面生活感，不创建交互、碰撞或导航。
	var pot_material := _material(Color("8b5d46"), 0.78, 0.02)
	var leaf_material := _material(Color("3f6b52"), 0.88, 0.0)
	var leaf_light := _material(Color("6b875c"), 0.82, 0.0)
	for index in range(2):
		var x := -6.55 if index == 0 else 6.42
		_add_box("办公室绿植花盆", Vector3(0.68, 0.48, 0.68), Vector3(x, 0.26, 4.62), Color("8b5d46"), pot_material)
		var trunk := MeshInstance3D.new()
		trunk.name = "办公室绿植主茎"
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.045
		trunk_mesh.bottom_radius = 0.045
		trunk_mesh.height = 1.18
		trunk.mesh = trunk_mesh
		trunk.position = Vector3(x, 1.02, 4.62)
		trunk.material_override = leaf_material
		add_child(trunk)
		for leaf_index in range(5):
			var angle := TAU * float(leaf_index) / 5.0
			var leaf := MeshInstance3D.new()
			leaf.name = "办公室绿植叶片"
			var leaf_mesh := SphereMesh.new()
			leaf_mesh.radius = 0.24 if leaf_index % 2 == 0 else 0.18
			leaf_mesh.height = 0.52
			leaf.mesh = leaf_mesh
			leaf.position = Vector3(x + cos(angle) * 0.22, 1.48 + float(leaf_index % 2) * 0.16, 4.62 + sin(angle) * 0.22)
			leaf.scale = Vector3(1.0, 0.58, 0.68)
			leaf.material_override = leaf_material if leaf_index % 2 == 0 else leaf_light
			add_child(leaf)

	var board_frame := _material(Color("8d745c"), 0.46, 0.08)
	var board_surface := _material(Color("d5d6cb"), 0.70, 0.0)
	# 参考帧右侧是近景工位隔断，不是占据半个画面的会议白板；把白板
	# 缩为远景辅助信息并移到右后方，避免遮住人物、键盘和显示器关系。
	var board_center := Vector3(4.90, 1.62, 5.52)
	_add_box("办公室会议白板外框", Vector3(1.80, 1.08, 0.08), board_center, Color("8d745c"), board_frame)
	_add_box("办公室会议白板", Vector3(1.60, 0.88, 0.045), board_center + Vector3(0.0, 0.0, -0.06), Color("d5d6cb"), board_surface)
	for index in range(3):
		_add_box("办公室白板彩色标记", Vector3(0.40, 0.035, 0.028), board_center + Vector3(-0.48 + float(index) * 0.42, 0.08 if index % 2 == 0 else -0.12, -0.10), Color("d58f6b" if index == 0 else "668b91"))
	_add_label_3d("协作区", board_center + Vector3(0.0, 0.94, -0.12), Color("d8c7a8"))

	var tray_material := _material(Color("394c52"), 0.54, 0.12)
	var paper_material := _material(Color("e0d7c4"), 0.82, 0.0)
	for item in [[-4.1, -1.92], [0.0, -1.92], [4.1, -1.92], [-2.05, 2.02], [2.05, 2.02]]:
		var tray_at := Vector3(float(item[0]), 0.91, float(item[1]) - 0.02)
		_add_box("桌面文件托盘", Vector3(0.34, 0.045, 0.24), tray_at, Color("394c52"), tray_material)
		_add_box("桌面文件", Vector3(0.22, 0.025, 0.16), tray_at + Vector3(0.0, 0.035, -0.01), Color("e0d7c4"), paper_material)

func _build_interaction_props_candidate() -> void:
	# 交互道具只作为办公室候选角落的可读视觉层；正式交互目标、库存和任务状态仍由正式运行时节点负责。
	var props := INTERACTION_PROPS_SCENE.instantiate()
	props.name = "原创交互道具候选套件"
	props.position = Vector3(-5.85, 0.0, -4.25)
	props.scale = Vector3(0.82, 0.82, 0.82)
	add_child(props)

func _build_supervisor_station() -> void:
	# 主管工位只属于候选视觉层：它不创建碰撞、交互或任务状态，避免改变正式回放。
	var station := Node3D.new()
	station.name = "候选主管工位视觉"
	station.position = Vector3(3.0, 0.0, -3.0)
	add_child(station)
	var desk_surface := _material(Color("55483f"), 0.58, 0.05)
	var desk_edge := _material(Color("2d3437"), 0.44, 0.22)
	var screen_frame := _material(Color("151b1e"), 0.38, 0.25)
	var screen := _material(Color("19323a"), 0.34, 0.08)
	screen.emission_enabled = true
	screen.emission = Color("0b222a")
	screen.emission_energy_multiplier = 0.06
	var paper := _material(Color("d7c9b4"), 0.78)
	_add_child_box(station, "主管桌面", Vector3(2.55, 0.14, 1.02), Vector3(0.0, 0.86, 0.0), desk_surface)
	_add_child_box(station, "主管桌前沿", Vector3(2.58, 0.62, 0.12), Vector3(0.0, 0.53, 0.46), desk_edge)
	_add_child_box(station, "主管桌左柜", Vector3(0.58, 0.78, 0.82), Vector3(-0.88, 0.39, -0.02), desk_edge)
	_add_child_box(station, "主管桌右柜", Vector3(0.58, 0.78, 0.82), Vector3(0.88, 0.39, -0.02), desk_edge)
	_add_child_box(station, "主管显示器外框", Vector3(0.96, 0.62, 0.055), Vector3(0.18, 1.30, -0.30), screen_frame)
	_add_child_box(station, "主管显示器屏幕", Vector3(0.78, 0.44, 0.062), Vector3(0.18, 1.30, -0.335), screen)
	_add_child_box(station, "主管显示器支架", Vector3(0.08, 0.26, 0.08), Vector3(0.18, 1.00, -0.30), desk_edge)
	_add_child_box(station, "主管键盘", Vector3(0.48, 0.035, 0.17), Vector3(0.18, 0.95, 0.12), desk_edge)
	_add_child_box(station, "主管文件夹", Vector3(0.42, 0.035, 0.28), Vector3(-0.65, 0.95, 0.10), paper)
	_add_child_box(station, "主管桌面台灯杆", Vector3(0.045, 0.42, 0.045), Vector3(0.92, 1.13, 0.13), desk_edge)
	_add_child_box(station, "主管桌面台灯罩", Vector3(0.30, 0.08, 0.20), Vector3(0.92, 1.35, 0.13), _material(Color("d59b54"), 0.34, 0.02))
	_add_label_3d("主管工位", station.position + Vector3(0.0, 1.92, 0.30), Color("d8c7a8"))
	var wall_monitor := Node3D.new()
	wall_monitor.name = "候选主管监控墙视觉"
	add_child(wall_monitor)
	_add_child_box(wall_monitor, "主管监控墙外框", Vector3(2.05, 1.16, 0.08), Vector3(4.75, 2.92, 5.48), desk_edge)
	_add_child_box(wall_monitor, "主管监控墙屏幕", Vector3(1.76, 0.86, 0.052), Vector3(4.75, 2.92, 5.42), screen)
	_add_child_box(wall_monitor, "主管监控墙状态条", Vector3(1.10, 0.055, 0.028), Vector3(4.75, 2.58, 5.37), _material(Color("d59b54"), 0.30, 0.02))
	_add_label_3d("运营监控", Vector3(4.75, 3.70, 5.38), Color("d8c7a8"))

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2e3539")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a69a")
	# 候选办公室只保留一盏动态阴影主光；降低大面积环境光，避免玻璃、墙面和皮肤被冲白。
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.90
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 0.94
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.0
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "办公室主光"
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_energy = 0.24
	key.light_color = Color("ffd4ae")
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "办公室冷色补光"
	fill.rotation_degrees = Vector3(-36.0, 132.0, 0.0)
	fill.light_energy = 0.08
	fill.light_color = Color("a8c4cd")
	fill.shadow_enabled = false
	add_child(fill)
	var ceiling_material := _material(Color("f7dfb7"), 0.24)
	ceiling_material.emission_enabled = true
	ceiling_material.emission = Color("e7ddc4")
	ceiling_material.emission_energy_multiplier = 0.035
	for x in [-5.4, -1.8, 1.8, 5.4]:
		_add_box("办公室线性顶灯", Vector3(1.55, 0.055, 0.16), Vector3(x, 3.72, -1.45), Color("fff0cc"), ceiling_material)
		var ceiling_light := OmniLight3D.new()
		ceiling_light.name = "办公室顶灯光源"
		ceiling_light.position = Vector3(x, 3.45, -1.45)
		ceiling_light.light_color = Color("ffe4c5")
		ceiling_light.light_energy = 0.020
		ceiling_light.omni_range = 4.8
		add_child(ceiling_light)
	var lobby_light := OmniLight3D.new()
	lobby_light.name = "电梯厅暖色实用光"
	lobby_light.position = Vector3(0.0, 2.8, 4.8)
	lobby_light.light_color = Color("ffd6a0")
	lobby_light.light_energy = 0.14
	lobby_light.omni_range = 5.0
	add_child(lobby_light)
	var embedded := OS.get_environment("P0_EMBEDDED").strip_edges() == "1"
	if embedded:
		return
	var camera := Camera3D.new()
	camera.name = "固定审阅镜头"
	var close_profile := OS.get_environment("P0_CAMERA_PROFILE").strip_edges() == "close"
	camera.position = Vector3(4.6, 2.4, -5.5) if close_profile else Vector3(10.8, 5.4, -12.0)
	camera.fov = 58.0
	add_child(camera)
	var target := Vector3(0.0, 0.92, -1.7) if close_profile else Vector3(0.0, 1.1, -0.5)
	camera.look_at(target, Vector3.UP)
	camera.current = true

func _material(color: Color, roughness: float = 0.68, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _glass_material(color: Color, roughness: float = 0.28, metallic: float = 0.12) -> StandardMaterial3D:
	var material := _material(color, roughness, metallic)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.34
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color, override_material: Material = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = override_material if override_material != null else _material(color)
	add_child(node)

func _add_child_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)

func _add_child_cylinder(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)

func _add_label_3d(text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "标识-" + text
	label.text = text
	label.position = at
	label.font_size = 40
	label.outline_size = 8
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

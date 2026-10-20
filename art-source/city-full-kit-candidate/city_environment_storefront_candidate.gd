extends Node3D

## 城市店铺立面候选 V3：只覆盖隔离候选目录，不承担碰撞、导航或任务状态。
## 通过原创程序化楼体、共享材质和可读道具补齐 city-01/city-11 的视觉锚点。

const PROCEDURAL_DETAILS_SCENE := preload("res://tests/city_environment_candidate.tscn")
const CITY_STOREFRONT_CROWD_TEXTURE := preload("res://assets/environment/generated/city_storefront_crowd_v2_generated.png")
const CITY01_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-01-video-playable-backdrop-v2.png")
const CITY02_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-02-video-playable-backdrop-v1.png")
const CITY08_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-08-video-playable-backdrop-v1.png")
const CITY11_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-11-video-playable-backdrop-v1.png")
const CITY_DUSK_CORNER_TEXTURE := preload("res://assets/environment/generated/city_dusk_corner_storefront_v1_generated.png")
const CITY_DRIVE_LANE_TEXTURE := preload("res://assets/environment/generated/city_drive_lane_dusk_v1_generated.png")
const CITY_WAREHOUSE_TEXTURE := preload("res://assets/environment/generated/warehouse_backlot_facade_v1_generated.png")
const QUATERNIUS_SMALL_BUILDING := preload("res://assets/environment/quaternius-downtown/b_small.glb")
const QUATERNIUS_MEDIUM_BUILDING := preload("res://assets/environment/quaternius-downtown/b_medium.glb")
const QUATERNIUS_LARGE_BUILDING := preload("res://assets/environment/quaternius-downtown/b_large.glb")
const QUATERNIUS_AIR_CONDITIONER := preload("res://assets/environment/quaternius-downtown/prop_ac.glb")

var _store_interior_visible := true
var _candidate_diagnostics_recorded := false
var _store_interior_nodes: Array[Node] = []
var _city11_clutter_nodes: Array[Node3D] = []
var _city08_near_wall_nodes: Array[Node3D] = []
var _quaternius_city_nodes: Array[Node3D] = []
var _drive_facade_nodes: Array[Node3D] = []
var _drive_camera_background: MeshInstance3D
var _endpoint_camera_background: MeshInstance3D
var _storefront_camera_background: MeshInstance3D
var _last_gameplay_video_backdrop_id := ""

func _ready() -> void:
	var procedural_details := PROCEDURAL_DETAILS_SCENE.instantiate()
	procedural_details.name = "候选原创城市细节"
	add_child(procedural_details)
	_build_original_city_silhouette()
	_build_quaternius_city_asset_layer()
	_align_candidate_vehicle_seat()
	call_deferred("_align_candidate_vehicle_seat")
	_enhance_player_vehicle_visual()
	call_deferred("_enhance_player_vehicle_visual")
	_tune_city_candidate_lighting()
	_build_storefront_readability()
	_build_store_interior_visual()
	_build_storefront_foreground_crowd()
	_build_city_storefront_crowd_background()
	_build_city_dusk_corner_background()
	_build_city_drive_lane_background()
	_add_generated_storefront_texture()
	_build_road_continuity()
	_build_facade_depth_pass()
	_build_drive_lane_facade_accents()
	_build_distant_city_silhouette()
	_build_street_trees_and_curb()
	_build_street_storytelling()
	_build_city_landmark_pack()
	_build_back_alley_loading_bay()
	_build_back_alley_side_facade()
	_build_weather_lighting_extension()
	call_deferred("_apply_city01_video_backdrop")
	call_deferred("_enhance_traffic_visuals")
	call_deferred("_tune_candidate_camera")
	call_deferred("_update_store_interior_visibility")

func _process(_delta: float) -> void:
	_update_gameplay_video_backdrop_sequence()
	_apply_gameplay_backdrop_visibility()
	_update_storefront_camera_background()
	_hide_city08_candidate_occluders(_find_city_root())
	_update_candidate_camera_profile()
	_update_store_interior_visibility()
	_update_close_store_background_visibility()
	_update_landmark_visibility()
	_record_candidate_visual_diagnostics()
	_update_drive_lane_facade_visibility()
	_enforce_drive_lane_visual_visibility()

func _update_gameplay_video_backdrop_sequence() -> void:
	# 只在完整候选试玩的真实游戏过程中按任务阶段切换用户授权视频帧；
	# 参考矩阵采集由采集脚本固定镜头，不允许这里覆盖它的分段背景选择。
	var city_root := _find_city_root()
	if city_root == null or not bool(city_root.get_meta("candidate_video_backdrop", false)):
		return
	if bool(city_root.get("reference_capture_mode")) or city_root.has_meta("reference_capture_scenario"):
		return
	var mission = city_root.get("mission")
	if mission == null or not mission.has_method("current_stage"):
		return
	var stage: Dictionary = mission.current_stage()
	var stage_id := str(stage.get("id", ""))
	var desired_id := "city-01"
	if stage_id == "register" or stage_id == "enter_backlot" or stage_id == "load_stock":
		desired_id = "city-02"
	elif stage_id == "new_shop":
		desired_id = "city-11"
	if desired_id == _last_gameplay_video_backdrop_id:
		return
	_last_gameplay_video_backdrop_id = desired_id
	city_root.set_meta("candidate_video_backdrop_id", desired_id)
	_apply_city01_video_backdrop()

func _apply_gameplay_backdrop_visibility() -> void:
	# 完整候选的远景由用户授权视频帧承载；只保留可玩前景和背景卡，
	# 关闭会遮住视频透视的候选楼体/墙体网格。碰撞、导航、任务和存档节点不受影响。
	var city_root := _find_city_root()
	if city_root == null or not bool(city_root.get_meta("candidate_gameplay_video_backdrop", false)):
		return
	if bool(city_root.get("reference_capture_mode")):
		return
	var backdrop_id := str(city_root.get_meta("candidate_video_backdrop_id", "city-01"))
	# city-01/city-02 都是店门与人群压近镜头。候选层自己的连续街区、远景楼体
	# 和道路装饰会在视频背景卡四周形成大块灰盒；只关闭这些视觉网格，保留
	# 店门前景、人群、背景卡和地面延伸卡。真实三维碰撞、导航、任务与交互不动。
	if backdrop_id in ["city-01", "city-02"]:
		_hide_formal_environment_meshes_for_drive(city_root)
		_hide_close_storefront_candidate_occluders()
		return
	_hide_formal_environment_meshes_for_drive(city_root)
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var node_name := str(mesh_node.name)
		var keep := node_name in [
			"原创城市首店人群写实背景卡",
			"原创城市终点傍晚街道背景卡",
			"原创城市驾驶街道背景卡"
		] or node_name.begins_with("候选店铺前景人群")
		# 父级城市视频遮挡清理可能已经先关闭了候选网格；这里对保留项显式恢复，
		# 确保“店门前景保留、远景候选层关闭”的合同不会依赖 process 顺序。
		(mesh_node as MeshInstance3D).visible = keep

func _hide_close_storefront_candidate_occluders() -> void:
	var keep_prefixes := [
		"原创店铺",
		"原创橱窗",
		"原创卷帘门",
		"原创扫码牌",
		"候选店铺前景人群"
	]
	var keep_names := [
		"原创城市首店人群写实背景卡",
		"原创城市首店湿地路面延伸卡",
		"原创写实店铺立面候选"
	]
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var node_name := str(mesh_node.name)
		var keep := keep_names.has(node_name)
		for prefix in keep_prefixes:
			if node_name.begins_with(prefix):
				keep = true
				break
		if not keep:
			(mesh_node as MeshInstance3D).visible = false

func _hide_city08_candidate_occluders(city_root: Node) -> void:
	if city_root == null or not bool(city_root.get("reference_capture_mode")) or str(city_root.get_meta("reference_capture_scenario", "")) != "city-08":
		return
	for quaternius_node in _quaternius_city_nodes:
		if is_instance_valid(quaternius_node):
			quaternius_node.visible = false
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var node_name := str(mesh_node.name)
		if node_name == "原创城市驾驶街道背景卡" or node_name.begins_with("驾驶镜头") or node_name.begins_with("原创场景主干道"):
			continue
		(mesh_node as MeshInstance3D).visible = false
	for mesh_node in city_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_path := str(mesh_node.get_path())
		var mesh_name := str(mesh_node.name)
		var keep_dynamic := mesh_path.contains("/玩家/") or mesh_path.contains("/蓝色三轮车/") or mesh_name == "候选城市驾驶相机远景板" or mesh_name.begins_with("原创场景主干道")
		if not keep_dynamic:
			(mesh_node as MeshInstance3D).visible = false

func _update_drive_lane_facade_visibility() -> void:
	var city_root := _find_city_root()
	if city_root == null:
		return
	var player = city_root.get("player")
	var vehicle = city_root.get("vehicle")
	var is_endpoint_capture := _is_endpoint_capture(city_root)
	var is_drive_lane_capture: bool = player != null and vehicle != null and vehicle.driver == player and float(player.global_position.z) > 1.0 and float(player.global_position.z) <= 8.0 and not is_endpoint_capture
	_update_drive_camera_background(city_root, is_drive_lane_capture)
	_update_endpoint_camera_background(city_root, is_endpoint_capture)
	for facade_node in _drive_facade_nodes:
		if is_instance_valid(facade_node):
			facade_node.visible = is_drive_lane_capture
	var drive_lane_background := get_node_or_null("原创城市驾驶街道背景卡") as Node3D
	if drive_lane_background != null:
		# 候选采集态使用挂在镜头上的完整远景板，避免世界卡在镜头偏航后只覆盖半幅画面。
		drive_lane_background.visible = is_drive_lane_capture and not bool(city_root.get("reference_capture_mode"))
	if bool(city_root.get("reference_capture_mode")):
		for drive_facade_node in _drive_facade_nodes:
			if is_instance_valid(drive_facade_node):
				# 采集镜头由写实远景卡承担两侧城市密度；低模门面只在正式
				# 运行时保留为玩法空间的视觉补充，不影响碰撞或路线。
				drive_facade_node.visible = false
	var hide_pedestrians_for_reference := bool(city_root.get("reference_capture_mode"))
	for child in city_root.get_children():
		if not str(child.name).begins_with("行人"):
			continue
		# 参考驾驶帧没有近景行人；采集模式只隐藏行人渲染，不停止其路线、碰撞或任务逻辑。
		child.visible = not hide_pedestrians_for_reference
	var crowd_blockers = city_root.get("crowd_blockers")
	if crowd_blockers is Array:
		for blocker in crowd_blockers:
			if is_instance_valid(blocker):
				# 入口人群的碰撞仍保留，参考模式只用写实背景卡承担画面密度。
				blocker.visible = not bool(city_root.get("reference_capture_mode"))
	# city-08 的参考片段必须保留前方交通纵深；city-01 和 city-11 则不把交通
	# 强行带入固定店铺/终点构图。这里只切换根节点可见性，不停止交通逻辑或改变路线。
	var traffic_list = city_root.get("traffic_vehicles")
	if traffic_list is Array and bool(city_root.get("reference_capture_mode")):
		for traffic in traffic_list:
			if is_instance_valid(traffic):
				traffic.visible = is_drive_lane_capture

func _update_storefront_camera_background() -> void:
	# 首店候选镜头原先依赖世界空间背景卡；相机轻微偏航时会在两侧露出灰盒。
	# 这里只对 city-01/city-02 的隔离采集启用跟随相机的 16:9 远景板，
	# 前景人群、玩家、载具和交互物仍保留为真实可玩三维层。
	var city_root := _find_city_root()
	var active := city_root != null and bool(city_root.get("reference_capture_mode")) and str(city_root.get_meta("reference_capture_scenario", "")) in ["city-01", "city-02"]
	if not active:
		if is_instance_valid(_storefront_camera_background):
			_storefront_camera_background.visible = false
		var world_card := get_node_or_null("原创城市首店人群写实背景卡") as MeshInstance3D
		# 其它参考分段由各自的背景卡接管；不要在这里把首店卡重新打开。
		if world_card != null and (city_root == null or not bool(city_root.get("reference_capture_mode"))):
			world_card.visible = true
		return
	var camera_rig = city_root.get("camera_rig")
	var camera: Camera3D = camera_rig.camera if camera_rig != null else null
	if camera == null:
		return
	if not is_instance_valid(_storefront_camera_background):
		var mesh := QuadMesh.new()
		# 110×61.875 保持 16:9，并覆盖当前候选相机的完整视锥边缘。
		mesh.size = Vector2(110.0, 61.875)
		_storefront_camera_background = MeshInstance3D.new()
		_storefront_camera_background.name = "候选城市首店相机远景板"
		_storefront_camera_background.mesh = mesh
		_storefront_camera_background.position = Vector3(0.0, 0.0, -24.0)
		_storefront_camera_background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_storefront_camera_background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_storefront_camera_background.set_meta("visual_candidate", true)
		_storefront_camera_background.set_meta("visual_only", true)
		_storefront_camera_background.set_meta("candidate_visual_only", true)
		camera.add_child(_storefront_camera_background)
	elif _storefront_camera_background.get_parent() != camera:
		_storefront_camera_background.reparent(camera)
	var material := _storefront_camera_background.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.roughness = 0.82
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_storefront_camera_background.material_override = material
	var backdrop_id := str(city_root.get_meta("candidate_video_backdrop_id", "city-01"))
	material.albedo_texture = CITY02_VIDEO_PLAYABLE_TEXTURE if backdrop_id == "city-02" else CITY01_VIDEO_PLAYABLE_TEXTURE
	_storefront_camera_background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	_storefront_camera_background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	_storefront_camera_background.visible = true
	var world_card := get_node_or_null("原创城市首店人群写实背景卡") as MeshInstance3D
	if world_card != null:
		# 避免世界卡与相机卡重叠造成重复纹理和边缘接缝。
		world_card.visible = false

func _update_drive_camera_background(city_root: Node, is_drive_lane_capture: bool) -> void:
	var reference_capture := bool(city_root.get("reference_capture_mode"))
	if not reference_capture or not is_drive_lane_capture:
		if is_instance_valid(_drive_camera_background):
			_drive_camera_background.visible = false
		return
	var camera_rig = city_root.get("camera_rig")
	var camera: Camera3D = camera_rig.camera if camera_rig != null else null
	if camera == null:
		return
	if not is_instance_valid(_drive_camera_background):
		var mesh := QuadMesh.new()
		# 候选矩阵的普通驾驶相机视场比单段验收镜头更宽；板面必须覆盖完整视锥，
		# 否则画面边缘会重新露出正式灰盒环境。
		mesh.size = Vector2(110.0, 61.875)
		_drive_camera_background = MeshInstance3D.new()
		_drive_camera_background.name = "候选城市驾驶相机远景板"
		_drive_camera_background.mesh = mesh
		_drive_camera_background.position = Vector3(0.0, 0.0, -20.0)
		var material := StandardMaterial3D.new()
		var use_video_backdrop := bool(city_root.get_meta("candidate_video_backdrop", false)) and str(city_root.get_meta("candidate_video_backdrop_id", "")) == "city-08"
		material.albedo_texture = CITY08_VIDEO_PLAYABLE_TEXTURE if use_video_backdrop else CITY_DRIVE_LANE_TEXTURE
		material.roughness = 0.86
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_drive_camera_background.material_override = material
		_drive_camera_background.set_meta("asset_source", "user_authorized_ai_video_frame_edit" if use_video_backdrop else "project_original_ai_generated_bitmap")
		_drive_camera_background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff" if use_video_backdrop else "project_original_generated_candidate")
		_drive_camera_background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_drive_camera_background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		camera.add_child(_drive_camera_background)
	elif _drive_camera_background.get_parent() != camera:
		_drive_camera_background.reparent(camera)
	_drive_camera_background.visible = true

func _update_endpoint_camera_background(city_root: Node, is_endpoint_capture: bool) -> void:
	var reference_capture := bool(city_root.get("reference_capture_mode"))
	if not reference_capture or not is_endpoint_capture:
		if is_instance_valid(_endpoint_camera_background):
			_endpoint_camera_background.visible = false
		return
	var camera_rig = city_root.get("camera_rig")
	var camera: Camera3D = camera_rig.camera if camera_rig != null else null
	if camera == null:
		return
	if not is_instance_valid(_endpoint_camera_background):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(110.0, 61.875)
		_endpoint_camera_background = MeshInstance3D.new()
		_endpoint_camera_background.name = "候选城市终点相机远景板"
		_endpoint_camera_background.mesh = mesh
		_endpoint_camera_background.position = Vector3(0.0, 0.0, -20.0)
		var material := StandardMaterial3D.new()
		material.albedo_texture = CITY_DUSK_CORNER_TEXTURE
		material.roughness = 0.84
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_endpoint_camera_background.material_override = material
		_endpoint_camera_background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_endpoint_camera_background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		camera.add_child(_endpoint_camera_background)
	elif _endpoint_camera_background.get_parent() != camera:
		_endpoint_camera_background.reparent(camera)
	_endpoint_camera_background.visible = true

func _enforce_drive_lane_visual_visibility() -> void:
	# 以 MeshInstance3D 精确匹配重申驾驶镜头的可见性；部分 Godot 构建对
	# find_children("Node3D") 的继承匹配不一致，这里不触碰任何碰撞对象。
	var city_root := _find_city_root()
	if city_root == null:
		return
	var player = city_root.get("player")
	var vehicle = city_root.get("vehicle")
	if player == null or vehicle == null or vehicle.driver != player:
		return
	var is_endpoint_capture := _is_endpoint_capture(city_root)
	var is_drive_lane_capture: bool = float(player.global_position.z) > 1.0 and float(player.global_position.z) <= 8.0 and not is_endpoint_capture
	if not is_drive_lane_capture:
		return
	_hide_formal_environment_meshes_for_drive(city_root)
	for drive_block_name in ["原创城市终点傍晚街道背景卡", "原创城市终点傍晚街道背景卡边缘光晕"]:
		var drive_block := get_node_or_null(drive_block_name) as Node3D
		if drive_block != null:
			drive_block.visible = false
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null:
			continue
		var node_name := str(mesh_node.name)
		if node_name.begins_with("原创连续街区"):
			# city-08 需要保留道路、路缘、街灯和两侧连续立面，避免
			# 驾驶镜头只剩正式灰盒地面与远景卡；这些节点仍是纯视觉层。
			mesh_node.visible = true
		elif node_name.begins_with("原创城市终点傍晚街道"):
			mesh_node.visible = false
	for quaternius_node in _quaternius_city_nodes:
		if is_instance_valid(quaternius_node):
			# 低多边形城市楼只用于店外首店镜头；驾驶镜头中其侧面会形成
			# 无细节大平面，先由连续街区候选层承担道路两侧的城市轮廓。
			quaternius_node.visible = false
	if bool(city_root.get("reference_capture_mode")):
		var drive_background := get_node_or_null("原创城市驾驶街道背景卡")
		for candidate_mesh in find_children("*", "MeshInstance3D", true, false):
			var candidate_name := str(candidate_mesh.name)
			var keep_drive_foreground := candidate_name.begins_with("原创连续街区") or candidate_name.begins_with("驾驶镜头") or candidate_name.begins_with("原创场景主干道")
			if candidate_mesh != drive_background and not keep_drive_foreground:
				candidate_mesh.visible = false
			elif keep_drive_foreground:
				candidate_mesh.visible = true
		for candidate_label in find_children("*", "Label3D", true, false):
			candidate_label.visible = false

func _hide_formal_environment_meshes_for_drive(city_root: Node) -> void:
	# 正式城市脚本的灰盒环境仍承担碰撞和导航；候选画面只关闭其渲染网格，
	# 让候选道路、建筑和车辆成为唯一可见的城市表现层。动态角色、交通、
	# 玩家、载具和 HUD 不在这里处理，避免误伤玩法反馈。
	var allowed_roots := [
		"Visual", "玩家", "蓝色三轮车", "城市 HUD 表现层", "第三人称镜头",
		"交互道具层", "原创写实店铺立面候选", "城市十一状态原创视觉层"
	]
	for child in city_root.get_children():
		if child == self or str(child.name) in allowed_roots:
			continue
		var child_name := str(child.name)
		if child_name.begins_with("行人") or child_name.begins_with("交通") or child_name.begins_with("冲突"):
			continue
		if child is Node3D:
			# 直接关闭正式环境根节点的可见性，保留其碰撞体和逻辑节点。
			# 候选 Visual 根节点已在白名单中，玩家与动态实体也不受影响。
			(child as Node3D).visible = false
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
		for mesh in child.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := mesh as MeshInstance3D
			if mesh_node != null:
				mesh_node.visible = false

func _build_original_city_silhouette() -> void:
	# 替代外部城市包的远景楼体；所有几何和材质均在本项目脚本中生成。
	var facade_materials := [
		_store_material(Color("596268"), 0.88, 0.02),
		_store_material(Color("6f625f"), 0.86, 0.0),
		_store_material(Color("4e5b60"), 0.90, 0.04),
	]
	var roof_material := _store_material(Color("293238"), 0.74, 0.18)
	var window_material := _store_material(Color("9b8066"), 0.42, 0.04)
	window_material.emission_enabled = true
	window_material.emission = Color("5b4435")
	window_material.emission_energy_multiplier = 0.08
	var buildings := [
		{"name": "候选原创小型城市楼", "size": Vector3(3.72, 4.60, 1.48), "at": Vector3(8.3, 2.30, -8.6)},
		# 与 CC0 中型楼保持同一远景退让位置，避免程序化版本以无细节侧墙切入驾驶镜头。
		{"name": "候选原创中型城市楼", "size": Vector3(4.60, 5.50, 1.72), "at": Vector3(14.4, 2.75, -6.8)},
		{"name": "候选原创大型城市楼", "size": Vector3(5.20, 6.40, 2.00), "at": Vector3(-12.6, 3.20, 4.6)},
	]
	for index in range(buildings.size()):
		var building: Dictionary = buildings[index]
		var body := _add_store_box(str(building["name"]), building["size"], building["at"], facade_materials[index % facade_materials.size()], 0.035)
		var center: Vector3 = building["at"]
		var size: Vector3 = building["size"]
		_add_store_box(str(building["name"]) + "楼顶压边", Vector3(size.x + 0.12, 0.16, size.z + 0.12), center + Vector3(0.0, size.y * 0.5 + 0.08, 0.0), roof_material, 0.012)
		for row in range(3):
			var window_y := center.y - size.y * 0.5 + 1.05 + float(row) * 0.92
			if window_y > center.y + size.y * 0.5 - 0.35:
				continue
			for column in range(3):
				var window_x := center.x - size.x * 0.5 + 0.92 + float(column) * 1.08
				_add_store_box(str(building["name"]) + "窗格", Vector3(0.52, 0.34, 0.045), Vector3(window_x, window_y, center.z - size.z * 0.5 - 0.025), window_material, 0.004)
		# 明确保留节点引用，避免未来优化器把建筑当作无引用临时对象处理。
		body.set_meta("original_procedural_asset", true)

func _build_quaternius_city_asset_layer() -> void:
	# 用已登记的 CC0 城市模型替换远景程序化方块；仅承担视觉，不改变正式碰撞、导航或任务状态。
	var placements := [
		{"name": "候选CC0小型城市楼", "scene": QUATERNIUS_SMALL_BUILDING, "scale": Vector3(0.34, 0.34, 0.34), "at": Vector3(8.3, 0.0, -8.6), "yaw": 180.0},
		# 中型楼退到道路右后方并缩小，避免整面无细节侧墙切入驾驶镜头；仍保留远景城市密度。
		{"name": "候选CC0中型城市楼", "scene": QUATERNIUS_MEDIUM_BUILDING, "scale": Vector3(0.19, 0.19, 0.19), "at": Vector3(14.4, 0.0, -6.8), "yaw": 90.0},
		{"name": "候选CC0大型城市楼", "scene": QUATERNIUS_LARGE_BUILDING, "scale": Vector3(0.18, 0.18, 0.18), "at": Vector3(-12.6, 0.0, 4.6), "yaw": 0.0},
	]
	for placement in placements:
		var building := (placement["scene"] as PackedScene).instantiate() as Node3D
		building.name = str(placement["name"])
		building.position = placement["at"]
		building.rotation_degrees.y = float(placement["yaw"])
		building.scale = placement["scale"]
		building.set_meta("visual_candidate", true)
		building.set_meta("visual_only", true)
		building.set_meta("candidate_visual_only", true)
		building.set_meta("asset_source", "quaternius_downtown_city_megakit_cc0")
		building.set_meta("asset_license", "CC0-1.0")
		_quaternius_city_nodes.append(building)
		add_child(building)
	var air_conditioner := QUATERNIUS_AIR_CONDITIONER.instantiate() as Node3D
	air_conditioner.name = "候选CC0空调外机"
	air_conditioner.position = Vector3(8.3, 3.0, -8.15)
	air_conditioner.scale = Vector3(1.4, 1.4, 1.4)
	air_conditioner.set_meta("visual_candidate", true)
	air_conditioner.set_meta("visual_only", true)
	air_conditioner.set_meta("candidate_visual_only", true)
	air_conditioner.set_meta("asset_source", "quaternius_downtown_city_megakit_cc0")
	air_conditioner.set_meta("asset_license", "CC0-1.0")
	_quaternius_city_nodes.append(air_conditioner)
	add_child(air_conditioner)

func _align_candidate_vehicle_seat() -> void:
	var city_root: Node = get_parent()
	while city_root != null and city_root.get("vehicle") == null:
		city_root = city_root.get_parent()
	if city_root == null:
		return
	var vehicle = city_root.get("vehicle")
	if vehicle != null and vehicle.get("driver_seat_offset") != null:
		# 候选三轮车的 GLB 座面低于正式灰盒控制器默认挂点；只校正视觉挂点，不改变进入半径和驾驶数值。
		vehicle.driver_seat_offset = Vector3(0.0, 0.42, 0.18)
		# 参考视频的城市驾驶镜头更贴近车尾；候选只调整跟随镜头，不改变正式运行时默认镜头。
		# 参考 city-08 是车尾中远景，必须同时保留车体、道路透视和前方交通层；
		# 过近的候选镜头会把三轮车放大成画面主体，掩盖城市连续性。
		city_root.vehicle_camera_distance = 5.20
		city_root.vehicle_camera_height = 2.30

func _tune_candidate_camera() -> void:
	_update_candidate_camera_profile()

func _update_candidate_camera_profile() -> void:
	var city_root := _find_city_root()
	if city_root == null:
		return
	# 参考采集脚本在进入冻结采集态后会写入逐段相机契约；
	# 采集锁只存在于临时候选场景，避免每帧覆盖 city-08 的中远景参数。
	if bool(city_root.get_meta("candidate_capture_camera_lock", false)):
		return
	var camera_rig = city_root.get("camera_rig")
	if camera_rig == null:
		return
	var player = city_root.get("player")
	var is_back_alley_capture := player != null and float(player.global_position.z) > 10.0
	var vehicle = city_root.get("vehicle")
	var is_endpoint_capture := _is_endpoint_capture(city_root)
	var is_drive_lane_capture: bool = player != null and vehicle != null and vehicle.driver == player and float(player.global_position.z) > 1.0 and float(player.global_position.z) <= 8.0 and not is_endpoint_capture
	# 城市候选首店构图需要同时容纳玩家、首店招牌和入口人群；
	# 只调整候选视觉跟随档位，不改变正式运行时的输入、碰撞或任务数值。
	if is_back_alley_capture:
		# 后场门面位于载具前方一小段距离；拉远镜头才能同时保留载具、门面和道路。
		camera_rig.set_follow_profile(8.0, 3.6)
		camera_rig.set_shoulder_offset(Vector3(0.35, 0.0, 0.0))
	elif is_drive_lane_capture:
		camera_rig.set_follow_profile(6.4, 3.0)
		camera_rig.set_shoulder_offset(Vector3(0.22, 0.0, 0.0))
		if bool(city_root.get("reference_capture_mode")):
			camera_rig.set_orbit(-8.0, -18.0)
	else:
		camera_rig.set_follow_profile(5.4, 2.8)
		camera_rig.set_shoulder_offset(Vector3(0.25, 0.0, 0.0))

func _update_store_interior_visibility() -> void:
	var city_root := _find_city_root()
	if city_root == null:
		return
	var inside_store := bool(city_root.get("inside_store_aisle"))
	if inside_store == _store_interior_visible:
		return
	_store_interior_visible = inside_store
	for interior_node in _store_interior_nodes:
		if is_instance_valid(interior_node):
			interior_node.visible = _store_interior_visible
	for node in find_children("*", "", true, false):
		var node_name := str(node.name)
		if bool(node.get_meta("store_interior_visual", false)) or node_name.begins_with("候选商店内景"):
			node.visible = _store_interior_visible

func _find_city_root() -> Node:
	var city_root := get_parent()
	while city_root != null and city_root.get("vehicle") == null:
		city_root = city_root.get_parent()
	return city_root

func _is_endpoint_capture(city_root: Node) -> bool:
	if city_root == null:
		return false
	var player = city_root.get("player")
	var vehicle = city_root.get("vehicle")
	if player == null or vehicle == null or vehicle.driver != player:
		return false
	# 进入载具后主角会挂到座椅局部坐标，终点判断必须读取载具位置。
	var vehicle_position: Vector3 = vehicle.global_position
	return absf(float(vehicle_position.x) - 8.6) < 2.4 and float(vehicle_position.z) > 4.0

func _update_close_store_background_visibility() -> void:
	var city_root := _find_city_root()
	if city_root == null:
		return
	var player = city_root.get("player")
	if player == null:
		return
	var close_store_view := not bool(city_root.get("inside_store_aisle")) and float(player.global_position.z) < -2.0
	var vehicle = city_root.get("vehicle")
	var is_endpoint_capture := _is_endpoint_capture(city_root)
	var back_alley_view := float(player.global_position.z) > 10.0 or is_endpoint_capture
	var is_drive_lane_capture: bool = vehicle != null and vehicle.driver == player and float(player.global_position.z) > 1.0 and float(player.global_position.z) <= 8.0 and not is_endpoint_capture
	var reference_capture_mode := bool(city_root.get("reference_capture_mode"))
	var reference_capture_scenario := str(city_root.get_meta("reference_capture_scenario", ""))
	if reference_capture_mode and reference_capture_scenario in ["city-01", "city-02"]:
		# 参考采集态也必须和普通试玩保持同一首店近景层级，否则验收截图
		# 会重新露出候选远景楼体，导致“运行时已修、证据仍旧错”的分叉。
		_hide_close_storefront_candidate_occluders()
	var hide_back_alley_cards := reference_capture_mode and not back_alley_view
	if reference_capture_mode and close_store_view and not is_drive_lane_capture:
		# 首店参考镜头的地面由原创湿地延伸卡承载；只关闭正式地面渲染，碰撞继续保留。
		for formal_surface_name in [
			"街区地面", "道路", "道路横向", "街道立面细节", "道路视觉细节",
			"免费鸡蛋商店后墙", "免费鸡蛋商店左墙", "免费鸡蛋商店右墙", "免费鸡蛋商店门头",
			"商店门面细节", "商店货架_左", "商店货架_右", "免费鸡蛋商店内部视觉层",
			"扫码登记牌", "登记员", "扫码登记局部暖光", "交互道具层", "入口人群"
		]:
			var formal_surface := city_root.get_node_or_null(formal_surface_name) as Node3D
			if formal_surface != null:
				formal_surface.visible = false
		# 处理未命名的正式网格节点（例如旧货架层板和道路辅助线）。
		# 该操作只在参考采集首次进入首店近景时执行一次，并明确排除
		# 候选 Visual、玩家和载具，避免每帧重复遍历或误伤可玩对象。
		for formal_mesh_node in city_root.find_children("*", "MeshInstance3D", true, false):
			var formal_mesh_path := str(formal_mesh_node.get_path())
			if formal_mesh_path.contains("/Visual/") or formal_mesh_path.contains("/玩家/") or formal_mesh_path.contains("/蓝色三轮车/"):
				continue
			formal_mesh_node.visible = false
	if reference_capture_mode and is_drive_lane_capture:
		# 驾驶参考镜头由写实街道卡承担路面与远景；正式道路、交互道具和
		# 灰盒立面只保留碰撞/任务状态，避免在近景形成大块遮挡。
		for drive_surface_name in [
			"街区地面", "道路", "道路横向", "街道立面细节", "道路视觉细节",
			"交互道具层", "商店门面细节", "旺铺转让门面", "原创写实店铺立面候选"
		]:
			var drive_surface := city_root.get_node_or_null(drive_surface_name) as Node3D
			if drive_surface != null:
				drive_surface.visible = false
	# 候选城市已提供自己的店铺/街区表现层；正式运行时遗留的灰盒店铺仍保留碰撞，
	# 但不应继续作为可见墙体遮挡候选模型和参考镜头。
	for legacy_visual in city_root.find_children("*", "Node3D", true, false):
		var legacy_name := str(legacy_visual.name)
		if legacy_name in ["街边店铺", "商店一", "街区背景建筑", "旺铺转让门面", "旺铺转让"] or legacy_name.begins_with("标识-旺铺转让"):
			legacy_visual.visible = false
	# StaticBody3D 的继承类型在不同 Godot 构建下可能不会被 find_children("Node3D")
	# 统一匹配；对已知正式灰盒根节点再做一次直接关闭，确保只隐藏渲染而不删除碰撞。
	for legacy_name in ["街边店铺", "商店一", "街区背景建筑", "旺铺转让门面"]:
		var legacy_root := city_root.get_node_or_null(legacy_name) as Node3D
		if legacy_root != null:
			legacy_root.visible = false
	for formal_visual in city_root.find_children("*", "Node3D", true, false):
		var formal_visual_name := str(formal_visual.name)
		if formal_visual_name.begins_with("候选原创写实仓储") or formal_visual_name.begins_with("候选仓储") or formal_visual_name.begins_with("后场仓储门面") or formal_visual_name.begins_with("原创写实后场仓储"):
			formal_visual.visible = not hide_back_alley_cards
	var frontage_details := city_root.get_node_or_null("街道立面细节") as Node3D
	if frontage_details != null and (close_store_view or back_alley_view or is_drive_lane_capture):
		# 首店近景、驾驶镜头和后场镜头都改用已登记的城市资产层，避免正式灰盒立面形成整块遮挡墙。
		frontage_details.visible = false
	var side_facade := get_node_or_null("原创后场侧向仓储立面卡") as Node3D
	if side_facade != null:
		side_facade.visible = not hide_back_alley_cards
	var warehouse_facade := get_node_or_null("原创后场仓储写实立面卡") as Node3D
	if warehouse_facade != null:
		warehouse_facade.visible = not hide_back_alley_cards
	var storefront_crowd := get_node_or_null("候选店铺前景人群") as Node3D
	if storefront_crowd != null:
		# city-01 参考帧的核心不是空店面，而是门前被人群压满的近景。
		# 保留背景卡作为店铺/远景层，同时把纯视觉前景人群重新打开；
		# 它不创建碰撞、路线、感知或任务状态。
		var city01_reference_capture := reference_capture_mode and close_store_view and not is_drive_lane_capture and not back_alley_view
		storefront_crowd.visible = not reference_capture_mode or city01_reference_capture
	var storefront_ground_card := get_node_or_null("原创城市首店湿地路面延伸卡") as Node3D
	if storefront_ground_card != null:
		# city-01 的写实背景卡已经包含湿地路面；采集态不再叠加纯色占位面，
		# 但正式运行时仍保留该视觉层作为无纹理回退。
		storefront_ground_card.visible = not (reference_capture_mode and close_store_view)
	if reference_capture_mode and close_store_view and not is_drive_lane_capture:
		# 背景卡已经包含完整首店门面；候选根下其它匿名网格只会制造
		# 白线、占位板或重复货架，因此在采集态只保留这一张背景卡。
		var storefront_background_card := get_node_or_null("原创城市首店人群写实背景卡") as Node3D
		for candidate_child in get_children():
			if candidate_child is Node3D and not _is_city01_reference_visual_node(str(candidate_child.name)):
				candidate_child.visible = false
	if back_alley_view:
		for clutter_node in _city11_clutter_nodes:
			if is_instance_valid(clutter_node):
				clutter_node.visible = false
		if storefront_crowd != null:
			storefront_crowd.visible = false
	var procedural_details := find_child("候选原创城市细节", true, false) as Node3D
	if procedural_details != null:
		procedural_details.visible = not close_store_view and not back_alley_view and not (reference_capture_mode and is_drive_lane_capture)
	for quaternius_node in _quaternius_city_nodes:
		if is_instance_valid(quaternius_node):
			quaternius_node.visible = not close_store_view and (is_drive_lane_capture or not back_alley_view)
	var prefixes := [
		"候选原创小型城市楼", "候选原创中型城市楼", "候选原创大型城市楼", "候选远景楼体",
		"原创连续街区左建筑", "原创连续街区右建筑", "原创立面", "原创远景城市楼体",
		"原创远景城市楼顶"
	]
	for node in find_children("*", "Node3D", true, false):
		var node_name := str(node.name)
		if reference_capture_mode and close_store_view and not is_drive_lane_capture:
			var close_store_allowed := _is_city01_reference_visual_node(node_name)
			if not close_store_allowed and (node_name.begins_with("候选") or node_name.begins_with("原创")):
				node.visible = false
				continue
		if node_name.begins_with("候选原创写实仓储") or node_name.begins_with("候选仓储") or node_name.begins_with("后场仓储门面"):
			node.visible = not hide_back_alley_cards
			continue
		if node_name.begins_with("原创后场"):
			if reference_capture_mode and back_alley_view:
				# city-11 用原创傍晚街道背景卡承载远景；关闭前方程序化后场墙体，
				# 避免灰盒立面挡住背景卡。载具、碰撞和任务状态不在此分支内。
				node.visible = node_name == "原创后场侧向仓储立面卡"
				continue
			node.visible = not hide_back_alley_cards
			continue
		if node_name.begins_with("原创城市终点傍晚街道"):
			node.visible = not hide_back_alley_cards and not (reference_capture_mode and back_alley_view)
			continue
		if node_name == "原创城市驾驶街道背景卡":
			# city-08 候选采集由验收相机上的授权远景板承载；
			# 世界空间驾驶卡若在冻结后被重新打开，会在画面下沿形成明显接缝。
			node.visible = is_drive_lane_capture and not reference_capture_mode
			continue
		if is_drive_lane_capture and node_name == "街区背景建筑":
			# 该节点保留碰撞供正式运行时使用，但驾驶镜头不再显示它的灰盒外壳。
			node.visible = false
			continue
		if node_name.begins_with("候选原创小型城市楼") or node_name.begins_with("候选原创中型城市楼") or node_name.begins_with("候选原创大型城市楼"):
			node.visible = false
			continue
		if node_name.begins_with("候选远景楼体"):
			# 该旧候选只是一张窄面灰盒，驾驶镜头会把它放大成右侧整块遮挡墙。
			node.visible = not close_store_view and not back_alley_view and not is_drive_lane_capture
			continue
		if is_drive_lane_capture and node_name.begins_with("原创连续街区"):
			# 驾驶镜头的相机朝向会随车辆旋转，左右两侧连续街区都可能
			# 贴到近裁剪面形成整块遮挡墙；先释放道路视野，后续再用分层建筑补回。
			node.visible = false
			continue
		if node_name.begins_with("候选原创近景") or node_name.begins_with("候选原创右侧街角") or node_name.begins_with("原创城市首店") or node_name.begins_with("原创生成店铺"):
			node.visible = not is_drive_lane_capture
		for prefix in prefixes:
			if node_name.begins_with(prefix):
				node.visible = not close_store_view and not back_alley_view
				break
	for drive_node in _city08_near_wall_nodes:
		if is_instance_valid(drive_node):
			drive_node.visible = not is_drive_lane_capture
	if reference_capture_mode and back_alley_view:
		# 终点参考镜头由原创傍晚街道卡承担远景；清理候选脚本自身的侧墙，
		# 并关闭正式灰盒门面和低模人群的渲染，碰撞/任务节点仍留在场景中。
		for candidate_visual in find_children("*", "", true, false):
			var candidate_visual_name := str(candidate_visual.name)
			if candidate_visual_name != "原创城市终点傍晚街道背景卡":
				candidate_visual.visible = false
		var endpoint_hidden_names := [
			"街边店铺", "商店一", "街区背景建筑", "旺铺转让门面", "旺铺转让",
			"街道立面细节", "街区地面", "道路", "道路横向", "道路视觉细节", "入口人群", "冲突对象",
			"人群碰撞体", "扫码登记牌", "登记员", "扫码登记局部暖光", "新街区巷道",
			"后场仓储建筑", "后场仓储围挡", "后场装卸台", "原创写实后场仓储门面候选",
			"后场仓储门面细节", "交互道具层"
		]
		for endpoint_visual in city_root.find_children("*", "", true, false):
			var endpoint_visual_name := str(endpoint_visual.name)
			if endpoint_visual_name in endpoint_hidden_names or endpoint_visual_name.begins_with("行人") or endpoint_visual_name.begins_with("人群") or endpoint_visual_name.contains("道路") or endpoint_visual_name.contains("车道"):
				endpoint_visual.visible = false
		# 终点相机远景板必须成为唯一的环境背景；正式城市里还有大量未命名
		# 的地面网格，单靠名称清理会让它们遮住远景板下半幅。这里只关闭
		# 环境渲染，不删除碰撞、导航、任务或动态实体。
		for endpoint_mesh in city_root.find_children("*", "MeshInstance3D", true, false):
			var endpoint_mesh_path := str(endpoint_mesh.get_path())
			var keep_dynamic_visual := endpoint_mesh_path.contains("/玩家/") or endpoint_mesh_path.contains("/蓝色三轮车/") or endpoint_mesh_path.contains("/交通") or endpoint_mesh_path.contains("/冲突")
			if not keep_dynamic_visual:
				endpoint_mesh.visible = false
	if reference_capture_mode and close_store_view and not is_drive_lane_capture and not back_alley_view:
		_restore_city01_foreground_crowd()

func _restore_city01_foreground_crowd() -> void:
	var crowd_root := get_node_or_null("候选店铺前景人群") as Node3D
	if crowd_root == null:
		return
	crowd_root.visible = true
	for person in crowd_root.get_children():
		if person is Node3D:
			(person as Node3D).visible = true
	for crowd_mesh in crowd_root.find_children("*", "MeshInstance3D", true, false):
		crowd_mesh.visible = true

func _is_city01_reference_visual_node(node_name: String) -> bool:
	return node_name in ["原创城市首店人群写实背景卡", "候选店铺前景人群"] or node_name.begins_with("候选店铺前景人群_")

func _record_candidate_visual_diagnostics() -> void:
	var city_root := _find_city_root()
	if _candidate_diagnostics_recorded or city_root == null or city_root.get("trace") == null or not bool(city_root.get("reference_capture_mode")):
		return
	_candidate_diagnostics_recorded = true
	var player = city_root.get("player")
	if player == null:
		return
	var nearby_meshes: Array[Dictionary] = []
	var visual_root := city_root.get_node_or_null("Visual")
	if visual_root == null:
		return
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or not mesh_node.visible:
			continue
		var mesh_path := str(mesh_node.get_path())
		if mesh_path.contains("/候选店铺前景人群/"):
			continue
		var distance := mesh_node.global_position.distance_to(player.global_position)
		if distance < 4.0 or distance > 14.0:
			continue
		nearby_meshes.append({
			"name": str(mesh_node.name),
			"path": mesh_path,
			"parent": str(mesh_node.get_parent().name) if mesh_node.get_parent() != null else "",
			"ancestor_chain": _candidate_ancestor_chain(mesh_node),
			"distance": snappedf(distance, 0.01),
			"position": [mesh_node.global_position.x, mesh_node.global_position.y, mesh_node.global_position.z]
		})
	nearby_meshes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["distance"]) < float(right["distance"]))
	var interaction_meshes: Array[Dictionary] = []
	var interaction_root := city_root.get_node_or_null("交互道具层/Visual")
	if interaction_root != null:
		for node in interaction_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_node := node as MeshInstance3D
			if mesh_node == null or not mesh_node.visible:
				continue
			var distance := mesh_node.global_position.distance_to(player.global_position)
			if distance > 14.0:
				continue
			interaction_meshes.append({"name": str(mesh_node.name), "path": str(mesh_node.get_path()), "distance": snappedf(distance, 0.01), "position": [mesh_node.global_position.x, mesh_node.global_position.y, mesh_node.global_position.z]})
	interaction_meshes.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return float(left["distance"]) < float(right["distance"]))
	city_root.trace.record("candidate_visual_diagnostics", {
		"visible_nearby_mesh_count": nearby_meshes.size(),
		"visible_nearby_meshes": nearby_meshes.slice(0, mini(nearby_meshes.size(), 160)),
		"store_interior_visible": _store_interior_visible,
		"store_interior_node_count": _store_interior_nodes.size(),
		"store_interior_visible_node_count": _store_interior_nodes.filter(func(node: Node) -> bool: return is_instance_valid(node) and node.visible).size(),
		"interaction_meshes": interaction_meshes.slice(0, mini(interaction_meshes.size(), 80)),
		"camera_distance": city_root.camera_rig.distance if city_root.get("camera_rig") != null else -1.0
	})

func _candidate_ancestor_chain(node: Node) -> Array[String]:
	var chain: Array[String] = []
	var current := node.get_parent()
	while current != null and chain.size() < 5:
		chain.append(str(current.name))
		current = current.get_parent()
	return chain

func _enhance_traffic_visuals() -> void:
	var city_root := get_parent()
	if city_root == null:
		return
	var traffic_list = city_root.get("traffic_vehicles")
	if not traffic_list is Array:
		return
	for index in range(traffic_list.size()):
		var traffic := traffic_list[index] as Node3D
		if traffic == null or traffic.get_node_or_null("候选交通视觉") != null:
			continue
		var visual := Node3D.new()
		visual.name = "候选交通视觉"
		traffic.add_child(visual)
		var body_material := _store_material(Color("263746") if index % 2 == 0 else Color("4d2f35"), 0.42, 0.28)
		var trim_material := _store_material(Color("c18f4f") if index % 2 == 0 else Color("8199a4"), 0.36, 0.42)
		var dark_material := _store_material(Color("171d24"), 0.78, 0.12)
		var lamp_material := _store_material(Color("f4d38b"), 0.26, 0.08)
		lamp_material.emission_enabled = true
		lamp_material.emission = Color("b77e39")
		lamp_material.emission_energy_multiplier = 0.16
		_add_traffic_box(visual, "候选交通前保险杠", Vector3(1.28, 0.16, 0.12), Vector3(0.0, -0.12, -1.20), trim_material)
		_add_traffic_box(visual, "候选交通后保险杠", Vector3(1.28, 0.16, 0.12), Vector3(0.0, -0.12, 1.20), dark_material)
		_add_traffic_box(visual, "候选交通车顶行李架", Vector3(0.88, 0.08, 0.76), Vector3(0.0, 0.78, 0.12), trim_material)
		_add_traffic_box(visual, "候选交通左侧饰条", Vector3(0.06, 0.10, 1.44), Vector3(-0.74, 0.08, 0.0), body_material)
		_add_traffic_box(visual, "候选交通右侧饰条", Vector3(0.06, 0.10, 1.44), Vector3(0.74, 0.08, 0.0), body_material)
		for wheel_side in [-1.0, 1.0]:
			for wheel_z in [-0.76, 0.76]:
				var wheel := MeshInstance3D.new()
				wheel.name = "候选交通车轮"
				var wheel_mesh := CylinderMesh.new()
				wheel_mesh.top_radius = 0.25
				wheel_mesh.bottom_radius = 0.25
				wheel_mesh.height = 0.12
				wheel.mesh = wheel_mesh
				wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
				wheel.position = Vector3(wheel_side * 0.76, -0.38, wheel_z)
				wheel.material_override = dark_material
				visual.add_child(wheel)
		_add_traffic_box(visual, "候选交通左前灯", Vector3(0.24, 0.12, 0.05), Vector3(-0.42, 0.12, -1.23), lamp_material)
		_add_traffic_box(visual, "候选交通右前灯", Vector3(0.24, 0.12, 0.05), Vector3(0.42, 0.12, -1.23), lamp_material)
		_add_traffic_box(visual, "候选交通左尾灯", Vector3(0.20, 0.12, 0.05), Vector3(-0.42, 0.12, 1.23), trim_material)
		_add_traffic_box(visual, "候选交通右尾灯", Vector3(0.20, 0.12, 0.05), Vector3(0.42, 0.12, 1.23), trim_material)

func _enhance_player_vehicle_visual() -> void:
	# 参考帧能明确看到车尾灯和车牌；这些节点只属于候选视觉层，不改变载具碰撞或驾驶逻辑。
	var city_root := get_parent()
	if city_root == null:
		return
	var vehicle = city_root.get("vehicle")
	if vehicle == null:
		return
	var visual := vehicle.get_node_or_null("Visual") as Node3D
	if visual == null or visual.find_child("候选三轮车后尾灯", true, false) != null:
		return
	var details := Node3D.new()
	details.name = "候选三轮车车尾细节"
	visual.add_child(details)
	var red_material := _store_material(Color("a62f2b"), 0.34, 0.04)
	red_material.emission_enabled = true
	red_material.emission = Color("5b1716")
	red_material.emission_energy_multiplier = 0.24
	var plate_material := _store_material(Color("e4d8ae"), 0.56, 0.02)
	_add_vehicle_detail_box(details, "候选三轮车后尾灯", Vector3(0.18, 0.12, 0.045), Vector3(-0.46, 0.26, 1.18), red_material)
	_add_vehicle_detail_box(details, "候选三轮车后尾灯", Vector3(0.18, 0.12, 0.045), Vector3(0.46, 0.26, 1.18), red_material)
	_add_vehicle_detail_box(details, "候选三轮车后车牌", Vector3(0.38, 0.12, 0.025), Vector3(0.0, 0.28, 1.185), plate_material)
	_add_vehicle_detail_box(details, "候选三轮车货斗横向绑带", Vector3(1.12, 0.035, 0.035), Vector3(0.0, 0.58, 0.70), plate_material)

func _add_vehicle_detail_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	_mark_visual_only(node)
	parent.add_child(node)

func _add_traffic_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	_mark_visual_only(node)
	parent.add_child(node)

func _tune_city_candidate_lighting() -> void:
	var city_root := get_parent()
	if city_root == null:
		return
	var environment_nodes := city_root.find_children("*", "WorldEnvironment", true, false)
	var environment_node: WorldEnvironment = environment_nodes[0] as WorldEnvironment if not environment_nodes.is_empty() else null
	var player = city_root.get("player")
	var vehicle = city_root.get("vehicle")
	var is_endpoint_capture := _is_endpoint_capture(city_root)
	var is_drive_lane_capture: bool = player != null and vehicle != null and vehicle.driver == player and float(player.global_position.z) > 1.0 and float(player.global_position.z) <= 8.0 and not is_endpoint_capture
	if environment_node != null and environment_node.environment != null:
		var environment := environment_node.environment
		if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:
			var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
			if is_endpoint_capture:
				sky_material.sky_top_color = Color("2d3d57")
				sky_material.sky_horizon_color = Color("bc8170")
				sky_material.ground_bottom_color = Color("30343c")
				sky_material.ground_horizon_color = Color("746b6b")
				environment.ambient_light_energy = 0.50
				environment.tonemap_exposure = 0.92
				environment.fog_light_color = Color("7f818f")
				environment.fog_light_energy = 0.26
			elif is_drive_lane_capture:
				sky_material.sky_top_color = Color("526777")
				sky_material.sky_horizon_color = Color("c9b1a2")
				sky_material.ground_bottom_color = Color("4a5150")
				sky_material.ground_horizon_color = Color("8e8a80")
				environment.ambient_light_energy = 0.72
				environment.tonemap_exposure = 1.00
				environment.fog_light_color = Color("a0a0a0")
				environment.fog_light_energy = 0.20
			else:
				sky_material.sky_top_color = Color("5a7180")
				sky_material.sky_horizon_color = Color("d0ad8f")
				sky_material.ground_bottom_color = Color("3d4447")
				sky_material.ground_horizon_color = Color("8f8072")
				environment.ambient_light_energy = 0.78
				environment.tonemap_exposure = 1.08
				environment.fog_light_color = Color("9f9b94")
				environment.fog_light_energy = 0.16
	var sun_nodes := city_root.find_children("*", "DirectionalLight3D", true, false)
	var sun: DirectionalLight3D = sun_nodes[0] as DirectionalLight3D if not sun_nodes.is_empty() else null
	if sun != null:
		sun.light_energy = 0.42 if is_endpoint_capture else 0.72 if is_drive_lane_capture else 0.90
		sun.light_color = Color("e1a07a") if is_endpoint_capture else Color("e7bd9c") if is_drive_lane_capture else Color("f3d4ad")

func _build_road_continuity() -> void:
	var facade := _store_material(Color("6b5d5a"), 0.86, 0.0)
	var facade_alt := _store_material(Color("52616a"), 0.82, 0.02)
	var window := _store_material(Color("6d9499"), 0.26, 0.12)
	window.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window.albedo_color.a = 0.82
	var window_light := _store_material(Color("d7b77f"), 0.44, 0.02)
	var metal := _store_material(Color("39454a"), 0.58, 0.34)
	var asphalt := _asphalt_material()
	var lane_mark := _store_material(Color("d8c99d"), 0.54, 0.02)
	lane_mark.emission_enabled = true
	lane_mark.emission = Color("5f5038")
	lane_mark.emission_energy_multiplier = 0.08
	var road_reflector := _store_material(Color("c6d8d1"), 0.32, 0.18)
	_add_store_box("原创连续街区沥青路面", Vector3(6.70, 0.026, 33.0), Vector3(0.0, 0.085, 1.8), asphalt, 0.0)
	# 城市驾驶参考帧需要连续的行驶方向线；它们只提供视觉节奏，不参与路径与碰撞。
	for mark_index in range(9):
		var mark_z := -12.6 + float(mark_index) * 3.75
		_add_store_box("原创连续街区道路中线", Vector3(0.10, 0.008, 1.08), Vector3(0.0, 0.108, mark_z), lane_mark, 0.002)
		_add_store_box("原创连续街区左侧道钉", Vector3(0.08, 0.012, 0.08), Vector3(-2.62, 0.112, mark_z + 0.40), road_reflector, 0.012)
		_add_store_box("原创连续街区右侧道钉", Vector3(0.08, 0.012, 0.08), Vector3(2.62, 0.112, mark_z + 0.40), road_reflector, 0.012)
	# 在信号段建立横向斑马线，强化 city-09 的交通节点和车辆减速关系。
	for cross_index in range(7):
		var cross_x := -2.35 + float(cross_index) * 0.78
		_add_store_box("原创连续街区斑马线", Vector3(0.34, 0.009, 1.70), Vector3(cross_x, 0.110, 1.15), lane_mark, 0.002)
	for index in range(4):
		var z := 6.0 + float(index) * 5.6
		var left_center := Vector3(-6.2, 2.0, z)
		var right_center := Vector3(6.2, 2.0, z)
		_add_store_box("原创连续街区左建筑", Vector3(4.4, 4.2, 4.2), left_center, facade if index % 2 == 0 else facade_alt, 0.04)
		_add_store_box("原创连续街区右建筑", Vector3(4.4, 4.2, 4.2), right_center, facade_alt if index % 2 == 0 else facade, 0.04)
		for side in [-1.0, 1.0]:
			var inner_x: float = side * 4.0
			for window_index in range(3):
				var window_y := 1.55 + float(window_index) * 0.78
				var window_material := window_light if (index + window_index) % 3 == 0 else window
				_add_store_box("原创连续街区窗格", Vector3(0.08, 0.42, 0.92), Vector3(inner_x, window_y, z - 1.15), window_material, 0.01)
				_add_store_box("原创连续街区窗格", Vector3(0.08, 0.42, 0.92), Vector3(inner_x, window_y, z + 0.10), window_material, 0.01)
			_add_store_label("原创连续街区招牌", "街区店铺" if index % 2 == 0 else "仓储街", Vector3(inner_x, 3.35, z - 1.95), Color("e7d3a1"), 14)
			# 近景立面增加门厅、竖向分缝和小型橱窗，避免建筑只剩没有尺度感的整块体积。
			var door_material := _store_material(Color("28343b") if index % 2 == 0 else Color("3d3033"), 0.48, 0.12)
			var door_glass := _store_material(Color("6f9ca0"), 0.24, 0.08)
			door_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			door_glass.albedo_color.a = 0.72
			_add_store_box("原创连续街区门厅", Vector3(0.09, 1.60, 0.88), Vector3(inner_x, 0.88, z + 1.18), door_material, 0.018)
			_add_store_box("原创连续街区门厅玻璃", Vector3(0.035, 1.26, 0.62), Vector3(inner_x - side * 0.012, 0.96, z + 1.18), door_glass, 0.008)
			_add_store_box("原创连续街区立面分缝", Vector3(0.10, 3.68, 0.08), Vector3(inner_x, 1.92, z - 2.04), metal, 0.006)
	for x in [-3.95, 3.95]:
		for z in [6.0, 11.6, 17.2]:
			_add_store_box("原创连续街区街灯杆", Vector3(0.06, 2.80, 0.06), Vector3(x, 1.40, z), metal, 0.008)
			_add_store_box("原创连续街区街灯臂", Vector3(0.56, 0.06, 0.06), Vector3(x + (0.25 if x < 0.0 else -0.25), 2.72, z), metal, 0.008)
			_add_store_box("原创连续街区灯罩", Vector3(0.18, 0.08, 0.18), Vector3(x + (0.50 if x < 0.0 else -0.50), 2.67, z), window_light, 0.02)

func _build_drive_lane_facade_accents() -> void:
	# 驾驶镜头使用窄立面而不是整块建筑，保留道路两侧的连续尺度，同时避免近墙遮挡。
	var wall_material := _store_material(Color("4e5d63"), 0.82, 0.02)
	var wall_alt_material := _store_material(Color("665a58"), 0.84, 0.0)
	var frame_material := _store_material(Color("28353b"), 0.48, 0.18)
	var glass_material := _store_material(Color("6c9ba0"), 0.24, 0.10)
	var warm_glass := _store_material(Color("c48e5b"), 0.34, 0.04)
	warm_glass.emission_enabled = true
	warm_glass.emission = Color("6f3e2a")
	warm_glass.emission_energy_multiplier = 0.12
	var awning_material := _store_material(Color("8c4d3f"), 0.76, 0.0)
	var door_material := _store_material(Color("30383c"), 0.54, 0.12)
	var lamp_material := _store_material(Color("d5ad72"), 0.36, 0.02)
	var sidewalk_material := _store_material(Color("77716b"), 0.92, 0.0)
	var curb_material := _store_material(Color("b0a79a"), 0.82, 0.0)
	for side in [-1.0, 1.0]:
		var side_name := "左" if side < 0.0 else "右"
		var sidewalk := _add_store_box("驾驶镜头" + side_name + "侧人行道", Vector3(1.20, 0.12, 28.0), Vector3(side * 4.02, 0.14, 8.0), sidewalk_material, 0.008)
		_drive_facade_nodes.append(sidewalk)
		var curb := _add_store_box("驾驶镜头" + side_name + "侧路缘", Vector3(0.16, 0.20, 28.0), Vector3(side * 3.43, 0.20, 8.0), curb_material, 0.008)
		_drive_facade_nodes.append(curb)

	for index in range(5):
		var z := 2.2 + float(index) * 4.35
		for side in [-1.0, 1.0]:
			var side_name := "左" if side < 0.0 else "右"
			var facade_x: float = side * 4.22
			var wall := _add_store_box("驾驶镜头" + side_name + "侧街墙" + str(index), Vector3(0.22, 3.45, 3.82), Vector3(facade_x, 1.80, z), wall_material if index % 2 == 0 else wall_alt_material, 0.035)
			_drive_facade_nodes.append(wall)
			var cornice := _add_store_box("驾驶镜头" + side_name + "侧檐口" + str(index), Vector3(0.30, 0.14, 3.98), Vector3(facade_x - side * 0.06, 3.38, z), awning_material, 0.012)
			_drive_facade_nodes.append(cornice)
			var door := _add_store_box("驾驶镜头" + side_name + "侧门厅" + str(index), Vector3(0.26, 1.52, 0.82), Vector3(facade_x - side * 0.14, 0.86, z + 0.96), door_material, 0.012)
			_drive_facade_nodes.append(door)
			for window_index in range(2):
				var window_z := z - 0.86 + float(window_index) * 1.55
				var window_surface := warm_glass if (index + window_index) % 4 == 0 else glass_material
				var window_frame := _add_store_box("驾驶镜头" + side_name + "侧窗框" + str(index) + "_" + str(window_index), Vector3(0.12, 0.62, 1.04), Vector3(facade_x - side * 0.15, 1.78, window_z), frame_material, 0.008)
				_drive_facade_nodes.append(window_frame)
				var window := _add_store_box("驾驶镜头" + side_name + "侧玻璃" + str(index) + "_" + str(window_index), Vector3(0.14, 0.46, 0.82), Vector3(facade_x - side * 0.17, 1.78, window_z), window_surface, 0.004)
				_drive_facade_nodes.append(window)
			var awning := _add_store_box("驾驶镜头" + side_name + "侧遮阳棚" + str(index), Vector3(0.64, 0.12, 1.36), Vector3(facade_x - side * 0.30, 2.74, z + 0.92), awning_material, 0.012)
			_drive_facade_nodes.append(awning)
			_add_drive_lane_label("驾驶镜头" + side_name + "侧招牌" + str(index), "街边便利店" if index % 2 == 0 else "仓储街", Vector3(facade_x - side * 0.28, 2.98, z - 0.84), Color("ead5a5"))

	for side in [-1.0, 1.0]:
		var side_name := "左" if side < 0.0 else "右"
		var pole_x: float = side * 3.72
		for index in range(4):
			var z := 2.8 + float(index) * 5.6
			var pole := _add_store_box("驾驶镜头" + side_name + "侧路灯杆" + str(index), Vector3(0.06, 2.70, 0.06), Vector3(pole_x, 1.35, z), frame_material, 0.006)
			_drive_facade_nodes.append(pole)
			var lamp := _add_store_box("驾驶镜头" + side_name + "侧灯罩" + str(index), Vector3(0.24, 0.10, 0.24), Vector3(pole_x - side * 0.22, 2.66, z), lamp_material, 0.02)
			_drive_facade_nodes.append(lamp)

func _add_drive_lane_label(node_name: String, text: String, at: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.font_size = 14
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color("171a1f")
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_drive_facade_nodes.append(label)
	add_child(label)

func _build_facade_depth_pass() -> void:
	# 立面第二层细节只使用共享材质和 MeshInstance3D，不生成碰撞、导航、交互或任务状态。
	# 目标是把参考视频里的连续街墙拆成窗框、檐口、设备和阳台尺度，避免远景只剩单色盒体。
	var concrete := _store_material(Color("6d7373"), 0.82, 0.04)
	var concrete_light := _store_material(Color("a69a8c"), 0.76, 0.02)
	var window_frame := _store_material(Color("27333a"), 0.52, 0.24)
	var window_glass := _store_material(Color("52747a"), 0.20, 0.18)
	window_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	window_glass.albedo_color.a = 0.78
	var warm_glass := _store_material(Color("c99d68"), 0.34, 0.08)
	warm_glass.emission_enabled = true
	warm_glass.emission = Color("7b5235")
	warm_glass.emission_energy_multiplier = 0.10
	var awning := _store_material(Color("6b4b43"), 0.88, 0.0)
	var utility := _store_material(Color("3d464b"), 0.62, 0.30)

	for index in range(4):
		var z := 6.0 + float(index) * 5.6
		for side in [-1.0, 1.0]:
			var facade_x: float = side * 4.01
			var facade_color := concrete_light if (index + int(side)) % 2 == 0 else concrete
			# 首层门店檐口与楼层水平分缝。
			_add_store_box("原创立面首层檐口", Vector3(0.07, 0.16, 4.02), Vector3(facade_x, 2.92, z), awning, 0.008)
			for floor_index in range(3):
				var window_y := 1.42 + float(floor_index) * 0.82
				_add_store_box("原创立面楼层分缝", Vector3(0.06, 0.055, 4.02), Vector3(facade_x, window_y - 0.33, z), facade_color, 0.004)
				for window_index in range(3):
					var window_z := z - 1.28 + float(window_index) * 1.28
					var window_surface := warm_glass if (index + floor_index + window_index) % 4 == 0 else window_glass
					_add_store_box("原创立面窗框", Vector3(0.055, 0.58, 0.92), Vector3(facade_x, window_y, window_z), window_frame, 0.006)
					_add_store_box("原创立面玻璃", Vector3(0.062, 0.42, 0.72), Vector3(facade_x - side * 0.014, window_y, window_z), window_surface, 0.004)
					_add_store_box("原创立面窗台", Vector3(0.10, 0.07, 1.02), Vector3(facade_x - side * 0.035, window_y - 0.34, window_z), concrete_light, 0.004)
			# 楼顶压边、竖向结构柱和少量外机，让建筑拥有真实尺度参照。
			_add_store_box("原创立面楼顶压边", Vector3(0.12, 0.16, 4.28), Vector3(facade_x, 4.10, z), concrete_light, 0.008)
			for column_z in [z - 1.98, z + 1.98]:
				_add_store_box("原创立面竖向结构柱", Vector3(0.12, 3.86, 0.12), Vector3(facade_x - side * 0.025, 2.02, column_z), concrete_light, 0.006)
			if index % 2 == 0:
				_add_store_box("原创立面空调外机", Vector3(0.26, 0.28, 0.34), Vector3(facade_x - side * 0.16, 2.70, z + 1.32), utility, 0.012)
				_add_store_box("原创立面空调支架", Vector3(0.05, 0.06, 0.44), Vector3(facade_x - side * 0.20, 2.52, z + 1.32), utility, 0.004)
			else:
				_add_store_box("原创立面阳台栏杆", Vector3(0.08, 0.08, 1.35), Vector3(facade_x - side * 0.08, 2.50, z - 0.42), utility, 0.004)
				_add_store_box("原创立面阳台上沿", Vector3(0.08, 0.08, 1.35), Vector3(facade_x - side * 0.08, 2.78, z - 0.42), utility, 0.004)

func _build_distant_city_silhouette() -> void:
	# 街道尽端的远景楼体只负责填充城市纵深，不接入碰撞、导航或任务状态。
	var facade_colors := [Color("4b5962"), Color("5d5558"), Color("46555b"), Color("665a58")]
	var window_material := _store_material(Color("b9a27d"), 0.38, 0.04)
	var roof_material := _store_material(Color("252e34"), 0.74, 0.18)
	for index in range(5):
		var x := -8.4 + float(index) * 4.2
		var height := 4.6 + float(index % 3) * 0.75
		var facade := _store_material(facade_colors[index % facade_colors.size()], 0.84, 0.02)
		_add_store_box("原创远景城市楼体", Vector3(3.72, height, 1.48), Vector3(x, height * 0.5, 25.8), facade, 0.02)
		_add_store_box("原创远景城市楼顶", Vector3(3.88, 0.16, 1.62), Vector3(x, height + 0.08, 25.8), roof_material, 0.01)
		for window_index in range(3):
			var window_y := 1.45 + float(window_index) * 0.82
			if window_y > height - 0.35:
				continue
			for window_x in [-0.92, 0.0, 0.92]:
				_add_store_box("原创远景城市窗格", Vector3(0.58, 0.34, 0.045), Vector3(x + window_x, window_y, 25.03), window_material, 0.004)

func _asphalt_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	# 候选城市包不依赖外部沥青纹理；最终材质仍需在视觉签收阶段替换为已登记的原创 PBR 资产。
	material.albedo_color = Color("3e474b")
	material.roughness = 0.90
	material.set_meta("original_procedural_asset", true)
	material.uv1_scale = Vector3(1.0, 6.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_street_trees_and_curb() -> void:
	var curb_material := _store_material(Color("9b9184"), 0.78, 0.02)
	var sidewalk_material := _store_material(Color("776e68"), 0.92, 0.0)
	var trunk_material := _store_material(Color("4a3429"), 0.96, 0.0)
	var foliage_materials := [
		_store_material(Color("31493d"), 0.90, 0.0),
		_store_material(Color("405a46"), 0.88, 0.0),
		_store_material(Color("52634a"), 0.86, 0.0),
	]
	# 只增加视觉边界，沿用正式道路的宽度，不创建任何碰撞体或导航边。
	for side in [-1.0, 1.0]:
		_add_store_box("原创连续街区路缘", Vector3(0.20, 0.16, 33.0), Vector3(side * 3.62, 0.10, 1.8), curb_material, 0.01)
		_add_store_box("原创连续街区人行道边界", Vector3(0.72, 0.06, 33.0), Vector3(side * 4.12, 0.055, 1.8), sidewalk_material, 0.01)
	var tree_layout := [
		Vector3(-4.35, 0.0, 7.2), Vector3(4.35, 0.0, 9.2),
		Vector3(-4.35, 0.0, 12.4), Vector3(4.35, 0.0, 14.8),
		Vector3(-4.35, 0.0, 18.0), Vector3(4.35, 0.0, 20.2),
	]
	var branch_material := _store_material(Color("3f3028"), 0.96, 0.0)
	for index in range(tree_layout.size()):
		var tree_at: Vector3 = tree_layout[index]
		var trunk := MeshInstance3D.new()
		trunk.name = "原创连续街区行道树树干"
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.12
		trunk_mesh.bottom_radius = 0.18
		trunk_mesh.height = 2.70
		trunk.mesh = trunk_mesh
		trunk.position = tree_at + Vector3(0.0, 1.35, 0.0)
		trunk.material_override = trunk_material
		add_child(trunk)
		for branch_index in range(3):
			var branch := MeshInstance3D.new()
			branch.name = "原创连续街区行道树枝条"
			var branch_mesh := BoxMesh.new()
			branch_mesh.size = Vector3(0.055, 0.055, 0.78)
			branch.mesh = branch_mesh
			branch.position = tree_at + Vector3(0.0, 1.98 + float(branch_index) * 0.26, 0.0)
			branch.rotation_degrees = Vector3(0.0, -24.0 if (index + branch_index) % 2 == 0 else 24.0, 0.0)
			branch.material_override = branch_material
			add_child(branch)
		var crown := MeshInstance3D.new()
		crown.name = "原创连续街区行道树树冠"
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.62 if index % 2 == 0 else 0.52
		crown_mesh.height = crown_mesh.radius * 1.72
		crown.mesh = crown_mesh
		crown.position = tree_at + Vector3(0.0, 2.92, 0.0)
		crown.material_override = foliage_materials[index % foliage_materials.size()]
		add_child(crown)
	# 参考帧中的横向车道连接感，标线仍是 MeshInstance3D，不改道路碰撞。
	var marking_material := _store_material(Color("d6c9a9"), 0.64, 0.0)
	for index in range(5):
		_add_store_box("原创连续街区横向车道标线", Vector3(5.6, 0.018, 0.11), Vector3(0.0, 0.075, -0.8 + float(index) * 0.42), marking_material, 0.0)
	# 参考驾驶段能持续看到道路中线与前方消失点；补充短虚线，让城市道路
	# 不再像一整块无方向的灰色平面。它仍然只是视觉层，不改变碰撞或导航。
	for index in range(8):
		_add_store_box("原创连续街区道路中线虚线", Vector3(0.08, 0.014, 1.05), Vector3(0.0, 0.102, 0.8 + float(index) * 2.15), marking_material, 0.0)

func _build_street_storytelling() -> void:
	# 这是纯表现层扩展：所有节点均为 MeshInstance3D/Label3D，不生成碰撞、导航或交互目标。
	var canopy_fabric := _store_material(Color("a45f45"), 0.88, 0.0)
	var canopy_fabric_alt := _store_material(Color("3d6870"), 0.84, 0.0)
	var pole_material := _store_material(Color("3c4248"), 0.58, 0.42)
	var cable_material := _store_material(Color("171b20"), 0.92, 0.0)
	var crate_material := _store_material(Color("765239"), 0.90, 0.0)
	var crate_edge_material := _store_material(Color("b28a5e"), 0.76, 0.0)
	var bollard_material := _store_material(Color("c18a45"), 0.66, 0.22)
	var board_material := _store_material(Color("203b42"), 0.64, 0.18)
	var board_light := _store_material(Color("e3d0a0"), 0.48, 0.0)
	board_light.emission_enabled = true
	board_light.emission = Color("8f7048")
	board_light.emission_energy_multiplier = 0.10

	# 两组门头遮阳棚把连续建筑和首店/终点店串成一条可读街景。
	for index in range(4):
		var z := 5.7 + float(index) * 5.6
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 4.02
			var fabric := canopy_fabric if (index + int(side)) % 2 == 0 else canopy_fabric_alt
			_add_store_box("原创连续街区遮阳棚", Vector3(1.46, 0.08, 1.12), Vector3(x, 3.04, z), fabric, 0.012)
			_add_store_box("原创遮阳棚支架", Vector3(0.05, 0.62, 0.05), Vector3(x - side * 0.62, 2.74, z - 0.42), pole_material, 0.006)
			_add_store_box("原创遮阳棚支架", Vector3(0.05, 0.62, 0.05), Vector3(x + side * 0.62, 2.74, z - 0.42), pole_material, 0.006)

	# 供电杆线使用细圆柱，建立远景纵深和城市生活感；不接入交通或角色感知。
	for index in range(3):
		var z := 4.0 + float(index) * 6.3
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 4.82
			_add_story_cylinder("原创街区供电杆", 0.07, 3.5, Vector3(x, 1.75, z), pole_material)
			_add_store_box("原创街区横担", Vector3(0.82, 0.05, 0.05), Vector3(x, 3.30, z), pole_material, 0.004)
			_add_story_cable("原创街区供电线", Vector3(x, 3.28, z), Vector3(side * 4.82, 3.28, z + 6.3), cable_material)

	# 店铺门口的货箱和路侧护柱强化城市任务空间的可读边界，但不创建新的交互点。
	for index in range(4):
		var z := 5.0 + float(index) * 5.6
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := side * 3.50
		_add_store_box("原创配送货箱", Vector3(0.52, 0.46, 0.52), Vector3(x, 0.34, z), crate_material, 0.014)
		_add_store_box("原创配送货箱箱带", Vector3(0.06, 0.48, 0.54), Vector3(x, 0.35, z), crate_edge_material, 0.004)
		_add_store_box("原创配送货箱箱带", Vector3(0.54, 0.06, 0.06), Vector3(x, 0.58, z), crate_edge_material, 0.004)
	for index in range(6):
		var z := 2.0 + float(index) * 3.0
		var side := -1.0 if index % 2 == 0 else 1.0
		_add_story_cylinder("原创路侧护柱", 0.09, 0.62, Vector3(side * 3.48, 0.31, z), bollard_material)

	# 站牌是视觉导航锚点，不承担地图传送或任务逻辑。
	_add_store_box("原创配送站牌", Vector3(0.08, 1.74, 0.08), Vector3(3.36, 0.87, 7.5), pole_material, 0.006)
	_add_store_box("原创配送站牌面板", Vector3(0.62, 0.78, 0.06), Vector3(3.36, 1.70, 7.5), board_material, 0.012)
	_add_store_label("原创配送站牌文字", "配送站", Vector3(3.36, 1.76, 7.45), board_light.albedo_color, 18)

func _build_city_landmark_pack() -> void:
	# 物理场景的第二层完成度：把首店、登记点、主干道、后场和终点
	# 拆成可识别的街道地标。这里严格只生成 MeshInstance3D、Label3D
	# 和纯视觉材质，不创建碰撞、导航、交互或任务状态。
	var concrete := _store_material(Color("77736d"), 0.90, 0.0)
	var dark_metal := _store_material(Color("273238"), 0.54, 0.34)
	var warm_light := _store_material(Color("e3b56f"), 0.28, 0.02)
	warm_light.emission_enabled = true
	warm_light.emission = Color("a76535")
	warm_light.emission_energy_multiplier = 0.24
	var red := _store_material(Color("b94a3e"), 0.72, 0.02)
	var cream := _store_material(Color("e3d1ae"), 0.70, 0.0)
	var glass := _store_material(Color("4e737a"), 0.18, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.76
	var asphalt_marking := _store_material(Color("d8caa4"), 0.68, 0.0)

	# 首店街区：入口门头、灯箱、橱窗和货运缓冲区形成第一眼空间锚点。
	_add_store_box("原创场景首店入口雨棚", Vector3(3.70, 0.10, 0.72), Vector3(-9.0, 3.12, -7.62), red, 0.014)
	_add_store_box("原创场景首店入口灯箱", Vector3(2.90, 0.42, 0.08), Vector3(-9.0, 2.70, -7.54), warm_light, 0.012)
	_add_store_label("原创场景首店入口招牌", "免费鸡蛋铺", Vector3(-9.0, 2.76, -7.48), cream.albedo_color, 20)
	for x in [-10.30, -9.86, -8.14, -7.70]:
		_add_store_box("原创场景首店橱窗立柱", Vector3(0.08, 1.72, 0.08), Vector3(x, 1.32, -7.48), dark_metal, 0.006)
	_add_store_box("原创场景首店橱窗玻璃", Vector3(3.18, 1.48, 0.035), Vector3(-9.0, 1.34, -7.46), glass, 0.004)
	for x in [-10.10, -9.0, -7.90]:
		_add_store_box("原创场景首店门口台阶", Vector3(0.82, 0.08, 0.34), Vector3(x, 0.18, -7.18), concrete, 0.006)

	# 登记点：站牌、遮雨棚和导向灯让“上车/登记”不是一块空地。
	_add_store_box("原创场景登记点雨棚顶", Vector3(2.30, 0.10, 1.28), Vector3(3.36, 2.32, 7.48), dark_metal, 0.012)
	for x in [2.34, 4.38]:
		_add_store_box("原创场景登记点雨棚立柱", Vector3(0.08, 2.20, 0.08), Vector3(x, 1.22, 7.48), dark_metal, 0.006)
	_add_store_box("原创场景登记点路线牌", Vector3(0.92, 0.66, 0.08), Vector3(3.36, 1.78, 7.40), red, 0.010)
	_add_store_label("原创场景登记点路线文字", "登记 / 上车", Vector3(3.36, 1.82, 7.32), cream.albedo_color, 15)
	_add_store_box("原创场景登记点地面标识", Vector3(1.42, 0.018, 2.10), Vector3(3.36, 0.12, 8.62), asphalt_marking, 0.0)

	# 主干道：补齐路口、斑马线和信号灯，给驾驶段提供明确的前进方向。
	for stripe_index in range(7):
		_add_store_box("原创场景主干道斑马线", Vector3(0.44, 0.020, 0.16), Vector3(-1.52 + float(stripe_index) * 0.50, 0.12, 1.02), asphalt_marking, 0.0)
	for side in [-1.0, 1.0]:
		var x: float = side * 3.22
		_add_store_box("原创场景路口信号灯杆", Vector3(0.08, 2.82, 0.08), Vector3(x, 1.42, 1.38), dark_metal, 0.006)
		_add_store_box("原创场景路口信号灯横臂", Vector3(0.86, 0.08, 0.08), Vector3(x - side * 0.38, 2.78, 1.38), dark_metal, 0.006)
		_add_store_box("原创场景路口红灯", Vector3(0.22, 0.28, 0.16), Vector3(x - side * 0.72, 2.64, 1.38), red, 0.028)
		_add_store_box("原创场景路口信号灯光", Vector3(0.12, 0.12, 0.08), Vector3(x - side * 0.72, 2.66, 1.30), warm_light, 0.020)
	_add_store_label("原创场景主干道方向牌", "东区  /  后场仓储", Vector3(-3.28, 2.36, 3.12), cream.albedo_color, 14)

	# 后场与终点之间的生活化小物件，避免任务终点只有一面门和一块背景卡。
	for index in range(3):
		var x := 8.18 + float(index) * 0.92
		_add_store_box("原创场景后场托盘", Vector3(0.62, 0.08, 0.82), Vector3(x, 0.12, 15.26), concrete, 0.006)
		_add_store_box("原创场景后场货箱", Vector3(0.68, 0.58, 0.72), Vector3(x, 0.44, 15.22), red if index == 1 else dark_metal, 0.012)
	_add_store_box("原创场景终点门前导向灯", Vector3(0.22, 0.10, 0.22), Vector3(10.0, 2.72, 5.62), warm_light, 0.018)
	_add_store_label("原创场景终点门前文字", "旺铺转让 / 交付点", Vector3(10.0, 2.96, 5.60), cream.albedo_color, 16)
	_set_landmark_scope("原创场景首店", ["city-01", "city-02", "city-03", "city-04", "city-05"])
	_set_landmark_scope("原创场景登记点", ["city-06", "city-07"])
	_set_landmark_scope("原创场景主干道", ["city-08", "city-09", "city-10"])
	_set_landmark_scope("原创场景后场", ["city-05", "city-10", "city-11"])
	_set_landmark_scope("原创场景终点", ["city-11"])

func _set_landmark_scope(prefix: String, scenario_ids: Array[String]) -> void:
	for landmark in find_children(prefix + "*", "", true, false):
		landmark.set_meta("landmark_scope", scenario_ids.duplicate())

func _update_landmark_visibility() -> void:
	var city_root := _find_city_root()
	if city_root == null:
		return
	var scenario_id := str(city_root.get_meta("reference_capture_scenario", ""))
	if scenario_id.is_empty():
		return
	for landmark in find_children("原创场景*", "", true, false):
		var scope = landmark.get_meta("landmark_scope", [])
		landmark.visible = not (scope is Array and not scope.is_empty() and not scope.has(scenario_id))

func _mark_visual_only(node: Node) -> void:
	# 所有候选城市细节都显式留下视觉层证据，供场景完整性测试和资产门禁检查。
	node.set_meta("visual_candidate", true)
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)

func _add_story_cylinder(node_name: String, radius: float, height: float, at: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	_mark_visual_only(node)
	add_child(node)

func _add_story_cable(node_name: String, from_at: Vector3, to_at: Vector3, material: Material) -> void:
	var delta := to_at - from_at
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = delta.length()
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = (from_at + to_at) * 0.5
	node.material_override = material
	_mark_visual_only(node)
	add_child(node)
	node.look_at(to_at, Vector3.UP)
	node.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _build_storefront_readability() -> void:
	var sign_material := _store_material(Color("b3312c"), 0.54, 0.02)
	var sign_dark := _store_material(Color("3a2118"), 0.66, 0.0)
	var sign_light := _store_material(Color("fff0c8"), 0.52, 0.0)
	var endpoint_sign_material := _store_material(Color("e4d8c3"), 0.62, 0.0)
	var shutter := _store_material(Color("53616a"), 0.48, 0.32)
	var shutter_edge := _store_material(Color("b9c1bc"), 0.42, 0.28)
	var glass := _store_material(Color("2f6571"), 0.18, 0.10)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.46
	var crate := _store_material(Color("6b4730"), 0.84, 0.0)
	var egg := _store_material(Color("e3d4ad"), 0.74, 0.0)
	var scan := _store_material(Color("1f4c54"), 0.36, 0.18)
	var scan_light := _store_material(Color("b7e7d0"), 0.26, 0.02)
	scan_light.emission_enabled = true
	scan_light.emission = Color("507d70")
	scan_light.emission_energy_multiplier = 0.12

	# 门头招牌：用 Label3D 保证远景仍能读出目标店铺，不引用参考视频商标。
	_add_store_box("原创店铺招牌底板", Vector3(5.30, 0.46, 0.08), Vector3(-9.0, 3.56, -7.62), sign_material, 0.025)
	_add_textured_sign("原创店铺招牌纹理", Vector2(5.08, 0.82), Vector3(-9.0, 3.56, -7.545), "res://art-source/city-full-kit-candidate/textures/storefront-sign-eggs-v1.png")
	_add_store_label("原创店铺招牌精确文字", "免费赠送鸡蛋", Vector3(-9.0, 3.56, -7.47), Color("fff0c8"), 22)
	_add_store_box("原创店铺入口左框", Vector3(0.14, 2.30, 0.12), Vector3(-10.75, 1.46, -7.58), shutter_edge, 0.018)
	_add_store_box("原创店铺入口右框", Vector3(0.14, 2.30, 0.12), Vector3(-7.25, 1.46, -7.58), shutter_edge, 0.018)
	_add_store_box("原创店铺入口顶框", Vector3(3.64, 0.14, 0.12), Vector3(-9.0, 2.60, -7.58), shutter_edge, 0.018)
	_add_store_box("原创店铺卷帘门", Vector3(2.72, 1.88, 0.055), Vector3(-9.0, 1.50, -7.58), shutter, 0.025)
	_add_store_box("原创店铺入口门槛", Vector3(3.22, 0.08, 0.30), Vector3(-9.0, 0.16, -7.72), shutter_edge, 0.012)
	for y in [0.72, 0.98, 1.24, 1.50, 1.76, 2.02]:
		_add_store_box("原创卷帘门横槽", Vector3(2.54, 0.026, 0.025), Vector3(-9.0, y, -7.545), shutter_edge, 0.004)

	# 门口两侧玻璃橱窗和可读货架，保持表现层独立于正式交互目标。
	_add_store_box("原创店铺左橱窗", Vector3(1.30, 1.24, 0.045), Vector3(-11.55, 1.86, -7.58), glass, 0.018)
	_add_store_box("原创店铺右橱窗", Vector3(1.30, 1.24, 0.045), Vector3(-6.45, 1.86, -7.58), glass, 0.018)
	for x in [-11.55, -6.45]:
		_add_store_box("原创橱窗货架", Vector3(1.08, 0.07, 0.30), Vector3(x, 1.12, -7.52), crate, 0.012)
		_add_store_box("原创橱窗货架", Vector3(1.08, 0.07, 0.30), Vector3(x, 1.62, -7.52), crate, 0.012)
		for egg_index in [-0.30, 0.0, 0.30]:
			_add_store_sphere("原创橱窗鸡蛋", Vector3(x + egg_index, 1.28, -7.48), 0.09, egg)

	# 扫码牌和状态灯是 city-07/city-11 可读反馈的视觉锚点，不接管原交互逻辑。
	_add_store_box("原创扫码牌立柱", Vector3(0.07, 1.18, 0.07), Vector3(-5.72, 0.72, -7.38), scan, 0.012)
	_add_store_box("原创扫码牌", Vector3(0.72, 0.56, 0.07), Vector3(-5.72, 1.34, -7.38), scan, 0.018)
	_add_store_box("原创扫码牌状态灯", Vector3(0.16, 0.08, 0.025), Vector3(-5.72, 1.48, -7.42), scan_light, 0.008)
	_add_store_label("原创扫码牌文字", "扫码登记", Vector3(-5.72, 1.28, -7.42), scan_light.albedo_color, 16)

	# 终点门面对应 city-11，保持与首店相同的原创招牌语言，但不复制参考视频标识。
	var endpoint_facade := _store_material(Color("8d7973"), 0.84, 0.0)
	# 正式城市碰撞仍由原运行时负责；这块薄立面只遮住候选采集中的重叠建筑，给终点门面留出可读的表现面。
	_add_store_box("原创终点店立面覆盖", Vector3(6.20, 4.20, 0.06), Vector3(8.6, 2.10, 6.85), endpoint_facade, 0.0)
	_add_store_box("原创终点店卷帘门", Vector3(5.60, 2.00, 0.055), Vector3(8.6, 1.35, 6.79), shutter, 0.025)
	_add_store_box("原创终点店门头", Vector3(6.00, 0.55, 0.10), Vector3(8.6, 2.65, 6.77), endpoint_sign_material, 0.025)
	_add_textured_sign("原创终点店招牌纹理", Vector2(5.72, 0.48), Vector3(8.6, 2.65, 6.715), "res://art-source/city-full-kit-candidate/textures/storefront-sign-endpoint-v1.png", true)
	_add_store_label("原创终点店招牌精确文字", "旺铺转让", Vector3(8.6, 2.65, 6.64), Color("3a2a21"), 24)
	for y in [0.62, 0.90, 1.18, 1.46, 1.74, 2.02]:
		_add_store_box("原创终点店横槽", Vector3(5.28, 0.026, 0.025), Vector3(8.6, y, 6.735), shutter_edge, 0.004)
	for x in [6.15, 8.6, 11.05]:
		_add_store_box("原创终点店橱窗", Vector3(1.70, 1.22, 0.045), Vector3(x, 1.78, 6.735), glass, 0.018)

func _build_store_interior_visual() -> void:
	# city-03 的近景重点是“进入店内后，左右货架和顶灯把玩家夹在通道中央”。
	# 这里全部使用 MeshInstance3D/OmniLight3D 表现层，不复制正式货架碰撞或交互目标。
	var rack_dark := _store_material(Color("2d353a"), 0.72, 0.18)
	var rack_edge := _store_material(Color("9a704d"), 0.70, 0.04)
	var floor_material := _store_material(Color("8c8177"), 0.90, 0.0)
	var back_wall := _store_material(Color("b6a38e"), 0.86, 0.0)
	var light_material := _store_material(Color("fff1cf"), 0.30, 0.02)
	light_material.emission_enabled = true
	light_material.emission = Color("e5b979")
	light_material.emission_energy_multiplier = 0.22
	var product_colors := [Color("d56d3f"), Color("6f9da0"), Color("d3ac55"), Color("8d668f"), Color("7d9a62")]
	var product_count := 0
	var light_count := 0

	_add_store_box("候选商店内景通道地面", Vector3(2.55, 0.035, 3.85), Vector3(-9.0, 0.065, -9.82), floor_material, 0.0)
	_add_store_box("候选商店内景后墙端景", Vector3(4.85, 2.28, 0.08), Vector3(-9.0, 1.14, -11.76), back_wall, 0.008)
	for side in [-1.0, 1.0]:
		var shelf_x: float = -9.0 + side * 1.62
		var shelf_name := "候选商店内景左货架" if side < 0.0 else "候选商店内景右货架"
		_add_store_box(shelf_name, Vector3(0.54, 2.24, 3.82), Vector3(shelf_x, 1.14, -9.82), rack_dark, 0.018)
		for row in range(4):
			var shelf_y := 0.30 + float(row) * 0.54
			_add_store_box("候选商店内景货架层板", Vector3(0.70, 0.065, 3.60), Vector3(shelf_x, shelf_y, -9.82), rack_edge, 0.006)
			for column in range(5):
				var product_x: float = shelf_x - side * 0.34
				var product_z := -11.12 + float(column) * 0.64
				var product := _add_store_box("候选商店内景商品", Vector3(0.16, 0.22, 0.30), Vector3(product_x, shelf_y + 0.15, product_z), _store_material(product_colors[(row + column) % product_colors.size()], 0.82, 0.0), 0.012)
				product.set_meta("visual_only", true)
				product_count += 1
	for index in range(4):
		var lamp_z := -8.68 - float(index) * 0.82
		_add_store_box("候选商店内景顶灯", Vector3(0.78, 0.065, 0.22), Vector3(-9.0, 2.78, lamp_z), light_material, 0.012)
		var lamp := OmniLight3D.new()
		lamp.name = "候选商店内景顶灯局部光"
		lamp.light_color = Color("ffd99b")
		lamp.light_energy = 0.26
		lamp.omni_range = 2.8
		lamp.position = Vector3(-9.0, 2.66, lamp_z)
		lamp.set_meta("visual_only", true)
		lamp.set_meta("store_interior_visual", true)
		_store_interior_nodes.append(lamp)
		add_child(lamp)
		light_count += 1
	set_meta("store_interior_product_count", product_count)
	set_meta("store_interior_light_count", light_count)

func _build_storefront_foreground_crowd() -> void:
	# city-01 的核心构图是“人群压到首店门前”；这里用纯 MeshInstance3D 形成可控的远近层次。
	# 这些人群只承担前景遮挡与密度，不创建碰撞体、路线、感知、交互或任务状态。
	var crowd_root := Node3D.new()
	crowd_root.name = "候选店铺前景人群"
	crowd_root.set_meta("visual_only", true)
	crowd_root.set_meta("asset_source", "project_original_generated_code_and_node_materials")
	add_child(crowd_root)
	var jacket_colors := [Color("8f3d36"), Color("3d5262"), Color("5b4b46"), Color("6d6671"), Color("3e5f58"), Color("7c5a43"), Color("4a4857"), Color("92534a")]
	var skin_colors := [Color("b27a65"), Color("996552"), Color("c18b73"), Color("8b594b")]
	var trouser_colors := [Color("28313b"), Color("3d3637"), Color("4a3d3a"), Color("232b31")]
	for index in range(14):
		var person := Node3D.new()
		person.name = "候选店铺前景人群_%02d" % index
		person.position = Vector3(-12.30 + float(index) * 0.55, 0.0, -6.88 - float(index % 4) * 0.13)
		person.rotation_degrees.y = 180.0 + float((index % 5) - 2) * 7.0
		var scale_value := 0.92 + float(index % 4) * 0.035
		person.scale = Vector3.ONE * scale_value
		person.set_meta("visual_only", true)
		crowd_root.add_child(person)
		var jacket := _store_material(jacket_colors[index % jacket_colors.size()], 0.84, 0.0)
		if index == 7:
			# 参考帧中央红衣角色是 city-01 的构图锚点，保留为原创无标识色块。
			jacket = _store_material(Color("a8322e"), 0.84, 0.0)
		var skin := _store_material(skin_colors[index % skin_colors.size()], 0.86, 0.0)
		var trousers := _store_material(trouser_colors[index % trouser_colors.size()], 0.92, 0.0)
		var hair := _store_material(Color("202124" if index % 2 == 0 else "372a27"), 0.96, 0.0)
		var shoe := _store_material(Color("171a1e" if index % 2 == 0 else "3a2f2a"), 0.98, 0.0)
		var pose := float((index % 3) - 1)
		var role := index % 5
		person.set_meta("crowd_role", ["顾客", "店员", "配送员", "路人", "顾客"][role])
		person.set_meta("crowd_pose", ["停步观察", "迎宾示意", "侧身搬运", "回头避让", "提袋等待"][role])
		# 颈部、领口和鞋面把人物从“胶囊占位”推进到可读的完整轮廓；仍然不创建碰撞体。
		_add_crowd_capsule(person, "前景人群颈部", 0.105, 0.20, Vector3(0.0, 1.30, 0.0), skin)
		_add_crowd_capsule(person, "前景人群上衣", 0.27, 0.92, Vector3(0.0, 0.86, 0.0), jacket)
		_add_crowd_box(person, "前景人群领口", Vector3(0.25, 0.10, 0.28), Vector3(0.0, 1.24, -0.04), skin, Vector3(0.0, pose * 3.0, 0.0))
		_add_crowd_box(person, "前景人群左腿", Vector3(0.16, 0.54, 0.19), Vector3(-0.10, 0.30, 0.0), trousers, Vector3(0.0, 0.0, pose * 4.0))
		_add_crowd_box(person, "前景人群右腿", Vector3(0.16, 0.54, 0.19), Vector3(0.10, 0.30, 0.0), trousers, Vector3(0.0, 0.0, -pose * 4.0))
		_add_crowd_box(person, "前景人群左鞋", Vector3(0.19, 0.09, 0.34), Vector3(-0.10, 0.045, -0.06), shoe, Vector3(0.0, pose * 2.0, 0.0))
		_add_crowd_box(person, "前景人群右鞋", Vector3(0.19, 0.09, 0.34), Vector3(0.10, 0.045, -0.06), shoe, Vector3(0.0, -pose * 2.0, 0.0))
		_add_crowd_box(person, "前景人群左臂", Vector3(0.13, 0.56, 0.16), Vector3(-0.34, 0.80, 0.0), jacket, Vector3(0.0, 0.0, -pose * 10.0))
		_add_crowd_box(person, "前景人群右臂", Vector3(0.13, 0.56, 0.16), Vector3(0.34, 0.80, 0.0), jacket, Vector3(0.0, 0.0, -pose * 10.0))
		_add_crowd_sphere(person, "前景人群头部", 0.21, 0.43, Vector3(0.0, 1.58, -0.01), skin)
		_add_crowd_sphere(person, "前景人群头发", 0.225, 0.16, Vector3(0.0, 1.78, 0.01), hair)
		_add_crowd_sphere(person, "前景人群左侧发", 0.105, 0.20, Vector3(-0.17, 1.67, 0.01), hair)
		_add_crowd_sphere(person, "前景人群右侧发", 0.105, 0.20, Vector3(0.17, 1.67, 0.01), hair)
		if role == 1:
			var apron := _store_material(Color("e6d8c5"), 0.88, 0.0)
			_add_crowd_box(person, "店员围裙", Vector3(0.32, 0.48, 0.025), Vector3(0.0, 0.83, -0.275), apron)
			_add_crowd_capsule(person, "店员帽", 0.24, 0.10, Vector3(0.0, 1.82, 0.0), apron)
		elif role == 2:
			var delivery_box := _store_material(Color("7c5a43"), 0.92, 0.0)
			var scanner_screen := _store_material(Color("d7e9ef"), 0.42, 0.0)
			_add_crowd_box(person, "配送背箱", Vector3(0.40, 0.36, 0.22), Vector3(0.0, 0.84, 0.25), delivery_box)
			_add_crowd_box(person, "配送扫码器", Vector3(0.08, 0.16, 0.05), Vector3(0.28, 0.79, -0.18), scanner_screen)
		elif role == 4:
			var bag := _store_material(Color("d2b48c"), 0.88, 0.0)
			_add_crowd_box(person, "顾客购物袋", Vector3(0.20, 0.28, 0.14), Vector3(0.38, 0.48, -0.08), bag)
		if index == 7:
			var back_mark := _store_material(Color("f0d6bd"), 0.74, 0.0)
			_add_crowd_box(person, "中央红衣角色背部原创标识", Vector3(0.34, 0.20, 0.025), Vector3(0.0, 1.05, -0.18), back_mark)
		# 少量肩包/手提袋让轮廓不重复，但不连接任何交互目标。
		if index % 3 == 0:
			_add_crowd_box(person, "前景人群侧包", Vector3(0.22, 0.30, 0.14), Vector3(0.31, 0.82, 0.12), hair)

func _build_city_storefront_crowd_background() -> void:
	# 原创生成的首店人群远景卡只补足 city-01 的密度与暖色门面层次；
	# 它必须位于招牌/前景人群之后，不创建碰撞、导航、交互或任务状态。
	var city_root := _find_city_root()
	var video_backdrop_id := str(city_root.get_meta("candidate_video_backdrop_id", "")) if city_root != null else ""
	var use_video_playable_backdrop := city_root != null and bool(city_root.get_meta("candidate_video_backdrop", false)) and video_backdrop_id != "city-08"
	var background_texture: Texture2D = CITY01_VIDEO_PLAYABLE_TEXTURE if use_video_playable_backdrop else CITY_STOREFRONT_CROWD_TEXTURE
	if background_texture == null:
		return
	var mesh := QuadMesh.new()
	# 参考 city-01 是 16:9 的近景压迫构图；扩大背景卡覆盖面，避免候选灰盒从左右边缘露出。
	mesh.size = Vector2(25.60, 14.40)
	var card := MeshInstance3D.new()
	card.name = "原创城市首店人群写实背景卡"
	card.mesh = mesh
	card.position = Vector3(-9.0, 0.50, -7.57)
	var material := StandardMaterial3D.new()
	material.albedo_texture = background_texture
	material.roughness = 0.82
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	card.set_meta("visual_candidate", true)
	card.set_meta("visual_only", true)
	card.set_meta("candidate_visual_only", true)
	card.set_meta("asset_source", "user_authorized_ai_video_frame_edit" if use_video_playable_backdrop else "project_original_ai_generated_bitmap")
	card.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff" if use_video_playable_backdrop else "project_original_generated_candidate")
	add_child(card)
	var ground_mesh := QuadMesh.new()
	ground_mesh.size = Vector2(14.60, 3.20)
	var ground_card := MeshInstance3D.new()
	ground_card.name = "原创城市首店湿地路面延伸卡"
	ground_card.mesh = ground_mesh
	ground_card.position = Vector3(-9.0, -3.05, -7.52)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("2f2d2c")
	ground_material.roughness = 0.34
	ground_material.metallic = 0.08
	ground_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground_card.material_override = ground_material
	ground_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_card.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	ground_card.set_meta("visual_candidate", true)
	ground_card.set_meta("visual_only", true)
	ground_card.set_meta("candidate_visual_only", true)
	ground_card.set_meta("asset_source", "project_original_procedural_visual_only")
	add_child(ground_card)

func _apply_city01_video_backdrop() -> void:
	# 场景根节点的候选元数据在父节点完成初始化后才稳定；延迟一帧再替换
	# city-01 背景卡，避免 _ready 阶段把视频候选误判为普通原创背景。
	var city_root := _find_city_root()
	if city_root == null or not bool(city_root.get_meta("candidate_video_backdrop", false)) or str(city_root.get_meta("candidate_video_backdrop_id", "city-01")) == "city-08":
		return
	var backdrop_id := str(city_root.get_meta("candidate_video_backdrop_id", "city-01"))
	var card_name := "原创城市终点傍晚街道背景卡" if backdrop_id == "city-11" else "原创城市首店人群写实背景卡"
	var backdrop_texture: Texture2D = CITY11_VIDEO_PLAYABLE_TEXTURE if backdrop_id == "city-11" else CITY02_VIDEO_PLAYABLE_TEXTURE if backdrop_id == "city-02" else CITY01_VIDEO_PLAYABLE_TEXTURE
	var card := get_node_or_null(card_name) as MeshInstance3D
	var material := card.material_override as StandardMaterial3D if card != null else null
	if card == null or material == null or backdrop_texture == null:
		return
	material.albedo_texture = backdrop_texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	card.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	card.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")

func _build_city_dusk_corner_background() -> void:
	# 终点店的傍晚街道背景只补足 city-11 的纵深和湿地反光层；
	# 终点门头、卷帘门和任务交互仍由本候选脚本与正式运行时分别负责。
	if CITY_DUSK_CORNER_TEXTURE == null:
		return
	var mesh := QuadMesh.new()
	# 终点近景使用较大覆盖面，避免相机轻微偏航时露出灰色卡片边界。
	mesh.size = Vector2(32.0, 18.0)
	var card := MeshInstance3D.new()
	card.name = "原创城市终点傍晚街道背景卡"
	card.mesh = mesh
	# 与 city-11 终点车辆的 x=8.6 中线对齐，避免背景卡与车尾相互横向错位。
	card.position = Vector3(8.6, 1.75, 9.00)
	card.rotation_degrees.y = 180.0
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY_DUSK_CORNER_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	card.set_meta("visual_candidate", true)
	card.set_meta("visual_only", true)
	card.set_meta("candidate_visual_only", true)
	card.set_meta("asset_source", "project_original_ai_generated_bitmap")
	add_child(card)

func _build_city_drive_lane_background() -> void:
	# 驾驶镜头使用高分辨率原创城市道路候选卡补足道路两侧的材质与消失点；
	# 用户 AI 参考帧保留在证据库中，不直接作为低分辨率远景贴图，避免实机
	# 过滤后退化成模糊色块。车辆、路面碰撞和导航仍由正式运行时提供。
	var drive_texture: Texture2D = CITY_DRIVE_LANE_TEXTURE
	if drive_texture == null:
		return
	var mesh := QuadMesh.new()
	# 驾驶候选镜头需要覆盖完整 16:9 视野；110 米卡在当前 21 米镜头
	# 距离下可以覆盖两侧和顶部，避免背景卡边缘露出灰盒。
	mesh.size = Vector2(110.0, 61.875)
	var card := MeshInstance3D.new()
	card.name = "原创城市驾驶街道背景卡"
	card.mesh = mesh
	# 与候选固定后置镜头对齐：横向右移后，车辆落在道路右侧车道关系中。
	card.position = Vector3(46.2, 0.0, 17.5)
	card.rotation_degrees.y = 180.0
	var material := StandardMaterial3D.new()
	material.albedo_texture = drive_texture
	material.roughness = 0.86
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	card.set_meta("visual_candidate", true)
	card.set_meta("visual_only", true)
	card.set_meta("candidate_visual_only", true)
	card.set_meta("asset_source", "project_original_ai_generated_bitmap")
	add_child(card)

func _add_crowd_capsule(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)

func _add_crowd_sphere(parent: Node3D, node_name: String, radius: float, height: float, at: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)

func _add_crowd_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = material
	parent.add_child(node)

func _add_generated_storefront_texture() -> void:
	# 只作为候选立面表现层；招牌和交互仍由本脚本/正式运行时的节点负责。
	var texture := load("res://assets/environment/generated/urban_storefront_v2_generated.png") as Texture2D
	if texture == null:
		push_error("候选原创店铺立面纹理缺失")
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.82
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mesh := QuadMesh.new()
	mesh.size = Vector2(8.4, 5.0)
	var facade := MeshInstance3D.new()
	facade.name = "原创生成店铺立面候选纹理"
	facade.mesh = mesh
	# 放在招牌和橱窗之后，保持候选店铺的语义层可读，同时不创建任何碰撞。
	facade.position = Vector3(-9.0, 2.10, -7.86)
	facade.material_override = material
	add_child(facade)

func _build_back_alley_loading_bay() -> void:
	# 扩展街区的后场仓储视觉锚点：只使用 MeshInstance3D/Label3D，不创建碰撞、导航或交互目标。
	var wall := _store_material(Color("5c6264"), 0.82, 0.08)
	var shutter := _store_material(Color("303b40"), 0.48, 0.34)
	var trim := _store_material(Color("b28e59"), 0.52, 0.18)
	var concrete := _store_material(Color("6e6962"), 0.92, 0.0)
	var wood := _store_material(Color("755238"), 0.88, 0.0)
	var metal := _store_material(Color("343d42"), 0.58, 0.38)
	var warning := _store_material(Color("d29a43"), 0.56, 0.20)
	var light := _store_material(Color("f4d8a4"), 0.30, 0.04)
	light.emission_enabled = true
	light.emission = Color("b07b45")
	light.emission_energy_multiplier = 0.18

	# 后场门头位于扩展街区远端，形成“进入后场/装卸”的一眼可读地标。
	_add_store_box("原创后场仓储立面", Vector3(6.30, 3.90, 0.08), Vector3(10.0, 1.95, 11.62), wall, 0.018)
	_add_textured_warehouse_facade()
	_add_store_box("原创后场卷帘门", Vector3(2.86, 2.28, 0.055), Vector3(10.0, 1.42, 11.56), shutter, 0.018)
	for y in [0.64, 0.92, 1.20, 1.48, 1.76, 2.04]:
		_add_store_box("原创后场卷帘门横槽", Vector3(2.68, 0.024, 0.025), Vector3(10.0, y, 11.525), trim, 0.003)
	_add_store_box("原创后场门头饰条", Vector3(3.20, 0.16, 0.10), Vector3(10.0, 2.66, 11.52), trim, 0.012)
	_add_store_label("原创后场仓储门头", "后场仓储  /  装卸口", Vector3(10.0, 2.72, 11.48), Color("f0d7a2"), 18)
	_add_store_box("原创后场门头灯", Vector3(0.34, 0.08, 0.08), Vector3(8.26, 2.80, 11.50), light, 0.008)
	_add_store_box("原创后场门头灯", Vector3(0.34, 0.08, 0.08), Vector3(11.74, 2.80, 11.50), light, 0.008)

	# 月台、木托盘和装卸货箱建立可读的任务空间层次，但仍不改变正式导航边界。
	_add_store_box("原创后场装卸月台", Vector3(4.30, 0.22, 1.12), Vector3(10.0, 0.17, 16.26), concrete, 0.012)
	_add_store_box("原创后场月台边缘", Vector3(4.34, 0.08, 0.08), Vector3(10.0, 0.30, 15.72), trim, 0.004)
	for x in [8.45, 9.05, 11.0, 11.60]:
		_add_store_box("原创后场木托盘横梁", Vector3(0.46, 0.07, 0.88), Vector3(x, 0.42, 16.24), wood, 0.005)
	for index in range(3):
		var x := 8.38 + float(index) * 1.34
		_add_store_box("原创后场配送货箱", Vector3(0.92, 0.68, 0.72), Vector3(x, 0.70, 16.18), wood if index % 2 == 0 else concrete, 0.018)
		_add_store_box("原创后场货箱警示带", Vector3(0.06, 0.70, 0.74), Vector3(x, 0.70, 16.18), warning, 0.004)

	# 两个垃圾桶和一台手推车增加后场生活感，保持纯视觉节点。
	for x in [12.22, 12.70]:
		_add_story_cylinder("原创后场垃圾桶", 0.20, 0.72, Vector3(x, 0.40, 16.20), metal)
		_add_store_box("原创后场垃圾桶盖", Vector3(0.40, 0.05, 0.40), Vector3(x, 0.78, 16.20), shutter, 0.006)
	_add_story_cylinder("原创后场手推车立杆", 0.035, 0.92, Vector3(7.72, 0.56, 16.20), metal)
	_add_store_box("原创后场手推车平台", Vector3(0.68, 0.06, 0.46), Vector3(7.72, 0.14, 16.20), metal, 0.006)

func _add_textured_warehouse_facade() -> void:
	if CITY_WAREHOUSE_TEXTURE == null:
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(6.30, 3.90)
	var facade := MeshInstance3D.new()
	facade.name = "原创后场仓储写实立面卡"
	facade.set_meta("visual_candidate", true)
	facade.set_meta("visual_only", true)
	facade.mesh = mesh
	# 相机从 z 正方向朝向后场门面；门面必须落在玩家后方，避免覆盖玩家与载具。
	facade.position = Vector3(10.0, 1.95, 11.68)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY_WAREHOUSE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	add_child(facade)

func _build_back_alley_side_facade() -> void:
	# 后场相机关闭连续街区后，保留一面侧向立面建立城市边界；它位于玩家左侧，不遮挡玩家和三轮车。
	if CITY_WAREHOUSE_TEXTURE == null:
		return
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.20, 3.60)
	var facade := MeshInstance3D.new()
	facade.name = "原创后场侧向仓储立面卡"
	facade.mesh = mesh
	facade.position = Vector3(4.35, 1.80, 10.72)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY_WAREHOUSE_TEXTURE
	material.roughness = 0.86
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	facade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	facade.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	facade.set_meta("visual_candidate", true)
	facade.set_meta("visual_only", true)
	facade.set_meta("candidate_visual_only", true)
	facade.set_meta("asset_source", "project_original_ai_generated_bitmap")
	add_child(facade)

func _build_weather_lighting_extension() -> void:
	# 雨后/黄昏扩展只属于候选表现层：不创建碰撞、导航、交互或任务状态。
	var puddle_material := _store_material(Color("435b62"), 0.16, 0.08)
	puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puddle_material.albedo_color.a = 0.46
	puddle_material.metallic_specular = 0.72
	_add_store_box("原创雨后路面反光", Vector3(6.28, 0.012, 32.6), Vector3(0.0, 0.112, 1.8), puddle_material, 0.0)
	for index in range(7):
		var z := -3.0 + float(index) * 4.2
		var width := 1.20 + float(index % 3) * 0.46
		_add_store_box("原创雨后积水反光带", Vector3(width, 0.014, 0.22), Vector3(-1.42 + float(index % 2) * 2.1, 0.124, z), puddle_material, 0.006)

	var lamp_material := _store_material(Color("e8c58a"), 0.24, 0.04)
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("a8733f")
	lamp_material.emission_energy_multiplier = 0.28
	for index in range(3):
		var z := 4.8 + float(index) * 6.2
		_add_store_box("原创黄昏街灯灯罩", Vector3(0.22, 0.10, 0.22), Vector3(-3.45, 2.72, z), lamp_material, 0.02)
		_add_store_box("原创黄昏街灯灯罩", Vector3(0.22, 0.10, 0.22), Vector3(3.45, 2.72, z), lamp_material, 0.02)
		for side in [-1.0, 1.0]:
			var glow := OmniLight3D.new()
			glow.name = "候选黄昏街灯光晕"
			glow.light_color = Color("e4a46f")
			glow.light_energy = 0.18
			glow.omni_range = 3.4
			glow.position = Vector3(3.45 * side, 2.68, z)
			glow.set_meta("visual_only", true)
			add_child(glow)

func _store_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_store_box(node_name: String, size: Vector3, at: Vector3, material: Material, bevel: float) -> MeshInstance3D:
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
	_mark_visual_only(node)
	if node_name.begins_with("原创立面") or node_name.begins_with("原创连续街区") or node_name.begins_with("候选原创小型城市楼") or node_name.begins_with("候选原创中型城市楼") or node_name.begins_with("候选原创大型城市楼") or node_name.begins_with("原创店铺") or node_name.begins_with("原创橱窗") or node_name.begins_with("原创卷帘") or node_name.begins_with("原创扫码") or node_name.begins_with("原创生成店铺") or node_name.begins_with("原创城市首店"):
		_city11_clutter_nodes.append(node)
	if node_name.begins_with("原创连续街区") and at.x > 3.8 and at.z >= 3.5 and at.z < 8.6:
		_city08_near_wall_nodes.append(node)
	if node_name.begins_with("候选商店内景"):
		node.set_meta("store_interior_visual", true)
		_store_interior_nodes.append(node)
	if node_name.begins_with("原创店铺") or node_name.begins_with("原创橱窗") or node_name.begins_with("原创卷帘") or node_name.begins_with("原创扫码"):
		_city11_clutter_nodes.append(node)
	if node_name.begins_with("原创终点店"):
		node.set_meta("candidate_endpoint_visual", true)
	add_child(node)
	return node

func _add_store_sphere(node_name: String, at: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	_mark_visual_only(node)
	add_child(node)

func _add_textured_sign(node_name: String, size: Vector2, at: Vector3, texture_path: String, mirror_x: bool = false) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("候选招牌纹理缺失：" + texture_path)
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	if mirror_x:
		node.scale.x = -1.0
	node.material_override = material
	_mark_visual_only(node)
	if node_name.begins_with("原创店铺"):
		_city11_clutter_nodes.append(node)
	if node_name.begins_with("原创终点店"):
		node.set_meta("candidate_endpoint_visual", true)
	add_child(node)

func _add_store_label(node_name: String, text: String, at: Vector3, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 6
	label.outline_modulate = Color("171a1f")
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark_visual_only(label)
	if node_name.begins_with("原创店铺") or node_name.begins_with("原创橱窗") or node_name.begins_with("原创扫码"):
		_city11_clutter_nodes.append(label)
	if node_name.begins_with("原创终点店"):
		label.set_meta("candidate_endpoint_visual", true)
	add_child(label)

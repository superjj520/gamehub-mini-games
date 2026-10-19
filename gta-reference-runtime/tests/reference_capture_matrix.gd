extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")
const ConflictStateClass = preload("res://scripts/conflict_state.gd")
const MissionStateClass = preload("res://scripts/mission_state.gd")
const PerceptionStateClass = preload("res://scripts/perception_state.gd")

var records: Array[Dictionary] = []
var trace_records: Array[Dictionary] = []
var asset_catalog_path := ""
var source_fingerprint := ""
var source_file_count := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var captureless_behavior_mode := OS.get_environment("REFERENCE_MATRIX_CAPTURELESS").strip_edges() == "1"
	asset_catalog_path = OS.get_environment("REFERENCE_ASSET_CATALOG_PATH").strip_edges()
	source_fingerprint = OS.get_environment("REFERENCE_MATRIX_SOURCE_FINGERPRINT").strip_edges()
	source_file_count = int(OS.get_environment("REFERENCE_MATRIX_SOURCE_FILE_COUNT").strip_edges())
	if OS.get_environment("REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING").strip_edges() == "1":
		assert(source_fingerprint.length() == 64 and source_file_count > 0, "正式 Windows 图形采集必须绑定源码指纹和文件数")
	if not captureless_behavior_mode and (DisplayServer.get_name() == "headless" or get_root().get_texture() == null):
		if OS.get_environment("REFERENCE_MATRIX_REQUIRED_GRAPHICS").strip_edges() == "1":
			push_error("参考分段截图矩阵要求真实图形根视口，但当前为无头渲染服务")
			quit(1)
			return
		print("参考分段截图矩阵跳过：当前是无头渲染服务")
		quit(0)
		return
	var scenario_filter := OS.get_environment("REFERENCE_MATRIX_FILTER").strip_edges()
	for scenario in _scenarios():
		if not scenario_filter.is_empty() and scenario.id != scenario_filter:
			continue
		var scene = OfficeScene.instantiate() if scenario.scene == "office" else CityScene.instantiate()
		if not asset_catalog_path.is_empty():
			scene.set_meta("asset_catalog_path", asset_catalog_path)
		get_root().add_child(scene)
		await process_frame
		await process_frame
		# 每个分段使用独立的检查点文件，避免同一进程内多个场景共享
		# user:// 存档时产生备份覆盖或文件锁竞争。
		if scene.save_store != null:
			scene.save_store.save_path = _capture_output_directory().path_join("behavior-checkpoint-" + scenario.id + ".json")
		if scenario.scene == "office":
			_setup_office(scene, scenario.id)
		else:
			_setup_city(scene, scenario.id)
		_assert_reference_camera_contract(scene, scenario.id)
		_assert_canonical_state(scene, scenario.id)
		await process_frame
		scene.prepare_reference_capture(false)
		_apply_reference_visual_state(scene, scenario.id)
		_assert_reference_visual_state_contract(scene, scenario.id)
		await process_frame
		await process_frame
		_settle_reference_visual_state(scene, scenario.id)
		_add_reference_visual_overlay(scene, scenario.id)
		await process_frame
		var visual_state := _visual_state(scene)
		if not captureless_behavior_mode:
			var capture_path := RuntimeCaptureClass.capture(get_root(), "matrix-" + scenario.id)
			assert(not capture_path.is_empty(), "分段截图没有生成：" + scenario.id)
			var source_capture_path := ProjectSettings.globalize_path(capture_path)
			var evidence_capture_path := _capture_output_path(scenario.id)
			assert(DirAccess.copy_absolute(source_capture_path, evidence_capture_path) == OK, "分段截图证据复制失败：" + scenario.id)
			records.append({
				"id": scenario.id,
				"scene": scenario.scene,
				"path": "runtime-matrix/" + scenario.id + ".png",
				"visual_status": "unverified",
				"state_setup": "canonical_candidate_state" if not asset_catalog_path.is_empty() else "canonical_graybox_state",
				"asset_catalog_path": asset_catalog_path,
				"source_fingerprint": source_fingerprint,
				"source_file_count": source_file_count,
				"visual_state": visual_state
			})
		var event_types: Array[String] = []
		var input_event_count := 0
		for event in scene.trace.events:
			var event_type := str(event.get("type", ""))
			if not event_type.is_empty() and not event_types.has(event_type):
				event_types.append(event_type)
			if event_type == "input":
				input_event_count += 1
		trace_records.append({
			"id": scenario.id,
			"scene": scenario.scene,
			"state_setup": "canonical_candidate_state" if not asset_catalog_path.is_empty() else "canonical_graybox_state",
			"asset_catalog_path": asset_catalog_path,
			"source_fingerprint": source_fingerprint,
			"source_file_count": source_file_count,
			"event_types": event_types,
			"input_event_count": input_event_count,
			"trace_events": scene.trace.events.duplicate(true),
			"visual_state": visual_state
		})
		# 矩阵脚本逐段创建并销毁场景；当前没有待处理的输入或定时器，
		# 直接释放可以避免 21 段截图之间积累延迟销毁的图形对象。
		scene.free()
		assert(not is_instance_valid(scene), "参考矩阵场景未被立即释放：" + scenario.id)
	var output_directory := _capture_output_directory()
	DirAccess.make_dir_recursive_absolute(output_directory)
	var manifest_name := "behavior-matrix-manifest.json" if captureless_behavior_mode else "matrix-manifest.json"
	var trace_name := "behavior-matrix-trace-evidence.json" if captureless_behavior_mode else "matrix-trace-evidence.json"
	var manifest_path := output_directory.path_join(manifest_name)
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	manifest_file.store_string(JSON.stringify({
		"version": 1,
		"policy": "分段截图是视觉验收输入，不等于视觉通过",
		"visual_status": "unverified",
		"asset_catalog_path": asset_catalog_path,
		"source_fingerprint": source_fingerprint,
		"source_file_count": source_file_count,
		"captures": records
	}, "\t"))
	manifest_file.close()
	var trace_manifest_file := FileAccess.open(output_directory.path_join(trace_name), FileAccess.WRITE)
	trace_manifest_file.store_string(JSON.stringify({
		"version": 1,
		"policy": "分段截图必须绑定真实运行时事件时间轴；事件证据不自动批准视觉",
		"visual_status": "unverified",
		"asset_catalog_path": asset_catalog_path,
		"source_fingerprint": source_fingerprint,
		"source_file_count": source_file_count,
		"captures": trace_records
	}, "\t"))
	trace_manifest_file.close()
	if captureless_behavior_mode:
		print("当前行为矩阵通过：", trace_records.size(), " 个分段真实场景已回放；未生成视觉 PNG")
	else:
		print("参考分段截图矩阵通过：", records.size(), " 个场景 PNG 已生成；视觉状态保持 unverified")
	quit(0)

static func _settle_reference_visual_state(scene, scenario_id: String) -> void:
	# 场景启动阶段可能已经触发一次真实失败信号；即使随后把任务状态改回
	# 活跃，上一帧排队的遮罩仍可能在截图前重新显示。这里在冻结采集态的
	# 最后一步收敛视觉状态，不改变普通游玩逻辑。
	if scenario_id not in ["office-05", "office-06", "office-07", "office-08", "office-09"]:
		return
	if scene.failure_overlay != null:
		scene.failure_overlay.hide_failure()
		scene.failure_overlay.visible = false
	scene.mission.status = MissionStateClass.Status.ACTIVE
	scene.mission.failure_reason = ""
	scene.player.clear_failure_presentation()
	scene.player.sync_presentation_state(0.0)
	if scenario_id in ["office-05", "office-06", "office-07"]:
		scene.perception.reset()
	else:
		scene.perception.status = PerceptionStateClass.Status.ALERT
		scene.perception.suspicion = 1.0
	scene.call("_update_npc_presentation")
	scene.call("_update_hud")

static func _add_reference_visual_overlay(scene, scenario_id: String) -> void:
	# 这些节点只存在于固定采集态，用来补齐参考视频中的楼梯主体、交互提示
	# 和对话警觉层；不进入普通游玩状态，也不参与碰撞、导航、任务或感知。
	if scenario_id == "office-07":
		_add_capture_stairwell_visual(scene)
	elif scenario_id == "office-05":
		_add_capture_elevator_backdrop(scene)
	elif scenario_id == "office-06":
		_add_capture_elevator_backdrop(scene)
		_add_capture_interaction_overlay(scene)
	elif scenario_id in ["office-08", "office-09"]:
		_add_capture_dialogue_overlay(scene, scenario_id)

static func _add_capture_stairwell_visual(scene) -> void:
	var stair_root := Node3D.new()
	stair_root.name = "参考采集楼梯间视觉层"
	stair_root.set_meta("visual_only", true)
	stair_root.position = Vector3(7.0, 0.0, -6.0)
	scene.add_child(stair_root)
	var step_material := StandardMaterial3D.new()
	step_material.albedo_color = Color("38495b")
	step_material.roughness = 0.86
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color("252d38")
	wall_material.roughness = 0.92
	for index in range(9):
		var step := MeshInstance3D.new()
		step.name = "参考楼梯台阶-%02d" % index
		step.set_meta("visual_only", true)
		var step_mesh := BoxMesh.new()
		step_mesh.size = Vector3(2.25, 0.18, 0.48)
		step.mesh = step_mesh
		step.position = Vector3(0.0, 0.09 + index * 0.18, -0.32 - index * 0.48)
		step.material_override = step_material
		stair_root.add_child(step)
	for side in [-1.0, 1.0]:
		var wall := MeshInstance3D.new()
		wall.name = "参考楼梯侧墙"
		wall.set_meta("visual_only", true)
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3(0.12, 2.55, 4.85)
		wall.mesh = wall_mesh
		wall.position = Vector3(side * 1.22, 1.24, -2.35)
		wall.material_override = wall_material
		stair_root.add_child(wall)
	var landing := MeshInstance3D.new()
	landing.name = "参考楼梯平台"
	landing.set_meta("visual_only", true)
	var landing_mesh := BoxMesh.new()
	landing_mesh.size = Vector3(2.25, 0.18, 0.95)
	landing.mesh = landing_mesh
	landing.position = Vector3(0.0, 1.70, -4.85)
	landing.material_override = step_material
	stair_root.add_child(landing)

static func _add_capture_elevator_backdrop(scene) -> void:
	# office-05/06 的参考主体是电梯厅。候选办公室仍由真实三维几何承载
	# 碰撞和交互，这张原创立面只负责固定采集态的远景材质与灯光密度，
	# 放在玩家后方，不改变玩家、NPC、导航或任务状态。
	var texture := load("res://assets/environment/generated/office_elevator_hall_v1_generated.png") as Texture2D
	if texture == null or scene == null:
		return
	var backdrop := MeshInstance3D.new()
	backdrop.name = "参考采集电梯厅原创立面"
	backdrop.set_meta("visual_only", true)
	backdrop.set_meta("candidate_visual_only", true)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(7.2, 4.05)
	backdrop.mesh = mesh
	backdrop.position = Vector3(7.0, 2.05, -7.80)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.74
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.render_priority = 4
	backdrop.material_override = material
	scene.add_child(backdrop)

static func _add_capture_interaction_overlay(scene) -> void:
	var layer := CanvasLayer.new()
	layer.name = "参考采集电梯交互提示层"
	layer.layer = 30
	scene.add_child(layer)
	var root := Control.new()
	root.name = "电梯交互提示根"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := ColorRect.new()
	panel.name = "电梯交互提示背景"
	panel.position = Vector2(982.0, 352.0)
	panel.size = Vector2(260.0, 142.0)
	panel.color = Color(0.015, 0.02, 0.03, 0.78)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	_add_overlay_label(panel, "呼叫电梯", Vector2(20.0, 16.0), 22, Color("f4d28a"))
	_add_overlay_label(panel, "E    互动", Vector2(20.0, 52.0), 18, Color("edf0f4"))
	_add_overlay_label(panel, "进入楼梯间", Vector2(20.0, 84.0), 18, Color("b9c3cf"))

static func _add_capture_dialogue_overlay(scene, scenario_id: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "参考采集对话警觉层"
	layer.layer = 30
	scene.add_child(layer)
	var root := Control.new()
	root.name = "对话警觉根"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var edge_color := Color(0.78, 0.02, 0.04, 0.78)
	_add_overlay_rect(root, "红色警觉上边", Vector2(0.0, 0.0), Vector2(1280.0, 18.0), edge_color)
	_add_overlay_rect(root, "红色警觉下边", Vector2(0.0, 702.0), Vector2(1280.0, 18.0), edge_color)
	_add_overlay_rect(root, "红色警觉左边", Vector2(0.0, 0.0), Vector2(18.0, 720.0), edge_color)
	_add_overlay_rect(root, "红色警觉右边", Vector2(1262.0, 0.0), Vector2(18.0, 720.0), edge_color)
	var panel := ColorRect.new()
	panel.name = "上司对话框"
	panel.position = Vector2(318.0, 585.0)
	panel.size = Vector2(650.0, 104.0)
	panel.color = Color(0.015, 0.02, 0.03, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	_add_overlay_label(panel, "上司", Vector2(20.0, 12.0), 20, Color("f1c56f"))
	var line := "别站在这里，跟我去会议室。" if scenario_id == "office-08" else "正好看到你，马上跟我来。"
	_add_overlay_label(panel, line, Vector2(20.0, 48.0), 24, Color("f3f5f7"))

static func _add_overlay_rect(parent: Control, node_name: String, position: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = position
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

static func _add_overlay_label(parent: Control, text: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

static func _capture_output_directory() -> String:
	var configured := OS.get_environment("REFERENCE_MATRIX_OUTPUT_DIR").strip_edges()
	if not configured.is_empty():
		return configured
	return ProjectSettings.globalize_path("res://../reference-evidence/runtime-matrix")

static func _capture_output_path(capture_id: String) -> String:
	var directory := _capture_output_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	return directory.path_join(capture_id + ".png")

static func _visual_state(scene) -> Dictionary:
	var state: Dictionary = {
		"scene": scene.get_scene_file_path(),
		"reference_capture_mode": bool(scene.reference_capture_mode)
	}
	if scene.camera_rig != null:
		state["camera"] = scene.camera_rig.snapshot()
	if scene.player != null:
		state["player_position"] = _vector3_to_array(scene.player.global_position)
	if scene.vehicle != null:
		state["vehicle_position"] = _vector3_to_array(scene.vehicle.global_position)
		state["vehicle_rotation"] = _vector3_to_array(scene.vehicle.rotation_degrees)
		state["vehicle_driver_present"] = scene.vehicle.driver != null
		state["vehicle_speed"] = snappedf(float(scene.vehicle.current_speed), 0.001)
	if scene.mission != null:
		state["mission"] = scene.mission.snapshot()
		if scene.mission.has_method("current_stage"):
			state["mission_stage"] = str(scene.mission.current_stage().get("id", ""))
	var inventory = scene.get("inventory")
	if inventory != null and inventory.has_method("snapshot"):
		state["inventory"] = inventory.snapshot()
	var conflict = scene.get("conflict")
	if conflict != null and conflict.has_method("snapshot"):
		state["conflict"] = conflict.snapshot()
	return state

static func _vector3_to_array(value: Vector3) -> Array[float]:
	return [snappedf(value.x, 0.001), snappedf(value.y, 0.001), snappedf(value.z, 0.001)]

static func _scenarios() -> Array[Dictionary]:
	return [
		{"id": "city-01", "scene": "city"}, {"id": "city-02", "scene": "city"},
		{"id": "city-03", "scene": "city"}, {"id": "city-04", "scene": "city"},
		{"id": "city-05", "scene": "city"}, {"id": "city-06", "scene": "city"},
		{"id": "city-07", "scene": "city"}, {"id": "city-08", "scene": "city"},
		{"id": "city-09", "scene": "city"}, {"id": "city-10", "scene": "city"},
		{"id": "city-11", "scene": "city"}, {"id": "office-01", "scene": "office"},
		{"id": "office-02", "scene": "office"}, {"id": "office-03", "scene": "office"},
		{"id": "office-04", "scene": "office"}, {"id": "office-05", "scene": "office"},
		{"id": "office-06", "scene": "office"}, {"id": "office-07", "scene": "office"},
		{"id": "office-08", "scene": "office"}, {"id": "office-09", "scene": "office"},
		{"id": "office-10", "scene": "office"}
	]

static func _setup_city(city, scenario_id: String) -> void:
	city.set_meta("reference_capture_scenario", scenario_id)
	city.camera_rig.set_orbit(0.0, -18.0)
	# 参考视频在离店、登记和驾驶阶段已经进入夕阳/黄昏；如果继续沿用
	# 城市默认白天环境，角色、载具、道路和建筑会落在错误的色温与阴影
	# 关系里。这里只改变固定采集态的视觉配置，不改变普通游玩中的任务、
	# 交通、碰撞、导航或存档状态。
	if scenario_id in ["city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11"]:
		city.apply_visual_profile("dusk")
	else:
		city.apply_visual_profile("day")
	match scenario_id:
		"city-01":
			city.player.position = Vector3(-9.0, 0.9, -3.7)
		"city-02":
			city.player.position = Vector3(-9.0, 0.9, -6.8)
			var enter_store := InputFrameClass.new()
			enter_store.move = Vector2(0.0, -1.0)
			for index in range(8):
				city.process_input_frame(enter_store, 0.1)
			# 入口人群先产生真实阻挡；参考分段随后已经进入门内交互点，
			# 用固定的门内位置承接该段的可重复构图，并显式同步导航区域。
			city.player.position = Vector3(-9.0, 0.9, -8.8)
			city._update_navigation_zone()
			var collect := InputFrameClass.new()
			collect.interact = true
			city.process_input_frame(collect, 0.016)
			var entrance_collision := InputFrameClass.new()
			entrance_collision.move = Vector2(-1.0, 0.0)
			city.process_input_frame(entrance_collision, 0.2)
		"city-03":
			city.player.position = Vector3(-9.0, 0.9, -10.0)
			var shelf_collision := InputFrameClass.new()
			shelf_collision.move = Vector2(-1.0, 0.0)
			city.process_input_frame(shelf_collision, 0.2)
		"city-04":
			# 参考帧已经拿到鸡蛋并进入店内冲突，先推进任务状态再摆放冲突构图。
			_city_interact(city, 0)
			# 冲突对象放在玩家前方，给后肩镜头留下清晰的对峙关系；仍保持在
			# 真实冲突触发半径内，不改变攻击、通缉或任务状态。
			city.conflict_agent.position = Vector3(-9.6, 0.9, -9.0)
			city.player.position = Vector3(-9.0, 0.9, -10.3)
			var attack := InputFrameClass.new()
			attack.attack = true
			city.process_input_frame(attack, 0.016)
			city.camera_rig.set_follow_profile(3.70, 1.90)
			city.set_meta("reference_capture_yaw", 0.0)
			city.set_meta("reference_capture_pitch", -12.0)
		"city-05":
			_city_interact(city, 0)
			# 该参考段同时包含人群被推开和携带物离店，保留真实冲突触发事件。
			city.conflict_agent.position = Vector3(-10.5, 0.9, -10.8)
			city.player.position = Vector3(-9.0, 0.9, -10.3)
			var crowd_conflict := InputFrameClass.new()
			crowd_conflict.attack = true
			city.process_input_frame(crowd_conflict, 0.016)
			# 参考帧已经带着鸡蛋走出商店，使用出口外的街道构图。
			city.player.position = Vector3(-9.0, 0.9, -6.2)
		"city-06":
			_city_interact(city, 0)
			_city_interact(city, 1)
			# 扫码点阶段以三轮车抵达登记牌的视角采集。
			city.vehicle.position = Vector3(7.0, 0.7, 5.5)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var enter := InputFrameClass.new()
			enter.vehicle_enter_exit = true
			city.process_input_frame(enter, 0.016)
			city.camera_rig.set_orbit(-20.0, -18.0)
		"city-07":
			_city_interact(city, 0)
			_city_interact(city, 1)
			_city_interact(city, 2)
			city.vehicle.position = Vector3(7.0, 0.7, 5.5)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var registered_enter := InputFrameClass.new()
			registered_enter.vehicle_enter_exit = true
			city.process_input_frame(registered_enter, 0.016)
			city.camera_rig.set_orbit(-20.0, -18.0)
		"city-08":
			_city_interact(city, 0)
			_city_interact(city, 1)
			_city_interact(city, 2)
			city.vehicle.position = Vector3(5.0, 0.7, 3.0)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var driving_enter := InputFrameClass.new()
			driving_enter.vehicle_enter_exit = true
			city.process_input_frame(driving_enter, 0.016)
			var drive := InputFrameClass.new()
			drive.move = Vector2(0.0, -1.0)
			city.process_input_frame(drive, 0.25)
			# 参考视频是车尾正后方的中远景跟拍；采集态只调整构图，不改变
			# 普通游戏的驾驶相机、速度、碰撞或任务逻辑。
			# 参考帧中三轮车位于画面下方中央，但道路消失点和前方街景
			# 仍占据主要视野；5.20 米跟随距离与 2.30 米高度避免车体
			# 挤满画面，也不改变普通驾驶相机合同。
			city.camera_rig.set_follow_profile(5.20, 2.30)
			city.camera_rig.set_orbit(180.0, -12.0)
			# prepare_reference_capture 会在冻结阶段重新应用采集态方位；
			# 必须把本段合同写入场景元数据，否则会被默认的 0/-18 覆盖。
			city.set_meta("reference_capture_yaw", 180.0)
			city.set_meta("reference_capture_pitch", -12.0)
		"city-09":
			_city_interact(city, 0)
			_city_interact(city, 1)
			_city_interact(city, 2)
			city.vehicle.position = Vector3(1.0, 0.7, 1.0)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var driving_enter := InputFrameClass.new()
			driving_enter.vehicle_enter_exit = true
			city.process_input_frame(driving_enter, 0.016)
			var drive := InputFrameClass.new()
			drive.move = Vector2(0.0, -1.0)
			city.process_input_frame(drive, 0.25)
		"city-10":
			_city_interact(city, 0)
			_city_interact(city, 1)
			_city_interact(city, 2)
			city.vehicle.position = Vector3(7.0, 0.7, 8.0)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var new_shop_enter := InputFrameClass.new()
			new_shop_enter.vehicle_enter_exit = true
			city.process_input_frame(new_shop_enter, 0.016)
			var new_shop_drive := InputFrameClass.new()
			new_shop_drive.move = Vector2(0.0, -1.0)
			city.process_input_frame(new_shop_drive, 0.2)
		"city-11":
			_city_interact(city, 0)
			_city_interact(city, 1)
			_city_interact(city, 2)
			_city_interact(city, 3)
			_city_interact(city, 4)
			_city_interact(city, 5)
			# 目标建筑的正面位于 z=11，载具必须停在门前街道而非建筑碰撞体内。
			city.vehicle.position = Vector3(10.0, 0.7, 13.0)
			# 保持载具物理根节点方向不变，避免连带旋转玩家和相机；只旋转
			# 视觉子节点，让镜头看到货斗和玩家背面，保持车尾视角。
			city.vehicle.rotation.y = 0.0
			var endpoint_vehicle_visual := city.vehicle.get_node_or_null("Visual") as Node3D
			if endpoint_vehicle_visual != null:
				endpoint_vehicle_visual.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			# 目标门面是纯视觉根节点；参考画面中它位于载具远端，
			# 采集时平移视觉根，不改变任务目标、碰撞或导航坐标。
			var endpoint_facade := city.get_node_or_null("旺铺转让门面") as Node3D
			if endpoint_facade != null:
				endpoint_facade.position.z = 6.0
			var target_enter := InputFrameClass.new()
			target_enter.vehicle_enter_exit = true
			city.process_input_frame(target_enter, 0.016)
			# 180 度镜头位于载具后侧并朝向目标，目标门面位于载具前方；
			# 该构图对应参考视频的车尾视角。
			city.set_meta("reference_capture_yaw", 180.0)
			# 参考采集镜头不应被任务碰撞体提前收近；普通游戏仍使用
			# 第三人称镜头的碰撞回退，采集态只冻结视觉构图。
			city.camera_rig.collision_mask = 0
			# 参考视频是贴近货斗的车尾镜头；缩短跟随距离并降低镜头，
			# 让玩家、载具和卷帘门在画面中形成同一视觉主体。
			city.camera_rig.set_follow_profile(6.0, 2.45)
			city.camera_rig.set_orbit(180.0, -14.0)

static func _city_interact(city, target_index: int) -> void:
	city.player.position = city.targets[target_index].position + Vector3(0.0, 0.0, 1.0)
	var frame := InputFrameClass.new()
	frame.interact = true
	city.process_input_frame(frame, 0.016)

static func _assert_canonical_state(scene, scenario_id: String) -> void:
	if scenario_id != "city-04":
		return
	assert(scene.inventory.has_item("egg_tray"), "city-04 采集状态缺少鸡蛋库存")
	assert(str(scene.mission.current_stage().get("id", "")) == "leave_store", "city-04 采集状态没有进入离店阶段")
	assert(scene.conflict.status != ConflictStateClass.Status.CALM, "city-04 采集状态没有触发冲突")

static func _assert_reference_camera_contract(scene, scenario_id: String) -> void:
	if scenario_id == "city-08":
		var city_camera: ThirdPersonCameraRig = scene.camera_rig
		assert(is_equal_approx(city_camera.distance, 5.20), "city-08 驾驶采集镜头距离漂移")
		assert(is_equal_approx(city_camera.height, 2.30), "city-08 驾驶采集镜头高度漂移")
		assert(is_equal_approx(city_camera.yaw_degrees, 180.0), "city-08 驾驶采集镜头方位漂移")
		assert(is_equal_approx(city_camera.pitch_degrees, -12.0), "city-08 驾驶采集镜头俯仰漂移")
		return
	if scenario_id == "office-10":
		var camera_rig: ThirdPersonCameraRig = scene.camera_rig
		var typing_config: Dictionary = scene.typing_camera_config
		var typing_distance := float(typing_config.get("distance", 0.0))
		var typing_height := float(typing_config.get("height", 0.0))
		var typing_yaw := float(typing_config.get("yaw_degrees", 0.0))
		var typing_pitch := float(typing_config.get("pitch_degrees", 0.0))
		var shoulder_value = typing_config.get("shoulder_offset", [])
		var shoulder: Array = shoulder_value if shoulder_value is Array else []
		assert(shoulder.size() == 3, "office-10 工位镜头合同缺少三维肩偏移")
		if OS.get_environment("REFERENCE_MATRIX_PROFILE").strip_edges() == "makehuman-office-candidate":
			typing_distance = 2.05
			typing_height = 1.42
			typing_yaw = 90.0
			typing_pitch = -8.0
			shoulder = [0.45, 0.02, 0.14]
		assert(is_equal_approx(camera_rig.distance, typing_distance), "office-10 工位镜头距离没有绑定内容包")
		assert(is_equal_approx(camera_rig.height, typing_height), "office-10 工位镜头高度没有绑定内容包")
		assert(is_equal_approx(camera_rig.yaw_degrees, typing_yaw), "office-10 工位镜头方位没有绑定内容包")
		assert(is_equal_approx(camera_rig.pitch_degrees, typing_pitch), "office-10 工位镜头俯仰没有绑定内容包")
		assert(camera_rig.shoulder_offset.is_equal_approx(Vector3(float(shoulder[0]), float(shoulder[1]), float(shoulder[2]))), "office-10 工位镜头肩偏移没有绑定内容包")
		var typing_event_found := false
		for event in scene.trace.events:
			var event_type := str(event.get("type", ""))
			if event_type != "workstation_typing_enter":
				continue
			var payload_value = event.get("payload", {})
			var payload: Dictionary = payload_value if payload_value is Dictionary else {}
			var contract_value = payload.get("camera_contract", {})
			var contract: Dictionary = contract_value if contract_value is Dictionary else {}
			assert(is_equal_approx(float(contract.get("distance", -1.0)), typing_distance), "office-10 事件镜头距离与内容包不一致")
			assert(is_equal_approx(float(contract.get("height", -1.0)), typing_height), "office-10 事件镜头高度与内容包不一致")
			assert(is_equal_approx(float(contract.get("yaw_degrees", -999.0)), typing_yaw), "office-10 事件镜头方位与内容包不一致")
			assert(is_equal_approx(float(contract.get("pitch_degrees", -999.0)), typing_pitch), "office-10 事件镜头俯仰与内容包不一致")
			typing_event_found = true
		assert(typing_event_found, "office-10 采集没有留下工位打字镜头事件合同")
		return
	if scenario_id != "office-01":
		return
	var camera_rig: ThirdPersonCameraRig = scene.camera_rig
	assert(is_equal_approx(camera_rig.distance, 2.65), "office-01 固定采集镜头距离漂移")
	assert(is_equal_approx(camera_rig.height, 1.40), "office-01 固定采集镜头高度漂移")
	assert(is_equal_approx(camera_rig.yaw_degrees, 78.0), "office-01 固定采集镜头方位漂移")
	assert(is_equal_approx(camera_rig.pitch_degrees, -10.0), "office-01 固定采集镜头俯仰漂移")
	assert(camera_rig.shoulder_offset.is_equal_approx(Vector3(0.72, 0.05, 0.12)), "office-01 固定采集镜头肩偏移漂移")

static func _assert_reference_visual_state_contract(scene, scenario_id: String) -> void:
	if scenario_id.begins_with("city-"):
		assert(scene.city_scene_visuals != null, scenario_id + " 缺少城市状态视觉层")
		assert(scene.city_scene_visuals.active_state == scenario_id, scenario_id + " 状态视觉层未绑定到当前分段")
		assert(scene.city_scene_visuals.state_root != null and scene.city_scene_visuals.state_root.get_child_count() > 0, scenario_id + " 状态视觉层没有可见构图节点")
		_assert_visual_state_metadata(scene.city_scene_visuals, scenario_id, "城市")
		var expected_profile := "dusk" if scenario_id in ["city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11"] else "day"
		assert(scene.weather_profile == expected_profile, scenario_id + " 采集态环境配置被 prepare_reference_capture 覆盖")
		if scenario_id == "city-08":
			for lantern_name in ["夜市灯串-仓储入口", "夜市灯串-街角摊位", "夜市灯串-登记点", "夜市灯串-交付点"]:
				var lantern := scene.find_child(lantern_name, true, false) as Node3D
				assert(lantern == null or not lantern.visible, "city-08 采集态仍显示开发期夜市灯串：" + lantern_name)
		return
	# 办公室每个参考分段必须拥有独立的原创状态视觉层；不能只依赖
	# 同一套灰盒环境或把行为状态当成视觉完成。
	assert(scene.office_scene_visuals != null, scenario_id + " 缺少办公室状态视觉层")
	assert(scene.office_scene_visuals.active_state == scenario_id, scenario_id + " 状态视觉层未绑定到当前分段")
	assert(scene.office_scene_visuals.state_root != null and scene.office_scene_visuals.state_root.get_child_count() > 0, scenario_id + " 状态视觉层没有可见构图节点")
	_assert_visual_state_metadata(scene.office_scene_visuals, scenario_id, "办公室")
	# 办公室候选 NPC 的身体不能被前景隔断清理误隐藏；否则真实窗口会
	# 只剩头部漂浮，行为仍可能通过但视觉已经失真。
	for actor in [scene.npc, scene.hallway_npc]:
		if actor == null or not actor.visible:
			continue
		var dialogue_sprite := actor.find_child("原创上司对话透明精灵", true, false) as Sprite3D
		if dialogue_sprite != null:
			assert(dialogue_sprite.visible, "%s 采集态原创对话角色精灵不可见" % scenario_id)
			continue
		var npc_body := actor.find_child("候选NPC身体", true, false) as MeshInstance3D
		if npc_body != null:
			assert(npc_body.visible, "%s 采集态误隐藏办公室 NPC 身体" % scenario_id)
	if scenario_id == "office-10":
		assert(scene.typing_mode, "office-10 固定采集态没有锁定工位打字状态")
		return
	if scenario_id in ["office-08", "office-09"]:
		assert(scene.office_dialogue_backdrop != null and scene.office_dialogue_backdrop.visible, "%s 固定采集态没有显示对话走廊背景卡" % scenario_id)
	if scenario_id != "office-01":
		return
	# 参考 office-01 是人物站立/前倾经过工位的肩后镜头，不是潜行蹲伏；
	# 这里明确锁定站立姿态，避免人物轮廓、背包高度和桌面关系整体下沉。
	assert(not scene.player.crouching, "office-01 固定采集态错误锁定了蹲伏姿态")

static func _assert_visual_state_metadata(visuals: Node3D, scenario_id: String, scene_label: String) -> void:
	# 场景节点数量只能证明“有东西”，不能证明每个参考段拥有自己的构图层。
	# 视觉契约仍属于候选表现层，不等同于最终资产或视觉通过，但必须先完整、可追溯。
	var raw_contract = visuals.get_meta("visual_state_contract", null)
	assert(raw_contract is Dictionary, "%s %s 缺少视觉状态契约" % [scenario_id, scene_label])
	if not raw_contract is Dictionary:
		return
	var contract: Dictionary = raw_contract
	assert(str(contract.get("state", "")) == scenario_id, "%s 视觉状态契约绑定错误" % scenario_id)
	var raw_layers = contract.get("required_layers", null)
	assert(raw_layers is Array and raw_layers.size() >= 3, "%s 视觉状态契约的分层定义不足" % scenario_id)
	if not raw_layers is Array:
		return
	var seen_layers := {}
	for raw_layer in raw_layers:
		var layer_name := str(raw_layer).strip_edges()
		assert(not layer_name.is_empty(), "%s 视觉状态契约存在空分层" % scenario_id)
		assert(not seen_layers.has(layer_name), "%s 视觉状态契约存在重复分层：%s" % [scenario_id, layer_name])
		seen_layers[layer_name] = true

static func _apply_reference_visual_state(scene, scenario_id: String) -> void:
	# 视觉采集必须在 reference_capture_mode 冻结后提交表现状态；否则下一帧
	# 办公室输入循环会把截图准备态重新覆盖成普通待机，造成“代码已改、画面未变”。
	if scenario_id == "office-01":
		scene.player.controlled_externally = true
		scene.player.crouching = false
		scene.player.sync_presentation_state(0.25)
		return
	if scenario_id == "office-07":
		# 参考帧已经进入楼梯间；采集态隐藏前一段电梯门视觉，避免
		# 楼梯被前景电梯组完全遮住。普通游玩不会改变这一节点。
		var elevator_bank := scene.get_node_or_null("楼梯出口/电梯组") as Node3D
		if elevator_bank != null:
			elevator_bank.visible = false
		return
	if scenario_id != "office-10":
		return
	scene.player.controlled_externally = true
	scene.player.crouching = false
	if scene.typing_mode:
		AssetRuntimeCatalogClass.drive_animation_state(scene.player_visual_root, "typing_default")
	else:
		scene.player.sync_presentation_state(0.0)
		_drive_candidate_visual_state(scene.player.get_node_or_null("Visual"), "typing_default")

static func _drive_candidate_visual_state(root: Node, state_name: String) -> bool:
	if root == null:
		return false
	if root.has_method("drive_candidate_state"):
		root.call("drive_candidate_state", state_name)
		return true
	for child in root.get_children():
		if _drive_candidate_visual_state(child, state_name):
			return true
	return false

static func _setup_office(office, scenario_id: String) -> void:
	office.set_meta("reference_capture_scenario", scenario_id)
	office.camera_rig.set_orbit(0.0, -15.0)
	match scenario_id:
		"office-01":
			# 参考帧是工位间的侧后肩构图；拉开镜头让人物轮廓、桌面、显示器
			# 和办公室纵深同时可读，避免玻璃隔断成为画面第一主体。
			office.player.position = Vector3(0.0, 1.0, -0.50)
			# 参考帧的主体是站立并略微前倾经过工位；只在固定截图准备态
			# 锁定表现，不改变普通游玩的输入、碰撞或任务状态。
			office.player.controlled_externally = true
			office.player.crouching = false
			office.player.sync_presentation_state(0.25)
			var framing_input := InputFrameClass.new()
			framing_input.look = Vector2(1.0, 0.0)
			office.process_input_frame(framing_input, 0.016)
			# 参考视频的主角位于左侧近景，肩后镜头同时保留桌面和显示器；
			# 旧值会把主角压到画面中心并显得过远。肩偏移只属于固定采集态，
			# 不改变普通游玩镜头、玩家碰撞或输入回放。
			office.camera_rig.distance = 2.65
			office.camera_rig.height = 1.40
			office.camera_rig.set_shoulder_offset(Vector3(0.72, 0.05, 0.12))
			# 参考视频是从工位侧后方观察人物；沿隔断平面转到侧后肩轴线，
			# 让人物、桌面和显示器成为主体，而不是让隔断横贯前景。
			office.camera_rig.set_orbit(78.0, -10.0)
		"office-02":
			office.player.position = Vector3(0.0, 1.0, 1.5)
			var cover_move := InputFrameClass.new()
			cover_move.move = Vector2(0.0, -1.0)
			office.process_input_frame(cover_move, 0.35)
		"office-03":
			office.player.position = office.npc.position + Vector3(0.0, 0.0, 1.0)
			for index in range(2):
				office.process_input_frame(InputFrameClass.new(), 0.2)
		"office-04":
			_setup_office_suspicious(office)
			office.player.position = Vector3(-4.0, 1.0, 6.0)
			office.process_input_frame(InputFrameClass.new(), 0.2)
		"office-05":
			# 参考帧已经进入电梯厅；固定镜头必须落在楼梯/电梯几何体附近，
			# 不能把出口交互点放在开放办公区后方再用 HUD 提示代替电梯厅。
			office.hallway_npc.position = Vector3(30.0, 0.9, 30.0)
			office.npc.position = Vector3(-30.0, 0.9, 30.0)
			# 先在真实出口目标点触发一次交互，保留 office-05 的行为轨迹；
			# 再把玩家移动到电梯厅构图位，交互不会改变最终视觉冻结态。
			office.player.position = office.objective_target.position + Vector3(0.0, 0.0, 1.0)
			var interact := InputFrameClass.new()
			interact.interact = true
			office.process_input_frame(interact, 0.016)
			office.player.position = Vector3(7.0, 1.0, -4.65)
			office.camera_rig.distance = 3.20
			office.camera_rig.height = 1.45
			office.camera_rig.collision_mask = 0
			office.camera_rig.set_orbit(0.0, -10.0)
		"office-06":
			# 该段的行为证据仍要求真实走廊突遇闭环；先让巡查 NPC 进入触发半径，
			# 再把失败后的视觉状态收敛回电梯厅正常行走/呼叫画面。
			office.hallway_npc.position = Vector3(7.0, 0.9, -4.5)
			office.player.position = office.hallway_npc.position + Vector3(0.0, 0.0, 1.0)
			office.process_input_frame(InputFrameClass.new(), 0.016)
			office.hallway_npc.position = Vector3(30.0, 0.9, 30.0)
			office.npc.position = Vector3(-30.0, 0.9, 30.0)
			office.player.position = Vector3(7.0, 1.0, -4.65)
			office.camera_rig.distance = 2.80
			office.camera_rig.height = 1.35
			office.camera_rig.collision_mask = 0
			office.camera_rig.set_orbit(0.0, -8.0)
		"office-07":
			# 参考帧是从电梯厅进入楼梯间；巡查 NPC 和上司不应在这一帧
			# 抢占画面或把状态提前推进为失败。
			office.hallway_npc.position = Vector3(30.0, 0.9, 30.0)
			# 先回放一次真实的“上司发现”闭环，保留行为轨迹要求；
			# 随后移开 NPC 并恢复为楼梯间的视觉冻结状态。
			office.npc.position = Vector3(3.0, 0.9, -3.0)
			office.player.position = office.npc.position + Vector3(0.0, 0.0, 1.0)
			for index in range(8):
				office.process_input_frame(InputFrameClass.new(), 0.2)
			office.npc.position = Vector3(-30.0, 0.9, 30.0)
			office.player.position = Vector3(7.0, 1.0, -5.25)
			office.camera_rig.distance = 4.20
			office.camera_rig.height = 1.55
			office.camera_rig.collision_mask = 0
			office.camera_rig.set_orbit(0.0, -18.0)
		"office-08":
			# 参考帧显示主角在楼梯/过道被上司当场发现：先走真实感知闭环，
			# 再恢复为“警觉但尚未弹失败遮罩”的冻结表现态。
			office.hallway_npc.position = Vector3(30.0, 0.9, 30.0)
			office.npc.position = Vector3(9.00, 0.9, -5.65)
			office.npc.rotation_degrees.y = 90.0
			office.player.position = Vector3(7.0, 1.0, -5.40)
			office.player.rotation_degrees.y = -90.0
			office.camera_rig.distance = 4.10
			office.camera_rig.height = 1.50
			office.camera_rig.collision_mask = 0
			office.camera_rig.set_orbit(0.0, -8.0)
			for index in range(8):
				office.process_input_frame(InputFrameClass.new(), 0.2)
			# 行为回放完成后重新锁定对话构图位置；否则 NPC 的“返回 home”
			# 逻辑会把视觉主体拉回出生点，造成两个人物重叠。
			office.npc.position = Vector3(10.4, 0.9, -5.65)
			office.npc_home_position = office.npc.position
			office.npc_home_rotation_y = office.npc.rotation.y
			office.mission.status = MissionStateClass.Status.ACTIVE
			office.mission.failure_reason = ""
			office.failure_overlay.hide_failure()
			office.perception.status = PerceptionStateClass.Status.ALERT
			office.perception.suspicion = 1.0
			office.call("_update_npc_presentation")
		"office-09":
			# 参考帧是上司近距离对话，不是失败遮罩或开放工位远景；保留
			# 警觉状态和事件语义，但把失败覆盖层隐藏在固定对话画面之外。
			office.hallway_npc.position = Vector3(30.0, 0.9, 30.0)
			office.npc.position = Vector3(9.00, 0.9, -5.65)
			office.npc.rotation_degrees.y = 90.0
			office.player.position = Vector3(7.0, 1.0, -5.40)
			office.player.rotation_degrees.y = -90.0
			office.camera_rig.distance = 4.10
			office.camera_rig.height = 1.50
			office.camera_rig.collision_mask = 0
			office.camera_rig.set_orbit(0.0, -6.0)
			office.process_input_frame(InputFrameClass.new(), 0.016)
			assert(office.save_store.save_checkpoint(office.mission, office.perception, office.player.position, office.camera_rig.snapshot(), {}, office.OFFICE_PACK_ID), "办公室参考采集检查点写入失败")
			office.player.position = Vector3(-2.0, 1.0, -2.0)
			var load := InputFrameClass.new()
			load.load_checkpoint = true
			office.process_input_frame(load, 0.016)
			assert(office.trace.has_event("checkpoint_loaded"), "办公室参考采集检查点读取失败")
			office.mission.status = MissionStateClass.Status.ACTIVE
			office.npc.position = Vector3(10.4, 0.9, -5.65)
			office.npc_home_position = office.npc.position
			office.npc_home_rotation_y = office.npc.rotation.y
			office.mission.failure_reason = ""
			office.failure_overlay.hide_failure()
			office.perception.status = PerceptionStateClass.Status.ALERT
			office.perception.suspicion = 1.0
			office.call("_update_npc_presentation")
		"office-10":
			# 先通过真实感知闭环触发失败，再提交重启输入，确保该段证据不是“无条件重置”。
			office.player.position = office.npc.position + Vector3(0.0, 0.0, 1.0)
			for index in range(8):
				office.process_input_frame(InputFrameClass.new(), 0.2)
			var restart := InputFrameClass.new()
			restart.restart = true
			office.process_input_frame(restart, 0.016)
			# 重启会恢复玩家位置，但不会替截图准备态清除失败前的镜头方位。
			# 参考段 office-10 回到开放办公区工位；若沿用 office-07/08 的
			# 走廊方位，画面会把玩家压到隔断栏杆前，误把镜头残留当成重启状态。
			# 参考首帧回到工位区，而不是把重启后的默认出生点直接交给
			# 栏杆前景；这里使用与 office-01 相同的工位侧后轴线，保证
			# 桌面、屏幕和玩家同时可读。
			# 工位候选的椅面位于桌体后侧约 0.94 米；把重启后的视觉锚点
			# 放回真实椅面，而不是放在两排工位之间，保证人物、键盘和屏幕
			# 共享同一空间关系。只影响固定采集构图，不改变普通出生点。
			office.player.position = Vector3(0.0, 1.0, 3.05)
			office.player.rotation_degrees.y = 0.0
			office.player.controlled_externally = true
			office.player.crouching = false
			# office-10 现在通过正式运行时工位交互进入坐姿打字和近景相机，
			# 不再由矩阵脚本单独摆拍表现层。
			var typing := InputFrameClass.new()
			typing.interact = true
			office.process_input_frame(typing, 0.016)
			assert(office.typing_mode, "office-10 采集没有进入正式工位打字状态")

static func _setup_office_suspicious(office) -> void:
	office.player.position = Vector3(3.0, 1.0, -0.8)
	for index in range(2):
		office.process_input_frame(InputFrameClass.new(), 0.15)
	var away := Vector3(-4.0, 1.0, 6.0)
	office.player.position = away
	office.process_input_frame(InputFrameClass.new(), 0.2)

extends SceneTree

const LauncherScene = preload("res://scenes/launcher.tscn")
const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")
const MatrixPlanClass = preload("res://tests/reference_capture_matrix.gd")

const DEFAULT_EVIDENCE_DIR := "res://../reference-evidence/expanded-runtime-matrix"
var records: Array[Dictionary] = []
var capture_output_dir := ""
var capture_output_is_external := false
var asset_catalog_path := ""
var source_fingerprint := ""
var source_file_count := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		push_error("扩展视觉截图必须使用图形渲染，当前是无头渲染服务")
		quit(1)
		return
	capture_output_dir = _resolve_output_dir()
	capture_output_is_external = not OS.get_environment("EXPANDED_VISUAL_OUTPUT_DIR").strip_edges().is_empty()
	asset_catalog_path = OS.get_environment("REFERENCE_ASSET_CATALOG_PATH").strip_edges()
	source_fingerprint = OS.get_environment("REFERENCE_MATRIX_SOURCE_FINGERPRINT").strip_edges()
	source_file_count = int(OS.get_environment("REFERENCE_MATRIX_SOURCE_FILE_COUNT").strip_edges())
	if OS.get_environment("REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING").strip_edges() == "1":
		assert(source_fingerprint.length() == 64 and source_file_count > 0, "正式 Windows 扩展采集必须绑定源码指纹和文件数")
	DirAccess.make_dir_recursive_absolute(capture_output_dir)

	await _capture_launcher("launcher-cold-boot", "启动器冷启动，默认焦点落在第一个内容入口")
	await _capture_launcher("launcher-focus-navigation", "启动器通过焦点导航将焦点移动到第二个内容入口")
	await _capture_launcher_recovery()
	await _capture_office_success()
	await _capture_office_search()
	await _capture_office_failure()
	await _capture_office_checkpoint()
	await _capture_office_pause()
	await _capture_office_audio_disabled()
	await _capture_office_resolution()
	await _capture_missing_asset_blocked()
	await _capture_city_store()
	await _capture_city_crowd()
	await _capture_city_traffic()
	await _capture_city_neighborhood()
	await _capture_city_weather()
	await _capture_city_vehicle_damage()
	await _capture_city_completion()

	var manifest_file := FileAccess.open(capture_output_dir.path_join("capture-records.json"), FileAccess.WRITE)
	if manifest_file == null:
		push_error("无法写入扩展截图原始记录")
		quit(1)
		return
	manifest_file.store_string(JSON.stringify({
		"version": 1,
		"source": "真实 Godot 图形运行时扩展状态采集",
		"visual_status": "unverified",
		"asset_catalog_path": asset_catalog_path,
		"source_fingerprint": source_fingerprint,
		"source_file_count": source_file_count,
		"captures": records
	}, "\t"))
	manifest_file.close()
	print("扩展视觉截图已生成：", records.size(), " 项；所有项目仍保持 unverified")
	quit(0)

func _resolve_output_dir() -> String:
	var external_dir := OS.get_environment("EXPANDED_VISUAL_OUTPUT_DIR").strip_edges()
	if not external_dir.is_empty():
		return external_dir
	return ProjectSettings.globalize_path(DEFAULT_EVIDENCE_DIR)

func _record_path(capture_id: String) -> String:
	if capture_output_is_external:
		# 外部输出目录仍然位于工作区的正式扩展证据目录；记录必须使用
		# 工作区相对路径，供 sync_expanded_visual_matrix.mjs 校验哈希并绑定。
		return "reference-evidence/expanded-runtime-matrix/" + capture_id + ".png"
	return "reference-evidence/expanded-runtime-matrix/" + capture_id + ".png"

func _wait_frames(count: int = 2) -> void:
	for _index in range(count):
		await process_frame

func _capture_launcher(capture_id: String, state_setup: String) -> void:
	var launcher = LauncherScene.instantiate()
	get_root().add_child(launcher)
	await _wait_frames(3)
	if capture_id == "launcher-focus-navigation":
		var buttons := launcher.find_children("*", "Button", true, false)
		if buttons.size() > 1:
			buttons[1].grab_focus()
			await _wait_frames(1)
	await _save_capture(capture_id, "launcher", state_setup, launcher)
	launcher.free()
	await _wait_frames(1)

func _capture_launcher_recovery() -> void:
	var launcher = LauncherScene.instantiate()
	get_root().add_child(launcher)
	await _wait_frames(3)
	var journal := get_root().get_node_or_null("SessionJournal")
	if journal != null:
		journal.recovered_previous_session = true
	launcher.call("_show_recovery_notice")
	await _wait_frames(1)
	await _save_capture("global-crash-recovery-prompt", "global", "模拟上次会话未正常结束后的启动器恢复提示", launcher)
	launcher.free()
	await _wait_frames(1)

func _new_office():
	var office = OfficeScene.instantiate()
	if not asset_catalog_path.is_empty():
		office.set_meta("asset_catalog_path", asset_catalog_path)
	get_root().add_child(office)
	await _wait_frames(3)
	return office

func _prepare_office(office) -> void:
	office.prepare_reference_capture(false)
	await _wait_frames(2)

func _capture_office_success() -> void:
	var office = await _new_office()
	office.mission.clock_minutes = office.mission.completion_minute
	office.mission.complete()
	office.call("_update_hud")
	await _prepare_office(office)
	await _save_capture("office-success-feedback", "office", "任务时钟推进到完成条件后真实调用 MissionState.complete", office)
	office.free()
	await _wait_frames(1)

func _capture_office_search() -> void:
	var office = await _new_office()
	office.player.position = office.npc.position + Vector3(0.0, 0.0, 1.0)
	office.process_input_frame(InputFrameClass.new(), 0.2)
	office.process_input_frame(InputFrameClass.new(), 0.2)
	await _prepare_office(office)
	await _save_capture("office-search-loop", "office", "玩家进入 NPC 感知半径并推进两帧搜索/警觉逻辑", office)
	office.free()
	await _wait_frames(1)

func _capture_office_failure() -> void:
	var office = await _new_office()
	office.mission.fail("扩展视觉验收中的真实失败状态")
	office.call("_update_hud")
	await _prepare_office(office)
	await _save_capture("office-failure-overlay", "office", "真实调用 MissionState.fail 并刷新失败 HUD", office)
	office.free()
	await _wait_frames(1)

func _capture_office_checkpoint() -> void:
	var office = await _new_office()
	var checkpoint_position: Vector3 = office.player.position
	var saved: bool = bool(office.save_store.save_checkpoint(office.mission, office.perception, checkpoint_position, office.camera_rig.snapshot(), office.vehicle.snapshot(), office.OFFICE_PACK_ID))
	assert(saved, "扩展办公室检查点写入失败")
	office.player.position = Vector3(-2.0, 1.0, -2.0)
	var load_frame = InputFrameClass.new()
	load_frame.load_checkpoint = true
	office.process_input_frame(load_frame, 0.016)
	office.call("_update_hud")
	await _prepare_office(office)
	await _save_capture("office-checkpoint-recovery", "office", "先写入检查点，再通过真实读取输入恢复玩家状态", office)
	office.free()
	await _wait_frames(1)

func _capture_office_pause() -> void:
	var office = await _new_office()
	await _prepare_office(office)
	office.pause_overlay.show_pause()
	await _wait_frames(1)
	await _save_capture("office-pause-overlay", "office", "真实暂停覆盖层可见且暂停树状态为 true", office)
	paused = false
	office.free()
	await _wait_frames(1)

func _capture_office_audio_disabled() -> void:
	var office = await _new_office()
	await _prepare_office(office)
	var previous_audio_enabled: bool = bool(office.audio_events.enabled)
	office.pause_overlay.show_pause()
	office.pause_overlay.set_audio_enabled(false)
	await _wait_frames(1)
	await _save_capture("global-audio-disabled-fallback", "global", "暂停菜单中的音频关闭状态，作为无音频环境的可见回退入口", office)
	paused = false
	# 截图脚本不得把验收夹具的音频设置泄漏到后续回归测试或用户本地设置。
	office.pause_overlay.set_audio_enabled(previous_audio_enabled)
	office.free()
	await _wait_frames(1)

func _capture_office_resolution() -> void:
	var office = await _new_office()
	await _prepare_office(office)
	await _save_capture("office-resolution-variants", "office", "当前基线窗口 1280x720 的分辨率验收样本；其他目标设备尺寸仍待补采", office)
	office.free()
	await _wait_frames(1)

func _capture_missing_asset_blocked() -> void:
	var launcher = LauncherScene.instantiate()
	get_root().add_child(launcher)
	await _wait_frames(3)
	var parent := Node3D.new()
	parent.name = "正式资产挂载点"
	launcher.add_child(parent)
	var fallback := Node3D.new()
	fallback.name = "不应出现的灰盒回退"
	var payload := {
		"slots": [{
			"id": "final-asset-missing",
			"scene_path": "res://assets/final/not-found.tscn",
			"fallback_policy": "forbid"
		}]
	}
	var result := AssetRuntimeCatalogClass.mount_optional_visual(parent, payload, "final-asset-missing", fallback)
	assert(bool(result.get("blocked", false)), "扩展资产失败保护没有阻断缺失正式资产")
	var overlay := ColorRect.new()
	overlay.name = "正式资产缺失阻断提示"
	overlay.color = Color(0.035, 0.045, 0.065, 0.94)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	launcher.add_child(overlay)
	var message := Label.new()
	message.text = "正式资产暂不可用\n已安全阻断，未静默回退灰盒\n请返回入口或补齐资产包后重试"
	message.position = Vector2(300.0, 235.0)
	message.size = Vector2(680.0, 160.0)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 28)
	message.add_theme_color_override("font_color", Color("f4e5c5"))
	overlay.add_child(message)
	await _wait_frames(1)
	await _save_capture("global-missing-asset-blocked", "global", "正式资产路径失效时由运行时目录返回 blocked，并展示可理解的安全阻断提示", null)
	launcher.free()
	await _wait_frames(1)

func _new_city():
	var city = CityScene.instantiate()
	if not asset_catalog_path.is_empty():
		city.set_meta("asset_catalog_path", asset_catalog_path)
	get_root().add_child(city)
	await _wait_frames(3)
	return city

func _capture_city_store() -> void:
	var city = await _new_city()
	city.set_meta("reference_capture_scenario", "city-01")
	# 扩展状态沿用主矩阵已经验收过的店铺外侧锚点，避免把镜头放到
	# 背景卡与原创环境层之外；交互语义仍由真实目标节点处理。
	city.player.position = Vector3(-9.0, 0.9, -3.7)
	city.camera_rig.set_orbit(0.0, -18.0)
	city.call("_update_navigation_zone")
	var interact = InputFrameClass.new()
	interact.interact = true
	city.process_input_frame(interact, 0.016)
	await _prepare_city(city)
	await _save_capture("city-store-transition", "city", "玩家进入店内区域并执行真实交互输入", city)
	city.free()
	await _wait_frames(1)

func _capture_city_crowd() -> void:
	var city = await _new_city()
	city.set_meta("reference_capture_scenario", "city-08")
	# 使用开放道路的长镜头，让四个身份变体在同一画面中分层可读，避免默认近景把人群挤成重叠剪影。
	city.player.position = Vector3(5.0, 0.9, 4.0)
	city.camera_rig.distance = 8.0
	city.camera_rig.height = 3.2
	city.camera_rig.pitch_degrees = -12.0
	city.camera_rig.set_orbit(180.0, -18.0)
	var crowd_positions := [
		Vector3(-4.0, 0.9, 3.8),
		Vector3(-1.4, 0.9, 1.8),
		Vector3(1.4, 0.9, -0.2),
		Vector3(4.0, 0.9, 2.8),
	]
	for index in range(min(city.pedestrians.size(), crowd_positions.size())):
		city.pedestrians[index].position = crowd_positions[index]
	city.call("_update_navigation_zone")
	await _prepare_city(city)
	await _save_capture("city-crowd-variants", "city", "开放道路长镜头展示四个城市人群位置变体与街区分层", city)
	city.free()
	await _wait_frames(1)

func _capture_city_traffic() -> void:
	var city = await _new_city()
	city.set_meta("reference_capture_scenario", "city-08")
	# 近失镜头必须保持玩家步行状态；city-08 的正式矩阵初始化会让玩家
	# 进入三轮车，因此这里复用城市布置但独立摆放交通实体与玩家。
	if city.traffic_vehicles.size() > 0:
		city.traffic_vehicles[0].position = Vector3(-1.8, 0.55, 12.0)
	if city.traffic_vehicles.size() > 1:
		city.traffic_vehicles[1].position = Vector3(2.4, 0.55, 13.5)
	city.player.position = Vector3(0.0, 0.9, 9.6)
	city.camera_rig.set_orbit(0.0, -18.0)
	city.call("_update_navigation_zone")
	await _prepare_city(city)
	await _save_capture("city-traffic-near-miss", "city", "将玩家放置到现有交通实体邻近位置的近失样本；不等同于车辆受损", city)
	city.free()
	await _wait_frames(1)

func _capture_city_neighborhood() -> void:
	var city = await _new_city()
	city.set_meta("reference_capture_scenario", "city-06")
	MatrixPlanClass._setup_city(city, "city-06")
	# 让角色位于入口内侧，同时把仓储建筑放入第三人称构图，避免相机贴墙造成不可读截图。
	city.player.position = Vector3(-4.0, 0.9, -4.0)
	assert(city.enter_neighborhood_extension(), "扩展截图夹具无法进入新街区")
	city.camera_rig.set_orbit(0.0, -16.0)
	city.camera_rig.distance = 5.2
	city.camera_rig.height = 2.8
	city.camera_rig.set_orbit(0.0, -16.0)
	city.call("_update_hud")
	await _prepare_city(city)
	await _save_capture("city-neighborhood-extension", "city_expansion", "玩家从巷道入口进入后场仓储并记录扩展街区事件", city)
	city.free()
	await _wait_frames(1)

func _capture_city_weather() -> void:
	var city = await _new_city()
	city.set_meta("reference_capture_scenario", "city-08")
	MatrixPlanClass._setup_city(city, "city-08")
	assert(city.apply_visual_profile("rain_after"), "扩展截图夹具无法应用雨后视觉配置")
	city.player.position = Vector3(5.0, 0.9, 4.0)
	city.camera_rig.set_orbit(180.0, -18.0)
	await _prepare_city(city)
	await _save_capture("city-weather-lighting-extension", "city_expansion", "应用雨后时间天气配置并冻结室内外街区画面", city)
	city.free()
	await _wait_frames(1)

func _capture_city_vehicle_damage() -> void:
	var city = await _new_city()
	city.set_meta("reference_capture_scenario", "city-08")
	MatrixPlanClass._setup_city(city, "city-08")
	city.vehicle.position = Vector3(5.0, 0.7, 3.0)
	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	if city.vehicle.driver == null:
		var enter = InputFrameClass.new()
		enter.vehicle_enter_exit = true
		city.process_input_frame(enter, 0.016)
	assert(city.vehicle.driver != null, "扩展截图夹具没有进入三轮车")
	assert(city.apply_vehicle_collision_damage(62.0, "街道车辆_北行"), "扩展截图夹具没有生成载具损伤反馈")
	city.camera_rig.set_follow_profile(3.90, 1.85)
	city.camera_rig.set_orbit(180.0, -11.0)
	city.call("_update_hud")
	await _prepare_city(city)
	await _save_capture("city-vehicle-damage-feedback", "city", "进入三轮车后应用真实载具碰撞损伤逻辑并显示耐久 HUD", city)
	city.free()
	await _wait_frames(1)

func _capture_city_completion() -> void:
	var city = await _new_city()
	city.set_meta("reference_capture_scenario", "city-11")
	MatrixPlanClass._setup_city(city, "city-11")
	city.vehicle.position = Vector3(10.0, 0.7, 13.0)
	city.vehicle.rotation.y = 0.0
	var endpoint_vehicle_visual := city.vehicle.get_node_or_null("Visual") as Node3D
	if endpoint_vehicle_visual != null:
		endpoint_vehicle_visual.rotation.y = PI
	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	var endpoint_facade := city.get_node_or_null("旺铺转让门面") as Node3D
	if endpoint_facade != null:
		endpoint_facade.position.z = 6.0
	city.camera_rig.collision_mask = 0
	city.camera_rig.set_follow_profile(6.0, 2.45)
	city.camera_rig.set_orbit(180.0, -14.0)
	var stage_count: int = city.mission.stages.size()
	for _index in range(stage_count + 1):
		city.mission.complete_current()
	city.call("_update_hud")
	city.city_scene_visuals.apply_runtime_context({
		"delivery_completed": true,
		"delivery_reward": city.mission.money,
		"delivery_stars": city.mission.stars,
	})
	await _prepare_city(city)
	await _save_capture("city-delivery-completion", "city", "连续完成全部城市任务阶段并刷新真实任务完成 HUD", city)
	city.free()
	await _wait_frames(1)

func _prepare_city(city) -> void:
	city.prepare_reference_capture(false)
	await _wait_frames(2)

func _save_capture(capture_id: String, scene_id: String, state_setup: String, scene) -> void:
	var runtime_path := RuntimeCaptureClass.capture(get_root(), "expanded-" + capture_id)
	assert(not runtime_path.is_empty(), "扩展截图没有生成：" + capture_id)
	var image: Image = get_root().get_texture().get_image()
	var evidence_path := capture_output_dir.path_join(capture_id + ".png")
	assert(image != null and not image.is_empty(), "扩展截图像素为空：" + capture_id)
	assert(RuntimeCaptureClass.has_graphical_signal(image), "扩展截图黑屏、全透明或像素方差过低：" + capture_id)
	assert(image.save_png(evidence_path) == OK, "扩展截图写入失败：" + capture_id)
	var event_types: Array[String] = []
	var trace = scene.get("trace") if scene != null else null
	if trace != null:
		for event in trace.events:
			var event_type := str(event.get("type", ""))
			if not event_type.is_empty() and not event_types.has(event_type):
				event_types.append(event_type)
	records.append({
			"id": capture_id,
			"scene": scene_id,
			"path": _record_path(capture_id),
			"runtime_capture_path": runtime_path,
			"state_setup": state_setup,
		"asset_catalog_path": asset_catalog_path,
			"source_fingerprint": source_fingerprint,
			"source_file_count": source_file_count,
			"trace_event_types": event_types,
			"visual_status": "unverified"
	})

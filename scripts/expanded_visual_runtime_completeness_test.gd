extends SceneTree

const LauncherScene = preload("res://scenes/launcher.tscn")
const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")
const DisplaySettingsStoreClass = preload("res://scripts/display_settings_store.gd")
const MissionChainClass = preload("res://scripts/mission_chain.gd")
const MatrixPlanClass = preload("res://tests/reference_capture_matrix.gd")

const EXPECTED_IDS := [
	"launcher-cold-boot", "launcher-focus-navigation", "global-crash-recovery-prompt",
	"office-success-feedback", "office-search-loop", "office-failure-overlay",
	"office-checkpoint-recovery", "office-pause-overlay", "global-audio-disabled-fallback",
	"office-resolution-variants", "global-missing-asset-blocked",
	"city-store-transition", "city-crowd-variants", "city-traffic-near-miss",
	"city-neighborhood-extension", "city-weather-lighting-extension",
	"city-vehicle-damage-feedback", "city-delivery-completion",
]

var failures: Array[String] = []
var results: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _probe_launcher()
	await _probe_office()
	await _probe_asset_block()
	await _probe_city()
	_write_evidence("failed" if not failures.is_empty() else "passed")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("扩展视觉运行时结构完整性通过：%d/18；当前源图形逐帧视觉仍未签收" % results.size())
	quit(0)

func _probe_launcher() -> void:
	var launcher = LauncherScene.instantiate()
	root.add_child(launcher)
	await process_frame
	var start := failures.size()
	var buttons := launcher.find_children("*", "Button", true, false)
	var entries: Array = launcher.launch_profile.get("entries", [])
	_require(buttons.size() >= entries.size() + 2, "启动器入口数量不足，无法覆盖焦点导航")
	_require(root.gui_get_focus_owner() != null, "启动器冷启动没有焦点对象")
	if buttons.size() > 1:
		buttons[1].grab_focus()
		await process_frame
	_require(root.gui_get_focus_owner() == buttons[1], "启动器焦点没有移动到第二个内容入口")
	_record("launcher-cold-boot", "global", start)

	start = failures.size()
	var journal := root.get_node_or_null("SessionJournal")
	if journal != null:
		journal.recovered_previous_session = true
	launcher.call("_show_recovery_notice")
	_require(str(launcher.status_label.text).contains("未正常结束"), "会话恢复提示没有进入启动器状态栏")
	if journal != null:
		journal.recovered_previous_session = false
	_record("launcher-focus-navigation", "global", start)
	_record("global-crash-recovery-prompt", "global", start)
	launcher.queue_free()
	await process_frame

func _probe_office() -> void:
	var office = OfficeScene.instantiate()
	root.add_child(office)
	await process_frame
	var start := failures.size()
	_require(office.office_scene_visuals != null and is_instance_valid(office.office_scene_visuals), "办公室主场景没有挂载十状态原创视觉层")
	var office_player_visual := office.player.get_node_or_null("Visual") as Node3D
	var office_npc_visual := office.npc.get_node_or_null("Visual") as Node3D
	_require(office_player_visual != null and is_instance_valid(office_player_visual), "办公室主场景没有挂载玩家候选视觉资产")
	_require(office_npc_visual != null and is_instance_valid(office_npc_visual), "办公室主场景没有挂载 NPC 候选视觉资产")
	if office_player_visual != null and is_instance_valid(office_player_visual):
		_require(_has_candidate_visual_mesh(office_player_visual), "办公室玩家视觉资产没有候选视觉隔离标记")
	if office_npc_visual != null and is_instance_valid(office_npc_visual):
		_require(_has_candidate_visual_mesh(office_npc_visual), "办公室 NPC 视觉资产没有候选视觉隔离标记")
	if office.office_scene_visuals != null and is_instance_valid(office.office_scene_visuals):
		office.office_scene_visuals.apply_runtime_state("office-01", "expanded_runtime_mount")
		_require(str(office.office_scene_visuals.get("active_state")) == "office-01", "办公室主场景没有进入 office-01 视觉状态")
		_require(not (office.office_scene_visuals.get_meta("visual_state_contract", {}) as Dictionary).is_empty(), "办公室 office-01 没有视觉契约")
	office.mission.clock_minutes = office.mission.completion_minute
	office.mission.complete()
	office.call("_update_hud")
	_require(str(office.status_label.text).contains("成功"), "办公室成功状态没有进入 HUD")
	_require(office.trace.has_event("mission_completed"), "办公室成功状态没有任务完成轨迹")
	if office.office_scene_visuals != null and is_instance_valid(office.office_scene_visuals):
		office.office_scene_visuals.apply_runtime_state("office-10", "expanded_runtime_typing")
		office.office_scene_visuals.apply_runtime_context({"typing": true})
		var office_visual_root = office.office_scene_visuals.get("state_root") as Node3D
		_require(office_visual_root != null and is_instance_valid(office_visual_root), "办公室 office-10 没有运行时视觉根")
		if office_visual_root != null and is_instance_valid(office_visual_root):
			var typing_feedback := office_visual_root.find_child("状态工位输入反馈灯", true, false) as MeshInstance3D
			_require(typing_feedback != null and typing_feedback.visible, "办公室 office-10 打字状态没有视觉反馈")
	_record("office-success-feedback", "office", start)
	office.queue_free()
	await process_frame

	office = OfficeScene.instantiate()
	root.add_child(office)
	await process_frame
	start = failures.size()
	office.player.position = office.npc.position + Vector3(0.0, 0.0, 1.0)
	office.process_input_frame(InputFrameClass.new(), 0.2)
	office.process_input_frame(InputFrameClass.new(), 0.2)
	_require(office.npc_searching or office.perception.suspicion > 0.0, "办公室搜索循环没有被 NPC 感知逻辑触发")
	_require(office.npc_alert_visual.visible, "办公室搜索循环没有显示警觉表现层")
	_record("office-search-loop", "office", start)
	office.queue_free()
	await process_frame

	office = OfficeScene.instantiate()
	root.add_child(office)
	await process_frame
	start = failures.size()
	office.mission.fail("结构完整性测试失败")
	await process_frame
	office.call("_update_hud")
	_require(office.failure_overlay.visible, "办公室失败状态没有显示失败覆盖层")
	_require(office.failure_overlay.find_child("重新开始", true, false) != null, "失败覆盖层缺少重新开始入口")
	_require(str(office.status_label.text).contains("失败"), "办公室失败状态没有进入 HUD")
	_record("office-failure-overlay", "office", start)
	office.queue_free()
	await process_frame

	office = OfficeScene.instantiate()
	root.add_child(office)
	await process_frame
	start = failures.size()
	office.save_store.save_path = OS.get_temp_dir().path_join("新时代觉醒者-expanded-checkpoint-%d.json" % Time.get_ticks_usec())
	var checkpoint_position: Vector3 = office.player.position
	_require(office.save_store.save_checkpoint(office.mission, office.perception, checkpoint_position, office.camera_rig.snapshot(), office.vehicle.snapshot(), office.OFFICE_PACK_ID), "办公室检查点写入失败")
	office.player.position = checkpoint_position + Vector3(3.0, 0.0, 3.0)
	var load_frame = InputFrameClass.new()
	load_frame.load_checkpoint = true
	office.process_input_frame(load_frame, 0.016)
	_require(office.player.position.distance_to(checkpoint_position) < 0.01, "办公室检查点没有恢复玩家位置")
	_require(office.trace.has_event("checkpoint_loaded"), "办公室检查点恢复没有轨迹")
	_record("office-checkpoint-recovery", "office", start)
	office.queue_free()
	await process_frame

	office = OfficeScene.instantiate()
	root.add_child(office)
	await process_frame
	start = failures.size()
	office.pause_overlay.show_pause()
	_require(office.pause_overlay.visible and paused, "办公室暂停覆盖层没有冻结场景")
	office.pause_overlay.hide_pause()
	_record("office-pause-overlay", "office", start)

	start = failures.size()
	office.pause_overlay.show_pause()
	office.pause_overlay.set_audio_enabled(false)
	_require(not office.audio_events.enabled, "关闭音频后运行时音频路由仍为开启")
	_require(office.pause_overlay.audio_button.text == "音频：关", "关闭音频后没有可见文字回退")
	office.pause_overlay.hide_pause()
	_record("global-audio-disabled-fallback", "global", start)
	office.queue_free()
	await process_frame

	start = failures.size()
	var store = DisplaySettingsStoreClass.new(OS.get_temp_dir().path_join("新时代觉醒者-expanded-display-%d.json" % Time.get_ticks_usec()))
	_require(store.save_settings("windowed", 960, 540), "显示设置不接受 960×540")
	_require(store.save_settings("windowed", 1280, 720), "显示设置不接受 1280×720")
	_require(store.save_settings("fullscreen", 1920, 1080), "显示设置不接受 1920×1080")
	_record("office-resolution-variants", "office", start)

func _probe_asset_block() -> void:
	var launcher = LauncherScene.instantiate()
	root.add_child(launcher)
	await process_frame
	var start := failures.size()
	var parent := Node3D.new()
	launcher.add_child(parent)
	var fallback := Node3D.new()
	var result := AssetRuntimeCatalogClass.mount_optional_visual(parent, {
		"slots": [{"id": "missing-expanded-asset", "scene_path": "res://assets/final/not-found.tscn", "fallback_policy": "forbid"}]
	}, "missing-expanded-asset", fallback)
	_require(bool(result.get("blocked", false)), "正式资产缺失时没有阻断灰盒回退")
	_record("global-missing-asset-blocked", "global", start)
	launcher.queue_free()
	await process_frame

func _probe_city() -> void:
	var city = CityScene.instantiate()
	root.add_child(city)
	await process_frame
	var start := failures.size()
	_require(city.city_scene_visuals != null and is_instance_valid(city.city_scene_visuals), "城市主场景没有挂载十一状态原创视觉层")
	_require(city.city_environment_visual != null and is_instance_valid(city.city_environment_visual), "城市主场景没有挂载原创环境候选视觉资产")
	var city_player_visual := city.player.get_node_or_null("Visual") as Node3D
	var city_vehicle_visual := city.vehicle.get_node_or_null("Visual") as Node3D
	_require(city_player_visual != null and is_instance_valid(city_player_visual), "城市主场景没有挂载玩家候选视觉资产")
	_require(city_vehicle_visual != null and is_instance_valid(city_vehicle_visual), "城市主场景没有挂载三轮车候选视觉资产")
	var mounted_crowd_visuals := 0
	for pedestrian in city.pedestrians:
		var pedestrian_visual := pedestrian.get_node_or_null("Visual") as Node3D
		if pedestrian_visual != null and is_instance_valid(pedestrian_visual):
			mounted_crowd_visuals += 1
	_require(mounted_crowd_visuals >= 4, "城市主场景挂载的人群候选视觉资产少于四个")
	if city.city_scene_visuals != null and is_instance_valid(city.city_scene_visuals):
		city.city_scene_visuals.apply_runtime_state("city-01", "expanded_runtime_mount")
		_require(str(city.city_scene_visuals.get("active_state")) == "city-01", "城市主场景没有进入 city-01 视觉状态")
		_require(not (city.city_scene_visuals.get_meta("visual_state_contract", {}) as Dictionary).is_empty(), "城市 city-01 没有视觉契约")
	city.city_scene_visuals.apply_runtime_context({"store_transition": true})
	_require_city_contract(city, "city-store-transition", "扩展店内过渡门框")
	_record("city-store-transition", "city", start)

	start = failures.size()
	var roles := {}
	for pedestrian in city.pedestrians:
		roles[str(pedestrian.role_id)] = true
	_require(city.pedestrians.size() >= 4, "城市人群数量不足四类")
	_require(roles.size() >= 4, "城市人群角色变体不足四类")
	_record("city-crowd-variants", "city", start)

	start = failures.size()
	_require(city.traffic_vehicles.size() >= 2, "城市交通实体不足两个")
	city.city_scene_visuals.apply_runtime_context({"traffic_active": true, "traffic_signal_red": true})
	_require_city_contract(city, "city-traffic-near-miss", "扩展交通近失停止线")
	city.city_scene_visuals.apply_runtime_state("city-09", "expanded_runtime_traffic")
	city.city_scene_visuals.apply_runtime_context({"traffic_active": true, "traffic_signal_red": true})
	_require(str(city.city_scene_visuals.get("active_state")) == "city-09", "城市主场景没有进入 city-09 驾驶视觉状态")
	var city_visual_root = city.city_scene_visuals.get("state_root") as Node3D
	_require(city_visual_root != null and is_instance_valid(city_visual_root), "城市 city-09 没有运行时视觉根")
	if city_visual_root != null and is_instance_valid(city_visual_root):
		var red_signal := city_visual_root.find_child("状态驾驶交通信号红灯", true, false) as MeshInstance3D
		_require(red_signal != null, "城市 city-09 缺少交通信号视觉层")
	_record("city-traffic-near-miss", "city", start)

	start = failures.size()
	MatrixPlanClass._setup_city(city, "city-06")
	city.player.position = Vector3(-4.0, 0.9, -4.0)
	_require(city.enter_neighborhood_extension(), "城市新街区入口没有进入成功")
	city.city_scene_visuals.apply_runtime_context({"neighborhood_active": true})
	_require(city.neighborhood_status == "active", "城市新街区状态没有落地")
	_require_city_contract(city, "city-neighborhood-extension", "扩展街区仓储后墙")
	_record("city-neighborhood-extension", "city_expansion", start)

	start = failures.size()
	_require(city.apply_visual_profile("rain_after"), "城市雨后视觉配置没有应用")
	city.city_scene_visuals.apply_runtime_context({"weather_profile": "rain_after"})
	_require(city.weather_profile == "rain_after", "城市天气状态没有落地")
	_require_city_contract(city, "city-weather-lighting-extension", "扩展雨后主路积水面")
	_record("city-weather-lighting-extension", "city_expansion", start)

	start = failures.size()
	MatrixPlanClass._setup_city(city, "city-08")
	city.vehicle.position = Vector3(5.0, 0.7, 3.0)
	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	if city.vehicle.driver == null:
		var enter = InputFrameClass.new()
		enter.vehicle_enter_exit = true
		city.process_input_frame(enter, 0.016)
	_require(city.vehicle.driver != null, "城市载具损伤前没有进入三轮车")
	_require(city.apply_vehicle_collision_damage(62.0, "结构完整性测试车辆"), "城市载具损伤没有生成")
	city.city_scene_visuals.apply_runtime_context({"vehicle_integrity": city.vehicle_integrity})
	_require(city.vehicle_integrity < 100.0, "城市载具耐久没有下降")
	_require_city_contract(city, "city-vehicle-damage-feedback", "扩展载具损伤提示")
	_record("city-vehicle-damage-feedback", "city", start)

	start = failures.size()
	MatrixPlanClass._setup_city(city, "city-11")
	for _index in range(city.mission.stages.size() + 1):
		city.mission.complete_current()
	city.city_scene_visuals.apply_runtime_context({
		"delivery_completed": true,
		"delivery_reward": city.mission.money,
		"delivery_stars": city.mission.stars,
	})
	_require(city.mission.status == MissionChainClass.Status.SUCCESS, "城市交付任务没有进入成功状态")
	_require_city_contract(city, "city-delivery-completion", "扩展交付完成结算牌")
	_record("city-delivery-completion", "city", start)
	city.queue_free()
	await process_frame

func _require_city_contract(city, contract_id: String, required_node: String) -> void:
	var context_root = city.city_scene_visuals.get("context_root")
	_require(context_root != null and is_instance_valid(context_root), contract_id + " 缺少运行时视觉上下文根")
	if context_root == null or not is_instance_valid(context_root):
		return
	var contracts: Array = context_root.get_meta("expanded_visual_contracts", [])
	var found := false
	for contract in contracts:
		if str(contract.get("id", "")) == contract_id:
			found = true
			break
	_require(found, contract_id + " 没有注册运行时视觉契约")
	_require(context_root.find_child(required_node, true, false) != null, contract_id + " 缺少关键场景层：" + required_node)

func _record(identifier: String, scope: String, failure_start: int) -> void:
	results.append({
		"id": identifier,
		"scope": scope,
		"status": "passed" if failures.size() == failure_start else "failed",
		"runtime_structure": "verified",
		"current_source_graphical_capture": "unverified",
		"visual_acceptance": "unverified",
	})

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _has_candidate_visual_mesh(root_node: Node) -> bool:
	if root_node == null or not is_instance_valid(root_node):
		return false
	if bool(root_node.get_meta("candidate_visual_only", false)):
		return true
	for mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		if bool(mesh.get_meta("candidate_visual_only", false)):
			return true
	return false

func _write_evidence(status: String) -> void:
	var evidence_path := ProjectSettings.globalize_path("res://../reference-evidence/candidate-runtime/expanded-visual-runtime-completeness.json")
	DirAccess.make_dir_recursive_absolute(evidence_path.get_base_dir())
	var file := FileAccess.open(evidence_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"status": status,
		"expected_count": EXPECTED_IDS.size(),
		"passed_count": results.filter(func(item): return item.get("status") == "passed").size(),
		"results": results,
		"failures": failures,
		"visual_acceptance": "unverified",
		"release_allowed": false,
		"evidence_boundary": "runtime_structure_and_state_only_not_framewise_visual_signoff",
		"generated_at": Time.get_datetime_string_from_system(true),
	}, "\t") + "\n")

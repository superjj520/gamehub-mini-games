extends SceneTree

const MissionStateClass = preload("res://scripts/mission_state.gd")
const PerceptionStateClass = preload("res://scripts/perception_state.gd")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const ReplayTapeClass = preload("res://scripts/replay_tape.gd")
const SaveStoreClass = preload("res://scripts/save_store.gd")
const InteractionTargetClass = preload("res://scripts/interaction_target.gd")
const VehicleClass = preload("res://scripts/vehicle_controller.gd")
const MissionChainClass = preload("res://scripts/mission_chain.gd")
const InventoryStateClass = preload("res://scripts/inventory_state.gd")
const ConflictStateClass = preload("res://scripts/conflict_state.gd")
const TraceRecorderClass = preload("res://scripts/trace_recorder.gd")
const ContentPackLoaderClass = preload("res://scripts/content_pack_loader.gd")
const InputActionsClass = preload("res://scripts/input_actions.gd")
const AudioEventRouterClass = preload("res://scripts/audio_event_router.gd")
const SettingsStoreClass = preload("res://scripts/settings_store.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")

func _init() -> void:
	InputActionsClass.ensure_defaults()
	for action_name in InputActionsClass.ACTIONS:
		assert(InputMap.has_action(action_name), "输入动作没有注册：" + action_name)
	for action_name in ["move_left", "move_right", "move_forward", "move_back", "look_left", "look_right", "look_up", "look_down"]:
		var axis_events := InputMap.action_get_events(action_name)
		assert(is_equal_approx(InputMap.action_get_deadzone(action_name), InputActionsClass.GAMEPAD_DEADZONE), "手柄轴动作死区没有锁定：" + action_name)
		var has_keyboard := false
		var has_gamepad := false
		for event in axis_events:
			if event is InputEventKey:
				has_keyboard = true
			if event is InputEventJoypadMotion:
				has_gamepad = true
		assert(has_keyboard, "动作缺少键盘映射：" + action_name)
		assert(has_gamepad, "动作缺少手柄轴映射：" + action_name)
	for action_name in ["crouch", "interact", "restart", "vehicle_enter_exit", "load_checkpoint", "attack", "dodge", "pause"]:
		var button_events := InputMap.action_get_events(action_name)
		var has_keyboard := false
		var has_gamepad := false
		for event in button_events:
			if event is InputEventKey:
				has_keyboard = true
			if event is InputEventJoypadButton:
				has_gamepad = true
		assert(has_keyboard, "动作缺少键盘按键映射：" + action_name)
		assert(has_gamepad, "动作缺少手柄按键映射：" + action_name)
	assert(InputMap.action_get_events("look_right").size() >= 2, "镜头右转没有键盘和手柄映射")
	var pause_has_start := false
	for event in InputMap.action_get_events("pause"):
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START:
			pause_has_start = true
	assert(pause_has_start, "暂停动作没有手柄开始键映射")
	var asset_catalog := AssetRuntimeCatalogClass.load_json("res://content/asset-runtime-catalog.json")
	assert(AssetRuntimeCatalogClass.validate(asset_catalog).is_empty(), "资产运行时目录校验失败")
	var invalid_asset_catalog: Dictionary = asset_catalog.duplicate(true)
	invalid_asset_catalog["slots"][0]["scene_path"] = "res://tests/missing-asset-scene.tscn"
	assert(not AssetRuntimeCatalogClass.validate(invalid_asset_catalog).is_empty(), "不存在的资产路径没有被目录校验阻断")
	var invalid_required_catalog: Dictionary = asset_catalog.duplicate(true)
	invalid_required_catalog["slots"][0]["scene_path"] = "res://tests/missing-asset-scene.tscn"
	invalid_required_catalog["slots"][0]["fallback_policy"] = "forbid"
	assert(not AssetRuntimeCatalogClass.validate(invalid_required_catalog).is_empty(), "禁止回退的缺失资产没有被目录校验阻断")
	var silence_router := AudioEventRouterClass.new()
	silence_router.enabled = true
	var stale_audio_player := AudioStreamPlayer.new()
	silence_router.active_players.append(stale_audio_player)
	silence_router.silence()
	assert(not silence_router.enabled, "音频静音接口没有关闭播放")
	assert(silence_router.active_players.is_empty(), "音频静音接口没有清理活动播放器")
	assert(not is_instance_valid(stale_audio_player), "音频静音接口没有释放脱离场景的播放器")
	silence_router.free()
	var asset_parent := Node3D.new()
	var asset_fallback := Node3D.new()
	# 当前正式目录已经绑定了可加载的原创候选场景；灰盒分支要用显式
	# 的缺失资源夹具验证，不能把“候选成功挂载”误报成回退失败。
	var fallback_catalog: Dictionary = asset_catalog.duplicate(true)
	fallback_catalog["slots"][0]["scene_path"] = ""
	fallback_catalog["slots"][0]["fallback_policy"] = "procedural_graybox"
	var asset_mount := AssetRuntimeCatalogClass.mount_optional_visual(asset_parent, fallback_catalog, "player-character", asset_fallback)
	assert(asset_mount.get("used_fallback", false), "显式灰盒目录没有使用灰盒回退")
	assert(asset_parent.get_child_count() == 1 and asset_parent.get_child(0) == asset_fallback, "灰盒回退没有挂到资产根节点")
	asset_parent.free()
	var override_catalog: Dictionary = asset_catalog.duplicate(true)
	override_catalog["slots"][0]["scene_path"] = "res://tests/asset_override_fixture.tscn"
	var override_parent := Node3D.new()
	var override_fallback := Node3D.new()
	var override_mount := AssetRuntimeCatalogClass.mount_optional_visual(override_parent, override_catalog, "player-character", override_fallback)
	assert(not override_mount.get("used_fallback", true), "有效 scene_path 没有挂载资产覆盖")
	assert(override_parent.get_child_count() == 1 and override_parent.get_child(0).name == "Visual", "资产覆盖没有使用契约根节点名称")
	assert(not is_instance_valid(override_fallback), "资产覆盖成功后未释放未挂树的灰盒回退节点")
	override_parent.free()
	var blocked_catalog: Dictionary = asset_catalog.duplicate(true)
	blocked_catalog["slots"][0]["scene_path"] = "res://tests/missing-asset-scene.tscn"
	blocked_catalog["slots"][0]["fallback_policy"] = "forbid"
	var blocked_parent := Node3D.new()
	var blocked_fallback := Node3D.new()
	var blocked_mount := AssetRuntimeCatalogClass.mount_optional_visual(blocked_parent, blocked_catalog, "player-character", blocked_fallback)
	assert(blocked_mount.get("blocked", false), "禁止回退的缺失资产没有返回 blocked")
	assert(not blocked_mount.get("used_fallback", true), "禁止回退的缺失资产错误使用灰盒")
	assert(blocked_parent.get_child_count() == 0, "禁止回退的缺失资产仍挂载了灰盒")
	assert(not is_instance_valid(blocked_fallback), "禁止回退的缺失资产没有释放灰盒节点")
	blocked_parent.free()
	var mission = MissionStateClass.new()
	assert(mission.status == MissionStateClass.Status.NOT_STARTED, "任务初始状态错误")
	mission.start()
	assert(mission.status == MissionStateClass.Status.ACTIVE, "任务没有进入进行中")
	mission.tick(1)
	assert(mission.clock_minutes == 18 * 60, "时间推进不符合预期")
	mission.fail("测试发现")
	assert(mission.status == MissionStateClass.Status.FAILED, "失败状态没有生效")
	mission.restart()
	assert(mission.status == MissionStateClass.Status.ACTIVE, "重试没有恢复任务")
	mission.complete()
	assert(mission.status == MissionStateClass.Status.SUCCESS, "成功状态没有生效")
	var timed_mission = MissionStateClass.new()
	timed_mission.completion_minute = 18 * 60
	timed_mission.start()
	assert(not timed_mission.complete(), "准点任务在时间未到时错误完成")
	timed_mission.tick(1)
	assert(timed_mission.complete(), "准点任务到时后没有完成")
	var retry_timed_mission = MissionStateClass.new()
	retry_timed_mission.completion_minute = 18 * 60
	retry_timed_mission.start()
	retry_timed_mission.fail("测试发现")
	retry_timed_mission.restart()
	assert(not retry_timed_mission.complete(), "准点任务重试后错误丢失下班时间条件")

	var perception = PerceptionStateClass.new()
	for index in range(8):
		perception.observe(true, 0.2, Vector3(1, 0, 1))
	assert(perception.status == PerceptionStateClass.Status.ALERT, "NPC感知没有进入发现状态")
	perception.reset()
	assert(perception.status == PerceptionStateClass.Status.CALM, "NPC感知重置失败")

	var input_frame = InputFrameClass.new()
	input_frame.move = Vector2(0.0, -1.0)
	input_frame.look = Vector2(12.0, -4.0)
	input_frame.crouch = true
	input_frame.interact = true
	input_frame.restart = true
	input_frame.vehicle_enter_exit = true
	input_frame.load_checkpoint = true
	input_frame.attack = true
	input_frame.dodge = true
	var tape: ReplayTape = ReplayTapeClass.new()
	tape.append(input_frame)
	var restored_tape: ReplayTape = ReplayTapeClass.from_json(tape.to_json())
	assert(restored_tape.size() == 1, "回放帧数量没有恢复")
	var restored_frame = restored_tape.frame_at(0)
	assert(restored_frame.move == Vector2(0.0, -1.0), "回放移动输入没有恢复")
	assert(restored_frame.look == Vector2(12.0, -4.0), "回放镜头输入没有恢复")
	assert(restored_frame.crouch and restored_frame.interact, "回放动作输入没有恢复")
	assert(restored_frame.restart, "回放重启输入没有恢复")
	assert(restored_frame.vehicle_enter_exit, "回放上下车输入没有恢复")
	assert(restored_frame.load_checkpoint, "回放读取存档输入没有恢复")
	assert(restored_frame.attack, "回放攻击输入没有恢复")
	assert(restored_frame.dodge, "回放闪避输入没有恢复")
	var malformed_tape: ReplayTape = ReplayTapeClass.from_json("不是 JSON")
	assert(malformed_tape.size() == 0 and not malformed_tape.last_error.is_empty(), "损坏回放没有暴露解析错误")
	var unsupported_version_tape: ReplayTape = ReplayTapeClass.from_json(JSON.stringify({"version": 2, "frames": []}))
	assert(unsupported_version_tape.size() == 0 and not unsupported_version_tape.last_error.is_empty(), "不支持的回放版本没有被拒绝")
	var invalid_frame_tape: ReplayTape = ReplayTapeClass.from_json(JSON.stringify({
		"version": 1,
		"frames": [{"x": "非法", "y": 0.0, "look_x": 0.0, "look_y": 0.0, "crouch": false, "interact": false, "restart": false, "vehicle_enter_exit": false, "load_checkpoint": false, "attack": false, "dodge": false}]
	}))
	assert(invalid_frame_tape.size() == 0 and not invalid_frame_tape.last_error.is_empty(), "非法输入帧没有被拒绝")
	var oversized_frame_tape: ReplayTape = ReplayTapeClass.from_json(JSON.stringify({
		"version": 1,
		"frames": [{"x": 2.0, "y": 0.0, "look_x": 0.0, "look_y": 0.0, "crouch": false, "interact": false, "restart": false, "vehicle_enter_exit": false, "load_checkpoint": false, "attack": false, "dodge": false}]
	}))
	assert(oversized_frame_tape.size() == 0 and not oversized_frame_tape.last_error.is_empty(), "超出移动幅度上限的回放没有被拒绝")
	var unsafe_frame := InputFrameClass.new()
	unsafe_frame.move = Vector2(INF, 0.0)
	unsafe_frame.look = Vector2(500.0, 0.0)
	unsafe_frame.sanitize()
	assert(unsafe_frame.move == Vector2.ZERO, "非有限移动输入没有被安全归一化")
	assert(unsafe_frame.look.length() <= InputFrameClass.MAX_LOOK_DELTA_PER_FRAME + 0.0001, "镜头输入归一化没有限制单帧幅度")

	var save_path := OS.get_temp_dir().path_join("reference_smoke_checkpoint.json")
	var store: SaveStore = SaveStoreClass.new(save_path)
	mission.clock_minutes = 1088
	mission.failure_reason = "测试状态"
	perception.status = PerceptionStateClass.Status.SUSPICIOUS
	perception.suspicion = 0.55
	assert(store.save_checkpoint(mission, perception, Vector3(2.0, 1.0, 3.0), {"yaw": 35.0, "pitch": -20.0}, {}, "office-smoke-v1"), "存档写入失败")
	var loaded_mission: MissionState = MissionStateClass.new()
	var loaded_perception: PerceptionState = PerceptionStateClass.new()
	assert(store.load_checkpoint(loaded_mission, loaded_perception, null, null, null, "office-smoke-v1"), "存档读取失败")
	assert(not store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new()), "省略内容包标识的办公室读取没有被拒绝")
	var office_payload = JSON.parse_string(FileAccess.get_file_as_string(store.save_path))
	assert(office_payload.get("player_position", {}).get("x") == 2.0, "办公室玩家位置没有写入存档")
	assert(office_payload.get("camera", {}).get("yaw") == 35.0, "办公室镜头朝向没有写入存档")
	assert(office_payload.get("content_pack_id", "") == "office-smoke-v1", "办公室存档没有绑定内容包标识")
	assert(loaded_mission.clock_minutes == 1088, "任务时间没有从存档恢复")
	assert(loaded_mission.failure_reason == "测试状态", "任务字段没有从存档恢复")
	assert(loaded_perception.status == PerceptionStateClass.Status.SUSPICIOUS, "NPC状态没有从存档恢复")
	assert(is_equal_approx(loaded_perception.suspicion, 0.55), "NPC警觉值没有从存档恢复")
	assert(not store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, "office-other-v2"), "办公室不同内容包的存档没有被拒绝")
	var malformed_content_pack_path := OS.get_temp_dir().path_join("reference-malformed-content-pack-%d.json" % Time.get_ticks_usec())
	var malformed_content_pack_payload: Dictionary = office_payload.duplicate(true)
	malformed_content_pack_payload["content_pack_id"] = 17
	var malformed_content_pack_file := FileAccess.open(malformed_content_pack_path, FileAccess.WRITE)
	malformed_content_pack_file.store_string(JSON.stringify(malformed_content_pack_payload))
	malformed_content_pack_file = null
	var malformed_content_pack_store: SaveStore = SaveStoreClass.new(malformed_content_pack_path)
	assert(not malformed_content_pack_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, "office-smoke-v1"), "非字符串内容包标识没有被拒绝")
	mission.clock_minutes = 1089
	assert(store.save_checkpoint(mission, perception), "第二次存档写入失败")
	assert(FileAccess.file_exists(save_path + ".bak"), "第二次存档没有生成备份")
	var corrupt_file := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt_file.store_string("{}")
	corrupt_file = null
	var recovered_mission: MissionState = MissionStateClass.new()
	var recovered_perception: PerceptionState = PerceptionStateClass.new()
	assert(store.load_checkpoint(recovered_mission, recovered_perception, null, null, null, ""), "主档损坏后没有从备份恢复")
	assert(recovered_mission.clock_minutes == 1088, "备份存档没有恢复到上一份有效状态")
	var malformed_path := OS.get_temp_dir().path_join("reference-malformed-checkpoint-%d.json" % Time.get_ticks_usec())
	var malformed_file := FileAccess.open(malformed_path, FileAccess.WRITE)
	malformed_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "office",
		"mission": {"status": 0, "clock_minutes": 1079, "objective": "准点下班", "failure_reason": "", "completion_minute": -1},
		"perception": {"status": 0, "suspicion": 0.0, "last_seen_position": "被篡改"},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"camera": {},
		"vehicle": {}
	}))
	malformed_file = null
	var malformed_store: SaveStore = SaveStoreClass.new(malformed_path)
	assert(not malformed_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "办公室恶意字段没有被安全拒绝")
	var malformed_camera_path := OS.get_temp_dir().path_join("reference-malformed-camera-%d.json" % Time.get_ticks_usec())
	var malformed_camera_file := FileAccess.open(malformed_camera_path, FileAccess.WRITE)
	malformed_camera_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "office",
		"mission": {"status": 0, "clock_minutes": 1079, "objective": "准点下班", "failure_reason": "", "completion_minute": -1},
		"perception": {"status": 0, "suspicion": 0.0, "last_seen_position": {"x": 0.0, "y": 0.0, "z": 0.0}},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"camera": {"yaw": "篡改"},
		"vehicle": {}
	}))
	malformed_camera_file = null
	var malformed_camera_store: SaveStore = SaveStoreClass.new(malformed_camera_path)
	assert(not malformed_camera_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "办公室镜头深层恶意字段没有被安全拒绝")
	var malformed_vehicle_path := OS.get_temp_dir().path_join("reference-malformed-vehicle-%d.json" % Time.get_ticks_usec())
	var malformed_vehicle_file := FileAccess.open(malformed_vehicle_path, FileAccess.WRITE)
	malformed_vehicle_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "office",
		"mission": {"status": 0, "clock_minutes": 1079, "objective": "准点下班", "failure_reason": "", "completion_minute": -1},
		"perception": {"status": 0, "suspicion": 0.0, "last_seen_position": {"x": 0.0, "y": 0.0, "z": 0.0}},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"camera": {},
		"vehicle": {"position": {"x": 0.0, "y": 0.0, "z": 0.0}, "has_driver": "是"}
	}))
	malformed_vehicle_file = null
	var malformed_vehicle_store: SaveStore = SaveStoreClass.new(malformed_vehicle_path)
	assert(not malformed_vehicle_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "办公室载具深层恶意字段没有被安全拒绝")
	var missing_office_core_path := OS.get_temp_dir().path_join("reference-missing-office-core-%d.json" % Time.get_ticks_usec())
	var missing_office_core_file := FileAccess.open(missing_office_core_path, FileAccess.WRITE)
	missing_office_core_file.store_string(JSON.stringify({"version": 2, "kind": "office"}))
	missing_office_core_file = null
	var missing_office_core_store: SaveStore = SaveStoreClass.new(missing_office_core_path)
	assert(not missing_office_core_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "缺少办公室核心字段的存档没有被拒绝")
	var malformed_version_path := OS.get_temp_dir().path_join("reference-malformed-version-%d.json" % Time.get_ticks_usec())
	var malformed_version_file := FileAccess.open(malformed_version_path, FileAccess.WRITE)
	malformed_version_file.store_string(JSON.stringify({"version": 2.9, "kind": "office"}))
	malformed_version_file = null
	var malformed_version_store: SaveStore = SaveStoreClass.new(malformed_version_path)
	assert(not malformed_version_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "非整数存档版本没有被拒绝")
	var decimal_version_path := OS.get_temp_dir().path_join("reference-decimal-version-%d.json" % Time.get_ticks_usec())
	var decimal_save_version_file := FileAccess.open(decimal_version_path, FileAccess.WRITE)
	decimal_save_version_file.store_string("{\"version\":2.0,\"kind\":\"office\"}")
	decimal_save_version_file = null
	var decimal_version_store: SaveStore = SaveStoreClass.new(decimal_version_path)
	assert(not decimal_version_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "整数值浮点存档版本没有被拒绝")
	var interfering_version_path := OS.get_temp_dir().path_join("reference-interfering-version-%d.json" % Time.get_ticks_usec())
	var interfering_version_file := FileAccess.open(interfering_version_path, FileAccess.WRITE)
	interfering_version_file.store_string(JSON.stringify({
		"note": "\\\"version\\\":2",
		"metadata": {"version": 2},
		"events": [{"version": 2}],
		"version": 2,
		"kind": "office",
		"mission": {"status": 0, "clock_minutes": 1079, "objective": "准点下班", "failure_reason": "", "completion_minute": -1},
		"perception": {"status": 0, "suspicion": 0.0, "last_seen_position": {"x": 0.0, "y": 0.0, "z": 0.0}},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"camera": {},
		"vehicle": {}
	}))
	interfering_version_file = null
	var interfering_version_store: SaveStore = SaveStoreClass.new(interfering_version_path)
	assert(interfering_version_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "字符串、嵌套对象和数组中的伪造版本字段干扰了存档版本校验")
	var duplicate_version_path := OS.get_temp_dir().path_join("reference-duplicate-version-%d.json" % Time.get_ticks_usec())
	var duplicate_version_file := FileAccess.open(duplicate_version_path, FileAccess.WRITE)
	duplicate_version_file.store_string("{\"version\":2,\"version\":2.0,\"kind\":\"office\"}")
	duplicate_version_file = null
	var duplicate_version_store: SaveStore = SaveStoreClass.new(duplicate_version_path)
	assert(not duplicate_version_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "重复顶层存档版本键没有被拒绝")
	var escaped_duplicate_version_path := OS.get_temp_dir().path_join("reference-escaped-duplicate-version-%d.json" % Time.get_ticks_usec())
	var escaped_duplicate_version_file := FileAccess.open(escaped_duplicate_version_path, FileAccess.WRITE)
	escaped_duplicate_version_file.store_string("{\"\\u0076ersion\":2.9,\"version\":2,\"kind\":\"office\"}")
	escaped_duplicate_version_file = null
	var escaped_duplicate_version_store: SaveStore = SaveStoreClass.new(escaped_duplicate_version_path)
	assert(not escaped_duplicate_version_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "Unicode 转义等价的重复存档版本键没有被拒绝")
	var malformed_status_path := OS.get_temp_dir().path_join("reference-malformed-status-%d.json" % Time.get_ticks_usec())
	var malformed_status_file := FileAccess.open(malformed_status_path, FileAccess.WRITE)
	malformed_status_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "office",
		"mission": {"status": 9, "clock_minutes": 1079, "objective": "准点下班", "failure_reason": "", "completion_minute": -1},
		"perception": {"status": 0, "suspicion": 0.0, "last_seen_position": {"x": 0.0, "y": 0.0, "z": 0.0}},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"camera": {},
		"vehicle": {}
	}))
	malformed_status_file = null
	var malformed_status_store: SaveStore = SaveStoreClass.new(malformed_status_path)
	assert(not malformed_status_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "越界任务状态没有被拒绝")
	mission.clock_minutes = 1088

	var legacy_path := OS.get_temp_dir().path_join("reference_legacy_checkpoint.json")
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({
		"version": 1,
		"mission": mission.snapshot(),
		"perception": {
			"status": perception.status,
			"suspicion": perception.suspicion,
			"last_seen_position": {"x": 1.0, "y": 0.0, "z": 2.0}
		}
	}))
	legacy_file = null
	var legacy_store: SaveStore = SaveStoreClass.new(legacy_path)
	var migrated_mission: MissionState = MissionStateClass.new()
	var migrated_perception: PerceptionState = PerceptionStateClass.new()
	assert(legacy_store.load_checkpoint(migrated_mission, migrated_perception, null, null, null, ""), "旧版本存档没有迁移成功")
	assert(migrated_mission.clock_minutes == 1088, "旧版本存档迁移后任务时间错误")
	assert(not legacy_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, "office-smoke-v1"), "旧版本无内容包标识存档不应进入绑定内容包")

	var future_path := OS.get_temp_dir().path_join("reference_future_checkpoint.json")
	var future_file := FileAccess.open(future_path, FileAccess.WRITE)
	future_file.store_string(JSON.stringify({"version": 999, "kind": "office"}))
	future_file = null
	var future_store: SaveStore = SaveStoreClass.new(future_path)
	assert(not future_store.load_checkpoint(MissionStateClass.new(), PerceptionStateClass.new(), null, null, null, ""), "未知未来版本没有被安全拒绝")

	var invalid_store: SaveStore = SaveStoreClass.new("/definitely_missing_gta_reference_parent/checkpoint.json")
	assert(not invalid_store.save_checkpoint(mission, perception), "无效存档路径没有失败")
	assert(not invalid_store.last_error.is_empty(), "存档失败没有留下可观测错误")

	var actor := CharacterBody3D.new()
	actor.position = Vector3.ZERO
	var actor_collision := CollisionShape3D.new()
	var actor_box := BoxShape3D.new()
	actor_box.size = Vector3(0.8, 1.8, 0.8)
	actor_collision.shape = actor_box
	actor.add_child(actor_collision)
	var actor_disabled_collision := CollisionShape3D.new()
	var actor_disabled_box := BoxShape3D.new()
	actor_disabled_box.size = Vector3(0.6, 0.6, 0.6)
	actor_disabled_collision.shape = actor_disabled_box
	actor_disabled_collision.disabled = true
	actor.add_child(actor_disabled_collision)
	var target = InteractionTargetClass.new()
	target.position = Vector3(1.0, 0.0, 0.0)
	target.interaction_radius = 2.0
	target.one_shot = true
	assert(target.can_interact(actor.position), "交互距离判断错误")
	assert(target.try_interact(actor, true), "交互没有触发")
	assert(not target.try_interact(actor, true), "一次性交互被重复触发")

	var vehicle = VehicleClass.new()
	vehicle.position = Vector3(0.0, 0.0, 1.0)
	assert(vehicle.can_enter(actor), "载具进入距离判断错误")
	assert(vehicle.enter(actor), "载具进入失败")
	assert(vehicle.driver == actor, "载具没有记录驾驶者")
	assert(actor.visible, "载具进入后驾驶者不应从视觉中消失")
	assert(actor.position.distance_to(vehicle.driver_seat_position()) < 0.001, "驾驶者没有挂到载具座椅位置")
	assert(actor_collision.disabled, "进入载具后玩家碰撞体没有暂时禁用")
	assert(actor_disabled_collision.disabled, "进入载具后玩家原本禁用的碰撞体被错误启用")
	assert(not vehicle.enter(actor), "已有驾驶者时载具被重复进入")
	vehicle.velocity = Vector3(3.0, 0.0, 1.0)
	assert(vehicle.exit(), "载具退出失败")
	assert(vehicle.driver == null, "载具没有清除驾驶者")
	assert(actor.visible, "载具退出后驾驶者没有恢复可见")
	assert(not actor_collision.disabled, "退出载具后玩家碰撞体没有恢复")
	assert(actor_disabled_collision.disabled, "退出载具后玩家原本禁用的碰撞体状态没有恢复")
	assert(vehicle.velocity == Vector3.ZERO, "退出载具后 CharacterBody3D 速度没有清零")
	assert(not vehicle.exit(), "没有驾驶者时载具错误退出")
	assert(not vehicle.can_enter(null), "空节点错误通过载具进入检查")

	actor.free()
	target.free()
	vehicle.free()

	var stale_can_enter_vehicle = VehicleClass.new()
	stale_can_enter_vehicle.position = Vector3.ZERO
	var stale_can_enter_events: Array[bool] = []
	stale_can_enter_vehicle.driver_changed.connect(func(has_driver: bool): stale_can_enter_events.append(has_driver))
	_enter_then_free_driver(stale_can_enter_vehicle)
	stale_can_enter_vehicle.current_speed = 3.0
	stale_can_enter_vehicle.velocity = Vector3(2.0, 0.0, 1.0)
	var can_enter_actor := CharacterBody3D.new()
	can_enter_actor.position = stale_can_enter_vehicle.position
	assert(stale_can_enter_vehicle.can_enter(can_enter_actor), "can_enter 清理失效驾驶者后没有允许有效玩家重新进入")
	assert(stale_can_enter_vehicle.driver == null, "can_enter 没有清理失效驾驶者引用")
	assert(is_zero_approx(stale_can_enter_vehicle.current_speed), "can_enter 清理失效驾驶者后没有归零速度")
	assert(stale_can_enter_vehicle.velocity == Vector3.ZERO, "can_enter 清理失效驾驶者后没有清零运动速度")
	assert(not stale_can_enter_events.is_empty() and not stale_can_enter_events[-1], "can_enter 清理失效驾驶者没有发出退出事件")
	can_enter_actor.free()
	stale_can_enter_vehicle.free()

	var stale_apply_vehicle = VehicleClass.new()
	stale_apply_vehicle.position = Vector3.ZERO
	_enter_then_free_driver(stale_apply_vehicle)
	stale_apply_vehicle.current_speed = 3.0
	stale_apply_vehicle.velocity = Vector3(2.0, 0.0, 1.0)
	stale_apply_vehicle.apply_input(InputFrameClass.new(), 0.016)
	assert(stale_apply_vehicle.driver == null, "apply_input 没有清理失效驾驶者引用")
	assert(is_zero_approx(stale_apply_vehicle.current_speed), "apply_input 清理失效驾驶者后没有归零速度")
	assert(stale_apply_vehicle.velocity == Vector3.ZERO, "apply_input 清理失效驾驶者后没有清零运动速度")
	stale_apply_vehicle.free()

	var stale_snapshot_vehicle = VehicleClass.new()
	stale_snapshot_vehicle.position = Vector3.ZERO
	_enter_then_free_driver(stale_snapshot_vehicle)
	stale_snapshot_vehicle.velocity = Vector3(2.0, 0.0, 1.0)
	var stale_snapshot: Dictionary = stale_snapshot_vehicle.snapshot()
	assert(stale_snapshot_vehicle.driver == null, "snapshot 没有清理失效驾驶者引用")
	assert(not stale_snapshot.get("has_driver", true), "snapshot 清理失效驾驶者后仍报告有人驾驶")
	assert(stale_snapshot_vehicle.velocity == Vector3.ZERO, "snapshot 清理失效驾驶者后没有清零运动速度")
	stale_snapshot_vehicle.free()

	var stale_exit_vehicle = VehicleClass.new()
	stale_exit_vehicle.position = Vector3.ZERO
	var stale_exit_events: Array[bool] = []
	stale_exit_vehicle.driver_changed.connect(func(has_driver: bool): stale_exit_events.append(has_driver))
	_enter_then_free_driver(stale_exit_vehicle)
	stale_exit_vehicle.velocity = Vector3(2.0, 0.0, 1.0)
	assert(not stale_exit_vehicle.exit(), "exit 对失效驾驶者错误报告退出成功")
	assert(stale_exit_vehicle.driver == null, "exit 没有清理失效驾驶者引用")
	assert(stale_exit_vehicle.velocity == Vector3.ZERO, "exit 清理失效驾驶者后没有清零运动速度")
	assert(not stale_exit_events.is_empty() and not stale_exit_events[-1], "exit 清理失效驾驶者没有发出退出事件")
	stale_exit_vehicle.free()

	var chain = MissionChainClass.new()
	chain.configure([
		{"id": "one", "objective": "第一步", "reward": 10, "stars": 1},
		{"id": "two", "objective": "第二步", "reward": 20, "stars": 2}
	])
	chain.start()
	assert(chain.current_objective() == "第一步", "任务链初始目标错误")
	assert(chain.complete_current(), "任务链第一阶段没有完成")
	assert(chain.current_objective() == "第二步", "任务链没有切换阶段")
	assert(chain.complete_current(), "任务链第二阶段没有完成")
	assert(chain.status == MissionChainClass.Status.SUCCESS, "任务链没有进入成功状态")
	assert(chain.money == 30 and chain.stars == 3, "任务链奖励没有累计")

	var inventory = InventoryStateClass.new()
	inventory.add_item("egg_tray")
	assert(inventory.has_item("egg_tray"), "物品没有加入库存")
	assert(inventory.remove_item("egg_tray"), "物品没有从库存移除")
	assert(not inventory.has_item("egg_tray"), "物品移除后仍然存在")
	inventory.add_item("egg_tray", 2)
	var inventory_copy = InventoryStateClass.new()
	inventory_copy.restore(inventory.snapshot())
	assert(inventory_copy.count("egg_tray") == 2, "库存存档没有恢复")

	var city_store: SaveStore = SaveStoreClass.new(OS.get_temp_dir().path_join("city_smoke_checkpoint.json"))
	var city_chain = MissionChainClass.new()
	city_chain.configure([{"id": "collect_eggs", "objective": "领取免费鸡蛋", "reward": 30, "stars": 1}])
	city_chain.start()
	var city_inventory = InventoryStateClass.new()
	city_inventory.add_item("egg_tray")
	var city_vehicle_snapshot := {"position": {"x": 6.0, "y": 0.7, "z": 8.0}, "rotation_y": 0.25, "current_speed": 2.5, "has_driver": true}
	assert(city_store.save_city_checkpoint(city_chain, city_inventory, Vector3(3.0, 1.0, 4.0), true, {}, {"yaw": 42.0, "pitch": -18.0}, city_vehicle_snapshot, "city-smoke-v1"), "城市存档写入失败")
	var restored_city_chain = MissionChainClass.new()
	restored_city_chain.configure([{"id": "collect_eggs", "objective": "领取免费鸡蛋", "reward": 30, "stars": 1}])
	var restored_city_inventory = InventoryStateClass.new()
	var city_data = city_store.load_city_checkpoint(restored_city_chain, restored_city_inventory, "city-smoke-v1")
	assert(not city_data.is_empty(), "城市存档读取失败")
	var city_payload = JSON.parse_string(FileAccess.get_file_as_string(city_store.save_path))
	assert(city_payload.get("content_pack_id", "") == "city-smoke-v1", "城市存档没有绑定内容包标识")
	assert(city_store.load_city_checkpoint(MissionChainClass.new(), InventoryStateClass.new(), "city-other-v2").is_empty(), "城市不同内容包的存档没有被拒绝")
	assert(restored_city_inventory.has_item("egg_tray"), "城市库存没有恢复")
	assert(city_data["registered"], "登记状态没有恢复")
	assert(city_data["player_position"] == Vector3(3.0, 1.0, 4.0), "城市玩家位置没有恢复")
	assert(city_data["camera"].get("yaw") == 42.0, "城市镜头朝向没有恢复")
	assert(is_equal_approx(float(city_data["vehicle"].get("position", {}).get("x", 0.0)), 6.0), "城市载具快照没有恢复")
	assert(is_equal_approx(float(city_data["vehicle"].get("current_speed", 0.0)), 2.5), "城市载具速度快照没有恢复")
	assert(bool(city_data["vehicle"].get("has_driver", false)), "城市载具驾驶状态没有恢复")
	var malformed_city_content_pack_path := OS.get_temp_dir().path_join("reference-malformed-city-content-pack-%d.json" % Time.get_ticks_usec())
	var malformed_city_content_pack_payload: Dictionary = city_payload.duplicate(true)
	malformed_city_content_pack_payload["content_pack_id"] = ["city-smoke-v1"]
	var malformed_city_content_pack_file := FileAccess.open(malformed_city_content_pack_path, FileAccess.WRITE)
	malformed_city_content_pack_file.store_string(JSON.stringify(malformed_city_content_pack_payload))
	malformed_city_content_pack_file = null
	var malformed_city_content_pack_store: SaveStore = SaveStoreClass.new(malformed_city_content_pack_path)
	assert(malformed_city_content_pack_store.load_city_checkpoint(MissionChainClass.new(), InventoryStateClass.new(), "city-smoke-v1").is_empty(), "城市非字符串内容包标识没有被拒绝")
	var malformed_city_path := OS.get_temp_dir().path_join("reference-malformed-city-checkpoint-%d.json" % Time.get_ticks_usec())
	var malformed_city_file := FileAccess.open(malformed_city_path, FileAccess.WRITE)
	malformed_city_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "city",
		"mission_chain": {"status": 0, "current_index": -1, "failure_reason": "", "money": 0, "stars": 0},
		"inventory": {},
		"player_position": "被篡改",
		"registered": false,
		"conflict": {},
		"camera": {},
		"vehicle": {}
	}))
	malformed_city_file = null
	var malformed_city_store: SaveStore = SaveStoreClass.new(malformed_city_path)
	assert(malformed_city_store.load_city_checkpoint(MissionChainClass.new(), InventoryStateClass.new(), "").is_empty(), "城市恶意字段没有被安全拒绝")
	var malformed_inventory_path := OS.get_temp_dir().path_join("reference-malformed-inventory-%d.json" % Time.get_ticks_usec())
	var malformed_inventory_file := FileAccess.open(malformed_inventory_path, FileAccess.WRITE)
	malformed_inventory_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "city",
		"mission_chain": {"status": 0, "current_index": -1, "failure_reason": "", "money": 0, "stars": 0},
		"inventory": {"egg_tray": "两"},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"registered": false,
		"conflict": {},
		"camera": {},
		"vehicle": {}
	}))
	malformed_inventory_file = null
	var malformed_inventory_store: SaveStore = SaveStoreClass.new(malformed_inventory_path)
	assert(malformed_inventory_store.load_city_checkpoint(MissionChainClass.new(), InventoryStateClass.new(), "").is_empty(), "城市库存深层恶意字段没有被安全拒绝")
	var malformed_chain_path := OS.get_temp_dir().path_join("reference-malformed-chain-%d.json" % Time.get_ticks_usec())
	var malformed_chain_file := FileAccess.open(malformed_chain_path, FileAccess.WRITE)
	malformed_chain_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "city",
		"mission_chain": {"status": 0, "current_index": 1.5, "failure_reason": "", "money": 0, "stars": 0},
		"inventory": {},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"registered": false,
		"conflict": {},
		"camera": {},
		"vehicle": {}
	}))
	malformed_chain_file = null
	var malformed_chain_store: SaveStore = SaveStoreClass.new(malformed_chain_path)
	assert(malformed_chain_store.load_city_checkpoint(MissionChainClass.new(), InventoryStateClass.new(), "").is_empty(), "城市任务链深层恶意字段没有被安全拒绝")
	var missing_city_core_path := OS.get_temp_dir().path_join("reference-missing-city-core-%d.json" % Time.get_ticks_usec())
	var missing_city_core_file := FileAccess.open(missing_city_core_path, FileAccess.WRITE)
	missing_city_core_file.store_string(JSON.stringify({"version": 2, "kind": "city"}))
	missing_city_core_file = null
	var missing_city_core_store: SaveStore = SaveStoreClass.new(missing_city_core_path)
	assert(missing_city_core_store.load_city_checkpoint(MissionChainClass.new(), InventoryStateClass.new(), "").is_empty(), "缺少城市核心字段的存档没有被拒绝")
	var out_of_bounds_chain_path := OS.get_temp_dir().path_join("reference-out-of-bounds-chain-%d.json" % Time.get_ticks_usec())
	var out_of_bounds_chain_file := FileAccess.open(out_of_bounds_chain_path, FileAccess.WRITE)
	out_of_bounds_chain_file.store_string(JSON.stringify({
		"version": 2,
		"kind": "city",
		"mission_chain": {"status": 1, "current_index": 99, "failure_reason": "", "money": 0, "stars": 0},
		"inventory": {},
		"player_position": {"x": 0.0, "y": 1.0, "z": 0.0},
		"registered": false,
		"conflict": {},
		"camera": {},
		"vehicle": {}
	}))
	out_of_bounds_chain_file = null
	var out_of_bounds_chain_store: SaveStore = SaveStoreClass.new(out_of_bounds_chain_path)
	var out_of_bounds_chain = MissionChainClass.new()
	out_of_bounds_chain.configure([{"id": "only_stage", "objective": "唯一阶段"}])
	assert(out_of_bounds_chain_store.load_city_checkpoint(out_of_bounds_chain, InventoryStateClass.new(), "").is_empty(), "超出内容包阶段数量的城市任务索引没有被拒绝")
	var non_finite_payload: Dictionary = {
		"version": 2,
		"kind": "office",
		"mission": {"status": 0, "clock_minutes": 1079, "objective": "准点下班", "failure_reason": "", "completion_minute": -1},
		"perception": {"status": 0, "suspicion": 0.0, "last_seen_position": {"x": 0.0, "y": 0.0, "z": 0.0}},
		"player_position": {"x": INF, "y": 1.0, "z": 0.0},
		"camera": {},
		"vehicle": {}
	}
	var non_finite_store: SaveStore = SaveStoreClass.new(OS.get_temp_dir().path_join("reference-non-finite-position.json"))
	assert(not non_finite_store._validate_payload(non_finite_payload, true), "非有限玩家位置没有被拒绝")

	var conflict = ConflictStateClass.new()
	conflict.trigger("测试冲突")
	assert(conflict.status == ConflictStateClass.Status.ENGAGED, "冲突没有进入交战状态")
	conflict.pursue()
	assert(conflict.status == ConflictStateClass.Status.PURSUED, "冲突没有进入追踪状态")
	conflict.tick(10.0, true)
	assert(conflict.status == ConflictStateClass.Status.FAILED, "冲突生命归零后没有失败")

	var trace = TraceRecorderClass.new()
	trace.advance(0.25)
	trace.record("interaction", {"id": "collect_eggs"})
	var trace_path := OS.get_temp_dir().path_join("reference-trace-%d.json" % Time.get_ticks_usec())
	assert(trace.save(trace_path), "事件时间轴写入失败")
	assert(FileAccess.file_exists(trace_path), "事件时间轴写入后文件不存在")
	var saved_trace_file := FileAccess.open(trace_path, FileAccess.READ)
	assert(saved_trace_file != null, "事件时间轴写入后无法读取")
	var saved_trace_text := saved_trace_file.get_as_text()
	saved_trace_file.close()
	saved_trace_file = null
	var restored_saved_trace := TraceRecorderClass.from_json(saved_trace_text)
	assert(restored_saved_trace.has_event("interaction"), "写入后的事件时间轴没有恢复")
	DirAccess.remove_absolute(trace_path)
	var restored_trace = TraceRecorderClass.from_json(trace.to_json())
	assert(restored_trace.has_event("interaction"), "事件追踪没有恢复")
	assert(is_equal_approx(restored_trace.events[0]["time"], 0.25), "事件时间没有恢复")
	var malformed_trace = TraceRecorderClass.from_json("不是 JSON")
	assert(malformed_trace.events.is_empty() and not malformed_trace.last_error.is_empty(), "损坏事件时间轴没有暴露解析错误")
	var unsupported_trace = TraceRecorderClass.from_json(JSON.stringify({"version": 2, "events": []}))
	assert(unsupported_trace.events.is_empty() and not unsupported_trace.last_error.is_empty(), "不支持的事件时间轴版本没有被拒绝")
	var invalid_trace = TraceRecorderClass.from_json(JSON.stringify({
		"version": 1,
		"events": [
			{"time": 0.5, "type": "first", "payload": {}},
			{"time": 0.25, "type": "out_of_order", "payload": {}}
		]
	}))
	assert(invalid_trace.events.is_empty() and not invalid_trace.last_error.is_empty(), "非单调事件时间轴没有被拒绝")

	var audio_router = AudioEventRouterClass.new()
	audio_router.emit_event("interaction_success", {"id": "test"})
	assert(audio_router.history.size() == 1, "音频事件路由没有保留事件")
	var audio_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/audio_cues.json"))
	assert(audio_catalog is Dictionary and audio_catalog.get("cues", []).size() > 0, "音频提示音清单数量错误")
	assert(AudioEventRouterClass.validate_cue_catalog(audio_catalog).is_empty(), "音频提示音清单字段校验失败")
	assert(audio_catalog.get("cues", [])[0].get("id") == "interaction_success", "音频事件映射清单没有读取")
	var audio_resource_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/audio-runtime-catalog.json"))
	var expected_audio_event_count: int = audio_catalog.get("cues", []).size() if audio_catalog is Dictionary else 0
	assert(audio_resource_catalog is Dictionary and audio_resource_catalog.get("events", []).size() == expected_audio_event_count, "运行时音频目录数量错误")
	assert(AudioEventRouterClass.validate_audio_resource_catalog(audio_resource_catalog).is_empty(), "运行时音频目录字段校验失败")
	assert(AudioEventRouterClass.validate_catalog_alignment(audio_catalog, audio_resource_catalog).is_empty(), "音频提示音与运行时资源目录没有逐事件对齐")
	var invalid_audio_alignment: Dictionary = audio_resource_catalog.duplicate(true)
	invalid_audio_alignment["events"].pop_back()
	assert(not AudioEventRouterClass.validate_catalog_alignment(audio_catalog, invalid_audio_alignment).is_empty(), "音频目录事件缺失没有被对齐校验阻断")
	var valid_audio_resource_catalog: Dictionary = audio_resource_catalog.duplicate(true)
	valid_audio_resource_catalog["events"][0]["stream_path"] = "res://tests/audio_stream_fixture.tres"
	assert(AudioEventRouterClass.validate_audio_resource_catalog(valid_audio_resource_catalog).is_empty(), "有效 AudioStream 资源路径没有通过目录校验")
	var invalid_audio_resource_catalog: Dictionary = audio_resource_catalog.duplicate(true)
	invalid_audio_resource_catalog["events"][0]["stream_path"] = "res://content/audio_cues.json"
	var invalid_audio_resource_errors := AudioEventRouterClass.validate_audio_resource_catalog(invalid_audio_resource_catalog)
	assert(invalid_audio_resource_errors.any(func(error): return str(error).contains("必须指向 AudioStream")), "非音频资源路径没有被运行时音频目录阻断")
	var invalid_audio_catalog: Dictionary = audio_catalog.duplicate(true)
	invalid_audio_catalog["cues"][0]["duration"] = 4.0
	invalid_audio_catalog["cues"].append(invalid_audio_catalog["cues"][0].duplicate(true))
	var invalid_audio_errors := AudioEventRouterClass.validate_cue_catalog(invalid_audio_catalog)
	assert(invalid_audio_errors.any(func(error): return str(error).contains("提示音 id 重复")), "音频清单没有拒绝重复事件")
	assert(invalid_audio_errors.any(func(error): return str(error).contains("提示音时长超出范围")), "音频清单没有拒绝超长提示音")
	var original_only_audio_catalog = JSON.parse_string(FileAccess.get_file_as_string("res://content/audio-runtime-catalog-original-only.json"))
	assert(original_only_audio_catalog is Dictionary, "原创边界音频目录无法读取")
	assert(AudioEventRouterClass.validate_audio_resource_catalog(original_only_audio_catalog).is_empty(), "原创边界音频目录字段校验失败")
	assert(AudioEventRouterClass.validate_catalog_alignment(audio_catalog, original_only_audio_catalog).is_empty(), "原创边界音频目录事件没有逐事件对齐")
	for original_audio_event in original_only_audio_catalog.get("events", []):
		assert(str(original_audio_event.get("fallback_policy", "")) == "forbid", "原创边界音频事件仍允许程序化灰盒回退：" + str(original_audio_event.get("id", "")))
	audio_router.set_master_volume_db(-8.0)
	assert(is_equal_approx(audio_router.volume_snapshot()["master_volume_db"], -8.0), "音频主音量边界没有保存")
	audio_router.clear()
	assert(audio_router.history.is_empty(), "音频事件路由清理失败")
	audio_router.free()

	var settings_path := OS.get_temp_dir().path_join("reference-settings-smoke-%d.json" % Time.get_ticks_usec())
	var settings_store = SettingsStoreClass.new(settings_path)
	var default_settings := settings_store.load_audio_settings()
	assert(not default_settings["enabled"] and is_equal_approx(default_settings["master_volume_db"], -14.0), "音频设置默认值错误")
	assert(settings_store.save_audio_settings(true, -8.0), "音频设置写入失败")
	var restored_settings := settings_store.load_audio_settings()
	assert(restored_settings["enabled"] and is_equal_approx(restored_settings["master_volume_db"], -8.0), "音频设置读取失败")
	# 反复读取同一设置文件，确保读取路径在每次调用后都释放文件句柄，
	# 避免长时间运行或频繁打开暂停菜单时累积资源。
	for _read_index in range(8):
		var repeated_settings := settings_store.load_audio_settings()
		assert(repeated_settings["enabled"] and is_equal_approx(repeated_settings["master_volume_db"], -8.0), "音频设置重复读取结果不稳定")
	assert(settings_store.save_audio_settings(false, -20.0), "音频设置第二次写入失败")
	assert(FileAccess.file_exists(settings_path + ".bak"), "音频设置第二次写入没有生成备份")
	var corrupt_settings_file := FileAccess.open(settings_path, FileAccess.WRITE)
	corrupt_settings_file.store_string("[]")
	corrupt_settings_file = null
	var recovered_settings := settings_store.load_audio_settings()
	assert(recovered_settings["enabled"] and is_equal_approx(recovered_settings["master_volume_db"], -8.0), "音频设置损坏后没有从备份恢复")
	var malformed_settings_file := FileAccess.open(settings_path, FileAccess.WRITE)
	malformed_settings_file.store_string(JSON.stringify({"version": 1, "audio": {"enabled": "false", "master_volume_db": 12.0}}))
	malformed_settings_file = null
	var malformed_settings := settings_store.load_audio_settings()
	assert(malformed_settings["enabled"] and is_equal_approx(malformed_settings["master_volume_db"], -8.0), "篡改的音频设置没有从备份恢复")
	DirAccess.remove_absolute(settings_path + ".bak")
	var invalid_volume_settings := FileAccess.open(settings_path, FileAccess.WRITE)
	invalid_volume_settings.store_string(JSON.stringify({"version": 1, "audio": {"enabled": true, "master_volume_db": 12.0}}))
	invalid_volume_settings = null
	var invalid_volume_defaults := settings_store.load_audio_settings()
	assert(not invalid_volume_defaults["enabled"] and is_equal_approx(invalid_volume_defaults["master_volume_db"], -14.0), "无效音频设置没有安全回退默认值")
	var decimal_version_file := FileAccess.open(settings_path, FileAccess.WRITE)
	decimal_version_file.store_string("{\"version\":1.0,\"audio\":{\"enabled\":true,\"master_volume_db\":-8.0}}")
	decimal_version_file = null
	var decimal_version_defaults := settings_store.load_audio_settings()
	assert(not decimal_version_defaults["enabled"] and is_equal_approx(decimal_version_defaults["master_volume_db"], -14.0), "非整数版本设置没有被拒绝")
	assert(not settings_store.last_error.is_empty(), "无效设置回退默认值时没有留下错误信息")
	assert(not settings_store._validate_payload({"version": 1, "audio": {"enabled": true, "master_volume_db": INF}}), "非有限音频设置没有被拒绝")
	assert(not settings_store.save_audio_settings(true, 1.0), "越界音频主音量没有被拒绝")
	assert(not settings_store.save_audio_settings(true, INF), "非有限音频主音量没有被拒绝")
	var invalid_settings_store = SettingsStoreClass.new("/definitely_missing_gta_reference_parent/settings.json")
	assert(not invalid_settings_store.save_audio_settings(true, -8.0), "无效设置路径没有失败")
	assert(not invalid_settings_store.last_error.is_empty(), "设置写入失败没有留下可观测错误")

	var city_stages = ContentPackLoaderClass.stages_from_pack("res://content/city_mission.json")
	assert(city_stages.size() == 6, "城市内容包阶段数量错误")
	assert(city_stages[0].get("id") == "collect_eggs", "城市内容包没有读取首个目标")
	var office_pack = ContentPackLoaderClass.load_json("res://content/office_mission.json")
	assert(ContentPackLoaderClass.validate_pack(office_pack, "office").is_empty(), "办公室内容包校验失败")
	assert(ContentPackLoaderClass.validate_pack(ContentPackLoaderClass.load_json("res://content/city_mission.json"), "city").is_empty(), "城市内容包校验失败")
	assert(city_stages.size() == ContentPackLoaderClass.load_json("res://content/city_mission.json").get("targets", []).size(), "城市阶段与目标点数量未对齐")
	assert(int(office_pack.get("completion_minute", -1)) == 1080, "办公室内容包准点时间错误")
	var mismatched_city_pack = ContentPackLoaderClass.load_json("res://content/city_mission.json").duplicate(true)
	mismatched_city_pack["targets"].pop_back()
	var mismatch_errors := ContentPackLoaderClass.validate_pack(mismatched_city_pack, "city")
	assert(mismatch_errors.any(func(error): return str(error).contains("任务阶段缺少对应目标点：new_shop")), "内容包没有拒绝缺少目标点的任务阶段")
	var invalid_city_pack := {"id": "invalid", "version": 1, "display_name": "错误包", "stages": [{"id": "same", "objective": "一", "reward": -1, "stars": 9}, {"id": "same", "objective": "二", "reward": 1, "stars": 1}]}
	var invalid_errors := ContentPackLoaderClass.validate_pack(invalid_city_pack, "city")
	assert(invalid_errors.size() >= 3, "非法城市内容包没有被拒绝")

	print("参考还原基准烟雾测试通过")
	quit(0)

func _enter_then_free_driver(vehicle) -> void:
	var stale_actor := CharacterBody3D.new()
	stale_actor.position = vehicle.position
	var stale_collision := CollisionShape3D.new()
	var stale_box := BoxShape3D.new()
	stale_box.size = Vector3(0.8, 1.8, 0.8)
	stale_collision.shape = stale_box
	stale_actor.add_child(stale_collision)
	assert(vehicle.enter(stale_actor), "失效节点边界测试无法进入载具")
	stale_actor.free()

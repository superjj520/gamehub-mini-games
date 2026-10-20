extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const LauncherScene = preload("res://scenes/launcher.tscn")
const SaveStoreClass = preload("res://scripts/save_store.gd")
const MissionStateClass = preload("res://scripts/mission_state.gd")
const PerceptionStateClass = preload("res://scripts/perception_state.gd")
const MissionChainClass = preload("res://scripts/mission_chain.gd")
const InventoryStateClass = preload("res://scripts/inventory_state.gd")
const ContentPackLoaderClass = preload("res://scripts/content_pack_loader.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var launch_context = root.get_node_or_null("LaunchContext")
	assert(launch_context != null, "启动上下文自动加载单例缺失")
	launch_context.clear()

	var office_path := OS.get_temp_dir().path_join("reference-launcher-office-%d.json" % Time.get_ticks_usec())
	var office_mission = MissionStateClass.new()
	office_mission.start()
	office_mission.clock_minutes = 1077
	var office_perception = PerceptionStateClass.new()
	office_perception.suspicion = 0.35
	var office_store: SaveStore = SaveStoreClass.new(office_path)
	assert(office_store.save_checkpoint(office_mission, office_perception, Vector3(2.0, 1.0, 3.0), {"yaw": 22.0, "pitch": -14.0}, {}, "office-leave-on-time-v1"), "办公室启动器测试存档写入失败")
	var office_launcher = LauncherScene.instantiate()
	office_launcher.set_meta("office_checkpoint_path", office_path)
	root.add_child(office_launcher)
	await process_frame
	office_launcher._open_scene("res://scenes/benchmark.tscn", "", -1, "office-leave-on-time-v1")
	await process_frame
	var launched_office = current_scene
	var launched_office_loaded := await _wait_for_trace_event(launched_office, "checkpoint_loaded")
	assert(launched_office != null and launched_office.scene_file_path == "res://scenes/benchmark.tscn", "真实办公室启动器入口没有切换场景")
	assert(launched_office.initialized, "真实办公室启动器入口进入场景后没有完成初始化")
	assert(launched_office.office_pack_id == "office-leave-on-time-v1", "真实办公室启动器入口没有传递内容包标识")
	assert(launched_office.mission.clock_minutes == 1077, "真实办公室启动器入口没有恢复存档")
	assert(launched_office_loaded, "真实办公室启动器入口没有记录读取事件")
	assert(str(launch_context.pending_scene_path).is_empty(), "真实办公室启动器入口消费后仍残留场景意图")
	office_launcher.queue_free()
	await process_frame
	assert(change_scene_to_file("res://scenes/launcher.tscn") == OK, "办公室真实入口测试返回启动器失败")
	await process_frame

	launch_context.request_scene("res://scenes/benchmark.tscn", true)
	var office = OfficeScene.instantiate()
	office.set_meta("save_path", office_path)
	root.add_child(office)
	var office_loaded := await _wait_for_trace_event(office, "checkpoint_loaded")
	assert(office.initialized, "启动器恢复办公室后场景没有完成初始化")
	assert(office.mission.clock_minutes == 1077, "启动器恢复办公室没有读取任务时间")
	assert(office.player.position.distance_to(Vector3(2.0, 1.0, 3.0)) < 0.001, "启动器恢复办公室没有读取玩家位置")
	assert(office_loaded, "启动器恢复办公室没有记录读取事件")
	assert(not launch_context.consume_checkpoint("res://scenes/benchmark.tscn"), "办公室启动意图没有一次性消费")
	var persisted_office = JSON.parse_string(FileAccess.get_file_as_string(office_path))
	assert(int(persisted_office.get("mission", {}).get("clock_minutes", -1)) == 1077, "办公室初始启动存档覆盖了待恢复存档")
	office.queue_free()
	await process_frame

	var city_path := OS.get_temp_dir().path_join("reference-launcher-city-%d.json" % Time.get_ticks_usec())
	var city_pack := ContentPackLoaderClass.load_registered_pack("city", "city-free-eggs-v1")
	var city_chain: MissionChain = MissionChainClass.new()
	city_chain.configure(ContentPackLoaderClass.stages_from_payload(city_pack))
	city_chain.start()
	city_chain.complete_current()
	var city_inventory: InventoryState = InventoryStateClass.new()
	city_inventory.add_item("egg_tray", 1)
	var city_store: SaveStore = SaveStoreClass.new(city_path)
	assert(city_store.save_city_checkpoint(city_chain, city_inventory, Vector3(4.0, 0.9, 5.0), false, {"health": 88.0, "alert": 0.0}, {"yaw": -12.0, "pitch": -16.0}, {}, "city-free-eggs-v1"), "城市启动器测试存档写入失败")
	var city_launcher = LauncherScene.instantiate()
	city_launcher.set_meta("city_checkpoint_path", city_path)
	root.add_child(city_launcher)
	await process_frame
	city_launcher._open_scene("res://scenes/city.tscn", "", -1, "city-free-eggs-v1")
	await process_frame
	var launched_city = current_scene
	var launched_city_loaded := await _wait_for_trace_event(launched_city, "checkpoint_loaded")
	assert(launched_city != null and launched_city.scene_file_path == "res://scenes/city.tscn", "真实城市启动器入口没有切换场景")
	assert(launched_city.initialized, "真实城市启动器入口进入场景后没有完成初始化")
	assert(launched_city.city_pack_id == "city-free-eggs-v1", "真实城市启动器入口没有传递内容包标识")
	assert(launched_city.mission.current_index == 1, "真实城市启动器入口没有恢复任务阶段")
	assert(launched_city.inventory.has_item("egg_tray"), "真实城市启动器入口没有恢复库存")
	assert(launched_city_loaded, "真实城市启动器入口没有记录读取事件")
	assert(str(launch_context.pending_scene_path).is_empty(), "真实城市启动器入口消费后仍残留场景意图")
	city_launcher.queue_free()
	await process_frame
	assert(change_scene_to_file("res://scenes/launcher.tscn") == OK, "城市真实入口测试返回启动器失败")
	await process_frame

	var backup_only_city_path := OS.get_temp_dir().path_join("reference-launcher-city-backup-only-%d.json" % Time.get_ticks_usec())
	var backup_only_payload := FileAccess.get_file_as_string(city_path)
	var backup_only_file := FileAccess.open(backup_only_city_path + ".bak", FileAccess.WRITE)
	assert(backup_only_file != null, "启动器备份回退测试无法创建备份文件")
	backup_only_file.store_string(backup_only_payload)
	backup_only_file.flush()
	backup_only_file.close()
	backup_only_file = null
	var removed_backup_only_main := DirAccess.remove_absolute(backup_only_city_path)
	assert(removed_backup_only_main == OK or not FileAccess.file_exists(backup_only_city_path), "启动器备份回退测试没有移除主存档")
	var backup_launcher = LauncherScene.instantiate()
	backup_launcher.set_meta("city_checkpoint_path", backup_only_city_path)
	root.add_child(backup_launcher)
	await process_frame
	backup_launcher._open_scene("res://scenes/city.tscn")
	await process_frame
	var backup_city = current_scene
	var backup_city_loaded := await _wait_for_trace_event(backup_city, "checkpoint_loaded")
	assert(backup_city != null and backup_city.scene_file_path == "res://scenes/city.tscn", "仅备份存档没有通过真实城市启动器入口切换")
	assert(backup_city_loaded, "仅备份存档没有通过启动器恢复")
	assert(backup_city.mission.current_index == 1 and backup_city.inventory.has_item("egg_tray"), "仅备份存档恢复的城市状态不完整")
	backup_launcher.queue_free()
	await process_frame
	assert(change_scene_to_file("res://scenes/launcher.tscn") == OK, "城市备份回退测试返回启动器失败")
	await process_frame
	DirAccess.remove_absolute(backup_only_city_path + ".bak")

	launch_context.request_scene("res://scenes/city.tscn", true)
	var city = CityScene.instantiate()
	city.set_meta("save_path", city_path)
	root.add_child(city)
	var city_loaded := await _wait_for_trace_event(city, "checkpoint_loaded")
	assert(city.initialized, "启动器恢复城市后场景没有完成初始化")
	assert(city.mission.current_index == 1, "启动器恢复城市没有读取任务阶段")
	assert(city.inventory.has_item("egg_tray"), "启动器恢复城市没有读取库存")
	assert(Vector2(city.player.position.x, city.player.position.z).distance_to(Vector2(4.0, 5.0)) < 0.001, "启动器恢复城市没有读取玩家水平位置")
	assert(is_equal_approx(city.player.position.y, 0.9), "启动器恢复城市没有保持地面高度")
	assert(city_loaded, "启动器恢复城市没有记录读取事件")
	assert(not launch_context.consume_checkpoint("res://scenes/city.tscn"), "城市启动意图没有一次性消费")
	var persisted_city = JSON.parse_string(FileAccess.get_file_as_string(city_path))
	assert(int(persisted_city.get("mission_chain", {}).get("current_index", -1)) == 1, "城市初始启动存档覆盖了待恢复存档")
	assert(str(launch_context.pending_scene_path).is_empty(), "启动器恢复后仍残留启动意图")
	city.queue_free()
	await process_frame

	var missing_city_path := OS.get_temp_dir().path_join("reference-launcher-city-missing-%d.json" % Time.get_ticks_usec())
	launch_context.request_scene("res://scenes/city.tscn", true)
	var missing_city = CityScene.instantiate()
	missing_city.set_meta("save_path", missing_city_path)
	root.add_child(missing_city)
	var missing_city_loaded := await _wait_for_trace_event(missing_city, "checkpoint_load_failed")
	assert(missing_city.initialized, "不存在城市存档时没有完成新任务初始化")
	assert(missing_city.mission.status == MissionChainClass.Status.ACTIVE and missing_city.mission.current_index == 0, "不存在城市存档时没有保持新任务起点")
	assert(missing_city_loaded, "不存在城市存档时没有记录读取失败")
	missing_city.queue_free()
	await process_frame

	var corrupt_city_path := OS.get_temp_dir().path_join("reference-launcher-city-corrupt-%d.json" % Time.get_ticks_usec())
	var corrupt_city_file := FileAccess.open(corrupt_city_path, FileAccess.WRITE)
	corrupt_city_file.store_string("{坏城市存档")
	corrupt_city_file = null
	launch_context.request_scene("res://scenes/city.tscn", true)
	var corrupt_city = CityScene.instantiate()
	corrupt_city.set_meta("save_path", corrupt_city_path)
	root.add_child(corrupt_city)
	var corrupt_city_loaded := await _wait_for_trace_event(corrupt_city, "checkpoint_load_failed")
	assert(corrupt_city.initialized, "损坏城市存档时没有完成新任务初始化")
	assert(corrupt_city.mission.status == MissionChainClass.Status.ACTIVE and corrupt_city.mission.current_index == 0, "损坏城市存档时没有保持新任务起点")
	assert(corrupt_city_loaded, "损坏城市存档时没有记录读取失败")
	corrupt_city.queue_free()
	await process_frame

	var missing_path := OS.get_temp_dir().path_join("reference-launcher-missing-%d.json" % Time.get_ticks_usec())
	launch_context.request_scene("res://scenes/benchmark.tscn", true)
	var missing_office = OfficeScene.instantiate()
	missing_office.set_meta("save_path", missing_path)
	root.add_child(missing_office)
	var missing_office_loaded := await _wait_for_trace_event(missing_office, "checkpoint_load_failed")
	assert(missing_office.initialized, "不存在存档时办公室没有完成新任务初始化")
	assert(missing_office.mission.clock_minutes == 1079, "不存在存档时办公室没有保持新任务起点")
	assert(missing_office_loaded, "不存在存档时没有记录读取失败")
	missing_office.queue_free()
	await process_frame

	var corrupt_path := OS.get_temp_dir().path_join("reference-launcher-corrupt-%d.json" % Time.get_ticks_usec())
	var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("{坏存档")
	corrupt_file = null
	launch_context.request_scene("res://scenes/benchmark.tscn", true)
	var corrupt_office = OfficeScene.instantiate()
	corrupt_office.set_meta("save_path", corrupt_path)
	root.add_child(corrupt_office)
	var corrupt_office_loaded := await _wait_for_trace_event(corrupt_office, "checkpoint_load_failed")
	assert(corrupt_office.initialized, "损坏存档时办公室没有完成新任务初始化")
	assert(corrupt_office.mission.status == MissionStateClass.Status.ACTIVE, "损坏存档时办公室没有保持进行中状态")
	assert(corrupt_office_loaded, "损坏存档时没有记录读取失败")
	corrupt_office.queue_free()
	await process_frame
	launch_context.clear()
	print("启动器办公室与城市存档恢复集成测试通过")
	quit(0)

func _wait_for_trace_event(scene: Node, event_id: String, max_frames := 60) -> bool:
	for index in range(max_frames):
		if bool(scene.get("initialized")):
			var trace_recorder = scene.get("trace")
			if trace_recorder is Object and trace_recorder.has_method("has_event") and bool(trace_recorder.call("has_event", event_id)):
				await process_frame
				return true
		await process_frame
	return false

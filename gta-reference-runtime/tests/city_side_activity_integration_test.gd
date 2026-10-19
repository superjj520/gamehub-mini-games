extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path := OS.get_temp_dir().path_join("新时代觉醒者-side-activity-%d.json" % Time.get_ticks_usec())
	var city = CityScene.instantiate()
	city.set_meta("save_path", save_path)
	get_root().add_child(city)
	await process_frame
	assert(city.initialized, "支线测试城市没有完成初始化")
	assert(city.side_activity_target != null, "城市内容没有创建街边支线目标")
	assert(not city.side_activity_unlocked, "街边支线在登记前错误解锁")

	city.mission.current_index = 2
	city._sync_side_activity_state()
	assert(city.side_activity_unlocked, "完成登记后街边支线没有解锁")
	city.player.position = city.side_activity_target.position
	var without_vehicle := InputFrameClass.new()
	without_vehicle.interact = true
	city.process_input_frame(without_vehicle, 0.016)
	assert(not city.side_activity_completed, "未驾驶三轮车时错误完成支线")
	assert(not city.side_activity_accepted, "未驾驶三轮车时错误接单")
	assert(city.trace.has_event("side_activity_blocked"), "支线条件失败没有写入回放")

	city.vehicle.position = city.side_activity_target.position + Vector3(0.0, -0.3, 0.0)
	city.player.position = city.vehicle.position + Vector3.UP
	assert(city.vehicle.enter(city.player), "支线测试无法进入三轮车")
	var accept := InputFrameClass.new()
	accept.interact = true
	city.process_input_frame(accept, 0.016)
	assert(city.side_activity_accepted, "驾驶三轮车靠近摊主后没有接单")
	assert(not city.side_activity_completed, "接单阶段错误地直接完成支线")
	assert(city.inventory.has_item("vendor_parcel"), "接单后没有生成待配送货物")
	assert(city.side_activity_delivery_target != null and city.side_activity_delivery_target.visible, "接单后没有显示交付目标")
	assert(city.mission.money == 0, "接单阶段错误发放奖励")
	assert(city.trace.has_event("side_activity_accepted"), "接单没有写入回放")
	city._save_city_checkpoint()
	city.reference_capture_mode = true
	var in_transit_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	assert(in_transit_payload is Dictionary and bool(in_transit_payload.get("world_state", {}).get("side_activity_accepted", false)), "接单中途存档没有写入进行中状态")
	var in_transit = CityScene.instantiate()
	in_transit.set_meta("save_path", save_path)
	in_transit.set_meta("load_checkpoint", true)
	get_root().add_child(in_transit)
	in_transit.reference_capture_mode = true
	await process_frame
	in_transit._load_city_checkpoint()
	assert(in_transit.side_activity_accepted, "接单中途读取没有恢复进行中状态")
	assert(in_transit.inventory.has_item("vendor_parcel"), "接单中途读取没有恢复待配送货物")
	assert(in_transit.side_activity_delivery_target.visible, "接单中途读取没有恢复交付目标")
	city.queue_free()
	city = in_transit
	city.reference_capture_mode = false

	city.vehicle.position = city.side_activity_delivery_target.position + Vector3(0.0, -0.3, 0.0)
	city.player.position = city.vehicle.position + Vector3.UP
	var deliver := InputFrameClass.new()
	deliver.interact = true
	city.process_input_frame(deliver, 0.016)
	assert(city.side_activity_completed, "到达交付点后没有完成街边支线")
	assert(not city.side_activity_accepted, "交付后仍保持接单状态")
	assert(not city.inventory.has_item("vendor_parcel"), "交付后待配送货物没有清除")
	assert(city.mission.money == 35, "街边支线奖励没有进入任务经济")
	assert(city.trace.has_event("side_activity_completed"), "支线完成没有写入回放")

	city._save_city_checkpoint()
	# 读取验证期间冻结原场景，避免它的每帧自动存档覆盖待读取的完成状态。
	city.reference_capture_mode = true
	assert(FileAccess.file_exists(save_path), "支线完成后没有写出城市存档")
	var saved_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	assert(saved_payload is Dictionary and bool(saved_payload.get("world_state", {}).get("side_activity_completed", false)), "城市存档没有写入支线完成字段")
	var restored = CityScene.instantiate()
	restored.set_meta("save_path", save_path)
	# 让任务启动回调知道这是读档场景，避免 mission.start() 的起点存档覆盖旧文件。
	restored.set_meta("load_checkpoint", true)
	get_root().add_child(restored)
	# 新场景初始化后会在物理帧自动保存一次；先冻结自动写入，再验证读取旧存档。
	restored.reference_capture_mode = true
	await process_frame
	restored._load_city_checkpoint()
	restored.reference_capture_mode = false
	assert(restored.side_activity_completed, "读取城市存档没有恢复支线完成状态")
	assert(not restored.side_activity_accepted, "读取城市存档错误恢复为接单中")
	assert(restored.mission.money == 35, "读取城市存档没有恢复支线奖励")
	assert(not restored.side_activity_target.visible, "已完成支线读取后仍显示接单标记")

	# 第二条支线只改变内容配置，不改变核心接单、配送、奖励和存档代码。
	restored.mission.current_index = 3
	restored._sync_side_activity_state()
	var second_runtime: Dictionary = {}
	for runtime in restored.side_activity_runtimes:
		if str(runtime.get("id", "")) == "backlot_delivery":
			second_runtime = runtime
			break
	assert(not second_runtime.is_empty(), "内容包没有创建第二条后场配送支线")
	assert(bool(second_runtime.get("unlocked", false)), "进入后场后第二条支线没有解锁")
	var second_target := second_runtime.get("target") as Node3D
	var second_delivery_target := second_runtime.get("delivery_target") as Node3D
	assert(second_target != null and second_delivery_target != null, "第二条支线没有完整创建接单点和交付点")
	restored.vehicle.position = second_target.position + Vector3(0.0, -0.3, 0.0)
	restored.player.global_position = restored.vehicle.global_position + Vector3.UP
	if restored.vehicle.driver != restored.player:
		assert(restored.vehicle.enter(restored.player), "第二条支线测试无法进入三轮车")
	assert(restored._side_activity_can_interact(), "第二条支线接单点当前不可交互")
	var second_accept := InputFrameClass.new()
	second_accept.interact = true
	restored.process_input_frame(second_accept, 0.016)
	var accepted_second_runtime: Dictionary = restored.side_activity_runtimes[1]
	assert(bool(accepted_second_runtime.get("accepted", false)), "第二条支线没有复用配置化接单逻辑")
	assert(restored.inventory.has_item("vendor_parcel_1"), "第二条支线没有生成独立货物")
	restored.vehicle.position = second_delivery_target.position + Vector3(0.0, -0.3, 0.0)
	restored.player.global_position = restored.vehicle.global_position + Vector3.UP
	var second_deliver := InputFrameClass.new()
	second_deliver.interact = true
	restored.process_input_frame(second_deliver, 0.016)
	var completed_second_runtime: Dictionary = restored.side_activity_runtimes[1]
	assert(bool(completed_second_runtime.get("completed", false)), "第二条支线没有完成配置化交付")
	assert(not restored.inventory.has_item("vendor_parcel_1"), "第二条支线交付后货物没有清除")
	assert(restored.mission.money == 80, "第二条支线奖励没有叠加到任务经济")

	# 第三条支线在主线进入装载阶段后解锁，继续复用同一套运行时。
	restored.mission.current_index = 4
	restored._sync_side_activity_state()
	var third_runtime: Dictionary = {}
	for runtime in restored.side_activity_runtimes:
		if str(runtime.get("id", "")) == "repair_shop_pickup":
			third_runtime = runtime
			break
	assert(not third_runtime.is_empty(), "内容包没有创建第三条维修摊取件支线")
	assert(bool(third_runtime.get("unlocked", false)), "装载货物阶段没有解锁第三条支线")
	var third_target := third_runtime.get("target") as Node3D
	var third_delivery_target := third_runtime.get("delivery_target") as Node3D
	assert(third_target != null and third_delivery_target != null, "第三条支线没有完整创建接单点和交付点")
	restored.vehicle.position = third_target.position + Vector3(0.0, -0.3, 0.0)
	restored.player.global_position = restored.vehicle.global_position + Vector3.UP
	var third_accept := InputFrameClass.new()
	third_accept.interact = true
	restored.process_input_frame(third_accept, 0.016)
	var accepted_third_runtime: Dictionary = restored.side_activity_runtimes[2]
	assert(bool(accepted_third_runtime.get("accepted", false)), "第三条支线没有复用配置化接单逻辑")
	assert(restored.inventory.has_item("vendor_parcel_2"), "第三条支线没有生成独立货物")
	restored.vehicle.position = third_delivery_target.position + Vector3(0.0, -0.3, 0.0)
	restored.player.global_position = restored.vehicle.global_position + Vector3.UP
	var third_deliver := InputFrameClass.new()
	third_deliver.interact = true
	restored.process_input_frame(third_deliver, 0.016)
	var completed_third_runtime: Dictionary = restored.side_activity_runtimes[2]
	assert(bool(completed_third_runtime.get("completed", false)), "第三条支线没有完成配置化交付")
	assert(not restored.inventory.has_item("vendor_parcel_2"), "第三条支线交付后货物没有清除")
	assert(restored.mission.money == 135, "第三条支线奖励没有叠加到任务经济")

	city.queue_free()
	restored.queue_free()
	await process_frame
	print("城市街边支线集成测试通过：解锁 -> 车辆条件 -> 奖励 -> 存档恢复")
	quit(0)

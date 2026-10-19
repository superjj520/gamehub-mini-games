extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")
const MissionChainClass = preload("res://scripts/mission_chain.gd")

const PACK_ID := "city-market-delivery-v1"

func _init() -> void:
	call_deferred("_run")

func _request_market_pack(load_checkpoint: bool, checkpoint_path := "") -> void:
	var launch_context := get_root().get_node("LaunchContext")
	launch_context.request_scene("res://scenes/city.tscn", load_checkpoint, checkpoint_path, "", PACK_ID)

func _interact_at(city, target_index: int) -> void:
	var target = city.targets[target_index]
	city.player.position = target.position + Vector3(0.0, 0.0, 1.0)
	city.process_input_frame(InputFrameClass.new(), 0.016)
	assert(city.prompt_label.text == "E  " + target.prompt, "夜市内容目标没有显示交互提示：" + str(target.prompt))
	var frame := InputFrameClass.new()
	frame.interact = true
	city.process_input_frame(frame, 0.016)

func _run() -> void:
	var save_path := OS.get_temp_dir().path_join("新时代觉醒者-market-delivery-%d.json" % Time.get_ticks_usec())
	_request_market_pack(false)
	var city = CityScene.instantiate()
	city.set_meta("save_path", save_path)
	get_root().add_child(city)
	await process_frame

	assert(city.initialized, "夜市内容城市没有完成初始化")
	assert(city.city_pack_id == PACK_ID, "城市运行时没有使用夜市内容包")
	assert(city.targets.size() == 4, "夜市内容包没有创建四个任务目标")
	assert(city.mission.current_stage().get("id", "") == "accept_order", "夜市配送没有从接单阶段开始")
	assert(city.weather_profile == "dusk", "夜市内容包默认黄昏视觉配置没有应用到城市运行时")
	assert(is_equal_approx(float(city.vehicle.max_speed), 8.5), "夜市内容包载具速度没有应用")
	assert(city.city_story_lights.size() == 4, "黄昏配送没有创建四个原创夜市氛围灯")
	var dusk_light := city.city_story_lights[0].get("light") as OmniLight3D
	assert(dusk_light != null and dusk_light.light_energy > 0.5, "黄昏配置没有点亮夜市氛围灯")
	var dusk_energy := dusk_light.light_energy
	assert(city.apply_visual_profile("day"), "城市无法切换回白天视觉配置")
	assert(dusk_light.light_energy < dusk_energy, "白天配置没有降低夜市灯光能量")
	assert(city.apply_visual_profile("dusk"), "城市无法恢复黄昏视觉配置")
	assert(dusk_light.light_energy > dusk_energy * 0.8, "恢复黄昏后夜市灯光没有重新点亮")

	_interact_at(city, 0)
	assert(city.inventory.has_item("night_order_ticket"), "接单后没有生成夜市订单凭证")
	assert(city.mission.current_stage().get("id", "") == "load_crates", "接单后没有进入装载阶段")
	assert(city.trace.has_event("interaction"), "夜市接单没有记录交互事件")

	_interact_at(city, 1)
	assert(not city.inventory.has_item("night_order_ticket"), "装载后没有清除夜市订单凭证")
	assert(city.inventory.has_item("night_crate"), "装载后没有生成夜市货箱")
	assert(city.mission.current_stage().get("id", "") == "deliver_stock", "装载后没有进入配送阶段")
	assert(city.trace.has_event("night_stock_loaded"), "装载阶段没有记录配置化事件")

	_interact_at(city, 2)
	assert(not city.inventory.has_item("night_crate"), "交付后没有清除夜市货箱")
	assert(city.inventory.has_item("night_reward_token"), "交付后没有生成奖励凭证")
	assert(city.mission.current_stage().get("id", "") == "collect_reward", "交付后没有进入领奖阶段")
	assert(city.trace.has_event("night_stock_delivered"), "配送阶段没有记录配置化事件")

	_interact_at(city, 3)
	assert(not city.inventory.has_item("night_reward_token"), "领奖后没有清除奖励凭证")
	assert(city.mission.status == MissionChainClass.Status.SUCCESS, "夜市配送四阶段完成后任务没有成功")
	assert(city.mission.money == 180, "夜市配送四阶段奖励金额不正确")
	assert(city.mission.stars == 5, "夜市配送四阶段星级没有达到上限")
	assert(city.trace.has_event("night_delivery_rewarded"), "领奖阶段没有记录配置化事件")

	# 完成态必须可以写入并按同一个内容包恢复，避免新增内容只能单次运行。
	city.reference_capture_mode = true
	city._save_city_checkpoint()
	var saved_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	assert(saved_payload is Dictionary, "夜市配送完成后没有写出有效存档")
	assert(str(saved_payload.get("content_pack_id", "")) == PACK_ID, "夜市存档没有绑定内容包 id")
	assert(int(saved_payload.get("mission_chain", {}).get("current_index", -1)) == 4, "夜市存档没有保存完成索引")

	_request_market_pack(true, save_path)
	var restored = CityScene.instantiate()
	restored.set_meta("save_path", save_path)
	restored.set_meta("load_checkpoint", true)
	restored.reference_capture_mode = true
	get_root().add_child(restored)
	await process_frame
	restored._load_city_checkpoint()
	assert(restored.city_pack_id == PACK_ID, "读取夜市存档时内容包 id 不一致")
	assert(restored.mission.status == MissionChainClass.Status.SUCCESS, "读取夜市存档没有恢复任务完成状态")
	assert(restored.mission.money == 180, "读取夜市存档没有恢复任务奖励")
	assert(not restored.inventory.has_item("night_order_ticket"), "读取完成存档错误恢复订单凭证")
	assert(not restored.inventory.has_item("night_crate"), "读取完成存档错误恢复货箱")
	assert(not restored.inventory.has_item("night_reward_token"), "读取完成存档错误恢复奖励凭证")
	assert(restored.weather_profile == "dusk", "读取夜市存档没有保持视觉配置")

	city.queue_free()
	restored.queue_free()
	await process_frame
	print("城市夜市配送集成测试通过：接单 -> 装载 -> 配送 -> 领奖 -> 存档恢复")
	quit(0)

extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	await process_frame
	city.save_store.save_path = OS.get_temp_dir().path_join("reference-city-extension-%d.json" % Time.get_ticks_usec())
	assert(city.get_node_or_null("新街区巷道") != null, "新街区巷道没有进入城市运行时")
	assert(city.get_node_or_null("后场仓储建筑") != null, "后场仓储建筑没有进入城市运行时")
	assert(city.find_child("原创写实后场仓储门面候选", true, false) != null, "后场仓储原创门面候选没有进入城市运行时")
	for detail_name in ["后场仓储装卸雨棚", "后场仓储木托盘-01", "后场仓储警示灯", "后场仓储地面导视线"]:
		var detail := city.find_child(detail_name, true, false)
		assert(detail != null, "新街区候选视觉缺少：" + detail_name)
		assert(bool(detail.get_meta("visual_only", false)), "新街区细节必须保持 visual_only：" + detail_name)
		assert(bool(detail.get_meta("candidate_visual_only", false)), "新街区细节必须保持 candidate_visual_only：" + detail_name)
	assert(city.find_children("*", "StaticBody3D", true, false).size() > 0, "城市扩展基础碰撞缺失")

	city.city_scene_visuals.apply_runtime_context({
		"store_transition": true,
		"neighborhood_active": true,
		"weather_profile": "rain_after",
		"traffic_active": true,
		"traffic_signal_red": true,
		"vehicle_integrity": 28.0,
		"delivery_completed": true,
		"delivery_reward": 260,
		"delivery_stars": 3,
	})
	var expanded_context: Node3D = city.city_scene_visuals.context_root
	assert(expanded_context != null, "城市扩展视觉上下文根节点没有创建")
	assert(bool(expanded_context.get_meta("visual_only", false)), "城市扩展视觉上下文必须保持 visual_only")
	assert(bool(expanded_context.get_meta("candidate_visual_only", false)), "城市扩展视觉上下文必须保持 candidate_visual_only")
	var expanded_contracts: Array = expanded_context.get_meta("expanded_visual_contracts", [])
	assert(expanded_contracts.size() == 6, "组合扩展状态必须保留六个视觉契约，实际为 %d" % expanded_contracts.size())
	var expanded_ids: Array[String] = []
	for contract in expanded_contracts:
		assert(contract is Dictionary, "扩展视觉契约必须是字典")
		var contract_id := str(contract.get("id", ""))
		assert(not contract_id.is_empty(), "扩展视觉契约缺少 id")
		assert(not expanded_ids.has(contract_id), "扩展视觉契约 id 重复：" + contract_id)
		expanded_ids.append(contract_id)
		var layers: Array = contract.get("layers", [])
		assert(layers.size() >= 2, "扩展视觉契约必须至少包含两层：" + contract_id)
	assert(expanded_ids.has("city-store-transition"), "组合状态丢失店内过渡视觉契约")
	assert(expanded_ids.has("city-neighborhood-extension"), "组合状态丢失新街区视觉契约")
	assert(expanded_ids.has("city-weather-lighting-extension"), "组合状态丢失雨后视觉契约")
	assert(expanded_ids.has("city-traffic-near-miss"), "组合状态丢失交通视觉契约")
	assert(expanded_ids.has("city-vehicle-damage-feedback"), "组合状态丢失载具损伤视觉契约")
	assert(expanded_ids.has("city-delivery-completion"), "组合状态丢失交付完成视觉契约")
	for completion_node_name in ["扩展交付完成结算牌", "扩展交付完成状态灯-00", "扩展交付完成路线终点", "扩展交付完成标题", "扩展交付完成奖励"]:
		var completion_node := expanded_context.find_child(completion_node_name, true, false)
		assert(completion_node != null, "交付完成视觉缺少：" + completion_node_name)
		assert(bool(completion_node.get_meta("visual_only", false)), "交付完成视觉必须保持 visual_only：" + completion_node_name)
		assert(bool(completion_node.get_meta("candidate_visual_only", false)), "交付完成视觉必须保持 candidate_visual_only：" + completion_node_name)
	for visual_node in expanded_context.get_children():
		assert(not (visual_node is CollisionObject3D), "扩展视觉上下文不得创建碰撞对象：" + visual_node.name)
		assert(not (visual_node is NavigationRegion3D), "扩展视觉上下文不得创建导航对象：" + visual_node.name)
		assert(bool(visual_node.get_meta("visual_only", false)), "扩展视觉子节点缺少 visual_only：" + visual_node.name)

	city.player.position = city.neighborhood_entry
	assert(city.enter_neighborhood_extension(), "玩家在入口位置无法进入扩展街区")
	assert(city.neighborhood_status == "active", "扩展街区没有进入 active 状态")
	assert(city.trace.has_event("neighborhood_entered"), "扩展街区进入没有记录事件")

	assert(city.apply_visual_profile("dusk"), "黄昏视觉配置应用失败")
	assert(city.weather_profile == "dusk", "黄昏视觉配置没有记录")
	assert(city.apply_visual_profile("rain_after"), "雨后视觉配置应用失败")
	assert(city.get_node_or_null("雨后视觉层") != null, "雨后视觉层没有生成")
	for reflection_name in ["雨后路面积水反光-00", "雨后排水沟反光-01"]:
		var reflection := city.find_child(reflection_name, true, false)
		assert(reflection != null, "雨后视觉层缺少反光细节：" + reflection_name)
		assert(bool(reflection.get_meta("visual_only", false)), "雨后反光必须保持 visual_only：" + reflection_name)
		assert(bool(reflection.get_meta("candidate_visual_only", false)), "雨后反光必须保持 candidate_visual_only：" + reflection_name)
	assert(city.trace.has_event("visual_profile"), "视觉配置没有记录事件")

	var damage_before: float = city.vehicle_integrity
	assert(city.apply_vehicle_collision_damage(55.0, "扩展验收交通车辆"), "载具碰撞损伤没有应用")
	assert(city.vehicle_integrity < damage_before, "载具耐久没有下降")
	assert(city.vehicle_status_label.visible, "载具损伤 HUD 没有显示")
	var candidate_damage_panel: Node = city.vehicle.find_child("候选三轮车损伤面板", true, false)
	var candidate_damage_smoke := city.vehicle.find_child("候选三轮车损伤烟雾", true, false) as GPUParticles3D
	if candidate_damage_panel != null:
		assert(candidate_damage_panel.visible, "候选三轮车受损后没有显示专属损伤面板")
		assert(candidate_damage_smoke != null, "候选三轮车受损后缺少原创损伤烟雾")
		assert(candidate_damage_smoke.emitting, "候选三轮车受损后原创损伤烟雾没有发射")
		assert(not city.find_child("三轮车损伤标记", true, false).visible, "候选三轮车仍叠加显示灰盒损伤条")
		assert(not city.find_child("三轮车损伤侧板", true, false).visible, "候选三轮车仍叠加显示灰盒损伤侧板")
		assert(not city.find_child("三轮车损伤警示灯", true, false).visible, "候选三轮车仍叠加显示灰盒损伤警示灯")
		assert(not city.find_child("三轮车损伤烟雾-0", true, false).visible, "候选三轮车仍叠加显示灰盒损伤烟雾")
	else:
		assert(city.find_child("三轮车损伤标记", true, false) != null, "载具缺少损伤标记视觉")
		assert(city.find_child("三轮车损伤标记", true, false).visible, "载具损伤后车体标记没有显示")
		assert(city.find_child("三轮车损伤侧板", true, false) != null, "载具缺少侧板损伤视觉")
		assert(city.find_child("三轮车损伤侧板", true, false).visible, "载具损伤后侧板标记没有显示")
		assert(city.find_child("三轮车损伤警示灯", true, false) != null, "载具缺少损伤警示灯视觉")
		assert(city.find_child("三轮车损伤烟雾-0", true, false) != null, "载具缺少损伤烟雾层")
		assert(city.find_child("三轮车损伤烟雾-0", true, false).visible, "载具损伤后烟雾层没有显示")
	assert(city.trace.has_event("vehicle_damage"), "载具损伤没有记录事件")
	assert(city.audio_events.history.any(func(event): return str(event.get("id", "")) == "vehicle_collision"), "载具碰撞没有进入音频事件路由")
	assert(float(city.hud_visual.get("feedback_timer")) > 0.0, "载具碰撞没有给出即时边缘反馈")
	city.mission.money = 100
	city.player.position = city.targets[5].position + Vector3(0.0, 0.0, 2.2)
	var service_probe = InputFrameClass.new()
	city.process_input_frame(service_probe, 0.016)
	assert(city.prompt_label.text.contains("维修三轮车"), "维修点配置的交互半径没有生效")
	city.player.position = city.targets[5].position + Vector3(0.0, 0.0, 1.0)
	var service_frame = InputFrameClass.new()
	service_frame.interact = true
	city.process_input_frame(service_frame, 0.016)
	assert(is_equal_approx(city.vehicle_integrity, 100.0), "维修交互没有恢复三轮车耐久")
	assert(city.mission.money == 70, "维修交互没有扣除正确费用")
	assert(city.trace.has_event("vehicle_repaired"), "维修交互没有记录事件")
	assert(float(city.hud_visual.get("feedback_timer")) > 0.0, "维修成功没有给出即时边缘反馈")
	var collision_audio_count: int = city.audio_events.history.size()
	assert(city.apply_vehicle_collision_damage(100.0, "扩展验收损毁测试"), "载具损毁碰撞没有应用")
	assert(city.audio_events.history.size() > collision_audio_count, "载具损毁没有新增音频事件")
	assert(city.audio_events.history.any(func(event): return str(event.get("id", "")) == "vehicle_destroyed"), "载具损毁没有进入失败音频事件路由")
	city._save_city_checkpoint()
	var saved_payload = JSON.parse_string(FileAccess.get_file_as_string(city.save_store.save_path))
	assert(is_equal_approx(float(saved_payload.get("vehicle", {}).get("integrity", -1.0)), city.vehicle_integrity), "载具耐久没有写入城市存档")
	assert(saved_payload.get("world_state", {}).get("weather_profile", "") == "rain_after", "天气配置没有写入城市存档")
	assert(saved_payload.get("world_state", {}).get("neighborhood_status", "") == "active", "扩展街区状态没有写入城市存档")
	city.vehicle_integrity = 100.0
	city._update_vehicle_damage_feedback()
	assert(not city.find_child("三轮车损伤标记", true, false).visible, "清空当前载具耐久后损伤标记仍可见")
	assert(not city.find_child("三轮车损伤侧板", true, false).visible, "清空当前载具耐久后侧板标记仍可见")
	assert(not city.find_child("三轮车损伤烟雾-0", true, false).visible, "清空当前载具耐久后烟雾层仍可见")
	if candidate_damage_smoke != null:
		assert(not candidate_damage_smoke.emitting, "清空当前载具耐久后原创损伤烟雾仍在发射")
	city.neighborhood_status = "inactive"
	assert(city.apply_visual_profile("day"), "读取前恢复白天视觉失败")
	city._load_city_checkpoint()
	assert(is_equal_approx(city.vehicle_integrity, float(saved_payload["vehicle"]["integrity"])), "读取城市存档没有恢复载具耐久")
	if candidate_damage_panel != null:
		assert(candidate_damage_panel.visible, "读取城市存档没有恢复候选载具损伤面板")
		assert(candidate_damage_smoke != null and candidate_damage_smoke.emitting, "读取城市存档没有恢复原创损伤烟雾")
	else:
		assert(city.find_child("三轮车损伤标记", true, false).visible, "读取城市存档没有恢复载具损伤标记")
	assert(city.vehicle_status_label.visible, "读取城市存档没有恢复载具损伤 HUD")
	assert(city.weather_profile == "rain_after", "读取城市存档没有恢复天气配置")
	assert(city.get_node_or_null("雨后视觉层") != null, "读取城市存档没有恢复雨后视觉层")
	assert(city.neighborhood_status == "active", "读取城市存档没有恢复扩展街区状态")

	city.free()
	await process_frame
	print("城市扩展街区、视觉配置与载具反馈集成测试通过")
	quit(0)

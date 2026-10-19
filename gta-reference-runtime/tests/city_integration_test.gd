extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")
const MissionChainClass = preload("res://scripts/mission_chain.gd")

func _init() -> void:
	call_deferred("_run")

func _assert_original_crowd_grounded(visual: Node, label: String) -> void:
	assert(visual is Node3D, label + "不是 Node3D")
	if visual.has_meta("city_makehuman_asset"):
		var makehuman_visual := visual as Node3D
		var makehuman_role_scale := maxf(absf(makehuman_visual.scale.y), 0.001)
		var expected_makehuman_y := -float(makehuman_visual.get_meta("city_makehuman_foot_origin_y", -0.0143)) * makehuman_role_scale
		assert(is_equal_approx(makehuman_visual.position.y, expected_makehuman_y), label + "没有按 MakeHuman 包围盒底部贴地")
		assert(is_equal_approx(float(makehuman_visual.get_meta("ground_contact_offset", -1.0)), makehuman_visual.position.y), label + "没有登记 MakeHuman 贴地偏移")
		return
	assert(visual.has_meta("original_procedural_asset"), label + "缺少原创资产元数据")
	var visual_3d := visual as Node3D
	var role_scale := maxf(absf(visual_3d.scale.y), 0.001)
	assert(is_equal_approx(visual_3d.position.y, 1.075 * role_scale), label + "没有按角色缩放贴地")
	assert(is_equal_approx(float(visual_3d.get_meta("ground_contact_offset", -1.0)), visual_3d.position.y), label + "没有登记贴地偏移")

func _run() -> void:
	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	assert(city.city_scene_visuals != null, "城市正式运行时没有挂载状态视觉层")
	assert(city.city_scene_visuals.active_state == "city-01", "城市初始游玩状态没有绑定 city-01 构图")
	assert(city.pedestrians.size() == 4, "城市人群没有按内容包路线创建")
	assert(city.traffic_vehicles.size() == 3, "城市交通没有按内容包路线创建")
	assert(city.traffic_vehicles[0].has_signal_stop_point, "北行交通车辆没有接入路口停车点")
	assert(city.traffic_vehicles[1].has_signal_stop_point, "南行交通车辆没有接入路口停车点")
	assert(not city.traffic_vehicles[0].signal_red, "城市初始信号灯错误处于红灯")
	city.city_scene_visuals.apply_runtime_state("city-09", "signal_visual_test")
	city.city_scene_visuals.apply_runtime_context({"traffic_active": true, "traffic_signal_red": true})
	assert(bool(city.city_scene_visuals.state_root.get_meta("traffic_signal_red", false)), "城市红灯逻辑没有同步到驾驶场景视觉层")
	assert(city.city_scene_visuals.state_root.get_meta("traffic_signal_visual_phase", "") == "red", "城市驾驶场景没有记录红灯表现相位")
	var signal_red_visual := city.city_scene_visuals.find_child("状态驾驶交通信号红灯", true, false) as MeshInstance3D
	var signal_green_visual := city.city_scene_visuals.find_child("状态驾驶交通信号绿灯", true, false) as MeshInstance3D
	assert(signal_red_visual != null and signal_green_visual != null, "城市驾驶场景缺少红绿灯视觉节点")
	assert((signal_red_visual.material_override as StandardMaterial3D).emission_energy_multiplier > (signal_green_visual.material_override as StandardMaterial3D).emission_energy_multiplier, "红灯相位没有点亮红灯并压低绿灯")
	city.city_scene_visuals.apply_runtime_context({"traffic_active": true, "traffic_signal_red": false})
	assert(not bool(city.city_scene_visuals.state_root.get_meta("traffic_signal_red", true)), "城市绿灯逻辑没有同步到驾驶场景视觉层")
	assert(city.city_scene_visuals.state_root.get_meta("traffic_signal_visual_phase", "") == "green", "城市驾驶场景没有记录绿灯表现相位")
	assert((signal_green_visual.material_override as StandardMaterial3D).emission_energy_multiplier > (signal_red_visual.material_override as StandardMaterial3D).emission_energy_multiplier, "绿灯相位没有点亮绿灯并压低红灯")
	city.city_scene_visuals.apply_runtime_state("city-01", "integration_restore")
	city.city_scene_visuals.apply_runtime_context({})
	assert(city.weather_profile == "day", "城市默认视觉配置不是白天")
	assert(not city.apply_visual_profile("storm"), "城市错误接受未登记的天气配置")
	assert(city.weather_profile == "day", "非法天气配置改变了城市当前状态")
	assert(city.apply_visual_profile("dusk"), "城市无法切换到黄昏视觉配置")
	assert(city.weather_profile == "dusk", "城市黄昏视觉配置没有写入状态")
	assert(city.weather_effect_root == null, "黄昏配置意外残留雨后视觉层")
	assert(city.trace.has_event("visual_profile"), "黄昏视觉配置没有记录事件")
	assert(city.apply_visual_profile("rain_after"), "城市无法切换到雨后视觉配置")
	assert(city.weather_profile == "rain_after", "城市雨后视觉配置没有写入状态")
	assert(city.weather_effect_root != null, "雨后配置没有创建独立视觉层")
	assert(bool(city.weather_effect_root.get_meta("visual_only", false)), "雨后视觉层没有登记为 visual_only")
	assert(bool(city.weather_effect_root.get_meta("visual_candidate", false)), "雨后视觉层没有登记为 visual_candidate")
	var rain_streak_count := 0
	for weather_child in city.weather_effect_root.get_children():
		if str(weather_child.name).begins_with("雨痕-"):
			rain_streak_count += 1
	assert(city.weather_effect_root.find_child("雨后湿润路面", true, false) != null, "雨后视觉层没有创建湿润路面")
	assert(rain_streak_count == 20, "雨后视觉层没有保留 20 条雨痕")
	assert(city.weather_effect_root.get_child_count() >= 24, "雨后视觉层没有保留新增的积水与排水反光细节")
	_assert_visual_only_subtree(city.weather_effect_root, "雨后视觉层")
	assert(city.apply_visual_profile("day"), "城市无法恢复白天视觉配置")
	assert(city.weather_profile == "day", "城市恢复白天配置后状态错误")
	assert(city.weather_effect_root == null, "恢复白天配置后仍残留雨后视觉层")
	var neighborhood_entry_position: Vector3 = city.neighborhood_entry
	city.player.position = neighborhood_entry_position + Vector3(20.0, 0.0, 0.0)
	assert(not city.enter_neighborhood_extension(), "远离巷道入口时错误进入后场仓储街区")
	assert(city.neighborhood_status == "locked", "远离入口的失败进入改变了街区状态")
	city.player.position = neighborhood_entry_position
	assert(city.enter_neighborhood_extension(), "靠近巷道入口时无法进入后场仓储街区")
	assert(city.neighborhood_status == "active", "进入后场仓储街区后状态没有激活")
	assert(city.city_scene_visuals.active_state == "city-05", "进入后场仓储街区后没有切换到 city-05 离店道路构图")
	assert(city.trace.has_event("neighborhood_entered"), "进入后场仓储街区没有记录事件")
	assert(city.find_child("新街区巷道", true, false) != null, "城市缺少新街区巷道")
	assert(city.find_child("后场仓储建筑", true, false) != null, "城市缺少后场仓储建筑")
	var warehouse_facade := city.find_child("原创写实后场仓储门面候选", true, false)
	assert(warehouse_facade != null, "城市缺少原创后场仓储门面候选")
	assert(bool(warehouse_facade.get_meta("visual_candidate", false)), "后场仓储门面没有登记为视觉候选")
	var city_main_player_visual: Node = city.player.get_node_or_null("Visual")
	assert(city_main_player_visual != null, "正式城市运行时没有挂载原创主角候选")
	assert(city_main_player_visual.has_meta("original_procedural_asset"), "城市主角候选缺少原创资产元数据")
	assert(city_main_player_visual.get_node_or_null("候选主角背包") != null, "城市主角候选没有保持办公室一致的背包识别")
	assert(city_main_player_visual.get_node_or_null("AnimationPlayer") != null, "城市主角候选缺少动画状态桥接入口")
	assert(city.vehicle.get_node_or_null("Visual") != null, "正式城市运行时没有挂载三轮车视觉候选")
	assert(city.vehicle.get_node("Visual").find_child("候选三轮车车体", true, false) != null, "正式城市运行时没有挂载候选三轮车车体")
	assert(city.vehicle.get_node("Visual").has_meta("original_procedural_asset"), "正式城市三轮车候选缺少原创资产元数据")
	assert(city.vehicle.get_node("Visual").find_child("候选三轮车损伤面板", true, false) != null, "正式城市三轮车候选缺少损伤反馈面板")
	assert(city.vehicle_wheels.size() == 3, "正式城市三轮车候选没有绑定三个滚动车轮")
	assert(is_equal_approx(city.pedestrians[0].walk_speed, 1.4), "城市人群速度没有从内容包读取")
	assert(is_equal_approx(city.traffic_vehicles[2].travel_speed, 1.8), "城市交通速度没有从内容包读取")
	assert(is_equal_approx(city.vehicle_camera_distance, 5.2), "城市载具镜头距离没有从内容包读取")
	assert(is_equal_approx(city.vehicle_camera_height, 2.3), "城市载具镜头高度没有从内容包读取")
	assert(city.pedestrians[0].traffic_sources.size() == city.traffic_vehicles.size(), "城市行人没有接入交通车辆感知")
	city.save_store.save_path = OS.get_temp_dir().path_join("reference-city-integration-%d.json" % Time.get_ticks_usec())
	var pedestrian_start: Vector3 = city.pedestrians[0].global_position
	var traffic_start: Vector3 = city.traffic_vehicles[0].global_position
	var traffic_wheel: Node3D = city.traffic_vehicles[0].find_child("远景车辆车轮-左", true, false) as Node3D
	assert(traffic_wheel != null, "城市交通车辆缺少可驱动的车轮视觉节点")
	var traffic_wheel_rotation: float = traffic_wheel.rotation.x
	city.pedestrians[0]._physics_process(1.0)
	city.traffic_vehicles[0]._physics_process(1.0)
	assert(city.pedestrians[0].global_position.distance_to(pedestrian_start) > 0.1, "城市行人没有沿内容包路线移动")
	assert(city.traffic_vehicles[0].global_position.distance_to(traffic_start) > 0.1, "城市交通车辆没有沿内容包路线移动")
	assert(absf(traffic_wheel.rotation.x - traffic_wheel_rotation) > 0.01, "城市交通车辆移动时车轮没有同步旋转")
	var signal_vehicle = city.traffic_vehicles[0]
	signal_vehicle.global_position = Vector3(-2.0, 0.55, 4.8)
	signal_vehicle.velocity = Vector3(0.0, 0.0, -signal_vehicle.travel_speed)
	signal_vehicle.set_signal_red(true)
	var signal_stop_start: Vector3 = signal_vehicle.global_position
	signal_vehicle._physics_process(0.5)
	assert(signal_vehicle.global_position.distance_to(signal_stop_start) < 0.2, "红灯状态下交通车辆没有在停车点前减速")
	signal_vehicle.set_signal_red(false)
	signal_vehicle._physics_process(0.5)
	assert(signal_vehicle.global_position.distance_to(signal_stop_start) > 0.2, "绿灯状态下交通车辆没有恢复通行")
	city.traffic_vehicles[0].global_position = traffic_start
	var avoidance_pedestrian: CityPedestrian = city.pedestrians[0]
	var avoidance_target: CharacterBody3D = city.traffic_vehicles[0]
	var avoidance_waypoints: Array = avoidance_pedestrian.waypoints.duplicate()
	var avoidance_waypoint_index: int = avoidance_pedestrian.waypoint_index
	avoidance_pedestrian.global_position = avoidance_target.global_position + Vector3(0.8, 0.35, 0.0)
	avoidance_pedestrian.waypoints = [avoidance_pedestrian.global_position + Vector3(0.0, 0.0, 6.0), avoidance_pedestrian.global_position + Vector3(0.0, 0.0, 6.0)]
	avoidance_pedestrian.waypoint_index = 0
	avoidance_target.velocity = Vector3(0.0, 0.0, -2.0)
	var avoidance_start: Vector3 = avoidance_pedestrian.global_position
	avoidance_pedestrian._physics_process(0.2)
	assert(avoidance_pedestrian.traffic_avoidance_active, "交通车辆接近时行人没有进入让行状态")
	assert(avoidance_pedestrian.global_position.distance_to(avoidance_start) > 0.05, "行人让行状态没有产生移动")
	assert(avoidance_pedestrian.global_position.x > avoidance_start.x, "行人没有沿远离交通车辆的方向让行")
	avoidance_pedestrian.global_position = Vector3(-4.0, 0.9, -2.0)
	avoidance_pedestrian.waypoints = avoidance_waypoints
	avoidance_pedestrian.waypoint_index = avoidance_waypoint_index
	avoidance_target.velocity = Vector3.ZERO
	avoidance_pedestrian._physics_process(0.2)
	assert(not avoidance_pedestrian.traffic_avoidance_active, "远离交通车辆后行人仍保持让行状态")
	var panic_pedestrian: CityPedestrian = city.pedestrians[1]
	panic_pedestrian.global_position = Vector3(0.0, 0.9, 0.0)
	panic_pedestrian.panic_timer = 0.0
	var panic_start: Vector3 = panic_pedestrian.global_position
	assert(panic_pedestrian.react_to_vehicle(Vector3(-0.8, 0.9, 0.0), 1.0), "高速载具近失没有触发行人惊慌")
	panic_pedestrian._physics_process(0.25)
	assert(panic_pedestrian.panic_timer > 0.0, "行人近失反应没有保留惊慌计时")
	assert(panic_pedestrian.global_position.distance_to(panic_start) > 0.1, "行人近失反应没有远离载具")
	assert(not panic_pedestrian.react_to_vehicle(Vector3.ZERO), "同一惊慌窗口被重复触发")
	var runtime_near_miss_pedestrian: CityPedestrian = city.pedestrians[2]
	runtime_near_miss_pedestrian.displaced = false
	runtime_near_miss_pedestrian.panic_timer = 0.0
	city.vehicle.global_position = Vector3(2.0, 0.7, 0.0)
	city.player.global_position = city.vehicle.global_position + Vector3(0.0, 0.9, 0.0)
	assert(city.vehicle.enter(city.player), "近失事件测试无法让玩家进入载具")
	city.vehicle.current_speed = 2.0
	runtime_near_miss_pedestrian.global_position = city.vehicle.global_position + Vector3(1.0, 0.0, 0.0)
	var wanted_before_near_miss: int = city.wanted.level
	city._check_vehicle_collisions(0.1)
	assert(city.trace.has_event("pedestrian_near_miss"), "城市运行时没有记录行人近失事件")
	assert(city.wanted.level > wanted_before_near_miss, "行人近失没有增加通缉等级")
	assert(runtime_near_miss_pedestrian.panic_timer > 0.0, "城市运行时没有驱动行人惊慌状态")
	assert(city.audio_events.history.any(func(event): return event.get("id", "") == "perception_alert"), "行人近失没有触发警觉音频事件")
	assert(city.vehicle.exit(), "近失事件测试无法退出载具")
	city.wanted.reset()
	city._clear_police_response()
	city.wanted.report(2, "测试通缉")
	city._update_police_response(0.1)
	assert(city.police_vehicles.size() == 1, "两星通缉没有生成警车")
	var police_vehicle: Node = city.police_vehicles[0]
	assert(police_vehicle.pursuit_enabled, "警车没有进入追捕状态")
	assert(police_vehicle.find_child("警车红灯", true, false) != null and police_vehicle.find_child("警车蓝灯", true, false) != null, "警车缺少红蓝交替警灯")
	police_vehicle._physics_process(0.25)
	assert(police_vehicle.find_child("警车红灯", true, false).visible, "警车红灯没有在第一闪烁相位点亮")
	police_vehicle._physics_process(0.25)
	assert(police_vehicle.find_child("警车蓝灯", true, false).visible, "警车蓝灯没有在第二闪烁相位点亮")
	var police_start: Vector3 = police_vehicle.global_position
	police_vehicle._physics_process(0.5)
	assert(police_vehicle.global_position.distance_to(police_start) > 0.1, "警车没有向玩家追捕")
	assert(city.wanted.level == 2, "警车追捕期间通缉等级不应提前衰减")
	city.neighborhood_status = "locked"
	police_vehicle.global_position = city.player.global_position
	city._update_police_response(0.1)
	assert(city.trace.has_event("police_capture"), "警车接触玩家没有记录抓捕事件")
	assert(city.mission.status == MissionChain.Status.FAILED, "警车抓捕没有让当前任务失败")
	assert(city.failure_overlay.visible, "警车抓捕后没有显示任务失败覆盖层")
	assert(city.wanted.level == 0, "警车抓捕后通缉状态没有清零")
	assert(city.police_vehicles.is_empty(), "警车抓捕后没有清理追捕实体")
	var restart_after_capture := InputFrameClass.new()
	restart_after_capture.restart = true
	city.process_input_frame(restart_after_capture, 0.016)
	assert(city.mission.status == MissionChain.Status.ACTIVE, "抓捕失败后按重开没有恢复任务")
	assert(not city.failure_overlay.visible, "抓捕失败后按重开没有隐藏失败覆盖层")
	assert(city.wanted.level == 0, "抓捕失败后按重开没有清零通缉状态")
	assert(city.police_vehicles.is_empty(), "抓捕失败后按重开没有清理警车")
	assert(city.player.global_position.is_equal_approx(Vector3(0.0, 1.0, 9.0)), "抓捕失败后按重开没有回到任务起点")
	assert(city.trace.has_event("mission_restart"), "抓捕失败后按重开没有记录重开事件")
	city.wanted.report(2, "测试通缉")
	city._update_police_response(0.1)
	city.inside_store_aisle = true
	city._update_police_response(1.6)
	assert(city.police_vehicles.is_empty(), "进入安全区后没有甩开警车")
	assert(city.trace.has_event("police_lost"), "甩开警车没有写入回放")
	city.inside_store_aisle = false
	city.wanted.reset()
	city._update_police_response(0.1)
	assert(city.police_vehicles.is_empty(), "通缉归零后警车没有清理")
	assert(city.pedestrians[0].find_child("Visual", true, false) != null or city.pedestrians[0].find_child("手臂-左", true, false) != null, "城市行人缺少可替换的人体轮廓")
	var city_crowd_candidate: Node = city.pedestrians[0].find_child("Visual", true, false)
	assert(city_crowd_candidate != null and city_crowd_candidate.has_meta("original_procedural_asset"), "正式城市运行时没有挂载原创程序化人群候选")
	assert(city_crowd_candidate.get_node_or_null("AnimationPlayer") != null, "原创程序化人群候选缺少动画契约")
	assert(city_crowd_candidate.get_node("AnimationPlayer").has_animation("walk_default"), "原创程序化人群候选缺少行走动作")
	assert(city_crowd_candidate.find_child("原创程序化颈部", true, false) != null, "原创程序化人群缺少颈部轮廓细节")
	assert(city_crowd_candidate.find_child("原创程序化鼻部细节", true, false) != null, "原创程序化人群缺少面部轮廓细节")
	assert(city_crowd_candidate.find_child("原创程序化嘴部细节", true, false) != null, "原创程序化人群缺少嘴部轮廓细节")
	assert(city_crowd_candidate.find_child("原创程序化腰带", true, false) != null, "原创程序化人群缺少腰部服装层次")
	assert(city_crowd_candidate.find_child("原创程序化左鞋底", true, false) != null, "原创程序化人群缺少左鞋底细节")
	assert(city_crowd_candidate.find_child("原创程序化右鞋底", true, false) != null, "原创程序化人群缺少右鞋底细节")
	_assert_original_crowd_grounded(city_crowd_candidate, "城市逻辑行人视觉")
	assert(city.visual_crowd_root != null, "城市缺少纯视觉人群层")
	assert(bool(city.visual_crowd_root.get_meta("visual_only", false)), "城市纯视觉人群层没有登记为 visual_only")
	assert(bool(city.visual_crowd_root.get_meta("visual_candidate", false)), "城市纯视觉人群层没有登记为 visual_candidate")
	assert(city.visual_crowd_root.get_child_count() == 18, "城市纯视觉人群没有按前中后景契约创建 18 个角色")
	for visual_crowd_wrapper in city.visual_crowd_root.get_children():
		assert(visual_crowd_wrapper is Node3D, "城市纯视觉人群容器不是 Node3D")
		assert(bool(visual_crowd_wrapper.get_meta("visual_only", false)), "城市纯视觉人群容器缺少 visual_only 标记")
		assert(is_equal_approx(visual_crowd_wrapper.position.y, 1.075 * visual_crowd_wrapper.scale.y * float(visual_crowd_wrapper.get_meta("candidate_role_scale", 1.0))), "城市纯视觉人群实例脚底必须同时按体型和实例缩放贴地")
		assert(visual_crowd_wrapper.get_child_count() == 1, "城市纯视觉人群容器包含未登记的逻辑子节点")
		_assert_visual_only_subtree(visual_crowd_wrapper.get_child(0), "城市纯视觉人群")
	var city_horizon := city.get_node_or_null("原创城市远景层")
	assert(city_horizon != null, "城市缺少原创远景层")
	assert(bool(city_horizon.get_meta("visual_only", false)), "城市远景层没有登记为 visual_only")
	assert(bool(city_horizon.get_meta("visual_candidate", false)), "城市远景层没有登记为 visual_candidate")
	assert(city_horizon.get_node_or_null("城市远景连续地面") != null, "城市远景层缺少连续地面")
	assert(city_horizon.find_child("城市远景楼体_00", true, false) != null, "城市远景层缺少楼体轮廓")
	assert(city_horizon.find_child("城市远景窗带_00_00", true, false) != null, "城市远景层缺少窗带细节")
	assert(city_horizon.find_child("城市远景屋顶设备_00", true, false) != null, "城市远景层缺少屋顶设备轮廓")
	_assert_visual_only_subtree(city_horizon, "城市远景层")
	var conflict_crowd_candidate: Node = city.conflict_agent.get_node_or_null("Visual")
	assert(conflict_crowd_candidate != null, "城市冲突对象没有挂载视觉候选")
	assert(conflict_crowd_candidate.has_meta("city_role") and str(conflict_crowd_candidate.get_meta("city_role")) == "conflict", "城市冲突对象没有解析为冲突角色")
	_assert_original_crowd_grounded(conflict_crowd_candidate, "城市冲突角色视觉")
	assert(city.mission.status == MissionChainClass.Status.ACTIVE, "城市任务没有开始")
	assert(is_equal_approx(city.player.walk_speed, 4.2), "城市玩家速度没有从内容包读取")
	assert(is_equal_approx(city.vehicle.max_speed, 8.0), "城市载具速度没有从内容包读取")
	assert(city.mission.current_stage().get("id") == "collect_eggs", "城市初始目标错误")
	assert(city.city_pack.get("targets", []).size() == 6, "城市目标点没有从内容包加载")
	assert(city.targets.size() == 6, "城市运行时目标点数量错误")
	assert(city.mission_title_label != null and city.money_label != null and city.wanted_label != null, "城市 HUD 缺少任务标题、金钱或星级区域")
	assert(is_equal_approx(city.mission_title_label.anchor_left, 0.5) and is_equal_approx(city.mission_title_label.anchor_right, 0.5), "城市任务标题没有使用居中锚点")
	assert(is_equal_approx(city.money_label.anchor_left, 1.0) and is_equal_approx(city.money_label.anchor_right, 1.0), "城市金钱 HUD 没有使用右上锚点")
	assert(city.find_child("免费鸡蛋红色门头", true, false) != null, "城市缺少免费鸡蛋门头视觉")
	assert(city.find_child("标识-免费鸡蛋", true, false) != null, "城市缺少免费鸡蛋门头文字")
	assert(city.find_child("免费鸡蛋商店后墙", true, false) != null, "城市缺少商店后墙")
	assert(city.find_child("免费鸡蛋商店左墙", true, false) != null, "城市缺少商店左墙")
	var scan_board := city.find_child("扫码登记牌", true, false)
	assert(scan_board != null and bool(scan_board.get_meta("visual_only", false)), "城市扫码登记牌没有登记为纯视觉层")
	assert(scan_board.find_child("扫码登记牌深色标题带", true, false) != null, "城市扫码登记牌缺少深色标题带")
	assert(scan_board.find_child("扫码登记牌二维码边框", true, false) != null, "城市扫码登记牌缺少二维码边框")
	assert(scan_board.find_child("扫码登记牌状态灯", true, false) != null, "城市扫码登记牌缺少状态灯")
	var clerk := city.find_child("登记员", true, false)
	assert(clerk != null and bool(clerk.get_meta("visual_only", false)), "城市登记员没有登记为纯视觉层")
	assert(clerk.find_child("登记员手持设备", true, false) != null, "城市登记员缺少手持设备")
	assert(clerk.find_child("登记员胸牌", true, false) != null, "城市登记员缺少胸牌")
	var road_details := city.find_child("道路视觉细节", true, false)
	assert(road_details != null, "城市缺少道路视觉细节")
	assert(bool(road_details.get_meta("candidate_visual_only", false)), "道路视觉细节必须登记为纯视觉层")
	assert(road_details.find_children("*人行道-纵向*", "MeshInstance3D", true, false).size() == 2, "城市缺少两侧连续人行道")
	assert(road_details.find_children("*人行道-横向*", "MeshInstance3D", true, false).size() == 2, "城市缺少横向连续人行道")
	_assert_visual_only_subtree(road_details, "道路视觉细节")
	var composition_pass := city.find_child("原创城市构图层", true, false)
	assert(composition_pass != null, "城市缺少路口到后场入口的构图层")
	assert(bool(composition_pass.get_meta("visual_only", false)), "城市构图层必须登记为纯视觉层")
	assert(bool(composition_pass.get_meta("candidate_visual_only", false)), "城市构图层必须登记为纯视觉候选")
	assert(composition_pass.get_child_count() == 18, "城市构图层节点数量不符合视觉契约")
	assert(composition_pass.find_child("城市构图-信号杆-01", true, false) != null, "城市构图层缺少路口信号杆")
	assert(composition_pass.find_child("城市构图-街区导视牌", true, false) != null, "城市构图层缺少后场入口导视牌")
	assert(composition_pass.find_child("城市构图-街区导视字", true, false) != null, "城市构图层缺少任务街区导视字")
	_assert_visual_only_subtree(composition_pass, "原创城市构图层")
	var street_storytelling := city.find_child("原创街区故事层", true, false)
	assert(street_storytelling != null, "城市缺少原创街区故事层")
	assert(bool(street_storytelling.get_meta("candidate_visual_only", false)), "街区故事层必须登记为纯视觉层")
	assert(street_storytelling.get_child_count() == 26, "街区故事层节点数量不符合视觉契约")
	assert(street_storytelling.find_child("街区故事-免费鸡蛋遮阳棚", true, false) != null, "街区故事层缺少店铺遮阳棚")
	assert(street_storytelling.find_child("街区故事-货箱-03", true, false) != null, "街区故事层缺少叠放货箱")
	assert(street_storytelling.find_child("街区故事-横跨线缆-01", true, false) != null, "街区故事层缺少横跨线缆")
	_assert_visual_only_subtree(street_storytelling, "原创街区故事层")
	var city_environment_candidate: Node = city.get_node_or_null("Visual")
	assert(city_environment_candidate != null and city_environment_candidate.has_meta("original_procedural_asset"), "正式城市运行时没有挂载原创环境候选")
	assert(city_environment_candidate.find_child("候选店铺门面", true, false) != null, "原创城市环境候选缺少店铺门面")
	var storefront_card := city_environment_candidate.find_child("候选原创写实店铺材质卡", true, false) as MeshInstance3D
	assert(storefront_card != null and storefront_card.mesh is QuadMesh, "原创城市环境候选缺少店铺材质卡")
	assert(storefront_card.material_override is StandardMaterial3D, "原创城市环境店铺材质卡缺少标准材质")
	assert((storefront_card.material_override as StandardMaterial3D).albedo_texture != null, "原创城市环境店铺材质卡没有纹理")
	var storefront_crowd_card := city_environment_candidate.find_child("候选原创写实店铺人群背景卡", true, false) as MeshInstance3D
	assert(storefront_crowd_card != null and storefront_crowd_card.mesh is QuadMesh, "原创城市环境候选缺少店铺人群背景卡")
	assert(storefront_crowd_card.material_override is StandardMaterial3D, "原创城市环境店铺人群背景卡缺少标准材质")
	assert((storefront_crowd_card.material_override as StandardMaterial3D).albedo_texture != null, "原创城市环境店铺人群背景卡没有纹理")
	assert(storefront_crowd_card.get_child_count() == 0, "店铺人群背景卡意外包含逻辑子节点")
	var warehouse_card := city_environment_candidate.find_child("候选原创写实仓储材质卡", true, false) as MeshInstance3D
	assert(warehouse_card != null and warehouse_card.mesh is QuadMesh, "原创城市环境候选缺少仓储材质卡")
	assert(city_environment_candidate.find_child("候选街灯灯罩", true, false) != null, "原创城市环境候选缺少街灯细节")
	assert(city_environment_candidate.find_child("候选原创小型城市楼", true, false) != null, "原创城市环境候选缺少远景建筑")
	for traffic_visual_name in ["原创路侧停靠轿车", "原创路口暖色出租车", "原创远端白色面包车"]:
		var traffic_visual := city_environment_candidate.find_child(traffic_visual_name, true, false) as Node3D
		assert(traffic_visual != null, "原创城市环境候选缺少街道交通视觉：" + traffic_visual_name)
		assert(bool(traffic_visual.get_meta("candidate_visual_only", false)), "街道交通视觉没有登记为 candidate_visual_only：" + traffic_visual_name)
		assert(traffic_visual.find_child("车窗", true, false) != null, "街道交通视觉缺少车窗层：" + traffic_visual_name)
		assert(traffic_visual.find_child("左侧后视镜", true, false) != null, "街道交通视觉缺少左侧后视镜：" + traffic_visual_name)
		assert(traffic_visual.find_child("前车牌", true, false) != null, "街道交通视觉缺少前车牌：" + traffic_visual_name)
		assert(traffic_visual.find_child("左侧车门缝", true, false) != null, "街道交通视觉缺少车门缝：" + traffic_visual_name)
		assert(traffic_visual.find_child("原创车辆轮胎", true, false) != null, "街道交通视觉缺少轮胎层：" + traffic_visual_name)
		assert(traffic_visual.find_child("前左灯", true, false) != null, "街道交通视觉缺少前灯层：" + traffic_visual_name)
		_assert_visual_only_subtree(traffic_visual, traffic_visual_name)
	assert(road_details.get_parent() == city, "城市道路视觉细节没有直接挂在城市根节点")
	assert(road_details.get_child_count() == 60, "城市道路视觉细节数量不符合纯视觉契约")
	var vertical_lane_count := 0
	var horizontal_lane_count := 0
	var vertical_curb_count := 0
	var horizontal_curb_count := 0
	var crosswalk_count := 0
	var drainage_count := 0
	var utility_cover_count := 0
	var sidewalk_count := 0
	var sidewalk_seam_count := 0
	for road_child in road_details.get_children():
		assert(road_child is MeshInstance3D, "道路视觉细节意外包含碰撞或逻辑节点")
		var road_mesh := road_child as MeshInstance3D
		assert(road_mesh.mesh is BoxMesh, "道路视觉细节不是盒状灰盒网格")
		assert(road_mesh.material_override is StandardMaterial3D, "道路视觉细节缺少独立材质")
		assert(road_mesh.get_child_count() == 0, "道路视觉细节包含隐藏的子逻辑节点")
		var box := road_mesh.mesh as BoxMesh
		var child_name := str(road_mesh.name)
		if child_name.begins_with("车道线-纵向-"):
			vertical_lane_count += 1
			assert(is_equal_approx(box.size.x, 0.16) and is_equal_approx(box.size.z, 2.0), "纵向车道线尺寸错误")
			assert(is_equal_approx(road_mesh.position.x, 0.0) and is_equal_approx(road_mesh.position.y, 0.065), "纵向车道线位置错误")
		elif child_name.begins_with("车道线-横向-"):
			horizontal_lane_count += 1
			assert(is_equal_approx(box.size.x, 2.0) and is_equal_approx(box.size.z, 0.16), "横向车道线尺寸错误")
			assert(is_equal_approx(road_mesh.position.z, 0.0) and is_equal_approx(road_mesh.position.y, 0.07), "横向车道线位置错误")
		elif child_name.begins_with("路缘-纵向-"):
			vertical_curb_count += 1
			assert(is_equal_approx(box.size.x, 0.12) and is_equal_approx(box.size.z, 17.0), "纵向路缘尺寸错误")
			assert(is_equal_approx(absf(road_mesh.position.x), 3.35) and is_equal_approx(absf(road_mesh.position.z), 8.5), "纵向路缘位置错误")
		elif child_name.begins_with("路缘-横向-"):
			horizontal_curb_count += 1
			assert(is_equal_approx(box.size.x, 17.0) and is_equal_approx(box.size.z, 0.12), "横向路缘尺寸错误")
			assert(is_equal_approx(absf(road_mesh.position.x), 8.5) and is_equal_approx(absf(road_mesh.position.z), 2.4), "横向路缘位置错误")
		elif child_name.begins_with("北侧斑马线-") or child_name.begins_with("南侧斑马线-"):
			crosswalk_count += 1
			assert(is_equal_approx(box.size.x, 0.42) and is_equal_approx(box.size.z, 2.1), "斑马线尺寸错误")
			assert(is_equal_approx(road_mesh.position.y, 0.082), "斑马线高度错误")
		elif child_name.begins_with("路缘排水沟-"):
			drainage_count += 1
			assert(is_equal_approx(box.size.x, 0.42) and is_equal_approx(box.size.z, 0.9), "路缘排水沟尺寸错误")
			assert(is_equal_approx(road_mesh.position.y, 0.085), "路缘排水沟高度错误")
		elif child_name.begins_with("道路检修井盖-"):
			utility_cover_count += 1
			assert(is_equal_approx(box.size.x, 0.62) and is_equal_approx(box.size.z, 0.62), "道路检修井盖尺寸错误")
			assert(is_equal_approx(road_mesh.position.y, 0.086), "道路检修井盖高度错误")
		elif child_name.begins_with("人行道-纵向-"):
			sidewalk_count += 1
			assert(is_equal_approx(box.size.x, 1.65) and is_equal_approx(box.size.z, 34.0), "纵向人行道尺寸错误")
			assert(is_equal_approx(road_mesh.position.y, 0.09), "纵向人行道高度错误")
		elif child_name.begins_with("人行道-横向-"):
			sidewalk_count += 1
			assert(is_equal_approx(box.size.x, 34.0) and is_equal_approx(box.size.z, 1.65), "横向人行道尺寸错误")
			assert(is_equal_approx(road_mesh.position.y, 0.095), "横向人行道高度错误")
		elif child_name.begins_with("人行道接缝-"):
			sidewalk_seam_count += 1
			assert(is_equal_approx(box.size.x, 1.7) and is_equal_approx(box.size.z, 0.035), "人行道接缝尺寸错误")
			assert(is_equal_approx(road_mesh.position.y, 0.125), "人行道接缝高度错误")
		else:
			assert(false, "道路视觉细节名称未登记：" + child_name)
	assert(vertical_lane_count == 6, "纵向车道线数量错误")
	assert(horizontal_lane_count == 6, "横向车道线数量错误")
	assert(vertical_curb_count == 4, "纵向路缘数量错误")
	assert(horizontal_curb_count == 4, "横向路缘数量错误")
	assert(crosswalk_count == 14, "斑马线数量错误")
	assert(drainage_count == 4, "路缘排水沟数量错误")
	assert(utility_cover_count == 2, "道路检修井盖数量错误")
	assert(sidewalk_count == 4, "人行道数量错误")
	assert(sidewalk_seam_count == 16, "人行道接缝数量错误")
	var frontage_details := city.find_child("街道立面细节", true, false)
	assert(frontage_details != null, "城市缺少沿街建筑立面视觉细节")
	assert(frontage_details.get_child_count() >= 28, "城市沿街立面视觉细节少于四栋建筑基础契约")
	for frontage_child in frontage_details.get_children():
		assert(frontage_child is MeshInstance3D, "城市沿街立面细节意外包含碰撞或逻辑节点")
	var photo_storefront := frontage_details.find_child("原创写实店铺立面候选", true, false) as MeshInstance3D
	assert(photo_storefront != null, "城市背景店铺缺少原创写实立面候选")
	assert(photo_storefront.mesh is QuadMesh, "原创写实店铺立面候选必须使用平面展示网格")
	assert(photo_storefront.material_override is StandardMaterial3D, "原创写实店铺立面候选缺少标准材质")
	var photo_material := photo_storefront.material_override as StandardMaterial3D
	assert(photo_material.albedo_texture != null, "原创写实店铺立面候选没有加载登记纹理")
	assert(str(photo_material.albedo_texture.resource_path).ends_with("urban_storefront_v2_generated.png"), "城市店铺立面没有绑定当前版本原创纹理")
	assert(photo_storefront.get_child_count() == 0, "原创写实店铺立面候选不应挂载逻辑或碰撞子节点")
	assert(city.find_child("扫码登记牌", true, false) != null, "城市缺少扫码登记牌视觉")
	assert(city.find_child("登记员", true, false) != null, "城市缺少登记员角色")
	assert(city.find_child("三轮车座椅", true, false) != null or city.find_child("候选三轮车座椅", true, false) != null, "城市三轮车缺少座椅视觉")
	assert(city.find_child("三轮车车把", true, false) != null or city.find_child("候选三轮车车把", true, false) != null, "城市三轮车缺少车把视觉")
	assert(city.find_child("三轮车货架", true, false) != null or city.find_child("候选三轮车货架", true, false) != null, "城市三轮车缺少货架视觉")
	assert(city.find_child("入口人群", true, false) != null, "城市缺少入口人群碰撞")
	assert(city.crowd_blockers.size() >= 10, "城市入口人群密度不足")
	assert(city.traffic_vehicles.size() == 3, "城市缺少背景交通车辆")
	assert(city.camera_rig.snapshot().has("collision_distance"), "城市镜头快照缺少碰撞距离")
	assert(city.find_child("商店货架_左", true, false) != null, "城市缺少左侧货架")
	assert(city.find_child("商店货架_右", true, false) != null, "城市缺少右侧货架")
	var new_shop_facade := city.find_child("旺铺转让门面", true, false)
	assert(new_shop_facade != null and bool(new_shop_facade.get_meta("visual_only", false)), "城市目标店铺门面没有登记为纯视觉层")
	var shutter_detail := new_shop_facade.find_child("旺铺转让卷帘门细节", true, false)
	assert(shutter_detail != null and shutter_detail.get_child_count() == 8, "城市目标店铺缺少八道卷帘门横槽")
	assert(new_shop_facade.find_child("旺铺转让门框左柱", true, false) != null, "城市目标店铺缺少左门框立柱")
	assert(new_shop_facade.find_child("旺铺转让门框右柱", true, false) != null, "城市目标店铺缺少右门框立柱")
	assert(new_shop_facade.find_child("旺铺转让招牌局部暖光", true, false) != null, "城市目标店铺缺少招牌局部暖光")
	for traffic in city.traffic_vehicles:
		assert(traffic is CharacterBody3D, "背景交通车辆没有移动碰撞体")
		assert(traffic.find_child("交通碰撞体", true, false) != null, "背景交通缺少碰撞形状")
		assert(traffic.find_child("远景车辆车顶", true, false) != null, "背景交通缺少车顶视觉")
		assert(traffic.find_child("远景车辆左尾灯", true, false) != null, "背景交通缺少尾灯视觉")
		assert(traffic.find_child("远景车辆车轮-左", true, false) != null, "背景交通缺少车轮视觉")
	city.player.position = Vector3(-9.0, 0.9, -6.8)
	var enter_store_frame := InputFrameClass.new()
	enter_store_frame.move = Vector2(0.0, -1.0)
	for index in range(60):
		city.process_input_frame(enter_store_frame, 0.1)
		if city.inside_store_aisle:
			break
	assert(city.inside_store_aisle, "玩家无法从商店入口进入货架通道")
	assert(city.audio_events.history.any(func(event): return str(event.get("id", "")) == "footstep"), "城市移动没有进入脚步音频事件路由")
	assert(is_equal_approx(city.camera_rig.distance, 2.5), "进入商店后镜头没有切换到室内跟随距离")
	city.process_input_frame(InputFrameClass.new(), 0.016)
	assert(city.trace.has_event("navigation"), "进入货架通道没有记录导航事件")
	var crowd_collision_frame := InputFrameClass.new()
	crowd_collision_frame.move = Vector2(-1.0, 0.0)
	city.process_input_frame(crowd_collision_frame, 0.2)
	assert(city.trace.has_event("collision"), "城市人群碰撞没有记录事件")

	_interact_at(city, 0)
	assert(city.inventory.has_item("egg_tray"), "领取鸡蛋后库存没有物品")
	assert(city.player.presentation_snapshot()["state"] == city.player.PresentationState.INTERACT, "城市交互没有驱动角色表现状态")
	assert(city.cargo_visual.visible, "领取鸡蛋后角色没有显示携带物")
	assert(city.cargo_visual.name == "玩家携带鸡蛋托盘", "城市携带物没有使用原创鸡蛋托盘根节点")
	var cargo_rim_count := 0
	var cargo_egg_count := 0
	for cargo_mesh in city.cargo_visual.find_children("*", "MeshInstance3D", true, false):
		if str(cargo_mesh.name).begins_with("鸡蛋托盘侧框"):
			cargo_rim_count += 1
		if str(cargo_mesh.name).begins_with("鸡蛋托盘鸡蛋"):
			cargo_egg_count += 1
	assert(cargo_rim_count >= 2, "城市携带托盘缺少侧框")
	assert(cargo_egg_count >= 8, "城市携带托盘缺少鸡蛋视觉层")
	assert(bool(city.cargo_visual.get_meta("visual_only", false)), "城市携带托盘不得承载任务逻辑")
	assert(city.mission.current_stage().get("id") == "leave_store", "领取后没有进入离店目标")
	assert(str(city.cargo_visual.get_meta("carry_pose", "")) == "raised_exit", "离店阶段没有将鸡蛋托盘切换为高位奔跑姿态")
	assert(float(city.cargo_visual.position.y) > 1.20, "离店阶段鸡蛋托盘仍停留在低位携带高度")

	city.player.position = Vector3(-9.0, 0.9, -10.5)
	var leave_store_frame := InputFrameClass.new()
	leave_store_frame.move = Vector2(0.0, 1.0)
	for index in range(12):
		city.process_input_frame(leave_store_frame, 0.1)
		if city.targets[1].can_interact(city.player.global_position):
			break
	assert(city.targets[1].can_interact(city.player.global_position), "携带鸡蛋时无法真实走到商店出口")
	var leave_interact := InputFrameClass.new()
	leave_interact.interact = true
	city.process_input_frame(leave_interact, 0.016)
	assert(city.mission.current_stage().get("id") == "register", "离店后没有进入登记目标")

	# 在任务进行中建立断点，验证玩家未登记时的任务阶段、库存、位置和镜头可以完整恢复。
	city.player.position = Vector3(-2.5, 1.0, -1.5)
	city.camera_rig.set_orbit(27.0, -16.0)
	var checkpoint_position: Vector3 = city.player.position
	assert(city.save_store.save_city_checkpoint(city.mission, city.inventory, checkpoint_position, city.registered, city.conflict.snapshot(), city.camera_rig.snapshot(), {}, city.CITY_PACK_ID), "城市进行中断点写入失败")
	city.inventory.remove_item("egg_tray")
	city.registered = true
	city.player.position = Vector3(12.0, 1.0, 12.0)
	city.camera_rig.set_orbit(-12.0, -8.0)
	var load_checkpoint_frame := InputFrameClass.new()
	load_checkpoint_frame.load_checkpoint = true
	city.process_input_frame(load_checkpoint_frame, 0.016)
	assert(city.mission.current_stage().get("id") == "register", "城市进行中断点读取错误推进了任务阶段")
	assert(city.inventory.has_item("egg_tray"), "城市进行中断点读取没有恢复携带物")
	assert(not city.registered, "城市进行中断点读取错误恢复登记状态")
	assert(city.player.position.distance_to(checkpoint_position) < 0.001, "城市进行中断点读取没有恢复玩家位置")
	assert(is_equal_approx(city.camera_rig.yaw_degrees, 27.0), "城市进行中断点读取没有恢复镜头朝向")
	assert(city.trace.has_event("checkpoint_loaded"), "城市进行中断点读取没有记录成功事件")
	assert(city.audio_events.history.any(func(event): return str(event.get("id", "")) == "checkpoint_loaded"), "城市读取存档没有发出音频事件")

	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	var enter_frame = InputFrameClass.new()
	enter_frame.vehicle_enter_exit = true
	city.process_input_frame(enter_frame, 0.016)
	assert(city.vehicle.driver == city.player, "城市回放没有进入三轮车")
	assert(city.player.visible, "城市进入三轮车后驾驶者不应消失")
	assert(city.player.global_position.distance_to(city.vehicle.driver_seat_position()) < 0.001, "城市驾驶者没有挂到三轮车座椅")
	assert(city.player.presentation_snapshot()["state"] == city.player.PresentationState.VEHICLE, "城市进入三轮车后没有同步载具视觉状态")
	var city_player_visual: Node = city.player.get_node_or_null("Visual")
	if city_player_visual == null:
		city_player_visual = city.player.find_child("原创灰盒角色外观", true, false)
	assert(city_player_visual != null and float(city_player_visual.position.y) < 0.0, "城市玩家没有应用载具坐姿偏移")
	if city_player_visual != null and city_player_visual.get_node_or_null("AnimationPlayer") != null:
		assert(city_player_visual.get_node("AnimationPlayer").current_animation == "vehicle_default", "城市候选玩家没有播放载具动作")
	assert(is_equal_approx(city.camera_rig.distance, 5.2), "进入三轮车后镜头没有切换到载具跟随距离")
	assert(is_equal_approx(city.camera_rig.pitch_degrees, -12.0), "进入三轮车后镜头没有切换到低位车尾俯角")
	var drive_frame = InputFrameClass.new()
	drive_frame.move = Vector2(0.0, -1.0)
	var vehicle_start: Vector3 = city.vehicle.position
	var wheel_rotation_start: float = city.vehicle_wheels[0].rotation.x
	for index in range(10):
		city.process_input_frame(drive_frame, 0.1)
	assert(city.vehicle.position.distance_to(vehicle_start) > 0.1, "三轮车驾驶没有产生位移")
	assert(city.audio_events.history.any(func(event): return str(event.get("id", "")) == "vehicle_engine"), "城市载具移动没有进入引擎音频事件路由")
	assert(absf(city.vehicle_wheels[0].rotation.x - wheel_rotation_start) > 0.01, "三轮车车轮没有随驾驶位移滚动")
	var front_wheel_yaw_start: float = city.vehicle_wheels[2].rotation.y
	var steering_drive_frame := InputFrameClass.new()
	steering_drive_frame.move = Vector2(1.0, -1.0)
	for index in range(6):
		city.process_input_frame(steering_drive_frame, 0.1)
	assert(absf(city.vehicle_wheels[2].rotation.y - front_wheel_yaw_start) > 0.05, "三轮车前轮没有随转向输入同步偏转")
	assert(absf(city.vehicle.steering_input) > 0.1, "三轮车没有保留当前转向输入供视觉层读取")
	var candidate_damage_panel: Node = city.vehicle.find_child("候选三轮车损伤面板", true, false)
	if candidate_damage_panel != null:
		city.apply_vehicle_collision_damage(10.0)
		city._update_vehicle_damage_feedback()
		assert(candidate_damage_panel.visible, "候选三轮车受损后没有显示专属损伤面板")
		assert(not city.vehicle_damage_visual.visible, "候选三轮车仍叠加显示灰盒损伤条")
		assert(not city.vehicle_damage_side_visual.visible, "候选三轮车仍叠加显示灰盒损伤侧板")
		assert(not city.vehicle_damage_warning_visual.visible, "候选三轮车仍叠加显示灰盒损伤警示灯")
		for smoke in city.vehicle_damage_smoke:
			assert(not smoke.visible, "候选三轮车仍叠加显示灰盒损伤烟雾")
		city.vehicle_integrity = 100.0
		city._update_vehicle_damage_feedback()
	var driving_checkpoint_position: Vector3 = city.vehicle.position
	var driving_checkpoint_speed: float = city.vehicle.current_speed
	assert(city.save_store.save_city_checkpoint(city.mission, city.inventory, city.player.position, city.registered, city.conflict.snapshot(), city.camera_rig.snapshot(), city.vehicle.snapshot(), city.CITY_PACK_ID), "驾驶中城市存档写入失败")
	city.vehicle.position = Vector3(20.0, 0.7, 20.0)
	city.vehicle.current_speed = 0.0
	city._load_city_checkpoint()
	assert(city.vehicle.position.distance_to(driving_checkpoint_position) < 0.001, "读取城市存档没有恢复驾驶中的载具位置")
	assert(is_equal_approx(city.vehicle.current_speed, driving_checkpoint_speed), "读取城市存档没有恢复驾驶中的载具速度")
	assert(city.vehicle.driver == city.player, "读取城市存档没有恢复驾驶状态")
	assert(city.player.presentation_snapshot()["state"] == city.player.PresentationState.VEHICLE, "读取城市驾驶存档后没有恢复玩家载具表现状态")
	var exit_frame = InputFrameClass.new()
	exit_frame.vehicle_enter_exit = true
	city.process_input_frame(exit_frame, 0.016)
	assert(city.vehicle.driver == null, "城市回放没有退出三轮车")
	assert(is_equal_approx(city.camera_rig.pitch_degrees, -16.0), "退出三轮车后镜头没有恢复进入载具前的俯角")

	_interact_at(city, 2)
	assert(city.registered, "登记交互没有记录登记状态")
	assert(not city.inventory.has_item("egg_tray"), "登记后鸡蛋没有按规则消耗")
	assert(city.trace.has_event("clerk_interaction"), "登记交互没有记录登记员事件")
	assert(city.mission.current_stage().get("id") == "enter_backlot", "登记后没有进入后场目标")

	_interact_at(city, 3)
	assert(city.neighborhood_status == "active", "进入后场目标没有激活后场街区")
	assert(city.trace.has_event("neighborhood_entered"), "任务进入后场没有记录街区事件")
	assert(city.mission.current_stage().get("id") == "load_stock", "进入后场后没有进入装货目标")

	_interact_at(city, 4)
	assert(city.inventory.has_item("stock_crate"), "后场装货后库存没有货物")
	assert(city.mission.current_stage().get("id") == "new_shop", "装货后没有进入送货目标")

	_interact_at(city, 5)
	assert(city.mission.status == MissionChainClass.Status.SUCCESS, "城市任务没有完成")
	assert(city.mission.money == 260, "城市任务奖励金额错误")
	assert(city.mission.stars == 5, "城市任务星级错误")
	assert(not city.inventory.has_item("stock_crate"), "送货完成后货物没有从库存移除")
	assert(city.trace.has_event("stock_loaded"), "后场装货没有记录货物事件")
	assert(city.trace.has_event("stock_delivered"), "旺铺送货没有记录完成事件")
	assert(city.trace.has_event("interaction"), "城市回放没有记录交互事件")
	assert(city.trace.has_event("input"), "城市回放没有记录输入事件")
	assert(city.trace.has_event("audio_event"), "城市回放没有记录音频事件")
	assert(FileAccess.file_exists(city.save_store.save_path), "城市任务成功后没有自动写入检查点")
	var success_checkpoint = JSON.parse_string(FileAccess.get_file_as_string(city.save_store.save_path))
	assert(success_checkpoint is Dictionary, "城市任务成功检查点不是有效 JSON 对象")
	var success_mission = success_checkpoint.get("mission_chain", {})
	assert(int(success_mission.get("status", MissionChainClass.Status.NOT_STARTED)) == MissionChainClass.Status.SUCCESS, "城市任务成功检查点没有保存 SUCCESS 状态")
	assert(int(success_mission.get("money", -1)) == 260, "城市任务成功检查点没有保存奖励金额")
	assert(int(success_mission.get("stars", -1)) == 5, "城市任务成功检查点没有保存任务星级")
	var restored_city = CityScene.instantiate()
	restored_city.set_meta("save_path", city.save_store.save_path)
	restored_city.set_meta("load_checkpoint", true)
	get_root().add_child(restored_city)
	await process_frame
	await process_frame
	assert(restored_city.initialized, "城市重启实例没有完成初始化")
	assert(restored_city.mission.status == MissionChainClass.Status.SUCCESS, "城市重启实例没有自动恢复 SUCCESS 状态")
	assert(restored_city.mission.money == 260 and restored_city.mission.stars == 5, "城市重启实例没有恢复任务奖励和星级")
	assert(restored_city.trace.has_event("checkpoint_loaded"), "城市重启实例没有记录自动读档事件")
	restored_city.queue_free()
	await process_frame
	city.camera_rig.set_orbit(33.0, -18.0)
	assert(is_equal_approx(float(city.camera_rig.snapshot().get("yaw", 0.0)), 33.0), "城市测试设置镜头朝向后快照不一致")
	city._save_city_checkpoint()
	var saved_city_payload = JSON.parse_string(FileAccess.get_file_as_string(city.save_store.save_path))
	assert(is_equal_approx(float(saved_city_payload.get("camera", {}).get("yaw", 0.0)), 33.0), "城市镜头朝向没有写入存档")
	city.camera_rig.set_orbit(-10.0, -10.0)
	city._load_city_checkpoint()
	assert(is_equal_approx(city.camera_rig.yaw_degrees, 33.0), "城市读取存档没有恢复镜头朝向")
	assert(is_equal_approx(city.camera_rig.pitch_degrees, -18.0), "城市读取存档没有恢复镜头俯仰")

	# 载具损毁也是城市任务的真实失败分支：损毁必须进入失败覆盖层，
	# 然后可以通过同一套重开输入恢复到可继续游玩的任务起点。
	city.mission.restart()
	# 前面的警车失败测试按下过一次重开键；先模拟按键释放，避免把输入锁
	# 误认为玩家仍在持续按住重开键，从而掩盖载具失败分支本身。
	city.process_input_frame(InputFrameClass.new(), 0.016)
	city.vehicle_integrity = 100.0
	assert(city.apply_vehicle_collision_damage(100.0, "测试撞击"), "载具损毁测试没有接受有效碰撞伤害")
	assert(city.trace.has_event("vehicle_failed"), "载具损毁没有记录失败事件")
	assert(city.mission.status == MissionChainClass.Status.FAILED, "载具损毁没有让当前任务失败")
	assert(city.failure_overlay.visible, "载具损毁后没有显示任务失败覆盖层")
	var vehicle_restart_frame := InputFrameClass.new()
	vehicle_restart_frame.restart = true
	city.process_input_frame(vehicle_restart_frame, 0.016)
	assert(city.mission.status == MissionChainClass.Status.ACTIVE, "载具损毁后按重开没有恢复任务")
	assert(city.vehicle_integrity == 100.0, "载具损毁后按重开没有恢复载具耐久")
	assert(not city.failure_overlay.visible, "载具损毁后按重开没有隐藏失败覆盖层")

	city.set_meta("reference_capture_scenario", "city-11")
	city.prepare_reference_capture(false)
	assert(not city.visual_crowd_root.visible, "city-11 参考采集仍显示纯视觉人群层")
	var endpoint_facade := city.get_node_or_null("旺铺转让门面")
	assert(endpoint_facade == null or not endpoint_facade.visible, "city-11 参考采集仍显示旺铺转让门面程序化前景")
	for endpoint_visual in city.find_children("*", "Node3D", true, false):
		if endpoint_visual.name.contains("原创终点店") or endpoint_visual.name.contains("旺铺转让"):
			assert(not endpoint_visual.visible, "city-11 参考采集仍显示终点门面节点：" + endpoint_visual.name)
	var capture_vehicle_visual: Node = city.vehicle.get_node_or_null("Visual")
	if capture_vehicle_visual != null:
		var candidate_vehicle_root := capture_vehicle_visual.get_node_or_null("ThreeWheelDelivery") as Node3D
		if candidate_vehicle_root != null:
			assert(candidate_vehicle_root.visible, "参考采集错误隐藏了完整三轮车候选视觉根节点")
		for vehicle_mesh in capture_vehicle_visual.find_children("*", "MeshInstance3D", true, false):
			if vehicle_mesh.name.contains("顶篷") or vehicle_mesh.name.contains("顶棚"):
				assert(not vehicle_mesh.visible, "city-11 参考采集仍显示三轮车顶篷：" + vehicle_mesh.name)
	city.set_meta("reference_capture_scenario", "city-01")
	city.prepare_reference_capture(false)
	for pedestrian in city.pedestrians:
		assert(pedestrian.visible, "city-01 参考采集没有保留原创三维逻辑行人：" + pedestrian.name)
	for crowd_blocker in city.crowd_blockers:
		assert(crowd_blocker.visible, "city-01 参考采集没有保留入口人群视觉：" + crowd_blocker.name)
	assert(city.visual_crowd_root.visible, "city-01 参考采集没有保留原创程序化纯视觉人群层")
	var city_capture_storefront_crowd := city_environment_candidate.find_child("候选原创写实店铺人群背景卡", true, false) as MeshInstance3D
	assert(city_capture_storefront_crowd == null or not city_capture_storefront_crowd.visible, "city-01 参考采集仍显示环境店铺背景卡，应该使用授权远景背景层")
	var city_capture_board := city.get_node_or_null("扫码登记牌")
	assert(city_capture_board == null or not city_capture_board.visible, "city-01 参考采集仍显示扫码登记牌")
	var city_capture_road_details := city.get_node_or_null("道路视觉细节")
	assert(city_capture_road_details == null or not city_capture_road_details.visible, "city-01 参考采集仍显示程序化道路细节")
	var city_capture_props := city.get_node_or_null("交互道具层")
	assert(city_capture_props == null or not city_capture_props.visible, "city-01 参考采集仍显示交互道具候选层")
	# city-04 的店内冲突镜头允许使用候选背景卡承接远景像素，但背景卡必须
	# 落在真实玩家与冲突对象之后，不能因为与角色同深度而吞掉前景演员。
	city.set_meta("reference_capture_scenario", "city-04")
	city.set_meta("candidate_video_backdrop", true)
	city.set_meta("candidate_gameplay_video_backdrop", true)
	city.set_meta("candidate_video_backdrop_id", "city-04")
	city.prepare_reference_capture(false)
	var city04_backdrop := city.camera_rig.camera.find_child("用户授权城市视频帧候选背景卡", true, false) as MeshInstance3D
	assert(city04_backdrop != null and city04_backdrop.visible, "city-04 候选背景卡没有接入相机")
	assert(float(city04_backdrop.position.z) <= -30.0, "city-04 背景卡离相机过近，可能遮挡真实演员")
	assert(city04_backdrop.mesh is QuadMesh and (city04_backdrop.mesh as QuadMesh).size.x >= 90.0, "city-04 背景卡尺寸不足以覆盖安全视锥")
	assert(city.player.visible, "city-04 候选背景卡接入后错误隐藏玩家根节点")
	var frozen_pedestrian_position: Vector3 = city.pedestrians[0].global_position
	var frozen_traffic_position: Vector3 = city.traffic_vehicles[0].global_position
	await physics_frame
	await physics_frame
	assert(city.pedestrians[0].global_position.distance_to(frozen_pedestrian_position) < 0.001, "参考截图冻结后行人仍在漂移")
	assert(city.traffic_vehicles[0].global_position.distance_to(frozen_traffic_position) < 0.001, "参考截图冻结后交通车辆仍在漂移")

	city.queue_free()
	await process_frame
	print("城市任务端到端回放测试通过")
	quit(0)

func _interact_at(city, target_index: int) -> void:
	var target = city.targets[target_index]
	city.player.position = target.position + Vector3(0.0, 0.0, 1.0)
	city.process_input_frame(InputFrameClass.new(), 0.016)
	assert(city.prompt_label.text == "E  " + target.prompt, "接近城市目标后没有显示交互提示")
	var frame = InputFrameClass.new()
	frame.interact = true
	city.process_input_frame(frame, 0.016)

func _assert_visual_only_subtree(root: Node, label: String) -> void:
	assert(not (root is CollisionObject3D), label + "包含碰撞对象：" + root.name)
	assert(not (root is CollisionShape3D), label + "包含碰撞形状：" + root.name)
	assert(not (root is CollisionPolygon3D), label + "包含碰撞多边形：" + root.name)
	assert(not (root is NavigationRegion3D), label + "包含导航区域：" + root.name)
	assert(not (root is NavigationLink3D), label + "包含导航连接：" + root.name)
	assert(not (root is Area3D), label + "包含区域逻辑：" + root.name)
	for child in root.get_children():
		_assert_visual_only_subtree(child, label)

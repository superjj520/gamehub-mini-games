extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

const TEST_SIZES := [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1920, 1080)]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _verify_office()
	await _verify_city()
	print("多分辨率 HUD 锚点集成测试通过")
	quit(0)

func _verify_office() -> void:
	var office = OfficeScene.instantiate()
	get_root().add_child(office)
	await process_frame
	assert(office.hud_visual != null, "办公室缺少新的 HUD 表现层")
	assert(office.hud_visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "办公室 HUD 表现层不应拦截游戏输入")
	office.call("_update_hud")
	assert(str(office.hud_visual.distance_text).ends_with("m"), "办公室 HUD 没有消费任务目标距离")
	assert(office.hud_visual.radar_points.size() >= 2, "办公室雷达没有消费目标与 NPC 世界坐标")
	assert(office.hud_visual.radar_point_colors.size() >= 2, "办公室雷达没有消费目标与警戒对象颜色")
	assert(office.hud_visual.radar_point_colors[1].r > office.hud_visual.radar_point_colors[1].b, "办公室警戒对象没有使用警戒色")
	var office_forward_point: Vector2 = office.call("_radar_point_for_world", office.player.global_position - office.player.global_transform.basis.z.normalized() * 9.0)
	var office_right_point: Vector2 = office.call("_radar_point_for_world", office.player.global_position + office.player.global_transform.basis.x.normalized() * 9.0)
	assert(office_forward_point.y < -0.2, "办公室雷达没有把前方世界目标投影到上方")
	assert(office_right_point.x > 0.2, "办公室雷达没有把右侧世界目标投影到右方")
	var office_distance_before := str(office.hud_visual.distance_text)
	office.player.global_position = office.objective_target.global_position + Vector3(9.0, 0.0, 0.0)
	office.call("_update_hud")
	assert(str(office.hud_visual.distance_text) == "9m", "办公室任务距离没有随玩家位置更新")
	assert(str(office.hud_visual.distance_text) != office_distance_before or office_distance_before == "9m", "办公室任务距离没有形成动态变化证据")
	for viewport_size in TEST_SIZES:
		get_root().get_viewport().size = viewport_size
		await process_frame
		assert(absf(office.hud_visual.size.x - viewport_size.x) < 1.0 and absf(office.hud_visual.size.y - viewport_size.y) < 1.0, "办公室 HUD 表现层没有铺满当前视口")
		var clock_position: Vector2 = office.clock_label.global_position
		var prompt_position: Vector2 = office.prompt_label.global_position
		assert(clock_position.x > viewport_size.x * 0.78, "办公室时钟在视口缩放后没有保持右侧")
		assert(prompt_position.y > viewport_size.y * 0.88, "办公室交互提示在视口缩放后没有保持底部")
	office.queue_free()
	await process_frame

func _verify_city() -> void:
	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	assert(city.hud_visual != null, "城市缺少新的 HUD 表现层")
	assert(city.hud_visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "城市 HUD 表现层不应拦截游戏输入")
	city.call("_update_hud")
	assert(str(city.hud_visual.distance_text).ends_with("m"), "城市 HUD 没有消费任务目标距离")
	assert(city.hud_visual.radar_points.size() >= 2, "城市雷达没有消费任务目标与载具世界坐标")
	assert(city.hud_visual.radar_point_colors.size() >= 2, "城市雷达没有消费目标与载具颜色")
	assert(city.hud_visual.radar_point_colors[1].b > city.hud_visual.radar_point_colors[1].r, "城市载具没有使用蓝色雷达标记")
	city.hud_visual.apply_state({
		"mode": "city",
		"money": 190,
		"wanted_stars": 3,
		"vehicle": "驾驶中",
		"cargo": "鸡蛋×3",
		"conflict": "警觉",
		"prompt": "E  进入商店",
	})
	assert(city.hud_visual.money == 190, "城市 HUD 没有消费现金状态")
	assert(city.hud_visual.wanted_stars == 3, "城市 HUD 没有消费通缉星级状态")
	assert(city.hud_visual.vehicle_text == "驾驶中", "城市 HUD 没有消费载具状态")
	assert(city.hud_visual.cargo_text == "鸡蛋×3", "城市 HUD 没有消费货物状态")
	assert(city.hud_visual.conflict_text == "警觉", "城市 HUD 没有消费冲突状态")
	var city_forward_point: Vector2 = city.call("_radar_point_for_world", city.player.global_position - city.player.global_transform.basis.z.normalized() * 12.0)
	var city_right_point: Vector2 = city.call("_radar_point_for_world", city.player.global_position + city.player.global_transform.basis.x.normalized() * 12.0)
	assert(city_forward_point.y < -0.2, "城市雷达没有把前方世界目标投影到上方")
	assert(city_right_point.x > 0.2, "城市雷达没有把右侧世界目标投影到右方")
	for viewport_size in TEST_SIZES:
		get_root().get_viewport().size = viewport_size
		await process_frame
		assert(absf(city.hud_visual.size.x - viewport_size.x) < 1.0 and absf(city.hud_visual.size.y - viewport_size.y) < 1.0, "城市 HUD 表现层没有铺满当前视口")
		var title_position: Vector2 = city.mission_title_label.global_position
		var title_center: float = title_position.x + city.mission_title_label.size.x * 0.5
		var money_position: Vector2 = city.money_label.global_position
		assert(absf(title_center - viewport_size.x * 0.5) < 2.0, "城市任务标题在视口缩放后没有保持居中")
		assert(money_position.x > viewport_size.x * 0.78, "城市金钱 HUD 在视口缩放后没有保持右侧")
	city.queue_free()
	await process_frame

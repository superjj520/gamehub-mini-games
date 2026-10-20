extends SceneTree

const ContentPackLoaderClass = preload("res://scripts/content_pack_loader.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest := ContentPackLoaderClass.load_manifest()
	assert(ContentPackLoaderClass.validate_manifest(manifest).is_empty(), "内容包注册表校验失败")
	assert(manifest.get("packs", []).size() == 3, "内容包注册表没有登记三个当前内容包")
	assert(int(manifest.get("packs", [])[0].get("content_version", 0)) == 1, "办公室注册表没有绑定内容版本")
	assert(int(manifest.get("packs", [])[1].get("content_version", 0)) == 1, "城市注册表没有绑定内容版本")
	assert(int(manifest.get("packs", [])[2].get("content_version", 0)) == 1, "扩展城市注册表没有绑定内容版本")
	var office := ContentPackLoaderClass.load_registered_pack("office", "office-leave-on-time-v1")
	assert(office.get("objective") == "准点下班", "办公室内容包没有通过注册表加载")
	assert(office.get("runtime", {}).get("office", {}).get("hallway_route", []).size() == 2, "办公室走廊路线没有进入内容包")
	assert(is_equal_approx(float(office.get("runtime", {}).get("office", {}).get("typing_camera", {}).get("distance", 0.0)), 1.75), "办公室坐姿打字镜头距离没有进入内容包")
	assert(office.get("runtime", {}).get("office", {}).get("typing_camera", {}).get("shoulder_offset", []) == [0.55, 0.02, 0.20], "办公室坐姿打字镜头肩偏移没有进入内容包")
	var city := ContentPackLoaderClass.load_registered_pack("city", "city-free-eggs-v1")
	assert(city.get("stages", []).size() == 6, "城市内容包没有通过注册表加载")
	assert(city.get("stages", [])[1].get("requirements", [])[0].get("item_id") == "egg_tray", "城市阶段前置条件没有进入内容包")
	assert(city.get("stages", [])[2].get("effects", {}).get("set_registered", false), "城市登记效果没有进入内容包")
	assert(city.get("runtime", {}).get("crowd", {}).get("routes", []).size() == 4, "城市人群路线没有进入内容包")
	assert(city.get("runtime", {}).get("traffic", {}).get("vehicles", []).size() == 3, "城市交通路线没有进入内容包")
	assert(is_equal_approx(float(city.get("runtime", {}).get("vehicle", {}).get("camera_distance", 0.0)), 5.2), "城市载具镜头距离没有进入内容包")
	assert(is_equal_approx(float(city.get("runtime", {}).get("vehicle", {}).get("camera_height", 0.0)), 2.3), "城市载具镜头高度没有进入内容包")
	assert(is_equal_approx(float(city.get("runtime", {}).get("vehicle", {}).get("camera_pitch_degrees", 0.0)), -12.0), "城市载具镜头俯角没有进入内容包")
	assert(city.get("runtime", {}).get("vehicle", {}).get("driver_seat_offset", []) == [0.0, 1.12, 0.18], "城市驾驶座位偏移没有进入内容包")
	assert(office.get("runtime", {}).get("vehicle", {}).get("driver_seat_offset", []) == [0.0, 1.12, 0.18], "办公室驾驶座位偏移没有进入内容包")
	var market_city := ContentPackLoaderClass.load_registered_pack("city", "city-market-delivery-v1")
	assert(market_city.get("stages", []).size() == 4, "扩展城市内容包没有通过注册表加载")
	assert(market_city.get("stages", [])[1].get("requirements", [])[0].get("item_id") == "night_order_ticket", "扩展城市订单前置条件没有进入内容包")
	assert(market_city.get("stages", [])[2].get("effects", {}).get("add_items", [])[0].get("item_id") == "night_reward_token", "扩展城市交付奖励没有进入内容包")
	assert(market_city.get("runtime", {}).get("visual_profiles", {}).get("default") == "dusk", "扩展城市视觉配置没有进入内容包")
	assert(not bool(manifest.get("packs", [])[2].get("release_allowed", true)), "扩展城市内容包未完成验收却被标记为可发布")
	assert(ContentPackLoaderClass.load_registered_pack("city", "missing-pack").is_empty(), "不存在的内容包没有安全返回空结果")

	var invalid_manifest: Dictionary = manifest.duplicate(true)
	invalid_manifest["packs"][0]["id"] = "wrong-id"
	assert(not ContentPackLoaderClass.validate_manifest(invalid_manifest).is_empty(), "注册表与内容包 id 不一致没有被拒绝")
	var invalid_content_version: Dictionary = manifest.duplicate(true)
	invalid_content_version["packs"][0]["content_version"] = 2
	assert(not ContentPackLoaderClass.validate_manifest(invalid_content_version).is_empty(), "注册表与内容包 version 不一致没有被拒绝")
	var invalid_runtime: Dictionary = office.duplicate(true)
	invalid_runtime["runtime"]["perception"]["field_of_view_degrees"] = 400.0
	assert(not ContentPackLoaderClass.validate_pack(invalid_runtime, "office").is_empty(), "越界感知视野没有被内容包校验拒绝")
	var invalid_stage_rules: Dictionary = city.duplicate(true)
	invalid_stage_rules["stages"][1]["requirements"][0]["amount"] = 0
	assert(not ContentPackLoaderClass.validate_pack(invalid_stage_rules, "city").is_empty(), "非法任务前置条件没有被内容包校验拒绝")
	var invalid_conflict_config: Dictionary = city.duplicate(true)
	invalid_conflict_config["runtime"]["conflict"]["damage_per_second"] = -1.0
	assert(not ContentPackLoaderClass.validate_pack(invalid_conflict_config, "city").is_empty(), "非法冲突伤害参数没有被内容包校验拒绝")
	var invalid_crowd_route: Dictionary = city.duplicate(true)
	invalid_crowd_route["runtime"]["crowd"]["routes"][0][0] = ["坏坐标"]
	assert(not ContentPackLoaderClass.validate_pack(invalid_crowd_route, "city").is_empty(), "非法人群路线没有被内容包校验拒绝")
	var invalid_office_route: Dictionary = office.duplicate(true)
	invalid_office_route["runtime"]["office"]["hallway_route"][0] = ["坏坐标"]
	assert(not ContentPackLoaderClass.validate_pack(invalid_office_route, "office").is_empty(), "非法办公室路线没有被内容包校验拒绝")
	var invalid_typing_camera: Dictionary = office.duplicate(true)
	invalid_typing_camera["runtime"]["office"]["typing_camera"]["pitch_degrees"] = -95.0
	assert(not ContentPackLoaderClass.validate_pack(invalid_typing_camera, "office").is_empty(), "越界坐姿打字镜头俯仰没有被内容包校验拒绝")
	var invalid_conflict_radius: Dictionary = city.duplicate(true)
	invalid_conflict_radius["runtime"]["conflict"]["damage_radius"] = 0.0
	assert(not ContentPackLoaderClass.validate_pack(invalid_conflict_radius, "city").is_empty(), "非法冲突伤害半径没有被内容包校验拒绝")
	print("内容包注册表集成测试通过")
	quit(0)

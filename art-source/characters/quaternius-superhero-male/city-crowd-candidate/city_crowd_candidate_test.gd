extends SceneTree

const CityScene = preload("res://scenes/city.tscn")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-city-crowd-override.json")
	city.set_meta("settings_path", OS.get_temp_dir().path_join("city-crowd-candidate-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(city)
	for _frame in range(4):
		await process_frame
	assert(city.initialized, "城市人群候选场景初始化失败")
	assert(city.pedestrians.size() == 4, "城市人群数量不符合当前城市内容包")
	for pedestrian in city.pedestrians:
		var visual: Node = pedestrian.get_node_or_null("Visual")
		assert(visual != null, "城市行人没有挂载候选 Visual")
		assert(visual.get_node_or_null("Character") != null, "城市行人候选缺少角色实例")
		assert(visual.get_node_or_null("AnimationPlayer") != null, "城市行人候选缺少 AnimationPlayer")
		assert(visual.find_child("候选人群视觉配件", true, false) != null, "城市行人候选缺少帽子、肩包和反光层")
		assert(pedestrian.get_node_or_null("原创灰盒人群外观") == null, "城市候选挂载后仍保留灰盒人群外观")
		AssetRuntimeCatalogClass.drive_animation_state(pedestrian, "walk_default")
	await process_frame
	for pedestrian in city.pedestrians:
		var animation_player := pedestrian.get_node("Visual/AnimationPlayer") as AnimationPlayer
		assert(animation_player.current_animation == "walk_default", "城市候选行走状态没有驱动")
	var before: Vector3 = city.pedestrians[0].global_position
	city.pedestrians[0].waypoints = [before, before + Vector3(2.0, 0.0, 0.0)]
	city.pedestrians[0].set_physics_process(true)
	await process_frame
	assert(city.pedestrians[0].global_position.distance_to(before) > 0.0, "城市候选行人不再沿路线移动")
	print("城市人群候选导入、变体、动画和路线契约通过")
	city.free()
	await process_frame
	quit(0)

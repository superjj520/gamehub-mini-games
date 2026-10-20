extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# 这是普通游戏模式回归，不是候选视觉采集。普通模式必须由同一套灰盒
	# 视觉与碰撞边界承担可玩性，候选环境只能留在树中供资产检查。
	OS.set_environment("REFERENCE_ASSET_PREVIEW", "")
	OS.set_environment("REFERENCE_GAMEPLAY_VIDEO_BACKDROP", "")

	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://content/asset-runtime-catalog.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("新时代觉醒者-architecture-office-%d.json" % Time.get_ticks_usec()))
	root.add_child(office)
	await process_frame
	assert(office.initialized, "普通办公室没有完成初始化")
	assert(not office.has_meta("candidate_video_backdrop"), "普通办公室错误启用了视频背景元数据")
	var office_visual := office.get_node_or_null("Visual") as Node3D
	assert(office_visual != null and not office_visual.visible, "普通办公室候选环境没有与普通游戏渲染隔离")
	var office_ground := office.find_child("灰盒地面", true, false)
	assert(office_ground is StaticBody3D, "普通办公室缺少碰撞地面")
	var office_ground_meshes := office_ground.find_children("*", "MeshInstance3D", true, false)
	assert(not office_ground_meshes.is_empty() and (office_ground_meshes[0] as MeshInstance3D).visible, "普通办公室可见地面没有与碰撞地面保持一致")
	var office_desks := office.find_children("办公桌*", "", true, false)
	assert(office_desks.size() == 5, "普通办公室工位数量不是 5 个，可能重复实例化了整间办公室")
	office.prepare_reference_capture(false)
	assert(office.reference_capture_mode, "办公室没有进入参考采集态")
	office.restore_reference_capture()
	assert(not office.reference_capture_mode, "办公室退出参考采集态后仍保持冻结")
	assert(office.trace.has_event("reference_capture_restored"), "办公室没有记录参考采集恢复事件")
	office.queue_free()
	await process_frame

	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://content/asset-runtime-catalog.json")
	city.set_meta("settings_path", OS.get_temp_dir().path_join("新时代觉醒者-architecture-city-%d.json" % Time.get_ticks_usec()))
	root.add_child(city)
	await process_frame
	assert(city.initialized, "普通城市没有完成初始化")
	assert(not city.has_meta("candidate_video_backdrop"), "普通城市错误启用了视频背景元数据")
	var city_visual := city.get_node_or_null("Visual") as Node3D
	assert(city_visual != null and not city_visual.visible, "普通城市候选环境没有与普通游戏渲染隔离")
	var city_ground := city.find_child("街区地面", true, false)
	assert(city_ground is StaticBody3D, "普通城市缺少碰撞地面")
	var city_ground_meshes := city_ground.find_children("*", "MeshInstance3D", true, false)
	assert(not city_ground_meshes.is_empty() and (city_ground_meshes[0] as MeshInstance3D).visible, "普通城市可见地面没有与碰撞地面保持一致")
	city.prepare_reference_capture(false)
	assert(city.reference_capture_mode, "城市没有进入参考采集态")
	city.restore_reference_capture()
	assert(not city.reference_capture_mode, "城市退出参考采集态后仍保持冻结")
	assert(city.trace.has_event("reference_capture_restored"), "城市没有记录参考采集恢复事件")
	city.queue_free()
	await process_frame

	print("普通游戏可玩性架构隔离回归测试通过")
	quit(0)

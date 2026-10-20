extends SceneTree

const CityScene = preload("res://scenes/city.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")
	city.set_meta("settings_path", OS.get_temp_dir().path_join("movie-candidate-vehicle-detail-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(city)
	await process_frame
	await process_frame
	assert(city.initialized, "载具近景取证城市初始化失败")

	city.vehicle.position = Vector3(-2.4, 0.7, 3.4)
	city.vehicle.rotation.y = PI
	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	var enter := InputFrameClass.new()
	enter.vehicle_enter_exit = true
	city.process_input_frame(enter, 0.016)
	assert(city.vehicle.driver == city.player, "载具近景取证未进入载具")

	# 近景只调整镜头构图，保持正式载具的跟随逻辑和材质挂载路径不变。
	city.camera_rig.set_follow_profile(3.05, 1.72)
	city.camera_rig.set_orbit(-24.0, -8.0)
	city.prepare_reference_capture(false)
	for _frame in range(90):
		await process_frame
	city.queue_free()
	await process_frame
	print("载具近景取证城市场景完成")
	quit(0)

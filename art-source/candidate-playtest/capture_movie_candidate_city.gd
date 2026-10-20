extends SceneTree

const CityScene = preload("res://scenes/city.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")
	city.set_meta("settings_path", OS.get_temp_dir().path_join("movie-candidate-city-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(city)
	await process_frame
	await process_frame
	assert(city.initialized, "电影取证城市初始化失败")
	city.vehicle.position = Vector3(-2.4, 0.7, 3.4)
	city.vehicle.rotation.y = PI
	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	var enter := InputFrameClass.new()
	enter.vehicle_enter_exit = true
	city.process_input_frame(enter, 0.016)
	assert(city.vehicle.driver == city.player, "电影取证城市未进入载具")
	var drive := InputFrameClass.new()
	drive.move = Vector2(0.0, -1.0)
	city.process_input_frame(drive, 0.25)
	city.camera_rig.set_orbit(-4.0, -7.0)
	city.prepare_reference_capture(false)
	for _frame in range(75):
		await process_frame
	city.queue_free()
	await process_frame
	print("电影取证城市场景完成")
	quit(0)

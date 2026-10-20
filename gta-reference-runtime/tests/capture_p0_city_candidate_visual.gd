extends SceneTree

const CityScene = preload("res://scenes/city.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		print("P0 城市候选视觉截图跳过：当前是无头渲染服务")
		quit(0)
		return
	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-override.json")
	city.set_meta("settings_path", OS.get_temp_dir().path_join("p0-candidate-city-preview-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(city)
	await process_frame
	await process_frame
	assert(city.initialized, "P0 候选城市场景初始化失败")
	city.vehicle.position = Vector3(5.0, 0.7, 3.0)
	city.vehicle.rotation.y = PI
	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	var enter := InputFrameClass.new()
	enter.vehicle_enter_exit = true
	city.process_input_frame(enter, 0.016)
	assert(city.vehicle.driver == city.player, "P0 城市候选截图未进入三轮车驾驶状态")
	var drive := InputFrameClass.new()
	drive.move = Vector2(0.0, -1.0)
	city.process_input_frame(drive, 0.25)
	city.camera_rig.set_orbit(-20.0, -18.0)
	city.prepare_reference_capture(false)
	await process_frame
	await process_frame
	var capture_path := RuntimeCaptureClass.capture(get_root(), "p0-candidate-city-08")
	assert(not capture_path.is_empty(), "P0 城市候选视觉截图生成失败")
	var source_path := ProjectSettings.globalize_path(capture_path)
	var output_path := ProjectSettings.globalize_path("res://../reference-evidence/p0-candidate-city-08.png")
	assert(DirAccess.copy_absolute(source_path, output_path) == OK, "P0 城市候选视觉截图复制失败")
	print("P0 城市候选视觉截图已生成：", output_path)
	city.free()
	await process_frame
	quit(0)

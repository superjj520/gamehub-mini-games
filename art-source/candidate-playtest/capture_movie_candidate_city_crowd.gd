extends SceneTree

## 城市四身份近景取证：只验证候选人群的可见差异，不改变正式城市逻辑。

const CityScene := preload("res://scenes/city.tscn")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")
	city.set_meta("settings_path", OS.get_temp_dir().path_join("movie-candidate-city-crowd-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(city)
	await process_frame
	await process_frame
	assert(city.initialized, "城市人群近景取证初始化失败")

	city.prepare_reference_capture(false)
	var crowd_positions := [
		Vector3(-2.25, 0.9, 3.9),
		Vector3(-0.75, 0.9, 3.55),
		Vector3(0.75, 0.9, 3.55),
		Vector3(2.25, 0.9, 3.9),
	]
	for index in range(mini(city.pedestrians.size(), crowd_positions.size())):
		var pedestrian = city.pedestrians[index]
		pedestrian.position = crowd_positions[index]
		pedestrian.rotation.y = 0.0
		pedestrian.visible = true
		AssetRuntimeCatalogClass.drive_animation_state(pedestrian, "idle_default")
	for traffic in city.traffic_vehicles:
		traffic.visible = false
	city.player.visible = false
	city.vehicle.visible = false
	if is_instance_valid(city.conflict_agent):
		city.conflict_agent.visible = false
	var preview_camera := Camera3D.new()
	preview_camera.name = "城市四身份近景审阅镜头"
	preview_camera.fov = 48.0
	city.add_child(preview_camera)
	preview_camera.global_position = Vector3(0.0, 2.1, 9.4)
	preview_camera.look_at(Vector3(0.0, 1.25, 3.75), Vector3.UP)
	preview_camera.make_current()
	await process_frame
	await process_frame
	print("城市四身份近景取证场景完成")
	quit(0)

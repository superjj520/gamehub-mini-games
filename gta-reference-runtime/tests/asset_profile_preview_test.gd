extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("REFERENCE_ASSET_CATALOG_PATH", "res://tests/asset-runtime-catalog-override.json")
	var office := OfficeScene.instantiate()
	office.set_meta("settings_path", OS.get_temp_dir().path_join("candidate-profile-office-%d.json" % Time.get_ticks_usec()))
	root.add_child(office)
	await process_frame
	assert(office.initialized, "候选资产环境变量没有初始化办公室场景")
	assert(office.get_node_or_null("Visual/候选工位细节") != null, "候选资产环境变量没有挂载办公室环境")
	assert(office.player.get_node_or_null("Visual/候选主角身体") != null, "候选资产环境变量没有挂载主角")
	office.free()
	await process_frame

	var city := CityScene.instantiate()
	city.set_meta("settings_path", OS.get_temp_dir().path_join("candidate-profile-city-%d.json" % Time.get_ticks_usec()))
	root.add_child(city)
	await process_frame
	assert(city.initialized, "候选资产环境变量没有初始化城市场景")
	assert(city.get_node_or_null("Visual/候选CC0小型城市楼") != null, "候选资产环境变量没有挂载城市环境")
	assert(city.vehicle.get_node_or_null("Visual") != null and city.vehicle.get_node("Visual").find_child("候选三轮车车体", true, false) != null, "候选资产环境变量没有挂载三轮车")
	city.free()
	await process_frame
	print("候选资产环境变量预览链路通过")
	quit(0)

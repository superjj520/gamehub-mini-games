extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://tests/missing-runtime-catalog.json")
	get_root().add_child(office)
	await process_frame
	assert(not office.initialized, "损坏的办公室资产目录不应继续初始化")
	var office_overlay = office.get_node_or_null("运行时启动错误")
	assert(office_overlay != null, "办公室启动失败没有显示可理解的错误界面")
	assert(office_overlay.get_node_or_null("启动错误遮罩/启动错误面板/内容/返回入口") != null, "办公室启动错误界面缺少返回入口")
	office.free()

	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://tests/missing-runtime-catalog.json")
	get_root().add_child(city)
	await process_frame
	assert(not city.initialized, "损坏的城市资产目录不应继续初始化")
	var city_overlay = city.get_node_or_null("运行时启动错误")
	assert(city_overlay != null, "城市启动失败没有显示可理解的错误界面")
	assert(city_overlay.get_node_or_null("启动错误遮罩/启动错误面板/内容/返回入口") != null, "城市启动错误界面缺少返回入口")
	city.free()
	await process_frame
	print("运行时启动错误界面回归测试通过")
	quit(0)

extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		print("运行时视口截图链路跳过：当前是无头渲染服务")
		quit(0)
		return
	var office = OfficeScene.instantiate()
	get_root().add_child(office)
	await process_frame
	await process_frame
	office.prepare_reference_capture()
	await process_frame
	await process_frame
	var office_path := RuntimeCaptureClass.capture(get_root(), "office-test")
	assert(not office_path.is_empty(), "办公室运行时截图没有返回路径")
	assert(FileAccess.file_exists(office_path), "办公室运行时截图文件不存在")
	var office_repeat_path := RuntimeCaptureClass.capture(get_root(), "office-test-repeat")
	assert(FileAccess.get_file_as_bytes(office_path) == FileAccess.get_file_as_bytes(office_repeat_path), "办公室固定截图重复采集结果不一致")
	office.queue_free()
	await process_frame

	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	await process_frame
	city.prepare_reference_capture()
	await process_frame
	await process_frame
	var city_path := RuntimeCaptureClass.capture(get_root(), "city-test")
	assert(not city_path.is_empty(), "城市运行时截图没有返回路径")
	assert(FileAccess.file_exists(city_path), "城市运行时截图文件不存在")
	var city_repeat_path := RuntimeCaptureClass.capture(get_root(), "city-test-repeat")
	assert(FileAccess.get_file_as_bytes(city_path) == FileAccess.get_file_as_bytes(city_repeat_path), "城市固定截图重复采集结果不一致")
	city.queue_free()
	await process_frame
	print("运行时视口截图链路测试通过：办公室和城市 PNG 均已生成")
	quit(0)

extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

const SAMPLE_FRAMES := 300
const FRAME_DELTA := 1.0 / 60.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	get_root().add_child(office)
	await process_frame
	var office_start := Time.get_ticks_usec()
	for _index in range(SAMPLE_FRAMES):
		office.process_input_frame(InputFrameClass.new(), FRAME_DELTA)
	var office_elapsed_ms := float(Time.get_ticks_usec() - office_start) / 1000.0
	assert(office_elapsed_ms >= 0.0, "办公室性能计时无效")
	print("主机性能基线：办公室 %d 帧逻辑耗时 %.2f 毫秒" % [SAMPLE_FRAMES, office_elapsed_ms])
	office.queue_free()
	await process_frame

	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	var city_start := Time.get_ticks_usec()
	for _index in range(SAMPLE_FRAMES):
		city.process_input_frame(InputFrameClass.new(), FRAME_DELTA)
	var city_elapsed_ms := float(Time.get_ticks_usec() - city_start) / 1000.0
	assert(city_elapsed_ms >= 0.0, "城市性能计时无效")
	print("主机性能基线：城市 %d 帧逻辑耗时 %.2f 毫秒" % [SAMPLE_FRAMES, city_elapsed_ms])
	city.queue_free()
	await process_frame
	print("运行时性能烟雾测试通过；结果仅代表当前主机，不代表目标设备")
	quit(0)

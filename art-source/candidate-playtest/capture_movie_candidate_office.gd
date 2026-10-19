extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# Movie Maker 在无头后端会先访问空纹理并触发 Godot 崩溃；这里提前结束，
	# 让无鼠标验收流程留下可解释的失败，而不是产生不可追踪的崩溃。
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		push_error("候选办公室电影采集需要真实图形视口；无头模式仅允许行为测试")
		quit(2)
		return
	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("movie-candidate-office-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(office)
	await process_frame
	await process_frame
	assert(office.initialized, "电影取证办公室初始化失败")
	office.player.position = Vector3(0.0, 1.0, 1.7)
	office.camera_rig.set_follow_profile(3.65, 1.82)
	office.camera_rig.set_orbit(72.0, -10.0)
	office.prepare_reference_capture(false)
	for _frame in range(75):
		await process_frame
	office.queue_free()
	await process_frame
	print("电影取证办公室场景完成")
	quit(0)

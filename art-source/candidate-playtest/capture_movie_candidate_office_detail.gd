extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("movie-candidate-office-detail-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(office)
	await process_frame
	await process_frame
	assert(office.initialized, "办公室近景取证初始化失败")

	# 把角色放到真实工位之间，形成接近参考视频的肩后构图。
	office.player.position = Vector3(-1.8, 1.0, 4.0)
	office.camera_rig.set_follow_profile(2.55, 1.7)
	office.camera_rig.set_orbit(58.0, -7.0)
	office.prepare_reference_capture(false)
	for _frame in range(90):
		await process_frame
	office.queue_free()
	await process_frame
	print("办公室近景取证场景完成")
	quit(0)

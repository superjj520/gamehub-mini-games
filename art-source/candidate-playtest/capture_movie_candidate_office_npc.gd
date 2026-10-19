extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("movie-candidate-office-npc-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(office)
	await process_frame
	await process_frame
	assert(office.initialized, "办公室 NPC 近景取证初始化失败")

	# 只改变取证站位，把上司和主角放进同一个可读的第三人称空间，不改变正式任务配置。
	office.npc.position = Vector3(1.7, 0.9, -1.8)
	office.player.position = Vector3(-0.2, 1.0, 1.15)
	var requested_state := "idle_default"
	for argument in OS.get_cmdline_args():
		var text_argument := str(argument)
		if text_argument.begins_with("--npc-state="):
			requested_state = text_argument.trim_prefix("--npc-state=")
	var npc_visual: Node = office.npc.get_node_or_null("Visual")
	if npc_visual != null and npc_visual.has_method("drive_candidate_state"):
		npc_visual.drive_candidate_state(requested_state)
	var preview_camera := Camera3D.new()
	preview_camera.name = "候选 NPC 近景审阅镜头"
	preview_camera.fov = 52.0
	office.add_child(preview_camera)
	preview_camera.global_position = Vector3(5.1, 2.45, -4.6)
	preview_camera.look_at(Vector3(1.55, 1.08, -1.65), Vector3.UP)
	preview_camera.make_current()
	office.prepare_reference_capture(false)
	for _frame in range(90):
		await process_frame
	office.queue_free()
	await process_frame
	print("办公室 NPC 近景取证场景完成")
	quit(0)

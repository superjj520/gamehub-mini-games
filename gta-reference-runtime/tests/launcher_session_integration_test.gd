extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var journal = root.get_node_or_null("SessionJournal")
	assert(journal != null, "主入口缺少会话标记自动加载单例")
	var marker_path := OS.get_temp_dir().path_join("reference-launcher-session-%d.json" % Time.get_ticks_usec())
	journal.marker_path = marker_path
	journal.session_started = false
	journal.recovered_previous_session = false
	var previous_marker := FileAccess.open(marker_path, FileAccess.WRITE)
	previous_marker.store_string(JSON.stringify({"version": 1, "clean_exit": false}))
	previous_marker = null
	var result := change_scene_to_file("res://scenes/launcher.tscn")
	assert(result == OK, "启动器主场景加载失败")
	for index in range(3):
		await process_frame
	assert(journal.session_started, "启动器主场景加载后没有建立会话标记")
	assert(journal.recovered_previous_session, "启动器主场景没有识别上次异常会话")
	assert(FileAccess.file_exists(marker_path), "启动器主场景没有写入会话标记")
	var launcher = current_scene
	assert(str(launcher.status_label.text).contains("未正常结束"), "启动器没有显示异常退出恢复提示")
	assert(journal.finish_session(), "启动器测试结束时没有清理会话标记")
	assert(not FileAccess.file_exists(marker_path), "启动器测试结束后会话标记仍存在")
	print("启动器会话标记集成测试通过")
	quit(0)

extends SceneTree

const SessionJournalClass = preload("res://scripts/session_journal.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var marker_path := OS.get_temp_dir().path_join("reference-session-journal-%d.json" % Time.get_ticks_usec())
	var first = SessionJournalClass.new()
	first.marker_path = marker_path
	assert(not first.recovered_previous_session, "首次启动错误识别为异常退出")
	assert(first.start_session(), "会话标记写入失败")
	assert(not first.recovered_previous_session, "首次启动错误报告上次异常退出")
	assert(FileAccess.file_exists(marker_path), "会话标记文件不存在")

	var second = SessionJournalClass.new()
	second.marker_path = marker_path
	assert(second.start_session(), "第二次启动会话标记写入失败")
	assert(second.recovered_previous_session, "上次未清理的会话没有被识别")
	assert(second.finish_session(), "正常结束没有清理会话标记")
	assert(not FileAccess.file_exists(marker_path), "正常结束后会话标记仍存在")
	first.free()
	second.free()
	print("会话异常退出识别测试通过")
	quit(0)

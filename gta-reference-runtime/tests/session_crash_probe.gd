extends SceneTree

const SessionJournalClass = preload("res://scripts/session_journal.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mode := OS.get_environment("GTA_SESSION_PROBE_MODE")
	var marker_path := OS.get_environment("GTA_SESSION_MARKER_PATH")
	assert(not mode.is_empty() and not marker_path.is_empty(), "会话探针缺少模式或标记路径")
	var journal = root.get_node_or_null("SessionJournal")
	if journal == null:
		journal = SessionJournalClass.new()
		journal.name = "SessionJournal"
		root.add_child(journal)
	journal.marker_path = marker_path
	if mode == "hold":
		change_scene_to_file("res://scenes/launcher.tscn")
		for index in range(4):
			await process_frame
		assert(journal.session_started, "异常退出探针没有建立会话标记")
		print("会话崩溃探针已准备")
		while true:
			await process_frame
	else:
		assert(journal.start_session(), "恢复探针无法打开会话标记")
		assert(journal.recovered_previous_session, "恢复探针没有识别遗留会话标记")
		print("会话恢复探针通过 recovered=true")
		assert(journal.finish_session(), "恢复探针没有清理会话标记")
		quit(0)

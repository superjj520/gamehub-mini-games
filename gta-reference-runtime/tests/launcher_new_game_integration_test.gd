extends SceneTree

const LauncherScene = preload("res://scenes/launcher.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var launch_context = root.get_node_or_null("LaunchContext")
	assert(launch_context != null, "新游戏测试缺少启动上下文自动加载单例")
	launch_context.clear()
	var checkpoint_path := OS.get_temp_dir().path_join("新时代觉醒者-launcher-new-game-%d.json" % Time.get_ticks_usec())
	var checkpoint := FileAccess.open(checkpoint_path, FileAccess.WRITE)
	assert(checkpoint != null, "新游戏测试无法创建主存档")
	checkpoint.store_string("旧主存档")
	checkpoint.flush()
	checkpoint.close()
	var backup := FileAccess.open(checkpoint_path + ".bak", FileAccess.WRITE)
	assert(backup != null, "新游戏测试无法创建备份存档")
	backup.store_string("旧备份存档")
	backup.flush()
	backup.close()
	var temporary := FileAccess.open(checkpoint_path + ".tmp", FileAccess.WRITE)
	assert(temporary != null, "新游戏测试无法创建临时存档")
	temporary.store_string("旧临时存档")
	temporary.flush()
	temporary.close()

	var launcher = LauncherScene.instantiate()
	launcher.set_meta("office_checkpoint_path", checkpoint_path)
	root.add_child(launcher)
	await process_frame
	var buttons: Array[Node] = launcher.find_children("*", "Button", true, false)
	var new_game_button: Button = null
	for button in buttons:
		if str(button.text) == "新游戏（清除本地存档）":
			new_game_button = button
			break
	assert(new_game_button != null, "存在检查点时启动器没有显示新游戏入口")
	assert(launcher._clear_checkpoint_files(checkpoint_path), "新游戏测试无法清除主存档、备份和临时文件")
	assert(not FileAccess.file_exists(checkpoint_path), "新游戏没有清除主存档")
	assert(not FileAccess.file_exists(checkpoint_path + ".bak"), "新游戏没有清除备份存档")
	assert(not FileAccess.file_exists(checkpoint_path + ".tmp"), "新游戏没有清除临时存档")
	launcher.queue_free()
	await process_frame
	assert(change_scene_to_file("res://scenes/launcher.tscn") == OK, "新游戏测试返回启动器失败")
	await process_frame
	print("启动器新游戏与存档清理集成测试通过")
	quit(0)

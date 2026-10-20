extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for scene_resource in [OfficeScene, CityScene]:
		assert(change_scene_to_file(scene_resource.resource_path) == OK, "暂停测试场景加载失败")
		await process_frame
		await process_frame
		var scene = current_scene
		_assert_mouse_mode(Input.MOUSE_MODE_CAPTURED, "进入游戏场景后鼠标没有被捕获")
		# 每个测试进程共享 Godot user:// 目录；先关闭音频，避免上一轮测试的
		# 设置让本轮在未验证音频生命周期时产生跨测试副作用。
		scene.audio_events.enabled = false
		scene.settings_store.save_audio_settings(false, scene.audio_events.master_volume_db)
		assert(scene.pause_overlay != null, "场景没有创建暂停菜单")
		var pause_event := InputEventAction.new()
		pause_event.action = "pause"
		pause_event.pressed = true
		scene.pause_overlay._unhandled_input(pause_event)
		assert(scene.pause_overlay.visible, "统一暂停动作没有显示暂停菜单")
		assert(paused, "统一暂停动作没有暂停场景树")
		scene.pause_overlay._unhandled_input(pause_event)
		assert(not scene.pause_overlay.visible, "统一暂停动作没有恢复游戏")
		assert(not paused, "统一暂停动作恢复后场景树仍处于暂停")
		scene.pause_overlay.show_pause()
		assert(scene.pause_overlay.visible, "暂停菜单没有显示")
		assert(paused, "显示暂停菜单后场景树没有暂停")
		_assert_mouse_mode(Input.MOUSE_MODE_VISIBLE, "显示暂停菜单后鼠标没有释放")
		scene.pause_overlay.set_audio_enabled(true)
		assert(scene.pause_overlay.audio_enabled, "音频开关没有打开")
		assert(scene.audio_events.enabled, "暂停菜单音频开关没有同步到场景路由")
		scene.pause_overlay.set_audio_volume_db(-8.0)
		assert(is_equal_approx(scene.audio_events.master_volume_db, -8.0), "音频音量没有同步到场景路由")
		assert(FileAccess.file_exists(scene.settings_store.settings_path), "音频设置没有持久化")
		scene.pause_overlay.hide_pause()
		assert(not paused, "恢复游戏后场景树仍处于暂停")
		assert(not scene.pause_overlay.visible, "恢复游戏后暂停菜单仍可见")
		_assert_mouse_mode(Input.MOUSE_MODE_CAPTURED, "恢复游戏后鼠标没有重新捕获")
		assert(change_scene_to_file(scene_resource.resource_path) == OK, "暂停测试重新进入场景失败")
		await process_frame
		await process_frame
		var reloaded_scene = current_scene
		assert(reloaded_scene.audio_events.enabled, "重新进入场景后音频开关没有恢复")
		assert(is_equal_approx(reloaded_scene.audio_events.master_volume_db, -8.0), "重新进入场景后音量没有恢复")
		assert(reloaded_scene.pause_overlay.license_button != null, "暂停菜单缺少第三方许可入口")
		reloaded_scene.pause_overlay._toggle_license_text()
		assert(reloaded_scene.pause_overlay.license_text.visible, "第三方许可入口没有展开许可正文")
		assert(str(reloaded_scene.pause_overlay.license_text.text).contains("Godot Engine"), "第三方许可正文没有包含 Godot 声明")
		reloaded_scene.pause_overlay._toggle_license_text()
		assert(not reloaded_scene.pause_overlay.license_text.visible, "第三方许可入口无法收起许可正文")
		assert(reloaded_scene.pause_overlay.controls_button != null, "暂停菜单缺少操作说明入口")
		reloaded_scene.pause_overlay._toggle_controls_text()
		assert(reloaded_scene.pause_overlay.controls_text.visible, "操作说明入口没有展开控制说明")
		assert(str(reloaded_scene.pause_overlay.controls_text.text).contains("WASD"), "操作说明没有包含键盘移动方式")
		assert(str(reloaded_scene.pause_overlay.controls_text.text).contains("左摇杆"), "操作说明没有包含手柄移动方式")
		reloaded_scene.pause_overlay._toggle_controls_text()
		assert(not reloaded_scene.pause_overlay.controls_text.visible, "操作说明入口无法收起控制说明")
		reloaded_scene.pause_overlay.show_pause()
		reloaded_scene.pause_overlay._request_restart()
		await process_frame
		await process_frame
		assert(current_scene != null and current_scene.scene_file_path == scene_resource.resource_path, "暂停菜单重新开始没有重新加载当前场景")
		assert(not paused, "暂停菜单重新开始后场景树仍处于暂停")
		assert(current_scene.pause_overlay != null and not current_scene.pause_overlay.visible, "重新加载当前场景后暂停菜单状态没有清理")
		current_scene.audio_events.enabled = false
		current_scene.settings_store.save_audio_settings(false, current_scene.audio_events.master_volume_db)
		current_scene.pause_overlay.show_pause()
		current_scene.pause_overlay._request_menu()
		await process_frame
		assert(current_scene != null and current_scene.scene_file_path == "res://scenes/launcher.tscn", "暂停菜单返回场景入口没有进入启动器")
	print("暂停菜单端到端测试通过")
	quit(0)

func _assert_mouse_mode(expected: int, message: String) -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	assert(Input.get_mouse_mode() == expected, message)

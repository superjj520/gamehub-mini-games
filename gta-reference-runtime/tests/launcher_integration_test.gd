extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	launcher.set_meta("office_checkpoint_path", OS.get_temp_dir().path_join("新时代觉醒者-launcher-empty-office-%d.json" % Time.get_ticks_usec()))
	launcher.set_meta("city_checkpoint_path", OS.get_temp_dir().path_join("新时代觉醒者-launcher-empty-city-%d.json" % Time.get_ticks_usec()))
	root.add_child(launcher)
	await process_frame
	var profile_entries = launcher.launch_profile.get("entries", [])
	assert(profile_entries is Array and not profile_entries.is_empty(), "启动器没有读取有效启动入口")
	var buttons: Array[Node] = []
	for button in launcher.find_children("*", "Button", true, false):
		if not launcher.settings_overlay.is_ancestor_of(button):
			buttons.append(button)
	assert(buttons.size() == profile_entries.size() + 2, "启动器内容入口、设置或退出入口数量不正确")
	for index in range(profile_entries.size()):
		var entry: Dictionary = profile_entries[index]
		var button: Button = buttons[index]
		assert(not str(entry.get("content_pack_id", "")).is_empty(), "启动器入口没有绑定内容包标识")
		assert(str(button.text) == str(entry.get("title", "")), "启动器入口文案与启动配置不一致")
		assert(button.focus_mode == Control.FOCUS_ALL, "启动器入口没有启用键盘/手柄焦点")
		assert(launcher._keycode_for_shortcut(str(entry.get("shortcut", ""))) >= 0, "启动器入口快捷键无效")
		if index > 0:
			var previous_button: Button = buttons[index - 1]
			assert(previous_button.focus_neighbor_bottom == previous_button.get_path_to(button), "启动器入口焦点向下导航断裂")
			assert(button.focus_neighbor_top == button.get_path_to(previous_button), "启动器入口焦点向上导航断裂")
	assert(root.gui_get_focus_owner() == buttons[0], "启动器没有把焦点放到首个内容入口")
	var settings_button: Button = buttons[profile_entries.size()]
	assert(settings_button.text == "游戏设置", "启动器缺少首屏游戏设置入口")
	assert(settings_button.focus_mode == Control.FOCUS_ALL, "游戏设置入口没有启用键盘/手柄焦点")
	var quit_button: Button = buttons[profile_entries.size() + 1]
	assert(quit_button.text == "退出游戏", "启动器缺少明确的退出入口")
	assert(quit_button.focus_mode == Control.FOCUS_ALL, "退出入口没有启用键盘/手柄焦点")
	assert(quit_button.tooltip_text.contains("Esc"), "退出入口没有提示键盘退出方式")

	for index in range(profile_entries.size()):
		var entry: Dictionary = profile_entries[index]
		var key := InputEventKey.new()
		key.keycode = launcher._keycode_for_shortcut(str(entry.get("shortcut", "")))
		key.pressed = true
		var active_launcher = current_scene if current_scene != null and current_scene.scene_file_path == "res://scenes/launcher.tscn" else launcher
		active_launcher._unhandled_input(key)
		await process_frame
		assert(current_scene != null and current_scene.scene_file_path == str(entry.get("scene_path", "")), "快捷键没有进入启动配置指定场景")
		assert(current_scene.initialized, "启动配置指定场景没有完成初始化")
		if str(entry.get("id", "")) == "office":
			assert(current_scene.office_pack_id == str(entry.get("content_pack_id", "")), "办公室快捷键没有加载启动配置指定内容包")
		elif str(entry.get("id", "")) == "city":
			assert(current_scene.city_pack_id == str(entry.get("content_pack_id", "")), "城市快捷键没有加载启动配置指定内容包")
		if index < profile_entries.size() - 1:
			var reload_result := change_scene_to_file("res://scenes/launcher.tscn")
			assert(reload_result == OK, "场景返回启动器失败")
			await process_frame
	current_scene.queue_free()
	print("启动器场景集成测试通过")
	quit()

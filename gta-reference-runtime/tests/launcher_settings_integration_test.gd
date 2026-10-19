extends SceneTree

const LauncherScene = preload("res://scenes/launcher.tscn")
const DisplaySettingsStoreClass = preload("res://scripts/display_settings_store.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var settings_path := OS.get_temp_dir().path_join("新时代觉醒者-launcher-settings-%d.json" % Time.get_ticks_usec())
	var display_settings_path := OS.get_temp_dir().path_join("新时代觉醒者-launcher-display-settings-%d.json" % Time.get_ticks_usec())
	var seeded_display_store = DisplaySettingsStoreClass.new(display_settings_path)
	assert(seeded_display_store.save_settings("fullscreen", 1920, 1080), "启动器显示设置回归无法预置显示配置")
	var launcher = LauncherScene.instantiate()
	launcher.set_meta("settings_path", settings_path)
	launcher.set_meta("display_settings_path", display_settings_path)
	root.add_child(launcher)
	await process_frame
	assert(launcher.display_settings_applied_on_boot, "启动器启动时没有应用已保存的显示设置")
	var settings_button: Button = null
	for button in launcher.find_children("*", "Button", true, false):
		if str(button.text) == "游戏设置":
			settings_button = button
			break
	assert(settings_button != null, "启动器缺少首屏游戏设置入口")
	settings_button.emit_signal("pressed")
	await process_frame
	assert(launcher.settings_overlay.visible, "启动器设置面板没有打开")
	assert(launcher.settings_audio_button != null, "启动器设置缺少音频开关")
	assert(launcher.settings_audio_slider != null, "启动器设置缺少音量滑杆")
	assert(launcher.display_mode_option != null and launcher.display_resolution_option != null, "启动器设置缺少窗口模式或分辨率选项")
	assert(launcher.display_mode_option.get_selected_metadata() == "fullscreen", "启动器启动时没有恢复已保存的全屏模式")
	assert(launcher.display_resolution_option.get_selected_metadata() == "1920x1080", "启动器启动时没有恢复已保存的分辨率")
	launcher._toggle_launcher_audio()
	launcher.settings_audio_slider.value = -8.0
	await process_frame
	var persisted = launcher.settings_store.load_audio_settings()
	assert(bool(persisted.get("enabled", false)), "启动器设置没有持久化音频开关")
	assert(is_equal_approx(float(persisted.get("master_volume_db", 0.0)), -8.0), "启动器设置没有持久化主音量")
	launcher.display_mode_option.select(1)
	for index in range(launcher.display_resolution_option.item_count):
		if str(launcher.display_resolution_option.get_item_metadata(index)) == "1920x1080":
			launcher.display_resolution_option.select(index)
			break
	launcher._save_launcher_display_settings()
	var persisted_display = launcher.display_settings_store.load_settings()
	assert(str(persisted_display.get("mode", "")) == "fullscreen", "启动器设置没有持久化全屏模式")
	assert(int(persisted_display.get("width", 0)) == 1920 and int(persisted_display.get("height", 0)) == 1080, "启动器设置没有持久化目标分辨率")
	launcher._toggle_launcher_license()
	assert(launcher.settings_license_text.visible, "启动器设置没有展开第三方许可")
	assert(str(launcher.settings_license_text.text).contains("Godot Engine"), "启动器设置许可正文缺少 Godot 声明")
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	launcher._unhandled_input(cancel_event)
	assert(not launcher.settings_overlay.visible, "启动器设置返回后仍然可见")
	launcher.queue_free()
	await process_frame
	DirAccess.remove_absolute(settings_path)
	DirAccess.remove_absolute(settings_path + ".bak")
	DirAccess.remove_absolute(display_settings_path)
	DirAccess.remove_absolute(display_settings_path + ".bak")
	print("启动器首屏设置与持久化集成测试通过")
	quit(0)

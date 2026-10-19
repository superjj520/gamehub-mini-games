extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_configure_isolated_state()
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	await process_frame
	_assert(launcher.first_menu_button != null, "真实输入链启动器没有首个入口")

	_push_key(KEY_1, true)
	await process_frame
	await process_frame
	var office = current_scene
	_assert(office != null and office.scene_file_path == "res://scenes/benchmark.tscn", "真实输入链的数字键没有进入办公室")
	_assert(office.initialized, "真实输入链进入办公室后场景未初始化")

	var start_position: Vector3 = office.player.global_position
	_push_key(KEY_W, true)
	for index in range(10):
		await physics_frame
	_push_key(KEY_W, false)
	await physics_frame
	_assert(office.player.global_position.distance_to(start_position) > 0.1, "真实输入链的 W 键没有驱动玩家移动")
	_assert(office.trace.has_event("input"), "真实输入链的 W 键没有进入运行轨迹")

	_push_key(KEY_ESCAPE, true)
	_push_key(KEY_ESCAPE, false)
	await process_frame
	_assert(office.pause_overlay.visible, "真实输入链的 Esc 键没有打开暂停菜单")
	_assert(paused, "真实输入链打开暂停菜单后场景树没有暂停")

	office.pause_overlay.hide_pause()
	_assert(not paused, "真实输入链关闭暂停菜单后场景树仍处于暂停")
	print("真实输入循环通过：数字键进入场景、W 键移动、Esc 暂停与恢复")
	quit(0)

func _push_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	root.push_input(event)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)

func _configure_isolated_state() -> void:
	var state_root := OS.get_temp_dir().path_join("新时代觉醒者-real-input-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(state_root)
	OS.set_environment("REFERENCE_SETTINGS_PATH", state_root.path_join("reference_settings.json"))
	OS.set_environment("REFERENCE_DISPLAY_SETTINGS_PATH", state_root.path_join("reference_display_settings.json"))
	OS.set_environment("REFERENCE_CAMPAIGN_STATE_PATH", state_root.path_join("reference_campaign.json"))
	OS.set_environment("REFERENCE_SESSION_MARKER_PATH", state_root.path_join("reference_session.json"))
	OS.set_environment("REFERENCE_OFFICE_CHECKPOINT_PATH", state_root.path_join("reference_checkpoint.json"))
	OS.set_environment("REFERENCE_CITY_CHECKPOINT_PATH", state_root.path_join("city_checkpoint.json"))
	OS.set_environment("REFERENCE_BOOT_STATUS_PATH", state_root.path_join("boot_status.json"))


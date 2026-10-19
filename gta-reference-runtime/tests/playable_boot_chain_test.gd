extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	quit(1)
	return false

func _run() -> void:
	_configure_isolated_state()
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	root.add_child(launcher)
	await process_frame
	await process_frame

	if not _check(launcher.status_label != null, "可玩启动链没有创建启动器状态文本"): return
	if not _check(not str(launcher.status_label.text).is_empty(), "可玩启动链启动器没有进入可见状态"): return
	if not _check(launcher.first_menu_button != null, "可玩启动链没有首个可操作入口"): return
	if not _check(launcher.first_menu_button.focus_mode == Control.FOCUS_ALL, "可玩启动链首个入口不能获得键盘焦点"): return

	var enter_office := InputEventKey.new()
	enter_office.keycode = KEY_1
	enter_office.pressed = true
	launcher._unhandled_input(enter_office)
	await process_frame
	await process_frame

	var office = current_scene
	if not _check(office != null and office.scene_file_path == "res://scenes/benchmark.tscn", "可玩启动链没有从首屏进入办公室场景"): return
	if not _check(office.initialized, "可玩启动链进入办公室后场景没有完成初始化"): return
	if not _check(office.player != null and office.camera_rig != null, "可玩启动链办公室缺少玩家或第三人称镜头"): return
	if not _check(office.pause_overlay != null, "可玩启动链办公室缺少暂停恢复入口"): return

	var start_position: Vector3 = office.player.global_position
	var movement := InputFrameClass.new()
	movement.move = Vector2(0.0, -1.0)
	for index in range(8):
		office.process_input_frame(movement, 0.1)
	if not _check(office.player.global_position.distance_to(start_position) > 0.1, "可玩启动链移动输入没有产生玩家位移：起点=%s，终点=%s，速度=%s，阻挡=%s" % [start_position, office.player.global_position, office.player.velocity, office.player.last_motion_blocked]): return
	if not _check(office.trace.has_event("input"), "可玩启动链移动输入没有进入运行时轨迹"): return

	if not _check(change_scene_to_file("res://scenes/launcher.tscn") == OK, "可玩启动链无法返回启动器"): return
	await process_frame
	await process_frame
	if not _check(current_scene != null and current_scene.scene_file_path == "res://scenes/launcher.tscn", "可玩启动链返回后当前场景不是启动器"): return
	if not _check(current_scene.first_menu_button != null, "可玩启动链返回启动器后没有恢复可操作入口"): return

	print("可玩启动链通过：启动器、首屏入口、办公室场景、玩家移动、运行轨迹和返回入口")
	quit(0)

func _configure_isolated_state() -> void:
	var state_root := OS.get_temp_dir().path_join("新时代觉醒者-playable-boot-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(state_root)
	OS.set_environment("REFERENCE_SETTINGS_PATH", state_root.path_join("reference_settings.json"))
	OS.set_environment("REFERENCE_DISPLAY_SETTINGS_PATH", state_root.path_join("reference_display_settings.json"))
	OS.set_environment("REFERENCE_CAMPAIGN_STATE_PATH", state_root.path_join("reference_campaign.json"))
	OS.set_environment("REFERENCE_SESSION_MARKER_PATH", state_root.path_join("reference_session.json"))
	OS.set_environment("REFERENCE_OFFICE_CHECKPOINT_PATH", state_root.path_join("reference_checkpoint.json"))
	OS.set_environment("REFERENCE_CITY_CHECKPOINT_PATH", state_root.path_join("city_checkpoint.json"))
	var campaign_state = root.get_node_or_null("CampaignState")
	if campaign_state != null and campaign_state.has_method("configure_path"):
		campaign_state.configure_path(OS.get_environment("REFERENCE_CAMPAIGN_STATE_PATH"))
	var journal = root.get_node_or_null("SessionJournal")
	if journal != null:
		journal.marker_path = OS.get_environment("REFERENCE_SESSION_MARKER_PATH")
		journal.session_started = false

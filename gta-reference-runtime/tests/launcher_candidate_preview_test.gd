extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("REFERENCE_ASSET_PREVIEW", "1")
	var campaign_state = root.get_node_or_null("CampaignState")
	assert(campaign_state != null, "候选预览测试缺少 CampaignState 自动加载单例")
	var campaign_path := OS.get_temp_dir().path_join("新时代觉醒者-candidate-preview-campaign-%d.json" % Time.get_ticks_usec())
	campaign_state.configure_path(campaign_path)
	assert(campaign_state.reset(), "候选预览测试无法清理战役状态")
	assert(campaign_state.mark_office_completed({"money": 0, "stars": 1}), "候选预览测试无法解锁城市扩展")
	var launch_context = root.get_node_or_null("LaunchContext")
	assert(launch_context != null, "候选预览测试缺少 LaunchContext 自动加载单例")
	launch_context.clear()
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	launcher.set_meta("office_checkpoint_path", OS.get_temp_dir().path_join("新时代觉醒者-candidate-preview-office-%d.json" % Time.get_ticks_usec()))
	launcher.set_meta("city_checkpoint_path", OS.get_temp_dir().path_join("新时代觉醒者-candidate-preview-city-%d.json" % Time.get_ticks_usec()))
	root.add_child(launcher)
	await process_frame
	var buttons: Array[Node] = []
	for button in launcher.find_children("*", "Button", true, false):
		if not launcher.settings_overlay.is_ancestor_of(button):
			buttons.append(button)
	var profile_entries: Array = launcher.launch_profile.get("entries", [])
	var complete_candidate_package := FileAccess.file_exists("res://content/full-candidate-preview.marker")
	var office_candidate_button: Button = null
	var city_candidate_button: Button = null
	var market_delivery_button: Button = null
	for button in buttons:
		var button_text := str(button.text)
		if button_text.contains("办公室候选预览") or button_text.contains("候选资产预览"):
			office_candidate_button = button
		if button_text.contains("城市候选预览") or button_text.contains("城市扩展"):
			if button_text.contains("夜市"):
				market_delivery_button = button
			else:
				city_candidate_button = button
	if complete_candidate_package:
		var character_variant := str(launcher.launch_profile.get("character_variant", ""))
		var character_variant_label := str(launcher.launch_profile.get("character_variant_label", ""))
		assert(["makehuman", "original", "original_only"].has(character_variant), "完整候选包没有声明角色方案")
		assert(not character_variant_label.is_empty(), "完整候选包没有显示角色方案标签")
		assert(buttons.size() == profile_entries.size() + 2, "完整候选包不应重复追加候选入口，但必须保留设置和退出入口")
		assert(office_candidate_button != null, "完整候选包没有显示办公室候选入口")
		assert(city_candidate_button != null, "完整候选包没有显示城市候选入口")
		assert(launcher.shortcut_scene_requests.has(KEY_1), "完整候选包没有注册办公室 1 号快捷键")
		assert(launcher.shortcut_scene_requests.has(KEY_2), "完整候选包没有注册城市 2 号快捷键")
		assert(str(buttons[buttons.size() - 1].text) == "退出游戏", "完整候选包缺少退出入口")
		assert(str(buttons[buttons.size() - 2].text) == "游戏设置", "完整候选包缺少设置入口")
	else:
		assert(buttons.size() == profile_entries.size() + 5, "候选预览开启后没有追加办公室、城市、夜市、设置和退出五个入口")
		assert(office_candidate_button != null, "办公室候选预览入口没有明确标记为内部入口")
		assert(city_candidate_button != null, "城市候选预览入口没有明确标记为内部入口")
		assert(market_delivery_button != null, "夜市配送入口没有明确标记为内部入口")
		assert(launcher.shortcut_scene_requests.has(KEY_3), "候选预览入口没有注册 3 号快捷键")
		assert(launcher.shortcut_scene_requests.has(KEY_2), "城市候选预览入口没有注册 2 号快捷键")
		assert(launcher.shortcut_scene_requests.has(KEY_4), "夜市配送入口没有注册 4 号快捷键")
		assert(str(buttons[buttons.size() - 1].text) == "退出游戏", "候选预览入口缺少退出入口")
		assert(str(buttons[buttons.size() - 2].text) == "游戏设置", "候选预览入口缺少设置入口")

	var key := InputEventKey.new()
	key.keycode = KEY_1 if complete_candidate_package else KEY_3
	key.pressed = true
	launcher._unhandled_input(key)
	await process_frame
	var office = current_scene
	assert(office != null and office.scene_file_path == "res://scenes/benchmark.tscn", "候选预览快捷键没有进入办公室场景")
	assert(office.initialized, "候选预览办公室场景没有完成初始化")
	var expected_policy := "integration_test_asset_override"
	if complete_candidate_package:
		expected_policy = "original_assets_only_candidate_runtime_no_graybox_for_visual_slots" if str(launcher.launch_profile.get("character_variant", "")) == "original_only" else "optional_release_asset_with_graybox_fallback"
	assert(str(office.asset_catalog.get("policy", "")) == expected_policy, "候选预览入口没有传递隔离资产目录")
	assert(str(launch_context.pending_scene_path).is_empty(), "候选预览启动意图未被消费")
	if complete_candidate_package:
		assert(change_scene_to_file("res://scenes/launcher.tscn") == OK, "完整候选包返回启动器失败")
		await process_frame
		var city_launcher = current_scene
		assert(city_launcher != null and city_launcher.scene_file_path == "res://scenes/launcher.tscn", "完整候选包返回后启动器场景无效")
		launch_context.clear()
		var city_key := InputEventKey.new()
		city_key.keycode = KEY_2
		city_key.pressed = true
		city_launcher._unhandled_input(city_key)
		await process_frame
		var city = current_scene
		assert(city != null and city.scene_file_path == "res://scenes/city.tscn", "完整候选包城市快捷键没有进入城市场景")
		assert(city.initialized, "完整候选包城市场景没有完成初始化")
		assert(str(city.asset_catalog.get("policy", "")) == expected_policy, "完整候选包城市入口没有传递隔离资产目录")
	else:
		assert(change_scene_to_file("res://scenes/launcher.tscn") == OK, "候选预览返回启动器失败")
		await process_frame
		var market_launcher = current_scene
		assert(market_launcher != null and market_launcher.scene_file_path == "res://scenes/launcher.tscn", "候选预览返回后启动器场景无效")
		launch_context.clear()
		var market_key := InputEventKey.new()
		market_key.keycode = KEY_4
		market_key.pressed = true
		market_launcher._unhandled_input(market_key)
		await process_frame
		var market_city = current_scene
		assert(market_city != null and market_city.scene_file_path == "res://scenes/city.tscn", "夜市配送快捷键没有进入城市场景")
		assert(market_city.initialized, "夜市配送启动入口没有完成城市初始化")
		assert(market_city.city_pack_id == "city-market-delivery-v1", "夜市配送启动入口没有传递内容包 id")
		assert(str(market_city.asset_catalog.get("policy", "")) == expected_policy, "夜市配送入口没有传递隔离资产目录")
	OS.set_environment("REFERENCE_ASSET_PREVIEW", "")
	campaign_state.reset()
	print("启动器候选资产预览入口通过")
	quit()

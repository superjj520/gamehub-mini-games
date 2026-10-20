extends Control

const InputActionsClass = preload("res://scripts/input_actions.gd")
const SettingsStoreClass = preload("res://scripts/settings_store.gd")
const DisplaySettingsStoreClass = preload("res://scripts/display_settings_store.gd")
const RuntimeBootStatusClass = preload("res://scripts/runtime_boot_status.gd")

var status_label: Label
var launch_profile: Dictionary = {}
var shortcut_scene_paths: Dictionary = {}
var shortcut_scene_requests: Dictionary = {}
var settings_store
var display_settings_store
var settings_overlay: ColorRect
var settings_audio_button: Button
var settings_audio_slider: HSlider
var settings_audio_label: Label
var display_mode_option: OptionButton
var display_resolution_option: OptionButton
var settings_license_button: Button
var settings_license_text: RichTextLabel
var first_menu_button: Button
var display_settings_applied_on_boot := false

func _ready() -> void:
	RuntimeBootStatusClass.write("starting", "launcher")
	InputActionsClass.ensure_defaults()
	launch_profile = _load_launch_profile()
	settings_store = SettingsStoreClass.new(_settings_path())
	display_settings_store = DisplaySettingsStoreClass.new(_display_settings_path())
	var boot_display_settings: Dictionary = display_settings_store.load_settings()
	display_settings_applied_on_boot = display_settings_store.apply_settings(boot_display_settings)
	# 正式可见采集复用正常启动入口，避免 macOS 将 --scene 直接启动的
	# 测试场景判定为后台图形服务。没有这个环境变量时，玩家入口行为完全不变。
	if OS.get_environment("REFERENCE_RUN_CAPTURE_RUNNER").strip_edges() == "1":
		call_deferred("_open_reference_capture_runner")
		return
	_build_ui()
	RuntimeBootStatusClass.write("ready", "launcher", "首屏启动器已创建并获得默认焦点")
	var journal := get_node_or_null("/root/SessionJournal")
	if journal != null and journal.has_signal("session_opened"):
		journal.session_opened.connect(_on_session_opened)
	call_deferred("_show_recovery_notice")

func _open_reference_capture_runner() -> void:
	var result := get_tree().change_scene_to_file("res://tests/reference_capture_runner.tscn")
	if result != OK:
		push_error("可见参考采集入口加载失败：" + str(result))
		get_tree().quit(1)

func _unhandled_input(event: InputEvent) -> void:
	var is_echo: bool = event is InputEventKey and event.echo
	if settings_overlay != null and settings_overlay.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not is_echo:
		_close_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not is_echo:
		_request_quit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var request: Dictionary = shortcut_scene_requests.get(event.keycode, {})
		var scene_path := str(request.get("scene_path", shortcut_scene_paths.get(event.keycode, "")))
		if not scene_path.is_empty():
			if bool(request.get("requires_campaign_unlock", false)) and not _campaign_city_unlocked():
				status_label.text = "城市扩展尚未解锁 · 先完成办公室任务"
				get_viewport().set_input_as_handled()
				return
			_open_scene(scene_path, str(request.get("asset_catalog_path", "")), -1, str(request.get("content_pack_id", "")))

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101827")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_right", 96)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 72)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	var title := Label.new()
	title.text = "新时代觉醒者"
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)

	var description := Label.new()
	description.text = "第三人称任务游戏\n选择一个可回放的内容入口"
	description.add_theme_font_size_override("font_size", 20)
	column.add_child(description)

	var divider := HSeparator.new()
	column.add_child(divider)

	var buttons: Array[Button] = []
	shortcut_scene_paths.clear()
	shortcut_scene_requests.clear()
	var entries: Array = []
	entries.append_array(launch_profile.get("entries", []))
	# 完整候选包已有自己的候选入口；正式运行时通过环境变量追加内部预览入口。
	# 这样 Windows 候选可双击直达候选内容，同时不会在候选包中重复显示同一组按钮。
	if _candidate_preview_enabled() and str(launch_profile.get("status", "")) != "internal_candidate_review_only":
		entries.append({
			"id": "office-candidate-preview",
			"shortcut": "3",
			"title": "3  候选资产预览 · 办公室（仅内部）",
			"description": "使用隔离候选资产目录预览人物、NPC和办公室环境；不会进入默认发布入口",
			"scene_path": "res://scenes/benchmark.tscn",
			"asset_catalog_path": "res://tests/asset-runtime-catalog-override.json",
		})
		entries.append({
			"id": "city-extension-preview",
			"shortcut": "2",
			"title": "2  城市扩展 · 街区配送（仅内部）",
			"description": "使用城市候选运行时预览人群、交通、三轮车和后场仓储；不会进入默认发布入口",
			"scene_path": "res://scenes/city.tscn",
			"asset_catalog_path": "res://tests/asset-runtime-catalog-override.json",
			"content_pack_id": "city-free-eggs-v1",
			"requires_campaign_unlock": true,
		})
		entries.append({
			"id": "city-market-delivery-preview",
			"shortcut": "4",
			"title": "4  城市扩展 · 街角夜市配送（仅内部）",
			"description": "回放接单、装载、配送和领奖四阶段内容；不会进入默认发布入口",
			"scene_path": "res://scenes/city.tscn",
			"asset_catalog_path": "res://tests/asset-runtime-catalog-override.json",
			"content_pack_id": "city-market-delivery-v1",
			"requires_campaign_unlock": true,
		})
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if bool(entry.get("internal_only", false)) and not _candidate_preview_enabled():
			continue
		var button := Button.new()
		button.text = str(entry.get("title", "未命名入口"))
		button.tooltip_text = str(entry.get("description", ""))
		button.custom_minimum_size = Vector2(0, 64)
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 22)
		var scene_path := str(entry.get("scene_path", ""))
		var asset_catalog_path := str(entry.get("asset_catalog_path", ""))
		var content_pack_id := str(entry.get("content_pack_id", ""))
		var requires_campaign_unlock := bool(entry.get("requires_campaign_unlock", false))
		var campaign_locked := requires_campaign_unlock and not _campaign_city_unlocked()
		var entry_has_checkpoint := _checkpoint_available(_checkpoint_path_for_scene(scene_path))
		var shortcut := _keycode_for_shortcut(str(entry.get("shortcut", "")))
		if shortcut >= 0:
			shortcut_scene_paths[shortcut] = scene_path
			shortcut_scene_requests[shortcut] = {"scene_path": scene_path, "asset_catalog_path": asset_catalog_path, "content_pack_id": content_pack_id, "requires_campaign_unlock": requires_campaign_unlock}
		button.disabled = campaign_locked
		if campaign_locked:
			button.tooltip_text = "先完成办公室任务后解锁城市扩展"
		button.pressed.connect(func():
			if requires_campaign_unlock and not _campaign_city_unlocked():
				status_label.text = "城市扩展尚未解锁 · 先完成办公室任务"
				return
			_open_scene(scene_path, asset_catalog_path, -1, content_pack_id)
		)
		column.add_child(button)
		buttons.append(button)
		if entry_has_checkpoint:
			var new_game_button := Button.new()
			new_game_button.text = "新游戏（清除本地存档）"
			new_game_button.tooltip_text = "删除该入口的本地存档和备份后重新开始；需要确认"
			new_game_button.custom_minimum_size = Vector2(0, 48)
			new_game_button.focus_mode = Control.FOCUS_ALL
			new_game_button.add_theme_font_size_override("font_size", 18)
			new_game_button.pressed.connect(func(): _confirm_new_game(scene_path, asset_catalog_path, content_pack_id))
			column.add_child(new_game_button)
			buttons.append(new_game_button)
	for index in range(1, buttons.size()):
		buttons[index - 1].focus_neighbor_bottom = buttons[index - 1].get_path_to(buttons[index])
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(buttons[index - 1])
	first_menu_button = buttons[0] if not buttons.is_empty() else null

	var settings_button := Button.new()
	settings_button.text = "游戏设置"
	settings_button.tooltip_text = "音频、控制说明和第三方许可"
	settings_button.custom_minimum_size = Vector2(0, 56)
	settings_button.focus_mode = Control.FOCUS_ALL
	settings_button.add_theme_font_size_override("font_size", 20)
	settings_button.pressed.connect(_open_settings)
	column.add_child(settings_button)
	buttons.append(settings_button)

	var quit_button := Button.new()
	quit_button.text = "退出游戏"
	quit_button.tooltip_text = "关闭当前游戏窗口（键盘 Esc / 手柄 Start）"
	quit_button.custom_minimum_size = Vector2(0, 56)
	quit_button.focus_mode = Control.FOCUS_ALL
	quit_button.add_theme_font_size_override("font_size", 20)
	quit_button.pressed.connect(_request_quit)
	column.add_child(quit_button)
	buttons.append(quit_button)
	for index in range(1, buttons.size()):
		buttons[index - 1].focus_neighbor_bottom = buttons[index - 1].get_path_to(buttons[index])
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(buttons[index - 1])
	if not buttons.is_empty():
		buttons[0].grab_focus()

	status_label = Label.new()
	var candidate_variant_label := str(launch_profile.get("character_variant_label", "")).strip_edges()
	if not candidate_variant_label.is_empty():
		status_label.text = "内部候选 · " + candidate_variant_label + " · " + _campaign_status_text()
	else:
		status_label.text = ("内部开发入口 · 原创候选资产 · " + _campaign_status_text()) if bool(launch_profile.get("internal_development_mode", true)) else "首发范围入口 · 最终资产与视觉验收仍需完成"
	status_label.add_theme_color_override("font_color", Color("9aa7bd"))
	column.add_child(status_label)

	var controls_hint := Label.new()
	controls_hint.text = "选择：方向键 / 手柄摇杆    确认：Enter / 手柄 A    退出：Esc / 手柄 Start"
	controls_hint.add_theme_font_size_override("font_size", 16)
	controls_hint.add_theme_color_override("font_color", Color("71809a"))
	column.add_child(controls_hint)
	_build_settings_overlay()

func _build_settings_overlay() -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.name = "游戏设置遮罩"
	settings_overlay.color = Color(0.02, 0.03, 0.06, 0.86)
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_overlay.z_index = 30
	settings_overlay.visible = false
	add_child(settings_overlay)

	var panel := PanelContainer.new()
	panel.name = "游戏设置面板"
	panel.custom_minimum_size = Vector2(680, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340, -330)
	panel.size = Vector2(680, 660)
	settings_overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "游戏设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	settings_audio_button = Button.new()
	settings_audio_button.custom_minimum_size = Vector2(0, 52)
	settings_audio_button.focus_mode = Control.FOCUS_ALL
	settings_audio_button.add_theme_font_size_override("font_size", 18)
	settings_audio_button.pressed.connect(_toggle_launcher_audio)
	column.add_child(settings_audio_button)

	settings_audio_label = Label.new()
	settings_audio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(settings_audio_label)

	settings_audio_slider = HSlider.new()
	settings_audio_slider.min_value = -40.0
	settings_audio_slider.max_value = 0.0
	settings_audio_slider.step = 1.0
	settings_audio_slider.custom_minimum_size = Vector2(0, 32)
	settings_audio_slider.focus_mode = Control.FOCUS_ALL
	settings_audio_slider.value_changed.connect(_on_launcher_audio_volume_changed)
	column.add_child(settings_audio_slider)

	var display_title := Label.new()
	display_title.text = "显示设置（目标设备）"
	display_title.add_theme_font_size_override("font_size", 18)
	column.add_child(display_title)

	var display_mode_row := HBoxContainer.new()
	display_mode_row.add_theme_constant_override("separation", 12)
	column.add_child(display_mode_row)
	var display_mode_label := Label.new()
	display_mode_label.text = "窗口模式"
	display_mode_label.custom_minimum_size = Vector2(140, 48)
	display_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	display_mode_row.add_child(display_mode_label)
	display_mode_option = OptionButton.new()
	display_mode_option.custom_minimum_size = Vector2(0, 48)
	display_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_mode_option.focus_mode = Control.FOCUS_ALL
	display_mode_option.add_item("窗口")
	display_mode_option.set_item_metadata(0, "windowed")
	display_mode_option.add_item("全屏")
	display_mode_option.set_item_metadata(1, "fullscreen")
	display_mode_row.add_child(display_mode_option)

	var display_resolution_row := HBoxContainer.new()
	display_resolution_row.add_theme_constant_override("separation", 12)
	column.add_child(display_resolution_row)
	var display_resolution_label := Label.new()
	display_resolution_label.text = "分辨率"
	display_resolution_label.custom_minimum_size = Vector2(140, 48)
	display_resolution_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	display_resolution_row.add_child(display_resolution_label)
	display_resolution_option = OptionButton.new()
	display_resolution_option.custom_minimum_size = Vector2(0, 48)
	display_resolution_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_resolution_option.focus_mode = Control.FOCUS_ALL
	display_resolution_option.add_item("1280×720")
	display_resolution_option.set_item_metadata(0, "1280x720")
	display_resolution_option.add_item("960×540")
	display_resolution_option.set_item_metadata(1, "960x540")
	display_resolution_option.add_item("1920×1080")
	display_resolution_option.set_item_metadata(2, "1920x1080")
	display_resolution_row.add_child(display_resolution_option)

	var apply_display_button := Button.new()
	apply_display_button.name = "应用显示设置"
	apply_display_button.text = "应用显示设置"
	apply_display_button.custom_minimum_size = Vector2(0, 48)
	apply_display_button.focus_mode = Control.FOCUS_ALL
	apply_display_button.add_theme_font_size_override("font_size", 18)
	apply_display_button.pressed.connect(_save_launcher_display_settings)
	column.add_child(apply_display_button)

	var controls_title := Label.new()
	controls_title.text = "操作说明（键盘 / 手柄）"
	controls_title.add_theme_font_size_override("font_size", 18)
	column.add_child(controls_title)

	var controls_text := RichTextLabel.new()
	controls_text.bbcode_enabled = false
	controls_text.fit_content = true
	controls_text.custom_minimum_size = Vector2(0, 122)
	controls_text.text = "移动：WASD / 左摇杆\n镜头：方向键 / 右摇杆\n冲刺：Shift / 左摇杆按压    蹲伏：C / 手柄 B\n交互：E / 手柄 X    冲突：F / 手柄 RB    闪避：Space / 手柄 LB\n上下车：V / 手柄 Y\n暂停：Esc / 手柄 Start"
	column.add_child(controls_text)

	settings_license_button = Button.new()
	settings_license_button.text = "第三方许可"
	settings_license_button.custom_minimum_size = Vector2(0, 48)
	settings_license_button.focus_mode = Control.FOCUS_ALL
	settings_license_button.add_theme_font_size_override("font_size", 18)
	settings_license_button.pressed.connect(_toggle_launcher_license)
	column.add_child(settings_license_button)

	settings_license_text = RichTextLabel.new()
	settings_license_text.bbcode_enabled = false
	settings_license_text.fit_content = false
	settings_license_text.custom_minimum_size = Vector2(0, 120)
	settings_license_text.scroll_active = true
	settings_license_text.visible = false
	settings_license_text.text = "本项目当前使用 Godot Engine。\n\n" + Engine.get_license_text()
	column.add_child(settings_license_text)

	var close_button := Button.new()
	close_button.name = "关闭设置"
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(0, 52)
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_close_settings)
	column.add_child(close_button)

	_apply_launcher_audio_settings()
	_apply_launcher_display_settings()
	settings_audio_button.focus_neighbor_bottom = settings_audio_button.get_path_to(settings_audio_slider)
	settings_audio_slider.focus_neighbor_top = settings_audio_slider.get_path_to(settings_audio_button)
	close_button.focus_neighbor_top = close_button.get_path_to(settings_license_button)

func _open_settings() -> void:
	if settings_overlay == null:
		return
	_apply_launcher_audio_settings()
	_apply_launcher_display_settings()
	settings_overlay.visible = true
	settings_audio_button.grab_focus()

func _close_settings() -> void:
	if settings_overlay == null:
		return
	settings_overlay.visible = false
	if first_menu_button != null:
		first_menu_button.grab_focus()

func _toggle_launcher_audio() -> void:
	var current := _launcher_audio_settings()
	var enabled := not bool(current.get("enabled", false))
	if settings_store.save_audio_settings(enabled, float(current.get("master_volume_db", SettingsStoreClass.DEFAULT_MASTER_VOLUME_DB))):
		_apply_launcher_audio_settings()
		status_label.text = "设置已保存：音频" + ("开启" if enabled else "关闭")
	else:
		status_label.text = "设置保存失败：" + str(settings_store.last_error)

func _save_launcher_display_settings() -> void:
	var mode := str(display_mode_option.get_selected_metadata())
	var resolution := str(display_resolution_option.get_selected_metadata())
	var parts := resolution.split("x")
	if parts.size() != 2:
		status_label.text = "显示设置保存失败：分辨率格式无效"
		return
	var width := int(parts[0])
	var height := int(parts[1])
	if display_settings_store.save_settings(mode, width, height) and display_settings_store.apply_settings(display_settings_store.load_settings()):
		status_label.text = "显示设置已保存：" + ("窗口" if mode == "windowed" else "全屏") + " %d×%d" % [width, height]
	else:
		status_label.text = "显示设置保存失败：" + str(display_settings_store.last_error)

func _on_launcher_audio_volume_changed(value: float) -> void:
	var current := _launcher_audio_settings()
	var clamped := clampf(value, -40.0, 0.0)
	_update_launcher_audio_label(clamped)
	if settings_store.save_audio_settings(bool(current.get("enabled", false)), clamped):
		status_label.text = "设置已保存：主音量 %d dB" % roundi(clamped)

func _apply_launcher_audio_settings() -> void:
	var current := _launcher_audio_settings()
	var enabled := bool(current.get("enabled", SettingsStoreClass.DEFAULT_AUDIO_ENABLED))
	var volume_db := clampf(float(current.get("master_volume_db", SettingsStoreClass.DEFAULT_MASTER_VOLUME_DB)), -40.0, 0.0)
	if settings_audio_button != null:
		settings_audio_button.text = "音频：开" if enabled else "音频：关"
	if settings_audio_slider != null:
		settings_audio_slider.set_value_no_signal(volume_db)
	_update_launcher_audio_label(volume_db)

func _apply_launcher_display_settings() -> void:
	if display_settings_store == null or display_mode_option == null or display_resolution_option == null:
		return
	var settings: Dictionary = display_settings_store.load_settings()
	for index in range(display_mode_option.item_count):
		if str(display_mode_option.get_item_metadata(index)) == str(settings.get("mode", DisplaySettingsStoreClass.DEFAULT_MODE)):
			display_mode_option.select(index)
	for index in range(display_resolution_option.item_count):
		if str(display_resolution_option.get_item_metadata(index)) == "%dx%d" % [int(settings.get("width", DisplaySettingsStoreClass.DEFAULT_WIDTH)), int(settings.get("height", DisplaySettingsStoreClass.DEFAULT_HEIGHT))]:
			display_resolution_option.select(index)

func _launcher_audio_settings() -> Dictionary:
	if settings_store == null:
		return {"enabled": SettingsStoreClass.DEFAULT_AUDIO_ENABLED, "master_volume_db": SettingsStoreClass.DEFAULT_MASTER_VOLUME_DB}
	return settings_store.load_audio_settings()

func _update_launcher_audio_label(value: float) -> void:
	if settings_audio_label != null:
		settings_audio_label.text = "主音量：%d dB" % roundi(value)

func _toggle_launcher_license() -> void:
	if settings_license_text == null:
		return
	settings_license_text.visible = not settings_license_text.visible
	settings_license_button.text = "收起第三方许可" if settings_license_text.visible else "第三方许可"

func _settings_path() -> String:
	var environment_path := OS.get_environment("REFERENCE_SETTINGS_PATH").strip_edges()
	if not environment_path.is_empty():
		return environment_path
	return str(get_meta("settings_path", "user://reference_settings.json"))

func _display_settings_path() -> String:
	var environment_path := OS.get_environment("REFERENCE_DISPLAY_SETTINGS_PATH").strip_edges()
	if not environment_path.is_empty():
		return environment_path
	return str(get_meta("display_settings_path", "user://reference_display_settings.json"))

func _request_quit() -> void:
	status_label.text = "正在退出……"
	get_tree().quit()

func _load_launch_profile() -> Dictionary:
	var file := FileAccess.open("res://content/launch-profile.json", FileAccess.READ)
	if file == null:
		return {}
	var raw_text := file.get_as_text()
	file.close()
	file = null
	var payload = JSON.parse_string(raw_text)
	return payload if payload is Dictionary else {}

func _keycode_for_shortcut(shortcut: String) -> int:
	match shortcut:
		"1":
			return KEY_1
		"2":
			return KEY_2
		"3":
			return KEY_3
		"4":
			return KEY_4
		_:
			return -1

func _candidate_preview_enabled() -> bool:
	return OS.get_environment("REFERENCE_ASSET_PREVIEW").strip_edges() == "1" or FileAccess.file_exists("res://content/full-candidate-preview.marker")

func _campaign_city_unlocked() -> bool:
	var campaign_state := get_node_or_null("/root/CampaignState")
	return campaign_state != null and campaign_state.has_method("is_city_unlocked") and bool(campaign_state.is_city_unlocked())

func _campaign_status_text() -> String:
	return "城市扩展已解锁" if _campaign_city_unlocked() else "先完成办公室任务解锁城市扩展"

func _open_scene(scene_path: String, asset_catalog_path := "", load_checkpoint_override: int = -1, content_pack_id := "") -> void:
	RuntimeBootStatusClass.write("loading", "launcher", scene_path)
	var checkpoint_path := _checkpoint_path_for_scene(scene_path)
	var should_load_checkpoint := _checkpoint_available(checkpoint_path) if load_checkpoint_override < 0 else load_checkpoint_override == 1
	var launch_context := get_node_or_null("/root/LaunchContext")
	if launch_context != null and launch_context.has_method("request_scene"):
		launch_context.request_scene(scene_path, should_load_checkpoint, checkpoint_path, asset_catalog_path, content_pack_id)
	status_label.text = ("正在读取存档并加载：" if should_load_checkpoint else "正在加载：") + scene_path.get_file()
	var result := get_tree().change_scene_to_file(scene_path)
	if result != OK:
		RuntimeBootStatusClass.write("failed", "launcher", "场景加载失败：%s" % str(result))
		status_label.text = "加载失败：" + str(result)

func _confirm_new_game(scene_path: String, asset_catalog_path := "", content_pack_id := "") -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "新游戏确认"
	dialog.title = "开始新游戏"
	dialog.dialog_text = "这会删除该任务入口的本地存档、备份和临时文件，是否继续？"
	dialog.ok_button_text = "开始新游戏"
	dialog.cancel_button_text = "取消"
	dialog.confirmed.connect(func():
		_start_new_game(scene_path, asset_catalog_path, content_pack_id)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2(560, 220))
	dialog.get_ok_button().grab_focus()

func _start_new_game(scene_path: String, asset_catalog_path := "", content_pack_id := "") -> void:
	var checkpoint_path := _checkpoint_path_for_scene(scene_path)
	if not _clear_checkpoint_files(checkpoint_path):
		status_label.text = "无法清除本地存档，已取消新游戏"
		return
	_open_scene(scene_path, asset_catalog_path, 0, content_pack_id)

func _clear_checkpoint_files(path: String) -> bool:
	if path.strip_edges().is_empty():
		return false
	var candidate_paths := [path, path + ".bak", path + ".tmp"]
	for candidate in candidate_paths:
		if not FileAccess.file_exists(candidate):
			continue
		var absolute_path := ProjectSettings.globalize_path(candidate)
		var result := DirAccess.remove_absolute(absolute_path)
		if result != OK and FileAccess.file_exists(candidate):
			return false
	return true

func _checkpoint_path_for_scene(scene_path: String) -> String:
	if scene_path == "res://scenes/city.tscn":
		var city_environment_path := OS.get_environment("REFERENCE_CITY_CHECKPOINT_PATH").strip_edges()
		if not city_environment_path.is_empty():
			return city_environment_path
		return str(get_meta("city_checkpoint_path", "user://city_checkpoint.json"))
	var office_environment_path := OS.get_environment("REFERENCE_OFFICE_CHECKPOINT_PATH").strip_edges()
	if not office_environment_path.is_empty():
		return office_environment_path
	return str(get_meta("office_checkpoint_path", "user://reference_checkpoint.json"))

func _checkpoint_available(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")

func _show_recovery_notice() -> void:
	var journal := get_node_or_null("/root/SessionJournal")
	if journal != null and bool(journal.get("recovered_previous_session")):
		status_label.text = "检测到上次运行未正常结束 · 本地备份存档仍可读取"

func _on_session_opened(recovered_previous_session: bool) -> void:
	if recovered_previous_session:
		status_label.text = "检测到上次运行未正常结束 · 本地备份存档仍可读取"

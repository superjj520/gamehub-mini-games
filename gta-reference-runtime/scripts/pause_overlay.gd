class_name PauseOverlay
extends CanvasLayer

const InputActionsClass = preload("res://scripts/input_actions.gd")

signal restart_requested
signal menu_requested
signal audio_toggled(enabled: bool)
signal audio_volume_changed(volume_db: float)

var audio_enabled := false
var resume_button: Button
var restart_button: Button
var menu_button: Button
var audio_button: Button
var audio_volume_slider: HSlider
var audio_volume_label: Label
var controls_button: Button
var controls_text: RichTextLabel
var license_button: Button
var license_text: RichTextLabel
var input_locked := false

func _ready() -> void:
	InputActionsClass.ensure_defaults()
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build_ui()
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and not visible and not input_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func set_input_locked(locked: bool) -> void:
	input_locked = locked
	if locked and visible:
		hide_pause()
	if locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func toggle_pause() -> void:
	if visible:
		hide_pause()
	else:
		show_pause()

func show_pause() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()

func hide_pause() -> void:
	get_tree().paused = false
	visible = false
	if not input_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func set_audio_enabled(enabled: bool) -> void:
	audio_enabled = enabled
	audio_button.text = "音频：开" if audio_enabled else "音频：关"
	audio_toggled.emit(audio_enabled)

func apply_audio_settings(enabled: bool, volume_db: float) -> void:
	audio_enabled = enabled
	if audio_button != null:
		audio_button.text = "音频：开" if audio_enabled else "音频：关"
	var clamped := clampf(volume_db, -40.0, 0.0)
	if audio_volume_slider != null:
		audio_volume_slider.set_value_no_signal(clamped)
	_update_volume_label(clamped)

func set_audio_volume_db(volume_db: float) -> void:
	var clamped := clampf(volume_db, -40.0, 0.0)
	if audio_volume_slider != null:
		audio_volume_slider.value = clamped
	_update_volume_label(clamped)
	audio_volume_changed.emit(clamped)

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.03, 0.06, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 72)
	dimmer.add_child(margin)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "游戏暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	var hint := Label.new()
	hint.text = "选择操作，或按 Esc 返回游戏"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	column.add_child(hint)

	resume_button = _make_button("继续游戏")
	resume_button.pressed.connect(hide_pause)
	column.add_child(resume_button)
	restart_button = _make_button("重新开始当前场景")
	restart_button.pressed.connect(_request_restart)
	column.add_child(restart_button)
	menu_button = _make_button("返回场景入口")
	menu_button.pressed.connect(_request_menu)
	column.add_child(menu_button)
	audio_button = _make_button("音频：关")
	audio_button.pressed.connect(func(): set_audio_enabled(not audio_enabled))
	column.add_child(audio_button)
	audio_volume_label = Label.new()
	audio_volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(audio_volume_label)
	audio_volume_slider = HSlider.new()
	audio_volume_slider.min_value = -40.0
	audio_volume_slider.max_value = 0.0
	audio_volume_slider.step = 1.0
	audio_volume_slider.value = -14.0
	audio_volume_slider.custom_minimum_size = Vector2(0, 32)
	audio_volume_slider.value_changed.connect(_on_volume_slider_changed)
	column.add_child(audio_volume_slider)
	_update_volume_label(audio_volume_slider.value)
	controls_button = _make_button("操作说明")
	controls_button.pressed.connect(_toggle_controls_text)
	column.add_child(controls_button)

	controls_text = RichTextLabel.new()
	controls_text.bbcode_enabled = false
	controls_text.custom_minimum_size = Vector2(0, 168)
	controls_text.fit_content = false
	controls_text.focus_mode = Control.FOCUS_ALL
	controls_text.scroll_active = true
	controls_text.visible = false
	controls_text.text = "移动：WASD / 左摇杆\n镜头：方向键 / 右摇杆\n冲刺：Shift / 左摇杆按压    蹲伏：C / 手柄 B\n交互：E / 手柄 X    攻击或冲突动作：F / 手柄 RB    闪避：Space / 手柄 LB\n上下车：V / 手柄 Y\n重试：R / 手柄 A    读取检查点：L / 手柄 Back\n暂停：Esc / 手柄 Start"
	column.add_child(controls_text)
	license_button = _make_button("第三方许可")
	license_button.pressed.connect(_toggle_license_text)
	column.add_child(license_button)

	license_text = RichTextLabel.new()
	license_text.bbcode_enabled = false
	license_text.custom_minimum_size = Vector2(0, 220)
	license_text.fit_content = false
	license_text.focus_mode = Control.FOCUS_ALL
	license_text.scroll_active = true
	license_text.visible = false
	license_text.text = "本项目当前使用 Godot Engine。\n\n" + Engine.get_license_text()
	column.add_child(license_text)

func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	return button

func _request_restart() -> void:
	hide_pause()
	restart_requested.emit()

func _request_menu() -> void:
	hide_pause()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	menu_requested.emit()

func _toggle_license_text() -> void:
	license_text.visible = not license_text.visible
	license_button.text = "收起第三方许可" if license_text.visible else "第三方许可"
	if license_text.visible:
		license_text.grab_focus()

func _toggle_controls_text() -> void:
	controls_text.visible = not controls_text.visible
	controls_button.text = "收起操作说明" if controls_text.visible else "操作说明"
	if controls_text.visible:
		controls_text.grab_focus()

func _on_volume_slider_changed(value: float) -> void:
	_update_volume_label(value)
	audio_volume_changed.emit(value)

func _update_volume_label(value: float) -> void:
	if audio_volume_label != null:
		audio_volume_label.text = "主音量：%d dB" % roundi(value)

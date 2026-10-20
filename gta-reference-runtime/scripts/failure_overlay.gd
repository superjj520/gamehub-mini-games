class_name FailureOverlay
extends CanvasLayer

signal restart_requested
signal menu_requested

var _reason: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_build_ui()
	visible = false

func show_failure(reason: String) -> void:
	if _reason != null:
		_reason.text = "失败原因：" + reason
	visible = true
	var restart_button := get_node_or_null("失败遮罩/失败面板/内容/重新开始") as Button
	if restart_button != null:
		restart_button.grab_focus()

func hide_failure() -> void:
	visible = false

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "失败遮罩"
	dimmer.color = Color(0.025, 0.03, 0.05, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.name = "失败面板"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-300.0, -190.0)
	panel.size = Vector2(600.0, 380.0)
	dimmer.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "内容"
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title := Label.new()
	title.name = "标题"
	title.text = "任务失败"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("f06b63"))
	column.add_child(title)

	_reason = Label.new()
	_reason.name = "原因"
	_reason.text = "失败原因："
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.custom_minimum_size = Vector2(0.0, 54.0)
	_reason.add_theme_font_size_override("font_size", 18)
	column.add_child(_reason)

	var hint := Label.new()
	hint.name = "提示"
	hint.text = "场景已冻结。选择下一步操作，或按 R 快速重试。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("c4cbd6"))
	column.add_child(hint)

	var restart_button := _make_button("重新开始")
	restart_button.name = "重新开始"
	restart_button.pressed.connect(func():
		hide_failure()
		restart_requested.emit()
	)
	column.add_child(restart_button)

	var menu_button := _make_button("返回场景入口")
	menu_button.name = "返回入口"
	menu_button.pressed.connect(func():
		hide_failure()
		menu_requested.emit()
	)
	column.add_child(menu_button)

func _make_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 19)
	return button

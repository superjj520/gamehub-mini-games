class_name RuntimeBootError
extends CanvasLayer

var _title_text := "运行时无法启动"
var _reason_text := ""
var _title_label: Label
var _reason_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()
	_apply_text()

func configure(title: String, reason: String) -> void:
	_title_text = title
	_reason_text = reason
	if is_node_ready():
		_apply_text()

func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "启动错误遮罩"
	dimmer.color = Color(0.015, 0.02, 0.035, 0.92)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.name = "启动错误面板"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340.0, -210.0)
	panel.size = Vector2(680.0, 420.0)
	dimmer.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "内容"
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	_title_label = Label.new()
	_title_label.name = "标题"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color("f0b05e"))
	column.add_child(_title_label)

	_reason_label = Label.new()
	_reason_label.name = "原因"
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.custom_minimum_size = Vector2(0.0, 120.0)
	_reason_label.add_theme_font_size_override("font_size", 18)
	_reason_label.add_theme_color_override("font_color", Color("d6dce6"))
	column.add_child(_reason_label)

	var hint := Label.new()
	hint.name = "提示"
	hint.text = "本次启动已安全停止，没有静默回退到灰盒。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("8f9bad"))
	column.add_child(hint)

	var return_button := Button.new()
	return_button.name = "返回入口"
	return_button.text = "返回游戏入口"
	return_button.custom_minimum_size = Vector2(0.0, 54.0)
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.add_theme_font_size_override("font_size", 19)
	return_button.pressed.connect(_return_to_launcher)
	column.add_child(return_button)
	return_button.grab_focus()

func _apply_text() -> void:
	if _title_label != null:
		_title_label.text = _title_text
	if _reason_label != null:
		_reason_label.text = "原因：" + _reason_text

func _return_to_launcher() -> void:
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")

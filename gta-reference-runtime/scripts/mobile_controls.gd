class_name MobileControls
extends Control

signal pause_requested

const JOYSTICK_RADIUS := 86.0
const BUTTON_RADIUS := 54.0

var mobile_enabled := false
var move_touch_id := -1
var look_touch_id := -1
var crouch_touch_id := -1
var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var interact_queued := false
var restart_queued := false
var terminal_state := false
var joystick_center := Vector2.ZERO
var crouch_center := Vector2.ZERO
var interact_center := Vector2.ZERO
var restart_center := Vector2.ZERO
var pause_rect := Rect2()
var crouch_label: Label
var interact_label: Label
var restart_label: Label
var pause_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_enabled = _should_show()
	if not mobile_enabled:
		visible = false
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_labels()
	_layout()
	get_viewport().size_changed.connect(_layout)
	queue_redraw()

func _should_show() -> bool:
	var forced := OS.get_environment("MOBILE_CONTROLS").strip_edges()
	if forced == "1":
		return true
	return OS.get_name() in ["Android", "iOS", "Web"] or DisplayServer.is_touchscreen_available()

func _build_labels() -> void:
	crouch_label = _make_label("蹲伏")
	interact_label = _make_label("交互")
	restart_label = _make_label("重试")
	pause_label = _make_label("暂停")
	add_child(crouch_label)
	add_child(interact_label)
	add_child(restart_label)
	add_child(pause_label)
	restart_label.visible = false

func _make_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("f6f0dc"))
	label.add_theme_color_override("font_outline_color", Color("172033"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _layout() -> void:
	if not mobile_enabled:
		return
	var viewport_size := get_viewport_rect().size
	joystick_center = Vector2(140.0, viewport_size.y - 142.0)
	crouch_center = Vector2(viewport_size.x - 220.0, viewport_size.y - 116.0)
	interact_center = Vector2(viewport_size.x - 100.0, viewport_size.y - 220.0)
	restart_center = Vector2(viewport_size.x - 100.0, viewport_size.y - 100.0)
	pause_rect = Rect2(viewport_size.x - 132.0, 18.0, 112.0, 64.0)
	_place_label(crouch_label, crouch_center, 108.0)
	_place_label(interact_label, interact_center, 108.0)
	_place_label(restart_label, restart_center, 108.0)
	pause_label.position = Vector2(viewport_size.x - 132.0, 18.0)
	pause_label.size = Vector2(112.0, 64.0)
	queue_redraw()

func _place_label(label: Label, center: Vector2, diameter: float) -> void:
	label.position = center - Vector2.ONE * diameter * 0.5
	label.size = Vector2.ONE * diameter

func _draw() -> void:
	if not mobile_enabled:
		return
	draw_circle(joystick_center, JOYSTICK_RADIUS + 10.0, Color(0.04, 0.07, 0.12, 0.40))
	draw_arc(joystick_center, JOYSTICK_RADIUS + 10.0, 0.0, TAU, 48, Color(0.95, 0.86, 0.62, 0.62), 3.0)
	draw_circle(joystick_center + move_vector * JOYSTICK_RADIUS, 38.0, Color(0.85, 0.70, 0.38, 0.82))
	_draw_button(crouch_center, crouch_touch_id >= 0)
	_draw_button(interact_center, interact_queued)
	if terminal_state:
		_draw_button(restart_center, restart_queued)
	_draw_pause_button()

func _draw_button(center: Vector2, pressed: bool) -> void:
	var color := Color(0.78, 0.61, 0.28, 0.90) if pressed else Color(0.04, 0.07, 0.12, 0.55)
	draw_circle(center, BUTTON_RADIUS, color)
	draw_arc(center, BUTTON_RADIUS, 0.0, TAU, 40, Color(0.95, 0.86, 0.62, 0.70), 3.0)

func _draw_pause_button() -> void:
	draw_style_box(_panel_style(Color(0.04, 0.07, 0.12, 0.62)), pause_rect)

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.95, 0.86, 0.62, 0.70)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style

func _input(event: InputEvent) -> void:
	if not mobile_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_start_touch(touch.index, touch.position)
		else:
			_end_touch(touch.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == move_touch_id:
			move_vector = (drag.position - joystick_center).limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif drag.index == look_touch_id:
			look_delta += drag.relative * 1.15
			get_viewport().set_input_as_handled()

func _start_touch(index: int, position: Vector2) -> void:
	if pause_rect.has_point(position):
		pause_requested.emit()
		return
	if terminal_state and _inside_circle(position, restart_center):
		restart_queued = true
		queue_redraw()
		return
	if _inside_circle(position, crouch_center):
		crouch_touch_id = index
		queue_redraw()
		return
	if _inside_circle(position, interact_center):
		interact_queued = true
		queue_redraw()
		return
	if move_touch_id < 0 and position.distance_to(joystick_center) <= JOYSTICK_RADIUS * 1.55:
		move_touch_id = index
		move_vector = (position - joystick_center).limit_length(JOYSTICK_RADIUS) / JOYSTICK_RADIUS
		queue_redraw()
		return
	if look_touch_id < 0 and position.x > get_viewport_rect().size.x * 0.34:
		look_touch_id = index

func _end_touch(index: int) -> void:
	if index == move_touch_id:
		move_touch_id = -1
		move_vector = Vector2.ZERO
	if index == look_touch_id:
		look_touch_id = -1
	if index == crouch_touch_id:
		crouch_touch_id = -1
	queue_redraw()

func _inside_circle(position: Vector2, center: Vector2) -> bool:
	return position.distance_squared_to(center) <= BUTTON_RADIUS * BUTTON_RADIUS

func consume_input() -> Dictionary:
	if not mobile_enabled:
		return {}
	var result := {
		"move": move_vector,
		"look": look_delta,
		"crouch": crouch_touch_id >= 0,
		"interact": interact_queued,
		"restart": restart_queued
	}
	look_delta = Vector2.ZERO
	interact_queued = false
	restart_queued = false
	queue_redraw()
	return result

func set_terminal_state(terminal: bool) -> void:
	terminal_state = terminal
	if restart_label != null:
		restart_label.visible = terminal
	queue_redraw()

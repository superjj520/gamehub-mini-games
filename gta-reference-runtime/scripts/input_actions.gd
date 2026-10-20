class_name InputActions
extends RefCounted

const ACTIONS := [
	"move_left",
	"move_right",
	"move_forward",
	"move_back",
	"sprint",
	"look_left",
	"look_right",
	"look_up",
	"look_down",
	"crouch",
	"interact",
	"restart",
	"vehicle_enter_exit",
	"load_checkpoint",
	"attack",
	"dodge",
	"pause"
]
const GAMEPAD_DEADZONE := 0.18

static var initialized := false

static func ensure_defaults() -> void:
	if initialized:
		return
	for action_name in ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	_configure_gamepad_deadzones()
	_add_keyboard_defaults()
	_add_gamepad_defaults()
	initialized = true

static func _configure_gamepad_deadzones() -> void:
	for action_name in [
		"move_left",
		"move_right",
		"move_forward",
		"move_back",
		"look_left",
		"look_right",
		"look_up",
		"look_down"
	]:
		InputMap.action_set_deadzone(action_name, GAMEPAD_DEADZONE)

static func _add_keyboard_defaults() -> void:
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("sprint", KEY_SHIFT)
	_add_key("look_left", KEY_LEFT)
	_add_key("look_right", KEY_RIGHT)
	_add_key("look_up", KEY_UP)
	_add_key("look_down", KEY_DOWN)
	_add_key("crouch", KEY_C)
	_add_key("interact", KEY_E)
	_add_key("restart", KEY_R)
	_add_key("vehicle_enter_exit", KEY_V)
	_add_key("load_checkpoint", KEY_L)
	_add_key("attack", KEY_F)
	_add_key("dodge", KEY_SPACE)
	_add_key("pause", KEY_ESCAPE)

static func _add_gamepad_defaults() -> void:
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_button("crouch", JOY_BUTTON_B)
	_add_button("interact", JOY_BUTTON_X)
	_add_button("restart", JOY_BUTTON_A)
	_add_button("vehicle_enter_exit", JOY_BUTTON_Y)
	_add_button("load_checkpoint", JOY_BUTTON_BACK)
	_add_button("attack", JOY_BUTTON_RIGHT_SHOULDER)
	_add_button("dodge", JOY_BUTTON_LEFT_SHOULDER)
	_add_button("pause", JOY_BUTTON_START)

static func _add_key(action_name: StringName, keycode: Key) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var input_event := InputEventKey.new()
	input_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, input_event)

static func _add_axis(action_name: StringName, axis: JoyAxis, value: float) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, value):
			return
	var input_event := InputEventJoypadMotion.new()
	input_event.axis = axis
	input_event.axis_value = value
	InputMap.action_add_event(action_name, input_event)

static func _add_button(action_name: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.button_index == button:
			return
	var input_event := InputEventJoypadButton.new()
	input_event.button_index = button
	InputMap.action_add_event(action_name, input_event)

extends SceneTree

const InputActionsClass = preload("res://scripts/input_actions.gd")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const PlayerClass = preload("res://scripts/player_controller.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	InputActionsClass.initialized = false
	InputActionsClass.ensure_defaults()

	for action_name in InputActionsClass.ACTIONS:
		assert(InputMap.has_action(action_name), "输入动作没有注册：%s" % action_name)

	_assert_key("move_left", KEY_A)
	_assert_key("move_right", KEY_D)
	_assert_key("move_forward", KEY_W)
	_assert_key("move_back", KEY_S)
	_assert_key("sprint", KEY_SHIFT)
	_assert_key("look_left", KEY_LEFT)
	_assert_key("look_right", KEY_RIGHT)
	_assert_key("look_up", KEY_UP)
	_assert_key("look_down", KEY_DOWN)
	_assert_key("crouch", KEY_C)
	_assert_key("interact", KEY_E)
	_assert_key("restart", KEY_R)
	_assert_key("vehicle_enter_exit", KEY_V)
	_assert_key("load_checkpoint", KEY_L)
	_assert_key("attack", KEY_F)
	_assert_key("dodge", KEY_SPACE)
	_assert_key("pause", KEY_ESCAPE)

	_assert_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_assert_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_assert_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_assert_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_assert_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_assert_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_assert_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_assert_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	for action_name in ["move_left", "move_right", "move_forward", "move_back", "look_left", "look_right", "look_up", "look_down"]:
		assert(is_equal_approx(InputMap.action_get_deadzone(action_name), InputActionsClass.GAMEPAD_DEADZONE), "手柄死区不一致：%s" % action_name)

	_assert_button("crouch", JOY_BUTTON_B)
	_assert_button("sprint", JOY_BUTTON_LEFT_STICK)
	_assert_button("interact", JOY_BUTTON_X)
	_assert_button("restart", JOY_BUTTON_A)
	_assert_button("vehicle_enter_exit", JOY_BUTTON_Y)
	_assert_button("load_checkpoint", JOY_BUTTON_BACK)
	_assert_button("attack", JOY_BUTTON_RIGHT_SHOULDER)
	_assert_button("dodge", JOY_BUTTON_LEFT_SHOULDER)
	_assert_button("pause", JOY_BUTTON_START)

	var valid_data := {
		"x": 0.5,
		"y": -0.5,
		"look_x": 12.0,
		"look_y": -8.0,
		"sprint": true,
		"crouch": false,
		"interact": true,
		"restart": false,
		"vehicle_enter_exit": false,
		"load_checkpoint": false,
		"attack": false,
		"dodge": false,
	}
	assert(InputFrameClass.validate_dict(valid_data).is_empty(), "有效输入帧被错误拒绝")
	var invalid_data := valid_data.duplicate(true)
	invalid_data["x"] = 2.0
	invalid_data["interact"] = "true"
	assert(not InputFrameClass.validate_dict(invalid_data).is_empty(), "越界或错误类型输入帧没有被拒绝")

	var sanitized := InputFrameClass.new()
	sanitized.move = Vector2(4.0, 0.0)
	sanitized.look = Vector2(999.0, 0.0)
	sanitized.sanitize()
	assert(is_equal_approx(sanitized.move.length(), InputFrameClass.MAX_MOVE_MAGNITUDE), "移动输入没有被限制到安全幅度")
	assert(is_equal_approx(sanitized.look.length(), InputFrameClass.MAX_LOOK_DELTA_PER_FRAME), "镜头输入没有被限制到安全幅度")

	var player := PlayerClass.new()
	player.controlled_externally = true
	get_root().add_child(player)
	var movement := InputFrameClass.new()
	movement.move = Vector2(0.0, -1.0)
	player.apply_input(movement, 0.016)
	var first_step_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(first_step_speed < player.walk_speed, "角色移动没有经过加速阶段")
	for acceleration_index in range(40):
		player.apply_input(movement, 0.016)
	var settled_walk_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert(settled_walk_speed > first_step_speed, "角色加速没有逐步建立")
	var walk_velocity := Vector2(player.velocity.x, player.velocity.z).length()
	movement.sprint = true
	player.apply_input(movement, 0.016)
	var sprint_velocity := Vector2(player.velocity.x, player.velocity.z).length()
	assert(sprint_velocity > walk_velocity, "冲刺输入没有提高玩家移动速度")
	assert(player.stamina < player.max_stamina, "冲刺没有消耗体力")
	movement.crouch = true
	player.apply_input(movement, 0.016)
	var crouch_velocity := Vector2(player.velocity.x, player.velocity.z).length()
	assert(crouch_velocity < sprint_velocity, "蹲伏时不应继续保持冲刺速度")
	assert(not player.sprinting, "蹲伏时玩家不应保持冲刺状态")
	var stamina_before_recovery := player.stamina
	movement.sprint = false
	movement.crouch = false
	movement.move = Vector2.ZERO
	var release_speed := Vector2(player.velocity.x, player.velocity.z).length()
	player.apply_input(movement, 0.016)
	assert(Vector2(player.velocity.x, player.velocity.z).length() < release_speed, "释放移动后角色没有进入刹停阶段")
	for recovery_index in range(40):
		player.apply_input(movement, 0.016)
	assert(player.stamina > stamina_before_recovery, "停止冲刺后体力没有恢复")
	player.stamina = 0.0
	movement.sprint = true
	player.apply_input(movement, 0.016)
	assert(not player.sprinting, "体力耗尽后不应继续冲刺")
	player.queue_free()

	print("输入动作与输入帧契约测试通过：键盘、手柄、死区、边界校验")
	quit(0)

func _assert_key(action_name: StringName, keycode: Key) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	assert(false, "键盘默认映射缺失：%s" % action_name)

func _assert_axis(action_name: StringName, axis: JoyAxis, axis_value: float) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.axis == axis and is_equal_approx(event.axis_value, axis_value):
			return
	assert(false, "手柄轴映射缺失：%s" % action_name)

func _assert_button(action_name: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.button_index == button:
			return
	assert(false, "手柄按钮映射缺失：%s" % action_name)

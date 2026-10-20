class_name InputFrame
extends RefCounted

const InputActionsClass = preload("res://scripts/input_actions.gd")
const MAX_MOVE_MAGNITUDE := 1.0
const MAX_LOOK_DELTA_PER_FRAME := 240.0

var move := Vector2.ZERO
var look := Vector2.ZERO
var sprint := false
var crouch := false
var interact := false
var restart := false
var vehicle_enter_exit := false
var load_checkpoint := false
var attack := false
var dodge := false

static func from_keyboard() -> InputFrame:
	InputActionsClass.ensure_defaults()
	var frame := InputFrame.new()
	frame.move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	frame.look = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	frame.sprint = Input.is_action_pressed("sprint")
	frame.crouch = Input.is_action_pressed("crouch")
	frame.interact = Input.is_action_pressed("interact")
	frame.restart = Input.is_action_pressed("restart")
	frame.vehicle_enter_exit = Input.is_action_pressed("vehicle_enter_exit")
	frame.load_checkpoint = Input.is_action_pressed("load_checkpoint")
	frame.attack = Input.is_action_pressed("attack")
	frame.dodge = Input.is_action_pressed("dodge")
	frame.sanitize()
	return frame

func sanitize() -> void:
	move = _sanitize_vector(move, MAX_MOVE_MAGNITUDE)
	look = _sanitize_vector(look, MAX_LOOK_DELTA_PER_FRAME)

func _sanitize_vector(value: Vector2, maximum_length: float) -> Vector2:
	if not is_finite(value.x) or not is_finite(value.y):
		return Vector2.ZERO
	return value.limit_length(maximum_length)

func to_dict() -> Dictionary:
	return {
		"x": move.x,
		"y": move.y,
		"look_x": look.x,
		"look_y": look.y,
		"sprint": sprint,
		"crouch": crouch,
		"interact": interact,
		"restart": restart,
		"vehicle_enter_exit": vehicle_enter_exit,
		"load_checkpoint": load_checkpoint,
		"attack": attack,
		"dodge": dodge
	}

static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field_name in ["x", "y", "look_x", "look_y"]:
		if not data.has(field_name):
			errors.append("输入帧缺少数值字段：%s" % field_name)
			continue
		var value = data.get(field_name)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			errors.append("输入帧数值字段无效：%s" % field_name)
	if errors.is_empty():
		var move_value := Vector2(float(data["x"]), float(data["y"]))
		var look_value := Vector2(float(data["look_x"]), float(data["look_y"]))
		if move_value.length() > MAX_MOVE_MAGNITUDE + 0.0001:
			errors.append("输入帧移动幅度超出上限")
		if look_value.length() > MAX_LOOK_DELTA_PER_FRAME + 0.0001:
			errors.append("输入帧镜头幅度超出上限")
	for field_name in ["crouch", "interact", "restart", "vehicle_enter_exit", "load_checkpoint", "attack", "dodge"]:
		if not data.has(field_name):
			errors.append("输入帧缺少布尔字段：%s" % field_name)
		elif typeof(data.get(field_name)) != TYPE_BOOL:
			errors.append("输入帧布尔字段无效：%s" % field_name)
	return errors

static func from_dict(data: Dictionary) -> InputFrame:
	var frame := InputFrame.new()
	frame.move = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	frame.look = Vector2(float(data.get("look_x", 0.0)), float(data.get("look_y", 0.0)))
	frame.sprint = bool(data.get("sprint", false))
	frame.crouch = bool(data.get("crouch", false))
	frame.interact = bool(data.get("interact", false))
	frame.restart = bool(data.get("restart", false))
	frame.vehicle_enter_exit = bool(data.get("vehicle_enter_exit", false))
	frame.load_checkpoint = bool(data.get("load_checkpoint", false))
	frame.attack = bool(data.get("attack", false))
	frame.dodge = bool(data.get("dodge", false))
	return frame

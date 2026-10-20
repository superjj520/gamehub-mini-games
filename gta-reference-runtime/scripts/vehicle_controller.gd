class_name ReferenceVehicle
extends CharacterBody3D

signal driver_changed(has_driver: bool)

@export var max_speed := 8.0
@export var acceleration := 10.0
@export var braking := 14.0
@export var turn_speed := 1.8
@export var enter_radius := 2.5
@export var driver_seat_offset := Vector3(0.0, 1.12, 0.18)

var driver: Node3D
var current_speed := 0.0
var steering_input := 0.0
var _driver_attached := false
var _driver_collision_shapes: Array[CollisionShape3D] = []
var _driver_collision_disabled_states: Array[bool] = []
var _driver_visible_before_enter := true

func can_enter(actor: Node3D) -> bool:
	_normalize_driver()
	if actor == null or not is_instance_valid(actor):
		return false
	return driver == null and _world_position().distance_to(_actor_world_position(actor)) <= enter_radius

func enter(actor: Node3D) -> bool:
	if not can_enter(actor):
		return false
	driver = actor
	_driver_attached = true
	_capture_and_disable_driver_collisions(actor)
	_driver_visible_before_enter = driver.visible
	driver.visible = true
	_attach_driver_to_seat()
	driver_changed.emit(true)
	return true

func exit() -> bool:
	if not _normalize_driver():
		return false
	_restore_driver_collisions()
	var exit_position := _world_position() + Vector3.RIGHT * 1.6 + Vector3.UP
	driver.visible = _driver_visible_before_enter
	if driver.is_inside_tree():
		driver.global_position = exit_position
	else:
		driver.position = exit_position
	driver.visible = true
	driver = null
	_driver_attached = false
	current_speed = 0.0
	steering_input = 0.0
	velocity = Vector3.ZERO
	driver_changed.emit(false)
	return true

func apply_input(frame: InputFrame, delta: float) -> void:
	if not _normalize_driver():
		return
	var throttle := -frame.move.y
	if absf(throttle) > 0.01:
		current_speed = move_toward(current_speed, throttle * max_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, braking * delta)
	steering_input = move_toward(steering_input, frame.move.x, 8.0 * delta)
	rotation.y -= frame.move.x * turn_speed * delta * clampf(absf(current_speed) / max_speed, 0.2, 1.0)
	velocity = -global_transform.basis.z * current_speed
	# 正常窗口运行处于物理帧内，保留 CharacterBody3D 的滑动碰撞；
	# 输入回放和集成测试可能在物理帧外直接注入 delta，此时使用传入
	# 的确定性步长，避免引擎内部帧间隔把车辆移动压缩成几毫米。
	if Engine.is_in_physics_frame():
		move_and_slide()
	else:
		move_and_collide(velocity * delta)
	_attach_driver_to_seat()

func snapshot() -> Dictionary:
	_normalize_driver()
	var snapshot_position := _world_position()
	var has_active_driver := _driver_attached and driver != null and is_instance_valid(driver)
	var contact_position_error := -1.0
	var contact_rotation_error := -1.0
	if has_active_driver:
		contact_position_error = driver.global_position.distance_to(driver_seat_position())
		contact_rotation_error = absf(wrapf(driver.global_rotation.y - global_rotation.y, -PI, PI))
	return {
		"position": {"x": snapshot_position.x, "y": snapshot_position.y, "z": snapshot_position.z},
		"rotation_y": rotation.y,
		"current_speed": current_speed,
		"steering_input": steering_input,
		"has_driver": has_active_driver,
		"driver_contact": {
			"position_error": contact_position_error,
			"rotation_error": contact_rotation_error,
			"seat_offset": {"x": driver_seat_offset.x, "y": driver_seat_offset.y, "z": driver_seat_offset.z}
		}
	}

func driver_seat_position() -> Vector3:
	if is_inside_tree():
		return to_global(driver_seat_offset)
	return position + transform.basis * driver_seat_offset

func restore_snapshot(data: Dictionary) -> void:
	var position_data = data.get("position", {})
	if position_data is Dictionary:
		global_position = Vector3(
			float(position_data.get("x", global_position.x)),
			float(position_data.get("y", global_position.y)),
			float(position_data.get("z", global_position.z))
		)
	rotation.y = float(data.get("rotation_y", rotation.y))
	current_speed = float(data.get("current_speed", 0.0))
	steering_input = clampf(float(data.get("steering_input", 0.0)), -1.0, 1.0)

func _world_position() -> Vector3:
	return global_position if is_inside_tree() else position

func _actor_world_position(actor: Node3D) -> Vector3:
	return actor.global_position if actor.is_inside_tree() else actor.position

func _normalize_driver() -> bool:
	if driver == null:
		_restore_driver_collisions()
		var was_attached := _driver_attached
		_driver_attached = false
		if was_attached:
			current_speed = 0.0
			steering_input = 0.0
			velocity = Vector3.ZERO
			driver_changed.emit(false)
		return false
	if is_instance_valid(driver):
		return true
	_restore_driver_collisions()
	driver = null
	_driver_attached = false
	current_speed = 0.0
	steering_input = 0.0
	velocity = Vector3.ZERO
	driver_changed.emit(false)
	return false

func _capture_and_disable_driver_collisions(actor: Node3D) -> void:
	_driver_collision_shapes.clear()
	_driver_collision_disabled_states.clear()
	for node in actor.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if shape == null:
			continue
		_driver_collision_shapes.append(shape)
		_driver_collision_disabled_states.append(shape.disabled)
		shape.disabled = true

func _restore_driver_collisions() -> void:
	for index in range(_driver_collision_shapes.size()):
		var shape := _driver_collision_shapes[index]
		if is_instance_valid(shape):
			shape.disabled = _driver_collision_disabled_states[index]
	_driver_collision_shapes.clear()
	_driver_collision_disabled_states.clear()

func _attach_driver_to_seat() -> void:
	if driver == null or not is_instance_valid(driver):
		return
	var seat_position := driver_seat_position()
	if driver.is_inside_tree():
		driver.global_position = seat_position
		driver.global_rotation = global_rotation
	else:
		driver.position = seat_position
		driver.rotation = rotation

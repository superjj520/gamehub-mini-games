extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office_a = OfficeScene.instantiate()
	var office_b = OfficeScene.instantiate()
	get_root().add_child(office_a)
	get_root().add_child(office_b)
	await process_frame
	var office_inputs := [
		{"move": Vector2(0.0, -1.0), "look": Vector2(8.0, -2.0)},
		{"move": Vector2(1.0, 0.0), "crouch": true},
		{"move": Vector2(0.0, 0.0), "look": Vector2(-4.0, 1.0)},
		{"move": Vector2(-1.0, 0.0)}
	]
	for input_data in office_inputs:
		var frame_a := _frame_from_data(input_data)
		var frame_b := _frame_from_data(input_data)
		office_a.process_input_frame(frame_a, 0.1)
		office_b.process_input_frame(frame_b, 0.1)
	assert(office_a.player.global_position.distance_to(office_b.player.global_position) < 0.0001, "办公室相同输入没有产生相同角色位置")
	assert(is_equal_approx(office_a.camera_rig.yaw_degrees, office_b.camera_rig.yaw_degrees), "办公室相同输入没有产生相同镜头角度")
	assert(office_a.mission.status == office_b.mission.status, "办公室相同输入没有产生相同任务状态")
	office_a.queue_free()
	office_b.queue_free()
	await process_frame

	var city_a = CityScene.instantiate()
	var city_b = CityScene.instantiate()
	get_root().add_child(city_a)
	get_root().add_child(city_b)
	await process_frame
	var city_inputs := [
		{"move": Vector2(0.0, -1.0), "look": Vector2(5.0, 0.0)},
		{"move": Vector2(1.0, 0.0)},
		{"move": Vector2(0.0, 1.0), "attack": true},
		{"move": Vector2(0.0, 0.0)}
	]
	for input_data in city_inputs:
		var frame_a := _frame_from_data(input_data)
		var frame_b := _frame_from_data(input_data)
		city_a.process_input_frame(frame_a, 0.1)
		city_b.process_input_frame(frame_b, 0.1)
	assert(city_a.player.global_position.distance_to(city_b.player.global_position) < 0.0001, "城市相同输入没有产生相同角色位置")
	assert(is_equal_approx(city_a.camera_rig.yaw_degrees, city_b.camera_rig.yaw_degrees), "城市相同输入没有产生相同镜头角度")
	assert(city_a.mission.current_index == city_b.mission.current_index, "城市相同输入没有产生相同任务阶段")
	assert(city_a.conflict.status == city_b.conflict.status, "城市相同输入没有产生相同冲突状态")
	city_a.queue_free()
	city_b.queue_free()
	await process_frame
	print("场景级确定性回放测试通过")
	quit(0)

func _frame_from_data(data: Dictionary) -> InputFrame:
	var frame := InputFrameClass.new()
	frame.move = data.get("move", Vector2.ZERO)
	frame.look = data.get("look", Vector2.ZERO)
	frame.crouch = bool(data.get("crouch", false))
	frame.attack = bool(data.get("attack", false))
	frame.dodge = bool(data.get("dodge", false))
	return frame

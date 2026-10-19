extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")
const SAMPLE_FRAMES := 300
const FRAME_DELTA := 1.0 / 60.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	print("城市节点计数：%d，行人：%d，交通车辆：%d" % [_count_nodes(city), city.pedestrians.size(), city.traffic_vehicles.size()])
	_measure(city, "完整城市")

	for pedestrian in city.pedestrians:
		pedestrian.set_physics_process(false)
		var visual: Node = pedestrian.get_node_or_null("Visual")
		if visual != null:
			visual.set_process(false)
	for traffic in city.traffic_vehicles:
		traffic.set_physics_process(false)
		var visual: Node = traffic.get_node_or_null("Visual")
		if visual != null:
			visual.set_process(false)
	_measure(city, "冻结人群与交通")

	var player_collision_layer: int = city.player.collision_layer
	var player_collision_mask: int = city.player.collision_mask
	city.player.collision_layer = 0
	city.player.collision_mask = 0
	_measure(city, "冻结人群交通并关闭主角碰撞")
	city.player.collision_layer = player_collision_layer
	city.player.collision_mask = player_collision_mask

	city.queue_free()
	await process_frame
	print("城市性能剖面完成；结果仅用于定位，不代表目标设备")
	quit(0)

func _measure(city: Node, label: String) -> void:
	var start := Time.get_ticks_usec()
	for _index in range(SAMPLE_FRAMES):
		city.process_input_frame(InputFrameClass.new(), FRAME_DELTA)
	var elapsed := float(Time.get_ticks_usec() - start) / 1000.0
	print("城市性能剖面：%s %d 帧逻辑耗时 %.2f 毫秒" % [label, SAMPLE_FRAMES, elapsed])

func _count_nodes(root: Node) -> int:
	var total := 1
	for child in root.get_children():
		total += _count_nodes(child)
	return total

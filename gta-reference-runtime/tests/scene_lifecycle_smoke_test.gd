extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _probe_scene(OfficeScene, false, "office-lifecycle")
	await _probe_scene(CityScene, false, "city-lifecycle")
	await _probe_scene(OfficeScene, true, "office-capture")
	await _probe_scene(CityScene, true, "city-capture")
	print("场景与单次截图生命周期探针通过")
	quit(0)

func _probe_scene(scene_resource: PackedScene, capture: bool, capture_id: String) -> void:
	var scene = scene_resource.instantiate()
	get_root().add_child(scene)
	await process_frame
	await process_frame
	scene.prepare_reference_capture(false)
	assert(scene.reference_capture_mode, "生命周期探针没有进入参考采集冻结态：" + capture_id)
	assert(scene.pause_overlay != null and scene.pause_overlay.input_locked, "参考采集没有锁定暂停菜单输入：" + capture_id)
	assert(scene.audio_events != null and not scene.audio_events.enabled, "参考采集没有静音场景音频：" + capture_id)
	var frozen_position: Vector3 = scene.player.global_position
	var frozen_yaw: float = float(scene.camera_rig.yaw_degrees)
	var frozen_event_count: int = scene.trace.events.size()
	var blocked_frame = preload("res://scripts/input_frame.gd").new()
	blocked_frame.move = Vector2(1.0, -1.0)
	blocked_frame.look = Vector2(40.0, -20.0)
	blocked_frame.attack = true
	scene.process_input_frame(blocked_frame, 1.0)
	assert(scene.player.global_position.distance_to(frozen_position) < 0.001, "冻结采集态仍允许输入移动：" + capture_id)
	assert(is_equal_approx(scene.camera_rig.yaw_degrees, frozen_yaw), "冻结采集态仍允许输入转镜头：" + capture_id)
	assert(scene.trace.events.size() == frozen_event_count, "冻结采集态仍记录输入事件：" + capture_id)
	var blocked_pause := InputEventAction.new()
	blocked_pause.action = "pause"
	blocked_pause.pressed = true
	scene.pause_overlay._unhandled_input(blocked_pause)
	assert(not scene.pause_overlay.visible and not paused, "冻结采集态仍允许暂停菜单输入：" + capture_id)
	if capture and DisplayServer.get_name() != "headless" and get_root().get_texture() != null:
		var capture_path := RuntimeCaptureClass.capture(get_root(), capture_id)
		assert(not capture_path.is_empty(), "生命周期探针截图没有生成：" + capture_id)
	scene.free()
	assert(not is_instance_valid(scene), "生命周期探针场景未立即释放：" + capture_id)
	await process_frame

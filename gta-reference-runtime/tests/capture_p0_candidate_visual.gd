extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		print("P0 候选视觉截图跳过：当前是无头渲染服务")
		quit(0)
		return
	var office = OfficeScene.instantiate()
	var catalog_path := OS.get_environment("P0_CANDIDATE_CATALOG_PATH").strip_edges()
	if catalog_path.is_empty():
		catalog_path = "res://tests/asset-runtime-catalog-override.json"
	office.set_meta("asset_catalog_path", catalog_path)
	office.set_meta("settings_path", OS.get_temp_dir().path_join("p0-candidate-preview-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(office)
	await process_frame
	await process_frame
	assert(office.initialized, "P0 候选办公室场景初始化失败")
	var scenario := OS.get_environment("P0_CANDIDATE_SCENARIO").strip_edges()
	if scenario == "office-06":
		office.hallway_npc.position = Vector3(7.0, 0.9, -4.5)
		office.player.position = office.hallway_npc.position + Vector3(0.0, 0.0, 1.0)
		office.camera_rig.set_orbit(90.0, -12.0)
	else:
		var crouch := InputFrameClass.new()
		crouch.crouch = true
		office.process_input_frame(crouch, 0.2)
	office.prepare_reference_capture(false)
	await process_frame
	await process_frame
	var capture_id := "p0-candidate-office-06" if scenario == "office-06" else "p0-candidate-office-01"
	var capture_path := RuntimeCaptureClass.capture(get_root(), capture_id)
	assert(not capture_path.is_empty(), "P0 候选视觉截图生成失败")
	var source_path := ProjectSettings.globalize_path(capture_path)
	var output_path := ProjectSettings.globalize_path("res://../reference-evidence/%s.png" % capture_id)
	assert(DirAccess.copy_absolute(source_path, output_path) == OK, "P0 候选视觉截图复制失败")
	print("P0 候选视觉截图已生成：", output_path)
	office.free()
	await process_frame
	quit(0)

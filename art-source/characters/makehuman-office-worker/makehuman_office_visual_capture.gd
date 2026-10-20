extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const RetouchScript = preload("res://makehuman_office_npc_retouch.gd")
const STATES := ["idle_default", "search_default", "alert_default"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		push_error("MakeHuman 候选视觉采集必须使用真实图形窗口")
		quit(1)
		return
	var output_dir := OS.get_environment("MAKEHUMAN_CAPTURE_DIR").strip_edges()
	if output_dir.is_empty():
		push_error("缺少 MAKEHUMAN_CAPTURE_DIR")
		quit(1)
		return
	var preserve_imported_materials := OS.get_environment("MAKEHUMAN_KEEP_IMPORTED_MATERIALS") == "1"
	var reference_office_materials := OS.get_environment("MAKEHUMAN_REFERENCE_OFFICE_MATERIALS") == "1"
	var use_elegant_suit_candidate := OS.get_environment("MAKEHUMAN_USE_ELEGANT_SUIT") == "1"
	var use_elegant_suit_skinned := OS.get_environment("MAKEHUMAN_USE_ELEGANT_SUIT_SKINNED") == "1"
	if reference_office_materials and not preserve_imported_materials:
		push_error("V3 参考服装模式必须同时启用保留导入材质")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	for state_name in STATES:
		await _capture_state(state_name, output_dir)
	print("MakeHuman 候选图形视觉证据已生成：", STATES.size(), " 张")
	quit(0)

func _capture_state(state_name: String, output_dir: String) -> void:
	var preserve_imported_materials := OS.get_environment("MAKEHUMAN_KEEP_IMPORTED_MATERIALS") == "1"
	var reference_office_materials := OS.get_environment("MAKEHUMAN_REFERENCE_OFFICE_MATERIALS") == "1"
	var use_elegant_suit_candidate := OS.get_environment("MAKEHUMAN_USE_ELEGANT_SUIT") == "1"
	var use_elegant_suit_skinned := OS.get_environment("MAKEHUMAN_USE_ELEGANT_SUIT_SKINNED") == "1"
	var office = OfficeScene.instantiate()
	get_root().add_child(office)
	await process_frame
	await process_frame
	if not office.initialized:
		push_error("办公室场景未完成初始化：" + state_name)
		quit(1)
		return
	var visual: Node = office.npc.get_node_or_null("Visual")
	if visual == null:
		push_error("办公室 NPC 缺少候选 Visual：" + state_name)
		quit(1)
		return
	visual.set_script(RetouchScript)
	visual.set_meta("preserve_imported_materials", preserve_imported_materials)
	visual.set_meta("reference_office_materials", reference_office_materials)
	visual.set_meta("use_elegant_suit_candidate", use_elegant_suit_candidate)
	visual.set_meta("use_elegant_suit_skinned", use_elegant_suit_skinned)
	visual.call("_ready")
	var player_visual := office.player.get_node_or_null("Visual") as Node3D
	if player_visual != null:
		player_visual.visible = false
	for item in office.player.find_children("*", "MeshInstance3D", true, false):
		var player_mesh := item as MeshInstance3D
		if player_mesh != null:
			player_mesh.visible = false
	if office.hallway_npc != null:
		office.hallway_npc.visible = false
	# 默认办公室 NPC 面向场景内侧；候选视觉验收需要固定正面，检查面部和正面服装。
	office.npc.rotation.y = 0.0
	var close_capture := OS.get_environment("MAKEHUMAN_CLOSE_CAPTURE") == "1"
	office.player.position = office.npc.position + Vector3(0.0, 0.0, 1.25 if close_capture else 1.65)
	office.player.rotation.y = 0.0
	office.prepare_reference_capture(false)
	office.camera_rig.set_follow_profile(1.30 if close_capture else 1.85, 1.48 if close_capture else 1.65)
	office.camera_rig.set_orbit(0.0, -8.0)
	visual.call("drive_candidate_state", state_name)
	visual.call("_process", 0.42)
	await process_frame
	await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("候选视觉截图为空：" + state_name)
		quit(1)
		return
	if not _has_graphical_signal(image):
		push_error("候选视觉截图黑屏、全透明或像素方差过低：" + state_name)
		quit(1)
		return
	var output_path := output_dir.path_join("makehuman-office-npc-%s.png" % state_name)
	if image.save_png(output_path) != OK:
		push_error("候选视觉截图写入失败：" + output_path)
		quit(1)
		return
	office.free()
	await process_frame

func _has_graphical_signal(image: Image) -> bool:
	var sample_step := 8
	var count := 0
	var brightness_sum := 0.0
	var brightness_square_sum := 0.0
	var max_brightness := 0.0
	var alpha_sum := 0.0
	for y in range(0, image.get_height(), sample_step):
		for x in range(0, image.get_width(), sample_step):
			var pixel := image.get_pixel(x, y)
			var brightness := (pixel.r + pixel.g + pixel.b) / 3.0
			brightness_sum += brightness
			brightness_square_sum += brightness * brightness
			max_brightness = maxf(max_brightness, brightness)
			alpha_sum += pixel.a
			count += 1
	if count == 0:
		return false
	var average := brightness_sum / count
	var variance := maxf(0.0, brightness_square_sum / count - average * average)
	return max_brightness > 0.03 and alpha_sum / count > 0.03 and variance > 0.0001

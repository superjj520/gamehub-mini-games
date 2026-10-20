extends SceneTree

const CompositionScene = preload("res://office_desk_composition.tscn")
const CaptureGuard = preload("res://candidate_capture_guard.gd")
const OUTPUT_DIR := "res://../../../reference-evidence/candidates/p0-office/"

var composition: Node
var capture_temp_root := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	composition = CompositionScene.instantiate()
	if composition == null:
		_fail("办公室候选组合场景实例化失败")
		return
	get_root().add_child(composition)
	for _frame in range(8):
		await process_frame
	if not is_instance_valid(composition):
		_fail("办公室候选组合场景在渲染前失效")
		return
	var camera := composition.get_node_or_null("固定审阅镜头") as Camera3D
	if camera == null or not camera.current:
		_fail("办公室候选组合场景没有有效的固定审阅镜头")
		return
	for _frame in range(2):
		await process_frame
	var viewport_texture := get_root().get_texture()
	if viewport_texture == null:
		_fail("Godot 根视口没有纹理")
		return
	var image := viewport_texture.get_image()
	var capture_name := CaptureGuard.safe_capture_name(OS.get_environment("P0_CAPTURE_NAME"), "office-desk-composition-runtime")
	if capture_name.is_empty():
		_fail("候选截图文件名非法")
		return
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + capture_name + ".png")
	var formal_identity := _formal_runtime_identity()
	if formal_identity == "unavailable":
		_fail("正式运行时源指纹不可用，拒绝提交候选截图")
		return
	var metadata := {
		"candidate_only": true,
		"visual_status": "unverified",
		"formal_acceptance": false,
		"scene": "isolated_office_desk_composition",
		"reference_frames": ["video-2/office-01.jpg", "video-2/office-06.jpg"],
		"renderer": DisplayServer.get_name(),
		"camera": {"name": camera.name, "current": camera.current, "position": [camera.global_position.x, camera.global_position.y, camera.global_position.z], "fov": camera.fov},
		"formal_runtime_source": formal_identity,
		"capture_script": "capture_office_desk_runtime.gd",
		"generated_at_utc": Time.get_datetime_string_from_system(true)
	}
	capture_temp_root = OS.get_temp_dir().path_join("office-desk-capture-preview-" + str(Time.get_ticks_usec()))
	var result: Dictionary = CaptureGuard.commit(image, output, metadata, capture_temp_root)
	if not bool(result.get("ok", false)):
		_fail("候选组合截图提交失败：%s" % str(result.get("reason", "unknown")))
		return
	print("办公室候选组合截图已生成：%s；元数据：%s" % [output, str(result.get("metadata_path", ""))])
	_finish(0)

func _formal_runtime_identity() -> String:
	var report_file := FileAccess.open("res://../../../docs/readiness-report.json", FileAccess.READ)
	if report_file == null:
		return "unavailable"
	var parsed = JSON.parse_string(report_file.get_as_text())
	report_file.close()
	if not parsed is Dictionary:
		return "unavailable"
	var identity: Dictionary = parsed.get("build_identity", {})
	var source_hash := str(identity.get("source_sha256", ""))
	var source_count := int(identity.get("source_file_count", 0))
	if source_hash.is_empty() or source_count <= 0:
		return "unavailable"
	return "%s files=%d" % [source_hash, source_count]

func _fail(message: String) -> void:
	push_error(message)
	_finish(1)

func _finish(code: int) -> void:
	if is_instance_valid(composition):
		composition.free()
		composition = null
	if not capture_temp_root.is_empty() and not CaptureGuard.remove_tree(capture_temp_root):
		push_error("候选组合截图临时目录清理失败：%s" % capture_temp_root)
		code = 1
	capture_temp_root = ""
	quit(code)

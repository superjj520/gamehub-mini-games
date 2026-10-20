extends SceneTree

const CaptureGuard = preload("res://candidate_capture_guard.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var black := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	black.fill(Color.BLACK)
	var black_result: Dictionary = CaptureGuard.assess_image(black)
	_expect(not bool(black_result.get("ok", false)), "全黑图像必须被拒绝")

	var varied := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	for y in range(varied.get_height()):
		for x in range(varied.get_width()):
			var shade := 0.18 + 0.68 * float(x) / float(varied.get_width())
			varied.set_pixel(x, y, Color(shade, 0.52, 0.38, 1.0))
	var varied_result: Dictionary = CaptureGuard.assess_image(varied)
	_expect(bool(varied_result.get("ok", false)), "有亮度变化的图像必须通过基础像素检查")

	_expect(CaptureGuard.safe_capture_name("office_close_01", "fallback") == "office_close_01", "合法截图文件名必须保留")
	_expect(CaptureGuard.safe_capture_name("../escape", "fallback").is_empty(), "路径穿越文件名必须被拒绝")
	_expect(CaptureGuard.safe_capture_name("带中文", "fallback").is_empty(), "非白名单文件名必须被拒绝")

	var test_root := OS.get_temp_dir().path_join("candidate-capture-guard-test-%d" % Time.get_ticks_usec())
	var output := test_root.path_join("result.png")
	var metadata := {"candidate_only": true, "visual_status": "unverified", "formal_acceptance": false}
	var commit_result: Dictionary = CaptureGuard.commit(varied, output, metadata, test_root.path_join("work"))
	_expect(bool(commit_result.get("ok", false)), "有效图像必须完成 PNG/JSON 成对提交")
	_expect(FileAccess.file_exists(output), "提交后 PNG 必须存在")
	var metadata_path := output.get_basename() + ".json"
	_expect(FileAccess.file_exists(metadata_path), "提交后 JSON 元数据必须存在")
	var metadata_payload = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	_expect(metadata_payload is Dictionary, "提交后的 JSON 必须可解析")
	if metadata_payload is Dictionary:
		_expect(bool(metadata_payload.get("candidate_only", false)), "元数据必须标记 candidate_only")
		_expect(str(metadata_payload.get("visual_status", "")) == "unverified", "元数据必须标记 unverified")
		_expect(not bool(metadata_payload.get("formal_acceptance", true)), "元数据必须禁止 formal_acceptance")
		_expect(str(metadata_payload.get("file_sha256", "")) == FileAccess.get_sha256(output), "元数据哈希必须匹配 PNG")
	var second_result: Dictionary = CaptureGuard.commit(varied, output, metadata, test_root.path_join("work-2"))
	_expect(not bool(second_result.get("ok", false)), "重复目标必须拒绝覆盖")
	var unsafe_metadata := metadata.duplicate(true)
	unsafe_metadata["formal_acceptance"] = true
	var unsafe_result: Dictionary = CaptureGuard.commit(varied, test_root.path_join("unsafe.png"), unsafe_metadata, test_root.path_join("work-3"))
	_expect(not bool(unsafe_result.get("ok", false)), "正式验收元数据必须被守护器拒绝")
	for failure_stage in ["before_png", "after_png", "before_png_commit", "after_png_commit"]:
		var failure_root := test_root.path_join("failure-" + failure_stage)
		var failure_output := failure_root.path_join("result.png")
		var failure_result: Dictionary = CaptureGuard.commit(varied, failure_output, metadata, failure_root.path_join("work"), failure_stage)
		_expect(not bool(failure_result.get("ok", false)), "故障注入必须失败：" + failure_stage)
		_expect(not FileAccess.file_exists(failure_output), "故障注入不能留下 PNG：" + failure_stage)
		_expect(not FileAccess.file_exists(failure_output.get_basename() + ".json"), "故障注入不能留下 JSON：" + failure_stage)
	var removed := CaptureGuard.remove_tree(test_root)
	_expect(removed and not DirAccess.dir_exists_absolute(test_root), "临时目录必须可验证地删除")
	if failures.is_empty():
		print("候选截图证据守护契约通过：黑屏拒绝、文件名边界、PNG/JSON 提交和拒绝覆盖均正常")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

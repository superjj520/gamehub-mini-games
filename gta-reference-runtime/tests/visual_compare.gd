extends SceneTree

const EXACT_TOLERANCE := 0
const ACCEPTANCE_TOLERANCE := 8

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("用法：godot --headless --path gta-reference-runtime -s res://tests/visual_compare.gd -- 参考帧.png 运行时截图.png 报告.json")
		quit(2)
		return
	var reference_path := args[0]
	var candidate_path := args[1]
	var report_path := args[2]
	var reference := Image.load_from_file(reference_path)
	var candidate := Image.load_from_file(candidate_path)
	if reference == null or reference.is_empty():
		printerr("无法读取参考帧：" + reference_path)
		quit(2)
		return
	if candidate == null or candidate.is_empty():
		printerr("无法读取运行时截图：" + candidate_path)
		quit(2)
		return

	var source_size := Vector2i(candidate.get_width(), candidate.get_height())
	var target_size := Vector2i(reference.get_width(), reference.get_height())
	if candidate.get_width() != reference.get_width() or candidate.get_height() != reference.get_height():
		candidate.resize(reference.get_width(), reference.get_height(), Image.INTERPOLATE_LANCZOS)

	var pixel_count := reference.get_width() * reference.get_height()
	var exact_match_count := 0
	var tolerance_match_count := 0
	var total_error := 0.0
	var max_error := 0
	for y in range(reference.get_height()):
		for x in range(reference.get_width()):
			var expected := reference.get_pixel(x, y)
			var actual := candidate.get_pixel(x, y)
			var channel_error := maxi(absi(roundi(expected.r * 255.0) - roundi(actual.r * 255.0)), absi(roundi(expected.g * 255.0) - roundi(actual.g * 255.0)))
			channel_error = maxi(channel_error, absi(roundi(expected.b * 255.0) - roundi(actual.b * 255.0)))
			total_error += float(channel_error)
			max_error = maxi(max_error, channel_error)
			if channel_error <= EXACT_TOLERANCE:
				exact_match_count += 1
			if channel_error <= ACCEPTANCE_TOLERANCE:
				tolerance_match_count += 1

	var report := {
		"version": 1,
		"visual_status": "unverified",
		"decision": "工具只产生对照指标，不自动批准视觉还原；必须由人工逐项复核参考帧与运行时截图",
		"reference_path": _portable_path(reference_path),
		"candidate_path": _portable_path(candidate_path),
		"reference_size": [target_size.x, target_size.y],
		"candidate_source_size": [source_size.x, source_size.y],
		"comparison_size": [target_size.x, target_size.y],
		"exact_pixel_ratio": float(exact_match_count) / float(pixel_count),
		"within_8_level_ratio": float(tolerance_match_count) / float(pixel_count),
		"mean_absolute_channel_error": total_error / float(pixel_count),
		"max_channel_error": max_error,
		"reference_sha256": _sha256(reference_path),
		"candidate_sha256": _sha256(candidate_path)
	}
	var absolute_report_path := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute_report_path.get_base_dir())
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		printerr("无法写入视觉对照报告：" + report_path)
		quit(2)
		return
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("视觉对照报告已生成：", report_path, "；视觉状态保持 unverified")
	quit(0)

func _sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func _portable_path(path: String) -> String:
	var project_root := ProjectSettings.globalize_path("res://").simplify_path()
	var workspace_root := project_root.get_base_dir().simplify_path()
	var normalized := path.simplify_path()
	if normalized.begins_with(workspace_root + "/"):
		return normalized.trim_prefix(workspace_root + "/")
	return normalized

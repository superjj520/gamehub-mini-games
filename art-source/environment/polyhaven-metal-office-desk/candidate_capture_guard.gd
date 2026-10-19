class_name CandidateCaptureGuard
extends RefCounted

const MAX_CAPTURE_NAME_LENGTH := 64

static func safe_capture_name(raw_name: String, fallback: String) -> String:
	var name := raw_name.strip_edges()
	if name.is_empty():
		name = fallback
	if name.length() > MAX_CAPTURE_NAME_LENGTH or name == "." or name == "..":
		return ""
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]+$")
	if pattern.search(name) == null:
		return ""
	return name

static func assess_image(image: Image) -> Dictionary:
	if image == null or image.is_empty():
		return {"ok": false, "reason": "image_empty"}
	if image.get_width() < 640 or image.get_height() < 360:
		return {"ok": false, "reason": "resolution_too_low"}
	var step := 2
	var sample_count := 0
	var bright_count := 0
	var luminance_sum := 0.0
	var luminance_square_sum := 0.0
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var pixel := image.get_pixel(x, y)
			var luminance := pixel.r * 0.2126 + pixel.g * 0.7152 + pixel.b * 0.0722
			luminance_sum += luminance
			luminance_square_sum += luminance * luminance
			if luminance > 0.03:
				bright_count += 1
			sample_count += 1
	if sample_count == 0:
		return {"ok": false, "reason": "no_samples"}
	var mean := luminance_sum / sample_count
	var variance := maxf(0.0, luminance_square_sum / sample_count - mean * mean)
	var bright_ratio := float(bright_count) / sample_count
	if bright_ratio < 0.01 or variance < 0.0005:
		return {"ok": false, "reason": "black_or_flat_image", "mean": mean, "variance": variance, "bright_ratio": bright_ratio}
	return {"ok": true, "mean": mean, "variance": variance, "bright_ratio": bright_ratio}

static func commit(image: Image, output_path: String, metadata: Dictionary, temp_root: String, failure_stage: String = "") -> Dictionary:
	var assessment := assess_image(image)
	if not bool(assessment.get("ok", false)):
		return assessment
	for required in {"candidate_only": true, "visual_status": "unverified", "formal_acceptance": false}:
		if metadata.get(required, null) != {"candidate_only": true, "visual_status": "unverified", "formal_acceptance": false}[required]:
			return {"ok": false, "reason": "candidate_metadata_policy_violation"}
	var metadata_path := output_path.get_basename() + ".json"
	if FileAccess.file_exists(output_path) or FileAccess.file_exists(metadata_path):
		return {"ok": false, "reason": "destination_exists"}
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(temp_root)
	var temp_png := temp_root.path_join("candidate-capture.png")
	var temp_json := temp_root.path_join("candidate-capture.json")
	if failure_stage == "before_png":
		return {"ok": false, "reason": "injected_png_failure"}
	if image.save_png(temp_png) != OK:
		return {"ok": false, "reason": "png_write_failed"}
	if failure_stage == "after_png":
		DirAccess.remove_absolute(temp_png)
		return {"ok": false, "reason": "injected_after_png_failure"}
	var enriched := metadata.duplicate(true)
	enriched["viewport"] = [image.get_width(), image.get_height()]
	enriched["image_quality"] = assessment
	enriched["file_sha256"] = FileAccess.get_sha256(temp_png)
	var metadata_file := FileAccess.open(temp_json, FileAccess.WRITE)
	if metadata_file == null:
		DirAccess.remove_absolute(temp_png)
		return {"ok": false, "reason": "metadata_open_failed"}
	metadata_file.store_string(JSON.stringify(enriched, "  "))
	var metadata_error := metadata_file.get_error()
	metadata_file.close()
	if metadata_error != OK:
		DirAccess.remove_absolute(temp_png)
		DirAccess.remove_absolute(temp_json)
		return {"ok": false, "reason": "metadata_write_failed"}
	if failure_stage == "before_png_commit":
		DirAccess.remove_absolute(temp_png)
		DirAccess.remove_absolute(temp_json)
		return {"ok": false, "reason": "injected_png_commit_failure"}
	if DirAccess.rename_absolute(temp_png, output_path) != OK:
		DirAccess.remove_absolute(temp_png)
		DirAccess.remove_absolute(temp_json)
		return {"ok": false, "reason": "png_commit_failed"}
	if failure_stage == "after_png_commit":
		DirAccess.remove_absolute(output_path)
		DirAccess.remove_absolute(temp_json)
		return {"ok": false, "reason": "injected_metadata_commit_failure"}
	if DirAccess.rename_absolute(temp_json, metadata_path) != OK:
		DirAccess.remove_absolute(output_path)
		DirAccess.remove_absolute(temp_json)
		return {"ok": false, "reason": "metadata_commit_failed"}
	return {"ok": true, "metadata_path": metadata_path, "quality": assessment, "sha256": enriched["file_sha256"]}

static func remove_tree(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	var removed := true
	for file_name in directory.get_files():
		if directory.remove(file_name) != OK:
			removed = false
	for directory_name in directory.get_directories():
		if not remove_tree(path.path_join(directory_name)):
			removed = false
	if DirAccess.remove_absolute(path) != OK:
		removed = false
	return removed and not DirAccess.dir_exists_absolute(path)

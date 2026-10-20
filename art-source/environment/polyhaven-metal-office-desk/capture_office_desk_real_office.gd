extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CaptureGuard = preload("res://candidate_capture_guard.gd")
const OUTPUT_DIR := "res://../../../reference-evidence/candidates/p0-office/"
const USER_ARTIFACTS := ["reference_last_replay.json", "office_last_trace.json"]

var office: Node
var temp_root := ""
var user_artifact_backups: Dictionary = {}
var restore_failed := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture_id := str(Time.get_ticks_usec())
	temp_root = OS.get_temp_dir().path_join("office-desk-capture-" + capture_id)
	DirAccess.make_dir_recursive_absolute(temp_root)
	_backup_user_artifacts()
	if restore_failed:
		_fail("候选截图开始前无法可靠备份 user:// 文件，已停止捕获")
		return
	office = OfficeScene.instantiate()
	if office == null:
		_fail("办公室候选真实运行时实例化失败")
		return
	var catalog_path := OS.get_environment("P0_CANDIDATE_CATALOG").strip_edges()
	if catalog_path.is_empty():
		catalog_path = "res://asset-runtime-catalog-office-desk-override.json"
	var full_kit := catalog_path.ends_with("asset-runtime-catalog-office-full-kit-override.json")
	office.set_meta("asset_catalog_path", catalog_path)
	office.set_meta("settings_path", temp_root.path_join("settings.json"))
	office.set_meta("save_path", temp_root.path_join("checkpoint.json"))
	get_root().add_child(office)
	for _frame in range(8):
		await process_frame
	if not is_instance_valid(office) or not bool(office.get("initialized")):
		_fail("办公室候选真实运行时没有初始化")
		return
	var candidate_visual := office.get_node_or_null("Visual")
	if candidate_visual == null:
		_fail("候选办公桌没有挂载到 office-environment-kit")
		return
	if office.get_node_or_null("办公室环境灰盒回退") != null:
		_fail("候选办公桌挂载失败，运行时仍保留灰盒回退")
		return
	var candidate_script: Script = candidate_visual.get_script()
	if candidate_script == null:
		_fail("办公室环境节点没有候选脚本")
		return
	if full_kit:
		if not str(candidate_script.resource_path).ends_with("office_desk_composition.gd"):
			_fail("办公室环境节点不是 Poly Haven 五工位组合候选场景")
			return
		if candidate_visual.find_children("*", "StaticBody3D", true, false).size() < 5:
			_fail("Poly Haven 五工位组合候选数量不足")
			return
	else:
		if not str(candidate_script.resource_path).ends_with("office_desk_candidate.gd"):
			_fail("办公室环境节点不是 Poly Haven 办公桌候选场景")
			return
		if candidate_visual.get_node_or_null("近似碰撞体") == null or candidate_visual.get_node_or_null("交互挂点") == null:
			_fail("候选办公桌缺少碰撞体或交互挂点")
			return
	office.prepare_reference_capture(false)
	var runtime_camera := office.get_node_or_null("玩家/第三人称镜头/第三人称相机") as Camera3D
	if runtime_camera == null or not runtime_camera.current:
		_fail("办公室候选真实运行时没有第三人称镜头")
		return
	for _frame in range(4):
		await process_frame
	for _frame in range(2):
		await process_frame
	var viewport_texture := get_root().get_texture()
	if viewport_texture == null:
		_fail("办公室候选真实运行时根视口没有纹理")
		return
	var image := viewport_texture.get_image()
	var capture_name := CaptureGuard.safe_capture_name(OS.get_environment("P0_CAPTURE_NAME"), ("office-full-kit-real-office-runtime-" if full_kit else "office-desk-real-office-runtime-") + str(Time.get_ticks_usec()))
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
		"scene": "formal_office_runtime_candidate_override",
		"reference_frames": ["video-2/office-01.jpg", "video-2/office-06.jpg"],
		"candidate_scene": "res://office_desk_composition.tscn" if full_kit else "res://office_desk_candidate.tscn",
		"candidate_catalog": catalog_path,
		"full_kit": full_kit,
		"candidate_mount_verified": true,
		"fallback_present": false,
		"third_person_camera_ready": true,
		"camera": {"name": runtime_camera.name, "current": runtime_camera.current, "position": [runtime_camera.global_position.x, runtime_camera.global_position.y, runtime_camera.global_position.z], "fov": runtime_camera.fov},
		"renderer": DisplayServer.get_name(),
		"formal_runtime_source": formal_identity,
		"capture_script": "capture_office_desk_real_office.gd",
		"generated_at_utc": Time.get_datetime_string_from_system(true)
	}
	var result: Dictionary = CaptureGuard.commit(image, output, metadata, temp_root)
	if not bool(result.get("ok", false)):
		_fail("办公室候选真实运行时截图提交失败：%s" % str(result.get("reason", "unknown")))
		return
	print("办公室候选真实运行时截图已生成：%s；元数据：%s" % [output, str(result.get("metadata_path", ""))])
	_finish(0)

func _backup_user_artifacts() -> void:
	for file_name in USER_ARTIFACTS:
		var absolute_path := ProjectSettings.globalize_path("user://" + file_name)
		var exists := FileAccess.file_exists(absolute_path)
		var record := {"path": absolute_path, "exists": exists}
		if exists:
			var source_hash := FileAccess.get_sha256(absolute_path)
			var backup_path := temp_root.path_join("user-backup-" + file_name)
			var backup_file := FileAccess.open(backup_path, FileAccess.WRITE)
			if backup_file == null:
				restore_failed = true
			else:
				backup_file.store_buffer(FileAccess.get_file_as_bytes(absolute_path))
				var backup_error := backup_file.get_error()
				backup_file.close()
				record["backup_path"] = backup_path
				record["sha256"] = source_hash
				var trusted_backup := backup_error == OK and not source_hash.is_empty() and FileAccess.get_sha256(backup_path) == source_hash
				record["trusted"] = trusted_backup
				if not trusted_backup:
					restore_failed = true
		user_artifact_backups[file_name] = record

func _restore_user_artifacts() -> void:
	for file_name in USER_ARTIFACTS:
		var record: Dictionary = user_artifact_backups.get(file_name, {})
		var absolute_path := str(record.get("path", ProjectSettings.globalize_path("user://" + file_name)))
		if bool(record.get("exists", false)):
			if not bool(record.get("trusted", false)):
				restore_failed = true
				continue
			var backup_path := str(record.get("backup_path", ""))
			if backup_path.is_empty() or not FileAccess.file_exists(backup_path):
				restore_failed = true
				continue
			var restored := FileAccess.open(absolute_path, FileAccess.WRITE)
			if restored != null:
				restored.store_buffer(FileAccess.get_file_as_bytes(backup_path))
				restored.close()
				if FileAccess.get_sha256(absolute_path) != str(record.get("sha256", "")):
					restore_failed = true
			else:
				restore_failed = true
		elif FileAccess.file_exists(absolute_path):
			if DirAccess.remove_absolute(absolute_path) != OK or FileAccess.file_exists(absolute_path):
				restore_failed = true

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
	if is_instance_valid(office):
		office.free()
		office = null
	_restore_user_artifacts()
	if not temp_root.is_empty():
		if not CaptureGuard.remove_tree(temp_root):
			push_error("办公室候选真实运行时临时目录清理失败：%s" % temp_root)
			code = 1
		temp_root = ""
	if restore_failed:
		push_error("候选截图捕获结束时恢复 user:// 文件失败")
		code = 1
	quit(code)

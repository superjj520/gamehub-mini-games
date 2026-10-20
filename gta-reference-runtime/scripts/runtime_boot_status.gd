class_name RuntimeBootStatus
extends RefCounted

static func write(status: String, scene_id: String, detail := "") -> void:
	var path := OS.get_environment("REFERENCE_BOOT_STATUS_PATH").strip_edges()
	if path.is_empty():
		return
	var absolute_path := path if path.begins_with("/") else ProjectSettings.globalize_path(path)
	var parent := absolute_path.get_base_dir()
	if not parent.is_empty():
		DirAccess.make_dir_recursive_absolute(parent)
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"status": status,
		"scene": scene_id,
		"detail": detail,
		"pid": OS.get_process_id(),
		"timestamp_usec": Time.get_ticks_usec(),
	}))
	file.flush()
	file.close()


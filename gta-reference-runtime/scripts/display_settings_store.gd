class_name DisplaySettingsStore
extends RefCounted

const CURRENT_VERSION := 1
const DEFAULT_MODE := "windowed"
const DEFAULT_WIDTH := 1280
const DEFAULT_HEIGHT := 720
const ALLOWED_MODES := ["windowed", "fullscreen"]
const ALLOWED_RESOLUTIONS := [
	{"width": 960, "height": 540},
	{"width": 1280, "height": 720},
	{"width": 1920, "height": 1080},
]

var settings_path: String
var last_error := ""

func _init(path := "user://reference_display_settings.json") -> void:
	settings_path = path

func load_settings() -> Dictionary:
	last_error = ""
	var primary := _read_payload(settings_path)
	if _validate_payload(primary):
		return _settings_from_payload(primary)
	var backup_path := settings_path + ".bak"
	if FileAccess.file_exists(backup_path):
		var backup := _read_payload(backup_path)
		if _validate_payload(backup):
			last_error = "显示设置主档无效，已从备份恢复"
			return _settings_from_payload(backup)
		last_error = "显示设置主档和备份均无效，已回退默认值"
	elif FileAccess.file_exists(settings_path):
		last_error = "显示设置格式无效，已回退默认值"
	return _defaults()

func save_settings(mode: String, width: int, height: int) -> bool:
	last_error = ""
	if not ALLOWED_MODES.has(mode):
		last_error = "显示模式无效"
		return false
	if not _is_allowed_resolution(width, height):
		last_error = "分辨率不在支持清单中"
		return false
	var payload := {
		"version": CURRENT_VERSION,
		"display": {
			"mode": mode,
			"width": width,
			"height": height,
		},
	}
	return _write_transaction(payload)

func apply_settings(settings: Dictionary) -> bool:
	if not _validate_settings(settings):
		last_error = "显示设置无法应用"
		return false
	if DisplayServer.get_name() == "headless":
		return true
	var mode := DisplayServer.WINDOW_MODE_WINDOWED if str(settings.get("mode", DEFAULT_MODE)) == "windowed" else DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(int(settings.get("width", DEFAULT_WIDTH)), int(settings.get("height", DEFAULT_HEIGHT))))
	return true

func _defaults() -> Dictionary:
	return {"mode": DEFAULT_MODE, "width": DEFAULT_WIDTH, "height": DEFAULT_HEIGHT}

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var payload = JSON.parse_string(file.get_as_text())
	file.close()
	return payload if payload is Dictionary else {}

func _validate_payload(payload: Dictionary) -> bool:
	if not _is_integer(payload.get("version", null)) or int(payload["version"]) != CURRENT_VERSION:
		return false
	return _validate_settings(payload.get("display", {}))

func _validate_settings(settings) -> bool:
	if not settings is Dictionary:
		return false
	var mode := str(settings.get("mode", ""))
	var width: Variant = settings.get("width", null)
	var height: Variant = settings.get("height", null)
	return ALLOWED_MODES.has(mode) and _is_integer(width) and _is_integer(height) and _is_allowed_resolution(int(width), int(height))

func _settings_from_payload(payload: Dictionary) -> Dictionary:
	var display: Dictionary = payload["display"]
	return {"mode": str(display["mode"]), "width": int(display["width"]), "height": int(display["height"])}

func _is_allowed_resolution(width: int, height: int) -> bool:
	for resolution in ALLOWED_RESOLUTIONS:
		if int(resolution["width"]) == width and int(resolution["height"]) == height:
			return true
	return false

func _write_transaction(payload: Dictionary) -> bool:
	var temporary_path := settings_path + ".tmp"
	var backup_path := settings_path + ".bak"
	var previous_backup_path := backup_path + ".previous"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "无法打开临时显示设置文件"
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
	if FileAccess.file_exists(previous_backup_path):
		DirAccess.remove_absolute(previous_backup_path)
	if FileAccess.file_exists(backup_path) and DirAccess.rename_absolute(backup_path, previous_backup_path) != OK:
		last_error = "无法暂存旧显示设置备份"
		return false
	if FileAccess.file_exists(settings_path) and DirAccess.rename_absolute(settings_path, backup_path) != OK:
		if FileAccess.file_exists(previous_backup_path):
			DirAccess.rename_absolute(previous_backup_path, backup_path)
		last_error = "无法创建显示设置备份"
		return false
	if DirAccess.rename_absolute(temporary_path, settings_path) != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(settings_path):
			DirAccess.rename_absolute(backup_path, settings_path)
		if FileAccess.file_exists(previous_backup_path) and not FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(previous_backup_path, backup_path)
		last_error = "无法提交显示设置"
		return false
	if FileAccess.file_exists(previous_backup_path):
		DirAccess.remove_absolute(previous_backup_path)
	return true

func _is_integer(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and is_equal_approx(float(value), round(float(value)))

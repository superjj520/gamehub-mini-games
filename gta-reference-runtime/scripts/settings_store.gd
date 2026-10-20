class_name SettingsStore
extends RefCounted

const CURRENT_VERSION := 1
const DEFAULT_AUDIO_ENABLED := false
const DEFAULT_MASTER_VOLUME_DB := -14.0

var settings_path: String
var last_error := ""

func _init(path := "user://reference_settings.json") -> void:
	settings_path = path

func load_audio_settings() -> Dictionary:
	last_error = ""
	var primary_payload := _read_payload(settings_path)
	if _validate_payload(primary_payload):
		return _settings_from_payload(primary_payload)
	var backup_path := settings_path + ".bak"
	if FileAccess.file_exists(backup_path):
		var backup_payload := _read_payload(backup_path)
		if _validate_payload(backup_payload):
			last_error = "主设置无效，已从备份恢复"
			return _settings_from_payload(backup_payload)
		last_error = "设置主档和备份均无效，已回退默认值"
	elif FileAccess.file_exists(settings_path):
		last_error = "设置格式无效，已回退默认值"
	return _defaults()

func save_audio_settings(enabled: bool, master_volume_db: float) -> bool:
	last_error = ""
	if not is_finite(master_volume_db) or master_volume_db < -40.0 or master_volume_db > 0.0:
		last_error = "音频主音量必须是 -40 到 0 之间的有限数值"
		return false
	var payload := {
		"version": CURRENT_VERSION,
		"audio": {
			"enabled": enabled,
			"master_volume_db": clampf(master_volume_db, -40.0, 0.0)
		}
	}
	var temporary_path := settings_path + ".tmp"
	var backup_path := settings_path + ".bak"
	var previous_backup_path := backup_path + ".previous"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "无法打开临时设置文件"
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
	file = null
	if FileAccess.file_exists(previous_backup_path):
		DirAccess.remove_absolute(previous_backup_path)
	if FileAccess.file_exists(backup_path):
		if DirAccess.rename_absolute(backup_path, previous_backup_path) != OK:
			last_error = "无法暂存旧设置备份"
			return false
	if FileAccess.file_exists(settings_path):
		if DirAccess.rename_absolute(settings_path, backup_path) != OK:
			if FileAccess.file_exists(previous_backup_path):
				DirAccess.rename_absolute(previous_backup_path, backup_path)
			last_error = "无法创建设置备份"
			return false
	if DirAccess.rename_absolute(temporary_path, settings_path) != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(settings_path):
			DirAccess.rename_absolute(backup_path, settings_path)
		if FileAccess.file_exists(previous_backup_path) and not FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(previous_backup_path, backup_path)
		last_error = "无法提交设置文件"
		return false
	if FileAccess.file_exists(previous_backup_path):
		DirAccess.remove_absolute(previous_backup_path)
	return true

func _defaults() -> Dictionary:
	return {"enabled": DEFAULT_AUDIO_ENABLED, "master_volume_db": DEFAULT_MASTER_VOLUME_DB}

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw_text := file.get_as_text()
	file.close()
	file = null
	var version_regex := RegEx.new()
	version_regex.compile("\\\"version\\\"\\s*:\\s*([^,}\\s]+)")
	var version_match := version_regex.search(raw_text)
	if version_match == null or not version_match.get_string(1).is_valid_int():
		return {}
	var payload = JSON.parse_string(raw_text)
	if not payload is Dictionary:
		return {}
	if not _is_integer(payload.get("version", null)) or int(payload["version"]) != CURRENT_VERSION:
		return {}
	return payload

func _settings_from_payload(payload: Dictionary) -> Dictionary:
	var audio: Dictionary = payload["audio"]
	return {
		"enabled": audio["enabled"],
		"master_volume_db": clampf(float(audio["master_volume_db"]), -40.0, 0.0)
	}

func _validate_payload(payload: Dictionary) -> bool:
	if not _is_integer(payload.get("version", null)) or int(payload["version"]) != CURRENT_VERSION:
		return false
	var audio = payload.get("audio", null)
	if not audio is Dictionary:
		return false
	if not audio.has("enabled") or typeof(audio["enabled"]) != TYPE_BOOL:
		return false
	if not audio.has("master_volume_db") or not _is_number(audio["master_volume_db"]):
		return false
	return float(audio["master_volume_db"]) >= -40.0 and float(audio["master_volume_db"]) <= 0.0

func _is_integer(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and is_equal_approx(float(value), round(float(value)))

func _is_number(value) -> bool:
	var value_type := typeof(value)
	if value_type == TYPE_INT:
		return true
	return value_type == TYPE_FLOAT and is_finite(float(value))

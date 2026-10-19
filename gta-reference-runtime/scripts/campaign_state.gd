extends Node

const CURRENT_VERSION := 1

var state_path := "user://reference_campaign.json"
var office_completed := false
var city_unlocked := false
var city_completed := false
var office_reward := 0
var office_stars := 0
var money := 0
var stars := 0
var last_scene := ""
var last_error := ""

func _ready() -> void:
	var environment_path := OS.get_environment("REFERENCE_CAMPAIGN_STATE_PATH").strip_edges()
	if not environment_path.is_empty():
		state_path = environment_path
	load_state()

func configure_path(path: String) -> void:
	state_path = path.strip_edges()
	if state_path.is_empty():
		state_path = "user://reference_campaign.json"
	load_state()

func load_state() -> bool:
	_reset_memory()
	last_error = ""
	if not FileAccess.file_exists(state_path):
		return true
	var file := FileAccess.open(state_path, FileAccess.READ)
	if file == null:
		last_error = "无法读取战役状态文件"
		return false
	var payload = JSON.parse_string(file.get_as_text())
	file.close()
	if not payload is Dictionary:
		last_error = "战役状态文件格式无效"
		return false
	if int(payload.get("version", 0)) > CURRENT_VERSION:
		last_error = "战役状态版本过新"
		return false
	office_completed = bool(payload.get("office_completed", false))
	city_unlocked = bool(payload.get("city_unlocked", office_completed)) or office_completed
	city_completed = bool(payload.get("city_completed", false))
	office_reward = maxi(int(payload.get("office_reward", 0)), 0)
	office_stars = clampi(int(payload.get("office_stars", 0)), 0, 5)
	money = maxi(int(payload.get("money", office_reward)), 0)
	stars = clampi(int(payload.get("stars", office_stars)), 0, 5)
	last_scene = str(payload.get("last_scene", ""))
	return true

func mark_scene_started(scene_id: String) -> bool:
	last_scene = scene_id.strip_edges()
	return save_state()

func mark_office_completed(payload: Dictionary = {}) -> bool:
	office_completed = true
	city_unlocked = true
	office_reward = maxi(int(payload.get("money", payload.get("reward", 0))), 0)
	office_stars = clampi(int(payload.get("stars", 0)), 0, 5)
	money = maxi(int(payload.get("money", office_reward)), 0)
	stars = clampi(int(payload.get("stars", office_stars)), 0, 5)
	last_scene = "office"
	return save_state()

func mark_city_completed(payload: Dictionary = {}) -> bool:
	city_unlocked = true
	city_completed = true
	money = maxi(int(payload.get("money", money)), 0)
	stars = clampi(int(payload.get("stars", stars)), 0, 5)
	last_scene = "city"
	return save_state()

func is_city_unlocked() -> bool:
	return city_unlocked or office_completed

func snapshot() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"office_completed": office_completed,
		"city_unlocked": is_city_unlocked(),
		"city_completed": city_completed,
		"office_reward": office_reward,
		"office_stars": office_stars,
		"money": money,
		"stars": stars,
		"last_scene": last_scene
	}

func save_state() -> bool:
	last_error = ""
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入战役状态文件"
		return false
	file.store_string(JSON.stringify(snapshot(), "\t"))
	file.flush()
	file.close()
	return true

func reset() -> bool:
	_reset_memory()
	last_error = ""
	if not FileAccess.file_exists(state_path):
		return true
	var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	if result != OK and FileAccess.file_exists(state_path):
		last_error = "无法删除战役状态文件"
		return false
	return true

func _reset_memory() -> void:
	office_completed = false
	city_unlocked = false
	city_completed = false
	office_reward = 0
	office_stars = 0
	money = 0
	stars = 0
	last_scene = ""

extends Node

const CURRENT_VERSION := 1

signal session_opened(recovered_previous_session: bool)

var marker_path := "user://reference_session.json"
var recovered_previous_session := false
var session_started := false

func _ready() -> void:
	var environment_path := OS.get_environment("REFERENCE_SESSION_MARKER_PATH").strip_edges()
	if not environment_path.is_empty():
		marker_path = environment_path
	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_start_if_game_session")

func start_session() -> bool:
	if session_started:
		return true
	recovered_previous_session = FileAccess.file_exists(marker_path)
	var file := FileAccess.open(marker_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": CURRENT_VERSION,
		"clean_exit": false,
		"started_at": Time.get_unix_time_from_system(),
		"engine": Engine.get_version_info().get("string", "unknown")
	}))
	file.flush()
	file.close()
	session_started = true
	session_opened.emit(recovered_previous_session)
	return true

func finish_session() -> bool:
	if not FileAccess.file_exists(marker_path):
		session_started = false
		return true
	var result := DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path))
	if result == OK or not FileAccess.file_exists(marker_path):
		session_started = false
		return true
	return false

func _start_if_game_session() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path != "res://scenes/launcher.tscn":
		return
	start_session()

func _on_scene_changed() -> void:
	if not session_started:
		call_deferred("_start_if_game_session")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and session_started:
		finish_session()
		get_tree().quit()

class_name MissionState
extends RefCounted

signal state_changed(previous_status: int, current_status: int)

enum Status { NOT_STARTED, ACTIVE, SUCCESS, FAILED }

var status: Status = Status.NOT_STARTED
var clock_minutes: int = 17 * 60 + 59
var _restart_clock_minutes: int = 17 * 60 + 59
var objective: String = "准点下班"
var failure_reason: String = ""
var _restart_completion_minute := -1
var _completion_minute: int = -1
var completion_minute: int:
	get:
		return _completion_minute
	set(value):
		_completion_minute = value
		_restart_completion_minute = value

func configure_schedule(start_minute: int, required_completion_minute: int) -> void:
	_restart_clock_minutes = maxi(start_minute, 0)
	clock_minutes = _restart_clock_minutes
	completion_minute = required_completion_minute

func start() -> void:
	if status == Status.NOT_STARTED:
		_set_status(Status.ACTIVE)

func tick(minutes: int) -> void:
	if status != Status.ACTIVE:
		return
	clock_minutes += maxi(minutes, 0)

func complete() -> bool:
	if status != Status.ACTIVE or (completion_minute >= 0 and clock_minutes < completion_minute):
		return false
	_set_status(Status.SUCCESS)
	return true

func fail(reason: String) -> void:
	if status == Status.ACTIVE:
		failure_reason = reason
		_set_status(Status.FAILED)

func restart() -> void:
	status = Status.NOT_STARTED
	clock_minutes = _restart_clock_minutes
	failure_reason = ""
	completion_minute = _restart_completion_minute
	start()

func snapshot() -> Dictionary:
	return {
		"status": status,
		"clock_minutes": clock_minutes,
		"objective": objective,
		"failure_reason": failure_reason,
		"completion_minute": completion_minute
	}

func _set_status(next_status: Status) -> void:
	var previous := status
	status = next_status
	state_changed.emit(previous, status)

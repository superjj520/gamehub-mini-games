class_name MissionChain
extends RefCounted

signal stage_changed(previous_stage: int, current_stage: int)
signal completed
signal failed(reason: String)

enum Status { NOT_STARTED, ACTIVE, SUCCESS, FAILED }

var stages: Array[Dictionary] = []
var current_index := -1
var status: Status = Status.NOT_STARTED
var failure_reason := ""
var money := 0
var stars := 0

func configure(stage_definitions: Array[Dictionary]) -> void:
	stages = stage_definitions.duplicate(true)
	current_index = -1
	status = Status.NOT_STARTED
	failure_reason = ""
	money = 0
	stars = 0

func start() -> void:
	if status != Status.NOT_STARTED or stages.is_empty():
		return
	status = Status.ACTIVE
	current_index = 0
	stage_changed.emit(-1, current_index)

func current_stage() -> Dictionary:
	if current_index < 0 or current_index >= stages.size():
		return {}
	return stages[current_index]

func current_objective() -> String:
	return str(current_stage().get("objective", ""))

func complete_current() -> bool:
	if status != Status.ACTIVE or current_index < 0:
		return false
	var stage := current_stage()
	money += int(stage.get("reward", 0))
	stars = clampi(stars + int(stage.get("stars", 0)), 0, 5)
	var previous := current_index
	current_index += 1
	if current_index >= stages.size():
		status = Status.SUCCESS
		completed.emit()
	else:
		stage_changed.emit(previous, current_index)
	return true

func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	return true

func fail(reason: String) -> void:
	if status != Status.ACTIVE:
		return
	failure_reason = reason
	status = Status.FAILED
	failed.emit(reason)

func restart() -> void:
	status = Status.NOT_STARTED
	current_index = -1
	failure_reason = ""
	money = 0
	stars = 0
	start()

func snapshot() -> Dictionary:
	return {
		"status": status,
		"current_index": current_index,
		"failure_reason": failure_reason,
		"money": money,
		"stars": stars
	}

func restore(snapshot_data: Dictionary) -> void:
	status = int(snapshot_data.get("status", Status.NOT_STARTED)) as Status
	current_index = int(snapshot_data.get("current_index", -1))
	failure_reason = str(snapshot_data.get("failure_reason", ""))
	money = int(snapshot_data.get("money", 0))
	stars = int(snapshot_data.get("stars", 0))


class_name ConflictState
extends RefCounted

signal status_changed(previous_status: int, current_status: int)
signal opponent_defeated_event(source: String)

enum Status { CALM, ENGAGED, PURSUED, FAILED }

var status: Status = Status.CALM
var max_health := 100.0
var health := 100.0
var alert := 0.0
var last_damage_source := ""
var damage_per_second := 10.0
var opponent_max_health := 100.0
var opponent_health := 100.0
var player_attack_damage := 34.0
var opponent_defeated := false
var dodge_window_seconds := 0.42
var dodge_timer := 0.0

func trigger(source := "人群冲突") -> void:
	if status == Status.FAILED or opponent_defeated:
		return
	last_damage_source = source
	_set_status(Status.ENGAGED)
	alert = 1.0

func pursue() -> void:
	if status == Status.ENGAGED:
		_set_status(Status.PURSUED)

func tick(delta: float, threat_near: bool) -> bool:
	if status == Status.CALM or status == Status.FAILED:
		return false
	dodge_timer = maxf(dodge_timer - maxf(delta, 0.0), 0.0)
	if threat_near:
		if dodge_timer > 0.0:
			last_damage_source = "闪避"
			return true
		health = maxf(health - delta * damage_per_second, 0.0)
	if health <= 0.0:
		_set_status(Status.FAILED)
	return false

func begin_dodge(window_seconds := -1.0) -> bool:
	if status == Status.CALM or status == Status.FAILED or opponent_defeated:
		return false
	var window := dodge_window_seconds if window_seconds <= 0.0 else float(window_seconds)
	dodge_timer = maxf(dodge_timer, maxf(window, 0.0))
	return dodge_timer > 0.0

func is_dodging() -> bool:
	return dodge_timer > 0.0

func attack(damage := -1.0, source := "玩家近战") -> bool:
	if status == Status.CALM or status == Status.FAILED or opponent_defeated:
		return false
	var applied_damage := player_attack_damage if damage <= 0.0 else damage
	opponent_health = maxf(opponent_health - maxf(applied_damage, 0.0), 0.0)
	last_damage_source = str(source)
	if opponent_health <= 0.0:
		opponent_defeated = true
		_set_status(Status.CALM)
		alert = 0.0
		dodge_timer = 0.0
		opponent_defeated_event.emit(last_damage_source)
	return true

func reset() -> void:
	status = Status.CALM
	health = max_health
	alert = 0.0
	last_damage_source = ""
	opponent_health = opponent_max_health
	opponent_defeated = false
	dodge_timer = 0.0

func snapshot() -> Dictionary:
	return {
		"status": status,
		"health": health,
		"opponent_health": opponent_health,
		"opponent_defeated": opponent_defeated,
		"alert": alert,
		"last_damage_source": last_damage_source
	}

func restore(data: Dictionary) -> void:
	status = int(data.get("status", Status.CALM)) as Status
	health = clampf(float(data.get("health", max_health)), 0.0, max_health)
	opponent_health = clampf(float(data.get("opponent_health", opponent_max_health)), 0.0, opponent_max_health)
	opponent_defeated = bool(data.get("opponent_defeated", opponent_health <= 0.0))
	alert = float(data.get("alert", 0.0))
	last_damage_source = str(data.get("last_damage_source", ""))
	dodge_timer = 0.0

func _set_status(next_status: Status) -> void:
	if status == next_status:
		return
	var previous := status
	status = next_status
	status_changed.emit(previous, status)

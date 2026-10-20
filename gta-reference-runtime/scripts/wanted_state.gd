class_name WantedState
extends RefCounted

signal level_changed(previous_level: int, current_level: int, source: String)

var level := 0
var max_level := 5
var decay_delay_seconds := 8.0
var decay_step_seconds := 4.0
var decay_timer := 0.0
var last_source := ""

func configure(config: Dictionary) -> void:
	max_level = clampi(int(config.get("max_level", max_level)), 1, 5)
	decay_delay_seconds = clampf(float(config.get("decay_delay_seconds", decay_delay_seconds)), 0.0, 120.0)
	decay_step_seconds = clampf(float(config.get("decay_step_seconds", decay_step_seconds)), 0.1, 120.0)
	level = clampi(level, 0, max_level)

func report(amount := 1, source := "未知事件") -> void:
	if amount <= 0:
		return
	var previous_level := level
	level = clampi(level + amount, 0, max_level)
	decay_timer = decay_delay_seconds
	last_source = str(source)
	if level != previous_level:
		level_changed.emit(previous_level, level, last_source)

func tick(delta: float, threat_active := false) -> void:
	if level <= 0:
		decay_timer = 0.0
		return
	if threat_active:
		decay_timer = decay_delay_seconds
		return
	decay_timer = maxf(decay_timer - maxf(delta, 0.0), 0.0)
	if decay_timer > 0.0:
		return
	var previous_level := level
	level = maxi(level - 1, 0)
	decay_timer = decay_step_seconds if level > 0 else 0.0
	if level != previous_level:
		level_changed.emit(previous_level, level, "衰减")

func reset() -> void:
	var previous_level := level
	level = 0
	decay_timer = 0.0
	last_source = ""
	if previous_level != level:
		level_changed.emit(previous_level, level, "重置")

func snapshot() -> Dictionary:
	return {
		"level": level,
		"decay_timer": decay_timer,
		"last_source": last_source
	}

func restore(data: Dictionary) -> void:
	if not data is Dictionary:
		reset()
		return
	level = clampi(int(data.get("level", 0)), 0, max_level)
	decay_timer = clampf(float(data.get("decay_timer", 0.0)), 0.0, 120.0)
	last_source = str(data.get("last_source", ""))

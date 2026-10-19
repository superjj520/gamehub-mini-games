class_name TraceRecorder
extends RefCounted

var elapsed := 0.0
var events: Array[Dictionary] = []
var last_error := ""

func advance(delta: float) -> void:
	elapsed += maxf(delta, 0.0)

func record(event_type: String, payload: Dictionary = {}) -> void:
	events.append({
		"time": snappedf(elapsed, 0.001),
		"type": event_type,
		"payload": payload.duplicate(true)
	})

func has_event(event_type: String) -> bool:
	for event in events:
		if event.get("type") == event_type:
			return true
	return false

func to_json() -> String:
	return JSON.stringify({"version": 1, "events": events})

func save(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_json())
	file.flush()
	file.close()
	file = null
	return true

static func from_json(json_text: String) -> TraceRecorder:
	var recorder := TraceRecorder.new()
	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		recorder.last_error = "事件时间轴不是有效 JSON 对象"
		return recorder
	var payload = parser.data
	if not payload is Dictionary:
		recorder.last_error = "事件时间轴不是有效 JSON 对象"
		return recorder
	var version = payload.get("version")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(version)) or float(version) != 1.0:
		recorder.last_error = "事件时间轴版本不受支持"
		return recorder
	var raw_events = payload.get("events")
	if not raw_events is Array:
		recorder.last_error = "事件时间轴 events 字段不是数组"
		return recorder
	var previous_time := -1.0
	for index in range(raw_events.size()):
		var event = raw_events[index]
		if not event is Dictionary:
			recorder.last_error = "事件时间轴第 %d 项不是对象" % index
			recorder.events.clear()
			return recorder
		var event_type = event.get("type")
		var event_time = event.get("time")
		if typeof(event_type) != TYPE_STRING or str(event_type).is_empty():
			recorder.last_error = "事件时间轴第 %d 项类型无效" % index
			recorder.events.clear()
			return recorder
		if typeof(event_time) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(event_time)) or float(event_time) < 0.0 or float(event_time) < previous_time:
			recorder.last_error = "事件时间轴第 %d 项时间无效" % index
			recorder.events.clear()
			return recorder
		if not event.has("payload") or not event.get("payload") is Dictionary:
			recorder.last_error = "事件时间轴第 %d 项 payload 无效" % index
			recorder.events.clear()
			return recorder
		recorder.events.append(event.duplicate(true))
		previous_time = float(event_time)
	if not recorder.events.is_empty():
		recorder.elapsed = float(recorder.events.back().get("time", 0.0))
	return recorder

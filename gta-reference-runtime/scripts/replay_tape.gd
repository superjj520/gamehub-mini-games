class_name ReplayTape
extends RefCounted

const InputFrameClass = preload("res://scripts/input_frame.gd")

var frames: Array[Dictionary] = []
var last_error := ""

func append(frame: InputFrame) -> void:
	frames.append(frame.to_dict())

func clear() -> void:
	frames.clear()

func size() -> int:
	return frames.size()

func frame_at(index: int) -> InputFrame:
	if index < 0 or index >= frames.size():
		return InputFrame.new()
	return InputFrame.from_dict(frames[index])

func to_json() -> String:
	return JSON.stringify({"version": 1, "frames": frames})

static func from_json(json_text: String) -> ReplayTape:
	var tape := ReplayTape.new()
	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		tape.last_error = "回放文件不是有效 JSON 对象"
		return tape
	var parsed = parser.data
	if not parsed is Dictionary:
		tape.last_error = "回放文件不是有效 JSON 对象"
		return tape
	var version = parsed.get("version")
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(version)) or float(version) != 1.0:
		tape.last_error = "回放版本不受支持"
		return tape
	var raw_frames = parsed.get("frames")
	if not raw_frames is Array:
		tape.last_error = "回放 frames 字段不是数组"
		return tape
	for index in range(raw_frames.size()):
		var frame = raw_frames[index]
		if not frame is Dictionary:
			tape.last_error = "回放第 %d 帧不是对象" % index
			tape.frames.clear()
			return tape
		var frame_errors := InputFrameClass.validate_dict(frame)
		if not frame_errors.is_empty():
			tape.last_error = "回放第 %d 帧无效：%s" % [index, ", ".join(frame_errors)]
			tape.frames.clear()
			return tape
		tape.frames.append(frame.duplicate(true))
	return tape

class_name SaveStore
extends RefCounted

const CURRENT_VERSION := 2
const REQUIRED_CONTENT_PACK_ID := "__content_pack_id_required__"

signal operation_failed(operation: String, path: String, reason: String)

var save_path: String
var last_error := ""

func _init(path := "user://reference_checkpoint.json") -> void:
	save_path = path

func save_checkpoint(mission: MissionState, perception: PerceptionState, player_position := Vector3.ZERO, camera_snapshot: Dictionary = {}, vehicle_snapshot: Dictionary = {}, content_pack_id := "") -> bool:
	last_error = ""
	var payload := {
		"version": CURRENT_VERSION,
		"kind": "office",
		"mission": mission.snapshot(),
		"perception": {
			"status": perception.status,
			"suspicion": perception.suspicion,
			"last_seen_position": {
				"x": perception.last_seen_position.x,
				"y": perception.last_seen_position.y,
				"z": perception.last_seen_position.z
			},
			"last_heard_position": {
				"x": perception.last_heard_position.x,
				"y": perception.last_heard_position.y,
				"z": perception.last_heard_position.z
			},
			"last_heard_strength": perception.last_heard_strength,
			"last_heard_age": perception.last_heard_age
		},
		"player_position": {"x": player_position.x, "y": player_position.y, "z": player_position.z},
		"camera": camera_snapshot.duplicate(true),
		"vehicle": vehicle_snapshot.duplicate(true),
		"content_pack_id": content_pack_id
	}
	return _write_payload(payload)

func load_checkpoint(mission: MissionState, perception: PerceptionState, player: Node3D = null, camera_rig: Node3D = null, vehicle: Node3D = null, expected_content_pack_id := REQUIRED_CONTENT_PACK_ID) -> bool:
	last_error = ""
	var payload := _read_payload()
	if payload.is_empty() or payload.get("kind", "office") != "office":
		_set_error("load", "存档格式不受支持")
		return false
	if not _content_pack_matches(payload, expected_content_pack_id):
		return false
	var mission_data = payload.get("mission", {})
	var perception_data = payload.get("perception", {})
	if not mission_data is Dictionary or not perception_data is Dictionary:
		_set_error("load", "存档字段不完整")
		return false
	mission.status = int(mission_data.get("status", MissionState.Status.NOT_STARTED)) as MissionState.Status
	mission.clock_minutes = int(mission_data.get("clock_minutes", 17 * 60 + 59))
	mission.objective = str(mission_data.get("objective", "准点下班"))
	mission.failure_reason = str(mission_data.get("failure_reason", ""))
	mission.completion_minute = int(mission_data.get("completion_minute", -1))
	perception.status = int(perception_data.get("status", PerceptionState.Status.CALM)) as PerceptionState.Status
	perception.suspicion = float(perception_data.get("suspicion", 0.0))
	var position = perception_data.get("last_seen_position", {})
	perception.last_seen_position = Vector3(float(position.get("x", 0.0)), float(position.get("y", 0.0)), float(position.get("z", 0.0)))
	var heard_position = perception_data.get("last_heard_position", {})
	perception.last_heard_position = Vector3(float(heard_position.get("x", 0.0)), float(heard_position.get("y", 0.0)), float(heard_position.get("z", 0.0)))
	perception.last_heard_strength = clampf(float(perception_data.get("last_heard_strength", 0.0)), 0.0, 1.0)
	perception.last_heard_age = maxf(float(perception_data.get("last_heard_age", 999.0)), 0.0)
	var player_data = payload.get("player_position", {})
	if player != null and player_data is Dictionary:
		player.position = Vector3(float(player_data.get("x", player.position.x)), float(player_data.get("y", player.position.y)), float(player_data.get("z", player.position.z)))
	var camera_data = payload.get("camera", {})
	if camera_rig != null and camera_data is Dictionary and camera_data.has("yaw") and camera_data.has("pitch") and camera_rig.has_method("set_orbit"):
		camera_rig.call("set_orbit", float(camera_data["yaw"]), float(camera_data["pitch"]))
	var vehicle_data = payload.get("vehicle", {})
	if vehicle != null and vehicle_data is Dictionary and not vehicle_data.is_empty():
		if vehicle.has_method("exit"):
			vehicle.call("exit")
		if vehicle.has_method("restore_snapshot"):
			vehicle.call("restore_snapshot", vehicle_data)
		if bool(vehicle_data.get("has_driver", false)) and player != null and vehicle.has_method("enter"):
			player.global_position = vehicle.global_position + Vector3.UP
			if vehicle.call("enter", player) and player.has_method("sync_presentation_state"):
				if player.has_method("trigger_presentation_action"):
					player.call("trigger_presentation_action", "vehicle")
				player.call("sync_presentation_state")
	return true

func save_city_checkpoint(chain: MissionChain, inventory: InventoryState, player_position: Vector3, registered: bool, conflict_data: Dictionary = {}, camera_snapshot: Dictionary = {}, vehicle_snapshot: Dictionary = {}, content_pack_id := "", world_state: Dictionary = {}) -> bool:
	last_error = ""
	var payload := {
		"version": CURRENT_VERSION,
		"kind": "city",
		"mission_chain": chain.snapshot(),
		"inventory": inventory.snapshot(),
		"player_position": {"x": player_position.x, "y": player_position.y, "z": player_position.z},
		"registered": registered,
		"conflict": conflict_data,
		"camera": camera_snapshot.duplicate(true),
		"vehicle": vehicle_snapshot.duplicate(true),
		"world_state": world_state.duplicate(true),
		"content_pack_id": content_pack_id
	}
	return _write_payload(payload)

func load_city_checkpoint(chain: MissionChain, inventory: InventoryState, expected_content_pack_id := REQUIRED_CONTENT_PACK_ID) -> Dictionary:
	last_error = ""
	var payload := _read_payload()
	if payload.is_empty() or payload.get("kind", "") != "city":
		_set_error("load", "城市存档格式不受支持")
		return {}
	if not _content_pack_matches(payload, expected_content_pack_id):
		return {}
	var chain_data = payload.get("mission_chain", {})
	var inventory_data = payload.get("inventory", {})
	if not chain_data is Dictionary or not inventory_data is Dictionary:
		_set_error("load", "城市存档字段不完整")
		return {}
	if not _validate_chain_against_stage_count(chain_data, chain.stages.size()):
		_set_error("load", "城市任务索引与当前内容包不匹配")
		return {}
	chain.restore(chain_data)
	inventory.restore(inventory_data)
	var position_data = payload.get("player_position", {})
	return {
		"player_position": Vector3(float(position_data.get("x", 0.0)), float(position_data.get("y", 1.0)), float(position_data.get("z", 0.0))),
		"registered": bool(payload.get("registered", false)),
		"conflict": payload.get("conflict", {}),
		"camera": payload.get("camera", {}),
		"vehicle": payload.get("vehicle", {}),
		"world_state": payload.get("world_state", {})
	}

func _write_payload(payload: Dictionary) -> bool:
	var temporary_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_set_error("save", "无法打开临时存档文件")
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
	file = null

	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		if DirAccess.rename_absolute(save_path, backup_path) != OK:
			_set_error("save", "无法创建存档备份")
			return false

	if DirAccess.rename_absolute(temporary_path, save_path) != OK:
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_path):
			DirAccess.rename_absolute(backup_path, save_path)
		_set_error("save", "无法提交临时存档")
		return false
	return true

func _read_payload() -> Dictionary:
	var payload := _read_payload_from_path(save_path, false)
	if not payload.is_empty():
		return payload
	var backup_path := save_path + ".bak"
	if FileAccess.file_exists(backup_path):
		var backup_payload := _read_payload_from_path(backup_path, false)
		if not backup_payload.is_empty():
			last_error = ""
			return backup_payload
	_set_error("load", "存档不存在或主档损坏，备份也不可用")
	return {}

func _read_payload_from_path(path: String, report_errors := true) -> Dictionary:
	if not FileAccess.file_exists(path):
		if report_errors:
			_set_error("load", "存档不存在")
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		if report_errors:
			_set_error("load", "无法读取存档文件")
		return {}
	var raw_text := file.get_as_text()
	file.close()
	file = null
	var version_literal := _top_level_version_literal(raw_text)
	if version_literal.is_empty() or not version_literal.is_valid_int():
		if report_errors:
			_set_error("load", "存档版本字段格式无效")
		return {}
	var payload = JSON.parse_string(raw_text)
	if not payload is Dictionary:
		if report_errors:
			_set_error("load", "存档不是有效 JSON")
		return {}
	# Godot 在当前运行时会把 JSON 数字解析为浮点值；原始词法扫描已经确认这是
	# 唯一、无小数的整数版本，因此在迁移前规范化为严格的整数 Variant。
	payload["version"] = int(version_literal)
	var migrated := _migrate_payload(payload, report_errors)
	if migrated.is_empty() or not _validate_payload(migrated, report_errors):
		return {}
	return migrated

func _top_level_version_literal(raw_text: String) -> String:
	var index := _skip_json_whitespace(raw_text, 0)
	if index >= raw_text.length() or raw_text[index] != "{":
		return ""
	index += 1
	var seen_keys: Dictionary = {}
	var version_literal := ""
	while index < raw_text.length():
		index = _skip_json_whitespace(raw_text, index)
		if index >= raw_text.length():
			return ""
		if raw_text[index] == "}":
			return version_literal
		var key_info := _read_json_key(raw_text, index)
		if key_info.is_empty():
			return ""
		var decoded_key = JSON.parse_string(str(key_info["raw"]))
		if typeof(decoded_key) != TYPE_STRING:
			return ""
		var key: String = str(decoded_key)
		if seen_keys.has(key):
			return ""
		seen_keys[key] = true
		index = int(key_info["next"])
		index = _skip_json_whitespace(raw_text, index)
		if index >= raw_text.length() or raw_text[index] != ":":
			return ""
		index = _skip_json_whitespace(raw_text, index + 1)
		var value_start := index
		var value_end := _skip_json_value(raw_text, index)
		if value_end < 0:
			return ""
		if key == "version":
			version_literal = raw_text.substr(value_start, value_end - value_start).strip_edges()
		index = _skip_json_whitespace(raw_text, value_end)
		if index < raw_text.length() and raw_text[index] == ",":
			index += 1
			continue
		if index < raw_text.length() and raw_text[index] == "}":
			return version_literal
		return ""
	return ""

func _read_json_key(raw_text: String, start: int) -> Dictionary:
	if start >= raw_text.length() or raw_text[start] != "\"":
		return {}
	var index := start + 1
	var value := ""
	while index < raw_text.length():
		var character := raw_text[index]
		if character == "\"":
			return {"value": value, "raw": raw_text.substr(start, index - start + 1), "next": index + 1}
		if character == "\\":
			if index + 1 >= raw_text.length():
				return {}
			value += "\\" + raw_text[index + 1]
			index += 2
			continue
		value += character
		index += 1
	return {}

func _skip_json_whitespace(raw_text: String, start: int) -> int:
	var index := start
	while index < raw_text.length() and raw_text[index] in [" ", "\t", "\r", "\n"]:
		index += 1
	return index

func _skip_json_string(raw_text: String, start: int) -> int:
	if start >= raw_text.length() or raw_text[start] != "\"":
		return -1
	var index := start + 1
	while index < raw_text.length():
		if raw_text[index] == "\\":
			index += 2
			continue
		if raw_text[index] == "\"":
			return index + 1
		index += 1
	return -1

func _skip_json_value(raw_text: String, start: int) -> int:
	if start >= raw_text.length():
		return -1
	if raw_text[start] == "\"":
		return _skip_json_string(raw_text, start)
	if raw_text[start] == "{" or raw_text[start] == "[":
		var stack: Array[String] = [raw_text[start]]
		var index := start + 1
		while index < raw_text.length():
			if raw_text[index] == "\"":
				index = _skip_json_string(raw_text, index)
				if index < 0:
					return -1
				continue
			if raw_text[index] == "{" or raw_text[index] == "[":
				stack.append(raw_text[index])
			elif raw_text[index] == "}" or raw_text[index] == "]":
				if stack.is_empty():
					return -1
				stack.pop_back()
				if stack.is_empty():
					return index + 1
			index += 1
		return -1
	var index := start
	while index < raw_text.length() and raw_text[index] not in [",", "}", "]", " ", "\t", "\r", "\n"]:
		index += 1
	return index

func _migrate_payload(payload: Dictionary, report_errors := true) -> Dictionary:
	var raw_version = payload.get("version", null)
	if typeof(raw_version) != TYPE_INT:
		if report_errors:
			_set_error("load", "存档版本字段格式无效")
		return {}
	var version := int(raw_version)
	if version <= 0 or version > CURRENT_VERSION:
		if report_errors:
			_set_error("load", "存档版本不受支持")
		return {}
	if version == 1:
		payload.erase("_legacy_unbound_content_pack")
		payload["version"] = CURRENT_VERSION
		if not payload.has("kind"):
			payload["kind"] = "office"
		# v1 办公室存档没有记录空间和载具字段，迁移时补齐明确的空快照，
		# 仍然要求任务和感知核心字段存在，避免把损坏存档伪装成新存档。
		if str(payload.get("kind", "office")) == "office":
			if not payload.has("player_position"):
				payload["player_position"] = {"x": 0.0, "y": 1.0, "z": 0.0}
			if not payload.has("camera"):
				payload["camera"] = {}
			if not payload.has("vehicle"):
				payload["vehicle"] = {}
		if not payload.has("content_pack_id"):
			payload["content_pack_id"] = ""
	else:
		payload.erase("_legacy_unbound_content_pack")
	return payload

func _validate_payload(payload: Dictionary, report_errors := true) -> bool:
	var kind := str(payload.get("kind", ""))
	if kind != "office" and kind != "city":
		return _validation_failed(report_errors, "存档类型不受支持")
	if not _require_fields(payload, ["player_position", "camera", "vehicle"], report_errors, "存档"):
		return false
	if payload.has("content_pack_id") and typeof(payload.get("content_pack_id")) != TYPE_STRING:
		return _validation_failed(report_errors, "内容包标识字段格式无效")
	if not _is_vector_dict(payload.get("player_position")):
		return _validation_failed(report_errors, "玩家位置字段格式无效")
	if not _validate_camera_snapshot(payload.get("camera"), report_errors):
		return false
	if not _validate_vehicle_snapshot(payload.get("vehicle"), report_errors):
		return false
	if kind == "office":
		if not _require_fields(payload, ["mission", "perception"], report_errors, "办公室"):
			return false
		if not _validate_mission_snapshot(payload.get("mission"), report_errors):
			return false
		if not _validate_perception_snapshot(payload.get("perception"), report_errors):
			return false
	else:
		if not _require_fields(payload, ["mission_chain", "inventory", "registered", "conflict"], report_errors, "城市"):
			return false
		if not _validate_mission_chain_snapshot(payload.get("mission_chain"), report_errors):
			return false
		if not _validate_inventory_snapshot(payload.get("inventory"), report_errors):
			return false
		if not _validate_conflict_snapshot(payload.get("conflict"), report_errors):
			return false
		if typeof(payload.get("registered")) != TYPE_BOOL:
			return _validation_failed(report_errors, "城市登记状态字段格式无效")
		if payload.has("world_state") and not _validate_world_state_snapshot(payload.get("world_state"), report_errors):
			return false
	return true

func _content_pack_matches(payload: Dictionary, expected_content_pack_id: String) -> bool:
	if expected_content_pack_id == REQUIRED_CONTENT_PACK_ID:
		_set_error("load", "读取存档时必须显式提供内容包标识")
		return false
	if expected_content_pack_id.is_empty():
		return true
	var stored_content_pack_id := str(payload.get("content_pack_id", ""))
	if stored_content_pack_id == expected_content_pack_id:
		return true
	_set_error("load", "存档内容包与当前运行内容不匹配")
	return false

func _require_fields(value: Dictionary, fields: Array, report_errors: bool, context: String) -> bool:
	for field_name in fields:
		if not value.has(field_name):
			return _validation_failed(report_errors, context + "缺少核心字段：" + str(field_name))
	return true

func _validate_camera_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "存档字段格式无效：camera")
	for field_name in ["yaw", "pitch", "collision_distance"]:
		if value.has(field_name) and not _is_number(value.get(field_name)):
			return _validation_failed(report_errors, "镜头字段格式无效：" + field_name)
	for field_name in ["position", "rotation"]:
		if value.has(field_name) and not _is_number_array(value.get(field_name)):
			return _validation_failed(report_errors, "镜头数组字段格式无效：" + field_name)
	if value.has("collision") and typeof(value.get("collision")) != TYPE_BOOL:
		return _validation_failed(report_errors, "镜头碰撞状态字段格式无效")
	return true

func _validate_vehicle_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "存档字段格式无效：vehicle")
	if value.has("position") and not _is_vector_dict(value.get("position")):
		return _validation_failed(report_errors, "载具位置字段格式无效")
	for field_name in ["rotation_y", "current_speed"]:
		if value.has(field_name) and not _is_number(value.get(field_name)):
			return _validation_failed(report_errors, "载具字段格式无效：" + field_name)
	if value.has("integrity") and not _is_number(value.get("integrity")):
		return _validation_failed(report_errors, "载具字段格式无效：integrity")
	if value.has("has_driver") and typeof(value.get("has_driver")) != TYPE_BOOL:
		return _validation_failed(report_errors, "载具驾驶者状态字段格式无效")
	return true

func _validate_world_state_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "存档字段格式无效：world_state")
	for field_name in ["weather_profile", "neighborhood_status"]:
		if value.has(field_name) and typeof(value.get(field_name)) != TYPE_STRING:
			return _validation_failed(report_errors, "世界状态字段格式无效：" + field_name)
	return true

func _validate_mission_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "办公室任务字段格式无效")
	if not _require_fields(value, ["status", "clock_minutes", "objective", "failure_reason", "completion_minute"], report_errors, "办公室任务"):
		return false
	for field_name in ["status", "clock_minutes", "completion_minute"]:
		if value.has(field_name) and not _is_integer(value.get(field_name)):
			return _validation_failed(report_errors, "办公室任务字段格式无效：" + field_name)
	if int(value.get("status")) < 0 or int(value.get("status")) > 3:
		return _validation_failed(report_errors, "办公室任务状态超出范围")
	for field_name in ["objective", "failure_reason"]:
		if value.has(field_name) and typeof(value.get(field_name)) != TYPE_STRING:
			return _validation_failed(report_errors, "办公室任务文本字段格式无效：" + field_name)
	return true

func _validate_perception_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "办公室感知字段格式无效")
	if not _require_fields(value, ["status", "suspicion", "last_seen_position"], report_errors, "办公室感知"):
		return false
	if not _is_integer(value.get("status")) or int(value.get("status")) < 0 or int(value.get("status")) > 3:
		return _validation_failed(report_errors, "办公室感知状态字段格式无效")
	if not _is_number(value.get("suspicion")) or float(value.get("suspicion")) < 0.0 or float(value.get("suspicion")) > 1.0:
		return _validation_failed(report_errors, "办公室警觉值字段格式无效")
	if not _is_vector_dict(value.get("last_seen_position")):
		return _validation_failed(report_errors, "NPC 最后位置字段格式无效")
	if value.has("last_heard_position") and not _is_vector_dict(value.get("last_heard_position")):
		return _validation_failed(report_errors, "NPC 最后听见位置字段格式无效")
	if value.has("last_heard_strength") and (not _is_number(value.get("last_heard_strength")) or float(value.get("last_heard_strength")) < 0.0 or float(value.get("last_heard_strength")) > 1.0):
		return _validation_failed(report_errors, "NPC 声音强度字段格式无效")
	if value.has("last_heard_age") and (not _is_number(value.get("last_heard_age")) or float(value.get("last_heard_age")) < 0.0):
		return _validation_failed(report_errors, "NPC 声音记忆年龄字段格式无效")
	return true

func _validate_mission_chain_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "城市任务链字段格式无效")
	if not _require_fields(value, ["status", "current_index", "failure_reason", "money", "stars"], report_errors, "城市任务链"):
		return false
	for field_name in ["status", "current_index", "money", "stars"]:
		if value.has(field_name) and not _is_integer(value.get(field_name)):
			return _validation_failed(report_errors, "城市任务链字段格式无效：" + field_name)
	if int(value.get("status")) < 0 or int(value.get("status")) > 3:
		return _validation_failed(report_errors, "城市任务链状态超出范围")
	if int(value.get("current_index")) < -1 or int(value.get("money")) < 0 or int(value.get("stars")) < 0 or int(value.get("stars")) > 5:
		return _validation_failed(report_errors, "城市任务链数值超出范围")
	if value.has("failure_reason") and typeof(value.get("failure_reason")) != TYPE_STRING:
		return _validation_failed(report_errors, "城市任务链失败原因格式无效")
	return true

func _validate_chain_against_stage_count(value: Dictionary, stage_count: int) -> bool:
	var status := int(value.get("status", -1))
	var current_index := int(value.get("current_index", -2))
	if stage_count <= 0:
		return status == MissionChain.Status.NOT_STARTED and current_index == -1
	match status:
		MissionChain.Status.NOT_STARTED:
			return current_index == -1
		MissionChain.Status.ACTIVE, MissionChain.Status.FAILED:
			return current_index >= 0 and current_index < stage_count
		MissionChain.Status.SUCCESS:
			return current_index == stage_count
	return false

func _validate_inventory_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "城市库存字段格式无效")
	for item_id in value.keys():
		if typeof(item_id) != TYPE_STRING or not _is_integer(value.get(item_id)) or int(value.get(item_id)) < 0:
			return _validation_failed(report_errors, "城市库存物品数量格式无效")
	return true

func _validate_conflict_snapshot(value, report_errors: bool) -> bool:
	if not value is Dictionary:
		return _validation_failed(report_errors, "城市冲突字段格式无效")
	if value.has("status") and not _is_integer(value.get("status")):
		return _validation_failed(report_errors, "城市冲突状态字段格式无效")
	if value.has("status") and (int(value.get("status")) < 0 or int(value.get("status")) > 3):
		return _validation_failed(report_errors, "城市冲突状态超出范围")
	for field_name in ["health", "alert"]:
		if value.has(field_name) and not _is_number(value.get(field_name)):
			return _validation_failed(report_errors, "城市冲突字段格式无效：" + field_name)
	if value.has("health") and float(value.get("health")) < 0.0:
		return _validation_failed(report_errors, "城市生命值不能为负数")
	if value.has("alert") and (float(value.get("alert")) < 0.0 or float(value.get("alert")) > 1.0):
		return _validation_failed(report_errors, "城市冲突警报值超出范围")
	if value.has("last_damage_source") and typeof(value.get("last_damage_source")) != TYPE_STRING:
		return _validation_failed(report_errors, "城市冲突来源字段格式无效")
	return true

func _is_vector_dict(value) -> bool:
	if not value is Dictionary:
		return false
	for axis in ["x", "y", "z"]:
		if not value.has(axis):
			return false
		if not _is_number(value.get(axis)):
			return false
	return true

func _is_number(value) -> bool:
	var value_type := typeof(value)
	if value_type == TYPE_INT:
		return true
	return value_type == TYPE_FLOAT and is_finite(float(value))

func _is_integer(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), round(float(value)))

func _is_number_array(value) -> bool:
	if not value is Array:
		return false
	for item in value:
		if not _is_number(item):
			return false
	return true

func _validation_failed(report_errors: bool, reason: String) -> bool:
	if report_errors:
		_set_error("load", reason)
	return false

func _set_error(operation: String, reason: String) -> void:
	last_error = reason
	operation_failed.emit(operation, save_path, reason)

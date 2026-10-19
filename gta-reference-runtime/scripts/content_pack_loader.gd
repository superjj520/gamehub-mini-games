class_name ContentPackLoader
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://content/content-pack-manifest.json"

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw_text := file.get_as_text()
	file.close()
	file = null
	var payload = JSON.parse_string(raw_text)
	return payload if payload is Dictionary else {}

static func load_manifest(path := DEFAULT_MANIFEST_PATH) -> Dictionary:
	return load_json(path)

static func validate_manifest(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(payload.get("schema_version", 0)) != 1:
		errors.append("内容包注册表 schema_version 必须为 1")
	for required_field in ["id", "version", "display_name", "packs"]:
		if not payload.has(required_field):
			errors.append("内容包注册表缺少字段：" + required_field)
	if int(payload.get("version", 0)) <= 0:
		errors.append("内容包注册表版本必须是正整数")
	var raw_packs = payload.get("packs", [])
	if not raw_packs is Array or raw_packs.is_empty():
		errors.append("内容包注册表必须包含 packs")
		return errors
	var identifiers: Dictionary = {}
	for index in range(raw_packs.size()):
		var pack = raw_packs[index]
		if not pack is Dictionary:
			errors.append("内容包注册表第 %d 项不是对象" % index)
			continue
		var pack_id := str(pack.get("id", ""))
		var kind := str(pack.get("kind", ""))
		var pack_path := str(pack.get("path", ""))
		for required_field in ["id", "kind", "path", "content_version", "enabled", "release_allowed"]:
			if not pack.has(required_field):
				errors.append("内容包注册表第 %d 项缺少字段：%s" % [index, required_field])
		if pack_id.is_empty():
			errors.append("内容包注册表第 %d 项 id 不能为空" % index)
		elif identifiers.has(pack_id):
			errors.append("内容包注册表 id 重复：" + pack_id)
		else:
			identifiers[pack_id] = true
		if kind != "office" and kind != "city":
			errors.append("内容包注册表 %s 的 kind 不受支持：%s" % [pack_id, kind])
		var content_version_value = pack.get("content_version")
		var content_version_type := typeof(content_version_value)
		var content_version_is_integer := content_version_type == TYPE_INT or (content_version_type == TYPE_FLOAT and is_equal_approx(float(content_version_value), roundf(float(content_version_value))))
		if not content_version_is_integer or int(content_version_value) <= 0:
			errors.append("内容包注册表 %s 的 content_version 必须是正整数" % pack_id)
		if not pack_path.begins_with("res://"):
			errors.append("内容包注册表 %s 的 path 必须位于 res://" % pack_id)
		elif not FileAccess.file_exists(pack_path):
			errors.append("内容包注册表 %s 的 path 不存在：%s" % [pack_id, pack_path])
		else:
			var pack_payload := load_json(pack_path)
			if str(pack_payload.get("id", "")) != pack_id:
				errors.append("内容包注册表 %s 与文件 id 不一致" % pack_id)
			if int(pack_payload.get("version", 0)) != int(pack.get("content_version", 0)):
				errors.append("内容包注册表 %s 与文件 version 不一致" % pack_id)
			var pack_errors := validate_pack(pack_payload, kind)
			for pack_error in pack_errors:
				errors.append("内容包 %s：%s" % [pack_id, pack_error])
	return errors

static func load_registered_pack(kind: String, pack_id: String, manifest_path := DEFAULT_MANIFEST_PATH) -> Dictionary:
	var manifest := load_manifest(manifest_path)
	if not validate_manifest(manifest).is_empty():
		return {}
	for pack in manifest.get("packs", []):
		if pack is Dictionary and bool(pack.get("enabled", false)) and str(pack.get("id", "")) == pack_id and str(pack.get("kind", "")) == kind:
			return load_json(str(pack.get("path", "")))
	return {}

static func validate_pack(payload: Dictionary, kind: String) -> Array[String]:
	var errors: Array[String] = []
	for required_field in ["id", "version", "display_name"]:
		if not payload.has(required_field):
			errors.append("缺少字段：" + required_field)
	if not int(payload.get("version", 0)) > 0:
		errors.append("版本必须是正整数")
	if kind == "office":
		for required_field in ["objective", "start_minute", "completion_minute"]:
			if not payload.has(required_field):
				errors.append("办公室内容包缺少字段：" + required_field)
		if int(payload.get("completion_minute", -1)) < int(payload.get("start_minute", -1)):
			errors.append("办公室完成时间不能早于开始时间")
	elif kind == "city":
		var raw_stages = payload.get("stages", [])
		var raw_targets = payload.get("targets", [])
		var stage_ids: Dictionary = {}
		var target_ids: Dictionary = {}
		if not raw_stages is Array or raw_stages.is_empty():
			errors.append("城市内容包必须包含阶段数组")
		else:
			for index in range(raw_stages.size()):
				var stage = raw_stages[index]
				if not stage is Dictionary:
					errors.append("阶段 %d 不是对象" % index)
					continue
				for required_field in ["id", "objective", "reward", "stars"]:
					if not stage.has(required_field):
						errors.append("阶段 %d 缺少字段：%s" % [index, required_field])
				var stage_id := str(stage.get("id", ""))
				if stage_id.is_empty():
					errors.append("阶段 %d 的 id 不能为空" % index)
				elif stage_ids.has(stage_id):
					errors.append("阶段 id 重复：" + stage_id)
				stage_ids[stage_id] = true
				if int(stage.get("reward", -1)) < 0:
					errors.append("阶段奖励不能为负数：" + stage_id)
				if int(stage.get("stars", -1)) < 0 or int(stage.get("stars", -1)) > 5:
					errors.append("阶段星级必须在 0 到 5：" + stage_id)
				_validate_stage_rules(stage, stage_id, errors)
		if not raw_targets is Array or raw_targets.is_empty():
			errors.append("城市内容包必须包含目标点数组")
		else:
			for index in range(raw_targets.size()):
				var target = raw_targets[index]
				if not target is Dictionary:
					errors.append("目标点 %d 不是对象" % index)
					continue
				for required_field in ["id", "label", "position", "color"]:
					if not target.has(required_field):
						errors.append("目标点 %d 缺少字段：%s" % [index, required_field])
				var target_id := str(target.get("id", ""))
				if target_id.is_empty():
					errors.append("目标点 %d 的 id 不能为空" % index)
				elif target_ids.has(target_id):
					errors.append("目标点 id 重复：" + target_id)
				target_ids[target_id] = true
				var raw_position = target.get("position", [])
				if not raw_position is Array or raw_position.size() != 3:
					errors.append("目标点位置必须是三个数字：" + target_id)
				else:
					for axis in range(3):
						var value_type := typeof(raw_position[axis])
						if value_type != TYPE_INT and value_type != TYPE_FLOAT:
							errors.append("目标点位置包含非数字：" + target_id)
							break
		if not stage_ids.is_empty() and not target_ids.is_empty():
			for stage_id in stage_ids:
				if not target_ids.has(stage_id):
					errors.append("任务阶段缺少对应目标点：" + str(stage_id))
			for target_id in target_ids:
				if not stage_ids.has(target_id):
					errors.append("目标点缺少对应任务阶段：" + str(target_id))
	else:
		errors.append("未知内容包类型：" + kind)
	_validate_runtime_config(payload, errors)
	return errors

static func _validate_runtime_config(payload: Dictionary, errors: Array[String]) -> void:
	if not payload.has("runtime"):
		return
	var runtime = payload.get("runtime")
	if not runtime is Dictionary:
		errors.append("runtime 必须是对象")
		return
	var section_limits := {
		"player": {"walk_speed": [0.1, 20.0], "crouch_speed": [0.1, 20.0]},
		"perception": {"max_distance": [0.5, 100.0], "field_of_view_degrees": [1.0, 360.0], "suspicion_gain_per_second": [0.0, 10.0], "suspicion_loss_per_second": [0.0, 10.0], "hearing_radius": [0.5, 100.0], "noise_suspicion_per_strength": [0.0, 10.0]},
		"npc": {"search_speed": [0.0, 20.0]},
		"vehicle": {"max_speed": [0.1, 100.0], "acceleration": [0.1, 100.0], "braking": [0.1, 100.0], "turn_speed": [0.0, 10.0], "enter_radius": [0.1, 10.0], "camera_distance": [0.8, 20.0], "camera_height": [0.8, 20.0], "camera_pitch_degrees": [-55.0, -5.0], "collision_damage_per_speed": [0.1, 20.0]},
		"vehicle_service": {"cost": [0.0, 100000.0], "repair_amount": [0.1, 100.0], "interaction_radius": [0.1, 10.0]},
		"conflict": {"max_health": [1.0, 1000.0], "damage_per_second": [0.0, 100.0], "opponent_max_health": [1.0, 1000.0], "player_attack_damage": [0.0, 1000.0], "defeat_bonus": [0.0, 100000.0], "dodge_window_seconds": [0.05, 2.0], "dodge_cooldown_seconds": [0.0, 10.0], "pursuit_speed": [0.0, 50.0], "trigger_radius": [0.1, 20.0], "damage_radius": [0.1, 20.0]},
		"wanted": {"max_level": [1.0, 5.0], "decay_delay_seconds": [0.0, 120.0], "decay_step_seconds": [0.1, 120.0]},
		"crowd": {"walk_speed": [0.0, 20.0]},
		"office": {"boss_rotation_y": [-360.0, 360.0], "hallway_trigger_radius": [0.1, 20.0], "hallway_clear_radius": [0.1, 20.0]}
	}
	for section_name in section_limits:
		if not runtime.has(section_name):
			continue
		var section = runtime.get(section_name)
		if not section is Dictionary:
			errors.append("runtime.%s 必须是对象" % section_name)
			continue
		for field_name in section_limits[section_name]:
			if not section.has(field_name):
				continue
			var value = section.get(field_name)
			var value_type := typeof(value)
			var limits: Array = section_limits[section_name][field_name]
			if value_type != TYPE_INT and value_type != TYPE_FLOAT:
				errors.append("runtime.%s.%s 必须是数字" % [section_name, field_name])
			elif float(value) < float(limits[0]) or float(value) > float(limits[1]):
				errors.append("runtime.%s.%s 超出范围" % [section_name, field_name])
	if runtime.has("vehicle") and runtime.get("vehicle") is Dictionary:
		var vehicle = runtime.get("vehicle")
		if vehicle.has("driver_seat_offset"):
			_validate_position(vehicle.get("driver_seat_offset"), "runtime.vehicle.driver_seat_offset", errors)
	if runtime.has("vehicle_service"):
		var vehicle_service = runtime.get("vehicle_service")
		if not vehicle_service is Dictionary:
			errors.append("runtime.vehicle_service 必须是对象")
		elif vehicle_service.has("enabled") and typeof(vehicle_service.get("enabled")) != TYPE_BOOL:
			errors.append("runtime.vehicle_service.enabled 必须是布尔值")
	if runtime.has("neighborhood"):
		var neighborhood = runtime.get("neighborhood")
		if not neighborhood is Dictionary:
			errors.append("runtime.neighborhood 必须是对象")
		else:
			if neighborhood.has("enabled") and typeof(neighborhood.get("enabled")) != TYPE_BOOL:
				errors.append("runtime.neighborhood.enabled 必须是布尔值")
			_validate_position(neighborhood.get("entry", []), "runtime.neighborhood.entry", errors)
	if runtime.has("visual_profiles"):
		var visual_profiles = runtime.get("visual_profiles")
		if not visual_profiles is Dictionary or not visual_profiles.get("supported", []) is Array:
			errors.append("runtime.visual_profiles 必须包含 supported 数组")
		else:
			for profile in visual_profiles.get("supported", []):
				if str(profile) not in ["day", "dusk", "rain_after"]:
					errors.append("runtime.visual_profiles 含未知配置：" + str(profile))
	if runtime.has("crowd") and runtime.get("crowd") is Dictionary:
		_validate_routes(runtime.get("crowd").get("routes", []), "runtime.crowd.routes", errors)
	if runtime.has("office"):
		var office = runtime.get("office")
		if not office is Dictionary:
			errors.append("runtime.office 必须是对象")
		else:
			for position_field in ["exit_position", "boss_position"]:
				_validate_position(office.get(position_field, []), "runtime.office." + position_field, errors)
			_validate_routes([office.get("hallway_route", [])], "runtime.office.hallway_route", errors)
			if office.has("typing_camera"):
				var typing_camera = office.get("typing_camera")
				if not typing_camera is Dictionary:
					errors.append("runtime.office.typing_camera 必须是对象")
				else:
					var typing_camera_limits := {
						"distance": [0.5, 20.0],
						"height": [0.5, 20.0],
						"yaw_degrees": [-360.0, 360.0],
						"pitch_degrees": [-89.0, 89.0]
					}
					for field_name in typing_camera_limits:
						if not typing_camera.has(field_name):
							continue
						var value = typing_camera.get(field_name)
						var limits: Array = typing_camera_limits[field_name]
						if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
							errors.append("runtime.office.typing_camera.%s 必须是数字" % field_name)
						elif float(value) < float(limits[0]) or float(value) > float(limits[1]):
							errors.append("runtime.office.typing_camera.%s 超出范围" % field_name)
					_validate_position(typing_camera.get("shoulder_offset", []), "runtime.office.typing_camera.shoulder_offset", errors)
	if runtime.has("traffic"):
		var traffic = runtime.get("traffic")
		if not traffic is Dictionary:
			errors.append("runtime.traffic 必须是对象")
		else:
			var vehicles = traffic.get("vehicles", [])
			if not vehicles is Array or vehicles.is_empty():
				errors.append("runtime.traffic.vehicles 必须是非空数组")
			else:
				for index in range(vehicles.size()):
					var vehicle = vehicles[index]
					if not vehicle is Dictionary:
						errors.append("runtime.traffic.vehicles 第 %d 项不是对象" % index)
						continue
					if str(vehicle.get("id", "")).is_empty():
						errors.append("runtime.traffic.vehicles 第 %d 项缺少 id" % index)
					var speed = vehicle.get("travel_speed", null)
					if speed == null or (typeof(speed) != TYPE_INT and typeof(speed) != TYPE_FLOAT) or float(speed) < 0.0 or float(speed) > 100.0:
						errors.append("runtime.traffic.vehicles 第 %d 项 travel_speed 无效" % index)
					_validate_routes([vehicle.get("route", [])], "runtime.traffic.vehicles[%d].route" % index, errors)

static func _validate_routes(raw_routes, label: String, errors: Array[String]) -> void:
	if not raw_routes is Array or raw_routes.is_empty():
		errors.append(label + " 必须是非空数组")
		return
	for route_index in range(raw_routes.size()):
		var route = raw_routes[route_index]
		if not route is Array or route.size() < 2:
			errors.append("%s 第 %d 条路线至少需要两个点" % [label, route_index])
			continue
		for point_index in range(route.size()):
			var point = route[point_index]
			if not point is Array or point.size() != 3:
				errors.append("%s 第 %d 条路线第 %d 个点必须是三个数字" % [label, route_index, point_index])
				continue
			for axis in range(3):
				var value_type := typeof(point[axis])
				if value_type != TYPE_INT and value_type != TYPE_FLOAT:
					errors.append("%s 第 %d 条路线包含非数字坐标" % [label, route_index])
					break

static func _validate_position(raw_position, label: String, errors: Array[String]) -> void:
	if not raw_position is Array or raw_position.size() != 3:
		errors.append(label + " 必须是三个数字")
		return
	for axis in range(3):
		var value_type := typeof(raw_position[axis])
		if value_type != TYPE_INT and value_type != TYPE_FLOAT:
			errors.append(label + " 包含非数字坐标")
			return

static func _validate_stage_rules(stage: Dictionary, stage_id: String, errors: Array[String]) -> void:
	if stage.has("requirements"):
		_validate_requirement_rules(stage.get("requirements"), "阶段 %s requirements" % stage_id, errors)
	var effects = stage.get("effects", {})
	if effects == null:
		return
	if not effects is Dictionary:
		errors.append("阶段 %s effects 必须是对象" % stage_id)
		return
	if effects.has("add_items"):
		_validate_item_rules(effects.get("add_items"), "阶段 %s effects.add_items" % stage_id, errors, false)
	if effects.has("remove_items"):
		_validate_item_rules(effects.get("remove_items"), "阶段 %s effects.remove_items" % stage_id, errors, false)
	if effects.has("set_registered") and typeof(effects.get("set_registered")) != TYPE_BOOL:
		errors.append("阶段 %s effects.set_registered 必须是布尔值" % stage_id)
	if effects.has("set_neighborhood_active") and typeof(effects.get("set_neighborhood_active")) != TYPE_BOOL:
		errors.append("阶段 %s effects.set_neighborhood_active 必须是布尔值" % stage_id)
	for event_key in ["trace_events", "audio_events"]:
		if not effects.has(event_key):
			continue
		var events = effects.get(event_key)
		if not events is Array:
			errors.append("阶段 %s effects.%s 必须是数组" % [stage_id, event_key])
			continue
		for event_index in range(events.size()):
			var event = events[event_index]
			if not event is Dictionary or str(event.get("id", "")).is_empty():
				errors.append("阶段 %s effects.%s 第 %d 项缺少 id" % [stage_id, event_key, event_index])

static func _validate_item_rules(raw_rules, label: String, errors: Array[String], allow_failure_message: bool) -> void:
	if not raw_rules is Array:
		errors.append(label + " 必须是数组")
		return
	for index in range(raw_rules.size()):
		var rule = raw_rules[index]
		if not rule is Dictionary:
			errors.append("%s 第 %d 项不是对象" % [label, index])
			continue
		if allow_failure_message and str(rule.get("type", "item")) != "item":
			errors.append("%s 第 %d 项 type 只支持 item" % [label, index])
		var item_id := str(rule.get("item_id", ""))
		if item_id.is_empty():
			errors.append("%s 第 %d 项缺少 item_id" % [label, index])
		if int(rule.get("amount", 0)) <= 0:
			errors.append("%s 第 %d 项 amount 必须为正数" % [label, index])

static func _validate_requirement_rules(raw_rules, label: String, errors: Array[String]) -> void:
	if not raw_rules is Array:
		errors.append(label + " 必须是数组")
		return
	for index in range(raw_rules.size()):
		var rule = raw_rules[index]
		if not rule is Dictionary:
			errors.append("%s 第 %d 项不是对象" % [label, index])
			continue
		var rule_type := str(rule.get("type", "item"))
		if rule_type == "item":
			_validate_item_rules([rule], label, errors, true)
		elif rule_type == "flag":
			var flag := str(rule.get("flag", ""))
			if flag not in ["registered", "neighborhood_active"]:
				errors.append("%s 第 %d 项 flag 不受支持：%s" % [label, index, flag])
			if str(rule.get("failure_message", "")).is_empty():
				errors.append("%s 第 %d 项 flag 缺少 failure_message" % [label, index])
		else:
			errors.append("%s 第 %d 项 type 不受支持：%s" % [label, index, rule_type])

static func stages_from_pack(path: String) -> Array[Dictionary]:
	var payload := load_json(path)
	return stages_from_payload(payload)

static func stages_from_payload(payload: Dictionary) -> Array[Dictionary]:
	var stages: Array[Dictionary] = []
	var raw_stages = payload.get("stages", [])
	if raw_stages is Array:
		for stage in raw_stages:
			if stage is Dictionary:
				stages.append(stage)
	return stages

class_name AssetRuntimeCatalog
extends RefCounted

static func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw_text := file.get_as_text()
	file.close()
	file = null
	var payload = JSON.parse_string(raw_text)
	return payload if payload is Dictionary else {}

static func validate(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(payload.get("schema_version", 0)) != 1:
		errors.append("资产运行时目录 schema_version 必须为 1")
	var slots = payload.get("slots", [])
	if not slots is Array or slots.is_empty():
		errors.append("资产运行时目录缺少 slots")
		return errors
	var identifiers := {}
	for index in range(slots.size()):
		var slot = slots[index]
		if not slot is Dictionary:
			errors.append("资产槽位 %d 不是对象" % index)
			continue
		var slot_id := str(slot.get("id", ""))
		if slot_id.is_empty():
			errors.append("资产槽位 %d 缺少 id" % index)
		elif identifiers.has(slot_id):
			errors.append("资产槽位 id 重复：" + slot_id)
		else:
			identifiers[slot_id] = true
		for required_field in ["category", "root_name", "scene_path", "fallback_policy"]:
			if not slot.has(required_field):
				errors.append("资产槽位 %s 缺少字段：%s" % [slot_id, required_field])
		var scene_path := str(slot.get("scene_path", ""))
		var fallback_policy := str(slot.get("fallback_policy", ""))
		if not ["procedural_graybox", "forbid"].has(fallback_policy):
			errors.append("资产槽位 %s 的 fallback_policy 未登记：%s" % [slot_id, fallback_policy])
		# 音频槽位由 AudioEventRouter 按逐事件 WAV 清单挂载，不通过 PackedScene
		# 的 scene_path 接入；原创边界仍必须禁止回退，但不能因此伪造一个场景路径。
		if fallback_policy == "forbid" and scene_path.is_empty() and str(slot.get("category", "")) != "audio":
			errors.append("资产槽位 %s 禁止回退但没有 scene_path" % slot_id)
		if not scene_path.is_empty() and not scene_path.begins_with("res://"):
			errors.append("资产槽位 %s 的 scene_path 必须位于 res://" % slot_id)
		elif not scene_path.is_empty():
			if not ResourceLoader.exists(scene_path):
				errors.append("资产槽位 %s 的 scene_path 不存在：%s" % [slot_id, scene_path])
			else:
				var resource = ResourceLoader.load(scene_path)
				if not resource is PackedScene:
					errors.append("资产槽位 %s 的 scene_path 必须指向 PackedScene：%s" % [slot_id, scene_path])
	return errors

static func has_slot(payload: Dictionary, slot_id: String) -> bool:
	return not _find_slot(payload, slot_id).is_empty()

static func mount_optional_visual(parent: Node, payload: Dictionary, slot_id: String, fallback: Node) -> Dictionary:
	var slot := _find_slot(payload, slot_id)
	var fallback_policy := str(slot.get("fallback_policy", "procedural_graybox")) if not slot.is_empty() else "procedural_graybox"
	if parent == null or fallback == null:
		if fallback_policy == "forbid":
			return {"node": null, "used_fallback": false, "blocked": true, "reason": "required_mount_target_missing", "slot_id": slot_id}
		return {"node": fallback, "used_fallback": true, "reason": "missing_parent_or_fallback"}
	var scene_path := str(slot.get("scene_path", "")) if not slot.is_empty() else ""
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var packed = load(scene_path)
		if packed is PackedScene:
			var override_node: Node = packed.instantiate()
			if override_node != null:
				override_node.name = str(slot.get("root_name", override_node.name))
				parent.add_child(override_node)
				if fallback.is_inside_tree():
					fallback.queue_free()
				else:
					# 灰盒回退通常在挂载覆盖场景前尚未入树，必须立即释放，
					# 否则其网格和材质会在场景销毁后成为孤儿资源。
					fallback.free()
				return {"node": override_node, "used_fallback": false, "reason": "catalog_override", "slot_id": slot_id}
	if fallback_policy == "forbid":
		# 成品目录不能在资源丢失、路径失效或实例化失败时静默显示灰盒。
		if fallback.is_inside_tree():
			fallback.queue_free()
		else:
			fallback.free()
		return {"node": null, "used_fallback": false, "blocked": true, "reason": "required_override_failed", "slot_id": slot_id}
	parent.add_child(fallback)
	return {"node": fallback, "used_fallback": true, "reason": "graybox_fallback", "slot_id": slot_id}

static func drive_animation_state(root: Node, state_name: String) -> Dictionary:
	if root == null or state_name.is_empty():
		return {"driven": false, "reason": "missing_root_or_state"}
	var animation_player := _find_animation_player(root)
	var player_driven := false
	if animation_player != null and animation_player.has_animation(state_name):
		if animation_player.current_animation != state_name:
			animation_player.play(state_name)
		player_driven = true
	var animation_tree := _find_animation_tree(root)
	var tree_driven := false
	if animation_tree != null:
		var playback = animation_tree.get("parameters/playback")
		if playback != null and playback.has_method("travel"):
			animation_tree.active = true
			playback.travel(state_name)
			tree_driven = true
	var candidate_driven := false
	if root.has_method("drive_candidate_state"):
		root.call("drive_candidate_state", state_name)
		candidate_driven = true
	return {"driven": player_driven or tree_driven or candidate_driven, "animation_player": player_driven, "animation_tree": tree_driven, "candidate_visual": candidate_driven, "state": state_name}

static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null

static func _find_animation_tree(root: Node) -> AnimationTree:
	if root is AnimationTree:
		return root as AnimationTree
	for child in root.get_children():
		var result := _find_animation_tree(child)
		if result != null:
			return result
	return null

static func _find_slot(payload: Dictionary, slot_id: String) -> Dictionary:
	for slot in payload.get("slots", []):
		if slot is Dictionary and str(slot.get("id", "")) == slot_id:
			return slot
	return {}

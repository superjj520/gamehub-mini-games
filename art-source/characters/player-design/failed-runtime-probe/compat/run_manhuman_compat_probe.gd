extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://assets/characters/original-procedural-office-characters/original_player_manhuman_compat_candidate.tscn") as PackedScene
	assert(packed != null, "兼容候选场景未导入")
	var candidate: Node = packed.instantiate()
	root.add_child(candidate)
	await process_frame
	var meshes := candidate.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() >= 4, "兼容候选网格数量不足")
	for state_name in ["idle_default", "walk_default", "crouch_default", "vehicle_default", "fail_default"]:
		assert(candidate.has_method("drive_candidate_state"), "兼容候选缺少状态接口")
		candidate.call("drive_candidate_state", state_name)
		await process_frame
	print("MakeHuman 清洗版兼容候选通过：网格 ", meshes.size(), " 个；状态接口 5/5")
	candidate.free()
	quit(0)

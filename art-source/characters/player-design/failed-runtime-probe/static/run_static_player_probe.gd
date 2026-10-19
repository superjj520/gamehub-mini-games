extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://assets/characters/original-procedural-office-characters/original_player_static_candidate.tscn") as PackedScene
	assert(packed != null, "静态人物候选场景未导入")
	var candidate: Node = packed.instantiate()
	root.add_child(candidate)
	await process_frame
	var meshes := candidate.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() >= 6, "静态人物候选网格数量不足")
	for state_name in ["idle_default", "walk_default", "crouch_default", "vehicle_default", "fail_default"]:
		candidate.call("drive_candidate_state", state_name)
		await process_frame
	print("MakeHuman 静态人物候选通过：网格 ", meshes.size(), " 个；状态接口 5/5")
	candidate.free()
	quit(0)

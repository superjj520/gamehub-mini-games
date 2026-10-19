extends SceneTree

## MakeHuman 候选的真实 Skeleton3D 姿态契约。
## 这是资产生产工具，不进入正式运行时或发布包。

const TARGETS := {
	"idle_default": ["spine_02"],
	"walk_default": ["upperarm_l", "thigh_l"],
	"search_default": ["head", "spine_02"],
	"alert_default": ["head", "spine_03"],
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_path := OS.get_environment("P0_CANDIDATE_SCENE_PATH").strip_edges()
	assert(not scene_path.is_empty(), "缺少 P0_CANDIDATE_SCENE_PATH")
	var packed: PackedScene = load(scene_path) as PackedScene
	assert(packed != null, "候选场景无法加载：" + scene_path)
	var root: Node3D = packed.instantiate()
	get_root().add_child(root)
	for _frame in range(4):
		await process_frame
	var character: Node = root.get_node_or_null("Character")
	assert(character != null, "候选场景缺少 Character")
	var skeleton_nodes: Array[Node] = character.find_children("*", "Skeleton3D", true, false)
	assert(not skeleton_nodes.is_empty(), "候选人物缺少 Skeleton3D")
	var skeleton: Skeleton3D = skeleton_nodes[0] as Skeleton3D
	var report := {}
	var failed := false
	for state_name in TARGETS:
		assert(root.has_method("drive_candidate_state"), "候选根节点缺少 drive_candidate_state")
		root.drive_candidate_state(state_name)
		var before := {}
		for bone_name in TARGETS[state_name]:
			var index := skeleton.find_bone(bone_name)
			assert(index >= 0, "缺少契约骨骼：" + bone_name)
			before[bone_name] = skeleton.get_bone_pose_rotation(index)
		for _frame in range(8):
			await process_frame
		var changed: Array[String] = []
		for bone_name in TARGETS[state_name]:
			var index := skeleton.find_bone(bone_name)
			var before_rotation: Quaternion = before[bone_name]
			var after_rotation: Quaternion = skeleton.get_bone_pose_rotation(index)
			if before_rotation.angle_to(after_rotation) > 0.0001:
				changed.append(bone_name)
		var passed := not changed.is_empty()
		report[state_name] = {"changed_bones": changed, "passed": passed}
		failed = failed or not passed
	var output_path := OS.get_environment("P0_BONE_ANIMATION_OUTPUT").strip_edges()
	if not output_path.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		assert(file != null, "无法写入姿态契约证据：" + output_path)
		file.store_string(JSON.stringify({"candidate_scene": scene_path, "states": report}))
		file.close()
	print("MakeHuman 候选真实骨骼姿态契约：", JSON.stringify(report))
	root.free()
	await process_frame
	quit(1 if failed else 0)

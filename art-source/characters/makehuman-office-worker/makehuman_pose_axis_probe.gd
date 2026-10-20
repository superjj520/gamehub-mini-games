extends SceneTree

## MakeHuman 候选骨骼轴向探针：只用于确定局部姿态修正方向，不进入正式运行时。

const CASES := [
	{"id": "base", "title": "原始导入", "axis": "", "left": 0.0, "right": 0.0},
	{"id": "z_player", "title": "Z轴·玩家方向", "axis": "z", "left": -1.48, "right": 1.48},
	{"id": "z_reverse", "title": "Z轴·反向", "axis": "z", "left": 1.48, "right": -1.48},
	{"id": "x_player", "title": "X轴·玩家方向", "axis": "x", "left": -1.48, "right": -1.48},
	{"id": "x_reverse", "title": "X轴·反向", "axis": "x", "left": 1.48, "right": 1.48},
	{"id": "y_pair", "title": "Y轴·左右对称", "axis": "y", "left": -1.48, "right": 1.48},
	{"id": "z_small", "title": "Z轴·小角度", "axis": "z", "left": -0.72, "right": 0.72},
	{"id": "x_small", "title": "X轴·小角度", "axis": "x", "left": -0.72, "right": -0.72},
]

const REQUIRED_BONES := ["upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		push_error("MakeHuman 骨骼轴向探针需要真实图形窗口")
		quit(2)
		return
	var output_path := OS.get_environment("POSE_PROBE_OUTPUT").strip_edges()
	var manifest_path := OS.get_environment("POSE_PROBE_MANIFEST").strip_edges()
	if output_path.is_empty() or manifest_path.is_empty():
		push_error("缺少 POSE_PROBE_OUTPUT 或 POSE_PROBE_MANIFEST")
		quit(1)
		return
	var packed := load("res://probe_character.glb") as PackedScene
	if packed == null:
		push_error("无法加载 MakeHuman 骨骼探针 GLB")
		quit(1)
		return
	var root := Node3D.new()
	root.name = "MakeHuman骨骼轴向探针场景"
	get_root().add_child(root)
	_build_lighting(root)
	_build_floor(root)
	var positions := [Vector3(-3.75, 0.0, 0.0), Vector3(-1.25, 0.0, 0.0), Vector3(1.25, 0.0, 0.0), Vector3(3.75, 0.0, 0.0), Vector3(-2.5, 0.0, -2.6), Vector3(0.0, 0.0, -2.6), Vector3(2.5, 0.0, -2.6), Vector3(5.0, 0.0, -2.6)]
	var results: Array[Dictionary] = []
	for index in range(CASES.size()):
		var character := packed.instantiate() as Node3D
		character.name = "姿态探针_%s" % CASES[index]["id"]
		character.position = positions[index]
		root.add_child(character)
		await process_frame
		await process_frame
		var result := _apply_case(character, CASES[index])
		results.append(result)
		_add_title(root, str(CASES[index]["title"]), positions[index] + Vector3(0.0, 2.18, 0.0))
	var camera := Camera3D.new()
	camera.name = "姿态探针相机"
	camera.fov = 52.0
	camera.position = Vector3(0.0, 3.1, 10.8)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, -0.8), Vector3.UP)
	camera.make_current()
	await process_frame
	await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("骨骼轴向探针截图为空")
		quit(1)
		return
	if image.save_png(output_path) != OK:
		push_error("骨骼轴向探针截图写入失败")
		quit(1)
		return
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		push_error("骨骼轴向探针清单写入失败")
		quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "status": "candidate_pose_axis_probe_captured", "visual_status": "unverified", "release_allowed": false, "image": output_path, "cases": results}))
	file.close()
	print("MakeHuman 骨骼轴向探针已生成：", output_path)
	root.free()
	await process_frame
	quit(0)

func _apply_case(character: Node3D, case_data: Dictionary) -> Dictionary:
	var skeleton_nodes := character.find_children("*", "Skeleton3D", true, false)
	if skeleton_nodes.is_empty():
		push_error("姿态探针角色缺少 Skeleton3D：" + str(case_data["id"]))
		return {"id": case_data["id"], "passed": false, "missing_bones": REQUIRED_BONES}
	var skeleton := skeleton_nodes[0] as Skeleton3D
	var base_rotations := {}
	var missing: Array[String] = []
	for bone_name in REQUIRED_BONES:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			missing.append(bone_name)
		else:
			base_rotations[bone_name] = skeleton.get_bone_pose_rotation(bone_index)
	if not missing.is_empty():
		return {"id": case_data["id"], "passed": false, "missing_bones": missing}
	var axis := str(case_data["axis"])
	for bone_name in REQUIRED_BONES:
		var correction := Vector3.ZERO
		if axis != "":
			var angle := float(case_data["left"] if bone_name.ends_with("_l") else case_data["right"])
			if axis == "x":
				correction.x = angle
			elif axis == "y":
				correction.y = angle
			elif axis == "z":
				correction.z = angle
		var bone_index := skeleton.find_bone(bone_name)
		skeleton.set_bone_pose_rotation(bone_index, base_rotations[bone_name] * Quaternion.from_euler(correction))
	return {"id": case_data["id"], "axis": axis, "left": case_data["left"], "right": case_data["right"], "passed": true, "missing_bones": []}

func _build_lighting(root: Node3D) -> void:
	var environment := WorldEnvironment.new()
	environment.name = "姿态探针环境"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202a33")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9c5ca")
	settings.ambient_light_energy = 0.72
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 1.08
	environment.environment = settings
	root.add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "姿态探针主光"
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_color = Color("f5ddc0")
	key.light_energy = 1.15
	key.shadow_enabled = true
	root.add_child(key)

func _build_floor(root: Node3D) -> void:
	var floor := MeshInstance3D.new()
	floor.name = "姿态探针地面"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(12.0, 8.0)
	floor.mesh = mesh
	floor.position = Vector3(0.0, 0.0, -1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("374047")
	material.roughness = 0.86
	floor.material_override = material
	root.add_child(floor)

func _add_title(root: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.name = "姿态探针标题_%s" % text
	label.text = text
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color("f2e2bd")
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)

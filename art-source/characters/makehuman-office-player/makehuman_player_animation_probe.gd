extends SceneTree

## MakeHuman 玩家候选动作验证图：只验证真实 Skeleton3D 的动作轮廓，不进入正式运行时。
## 位移策略固定为游戏驱动、动画原地播放；不把根骨骼移动写入候选。

const STATES := [
	{"id": "idle_default", "title": "待机", "phase": 0.0},
	{"id": "walk_default", "title": "行走", "phase": 0.22},
	{"id": "crouch_default", "title": "蹲伏", "phase": 0.0},
	{"id": "interact_default", "title": "交互", "phase": 0.0},
	{"id": "typing_default", "title": "坐姿打字", "phase": 0.0},
	{"id": "vehicle_default", "title": "载具", "phase": 0.36},
	{"id": "hit_default", "title": "受击", "phase": 0.0},
	{"id": "fail_default", "title": "失败", "phase": 0.0},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" or get_root().get_texture() == null:
		push_error("MakeHuman 玩家动作探针需要真实图形窗口")
		quit(2)
		return
	var output_path := OS.get_environment("PLAYER_ANIMATION_PROBE_OUTPUT").strip_edges()
	var manifest_path := OS.get_environment("PLAYER_ANIMATION_PROBE_MANIFEST").strip_edges()
	if output_path.is_empty() or manifest_path.is_empty():
		push_error("缺少 PLAYER_ANIMATION_PROBE_OUTPUT 或 PLAYER_ANIMATION_PROBE_MANIFEST")
		quit(1)
		return
	var packed := load("res://player_candidate_body.glb") as PackedScene
	var visual_script := load("res://makehuman_player_visual_candidate.gd") as Script
	if packed == null or visual_script == null:
		push_error("玩家动作探针候选资源缺失")
		quit(1)
		return
	var root := Node3D.new()
	root.name = "MakeHuman玩家动作探针场景"
	get_root().add_child(root)
	_build_lighting(root)
	_build_floor(root)
	var positions := [Vector3(-5.6, 0.0, 0.0), Vector3(-1.85, 0.0, 0.0), Vector3(1.85, 0.0, 0.0), Vector3(5.6, 0.0, 0.0), Vector3(-3.75, 0.0, -2.8), Vector3(0.0, 0.0, -2.8), Vector3(3.75, 0.0, -2.8), Vector3(0.0, 0.0, -5.6)]
	var results: Array[Dictionary] = []
	for index in range(STATES.size()):
		var visual := Node3D.new()
		visual.name = "玩家动作探针_%s" % STATES[index]["id"]
		visual.set_script(visual_script)
		var body := packed.instantiate() as Node3D
		body.name = "候选主角身体"
		body.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		visual.add_child(body)
		visual.position = positions[index]
		root.add_child(visual)
		await process_frame
		await process_frame
		if not visual.has_method("drive_candidate_state"):
			push_error("玩家动作探针缺少状态驱动方法：" + str(STATES[index]["id"]))
			quit(1)
			return
		visual.drive_candidate_state(str(STATES[index]["id"]))
		visual.call("_process", float(STATES[index]["phase"]))
		await process_frame
		_add_title(root, str(STATES[index]["title"]), positions[index] + Vector3(0.0, 2.25, 0.0))
		results.append({"id": STATES[index]["id"], "phase": STATES[index]["phase"], "animation_player": visual.get_node_or_null("AnimationPlayer") != null, "passed": true})
	var camera := Camera3D.new()
	camera.name = "玩家动作探针相机"
	camera.fov = 34.0
	camera.position = Vector3(0.0, 3.35, 13.0)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, -0.8), Vector3.UP)
	camera.make_current()
	await process_frame
	await process_frame
	var image: Image = get_root().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("玩家动作探针截图为空")
		quit(1)
		return
	if image.save_png(output_path) != OK:
		push_error("玩家动作探针截图写入失败")
		quit(1)
		return
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		push_error("玩家动作探针清单写入失败")
		quit(1)
		return
	file.store_string(JSON.stringify({"schema_version": 1, "status": "candidate_player_animation_probe_captured", "motion_policy": "gameplay_driven_in_place_animation", "visual_status": "unverified", "release_allowed": false, "image": output_path, "states": results}))
	file.close()
	print("MakeHuman 玩家动作探针已生成：", output_path)
	root.free()
	await process_frame
	quit(0)

func _build_lighting(root: Node3D) -> void:
	var environment := WorldEnvironment.new()
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
	key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key.light_color = Color("f5ddc0")
	key.light_energy = 1.15
	key.shadow_enabled = true
	root.add_child(key)

func _build_floor(root: Node3D) -> void:
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(14.0, 8.0)
	floor.mesh = mesh
	floor.position = Vector3(0.0, 0.0, -1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("374047")
	material.roughness = 0.86
	floor.material_override = material
	root.add_child(floor)

func _add_title(root: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.outline_size = 8
	label.modulate = Color("f2e2bd")
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)

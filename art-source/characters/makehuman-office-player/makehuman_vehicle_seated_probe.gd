extends SceneTree

## MakeHuman 玩家与真实三轮车候选的驾驶姿态探针。
## 使用正式运行时的驾驶座偏移和游戏驱动原地动作；仅生成候选验收证据。

const DRIVER_SEAT_OFFSET := Vector3(0.0, 1.12, 0.18)
const CASES := [
	{"id": "gameplay_rear", "title": "游戏视角·驾驶", "position": Vector3(-2.8, 0.0, 0.0), "rotation_y": 0.0},
	{"id": "three_quarter", "title": "三分之四·坐姿检查", "position": Vector3(2.8, 0.0, -0.25), "rotation_y": 0.42},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var offscreen := OS.get_environment("MAKEHUMAN_VEHICLE_PROBE_OFFSCREEN").strip_edges() == "1"
	if not offscreen and (DisplayServer.get_name() == "headless" or get_root().get_texture() == null):
		push_error("MakeHuman 载具驾驶探针需要真实图形窗口")
		quit(2)
		return
	var output_path := OS.get_environment("MAKEHUMAN_VEHICLE_PROBE_OUTPUT").strip_edges()
	var manifest_path := OS.get_environment("MAKEHUMAN_VEHICLE_PROBE_MANIFEST").strip_edges()
	if output_path.is_empty() or manifest_path.is_empty():
		push_error("缺少 MAKEHUMAN_VEHICLE_PROBE_OUTPUT 或 MAKEHUMAN_VEHICLE_PROBE_MANIFEST")
		quit(1)
		return
	var player_scene := load("res://player_candidate_body.glb") as PackedScene
	var vehicle_scene := load("res://three_wheel_delivery_candidate.glb") as PackedScene
	var visual_script := load("res://makehuman_player_visual_candidate.gd") as Script
	if player_scene == null or vehicle_scene == null or visual_script == null:
		push_error("载具驾驶探针候选资源缺失")
		quit(1)
		return
	var capture_viewport: SubViewport = null
	var capture_parent: Node = get_root()
	if offscreen:
		capture_viewport = SubViewport.new()
		capture_viewport.name = "MakeHuman载具驾驶探针离屏视口"
		capture_viewport.size = Vector2i(1280, 720)
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		capture_viewport.own_world_3d = true
		get_root().add_child(capture_viewport)
		capture_parent = capture_viewport
	var root := Node3D.new()
	root.name = "MakeHuman载具驾驶探针场景"
	capture_parent.add_child(root)
	_build_lighting(root)
	_build_floor(root)
	var results: Array[Dictionary] = []
	for item in CASES:
		var vehicle := vehicle_scene.instantiate() as Node3D
		vehicle.name = "真实三轮车候选_%s" % item["id"]
		vehicle.position = item["position"]
		vehicle.rotation.y = float(item["rotation_y"])
		root.add_child(vehicle)
		var visual := Node3D.new()
		visual.name = "驾驶玩家候选_%s" % item["id"]
		visual.set_script(visual_script)
		visual.position = vehicle.position + DRIVER_SEAT_OFFSET.rotated(Vector3.UP, vehicle.rotation.y)
		visual.rotation.y = vehicle.rotation.y
		var body := player_scene.instantiate() as Node3D
		body.name = "候选主角身体"
		# 角色正面朝向 -Z；三轮车前方同样为 -Z，探针相机从车辆后方观察。
		body.rotation.y = PI
		visual.add_child(body)
		root.add_child(visual)
		await process_frame
		await process_frame
		if not visual.has_method("drive_candidate_state"):
			push_error("载具驾驶探针缺少状态驱动方法：" + str(item["id"]))
			quit(1)
			return
		visual.drive_candidate_state("vehicle_default")
		visual.call("_process", 0.36)
		var hand_bones := _add_contact_markers(root, body, vehicle)
		_add_title(root, str(item["title"]), vehicle.position + Vector3(0.0, 2.62, 0.0))
		await process_frame
		var hand_positions := _read_hand_positions(body)
		var handlebar_positions := _read_handlebar_positions(vehicle)
		var seat_position_error := visual.global_position.distance_to(vehicle.to_global(DRIVER_SEAT_OFFSET))
		var hand_handlebar_error := _read_hand_handlebar_error(hand_positions, handlebar_positions)
		print("MAKEHUMAN_VEHICLE_CONTACT id=%s seat_error=%.4f hand_handlebar_error=%.4f" % [str(item["id"]), seat_position_error, hand_handlebar_error])
		results.append({
			"id": item["id"],
			"driver_seat_offset": [DRIVER_SEAT_OFFSET.x, DRIVER_SEAT_OFFSET.y, DRIVER_SEAT_OFFSET.z],
			"vehicle_rotation_y": item["rotation_y"],
			"player_state": "vehicle_default",
			"hand_bones_found": hand_bones,
			"hand_positions": hand_positions,
			"handlebar_positions": handlebar_positions,
			"contact_metrics": {
				"seat_position_error": seat_position_error,
				"hand_handlebar_error": hand_handlebar_error,
				"hand_handlebar_passed": hand_handlebar_error >= 0.0 and hand_handlebar_error <= 0.18,
				"measurement_only": true,
			},
			"animation_player": visual.get_node_or_null("AnimationPlayer") != null,
			"passed": true,
		})
	if OS.get_environment("MAKEHUMAN_VEHICLE_PROBE_VALIDATE_ONLY").strip_edges() == "1":
		_write_manifest(manifest_path, results, "candidate_makehuman_vehicle_seated_probe_measurement_only")
		root.free()
		if capture_viewport != null:
			capture_viewport.free()
		await process_frame
		quit(0)
		return
	var camera := Camera3D.new()
	camera.name = "MakeHuman载具驾驶探针相机"
	camera.fov = 38.0
	camera.position = Vector3(0.0, 3.25, 8.6)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.92, -0.30), Vector3.UP)
	camera.make_current()
	await process_frame
	await process_frame
	var viewport_texture := capture_viewport.get_texture() if offscreen else get_root().get_texture()
	var image: Image = viewport_texture.get_image() if viewport_texture != null else null
	if image == null or image.is_empty():
		push_error("载具驾驶探针截图为空")
		quit(1)
		return
	if image.save_png(output_path) != OK:
		push_error("载具驾驶探针截图写入失败")
		quit(1)
		return
	_write_manifest(manifest_path, results, "candidate_makehuman_vehicle_seated_probe_captured", output_path, "offscreen_subviewport" if offscreen else "graphical_window")
	print("MakeHuman 载具驾驶探针已生成：", output_path)
	root.free()
	if capture_viewport != null:
		capture_viewport.free()
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
	floor.position = Vector3(0.0, -0.40, -0.65)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("374047")
	material.roughness = 0.86
	floor.material_override = material
	root.add_child(floor)

func _add_title(root: Node3D, text: String, position: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color("f2e2bd")
	label.position = position
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)

func _add_contact_markers(root: Node3D, body: Node3D, vehicle: Node3D) -> Array[String]:
	var found: Array[String] = []
	var skeleton_nodes := body.find_children("*", "Skeleton3D", true, false)
	if not skeleton_nodes.is_empty():
		var skeleton := skeleton_nodes[0] as Skeleton3D
		for bone_name in ["hand_l", "hand_r"]:
			if skeleton.find_bone(bone_name) < 0:
				continue
			var attachment := BoneAttachment3D.new()
			attachment.name = "诊断手部挂点-" + bone_name
			attachment.bone_name = bone_name
			skeleton.add_child(attachment)
			_add_marker_sphere(attachment, "红色手部骨骼标记-" + bone_name, Color("ed5b63"), 0.075)
			found.append(bone_name)
	# 三轮车候选 GLB 的车把握持区位于横杆内侧，端点不是人体握持目标。
	for side in [-1.0, 1.0]:
		var handlebar_world := vehicle.to_global(Vector3(0.26 * side, 1.34, -0.80))
		_add_marker_sphere_at(root, "黄色车把握持区标记", handlebar_world, Color("f4ca52"), 0.06)
	return found

func _add_marker_sphere(parent: Node3D, marker_name: String, color: Color, radius: float) -> void:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	marker.mesh = mesh
	marker.material_override = _marker_material(color)
	parent.add_child(marker)

func _add_marker_sphere_at(root: Node3D, marker_name: String, position: Vector3, color: Color, radius: float) -> void:
	var marker := MeshInstance3D.new()
	marker.name = marker_name
	marker.position = position
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	marker.mesh = mesh
	marker.material_override = _marker_material(color)
	root.add_child(marker)

func _marker_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4
	return material

func _read_hand_positions(body: Node3D) -> Dictionary:
	var positions := {}
	for bone_name in ["hand_l", "hand_r"]:
		var attachment := body.find_child("诊断手部挂点-" + bone_name, true, false) as Node3D
		if attachment != null:
			var point := attachment.global_position
			positions[bone_name] = [point.x, point.y, point.z]
	return positions

func _read_handlebar_positions(vehicle: Node3D) -> Array:
	var positions: Array = []
	for side in [-1.0, 1.0]:
		var point := vehicle.to_global(Vector3(0.26 * side, 1.34, -0.80))
		positions.append([point.x, point.y, point.z])
	return positions

func _read_hand_handlebar_error(hand_positions: Dictionary, handlebar_positions: Array) -> float:
	if handlebar_positions.size() < 2 or not hand_positions.has("hand_l") or not hand_positions.has("hand_r"):
		return -1.0
	var left_hand := hand_positions["hand_l"] as Array
	var right_hand := hand_positions["hand_r"] as Array
	var first_handle := handlebar_positions[0] as Array
	var second_handle := handlebar_positions[1] as Array
	var left_point := Vector3(float(left_hand[0]), float(left_hand[1]), float(left_hand[2]))
	var right_point := Vector3(float(right_hand[0]), float(right_hand[1]), float(right_hand[2]))
	var first_point := Vector3(float(first_handle[0]), float(first_handle[1]), float(first_handle[2]))
	var second_point := Vector3(float(second_handle[0]), float(second_handle[1]), float(second_handle[2]))
	var direct_pair := left_point.distance_to(first_point) + right_point.distance_to(second_point)
	var swapped_pair := left_point.distance_to(second_point) + right_point.distance_to(first_point)
	return minf(direct_pair, swapped_pair) * 0.5

func _write_manifest(path: String, results: Array[Dictionary], status: String, image_path := "", capture_mode := "measurement_only") -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("载具驾驶探针清单写入失败")
		quit(1)
		return
	var payload := {
		"schema_version": 1,
		"status": status,
		"motion_policy": "gameplay_driven_in_place_animation",
		"driver_seat_offset": [DRIVER_SEAT_OFFSET.x, DRIVER_SEAT_OFFSET.y, DRIVER_SEAT_OFFSET.z],
		"visual_status": "unverified",
		"release_allowed": false,
		"capture_mode": capture_mode,
		"measurement_contract": {
			"seat_position_error_target": 0.001,
		"hand_handlebar_error_target": 0.18,
			"status": "measured_only",
		},
		"cases": results,
	}
	if not image_path.is_empty():
		payload["image"] = image_path
	file.store_string(JSON.stringify(payload))
	file.close()

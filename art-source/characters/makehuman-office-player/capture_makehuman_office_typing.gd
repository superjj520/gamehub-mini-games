extends SceneTree

## MakeHuman office-10 坐姿打字候选截图。
## 只用于候选视觉对照，不改变正式运行时和发布资产目录。

const OfficeScene = preload("res://scenes/benchmark.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var offscreen := OS.get_environment("MAKEHUMAN_OFFICE_TYPING_OFFSCREEN").strip_edges() == "1"
	if not offscreen and (DisplayServer.get_name() == "headless" or get_root().get_texture() == null):
		push_error("MakeHuman office-10 候选截图需要真实图形窗口")
		quit(2)
		return
	var user_args := OS.get_cmdline_user_args()
	var output_path := OS.get_environment("MAKEHUMAN_OFFICE_TYPING_OUTPUT").strip_edges()
	var manifest_path := OS.get_environment("MAKEHUMAN_OFFICE_TYPING_MANIFEST").strip_edges()
	if output_path.is_empty():
		output_path = _user_arg_value(user_args, "--output")
	if manifest_path.is_empty():
		manifest_path = _user_arg_value(user_args, "--manifest")
	if output_path.is_empty() or manifest_path.is_empty():
		push_error("缺少 MAKEHUMAN_OFFICE_TYPING_OUTPUT 或 MAKEHUMAN_OFFICE_TYPING_MANIFEST")
		quit(1)
		return
	var capture_viewport: SubViewport = null
	var capture_parent: Node = get_root()
	if offscreen:
		capture_viewport = SubViewport.new()
		capture_viewport.name = "MakeHuman办公室打字候选离屏视口"
		capture_viewport.size = Vector2i(1280, 720)
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		capture_viewport.own_world_3d = true
		get_root().add_child(capture_viewport)
		capture_parent = capture_viewport
	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("makehuman-office-typing-%d.json" % Time.get_ticks_usec()))
	# office-10 视频帧只承担清洁办公室远景；正式工位交互、typing_default、镜头和玩家仍走运行时。
	office.set_meta("candidate_video_backdrop", true)
	office.set_meta("candidate_video_backdrop_id", "office-10")
	capture_parent.add_child(office)
	await process_frame
	await process_frame
	assert(office.initialized, "MakeHuman office-10 候选办公室初始化失败")
	# 角色打字身体在 x=0、z=2.94 的原办公桌工位落座；该站位同时
	# 绑定正式 office-10 的椅面、键盘与桌面接触契约。
	office.player.position = Vector3(0.0, 1.0, 2.94)
	office.player.rotation_degrees.y = 0.0
	office.player.controlled_externally = true
	office.player.crouching = false
	office.player.sync_presentation_state(0.0)
	office.camera_rig.collision_mask = 0
	# 候选采集必须先走正式工位交互，再冻结画面；不能只调用表现层动画，
	# 否则镜头、玩家状态和事件轨迹可能与真实 office-10 运行路径分叉。
	var typing_input := InputFrameClass.new()
	typing_input.interact = true
	office.process_input_frame(typing_input, 0.016)
	assert(office.typing_mode, "MakeHuman office-10 候选没有通过正式工位交互进入打字状态")
	# 正式状态机已经从 runtime.office.typing_camera 设置距离、方位、俯仰
	# 和肩偏移；这里不再重新摆拍，避免候选预览与正式运行时出现第二套契约。
	var camera_probe := _camera_probe_from_args(user_args)
	if not camera_probe.is_empty():
		# 仅用于候选构图探针，不进入正式运行时契约；最终镜头仍需单独签收。
		if camera_probe.has("max_pitch_degrees"):
			office.camera_rig.max_pitch_degrees = float(camera_probe["max_pitch_degrees"])
		office.camera_rig.set_follow_profile(float(camera_probe.get("distance", office.camera_rig.distance)), float(camera_probe.get("height", office.camera_rig.height)))
		office.camera_rig.set_shoulder_offset(Vector3(float(camera_probe.get("shoulder_x", office.camera_rig.shoulder_offset.x)), office.camera_rig.shoulder_offset.y, office.camera_rig.shoulder_offset.z))
		office.camera_rig.set_orbit(float(camera_probe.get("yaw_degrees", office.camera_rig.yaw_degrees)), float(camera_probe.get("pitch_degrees", office.camera_rig.pitch_degrees)))
	office.prepare_reference_capture(false)
	assert(_drive_candidate_visual_state(office.player.get_node_or_null("Visual"), "typing_default"), "MakeHuman 玩家候选缺少 typing_default 状态")
	if not camera_probe.is_empty():
		if camera_probe.has("max_pitch_degrees"):
			office.camera_rig.max_pitch_degrees = float(camera_probe["max_pitch_degrees"])
		office.camera_rig.set_follow_profile(float(camera_probe.get("distance", office.camera_rig.distance)), float(camera_probe.get("height", office.camera_rig.height)))
		office.camera_rig.set_shoulder_offset(Vector3(float(camera_probe.get("shoulder_x", office.camera_rig.shoulder_offset.x)), office.camera_rig.shoulder_offset.y, office.camera_rig.shoulder_offset.z))
		office.camera_rig.set_orbit(float(camera_probe.get("yaw_degrees", office.camera_rig.yaw_degrees)), float(camera_probe.get("pitch_degrees", office.camera_rig.pitch_degrees)))
	for _frame in range(8):
		await process_frame
	if OS.get_environment("MAKEHUMAN_OFFICE_TYPING_VALIDATE_ONLY").strip_edges() == "1":
		var backdrop := office.find_child("用户授权办公室视频帧候选背景卡", true, false) as MeshInstance3D
		var backdrop_material := backdrop.material_override as StandardMaterial3D if backdrop != null else null
		var validation_file := FileAccess.open(manifest_path, FileAccess.WRITE)
		assert(validation_file != null, "MakeHuman office-10 配置验证清单写入失败")
		validation_file.store_string(JSON.stringify({
			"schema_version": 1,
			"status": "candidate_configuration_validation_only",
			"visual_status": "unverified",
			"release_allowed": false,
			"typing_mode": bool(office.typing_mode),
			"typing_state": "typing_default",
			"video_backdrop_enabled": bool(office.get_meta("candidate_video_backdrop", false)),
			"video_backdrop_id": str(office.get_meta("candidate_video_backdrop_id", "")),
			"video_backdrop_texture": str(backdrop_material.albedo_texture.resource_path) if backdrop_material != null and backdrop_material.albedo_texture != null else "",
			"video_backdrop_asset_source": str(backdrop.get_meta("asset_source", "")) if backdrop != null else "",
			"video_backdrop_rights_status": str(backdrop.get_meta("rights_status", "")) if backdrop != null else "",
			"reason": "当前运行没有可用图形根纹理；本报告只证明 office-10 正式工位交互、typing_default 与视频候选背景配置，不替代逐帧视觉验收。"
		}, "\t") + "\n")
		validation_file.close()
		assert(office.typing_mode, "MakeHuman office-10 配置验证没有保持 typing_mode")
		assert(backdrop != null and backdrop_material != null, "MakeHuman office-10 配置验证缺少视频背景卡")
		assert(str(backdrop_material.albedo_texture.resource_path).ends_with("office-10-video-playable-backdrop-v1.png"), "MakeHuman office-10 配置验证绑定了错误的视频背景")
		print("MakeHuman office-10 坐姿打字配置验证已生成：", manifest_path)
		office.queue_free()
		if capture_viewport != null:
			capture_viewport.free()
		quit(0)
		return
	var viewport_texture := capture_viewport.get_texture() if offscreen else get_root().get_texture()
	if viewport_texture == null:
		push_error("MakeHuman office-10 候选截图没有可用的图形纹理；当前渲染后端不支持离屏像素读取")
		office.queue_free()
		if capture_viewport != null:
			capture_viewport.free()
		quit(2)
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("MakeHuman office-10 候选截图没有可读取的像素；当前渲染后端返回空图像")
		office.queue_free()
		if capture_viewport != null:
			capture_viewport.free()
		quit(2)
		return
	assert(image.save_png(output_path) == OK, "MakeHuman office-10 候选截图写入失败")
	var player_visual := office.player.get_node_or_null("Visual") as Node3D
	var visual_debug := {
		"root_name": player_visual.name if player_visual != null else "",
		"visible": player_visual.visible if player_visual != null else false,
		"global_position": _vector3_to_array(player_visual.global_position) if player_visual != null else [],
		"global_scale": _vector3_to_array(player_visual.global_transform.basis.get_scale()) if player_visual != null else [],
		"child_count": player_visual.get_child_count() if player_visual != null else 0
	}
	var nearby_large_meshes: Array = []
	for mesh_node in office.find_children("*", "MeshInstance3D", true, false):
		var nearby_mesh := mesh_node as MeshInstance3D
		if nearby_mesh == null or nearby_mesh.mesh == null:
			continue
		if nearby_mesh.global_position.distance_to(office.player.global_position) > 4.5:
			continue
		var mesh_bounds := nearby_mesh.get_aabb()
		if mesh_bounds.size.x < 0.8 or mesh_bounds.size.y < 0.5:
			continue
		nearby_large_meshes.append({
			"path": str(nearby_mesh.get_path()),
			"visible": nearby_mesh.visible,
			"global_position": _vector3_to_array(nearby_mesh.global_position),
			"local_bounds_size": _vector3_to_array(mesh_bounds.size)
		})
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	assert(file != null, "MakeHuman office-10 候选清单写入失败")
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"status": "candidate_makehuman_office_typing_captured",
		"visual_status": "unverified",
		"release_allowed": false,
		"asset_catalog_path": "res://tests/asset-runtime-catalog-full-candidates.json",
		"state": "typing_default",
		"camera_contract": {
			"distance": office.camera_rig.distance,
			"height": office.camera_rig.height,
			"yaw_degrees": office.camera_rig.yaw_degrees,
			"pitch_degrees": office.camera_rig.pitch_degrees,
			"shoulder_offset": [office.camera_rig.shoulder_offset.x, office.camera_rig.shoulder_offset.y, office.camera_rig.shoulder_offset.z]
		},
		"runtime_debug": {
			"player_global_position": _vector3_to_array(office.player.global_position),
			"player_rotation_degrees": _vector3_to_array(office.player.rotation_degrees),
			"visual": visual_debug,
			"nearby_large_meshes": nearby_large_meshes,
			"active_workstation": office.active_workstation.interaction_id if office.active_workstation != null else "",
			"active_workstation_global_position": _vector3_to_array(office.active_workstation.global_position) if office.active_workstation != null else []
		},
		"camera_probe_override": camera_probe,
		"image": output_path,
		"capture_mode": "offscreen_subviewport" if offscreen else "graphical_window",
		"notes": "候选角色已使用真实 Skeleton3D 坐姿骨骼；不代表最终视觉、权利或目标设备通过"
	}, "\t"))
	file.close()
	office.queue_free()
	if capture_viewport != null:
		capture_viewport.free()
	await process_frame
	print("MakeHuman office-10 坐姿打字候选截图已生成：", output_path)
	quit(0)

func _drive_candidate_visual_state(root: Node, state_name: String) -> bool:
	if root == null:
		return false
	if root.has_method("drive_candidate_state"):
		root.call("drive_candidate_state", state_name)
		return true
	for child in root.get_children():
		if _drive_candidate_visual_state(child, state_name):
			return true
	return false

func _vector3_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _user_arg_value(args: PackedStringArray, key: String) -> String:
	for index in range(args.size() - 1):
		if args[index] == key:
			return args[index + 1].strip_edges()
	return ""

func _camera_probe_from_args(args: PackedStringArray) -> Dictionary:
	var probe := {}
	for item in [
		{"key": "--probe-yaw", "field": "yaw_degrees"},
		{"key": "--probe-pitch", "field": "pitch_degrees"},
		{"key": "--probe-max-pitch", "field": "max_pitch_degrees"},
		{"key": "--probe-height", "field": "height"},
		{"key": "--probe-distance", "field": "distance"},
		{"key": "--probe-shoulder-x", "field": "shoulder_x"}
	]:
		var raw := _user_arg_value(args, str(item["key"]))
		if not raw.is_empty():
			probe[str(item["field"])] = float(raw)
	return probe

extends SceneTree

## 使用 Godot MovieWriter 输出真实渲染帧。
## 不读取根视口纹理，因此可在无桌面显示环境中做图形证据采集。

const CityScene := preload("res://scenes/city.tscn")
const InputFrameClass := preload("res://scripts/input_frame.gd")
const CITY03_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-03-video-playable-backdrop-v1.png")
const CITY04_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-04-video-playable-backdrop-v1.png")
const CITY05_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-05-video-playable-backdrop-v1.png")
const CITY06_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-06-video-playable-backdrop-v1.png")
const CITY07_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-07-video-playable-backdrop-v1.png")
const CITY09_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-09-video-playable-backdrop-v1.png")
const CITY10_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-10-video-playable-backdrop-v1.png")
const CAPTURE_SIZE := Vector2i(1280, 720)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var capture_id := OS.get_environment("CITY_MOVIE_CAPTURE_ID").strip_edges()
	var offscreen := OS.get_environment("CITY_MOVIE_OFFSCREEN").strip_edges() == "1"
	var output_path := OS.get_environment("CITY_MOVIE_CAPTURE_OUTPUT").strip_edges()
	if not ["city-01", "city-03", "city-04", "city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11"].has(capture_id):
		push_error("缺少或不支持 CITY_MOVIE_CAPTURE_ID：" + capture_id)
		quit(1)
		return
	var capture_viewport: SubViewport = null
	var capture_parent: Node = root
	if offscreen:
		if output_path.is_empty():
			push_error("离屏城市采集缺少 CITY_MOVIE_CAPTURE_OUTPUT")
			quit(1)
			return
		capture_viewport = SubViewport.new()
		capture_viewport.name = "城市候选离屏采集视口"
		capture_viewport.size = CAPTURE_SIZE
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		capture_viewport.transparent_bg = false
		# 仅设置 own_world_3d 在当前 Godot/macOS 后端不会稳定地产生
		# 可读的渲染纹理；显式绑定 World3D，与离屏像素探针保持同一契约。
		capture_viewport.world_3d = World3D.new()
		root.add_child(capture_viewport)
		capture_parent = capture_viewport
	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", "res://art-source/city-full-kit-candidate/asset-runtime-catalog-city-full-kit-quaternius-override.json")
	city.set_meta("settings_path", OS.get_temp_dir().path_join("city-movie-capture-%s.json" % capture_id))
	city.set_meta("reference_capture_scenario", capture_id)
	if capture_id == "city-03":
		city.set_meta("candidate_video_backdrop", true)
		city.set_meta("candidate_video_backdrop_id", "city-03")
	elif capture_id == "city-05":
		city.set_meta("candidate_video_backdrop", true)
		city.set_meta("candidate_video_backdrop_id", "city-05")
	elif capture_id == "city-06":
		city.set_meta("candidate_video_backdrop", true)
		city.set_meta("candidate_video_backdrop_id", "city-06")
	elif capture_id == "city-07":
		city.set_meta("candidate_video_backdrop", true)
		city.set_meta("candidate_video_backdrop_id", "city-07")
	elif capture_id == "city-09":
		city.set_meta("candidate_video_backdrop", true)
		city.set_meta("candidate_video_backdrop_id", "city-09")
	elif capture_id == "city-10":
		city.set_meta("candidate_video_backdrop", true)
		city.set_meta("candidate_video_backdrop_id", "city-10")
	capture_parent.add_child(city)
	await process_frame
	await process_frame
	await process_frame
	if not city.initialized:
		push_error("城市候选场景初始化失败：" + capture_id)
		quit(1)
		return
	if capture_id == "city-01":
		city.player.position = Vector3(-9.0, 1.0, -3.7)
		city.player.rotation.y = 0.0
		_prepare_storefront_crowd(city)
		city.camera_rig.set_follow_profile(5.2, 2.3)
		city.camera_rig.set_orbit(0.0, -18.0)
		_set_fixed_camera(city, Vector3(-9.0, 4.8, -0.5), Vector3(-9.0, 2.0, -7.9))
	elif capture_id == "city-03":
		city.player.position = Vector3(-9.0, 0.9, -10.0)
		city.player.rotation.y = PI
		city.call("_update_navigation_zone")
		city.camera_rig.set_follow_profile(2.5, 1.75)
		city.camera_rig.set_orbit(180.0, -12.0)
		_set_city03_camera(city)
	elif capture_id == "city-04":
		if city.targets.size() > 0:
			city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
			var collect := InputFrameClass.new()
			collect.interact = true
			city.process_input_frame(collect, 0.016)
		city.conflict_agent.position = Vector3(-9.6, 0.9, -9.0)
		city.player.position = Vector3(-9.0, 0.9, -10.3)
		city.call("_update_navigation_zone")
		var attack := InputFrameClass.new()
		attack.attack = true
		city.process_input_frame(attack, 0.016)
		city.camera_rig.set_follow_profile(3.7, 1.9)
		city.camera_rig.set_orbit(0.0, -12.0)
		_set_city04_camera(city)
	elif capture_id == "city-05":
		if city.targets.size() > 0:
			city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
			var collect := InputFrameClass.new()
			collect.interact = true
			city.process_input_frame(collect, 0.016)
		if not city.inventory.has_item("egg_tray") or str(city.mission.current_stage().get("id", "")) != "leave_store":
			push_error("city-05 电影帧采集没有进入携带鸡蛋的离店阶段")
			quit(1)
			return
		city.player.position = Vector3(-9.0, 0.9, -6.2)
		city.player.rotation.y = PI
		city.call("_update_navigation_zone")
		var run := InputFrameClass.new()
		run.move = Vector2(0.0, 1.0)
		city.process_input_frame(run, 0.016)
		city.player.position = Vector3(-9.0, 0.9, -6.2)
		_set_city05_camera(city)
	elif capture_id == "city-06":
		if city.targets.size() > 1:
			city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
			var collect := InputFrameClass.new()
			collect.interact = true
			city.process_input_frame(collect, 0.016)
			city.player.position = city.targets[1].position + Vector3(0.0, 0.0, 1.0)
			var leave := InputFrameClass.new()
			leave.interact = true
			city.process_input_frame(leave, 0.016)
		if str(city.mission.current_stage().get("id", "")) != "register":
			push_error("city-06 电影帧采集没有进入扫码登记阶段")
			quit(1)
			return
		city.vehicle.position = Vector3(7.0, 0.7, 5.5)
		city.vehicle.rotation.y = PI
		city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
		var enter_register := InputFrameClass.new()
		enter_register.vehicle_enter_exit = true
		city.process_input_frame(enter_register, 0.016)
		if city.vehicle.driver != city.player:
			push_error("city-06 电影帧采集没有进入三轮车驾驶状态")
			quit(1)
			return
		_set_city06_camera(city)
	elif capture_id == "city-07":
		if city.targets.size() > 2:
			city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
			var collect_registered := InputFrameClass.new()
			collect_registered.interact = true
			city.process_input_frame(collect_registered, 0.016)
			city.player.position = city.targets[1].position + Vector3(0.0, 0.0, 1.0)
			var leave_registered := InputFrameClass.new()
			leave_registered.interact = true
			city.process_input_frame(leave_registered, 0.016)
			city.player.position = city.targets[2].position + Vector3(0.0, 0.0, 1.0)
			var scan_registered := InputFrameClass.new()
			scan_registered.interact = true
			city.process_input_frame(scan_registered, 0.016)
		_advance_registered_city_mission(city)
		if not bool(city.registered) or str(city.mission.current_stage().get("id", "")) != "new_shop":
			push_error("city-07 电影帧采集没有进入登记成功后的新店阶段")
			quit(1)
			return
		city.vehicle.position = Vector3(7.0, 0.7, 5.5)
		city.vehicle.rotation.y = PI
		city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
		var registered_enter := InputFrameClass.new()
		registered_enter.vehicle_enter_exit = true
		city.process_input_frame(registered_enter, 0.016)
		if city.vehicle.driver != city.player:
			push_error("city-07 电影帧采集没有进入登记成功后的三轮车驾驶状态")
			quit(1)
			return
		_set_city07_camera(city)
	elif capture_id == "city-09":
		if city.targets.size() > 2:
			city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
			var collect_driving := InputFrameClass.new()
			collect_driving.interact = true
			city.process_input_frame(collect_driving, 0.016)
			city.player.position = city.targets[1].position + Vector3(0.0, 0.0, 1.0)
			var leave_driving := InputFrameClass.new()
			leave_driving.interact = true
			city.process_input_frame(leave_driving, 0.016)
			city.player.position = city.targets[2].position + Vector3(0.0, 0.0, 1.0)
			var scan_driving := InputFrameClass.new()
			scan_driving.interact = true
			city.process_input_frame(scan_driving, 0.016)
		_advance_registered_city_mission(city)
		if not bool(city.registered) or str(city.mission.current_stage().get("id", "")) != "new_shop":
			push_error("city-09 电影帧采集没有进入登记成功后的新店阶段")
			quit(1)
			return
		city.vehicle.position = Vector3(1.0, 0.7, 1.0)
		city.vehicle.rotation.y = PI
		city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
		var enter_driving := InputFrameClass.new()
		enter_driving.vehicle_enter_exit = true
		city.process_input_frame(enter_driving, 0.016)
		if city.vehicle.driver != city.player:
			push_error("city-09 电影帧采集没有进入登记成功后的三轮车驾驶状态")
			quit(1)
			return
		var drive_registered := InputFrameClass.new()
		drive_registered.move = Vector2(0.0, -1.0)
		city.process_input_frame(drive_registered, 0.25)
		_set_city09_camera(city)
	elif capture_id == "city-10":
		if city.targets.size() > 2:
			city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
			var collect_rear_drive := InputFrameClass.new()
			collect_rear_drive.interact = true
			city.process_input_frame(collect_rear_drive, 0.016)
			city.player.position = city.targets[1].position + Vector3(0.0, 0.0, 1.0)
			var leave_rear_drive := InputFrameClass.new()
			leave_rear_drive.interact = true
			city.process_input_frame(leave_rear_drive, 0.016)
			city.player.position = city.targets[2].position + Vector3(0.0, 0.0, 1.0)
			var scan_rear_drive := InputFrameClass.new()
			scan_rear_drive.interact = true
			city.process_input_frame(scan_rear_drive, 0.016)
		_advance_registered_city_mission(city)
		if not bool(city.registered) or str(city.mission.current_stage().get("id", "")) != "new_shop":
			push_error("city-10 电影帧采集没有进入登记成功后的新店阶段")
			quit(1)
			return
		city.vehicle.position = Vector3(7.0, 0.7, 8.0)
		city.vehicle.rotation.y = PI
		city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
		var enter_rear_drive := InputFrameClass.new()
		enter_rear_drive.vehicle_enter_exit = true
		city.process_input_frame(enter_rear_drive, 0.016)
		if city.vehicle.driver != city.player:
			push_error("city-10 电影帧采集没有进入登记成功后的三轮车驾驶状态")
			quit(1)
			return
		var drive_rear := InputFrameClass.new()
		drive_rear.move = Vector2(0.0, -1.0)
		city.process_input_frame(drive_rear, 0.2)
		_set_city10_camera(city)
	elif capture_id == "city-08":
		city.vehicle.position = Vector3(-2.4, 0.7, 3.4)
		city.vehicle.rotation.y = PI
		city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
		var enter := InputFrameClass.new()
		enter.vehicle_enter_exit = true
		city.process_input_frame(enter, 0.016)
		if city.vehicle.driver != city.player:
			push_error("城市驾驶候选没有进入三轮车驾驶状态")
			quit(1)
			return
		var drive := InputFrameClass.new()
		drive.move = Vector2(0.0, -1.0)
		city.process_input_frame(drive, 0.25)
		_prepare_traffic_for_driving_capture(city)
		city.camera_rig.set_orbit(-20.0, -18.0)
		city.camera_rig.camera.make_current()
	else:
		city.player.position = Vector3(10.0, 1.0, 14.0)
		city.player.rotation.y = PI
		city.vehicle.position = Vector3(10.0, 0.7, 14.0)
		city.vehicle.rotation.y = PI
		city.camera_rig.set_follow_profile(5.2, 2.3)
		city.camera_rig.set_orbit(0.0, -18.0)
		_set_fixed_camera(city, Vector3(7.5, 3.5, 18.0), Vector3(10.0, 1.7, 13.4))
	city.camera_rig.collision_mask = 0
	city.camera_rig.set_follow_profile(city.camera_rig.distance, city.camera_rig.height)
	_hide_dynamic_actors(city, capture_id)
	city.prepare_reference_capture(false)
	await process_frame
	await process_frame
	await process_frame
	if capture_id == "city-06" or capture_id == "city-07":
		# 参考冻结会清理纯视觉节点；扫码牌和登记员属于该两段的正式前景锚点，候选电影采集态显式恢复。
		var scan_board: Node = city.find_child("扫码登记牌", true, false)
		var clerk: Node = city.find_child("登记员", true, false)
		if scan_board != null:
			scan_board.visible = true
		if clerk != null:
			clerk.visible = true
	if offscreen:
		# 无头后端可能不发出 frame_post_draw；项目内离屏探针使用普通帧同步，
		# 仍然从真实 SubViewport 纹理读取像素。
		await process_frame
		await process_frame
		var viewport_texture := capture_viewport.get_texture() if capture_viewport != null else null
		var image: Image = viewport_texture.get_image() if viewport_texture != null else null
		if image == null or image.is_empty():
			push_error("城市候选离屏采集像素为空：" + capture_id)
			quit(1)
			return
		if image.save_png(output_path) != OK:
			push_error("城市候选离屏采集 PNG 写入失败：" + capture_id)
			quit(1)
			return
		print("CITY_OFFSCREEN_CAPTURE_META id=%s width=%d height=%d" % [capture_id, image.get_width(), image.get_height()])
		capture_viewport.free()
		await process_frame
		quit(0)
		return
	# 非离屏模式由命令行 --quit-after 控制输出帧数，保持引擎 MovieWriter 有足够时间写 PNG。

func _set_fixed_camera(city, at: Vector3, target: Vector3) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 55.0
	city.add_child(camera)
	camera.global_position = at
	camera.look_at(target, Vector3.UP)
	camera.make_current()

func _set_city03_camera(city) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 58.0
	city.add_child(camera)
	camera.global_position = Vector3(-9.0, 2.15, -5.25)
	camera.look_at(Vector3(-9.0, 1.20, -10.95), Vector3.UP)
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(25.60, 14.40)
	var background := MeshInstance3D.new()
	background.name = "原创城市超市通道背景卡"
	background.mesh = background_mesh
	camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY03_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	camera.make_current()

func _set_city04_camera(city) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 58.0
	city.add_child(camera)
	camera.global_position = Vector3(-9.0, 2.15, -13.65)
	camera.look_at(Vector3(-9.45, 1.18, -9.05), Vector3.UP)
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(25.60, 14.40)
	var background := MeshInstance3D.new()
	background.name = "原创城市超市冲突背景卡"
	background.mesh = background_mesh
	camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY04_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	camera.make_current()

func _set_city05_camera(city) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 58.0
	city.add_child(camera)
	camera.global_position = Vector3(-9.0, 3.10, -10.80)
	camera.look_at(Vector3(-9.0, 1.15, -5.05), Vector3.UP)
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(25.60, 14.40)
	var background := MeshInstance3D.new()
	background.name = "原创城市黄昏离店背景卡"
	background.mesh = background_mesh
	camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY05_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	camera.make_current()

func _set_city06_camera(city) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 56.0
	city.add_child(camera)
	camera.global_position = Vector3(4.7, 2.65, 8.65)
	camera.look_at(Vector3(8.15, 1.20, 5.35), Vector3.UP)
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(25.60, 14.40)
	var background := MeshInstance3D.new()
	background.name = "原创城市黄昏扫码登记背景卡"
	background.mesh = background_mesh
	camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY06_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	camera.make_current()

func _set_city07_camera(city) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 56.0
	city.add_child(camera)
	camera.global_position = Vector3(4.7, 2.65, 8.65)
	camera.look_at(Vector3(8.15, 1.20, 5.35), Vector3.UP)
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(25.60, 14.40)
	var background := MeshInstance3D.new()
	background.name = "原创城市黄昏登记成功背景卡"
	background.mesh = background_mesh
	camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY07_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	camera.make_current()

func _set_city09_camera(city) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 60.0
	city.add_child(camera)
	camera.global_position = Vector3(-3.8, 3.0, 6.2)
	camera.look_at(Vector3(1.0, 1.15, 1.0), Vector3.UP)
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(25.60, 14.40)
	var background := MeshInstance3D.new()
	background.name = "原创城市黄昏行驶运动模糊背景卡"
	background.mesh = background_mesh
	camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY09_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	camera.make_current()

func _set_city10_camera(city) -> void:
	var camera := Camera3D.new()
	camera.name = "候选电影帧镜头"
	camera.fov = 58.0
	city.add_child(camera)
	var vehicle := city.get("vehicle") as Node3D
	if vehicle == null:
		camera.queue_free()
		return
	var forward := -vehicle.global_transform.basis.z
	var backward := vehicle.global_transform.basis.z
	camera.global_position = vehicle.global_position + backward * 7.0 + Vector3(0.0, 3.0, 0.0)
	camera.look_at(vehicle.global_position + forward * 13.0 + Vector3(0.0, 1.1, 0.0), Vector3.UP)
	var background_mesh := QuadMesh.new()
	background_mesh.size = Vector2(25.60, 14.40)
	var background := MeshInstance3D.new()
	background.name = "原创城市黄昏车尾跟拍背景卡"
	background.mesh = background_mesh
	camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY10_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	camera.make_current()

func _hide_dynamic_actors(city, capture_id: String) -> void:
	for pedestrian in city.pedestrians:
		pedestrian.visible = capture_id in ["city-01", "city-08"]
	for blocker in city.crowd_blockers:
		blocker.visible = capture_id == "city-01"
	if is_instance_valid(city.conflict_agent):
		city.conflict_agent.visible = capture_id == "city-04"
	for traffic in city.traffic_vehicles:
		traffic.visible = capture_id == "city-08"
	city.player.visible = true
	city.vehicle.visible = capture_id in ["city-06", "city-07", "city-08", "city-09", "city-10", "city-11"]

func _prepare_storefront_crowd(city) -> void:
	var positions := [Vector3(-11.1, 0.9, -6.4), Vector3(-9.6, 0.9, -6.0), Vector3(-8.1, 0.9, -6.2), Vector3(-6.8, 0.9, -6.5)]
	for index in range(mini(city.pedestrians.size(), positions.size())):
		city.pedestrians[index].position = positions[index]
		city.pedestrians[index].rotation.y = PI

func _prepare_traffic_for_driving_capture(city) -> void:
	var traffic_list: Array = city.traffic_vehicles
	if traffic_list.is_empty():
		return
	traffic_list[0].global_position = Vector3(-2.0, 0.55, 10.5)
	traffic_list[0].rotation.y = PI
	if traffic_list.size() > 1:
		traffic_list[1].global_position = Vector3(2.0, 0.55, 7.5)
		traffic_list[1].rotation.y = 0.0

func _advance_registered_city_mission(city) -> void:
	# 参考视频的登记成功构图需要保留“登记完成后新店阶段”语义；
	# 当前正式任务在登记后还包含进入后场和装货两步，这里按真实交互推进，
	# 不直接篡改任务状态，保证候选采集与正式玩法使用同一状态机。
	for target_index in [3, 4]:
		if city.targets.size() <= target_index:
			return
		city.player.position = city.targets[target_index].position + Vector3(0.0, 0.0, 1.0)
		var advance_frame := InputFrameClass.new()
		advance_frame.interact = true
		city.process_input_frame(advance_frame, 0.016)

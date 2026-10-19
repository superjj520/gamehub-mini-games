extends SceneTree

## 城市店铺候选双构图采集：只读取外置候选目录，不修改正式运行时。

const CityScene := preload("res://scenes/city.tscn")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const CITY02_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-02-video-playable-backdrop-v1.png")
const CITY03_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-03-video-playable-backdrop-v1.png")
const CITY05_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-05-video-playable-backdrop-v1.png")
const CITY06_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-06-video-playable-backdrop-v1.png")
const CITY07_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-07-video-playable-backdrop-v1.png")
const CITY08_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-08-video-playable-backdrop-v1.png")
const CITY09_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-09-video-playable-backdrop-v1.png")
const CITY10_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-10-video-playable-backdrop-v1.png")
const CITY11_VIDEO_PLAYABLE_TEXTURE := preload("res://art-source/city-full-kit-candidate/reference-video-candidate/city-11-video-playable-backdrop-v1.png")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var validation_only := OS.get_environment("CITY_CANDIDATE_CAPTURE_VALIDATE_ONLY").strip_edges() == "1"
	if not validation_only and (DisplayServer.get_name() == "headless" or get_root().get_texture() == null):
		push_error("城市候选截图需要可用的图形根视口；当前为无头或无根纹理运行")
		quit(2)
		return
	var output_dir := OS.get_environment("CITY_CANDIDATE_CAPTURE_DIR").strip_edges()
	var catalog_path := OS.get_environment("CITY_CANDIDATE_CATALOG").strip_edges()
	if catalog_path.is_empty():
		catalog_path = "res://../art-source/city-full-kit-candidate/asset-runtime-catalog-city-full-kit-quaternius-override.json"
	if output_dir.is_empty() and validation_only:
		output_dir = ProjectSettings.globalize_path("res://../reference-evidence/candidate-runtime")
	if output_dir.is_empty():
		push_error("缺少 CITY_CANDIDATE_CAPTURE_DIR")
		quit(1)
		return
	var validation_records: Array[Dictionary] = []
	var supported_capture_ids := ["city-01", "city-02", "city-03", "city-04", "city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11"]
	var requested_capture_id := OS.get_environment("CITY_CANDIDATE_CAPTURE_FILTER").strip_edges()
	if not requested_capture_id.is_empty():
		assert(supported_capture_ids.has(requested_capture_id), "不支持的城市候选采集段：" + requested_capture_id)
	var capture_ids := [requested_capture_id] if not requested_capture_id.is_empty() else supported_capture_ids
	for capture_id in capture_ids:
		var city = CityScene.instantiate()
		city.set_meta("asset_catalog_path", catalog_path)
		city.set_meta("settings_path", OS.get_temp_dir().path_join("city-storefront-candidate-%s.json" % capture_id))
		if capture_id == "city-01":
			# 用户授权的 AI 视频帧编辑版只作为 city-01 隔离候选背景；不进入正式发布资产。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-01")
		elif capture_id == "city-02":
			# city-02 使用用户授权的清洁人群围堵帧；玩家、人群和免费鸡蛋任务仍由正式运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-02")
		elif capture_id == "city-03":
			# city-03 使用用户授权的清洁超市通道帧；玩家、碰撞、导航和任务状态仍由正式运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-03")
		elif capture_id == "city-04":
			# city-04 使用用户授权的清洁超市冲突帧；冲突代理、攻击输入、通缉和任务状态仍由正式运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-04")
		elif capture_id == "city-05":
			# city-05 使用用户授权的黄昏离店帧；携带鸡蛋、离店阶段、奔跑玩家和 HUD 仍由正式运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-05")
		elif capture_id == "city-06":
			# city-06 使用用户授权的黄昏扫码登记帧；三轮车、登记牌、登记员、任务状态和 HUD 仍由正式运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-06")
		elif capture_id == "city-07":
			# city-07 使用用户授权的登记成功帧；注册成功反馈、三轮车、登记牌、登记员和 HUD 仍由正式运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-07")
		elif capture_id == "city-08":
			# city-08 使用同一参考视频的清洁道路帧，车辆、玩家和交通仍由运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-08")
		elif capture_id == "city-09":
			# city-09 使用用户授权的黄昏侧后方行驶帧，车辆、玩家、输入和 HUD 仍由运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-09")
		elif capture_id == "city-10":
			# city-10 使用用户授权的黄昏车尾跟拍帧，车辆、玩家、导航和 HUD 仍由运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-10")
		elif capture_id == "city-11":
			# city-11 使用用户授权的清洁终点门面帧；玩家、三轮车和任务交互仍由正式运行时叠加。
			city.set_meta("candidate_video_backdrop", true)
			city.set_meta("candidate_video_backdrop_id", "city-11")
		# 运行时的参考采集清理、动态实体可见性和分段背景卡都依赖这个
		# 分段身份；没有它时 city-08 会把交通误判为不可见，city-11
		# 也不会执行对应的灰盒与遮挡清理。该元数据只作用于隔离候选采集。
		city.set_meta("reference_capture_scenario", capture_id)
		root.add_child(city)
		await process_frame
		await process_frame
		await process_frame
		if not city.initialized:
			push_error("城市候选场景初始化失败：" + capture_id)
			quit(1)
			return
		if capture_id == "city-01" or capture_id == "city-02":
			# 站在正式 city-01 的街道侧，保留整面原创门头与入口层次。
			city.player.position = Vector3(-9.0, 1.0, -3.7)
			city.player.rotation.y = 0.0
			_prepare_storefront_crowd(city)
			city.camera_rig.set_follow_profile(5.2, 2.3)
			city.camera_rig.set_orbit(0.0, -18.0)
		elif capture_id == "city-03":
			# city-03 必须先进入正式导航区域，保证店内可见性、镜头档位和任务上下文都来自真实运行时。
			city.player.position = Vector3(-9.0, 0.9, -10.0)
			city.player.rotation.y = PI
			city.call("_update_navigation_zone")
			city.camera_rig.set_follow_profile(2.5, 1.75)
			city.camera_rig.set_orbit(180.0, -12.0)
		elif capture_id == "city-04":
			# 复用正式 city-04 的任务交互与冲突回放，再把角色摆到室内后肩冲突构图。
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
		elif capture_id == "city-05":
			# 复用正式免费鸡蛋任务：先在目标点完成领取，再进入离店阶段，
			# 最后把玩家放到街道中段，复现参考视频中的携带物奔跑状态。
			if city.targets.size() > 0:
				city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
				var collect := InputFrameClass.new()
				collect.interact = true
				city.process_input_frame(collect, 0.016)
			if not city.inventory.has_item("egg_tray") or str(city.mission.current_stage().get("id", "")) != "leave_store":
				push_error("city-05 候选没有进入携带鸡蛋的离店阶段")
				quit(1)
				return
			city.player.position = Vector3(-9.0, 0.9, -6.2)
			city.player.rotation.y = PI
			city.call("_update_navigation_zone")
			var run := InputFrameClass.new()
			run.move = Vector2(0.0, 1.0)
			city.process_input_frame(run, 0.016)
			city.player.position = Vector3(-9.0, 0.9, -6.2)
			city.camera_rig.set_follow_profile(4.6, 2.15)
			city.camera_rig.set_orbit(180.0, -14.0)
		elif capture_id == "city-06":
			# 复用正式任务的领取、离店和扫码登记阶段，再进入真实三轮车驾驶状态。
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
				push_error("city-06 候选没有进入扫码登记阶段")
				quit(1)
				return
			city.vehicle.position = Vector3(7.0, 0.7, 5.5)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var enter_register := InputFrameClass.new()
			enter_register.vehicle_enter_exit = true
			city.process_input_frame(enter_register, 0.016)
			if city.vehicle.driver != city.player:
				push_error("city-06 候选没有进入三轮车驾驶状态")
				quit(1)
				return
			city.camera_rig.set_follow_profile(5.2, 2.3)
			city.camera_rig.set_orbit(-20.0, -18.0)
		elif capture_id == "city-07":
			# 复用正式任务的领取、离店、扫码登记和成功反馈阶段，再进入真实三轮车驾驶状态。
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
				push_error("city-07 候选没有进入登记成功后的新店阶段")
				quit(1)
				return
			city.vehicle.position = Vector3(7.0, 0.7, 5.5)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var registered_enter := InputFrameClass.new()
			registered_enter.vehicle_enter_exit = true
			city.process_input_frame(registered_enter, 0.016)
			if city.vehicle.driver != city.player:
				push_error("city-07 候选没有进入登记成功后的三轮车驾驶状态")
				quit(1)
				return
			city.camera_rig.set_follow_profile(5.2, 2.3)
			city.camera_rig.set_orbit(-20.0, -18.0)
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
			# city-08 是街道驾驶中远景：保留道路透视、前方交通和驾驶员肩后关系。
			# 旧值会把镜头压到车体近景，导致车辆占比过大、街道层次和速度感消失。
			# 参考 city-08 是车辆正后方的街道中线构图；先前的偏航角把右侧
			# 建筑和路缘挤到画面外，车辆也失去“沿街配送”的空间关系。
			# 参考帧把三轮车压在画面下方中央，前方道路和交通纵深必须占据更大比例；
			# 这里仅调整候选采集态，正式驾驶相机仍由运行时内容包控制。
			city.camera_rig.set_follow_profile(6.4, 2.2)
			city.camera_rig.set_orbit(0.0, -12.0)
			city.camera_rig.camera.make_current()
		elif capture_id == "city-09":
			# city-09 是登记完成后的黄昏侧后方行驶镜头，严格复用正式登记状态，
			# 再推进一帧驾驶输入以保留速度与运动模糊语义。
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
				push_error("city-09 候选没有进入登记成功后的新店阶段")
				quit(1)
				return
			city.vehicle.position = Vector3(1.0, 0.7, 1.0)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var enter_driving := InputFrameClass.new()
			enter_driving.vehicle_enter_exit = true
			city.process_input_frame(enter_driving, 0.016)
			if city.vehicle.driver != city.player:
				push_error("city-09 候选没有进入登记成功后的三轮车驾驶状态")
				quit(1)
				return
			var drive_registered := InputFrameClass.new()
			drive_registered.move = Vector2(0.0, -1.0)
			city.process_input_frame(drive_registered, 0.25)
			city.camera_rig.set_follow_profile(5.8, 2.4)
			city.camera_rig.set_orbit(-20.0, -14.0)
		elif capture_id == "city-10":
			# city-10 是登记完成后的车尾跟拍镜头，复用正式三次交互、驾驶进入和推进输入。
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
				push_error("city-10 候选没有进入登记成功后的新店阶段")
				quit(1)
				return
			city.vehicle.position = Vector3(7.0, 0.7, 8.0)
			city.vehicle.rotation.y = PI
			city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
			var enter_rear_drive := InputFrameClass.new()
			enter_rear_drive.vehicle_enter_exit = true
			city.process_input_frame(enter_rear_drive, 0.016)
			if city.vehicle.driver != city.player:
				push_error("city-10 候选没有进入登记成功后的三轮车驾驶状态")
				quit(1)
				return
			var drive_rear := InputFrameClass.new()
			drive_rear.move = Vector2(0.0, -1.0)
			city.process_input_frame(drive_rear, 0.2)
			city.camera_rig.set_follow_profile(6.0, 2.3)
			city.camera_rig.set_orbit(0.0, -12.0)
		else:
			# 站在目标门面外的街道，避免镜头进入建筑碰撞体。
			city.player.position = Vector3(10.0, 1.0, 7.6)
			city.player.rotation.y = PI
			_prepare_endpoint_vehicle(city)
			var enter_endpoint := InputFrameClass.new()
			enter_endpoint.vehicle_enter_exit = true
			city.process_input_frame(enter_endpoint, 0.016)
			if city.vehicle.driver != city.player:
				push_error("城市终点候选采集没有进入三轮车驾驶状态")
				quit(1)
				return
			city.camera_rig.set_follow_profile(5.2, 2.3)
			city.camera_rig.set_orbit(0.0, -18.0)
		# 这是候选资产的构图采集，不修改正式运行时；关闭采集帧的镜头碰撞，
		# 避免灰盒终点碰撞体把候选门面完全遮掉。
		city.camera_rig.collision_mask = 0
		city.camera_rig.set_follow_profile(city.camera_rig.distance, city.camera_rig.height)
		_hide_dynamic_actors(city, capture_id)
		_set_candidate_preview_camera(city, capture_id)
		if capture_id == "city-02":
			# city-02 与 city-01 共用店铺前景结构，但必须使用自己的
			# 人群围堵参考帧，不能让配置报告回落到 city-01。
			_force_city02_authorized_background(city)
			if capture_id == "city-11":
				_force_city11_authorized_background(city)
		if capture_id == "city-01" or capture_id == "city-02" or capture_id == "city-03" or capture_id == "city-04" or capture_id == "city-05" or capture_id == "city-06":
			# city-01 的视频帧候选背景是世界空间店铺卡；若场景中已有驾驶预览远景板，
			# 只在本次隔离采集里关闭它，避免两个候选背景互相覆盖。
			var city01_preview_background := city.find_child("候选城市驾驶世界远景板", true, false) as MeshInstance3D
			if city01_preview_background != null:
				city01_preview_background.visible = false
		# 锁定逐段候选相机，防止环境候选的每帧默认档位覆盖参考构图。
		city.set_meta("candidate_capture_camera_lock", true)
		city.prepare_reference_capture(false)
		if capture_id == "city-01" or capture_id == "city-02" or capture_id == "city-03" or capture_id == "city-04" or capture_id == "city-05" or capture_id == "city-06" or capture_id == "city-07" or capture_id == "city-09" or capture_id == "city-10" or capture_id == "city-11":
			var segment_background_name: String = "原创城市终点傍晚街道背景卡" if capture_id == "city-11" else "原创城市首店人群写实背景卡"
			if capture_id == "city-03":
				segment_background_name = "原创城市超市通道背景卡"
			if capture_id == "city-04":
				segment_background_name = "原创城市超市冲突背景卡"
			if capture_id == "city-05":
				segment_background_name = "原创城市黄昏离店背景卡"
			if capture_id == "city-06":
				segment_background_name = "原创城市黄昏扫码登记背景卡"
			if capture_id == "city-07":
				segment_background_name = "原创城市黄昏登记成功背景卡"
			if capture_id == "city-09":
				segment_background_name = "原创城市黄昏行驶运动模糊背景卡"
			if capture_id == "city-10":
				segment_background_name = "原创城市黄昏车尾跟拍背景卡"
			var segment_background: MeshInstance3D = city.find_child(segment_background_name, true, false) as MeshInstance3D
			if segment_background != null:
				# 参考采集冻结会清理正式运行时的候选卡；候选隔离采集需要在
				# 冻结之后恢复当前分段的唯一背景卡，避免灰盒层抢占画面。
				segment_background.visible = true
		if capture_id == "city-08":
			# 候选驾驶参考卡是验收用的清晰构图层；正式运行时的体积雾会把
			# 远景卡二次处理成整体虚焦，无法判断道路透视、交通和车辆轮廓。
			# 仅在候选截图中关闭雾效，不改变正式驾驶场景的氛围配置。
			_disable_candidate_capture_fog(city)
			_hide_city08_graybox_occluders(city)
			_mount_city08_world_background(city)
			_force_city08_authorized_background(city)
		await process_frame
		await process_frame
		await process_frame
		if capture_id == "city-02":
			_force_city02_authorized_background(city)
		if capture_id == "city-11":
			_force_city11_authorized_background(city)
		if capture_id == "city-08":
			# 环境候选在三帧稳定过程中可能重新创建远景板；最后一次显式
			# 校准保证配置报告与实际 city-08 绑定同一授权候选帧。
			_force_city08_authorized_background(city)
		if capture_id == "city-01" or capture_id == "city-02" or capture_id == "city-03" or capture_id == "city-04" or capture_id == "city-05" or capture_id == "city-06" or capture_id == "city-07" or capture_id == "city-09" or capture_id == "city-10" or capture_id == "city-11":
			var settled_background_name: String = "原创城市终点傍晚街道背景卡" if capture_id == "city-11" else "原创城市首店人群写实背景卡"
			if capture_id == "city-03":
				settled_background_name = "原创城市超市通道背景卡"
			if capture_id == "city-04":
				settled_background_name = "原创城市超市冲突背景卡"
			if capture_id == "city-05":
				settled_background_name = "原创城市黄昏离店背景卡"
			if capture_id == "city-06":
				settled_background_name = "原创城市黄昏扫码登记背景卡"
			if capture_id == "city-07":
				settled_background_name = "原创城市黄昏登记成功背景卡"
			if capture_id == "city-09":
				settled_background_name = "原创城市黄昏行驶运动模糊背景卡"
			if capture_id == "city-10":
				settled_background_name = "原创城市黄昏车尾跟拍背景卡"
			var settled_background: MeshInstance3D = city.find_child(settled_background_name, true, false) as MeshInstance3D
			if settled_background != null:
				# 等待运行时完成三帧稳定后再次恢复背景卡，避免场景脚本在
				# _process 中重新套用正式运行时的可见性策略。
				settled_background.visible = true
			if capture_id == "city-11":
				_finalize_city11_capture_layers(city, settled_background)
			if capture_id == "city-06" or capture_id == "city-07":
				# 参考冻结会清理未登记的纯视觉节点；扫码牌和登记员是
				# city-06 的正式前景交互锚点，候选采集态显式恢复它们。
				var settled_scan_board: Node = city.find_child("扫码登记牌", true, false)
				var settled_clerk: Node = city.find_child("登记员", true, false)
				if settled_scan_board != null:
					settled_scan_board.visible = true
				if settled_clerk != null:
					settled_clerk.visible = true
		if capture_id == "city-08":
			# 正式冻结流程会隐藏交通根节点；候选驾驶参考需要恢复前方交通纵深，
			# 这里只改临时采集场景的渲染可见性，不恢复交通物理或路线调度。
			_restore_city08_traffic_visibility(city)
			_freeze_city08_capture_updates(city)
			_finalize_city08_capture_layers(city)
			await process_frame
		if validation_only:
			var validation_record := _build_candidate_validation_record(city, capture_id)
			if capture_id == "city-08" and int(validation_record["traffic"]["visible"]) < 2:
				push_error("city-08 候选配置没有保留至少两辆前方交通车辆：" + JSON.stringify(validation_record))
				city.queue_free()
				quit(1)
				return
			if capture_id == "city-11" and int(validation_record["capture_render_layers"]["visible_non_dynamic_meshes"]) != 0:
				push_error("city-11 候选配置仍有未冻结的非动态城市网格：" + JSON.stringify(validation_record))
				city.queue_free()
				quit(1)
				return
			validation_records.append(validation_record)
			city.queue_free()
			await process_frame
			continue
		var texture := get_root().get_texture()
		if texture == null:
			push_error("城市候选截图没有窗口纹理：" + capture_id)
			quit(1)
			return
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			push_error("城市候选截图为空：" + capture_id)
			quit(1)
			return
		var output_path := output_dir.path_join("city-storefront-candidate-%s.png" % capture_id)
		if image.save_png(output_path) != OK or not FileAccess.file_exists(output_path):
			push_error("城市候选截图写入失败：" + capture_id)
			quit(1)
			return
		print("CITY_STOREFRONT_CAPTURE_META id=%s width=%d height=%d" % [capture_id, image.get_width(), image.get_height()])
		city.queue_free()
		await process_frame
	if validation_only:
		DirAccess.make_dir_recursive_absolute(output_dir)
		var validation_path := output_dir.path_join("city-storefront-candidate-validation.json")
		var validation_payload := {
			"schema_version": 1,
			"status": "candidate_configuration_validation_only",
			"visual_status": "unverified",
			"release_allowed": false,
			"graphics_capture_performed": false,
			"reason": "当前运行没有可用图形根纹理；本报告只证明候选场景配置，不替代逐帧视觉验收。",
			"captures": validation_records,
		}
		var validation_file := FileAccess.open(validation_path, FileAccess.WRITE)
		if validation_file == null:
			push_error("城市候选配置验证报告写入失败：" + validation_path)
			quit(1)
			return
		validation_file.store_string(JSON.stringify(validation_payload, "\t") + "\n")
		validation_file.close()
		print("CITY_STOREFRONT_CONFIGURATION_VALIDATION path=%s captures=%d" % [validation_path, validation_records.size()])
	quit(0)

func _build_candidate_validation_record(city, capture_id: String) -> Dictionary:
	var visual_root := city.get_node_or_null("Visual") as Node3D
	var drive_background := visual_root.find_child("原创城市驾驶街道背景卡", true, false) as MeshInstance3D if visual_root != null else null
	var preview_camera := city.find_child("候选资产验收预览镜头", true, false) as Camera3D
	var capture_camera: Camera3D = preview_camera if preview_camera != null else city.camera_rig.camera
	var preview_background: Node = city.find_child("候选城市驾驶世界远景板", true, false)
	var city03_preview_background := city.find_child("原创城市超市通道背景卡", true, false) as MeshInstance3D
	var city04_preview_background := city.find_child("原创城市超市冲突背景卡", true, false) as MeshInstance3D
	var city05_preview_background := city.find_child("原创城市黄昏离店背景卡", true, false) as MeshInstance3D
	var city06_preview_background := city.find_child("原创城市黄昏扫码登记背景卡", true, false) as MeshInstance3D
	var city07_preview_background := city.find_child("原创城市黄昏登记成功背景卡", true, false) as MeshInstance3D
	var city09_preview_background := city.find_child("原创城市黄昏行驶运动模糊背景卡", true, false) as MeshInstance3D
	var city10_preview_background := city.find_child("原创城市黄昏车尾跟拍背景卡", true, false) as MeshInstance3D
	var segment_background_name: String = str({
		"city-01": "原创城市首店人群写实背景卡",
		"city-02": "原创城市首店人群写实背景卡",
		"city-05": "原创城市黄昏离店背景卡",
		"city-06": "原创城市黄昏扫码登记背景卡",
		"city-07": "原创城市黄昏登记成功背景卡",
		"city-09": "原创城市黄昏行驶运动模糊背景卡",
		"city-10": "原创城市黄昏车尾跟拍背景卡",
		"city-11": "原创城市终点傍晚街道背景卡",
	}.get(capture_id, ""))
	var segment_background: MeshInstance3D = city.find_child(segment_background_name, true, false) as MeshInstance3D if not segment_background_name.is_empty() else null
	var use_video_playable_backdrop := bool(city.get_meta("candidate_video_backdrop", false))
	var effective_background: Node = city03_preview_background if capture_id == "city-03" and city03_preview_background != null else city04_preview_background if capture_id == "city-04" and city04_preview_background != null else city05_preview_background if capture_id == "city-05" and city05_preview_background != null else city06_preview_background if capture_id == "city-06" and city06_preview_background != null else city07_preview_background if capture_id == "city-07" and city07_preview_background != null else city09_preview_background if capture_id == "city-09" and city09_preview_background != null else city10_preview_background if capture_id == "city-10" and city10_preview_background != null else segment_background if use_video_playable_backdrop and segment_background != null else preview_background if preview_background != null else segment_background if segment_background != null else drive_background
	var drive_material := effective_background.material_override as StandardMaterial3D if effective_background is MeshInstance3D else null
	var effective_texture_path := str(effective_background.get_meta("capture_texture_path", "")) if effective_background != null else ""
	if effective_texture_path.is_empty() and drive_material != null and drive_material.albedo_texture != null:
		effective_texture_path = str(drive_material.albedo_texture.resource_path)
	var traffic_visible_count := 0
	var traffic_visible_mesh_count := 0
	var traffic_candidate_visual_count := 0
	var drive_foreground_mesh_count := 0
	var storefront_foreground_person_count := 0
	var storefront_foreground_mesh_count := 0
	var store_interior_node_count := 0
	var store_interior_visible_node_count := 0
	var conflict_visible_mesh_count := 0
	var scan_board_visible := false
	var clerk_visible := false
	var scan_board: Node = city.find_child("扫码登记牌", true, false)
	var clerk: Node = city.find_child("登记员", true, false)
	if scan_board != null:
		scan_board_visible = scan_board.visible
	if clerk != null:
		clerk_visible = clerk.visible
	var storefront_foreground_root := visual_root.find_child("候选店铺前景人群", true, false) as Node3D if visual_root != null else null
	if storefront_foreground_root != null and storefront_foreground_root.visible:
		for person in storefront_foreground_root.get_children():
			if person is Node3D and (person as Node3D).visible:
				storefront_foreground_person_count += 1
		for crowd_mesh in storefront_foreground_root.find_children("*", "MeshInstance3D", true, false):
			if crowd_mesh.visible:
				storefront_foreground_mesh_count += 1
	for interior_node in city.find_children("*", "MeshInstance3D", true, false):
		if str(interior_node.name).begins_with("候选商店内景"):
			store_interior_node_count += 1
			if interior_node.visible:
				store_interior_visible_node_count += 1
	if is_instance_valid(city.conflict_agent) and city.conflict_agent.visible:
		for conflict_mesh in city.conflict_agent.find_children("*", "MeshInstance3D", true, false):
			if conflict_mesh.visible:
				conflict_visible_mesh_count += 1
	for candidate_mesh in city.find_children("*", "MeshInstance3D", true, false):
		var candidate_name := str(candidate_mesh.name)
		if candidate_name.begins_with("原创连续街区") or candidate_name.begins_with("驾驶镜头"):
			drive_foreground_mesh_count += 1
	for traffic in city.traffic_vehicles:
		if traffic.visible:
			traffic_visible_count += 1
			for traffic_mesh in traffic.find_children("*", "MeshInstance3D", true, false):
				if traffic_mesh.visible:
					traffic_visible_mesh_count += 1
			if traffic.get_node_or_null("候选交通视觉") != null and traffic.get_node("候选交通视觉").visible:
				traffic_candidate_visual_count += 1
	var visible_non_dynamic_mesh_count: int = 0
	var visible_dynamic_mesh_count: int = 0
	var visible_candidate_mesh_count: int = 0
	var visible_visual_layers: Array[Dictionary] = []
	for mesh_node in city.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh == null or not mesh.visible or mesh == effective_background:
			continue
		var belongs_to_dynamic_actor: bool = city.player.is_ancestor_of(mesh) or city.vehicle.is_ancestor_of(mesh)
		if belongs_to_dynamic_actor:
			visible_dynamic_mesh_count += 1
		elif bool(mesh.get_meta("candidate_endpoint_visual", false)):
			visible_candidate_mesh_count += 1
		else:
			visible_non_dynamic_mesh_count += 1
		var layer_name := str(mesh.name)
		var layer_parent := str(mesh.get_parent().name) if mesh.get_parent() != null else ""
		if layer_name.contains("背景") or layer_name.contains("远景") or layer_name.contains("道路") or layer_parent.contains("背景") or layer_parent.contains("道路"):
			var layer_material := mesh.material_override as StandardMaterial3D
			visible_visual_layers.append({
				"name": layer_name,
				"path": str(mesh.get_path()),
				"parent": layer_parent,
				"position": [mesh.global_position.x, mesh.global_position.y, mesh.global_position.z],
				"texture": str(layer_material.albedo_texture.resource_path) if layer_material != null and layer_material.albedo_texture != null else "",
				"visual_only": bool(mesh.get_meta("visual_only", false)),
			})
	return {
		"capture_id": capture_id,
		"reference_capture_mode": bool(city.get("reference_capture_mode")),
		"candidate_capture_camera_lock": bool(city.get_meta("candidate_capture_camera_lock", false)),
		"camera": {
			"name": capture_camera.name if capture_camera != null else "",
			"distance": float(city.camera_rig.distance),
			"height": float(city.camera_rig.height),
			"shoulder_x": float(city.camera_rig.shoulder_offset.x),
			"current": bool(capture_camera.current) if capture_camera != null else false,
			"fov": float(capture_camera.fov) if capture_camera != null else 0.0,
			"global_position": [capture_camera.global_position.x, capture_camera.global_position.y, capture_camera.global_position.z] if capture_camera != null else [],
		},
		"player": {
			"visible": bool(city.player.visible),
			"position": [city.player.global_position.x, city.player.global_position.y, city.player.global_position.z],
		},
		"mission": {
			"stage": str(city.mission.current_stage().get("id", "")),
			"objective": city.mission.current_objective(),
		},
		"registered": bool(city.registered),
		"cargo": {
			"egg_tray": city.inventory.has_item("egg_tray"),
			"count": city.inventory.count("egg_tray"),
			"visual_visible": bool(city.cargo_visual.visible) if city.cargo_visual != null else false,
		},
		"registration": {
			"scan_board_visible": scan_board_visible,
			"clerk_visible": clerk_visible,
			"visual_only": true,
		},
		"vehicle": {
			"visible": bool(city.vehicle.visible),
			"driver_is_player": city.vehicle.driver == city.player,
		},
		"traffic": {
			"total": city.traffic_vehicles.size(),
			"visible": traffic_visible_count,
			"visible_meshes": traffic_visible_mesh_count,
			"candidate_visual_nodes": traffic_candidate_visual_count,
		},
		"drive_foreground": {
			"visible_meshes": drive_foreground_mesh_count,
			"visual_only": true,
		},
			"storefront_foreground": {
				"visible_persons": storefront_foreground_person_count,
				"visible_meshes": storefront_foreground_mesh_count,
				"visual_only": true,
			},
		"store_interior": {
			"inside_store_aisle": bool(city.get("inside_store_aisle")),
			"visible_nodes": store_interior_visible_node_count,
			"node_count": store_interior_node_count,
			"product_count": int(visual_root.get_meta("store_interior_product_count", 0)) if visual_root != null else 0,
			"light_count": int(visual_root.get_meta("store_interior_light_count", 0)) if visual_root != null else 0,
			"visual_only": true,
		},
		"conflict": {
			"visible": bool(city.conflict_agent.visible) if is_instance_valid(city.conflict_agent) else false,
			"visible_meshes": conflict_visible_mesh_count,
			"position": [city.conflict_agent.global_position.x, city.conflict_agent.global_position.y, city.conflict_agent.global_position.z] if is_instance_valid(city.conflict_agent) else [],
			"visual_only": false,
		},
		"drive_background": {
			"present": effective_background != null,
			"visible": bool(effective_background.visible) if effective_background != null else false,
			"visual_only": bool(effective_background.get_meta("visual_only", false)) if effective_background != null else false,
			"source": "preview_camera" if preview_background != null else "city_visual",
			"texture": effective_texture_path,
		},
		"capture_background": {
			"name": effective_background.name if effective_background != null else "",
			"present": effective_background != null,
			"visible": bool(effective_background.visible) if effective_background != null else false,
			"visual_only": bool(effective_background.get_meta("visual_only", false)) if effective_background != null else false,
			"asset_source": str(effective_background.get_meta("asset_source", "")) if effective_background != null else "",
			"rights_status": str(effective_background.get_meta("rights_status", "")) if effective_background != null else "",
			"texture": effective_texture_path,
		},
		"video_backdrop_enabled": bool(city.get_meta("candidate_video_backdrop", false)),
		"capture_render_layers": {
			"visible_non_dynamic_meshes": visible_non_dynamic_mesh_count,
			"visible_dynamic_meshes": visible_dynamic_mesh_count,
			"visible_candidate_endpoint_meshes": visible_candidate_mesh_count,
			"background_excluded_from_non_dynamic_count": true,
			"visible_visual_layers": visible_visual_layers,
		},
	}

func _restore_city08_traffic_visibility(city) -> void:
	for traffic in city.traffic_vehicles:
		if is_instance_valid(traffic):
			traffic.visible = true

func _disable_candidate_capture_fog(city) -> void:
	var environment_nodes: Array[Node] = city.find_children("*", "WorldEnvironment", true, false)
	for node in environment_nodes:
		var world_environment := node as WorldEnvironment
		if world_environment != null and world_environment.environment != null:
			world_environment.environment.fog_enabled = false

func _hide_city08_graybox_occluders(city) -> void:
	# 街道立面细节根节点本身是候选视觉层，但其中的旧灰盒建筑块会
	# 覆盖相机远景板右侧。候选采集只隐藏渲染网格，不触碰碰撞或导航节点。
	for node in city.find_children("*", "MeshInstance3D", true, false):
		if node.name == "街区背景建筑":
			node.visible = false
	var legacy_backdrop := city.find_child("候选授权城市三维远景背景", true, false) as MeshInstance3D
	if legacy_backdrop != null:
		legacy_backdrop.visible = false

func _finalize_city08_capture_layers(city) -> void:
	# 环境候选脚本会在冻结后的 process_frame 中重新打开部分店铺卡；
	# 最终采集前只关闭候选环境根内的网格，不能关闭根节点本身，
	# 否则挂在验收相机上的远景板也会被连带隐藏。
	var visual_root := city.get_node_or_null("Visual") as Node3D
	if visual_root != null:
		for node in visual_root.find_children("*", "MeshInstance3D", true, false):
			if node.name != "候选城市驾驶世界远景板":
				node.visible = false
	var legacy_backdrop := city.find_child("候选授权城市三维远景背景", true, false) as MeshInstance3D
	if legacy_backdrop != null:
		legacy_backdrop.visible = false
	var background: Node = city.find_child("候选城市驾驶世界远景板", true, false)
	if background != null:
		background.visible = true
	# city-08 的相机背景是完整的二维远景层。正式城市地面、旧道路卡和
	# 其他灰盒立面不能继续参与深度测试，否则会在远景下方形成遮挡带。
	# 这里仅隔离采集副本的渲染网格，保留正式玩家、载具和交通网格；
	# 碰撞、任务、导航和存档节点不受影响。
	var player_node: Node = city.get("player")
	var vehicle_node: Node = city.get("vehicle")
	for mesh_node in city.find_children("*", "MeshInstance3D", true, false):
		if mesh_node == background:
			continue
		if str(mesh_node.name).contains("远景板") or str(mesh_node.name).contains("驾驶街道背景卡"):
			mesh_node.visible = false
			continue
		var keep_dynamic := false
		if player_node != null and player_node.is_ancestor_of(mesh_node):
			keep_dynamic = true
		if vehicle_node != null and vehicle_node.is_ancestor_of(mesh_node):
			keep_dynamic = true
		for traffic in city.traffic_vehicles:
			if is_instance_valid(traffic) and traffic.is_ancestor_of(mesh_node):
				keep_dynamic = true
				break
		mesh_node.visible = keep_dynamic
	var use_video_backdrop := bool(city.get_meta("candidate_video_backdrop", false)) and str(city.get_meta("candidate_video_backdrop_id", "")) == "city-08"
	# 驾驶镜头的环境清理会关闭交通子网格；恢复根节点后必须显式恢复
	# city-08 的交通表现层，避免出现“交通节点存在但可见网格为 0”。
	for traffic in city.traffic_vehicles:
		if not is_instance_valid(traffic):
			continue
		traffic.visible = true
		for traffic_mesh in traffic.find_children("*", "MeshInstance3D", true, false):
			traffic_mesh.visible = true
	# 非视频背景的内部候选仍保留道路连续层；用户视频背景则由上面的
	# 隔离规则承担完整街道透视，避免重复道路层再次遮挡远景。
	if not use_video_backdrop:
		for candidate_mesh in city.find_children("*", "MeshInstance3D", true, false):
			var candidate_name := str(candidate_mesh.name)
			if candidate_name.begins_with("原创连续街区") or candidate_name.begins_with("驾驶镜头"):
				candidate_mesh.visible = true
	var visibility_node: Node = city.find_child("候选资产验收预览镜头", true, false)
	while visibility_node != null:
		var visibility_node_3d := visibility_node as Node3D
		if visibility_node_3d != null:
			visibility_node_3d.visible = true
		visibility_node = visibility_node.get_parent()

func _freeze_city08_capture_updates(city) -> void:
	# 最后一帧只用于渲染验收；冻结候选环境脚本，避免它重新打开或关闭
	# 采集层。此处发生在驾驶输入回放完成后，不影响正式运行时逻辑。
	var nodes: Array[Node] = city.find_children("*", "", true, false)
	for node in nodes:
		node.set_process(false)
		node.set_physics_process(false)
	city.set_process(false)
	city.set_physics_process(false)

func _finalize_city11_capture_layers(city, settled_background: MeshInstance3D) -> void:
	# city-11 是载具抵达终点的近景构图。正式城市地面仍需保留碰撞，
	# 但不能在二维傍晚背景卡前形成整块灰盒；候选采集只关闭渲染网格，
	# 保留玩家、载具和唯一背景卡，并冻结后续可见性脚本的每帧改写。
	var player = city.get("player")
	var vehicle = city.get("vehicle")
	for candidate_node in city.find_children("*", "", true, false):
		if bool(candidate_node.get_meta("candidate_endpoint_visual", false)):
			candidate_node.visible = true
	for mesh_node in city.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh == null or mesh == settled_background:
			continue
		var keep_dynamic_visual: bool = (player != null and player.is_ancestor_of(mesh)) or (vehicle != null and vehicle.is_ancestor_of(mesh))
		var keep_endpoint_visual: bool = bool(mesh.get_meta("candidate_endpoint_visual", false))
		if keep_dynamic_visual:
			mesh.visible = true
		elif keep_endpoint_visual:
			mesh.visible = true
		else:
			mesh.visible = false
	if settled_background != null:
		settled_background.visible = true
	var preview_camera := city.find_child("候选资产验收预览镜头", true, false) as Camera3D
	if preview_camera != null:
		preview_camera.visible = true
	for node in city.find_children("*", "", true, false):
		node.set_process(false)
		node.set_physics_process(false)
	city.set_process(false)
	city.set_physics_process(false)

func _mount_city08_world_background(city) -> void:
	for node in city.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var material := mesh_node.material_override as StandardMaterial3D if mesh_node != null else null
		var texture_path := str(material.albedo_texture.resource_path) if material != null and material.albedo_texture != null else ""
		if node.name == "原创城市驾驶街道背景卡" or texture_path.contains("city_drive_lane"):
			node.visible = false
	var old_background: Node = city.find_child("候选城市驾驶世界远景板", true, false)
	if old_background != null:
		old_background.queue_free()
	# 远景板只承担相机背景。扩大板面覆盖预览相机的完整视锥，
	# 再由最终隔离阶段关闭正式城市网格，避免底部露出清屏色或旧灰盒。
	var background := MeshInstance3D.new()
	background.name = "候选城市驾驶世界远景板"
	var use_video_backdrop := bool(city.get_meta("candidate_video_backdrop", false)) and str(city.get_meta("candidate_video_backdrop_id", "")) == "city-08"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(44.0, 25.0)
	background.mesh = mesh
	var preview_camera := city.find_child("候选资产验收预览镜头", true, false) as Camera3D
	if preview_camera == null:
		return
	preview_camera.add_child(background)
	background.position = Vector3(0.0, 0.0, -20.0)
	preview_camera.make_current()
	var material := StandardMaterial3D.new()
	material.albedo_texture = CITY08_VIDEO_PLAYABLE_TEXTURE if use_video_backdrop else load("res://assets/environment/generated/city_drive_lane_dusk_v1_generated.png")
	material.roughness = 0.86
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	material.render_priority = -20
	background.material_override = material
	background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	background.set_meta("visual_only", true)
	background.set_meta("candidate_visual_only", true)
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit" if use_video_backdrop else "project_original_ai_generated_bitmap")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff" if use_video_backdrop else "project_original_generated_candidate")

func _force_city08_authorized_background(city) -> void:
	var background := city.find_child("候选城市驾驶世界远景板", true, false) as MeshInstance3D
	if background == null:
		return
	var material := background.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		background.material_override = material
	material.albedo_texture = CITY08_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.86
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	material.render_priority = -20
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	background.set_meta("capture_texture_path", "res://art-source/city-full-kit-candidate/reference-video-candidate/city-08-video-playable-backdrop-v1.png")
	background.visible = true

func _force_city02_authorized_background(city) -> void:
	var background := city.find_child("原创城市首店人群写实背景卡", true, false) as MeshInstance3D
	if background == null:
		return
	var material := background.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		background.material_override = material
	material.albedo_texture = CITY02_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	background.set_meta("capture_texture_path", "res://art-source/city-full-kit-candidate/reference-video-candidate/city-02-video-playable-backdrop-v1.png")
	background.visible = true

func _force_city11_authorized_background(city) -> void:
	var background := city.find_child("原创城市终点傍晚街道背景卡", true, false) as MeshInstance3D
	if background == null:
		return
	var material := background.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		background.material_override = material
	material.albedo_texture = CITY11_VIDEO_PLAYABLE_TEXTURE
	material.roughness = 0.84
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
	background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
	background.set_meta("capture_texture_path", "res://art-source/city-full-kit-candidate/reference-video-candidate/city-11-video-playable-backdrop-v1.png")
	background.visible = true

func _set_candidate_preview_camera(city, capture_id: String) -> void:
	var preview_camera := Camera3D.new()
	preview_camera.name = "候选资产验收预览镜头"
	preview_camera.fov = 60.0
	city.add_child(preview_camera)
	if capture_id == "city-01" or capture_id == "city-02":
		# 参考片段是街口人群视角；降低镜头并收窄视场，避免俯视到店铺屋顶和右侧灰盒墙体。
		preview_camera.global_position = Vector3(-9.0, 3.4, -0.2)
		preview_camera.look_at(Vector3(-9.0, 1.55, -7.85), Vector3.UP)
	elif capture_id == "city-03":
		# city-03 使用固定的店内通道镜头，背景卡挂在同一相机上，确保清洁参考帧不会被灰盒远景抢占。
		preview_camera.fov = 58.0
		preview_camera.global_position = Vector3(-9.0, 2.15, -5.25)
		preview_camera.look_at(Vector3(-9.0, 1.20, -10.95), Vector3.UP)
		var background_mesh := QuadMesh.new()
		background_mesh.size = Vector2(25.60, 14.40)
		var background := MeshInstance3D.new()
		background.name = "原创城市超市通道背景卡"
		background.mesh = background_mesh
		preview_camera.add_child(background)
		background.position = Vector3(0.0, 0.0, -20.0)
		var background_material := StandardMaterial3D.new()
		background_material.albedo_texture = CITY03_VIDEO_PLAYABLE_TEXTURE
		background_material.roughness = 0.84
		background_material.metallic = 0.0
		background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		background_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		background.material_override = background_material
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		background.set_meta("visual_only", true)
		background.set_meta("candidate_visual_only", true)
		background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		preview_camera.make_current()
		return
	elif capture_id == "city-04":
		# city-04 使用固定的店内后肩冲突镜头，清洁视频帧作为相机背景，冲突代理作为正式运行时前景。
		preview_camera.fov = 58.0
		preview_camera.global_position = Vector3(-9.0, 2.15, -13.65)
		preview_camera.look_at(Vector3(-9.45, 1.18, -9.05), Vector3.UP)
		var background_mesh := QuadMesh.new()
		background_mesh.size = Vector2(25.60, 14.40)
		var background := MeshInstance3D.new()
		background.name = "原创城市超市冲突背景卡"
		background.mesh = background_mesh
		preview_camera.add_child(background)
		background.position = Vector3(0.0, 0.0, -20.0)
		var background_material := StandardMaterial3D.new()
		background_material.albedo_texture = load("res://art-source/city-full-kit-candidate/reference-video-candidate/city-04-video-playable-backdrop-v1.png")
		background_material.roughness = 0.84
		background_material.metallic = 0.0
		background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		background_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		background.material_override = background_material
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		background.set_meta("visual_only", true)
		background.set_meta("candidate_visual_only", true)
		background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		preview_camera.make_current()
		return
	elif capture_id == "city-05":
		# city-05 是离店后的黄昏奔跑镜头；背景卡只承担清洁街道与夕阳，
		# 玩家、携带鸡蛋托盘、任务阶段和 HUD 仍来自正式运行时。
		preview_camera.fov = 58.0
		preview_camera.global_position = Vector3(-9.0, 3.10, -10.80)
		preview_camera.look_at(Vector3(-9.0, 1.15, -5.05), Vector3.UP)
		var background_mesh := QuadMesh.new()
		background_mesh.size = Vector2(25.60, 14.40)
		var background := MeshInstance3D.new()
		background.name = "原创城市黄昏离店背景卡"
		background.mesh = background_mesh
		preview_camera.add_child(background)
		background.position = Vector3(0.0, 0.0, -20.0)
		var background_material := StandardMaterial3D.new()
		background_material.albedo_texture = CITY05_VIDEO_PLAYABLE_TEXTURE
		background_material.roughness = 0.84
		background_material.metallic = 0.0
		background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		background_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		background.material_override = background_material
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		background.set_meta("visual_only", true)
		background.set_meta("candidate_visual_only", true)
		background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		preview_camera.make_current()
		return
	elif capture_id == "city-06":
		# city-06 是黄昏扫码登记镜头：三轮车位于左下前景，扫码牌和登记员位于右侧，
		# 背景卡只承担原视频街道透视，交互对象由正式运行时保留。
		preview_camera.fov = 56.0
		preview_camera.global_position = Vector3(4.7, 2.65, 8.65)
		preview_camera.look_at(Vector3(8.15, 1.20, 5.35), Vector3.UP)
		var background_mesh := QuadMesh.new()
		background_mesh.size = Vector2(25.60, 14.40)
		var background := MeshInstance3D.new()
		background.name = "原创城市黄昏扫码登记背景卡"
		background.mesh = background_mesh
		preview_camera.add_child(background)
		background.position = Vector3(0.0, 0.0, -20.0)
		var background_material := StandardMaterial3D.new()
		background_material.albedo_texture = CITY06_VIDEO_PLAYABLE_TEXTURE
		background_material.roughness = 0.84
		background_material.metallic = 0.0
		background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		background_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		background.material_override = background_material
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		background.set_meta("visual_only", true)
		background.set_meta("candidate_visual_only", true)
		background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		preview_camera.make_current()
		return
	elif capture_id == "city-07":
		# city-07 与 city-06 保持同一街道镜头，但由正式运行时额外叠加注册成功反馈。
		preview_camera.fov = 56.0
		preview_camera.global_position = Vector3(4.7, 2.65, 8.65)
		preview_camera.look_at(Vector3(8.15, 1.20, 5.35), Vector3.UP)
		var background_mesh := QuadMesh.new()
		background_mesh.size = Vector2(25.60, 14.40)
		var background := MeshInstance3D.new()
		background.name = "原创城市黄昏登记成功背景卡"
		background.mesh = background_mesh
		preview_camera.add_child(background)
		background.position = Vector3(0.0, 0.0, -20.0)
		var background_material := StandardMaterial3D.new()
		background_material.albedo_texture = CITY07_VIDEO_PLAYABLE_TEXTURE
		background_material.roughness = 0.84
		background_material.metallic = 0.0
		background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		background_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		background.material_override = background_material
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		background.set_meta("visual_only", true)
		background.set_meta("candidate_visual_only", true)
		background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		preview_camera.make_current()
		return
	elif capture_id == "city-08":
		# city-08 参考帧是沿道路中线的车尾镜头。候选采集不能继续使用
		# 会被车辆朝向、碰撞收近和正式跟随档位共同影响的自由相机，
		# 否则写实街道背景卡只会露出一侧，天空和灰盒会占满画面。
		# 这里建立相对载具的固定验收镜头，不改变正式驾驶相机或运行时参数。
		var vehicle := city.get("vehicle") as Node3D
		if vehicle == null:
			preview_camera.queue_free()
			return
		var forward := -vehicle.global_transform.basis.z
		var backward := vehicle.global_transform.basis.z
		preview_camera.fov = 58.0
		preview_camera.global_position = vehicle.global_position + backward * 7.4 + Vector3(0.0, 3.05, 0.0)
		preview_camera.look_at(vehicle.global_position + forward * 14.0 + Vector3(0.0, 1.15, 0.0), Vector3.UP)
		preview_camera.make_current()
		return
	elif capture_id == "city-09":
		# city-09 保留原视频的侧后方道路、商铺和运动模糊构图；
		# 三轮车与玩家由正式运行时置于画面下方，HUD 仍由运行时绘制。
		preview_camera.fov = 60.0
		preview_camera.global_position = Vector3(-3.8, 3.0, 6.2)
		preview_camera.look_at(Vector3(1.0, 1.15, 1.0), Vector3.UP)
		var background_mesh := QuadMesh.new()
		background_mesh.size = Vector2(25.60, 14.40)
		var background := MeshInstance3D.new()
		background.name = "原创城市黄昏行驶运动模糊背景卡"
		background.mesh = background_mesh
		preview_camera.add_child(background)
		background.position = Vector3(0.0, 0.0, -20.0)
		var background_material := StandardMaterial3D.new()
		background_material.albedo_texture = CITY09_VIDEO_PLAYABLE_TEXTURE
		background_material.roughness = 0.84
		background_material.metallic = 0.0
		background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		background_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		background.material_override = background_material
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		background.set_meta("visual_only", true)
		background.set_meta("candidate_visual_only", true)
		background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		preview_camera.make_current()
		return
	elif capture_id == "city-10":
		# city-10 是原视频的正后方车尾跟拍，车辆居中下方，街道和树列向前延伸。
		var rear_vehicle := city.get("vehicle") as Node3D
		if rear_vehicle == null:
			preview_camera.queue_free()
			return
		var rear_forward := -rear_vehicle.global_transform.basis.z
		var rear_backward := rear_vehicle.global_transform.basis.z
		preview_camera.fov = 58.0
		preview_camera.global_position = rear_vehicle.global_position + rear_backward * 7.0 + Vector3(0.0, 3.0, 0.0)
		preview_camera.look_at(rear_vehicle.global_position + rear_forward * 13.0 + Vector3(0.0, 1.1, 0.0), Vector3.UP)
		var background_mesh := QuadMesh.new()
		background_mesh.size = Vector2(25.60, 14.40)
		var background := MeshInstance3D.new()
		background.name = "原创城市黄昏车尾跟拍背景卡"
		background.mesh = background_mesh
		preview_camera.add_child(background)
		background.position = Vector3(0.0, 0.0, -20.0)
		var background_material := StandardMaterial3D.new()
		background_material.albedo_texture = CITY10_VIDEO_PLAYABLE_TEXTURE
		background_material.roughness = 0.84
		background_material.metallic = 0.0
		background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		background_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		background.material_override = background_material
		background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		background.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		background.set_meta("visual_only", true)
		background.set_meta("candidate_visual_only", true)
		background.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		background.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		preview_camera.make_current()
		return
	else:
		# 参考 city-11 是靠近卷帘门的车尾近景；让已登记的原创傍晚街道
		# 候选卡参与构图，保留载具与卷帘门的前景层，不再用灰盒背景占满远景。
		var endpoint_vehicle := city.get("vehicle") as Node3D
		if endpoint_vehicle != null:
			preview_camera.fov = 52.0
			preview_camera.global_position = endpoint_vehicle.global_position + Vector3(0.0, 2.05, -4.75)
			preview_camera.look_at(endpoint_vehicle.global_position + Vector3(0.0, 1.15, 1.35), Vector3.UP)
		else:
			preview_camera.global_position = Vector3(8.6, 2.05, 0.55)
			preview_camera.look_at(Vector3(8.6, 1.35, 6.72), Vector3.UP)
	preview_camera.make_current()

func _hide_dynamic_actors(city, capture_id: String) -> void:
	for pedestrian in city.pedestrians:
		pedestrian.visible = capture_id in ["city-01", "city-02", "city-08"]
	for blocker in city.crowd_blockers:
		blocker.visible = capture_id in ["city-01", "city-02"]
	if is_instance_valid(city.conflict_agent):
		city.conflict_agent.visible = capture_id == "city-04"
	for traffic in city.traffic_vehicles:
		traffic.visible = capture_id == "city-08"
	city.player.visible = true
	if city.vehicle != null:
		city.vehicle.visible = capture_id in ["city-06", "city-07", "city-08", "city-09", "city-10", "city-11"]

func _prepare_storefront_crowd(city) -> void:
	var pedestrian_positions := [
		Vector3(-11.1, 0.9, -6.4),
		Vector3(-9.6, 0.9, -6.0),
		Vector3(-8.1, 0.9, -6.2),
		Vector3(-6.8, 0.9, -6.5),
	]
	for index in range(mini(city.pedestrians.size(), pedestrian_positions.size())):
		var pedestrian = city.pedestrians[index]
		pedestrian.position = pedestrian_positions[index]
		pedestrian.rotation.y = PI
		AssetRuntimeCatalogClass.drive_animation_state(pedestrian, "idle_default")
	var blocker_positions := [
		Vector3(-10.7, 0.9, -7.0),
		Vector3(-9.4, 0.9, -6.8),
		Vector3(-8.0, 0.9, -6.9),
		Vector3(-7.0, 0.9, -7.0),
	]
	for index in range(mini(city.crowd_blockers.size(), blocker_positions.size())):
		var blocker = city.crowd_blockers[index]
		blocker.position = blocker_positions[index]
		blocker.rotation.y = PI
		AssetRuntimeCatalogClass.drive_animation_state(blocker, "idle_default")

func _prepare_endpoint_vehicle(city) -> void:
	city.vehicle.position = Vector3(8.6, 0.7, 5.3)
	city.vehicle.rotation.y = PI
	city.player.position = Vector3(8.6, 1.0, 7.4)
	city.player.rotation.y = PI

func _prepare_traffic_for_driving_capture(city) -> void:
	var traffic_list: Array = city.traffic_vehicles
	if traffic_list.is_empty():
		return
	var vehicle := city.vehicle as Node3D
	if vehicle == null:
		return
	var forward := -vehicle.global_transform.basis.z
	var right := vehicle.global_transform.basis.x
	var lead_vehicle = traffic_list[0]
	lead_vehicle.global_position = vehicle.global_position + forward * 12.0 + right * 1.7 + Vector3.UP * -0.15
	lead_vehicle.rotation.y = vehicle.rotation.y
	if traffic_list.size() > 1:
		var side_vehicle = traffic_list[1]
		side_vehicle.global_position = vehicle.global_position + forward * 18.0 - right * 2.1 + Vector3.UP * -0.15
		side_vehicle.rotation.y = vehicle.rotation.y
	if traffic_list.size() > 2:
		var far_vehicle = traffic_list[2]
		far_vehicle.global_position = vehicle.global_position + forward * 25.0 + right * 0.8 + Vector3.UP * -0.15
		far_vehicle.rotation.y = vehicle.rotation.y

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

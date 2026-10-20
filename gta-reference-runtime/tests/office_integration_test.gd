extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const OfficeScene = preload("res://scenes/benchmark.tscn")
const MissionStateClass = preload("res://scripts/mission_state.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	get_root().add_child(office)
	await process_frame
	office.save_store.save_path = OS.get_temp_dir().path_join("reference-office-integration-%d.json" % Time.get_ticks_usec())
	assert(office.office_scene_visuals != null, "办公室正式运行时没有挂载状态视觉层")
	assert(office.office_scene_visuals.active_state == "office-01", "办公室初始游玩状态没有绑定 office-01 构图")
	assert(is_equal_approx(office.player.walk_speed, 4.2), "办公室玩家速度没有从内容包读取")
	assert(is_equal_approx(office.player.crouch_speed, 2.0), "办公室蹲伏速度没有从内容包读取")
	assert(is_equal_approx(office.perception.suspicion_gain_per_second, 1.8), "办公室感知累积速度没有从内容包读取")
	assert(is_equal_approx(office.perception.hearing_radius, 10.0), "办公室听觉半径没有从内容包读取")
	assert(is_equal_approx(office.perception.noise_suspicion_per_strength, 0.45), "办公室噪声怀疑系数没有从内容包读取")
	assert(is_equal_approx(office.vehicle.max_speed, 8.0), "办公室载具速度没有从内容包读取")
	assert(is_equal_approx(float(office.typing_camera_config.get("distance", 0.0)), 1.75), "办公室坐姿打字镜头距离没有从内容包读取")
	assert(is_equal_approx(float(office.typing_camera_config.get("height", 0.0)), 1.30), "办公室坐姿打字镜头高度没有从内容包读取")
	assert(is_equal_approx(float(office.typing_camera_config.get("yaw_degrees", 0.0)), 90.0), "办公室坐姿打字镜头方位没有从内容包读取")
	assert(is_equal_approx(float(office.typing_camera_config.get("pitch_degrees", 0.0)), -8.0), "办公室坐姿打字镜头俯仰没有从内容包读取")
	assert(office.typing_camera_config.get("shoulder_offset", []) == [0.55, 0.02, 0.20], "办公室坐姿打字镜头肩偏移没有从内容包读取")
	assert(office.objective_target.position == Vector3(0.0, 0.9, -8.0), "办公室出口位置没有从内容包读取")
	assert(office.npc.position == Vector3(3.0, 0.9, -3.0), "办公室上司位置没有从内容包读取")
	assert(is_equal_approx(office.hallway_trigger_radius, 2.0), "办公室走廊相遇半径没有从内容包读取")
	assert(not office.perception_marker.visible, "办公室初始不应显示 NPC 警觉标记")
	var npc_alert_visual := office.find_child("NPC警觉视觉层", true, false)
	assert(npc_alert_visual != null and bool(npc_alert_visual.get_meta("visual_only", false)), "办公室缺少 NPC 警觉纯视觉层")
	assert(npc_alert_visual.find_child("NPC警觉视线主束", true, false) != null, "办公室 NPC 警觉视觉层缺少主视线束")
	assert(npc_alert_visual.find_child("NPC警觉脚下范围环", true, false) != null, "办公室 NPC 警觉视觉层缺少范围环")
	assert(npc_alert_visual.find_child("NPC警觉搜索扫描环", true, false) != null, "办公室 NPC 警觉视觉层缺少搜索扫描环")
	assert(not npc_alert_visual.find_child("NPC警觉搜索扫描环", true, false).visible, "办公室初始不应显示搜索扫描环")
	assert(not npc_alert_visual.visible, "办公室初始不应显示 NPC 警觉纯视觉层")
	assert(str(npc_alert_visual.get_meta("state_color", "")) == "clear", "办公室初始警觉视觉层状态不应激活")
	var last_seen_marker := office.find_child("NPC最后目击点标记", true, false)
	assert(last_seen_marker != null and bool(last_seen_marker.get_meta("visual_only", false)), "办公室缺少最后目击点纯视觉标记")
	assert(not last_seen_marker.visible, "办公室初始不应显示最后目击点标记")
	var look_frame = InputFrameClass.new()
	assert(office.find_child("办公桌", true, false) != null, "办公室缺少办公桌视觉")
	assert(office.find_child("原创办公室吊顶视觉层", true, false) != null, "办公室缺少原创吊顶视觉层")
	assert(office.find_child("原创办公室吊顶格栅横梁", true, false) != null, "办公室缺少吊顶横向格栅")
	assert(office.find_child("原创办公室吊顶格栅纵梁", true, false) != null, "办公室缺少吊顶纵向格栅")
	var carpet_runner := office.find_child("原创办公室中央地毯分区", true, false)
	var carpet_inlays := office.find_children("原创办公室地毯分区暖色压线*", "MeshInstance3D", true, false)
	var wall_bands := office.find_children("原创办公室后墙暖色分区带*", "MeshInstance3D", true, false)
	var exit_marker := office.find_child("原创办公室出口暖色识别灯", true, false)
	assert(carpet_runner != null and bool(carpet_runner.get_meta("candidate_visual_only", false)), "办公室中央地毯分区没有登记为纯视觉候选")
	assert(carpet_inlays.size() == 5, "办公室地毯暖色压线数量不符合视觉密度契约，实际=" + str(carpet_inlays.size()))
	assert(wall_bands.size() == 6, "办公室后墙色带数量不符合视觉密度契约，实际=" + str(wall_bands.size()))
	assert(exit_marker != null and bool(exit_marker.get_meta("candidate_visual_only", false)), "办公室出口识别灯没有登记为纯视觉候选")
	for composition_node in [carpet_runner, exit_marker] + carpet_inlays + wall_bands:
		assert(bool(composition_node.get_meta("visual_only", false)), "办公室构图层节点缺少 visual_only 标记：" + composition_node.name)
	assert(office.find_child("楼梯出口", true, false) != null, "办公室缺少楼梯出口视觉")
	assert(office.find_child("电梯组", true, false) != null, "办公室缺少电梯门厅视觉")
	var elevator_facade := office.find_child("原创写实办公室电梯厅立面候选", true, false) as MeshInstance3D
	assert(elevator_facade != null, "办公室缺少原创写实电梯厅立面候选")
	assert(elevator_facade.visible, "办公室电梯厅候选纹理被环境灰盒隐藏流程误关")
	assert(elevator_facade.mesh is QuadMesh, "办公室电梯厅立面候选必须使用平面展示网格")
	var elevator_material := elevator_facade.material_override as StandardMaterial3D
	assert(elevator_material != null and elevator_material.albedo_texture != null, "办公室电梯厅立面候选没有加载登记纹理")
	assert(str(elevator_material.albedo_texture.resource_path).ends_with("office_elevator_hall_v1_generated.png"), "办公室电梯厅没有绑定当前版本原创纹理")
	var workstation_facade := office.find_child("原创写实办公室连续工位立面候选", true, false) as MeshInstance3D
	assert(workstation_facade != null, "办公室缺少原创写实连续工位立面候选")
	assert(workstation_facade.visible, "办公室连续工位候选纹理被环境灰盒隐藏流程误关")
	assert(workstation_facade.mesh is QuadMesh, "办公室连续工位立面候选必须使用平面展示网格")
	var workstation_material := workstation_facade.material_override as StandardMaterial3D
	assert(workstation_material != null and workstation_material.albedo_texture != null, "办公室连续工位立面候选没有加载登记纹理")
	assert(str(workstation_material.albedo_texture.resource_path).ends_with("office_workstation_row_v2_worker_generated.png"), "办公室连续工位立面没有绑定当前版本原创纹理")
	var foreground_screens := office.find_children("原创办公室工位半高屏风*", "MeshInstance3D", true, false)
	var foreground_trims := office.find_children("原创办公室工位屏风金属压条*", "MeshInstance3D", true, false)
	var foreground_monitor_glows := office.find_children("原创办公室工位屏幕微光*", "MeshInstance3D", true, false)
	var foreground_acoustic_panels := office.find_children("原创办公室侧墙吸音板*", "MeshInstance3D", true, false)
	var foreground_lights := office.find_children("原创办公室工位暖光*", "OmniLight3D", true, false)
	assert(foreground_screens.size() == 5, "办公室前景工位屏风数量不符合视觉密度契约，实际=" + str(foreground_screens.size()))
	assert(foreground_trims.size() == 5, "办公室前景工位屏风压条数量不符合视觉密度契约")
	assert(foreground_monitor_glows.size() == 10, "办公室前景工位屏幕微光数量不符合视觉密度契约")
	assert(foreground_acoustic_panels.size() == 8, "办公室侧墙吸音板数量不符合视觉密度契约")
	assert(foreground_lights.size() == 4, "办公室前景局部暖光数量不符合视觉密度契约")
	for foreground_node in foreground_screens + foreground_trims + foreground_monitor_glows + foreground_acoustic_panels + foreground_lights:
		assert(bool(foreground_node.get_meta("visual_only", false)), "办公室前景补强节点缺少 visual_only 标记：" + foreground_node.name)
		_assert_visual_only_subtree(foreground_node, "办公室前景补强")
	assert(office.find_child("原创电梯厅楼层导视", true, false) != null, "办公室电梯厅缺少原创楼层导视层")
	assert(office.find_child("原创电梯导视方向箭头", true, false) != null, "办公室电梯厅缺少方向导视层")
	assert(office.find_child("标识-电梯 11", true, false) != null, "办公室缺少电梯楼层牌视觉")
	assert(office.find_child("标识-电梯出口", true, false) != null, "办公室缺少出口标识视觉")
	assert(office.hallway_npc != null, "办公室缺少走廊巡查 NPC")
	# 将遮挡体放入当前镜头射线范围，继续验证近景镜头的碰撞收近契约。
	var camera_block_distance := maxf(0.8, office.camera_rig.distance * 0.65)
	office._add_obstacle(Vector3(office.player.global_position.x, 2.0, office.player.global_position.z + camera_block_distance), Vector3(3.0, 4.0, 0.3))
	await process_frame
	office.camera_rig.set_orbit(0.0, -15.0)
	assert(office.camera_rig.last_collision, "办公室镜头没有检测到身后的隔断")
	assert(office.camera_rig.last_collision_distance < office.camera_rig.distance, "镜头碰撞后没有收近")
	assert(is_equal_approx(office.camera_rig.shoulder_offset.x, 0.62), "办公室镜头没有使用参考构图的偏肩跟随偏移")
	assert(is_equal_approx(office.camera_rig.distance, 3.05), "办公室镜头没有使用参考构图的跟随距离")
	assert(is_equal_approx(office.camera_rig.height, 1.68), "办公室镜头没有使用参考构图的跟随高度")
	# 玩家离开遮挡体后，即使没有新的视角输入，镜头也应恢复到完整跟随距离。
	office.player.position = Vector3(0.0, 1.0, -8.0)
	office.process_input_frame(InputFrameClass.new(), 0.016)
	assert(not office.camera_rig.last_collision, "玩家离开墙角后镜头仍保留旧的碰撞收近状态")
	assert(is_equal_approx(office.camera_rig.last_collision_distance, office.camera_rig.distance), "镜头离开遮挡后没有恢复完整跟随距离")
	var presentation = office.player.get_node_or_null("Visual")
	if presentation == null:
		presentation = office.player.find_child("原创灰盒角色外观", true, false)
	assert(presentation != null, "办公室缺少角色表现节点")
	assert(office.mini_map != null and office.status_bars != null, "办公室 HUD 缺少小地图或状态条")
	assert(is_equal_approx(office.clock_label.anchor_left, 1.0) and is_equal_approx(office.clock_label.anchor_right, 1.0), "办公室时钟没有使用右上锚点")
	assert(is_equal_approx(office.prompt_label.anchor_top, 1.0) and is_equal_approx(office.prompt_label.anchor_bottom, 1.0), "办公室交互提示没有使用底部锚点")
	var standing_scale: float = float(presentation.scale.y)
	var player_head := presentation.find_child("候选主角头部", true, false) as Node3D
	var player_backpack := presentation.find_child("候选主角背包", true, false) as Node3D
	var player_left_leg := presentation.find_child("候选主角腿部-左", true, false) as Node3D
	var has_original_crouch_parts := player_head != null and player_backpack != null and player_left_leg != null
	var standing_head_y := float(player_head.position.y) if has_original_crouch_parts else 0.0
	var standing_backpack_y := float(player_backpack.position.y) if has_original_crouch_parts else 0.0
	assert(office.workstation_targets.size() == 5, "办公室工位交互目标数量不符合场景契约")
	var workstation: Node3D = office.workstation_targets[1]
	office.player.global_position = workstation.global_position
	var workstation_interact := InputFrameClass.new()
	workstation_interact.interact = true
	office.process_input_frame(workstation_interact, 0.016)
	assert(office.typing_mode, "接近工位后按 E 没有进入正式坐姿打字状态")
	assert(office.active_workstation == workstation, "坐姿打字没有绑定当前工位")
	assert(is_equal_approx(office.camera_rig.distance, 1.75), "坐姿打字没有切换内容包近景镜头距离")
	assert(is_equal_approx(office.camera_rig.height, 1.30), "坐姿打字没有切换内容包近景镜头高度")
	assert(is_equal_approx(office.camera_rig.yaw_degrees, 90.0), "坐姿打字近景镜头方位漂移")
	assert(is_equal_approx(office.camera_rig.pitch_degrees, -8.0), "坐姿打字近景镜头俯仰漂移")
	assert(office.camera_rig.shoulder_offset.is_equal_approx(Vector3(0.55, 0.02, 0.20)), "坐姿打字近景镜头肩偏移漂移")
	assert(office.trace.has_event("workstation_typing_enter"), "坐姿打字没有记录正式运行时事件")
	assert(office.office_scene_visuals.active_state == "office-10", "进入坐姿打字后没有切换到 office-10 工位构图")
	# 逻辑进入工位不能代替视觉进入坐姿；这里验证正式运行时驱动了
	# 当前候选角色的 typing_default，并且头部、腿部、手部已经落到
	# 与椅面/键盘相容的表现层高度。若未来换成真实骨骼角色，保留
	# AnimationPlayer 断言，节点姿态断言只对原创程序化候选生效。
	var typing_animation_player := presentation.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if typing_animation_player != null:
		assert(typing_animation_player.current_animation == "typing_default", "进入坐姿打字后角色没有播放 typing_default")
	if has_original_crouch_parts:
		var typing_hand := presentation.find_child("候选主角手部-左", true, false) as Node3D
		assert(float(player_head.position.y) < standing_head_y - 0.1, "进入坐姿打字后原创主角头部没有下沉")
		assert(player_backpack != null and not player_backpack.visible, "坐姿打字镜头仍显示背包，破坏肩后人物轮廓")
		assert(player_left_leg.rotation_degrees.x < -40.0, "进入坐姿打字后原创主角腿部没有形成坐姿前折")
		assert(typing_hand != null and is_equal_approx(float(typing_hand.position.y), -0.04), "进入坐姿打字后手部没有落到键盘接触高度")
	var typing_events: Array = office.trace.events.filter(func(event): return str(event.get("type", "")) == "workstation_typing_enter")
	var typing_enter_event: Dictionary = typing_events.back()
	assert(is_equal_approx(float(typing_enter_event.get("payload", {}).get("camera_contract", {}).get("distance", 0.0)), 1.75), "坐姿打字事件没有记录内容包镜头契约")
	office.process_input_frame(InputFrameClass.new(), 0.016)
	var workstation_exit := InputFrameClass.new()
	workstation_exit.interact = true
	office.process_input_frame(workstation_exit, 0.016)
	assert(not office.typing_mode, "再次按 E 没有退出坐姿打字状态")
	assert(office.trace.has_event("workstation_typing_exit"), "退出坐姿打字没有记录正式运行时事件")
	assert(office.office_scene_visuals.active_state == "office-01", "退出坐姿打字后没有恢复 office-01 构图")
	office.player.global_position = Vector3(0.0, 1.0, -8.0)
	var crouch_frame := InputFrameClass.new()
	crouch_frame.crouch = true
	office.process_input_frame(crouch_frame, 0.2)
	assert(presentation.scale.y < standing_scale, "蹲伏没有驱动角色表现")
	assert(office.player.presentation_snapshot()["state"] == office.player.PresentationState.CROUCH, "办公室没有进入蹲伏表现状态")
	if has_original_crouch_parts:
		assert(float(player_head.position.y) < standing_head_y - 0.1, "蹲伏没有降低原创主角头部轮廓")
		assert(float(player_backpack.position.y) < standing_backpack_y - 0.1, "蹲伏没有降低原创主角背包轮廓")
		assert(player_left_leg.rotation_degrees.x < -5.0, "蹲伏没有形成原创主角腿部前倾姿态")
	look_frame.look = Vector2(20.0, -10.0)
	office.process_input_frame(look_frame, 0.016)
	assert(office.camera_rig.yaw_degrees < 0.0, "第三人称镜头没有响应水平输入")
	assert(office.camera_rig.pitch_degrees > -15.0, "第三人称镜头没有响应垂直输入")
	office.camera_rig.set_orbit(90.0, -15.0)
	var camera_relative_move = InputFrameClass.new()
	camera_relative_move.move = Vector2(0.0, -1.0)
	var expected_direction: Vector3 = -office.camera_rig.global_transform.basis.z
	expected_direction.y = 0.0
	expected_direction = expected_direction.normalized()
	var direction: Vector3 = office.player.movement_direction(camera_relative_move, office.camera_rig.global_transform.basis)
	assert(direction.dot(expected_direction) > 0.99, "角色移动没有跟随镜头水平朝向")
	var presentation_yaw_before: float = presentation.rotation.y
	var turn_frame := InputFrameClass.new()
	turn_frame.move = Vector2(-1.0, 0.0)
	office.process_input_frame(turn_frame, 0.2)
	assert(absf(presentation.rotation.y - presentation_yaw_before) > 0.01, "角色表现没有随移动方向平滑转向")
	assert(office.audio_events.history.any(func(event): return str(event.get("id", "")) == "footstep"), "办公室移动没有进入脚步音频事件路由")
	var office_visual_standing_y := float(presentation.position.y)
	office.player.position = Vector3(0.65, 1.0, -4.5)
	var collision_frame := InputFrameClass.new()
	collision_frame.move = Vector2(1.0, 0.0)
	office.process_input_frame(collision_frame, 0.2)
	assert(office.trace.has_event("collision"), "角色撞到办公室隔断后没有记录碰撞事件")
	office.player.position = office.vehicle.position + Vector3(0.0, 0.0, 1.0)
	# 载具存档回放独立使用一个新的秒表基线，避免前置镜头/碰撞操作把准点任务推进到 18:00。
	office.time_accumulator = 0.0
	var vehicle_enter_frame := InputFrameClass.new()
	vehicle_enter_frame.vehicle_enter_exit = true
	office.process_input_frame(vehicle_enter_frame, 0.016)
	assert(office.vehicle.driver == office.player, "办公室没有进入三轮车")
	assert(office.player.presentation_snapshot()["state"] == office.player.PresentationState.VEHICLE, "办公室进入三轮车后没有同步载具视觉状态")
	var office_player_visual: Node = office.player.get_node_or_null("Visual")
	if office_player_visual == null:
		office_player_visual = office.player.find_child("原创灰盒角色外观", true, false)
	assert(office_player_visual != null and float(office_player_visual.position.y) < office_visual_standing_y, "办公室玩家没有应用载具坐姿偏移")
	if office_player_visual != null and office_player_visual.get_node_or_null("AnimationPlayer") != null:
		assert(office_player_visual.get_node("AnimationPlayer").current_animation == "vehicle_default", "办公室候选玩家没有播放载具动作")
	var office_vehicle_start: Vector3 = office.vehicle.position
	var office_drive_frame := InputFrameClass.new()
	office_drive_frame.move = Vector2(0.0, -1.0)
	for index in range(8):
		office.process_input_frame(office_drive_frame, 0.1)
	assert(office.vehicle.position.distance_to(office_vehicle_start) > 0.1, "办公室三轮车驾驶没有产生位移")
	assert(office.audio_events.history.any(func(event): return str(event.get("id", "")) == "vehicle_engine"), "办公室载具移动没有进入引擎音频事件路由")
	var office_vehicle_checkpoint: Vector3 = office.vehicle.position
	var office_vehicle_checkpoint_speed: float = office.vehicle.current_speed
	assert(office.save_store.save_checkpoint(office.mission, office.perception, office.player.position, office.camera_rig.snapshot(), office.vehicle.snapshot(), office.OFFICE_PACK_ID), "办公室驾驶中存档写入失败")
	office.vehicle.position = Vector3(18.0, 0.7, 18.0)
	office.vehicle.current_speed = 0.0
	var release_vehicle_input := InputFrameClass.new()
	office.process_input_frame(release_vehicle_input, 0.016)
	var office_vehicle_load_frame := InputFrameClass.new()
	office_vehicle_load_frame.load_checkpoint = true
	office.process_input_frame(office_vehicle_load_frame, 0.016)
	assert(office.vehicle.position.distance_to(office_vehicle_checkpoint) < 0.001, "办公室读取存档没有恢复驾驶中的载具位置")
	assert(is_equal_approx(office.vehicle.current_speed, office_vehicle_checkpoint_speed), "办公室读取存档没有恢复驾驶中的载具速度")
	assert(office.vehicle.driver == office.player, "办公室读取存档没有恢复驾驶状态")
	assert(office.player.presentation_snapshot()["state"] == office.player.PresentationState.VEHICLE, "办公室读取驾驶存档后没有恢复玩家载具表现状态")
	var office_vehicle_exit_frame := InputFrameClass.new()
	office_vehicle_exit_frame.vehicle_enter_exit = true
	office.process_input_frame(office_vehicle_exit_frame, 0.016)
	assert(office.vehicle.driver == null, "办公室读取存档后无法退出载具")

	office.player.position = office.objective_target.position + Vector3(0.0, 0.0, 1.0)
	office.process_input_frame(InputFrameClass.new(), 0.016)
	assert(office.prompt_label.text == "E  离开办公室", "接近出口后没有显示交互提示")
	var early_interact = InputFrameClass.new()
	early_interact.interact = true
	office.process_input_frame(early_interact, 0.016)
	assert(office.mission.status == MissionStateClass.Status.ACTIVE, "17:59提前交互错误完成")
	assert(office.trace.has_event("interaction_blocked"), "提前交互没有记录阻断事件")
	assert(office.player.presentation_snapshot()["state"] == office.player.PresentationState.INTERACT, "办公室交互没有驱动角色表现状态")

	office.process_input_frame(InputFrameClass.new(), 1.0)
	var on_time_interact = InputFrameClass.new()
	on_time_interact.interact = true
	office.process_input_frame(on_time_interact, 0.016)
	assert(office.mission.status == MissionStateClass.Status.SUCCESS, "18:00后没有完成准点下班")
	assert(float(office.hud_visual.get("feedback_timer")) > 0.0, "办公室任务成功没有给出即时边缘反馈")
	assert(FileAccess.file_exists(office.save_store.save_path), "办公室任务成功后没有自动写入检查点")
	var success_checkpoint_file := FileAccess.open(office.save_store.save_path, FileAccess.READ)
	assert(success_checkpoint_file != null, "办公室成功检查点无法读取")
	var success_checkpoint = JSON.parse_string(success_checkpoint_file.get_as_text())
	success_checkpoint_file.close()
	assert(success_checkpoint is Dictionary, "办公室成功检查点不是有效对象")
	assert(int(success_checkpoint.get("mission", {}).get("status", -1)) == MissionStateClass.Status.SUCCESS, "办公室成功检查点没有保存 SUCCESS 状态")
	var restart_frame := InputFrameClass.new()
	restart_frame.restart = true
	office.process_input_frame(restart_frame, 0.016)
	assert(office.mission.status == MissionStateClass.Status.ACTIVE, "办公室成功后重试没有恢复任务")
	assert(office.trace.has_event("mission_restart"), "办公室重试没有记录任务重启事件")
	office.player.position = Vector3(2.0, 1.0, 3.0)
	office.camera_rig.set_orbit(35.0, -20.0)
	assert(office.save_store.save_checkpoint(office.mission, office.perception, office.player.position, office.camera_rig.snapshot(), {}, office.OFFICE_PACK_ID), "办公室集成测试存档写入失败")
	office.player.position = Vector3(-2.0, 1.0, -2.0)
	office.camera_rig.set_orbit(-20.0, -10.0)
	var load_frame := InputFrameClass.new()
	load_frame.load_checkpoint = true
	office.process_input_frame(load_frame, 0.016)
	assert(is_equal_approx(office.player.global_position.x, 2.0), "办公室读取存档没有恢复玩家位置")
	assert(is_equal_approx(office.camera_rig.yaw_degrees, 35.0), "办公室读取存档没有恢复镜头朝向")
	assert(office.trace.has_event("checkpoint_loaded"), "办公室读取存档没有记录成功事件")

	office.queue_free()
	await process_frame

	var detection_office = OfficeScene.instantiate()
	get_root().add_child(detection_office)
	await process_frame
	detection_office.player.position = detection_office.npc.position + Vector3(0.0, 0.0, 1.0)
	for index in range(8):
		detection_office.process_input_frame(InputFrameClass.new(), 0.2)
	assert(detection_office.mission.status == MissionStateClass.Status.FAILED, "NPC发现后任务没有失败")
	assert(float(detection_office.hud_visual.get("feedback_timer")) > 0.0, "NPC发现后没有给出即时边缘反馈")
	assert(detection_office.player.presentation_snapshot()["state"] == detection_office.player.PresentationState.FAIL, "NPC发现后玩家没有进入失败表现")
	assert(detection_office.perception_marker.visible and detection_office.perception_marker.text == "!", "NPC发现后没有显示感叹号标记")
	assert(detection_office.find_child("NPC警觉视觉层", true, false).visible, "NPC发现后没有显示警觉视线纯视觉层")
	assert(str(detection_office.find_child("NPC警觉视觉层", true, false).get_meta("state_color", "")) == "red", "NPC发现后的警觉视觉层没有使用红色状态")
	assert(bool(detection_office.find_child("NPC警觉视觉层", true, false).get_meta("mission_failed", false)), "NPC发现后警觉视觉层没有记录失败表现状态")
	assert(detection_office.failure_overlay.visible, "NPC发现后没有显示失败与重试覆盖层")
	assert(detection_office.trace.has_event("perception_state"), "NPC发现没有记录感知事件")
	assert(detection_office.trace.has_event("audio_event"), "NPC发现没有记录音频事件")

	detection_office.queue_free()
	await process_frame

	var search_office = OfficeScene.instantiate()
	get_root().add_child(search_office)
	await process_frame
	var npc_start: Vector3 = search_office.npc.global_position
	search_office.player.position = Vector3(3.0, 1.0, -0.8)
	for index in range(2):
		search_office.process_input_frame(InputFrameClass.new(), 0.15)
	assert(search_office.perception.status == 1, "NPC没有进入怀疑状态")
	assert(float(search_office.hud_visual.get("feedback_timer")) > 0.0, "NPC怀疑状态没有给出即时边缘反馈")
	assert(search_office.find_child("NPC警觉视觉层", true, false).visible, "NPC怀疑状态没有显示警觉视线纯视觉层")
	var initial_search_visual := search_office.find_child("NPC警觉视觉层", true, false)
	var initial_search_state := str(initial_search_visual.get_meta("state_color", ""))
	assert(initial_search_state == "yellow" or initial_search_state == "search", "NPC怀疑状态没有使用黄色或搜索警觉视觉层")
	search_office.player.position = Vector3(-4.0, 1.0, 6.0)
	search_office.process_input_frame(InputFrameClass.new(), 0.2)
	assert(search_office.trace.has_event("npc_search_started"), "NPC失去视线后没有开始搜索")
	assert(search_office.npc.global_position.distance_to(npc_start) > 0.01, "NPC搜索没有离开原位")
	var search_visual := search_office.find_child("NPC警觉视觉层", true, false)
	assert(str(search_visual.get_meta("state_color", "")) == "search", "NPC搜索没有切换搜索视觉状态")
	assert(search_visual.find_child("NPC警觉搜索扫描环", true, false).visible, "NPC搜索没有显示搜索扫描环")
	assert(search_office.office_scene_visuals.active_state == "office-02", "NPC搜索没有切换到 office-02 场景构图")
	var search_scene_feedback := search_office.office_scene_visuals.find_child("状态02搜索反馈灯", true, false) as MeshInstance3D
	assert(search_scene_feedback != null and search_scene_feedback.visible, "NPC搜索没有同步到 office-02 场景反馈灯")
	assert(str(search_office.office_scene_visuals.state_root.get_meta("runtime_awareness", "")) == "search", "office-02 场景没有记录真实搜索视觉状态")
	var search_marker := search_office.find_child("NPC最后目击点标记", true, false)
	assert(search_marker.visible, "NPC搜索没有显示最后目击点标记")
	var last_seen_position: Vector3 = search_office.perception.last_seen_position
	assert(is_equal_approx(search_marker.global_position.x, last_seen_position.x) and is_equal_approx(search_marker.global_position.z, last_seen_position.z), "最后目击点标记没有跟随感知系统位置")
	assert(search_marker.find_child("最后目击点扫描环", true, false) != null, "最后目击点标记缺少扫描环")
	assert(not bool(search_visual.get_meta("mission_failed", false)), "NPC搜索状态错误标记为任务失败")
	for index in range(70):
		search_office.process_input_frame(InputFrameClass.new(), 0.1)
	assert(search_office.trace.has_event("npc_search_reached"), "NPC搜索没有到达最后目击点")
	assert(search_office.trace.has_event("npc_search_return_started"), "NPC到达最后目击点后没有开始返回")
	assert(search_office.trace.has_event("npc_search_finished"), "NPC搜索完成后没有记录恢复巡查")
	assert(not search_office.npc_searching, "NPC搜索完成后仍保持搜索状态")
	assert(search_office.perception.status == 0, "NPC搜索完成后没有恢复平静状态")
	assert(search_office.npc.global_position.distance_to(search_office.npc_home_position) <= 0.01, "NPC搜索完成后没有回到巡查起点")
	assert(not search_marker.visible, "NPC搜索完成后最后目击点标记仍可见")
	search_office.queue_free()
	await process_frame

	var noise_office = OfficeScene.instantiate()
	get_root().add_child(noise_office)
	await process_frame
	noise_office.save_store.save_path = OS.get_temp_dir().path_join("reference-office-noise-%d.json" % Time.get_ticks_usec())
	var noise_source: Vector3 = noise_office.npc.global_position + Vector3(0.0, 0.0, 1.0)
	noise_office.player.position = noise_source
	assert(noise_office.perception.hear_noise(noise_source, 1.0, noise_office.npc.global_position), "NPC没有接收范围内的噪声刺激")
	assert(noise_office.perception.status == 1, "噪声刺激没有将 NPC 推进怀疑状态")
	assert(noise_office.perception.last_known_position().is_equal_approx(noise_source), "噪声刺激没有更新最后已知位置")
	noise_office.process_input_frame(InputFrameClass.new(), 0.016)
	assert(noise_office.npc_searching, "NPC听见噪声后没有进入搜索状态")
	assert(noise_office.npc_search_target.distance_to(Vector3(noise_source.x, noise_office.npc.global_position.y, noise_source.z)) < 0.001, "NPC搜索目标没有指向噪声位置")
	var noise_search_events: Array = noise_office.trace.events.filter(func(event): return str(event.get("type", "")) == "npc_search_started")
	assert(not noise_search_events.is_empty() and str(noise_search_events.back().get("payload", {}).get("stimulus", "")) == "noise", "NPC噪声搜索没有记录 stimulus=noise")
	assert(noise_office.save_store.save_checkpoint(noise_office.mission, noise_office.perception, noise_office.player.position, noise_office.camera_rig.snapshot(), noise_office.vehicle.snapshot(), noise_office.OFFICE_PACK_ID), "噪声感知状态存档失败")
	noise_office.perception.reset()
	assert(noise_office.save_store.load_checkpoint(noise_office.mission, noise_office.perception, noise_office.player, noise_office.camera_rig, noise_office.vehicle, noise_office.OFFICE_PACK_ID), "噪声感知状态读取失败")
	assert(noise_office.perception.last_heard_strength > 0.0, "读取存档没有恢复噪声记忆强度")
	assert(noise_office.perception.last_heard_position.distance_to(noise_source) < 0.001, "读取存档没有恢复噪声位置")
	noise_office.queue_free()
	await process_frame

	var hallway_office = OfficeScene.instantiate()
	get_root().add_child(hallway_office)
	await process_frame
	# 首帧巡查 NPC 会沿走廊移动到路线中段，固定相遇点以保持回放确定性。
	hallway_office.player.position = Vector3(7.0, 0.9, -4.5)
	hallway_office.process_input_frame(InputFrameClass.new(), 0.016)
	assert(hallway_office.trace.has_event("hallway_encounter"), "走廊突遇没有记录事件")
	assert(hallway_office.mission.status == MissionStateClass.Status.FAILED, "非蹲伏状态遇到走廊 NPC 没有失败")
	hallway_office.queue_free()
	await process_frame
	print("办公室潜行端到端回放测试通过")
	quit(0)

func _assert_visual_only_subtree(root: Node, label: String) -> void:
	assert(not (root is CollisionObject3D), label + "包含碰撞对象：" + root.name)
	assert(not (root is CollisionShape3D), label + "包含碰撞形状：" + root.name)
	assert(not (root is CollisionPolygon3D), label + "包含碰撞多边形：" + root.name)
	assert(not (root is NavigationRegion3D), label + "包含导航区域：" + root.name)
	assert(not (root is NavigationLink3D), label + "包含导航连接：" + root.name)
	assert(not (root is Area3D), label + "包含区域逻辑：" + root.name)
	for child in root.get_children():
		_assert_visual_only_subtree(child, label)

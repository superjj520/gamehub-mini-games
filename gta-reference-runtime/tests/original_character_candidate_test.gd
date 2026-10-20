extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")
const PlayerClass = preload("res://scripts/player_controller.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://content/asset-runtime-catalog-original-only.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("original-character-candidate-%d.json" % Time.get_ticks_usec()))
	root.add_child(office)
	await process_frame
	assert(office.initialized, "原创办公人员候选场景没有完成初始化")
	var visual: Node = office.player.get_node_or_null("Visual")
	assert(visual != null, "原创办公人员候选没有挂载 Visual 根节点")
	assert(visual.get_node_or_null("候选主角身体") != null, "原创办公人员候选缺少身体")
	assert(visual.get_node_or_null("候选主角衬衣") != null, "原创办公人员候选缺少衬衣")
	assert(visual.get_node_or_null("候选主角背包") != null, "原创办公人员候选缺少背包")
	assert(visual.get_node_or_null("候选主角夹克前襟-左") != null, "原创办公人员候选缺少夹克前襟层")
	assert(visual.get_node_or_null("候选主角背包扣带-左") != null, "原创办公人员候选缺少背包扣带细节")
	assert(visual.get_node_or_null("候选主角细节额前发束-左") != null, "原创办公人员候选缺少额前发型层")
	assert(visual.get_node_or_null("候选主角嘴部") != null, "原创办公人员候选缺少面部轮廓细节")
	assert(visual.get_node_or_null("候选主角鞋面侧条-左") != null, "原创办公人员候选缺少鞋面细节")
	assert(visual.get_node_or_null("候选主角头发") != null, "原创办公人员候选缺少短发轮廓")
	assert(visual.get_node_or_null("候选主角连帽内圈") != null, "原创办公人员候选缺少连帽内圈层")
	assert(visual.get_node_or_null("AnimationPlayer") != null, "原创办公人员候选缺少动画状态桥接入口")
	var high_detail_visual := visual.get_node_or_null("原创主角高细节视觉") as Node3D
	assert(high_detail_visual != null, "原创办公人员候选没有挂载高细节视觉模型")
	var high_detail_mesh_count := 0
	var high_detail_visible_mesh_count := 0
	for high_detail_mesh in high_detail_visual.find_children("*", "MeshInstance3D", true, false):
		high_detail_mesh_count += 1
		if bool(high_detail_mesh.visible):
			high_detail_visible_mesh_count += 1
		assert(bool(high_detail_mesh.get_meta("visual_only", false)), "高细节主角网格缺少 visual_only 标记：" + high_detail_mesh.name)
		assert(bool(high_detail_mesh.get_meta("candidate_visual_only", false)), "高细节主角网格缺少 candidate_visual_only 标记：" + high_detail_mesh.name)
	assert(high_detail_mesh_count > 0 and high_detail_visible_mesh_count > 0, "原创办公人员候选高细节模型没有可见网格")
	assert(high_detail_visual.find_child("AdvancedHead", true, false) != null, "高细节主角缺少头部姿态挂点")
	assert(high_detail_visual.find_child("AdvancedForearmL", true, false) != null, "高细节主角缺少左前臂姿态挂点")
	assert(high_detail_visual.find_child("AdvancedForearmR", true, false) != null, "高细节主角缺少右前臂姿态挂点")
	assert(visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "原创办公人员候选创建了碰撞对象")
	var player_mesh_count := 0
	for player_mesh in visual.find_children("*", "MeshInstance3D", true, false):
		player_mesh_count += 1
		assert(bool(player_mesh.get_meta("visual_only", false)), "原创办公人员候选主角网格缺少 visual_only 标记：" + player_mesh.name)
		assert(bool(player_mesh.get_meta("candidate_visual_only", false)), "原创办公人员候选主角网格缺少 candidate_visual_only 标记：" + player_mesh.name)
	assert(player_mesh_count >= 70, "原创办公人员候选主角网格数量不足，视觉候选可能未完整挂载")
	for mount_name in ["交互手部挂点", "载具挂点", "视线起点", "脚底碰撞参考点"]:
		assert(visual.get_node_or_null(mount_name) != null, "原创办公人员候选缺少挂点：" + mount_name)
	var animation_player: AnimationPlayer = visual.get_node("AnimationPlayer")
	for animation_name in ["idle_default", "walk_default", "interact_default", "typing_default", "vehicle_default", "hit_default", "fail_default"]:
		assert(animation_player.has_animation(animation_name), "原创办公人员候选缺少动画状态：" + animation_name)
		assert(animation_player.get_animation(animation_name).get_track_count() >= 1, "原创办公人员候选动画状态没有真实轨道：" + animation_name)
	var animation_result := AssetRuntimeCatalogClass.drive_animation_state(visual, "walk_default")
	assert(bool(animation_result.get("driven", false)), "原创办公人员候选动画状态桥接没有驱动 walk_default")
	assert(animation_player.current_animation == "walk_default", "原创办公人员候选 AnimationPlayer 没有进入 walk_default")
	var standing_body := visual.get_node("候选主角身体") as Node3D
	var standing_head := visual.get_node("候选主角头部") as Node3D
	var standing_body_y := standing_body.position.y
	var standing_head_y := standing_head.position.y
	var crouch_result := AssetRuntimeCatalogClass.drive_animation_state(visual, "crouch_default")
	assert(bool(crouch_result.get("candidate_visual", false)), "原创办公人员候选没有驱动蹲伏表现状态")
	assert(standing_body.position.y < standing_body_y, "原创办公人员候选蹲伏状态没有降低躯干")
	assert(standing_head.position.y < standing_head_y, "原创办公人员候选蹲伏状态没有降低头部")
	assert(bool(visual.get_node("候选主角背包").visible), "原创办公人员候选蹲伏状态错误隐藏背包")
	var standing_result := AssetRuntimeCatalogClass.drive_animation_state(visual, "idle_default")
	assert(bool(standing_result.get("candidate_visual", false)), "原创办公人员候选没有恢复站立表现状态")
	visual.set_candidate_context("city")
	var city_result := AssetRuntimeCatalogClass.drive_animation_state(visual, "idle_default")
	assert(bool(city_result.get("candidate_visual", false)), "原创办公人员候选城市上下文没有恢复表现状态")
	assert(bool(visual.get_node("候选主角载具红色前片").visible), "原创办公人员候选城市上下文没有显示红色服装前片")
	assert(bool(visual.get_node("候选主角载具红色后片").visible), "原创办公人员候选城市上下文没有显示红色服装后片")
	visual.set_candidate_context("office")
	assert(not bool(visual.get_node("候选主角载具红色前片").visible), "原创办公人员候选办公室上下文错误显示红色服装")
	var vehicle_result := AssetRuntimeCatalogClass.drive_animation_state(visual, "vehicle_default")
	assert(bool(vehicle_result.get("candidate_visual", false)), "原创办公人员候选没有驱动载具表现状态")
	var driver_back := visual.get_node_or_null("候选主角载具红色后片") as Node3D
	assert(driver_back != null and driver_back.visible, "原创办公人员候选载具状态没有显示红色上衣后片")
	assert(driver_back.scale.y < 1.40, "原创办公人员候选载具红色上衣纵向比例仍然过长")
	assert(not bool(visual.get_node("候选主角背包").visible), "原创办公人员候选载具状态仍被城市背包遮挡")
	var vehicle_visual := office.vehicle.get_node_or_null("Visual") as Node3D
	assert(vehicle_visual != null, "原创三轮载具候选没有挂载 Visual 根节点")
	var left_grip := vehicle_visual.get_node_or_null("候选三轮车左把手胶套") as Node3D
	var right_grip := vehicle_visual.get_node_or_null("候选三轮车右把手胶套") as Node3D
	assert(left_grip != null and right_grip != null, "原创三轮载具候选缺少左右把手接触节点")
	# 进入载具后，角色状态与双手接触点必须同时成立；这是驾驶镜头的硬接触契约。
	office.player.global_position = office.vehicle.global_position + Vector3(0.0, 0.0, 0.55)
	assert(office.vehicle.enter(office.player), "原创三轮载具候选无法进入载具")
	office.player.trigger_presentation_action("vehicle")
	await process_frame
	var left_hand := visual.get_node("候选主角手部-左") as Node3D
	var right_hand := visual.get_node("候选主角手部-右") as Node3D
	var left_hand_error := left_hand.global_position.distance_to(left_grip.global_position)
	var right_hand_error := right_hand.global_position.distance_to(right_grip.global_position)
	assert(left_hand_error < 0.22, "原创驾驶状态左手没有贴合左把手：%.3fm" % left_hand_error)
	assert(right_hand_error < 0.22, "原创驾驶状态右手没有贴合右把手：%.3fm" % right_hand_error)
	assert(office.player.presentation_snapshot().get("state", -1) == PlayerClass.PresentationState.VEHICLE, "原创驾驶状态没有进入 vehicle_default")
	office.vehicle.exit()
	var typing_result := AssetRuntimeCatalogClass.drive_animation_state(visual, "typing_default")
	assert(bool(typing_result.get("candidate_visual", false)), "原创办公人员候选没有驱动办公室打字表现状态")
	assert(bool(visual.get_node("候选主角办公室针织前片").visible), "原创办公人员候选打字状态没有显示办公室针织上衣")
	assert(not bool(driver_back.visible), "原创办公人员候选打字状态仍显示载具红色上衣")
	var typing_high_detail := visual.get_node("原创主角高细节视觉") as Node3D
	assert(typing_high_detail.position.y < -0.05, "原创办公人员候选高细节模型没有随打字状态下沉到椅面")
	assert(typing_high_detail.scale.y < 0.95, "原创办公人员候选高细节模型没有进入打字坐姿纵向收拢")
	assert(typing_high_detail.rotation_degrees.x < -5.0, "原创办公人员候选高细节模型没有向桌面前倾")
	var typing_body := visual.get_node("候选主角办公室针织主体") as Node3D
	var typing_front := visual.get_node("候选主角办公室针织前片") as Node3D
	var typing_back := visual.get_node("候选主角办公室针织后片") as Node3D
	assert(absf(typing_front.position.y - typing_body.position.y) < 0.12, "原创办公人员候选针织前片没有跟随坐姿主体下沉")
	assert(absf(typing_back.position.y - typing_body.position.y) < 0.12, "原创办公人员候选针织后片没有跟随坐姿主体下沉")
	var typing_hand := visual.get_node("候选主角手部-左") as Node3D
	var typing_hand_before := typing_hand.position
	await process_frame
	await process_frame
	var typing_hand_after := typing_hand.position
	assert(typing_hand_before.distance_to(typing_hand_after) > 0.0001, "原创办公人员候选打字状态没有连续手部微动作")
	assert(visual.get_node_or_null("Character") == null, "原创办公人员候选不应意外挂载第三方基础角色")

	var npc_visual: Node = office.npc.get_node_or_null("Visual")
	assert(npc_visual != null, "原创办公室 NPC 候选没有挂载 Visual 根节点")
	assert(npc_visual.find_child("候选NPC身体", true, false) != null, "原创办公室 NPC 候选缺少身体")
	assert(npc_visual.find_child("候选NPC袖口-左", true, false) != null, "原创办公室 NPC 候选缺少袖口细节")
	assert(npc_visual.find_child("候选NPC鞋底-左", true, false) != null, "原创办公室 NPC 候选缺少鞋底细节")
	assert(npc_visual.find_child("候选NPC平板外框", true, false) != null, "原创办公室 NPC 候选缺少平板外框")
	assert(npc_visual.find_child("候选NPC平板状态灯", true, false) != null, "原创办公室 NPC 候选缺少平板状态灯")
	assert(npc_visual.find_child("候选NPC夹克翻领-左", true, false) != null, "原创办公室 NPC 候选缺少夹克翻领")
	assert(npc_visual.find_child("候选NPC夹克前襟缝线-左", true, false) != null, "原创办公室 NPC 候选缺少前襟缝线")
	assert(npc_visual.find_child("候选NPC平板手带", true, false) != null, "原创办公室 NPC 候选缺少平板手部接触层")
	assert(npc_visual.find_child("候选NPC左腕手表", true, false) != null, "原创办公室 NPC 候选缺少手腕识别细节")
	assert(npc_visual.find_child("候选NPC鞋带-左", true, false) != null, "原创办公室 NPC 候选缺少鞋部细节")
	assert(npc_visual.find_child("候选NPC搜索状态环", true, false) != null, "原创办公室 NPC 候选缺少搜索状态环")
	assert(npc_visual.find_child("候选NPC警觉状态环", true, false) != null, "原创办公室 NPC 候选缺少警觉状态环")
	assert(npc_visual.find_child("候选NPC搜索探照束", true, false) != null, "原创办公室 NPC 候选缺少搜索探照束")
	assert(npc_visual.find_child("候选NPC警觉探照束", true, false) != null, "原创办公室 NPC 候选缺少警觉探照束")
	assert(npc_visual.find_children("*", "CollisionObject3D", true, false).is_empty(), "原创办公室 NPC 候选创建了碰撞对象")
	for npc_mesh in npc_visual.find_children("*", "MeshInstance3D", true, false):
		assert(bool(npc_mesh.get_meta("visual_only", false)), "原创办公室 NPC 网格缺少 visual_only 标记：" + npc_mesh.name)
		assert(bool(npc_mesh.get_meta("candidate_visual_only", false)), "原创办公室 NPC 网格缺少 candidate_visual_only 标记：" + npc_mesh.name)
	var search_result := AssetRuntimeCatalogClass.drive_animation_state(npc_visual, "search_default")
	assert(bool(search_result.get("candidate_visual", false)), "原创办公室 NPC 搜索状态没有驱动候选表现")
	var npc_animation_player := npc_visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	assert(npc_animation_player != null and npc_animation_player.get_animation("search_default").get_track_count() >= 3, "原创办公室 NPC 搜索状态缺少头部、身体和平板轨道")
	var search_ring := npc_visual.find_child("候选NPC搜索状态环", true, false) as Node3D
	var alert_ring := npc_visual.find_child("候选NPC警觉状态环", true, false) as Node3D
	var search_beam := npc_visual.find_child("候选NPC搜索探照束", true, false) as Node3D
	var alert_beam := npc_visual.find_child("候选NPC警觉探照束", true, false) as Node3D
	assert(search_ring != null, "原创办公室 NPC 搜索状态环节点路径无效")
	assert(alert_ring != null, "原创办公室 NPC 警觉状态环节点路径无效")
	assert(bool(search_ring.visible), "原创办公室 NPC 搜索状态环没有显示")
	assert(not bool(alert_ring.visible), "原创办公室 NPC 搜索状态错误显示警觉环")
	assert(bool(search_beam.visible), "原创办公室 NPC 搜索探照束没有显示")
	assert(not bool(alert_beam.visible), "原创办公室 NPC 搜索状态错误显示警觉探照束")
	var search_ring_scale_before := search_ring.scale
	await process_frame
	await process_frame
	var search_ring_scale_after := search_ring.scale
	assert(search_ring_scale_before.distance_to(search_ring_scale_after) > 0.0001, "原创办公室 NPC 搜索状态环没有连续脉冲")
	var alert_result := AssetRuntimeCatalogClass.drive_animation_state(npc_visual, "alert_default")
	assert(bool(alert_result.get("candidate_visual", false)), "原创办公室 NPC 警觉状态没有驱动候选表现")
	assert(bool(alert_ring.visible), "原创办公室 NPC 警觉状态环没有显示")
	assert(not bool(search_ring.visible), "原创办公室 NPC 警觉状态错误显示搜索环")
	assert(bool(alert_beam.visible), "原创办公室 NPC 警觉探照束没有显示")
	assert(not bool(search_beam.visible), "原创办公室 NPC 警觉状态错误显示搜索探照束")
	office.free()
	await process_frame
	print("原创办公人员候选接入契约测试通过；视觉截图仍需图形窗口人工验收")
	quit(0)

extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const RetouchScript = preload("res://makehuman_office_npc_retouch.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")

const STATES := ["idle_default", "walk_default", "search_default", "alert_default"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	get_root().add_child(office)
	await process_frame
	if not office.initialized:
		_fail("办公室候选人物覆盖后没有完成初始化")
		return
	var visual: Node = office.npc.get_node_or_null("Visual")
	if visual == null:
		_fail("办公室 NPC 没有挂载候选 Visual")
		return
	if office.npc.get_node_or_null("原创灰盒NPC外观") != null:
		_fail("MakeHuman 候选挂载后仍保留 NPC 灰盒回退")
		return
	var skeleton_nodes := visual.find_children("*", "Skeleton3D", true, false)
	if skeleton_nodes.is_empty():
		_fail("MakeHuman 候选 Visual 缺少 Skeleton3D")
		return
	var skeleton := skeleton_nodes[0] as Skeleton3D
	if skeleton.get_bone_count() < 40:
		_fail("MakeHuman 候选骨骼数量不足，无法作为办公室人物候选")
		return
	if visual.scale.distance_to(Vector3.ONE) > 0.001:
		_fail("MakeHuman 候选挂载后发生运行时缩放补丁")
		return

	# 将隔离预览的材质返工与真实骨骼姿态驱动挂到办公室 NPC 实例上。
	visual.set_script(RetouchScript)
	var preserve_imported_materials := OS.get_environment("MAKEHUMAN_KEEP_IMPORTED_MATERIALS") == "1"
	var reference_office_materials := OS.get_environment("MAKEHUMAN_REFERENCE_OFFICE_MATERIALS") == "1"
	var use_elegant_suit_candidate := OS.get_environment("MAKEHUMAN_USE_ELEGANT_SUIT") == "1"
	var use_elegant_suit_skinned := OS.get_environment("MAKEHUMAN_USE_ELEGANT_SUIT_SKINNED") == "1"
	if reference_office_materials and not preserve_imported_materials:
		_fail("V3 参考服装模式必须同时启用保留导入材质")
		return
	visual.set_meta("preserve_imported_materials", preserve_imported_materials)
	visual.set_meta("reference_office_materials", reference_office_materials)
	visual.set_meta("use_elegant_suit_candidate", use_elegant_suit_candidate)
	visual.set_meta("use_elegant_suit_skinned", use_elegant_suit_skinned)
	visual.call("_ready")
	if use_elegant_suit_skinned:
		var skinned_suit_found := false
		var imported_worksuit_visible := false
		for item in visual.find_children("*", "MeshInstance3D", true, false):
			var mesh := item as MeshInstance3D
			var identity := (str(mesh.name) + " " + str(mesh.mesh.resource_name if mesh.mesh != null else "")).to_lower()
			if identity.contains("elegantsuit01_skinned"):
				skinned_suit_found = true
			if (identity.contains("male_worksuit01") or identity.contains("worksuit")) and mesh.visible:
				imported_worksuit_visible = true
		if not skinned_suit_found:
			_fail("蒙皮西装模式没有找到 male_elegantsuit01_skinned 网格")
			return
		if imported_worksuit_visible:
			_fail("蒙皮西装模式仍显示原 male_worksuit01 工装网格")
			return
	var animation_player := visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		_fail("候选返工适配器没有提供正式 AnimationPlayer 桥接")
		return
	var animation_probe := visual.find_child("正式动画桥接探针", true, false) as Node3D
	if animation_probe == null:
		_fail("候选返工适配器缺少真实骨骼挂点下的动画探针")
		return
	for state_name in STATES:
		var baseline := _capture_candidate_pose(skeleton, state_name)
		var animation_result: Dictionary = AssetRuntimeCatalogClass.drive_animation_state(visual, state_name)
		if not bool(animation_result.get("driven", false)) or animation_player.current_animation != state_name:
			_fail("正式动画状态桥接没有驱动候选状态：%s" % state_name)
			return
		animation_player.advance(0.25)
		if animation_probe.rotation_degrees.length() <= 0.0001:
			_fail("正式动画状态桥接没有驱动真实骨骼挂点探针：%s" % state_name)
			return
		visual.call("drive_candidate_state", state_name)
		visual.call("_process", 0.37)
		if not _skeleton_pose_changed(skeleton, state_name, baseline):
			_fail("MakeHuman 候选姿态没有真实改变：%s" % state_name)
			return

	var candidate_role := str(visual.get_meta("candidate_role", "supervisor"))
	var backpack := office.npc.get_node_or_null("Visual").find_child("视觉返工背包", true, false) as MeshInstance3D
	if candidate_role == "supervisor":
		if backpack != null:
			_fail("主管角色不应生成主角背包视觉层")
			return
	else:
		if backpack == null:
			_fail("非主管办公室候选没有生成视觉返工背包挂点")
			return
		var backpack_attachment := backpack.get_parent() as BoneAttachment3D
		if backpack_attachment == null or backpack_attachment.bone_name != "spine_02":
			_fail("办公室候选背包没有挂到 spine_02 的 BoneAttachment3D")
			return
		if not backpack_attachment.scale.is_equal_approx(Vector3(0.88, 0.90, 0.88)):
			_fail("办公室候选背包比例没有应用视觉 V2 覆盖")
			return
		var front_pocket := office.npc.get_node_or_null("Visual").find_child("视觉返工背包前袋", true, false) as MeshInstance3D
		if front_pocket == null or front_pocket.get_parent() != backpack_attachment:
			_fail("办公室候选背包缺少前袋细节")
			return
		var reflective_strip := office.npc.get_node_or_null("Visual").find_child("视觉返工背包反光条", true, false) as MeshInstance3D
		if reflective_strip == null or reflective_strip.get_parent() != backpack_attachment:
			_fail("办公室候选背包缺少反光条细节")
			return
	var badge := office.npc.get_node_or_null("Visual").find_child("参考服装工牌", true, false) as MeshInstance3D
	var badge_attachment := badge.get_parent() as BoneAttachment3D if badge != null else null
	if badge == null or badge_attachment == null or badge_attachment.bone_name != "spine_03":
		_fail("办公室 NPC 候选缺少 spine_03 工牌挂点")
		return
	var radio := office.npc.get_node_or_null("Visual").find_child("视觉返工对讲机", true, false) as MeshInstance3D
	var radio_attachment := radio.get_parent() as BoneAttachment3D if radio != null else null
	if radio == null or radio_attachment == null or radio_attachment.bone_name != "spine_02":
		_fail("办公室 NPC 候选缺少 spine_02 对讲机挂点")
		return
	visual.call("drive_candidate_state", "alert_default")
	visual.call("_process", 0.12)
	var alert_badge_material := badge.material_override as StandardMaterial3D
	if alert_badge_material == null or alert_badge_material.albedo_color.r <= alert_badge_material.albedo_color.g:
		_fail("办公室 NPC 警觉状态没有切换工牌视觉反馈")
		return
	if office.perception == null or office.mission == null or office.camera_rig == null:
		_fail("MakeHuman 候选挂载破坏办公室感知、任务或镜头对象")
		return
	print("MakeHuman 候选已接入隔离办公室真实运行时：角色身份、Visual、Skeleton3D、四状态姿态和办公室系统保持完整")
	office.queue_free()
	await process_frame
	quit(0)

func _capture_candidate_pose(skeleton: Skeleton3D, state_name: String) -> Dictionary:
	var baseline := {}
	for bone_name in _candidate_bones()[state_name]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			_fail("MakeHuman 候选缺少声明骨骼：%s" % bone_name)
			return {}
		baseline[bone_name] = skeleton.get_bone_pose_rotation(bone_index)
	return baseline

func _candidate_bones() -> Dictionary:
	return {
		"idle_default": ["spine_02"],
		"walk_default": ["upperarm_l", "thigh_l"],
		"search_default": ["head", "spine_02"],
		"alert_default": ["head", "spine_03"],
	}

func _skeleton_pose_changed(skeleton: Skeleton3D, state_name: String, baseline: Dictionary) -> bool:
	var candidate_bones := {
		"idle_default": ["spine_02"],
		"walk_default": ["upperarm_l", "thigh_l"],
		"search_default": ["head", "spine_02"],
		"alert_default": ["head", "spine_03"],
	}
	var changed := false
	for bone_name in candidate_bones[state_name]:
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0 or not baseline.has(bone_name):
			return false
		if skeleton.get_bone_pose_rotation(bone_index).angle_to(baseline[bone_name]) > 0.0001:
			changed = true
	return changed

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

extends SceneTree

## 城市完整候选包的外置接入契约。
## 人群场景仍保留在 art-source，测试将它覆盖到真实城市运行时，
## 这样不用修改正式运行时目录，也不会改变正式源指纹。

const CityScene := preload("res://scenes/city.tscn")
const AssetRuntimeCatalogClass := preload("res://scripts/asset_runtime_catalog.gd")
const InputFrameClass := preload("res://scripts/input_frame.gd")
const MissionChainClass := preload("res://scripts/mission_chain.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate_root := ProjectSettings.globalize_path("res://../art-source")
	var configured_catalog_path := OS.get_environment("CITY_CANDIDATE_CATALOG").strip_edges()
	var catalog_path := configured_catalog_path if not configured_catalog_path.is_empty() else candidate_root.path_join("city-full-kit-candidate/asset-runtime-catalog-city-full-kit-override.json")
	if catalog_path.begins_with("res://"):
		assert(ResourceLoader.exists(catalog_path), "城市候选目录不存在：%s" % catalog_path)
	else:
		assert(FileAccess.file_exists(catalog_path), "城市候选目录不存在：%s" % catalog_path)
	assert(FileAccess.file_exists(catalog_path), "城市完整候选目录不存在")
	var catalog := AssetRuntimeCatalogClass.load_json(catalog_path)
	var catalog_errors := AssetRuntimeCatalogClass.validate(catalog)
	assert(catalog_errors.is_empty(), "城市完整候选目录契约校验失败：%s" % [catalog_errors])
	var player_slot: Dictionary = {}
	for raw_slot in catalog.get("slots", []):
		if raw_slot is Dictionary and str(raw_slot.get("id", "")) in ["player-character", "city-player-character"]:
			player_slot = raw_slot
			if str(raw_slot.get("id", "")) == "city-player-character":
				break
	var is_makehuman_player := str(player_slot.get("scene_path", "")).contains("makehuman")

	var city = CityScene.instantiate()
	city.set_meta("asset_catalog_path", catalog_path)
	city.set_meta("settings_path", OS.get_temp_dir().path_join("city-full-kit-candidate-%d.json" % Time.get_ticks_usec()))
	city.set_meta("save_path", OS.get_temp_dir().path_join("city-full-kit-candidate-save-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(city)
	await process_frame
	await process_frame
	assert(city.initialized, "城市完整候选包接入后运行时没有完成初始化")
	assert(city.mission.status == MissionChainClass.Status.ACTIVE, "城市完整候选包接入后任务没有保持 ACTIVE")
	assert(city.player.get_node_or_null("Visual") != null, "城市完整候选包没有挂载玩家候选")
	assert(city.player.get_node("Visual").get_script() != null, "城市玩家候选脚本缺失")
	for player_shadow_name in ["候选主角左脚软接触阴影", "候选主角右脚软接触阴影"]:
		var player_shadow := city.player.get_node("Visual").find_child(player_shadow_name, true, false) as MeshInstance3D
		assert(player_shadow != null, "城市玩家候选缺少接地阴影：" + player_shadow_name)
		assert(player_shadow.material_override is StandardMaterial3D, "城市玩家接地阴影缺少标准软阴影材质：" + player_shadow_name)
		assert((player_shadow.material_override as StandardMaterial3D).albedo_texture != null, "城市玩家接地阴影缺少径向渐变纹理：" + player_shadow_name)
		assert(bool(player_shadow.get_meta("ground_contact_visual", false)), "城市玩家接地阴影缺少 ground_contact_visual 标记：" + player_shadow_name)
		assert(bool(player_shadow.get_meta("visual_only", false)), "城市玩家接地阴影不得携带运行时逻辑：" + player_shadow_name)
		assert(player_shadow.find_children("*", "CollisionObject3D", true, false).is_empty(), "城市玩家接地阴影不得创建碰撞：" + player_shadow_name)
	if is_makehuman_player:
		assert(str(city.player.get_node("Visual").get_script().resource_path).contains("makehuman_player_visual_candidate.gd"), "MakeHuman 城市玩家没有挂载写实玩家包装器")
		assert(city.player.get_node("Visual").find_child("候选主角身体", true, false) != null, "MakeHuman 城市玩家缺少蒙皮身体实例")
		assert(city.player.get_node("Visual").find_child("候选主角背包", true, false) != null, "MakeHuman 城市玩家缺少背包骨骼挂点契约")
		assert(city.player.get_node("Visual").find_child("AnimationPlayer", true, false) != null, "MakeHuman 城市玩家缺少动画状态播放器")
		var makehuman_suit := city.player.get_node("Visual").find_child("Human_male_elegantsuit01_skinned_export", true, false) as MeshInstance3D
		assert(makehuman_suit != null, "MakeHuman 城市玩家缺少西装蒙皮网格")
		assert(bool(makehuman_suit.get_meta("city_outerwear_applied", false)), "MakeHuman 城市玩家没有应用城市红色外套上下文")
		assert(makehuman_suit.material_override is ShaderMaterial, "MakeHuman 城市玩家红色外套没有生成候选材质覆盖")
	else:
		assert(str(city.player.get_node("Visual").get_script().resource_path).contains("player_character_visual_candidate.gd"), "城市玩家没有挂载独立城市视觉候选脚本")
		var city_jacket := city.player.get_node("Visual").find_child("原创夹克肩部", true, false) as MeshInstance3D
		assert(city_jacket != null, "城市玩家候选缺少夹克肩部视觉节点")
		var city_jacket_material := city_jacket.material_override as StandardMaterial3D
		assert(city_jacket_material != null, "城市玩家候选夹克没有材质覆盖")
		assert(city_jacket_material.albedo_color.r > city_jacket_material.albedo_color.g * 1.6 and city_jacket_material.albedo_color.r > city_jacket_material.albedo_color.b * 1.6, "城市玩家候选夹克没有形成参考帧砖红识别色")
	assert(city.player.get_node_or_null("原创灰盒角色外观") == null, "玩家候选接入后仍保留灰盒回退")
	assert(city.vehicle.get_node_or_null("Visual") != null, "城市完整候选包没有挂载三轮车候选")
	assert(city.vehicle.get_node("Visual").find_child("ThreeWheelDelivery", true, false) != null, "三轮车候选 GLB 没有进入城市运行时")
	assert(city.vehicle.get_node("Visual").find_child("候选三轮车后尾灯", true, false) != null, "三轮车候选缺少车尾灯视觉细节")
	var vehicle_contact_shadows: Array[Node] = city.vehicle.get_node("Visual").find_children("候选三轮车软接触阴影-*", "MeshInstance3D", true, false)
	assert(vehicle_contact_shadows.size() == 3, "三轮车候选缺少三处轮胎软接触阴影")
	for contact_shadow in vehicle_contact_shadows:
		assert(bool(contact_shadow.get_meta("ground_contact_visual", false)), "三轮车接触阴影缺少 ground_contact_visual 标记")
		assert(bool(contact_shadow.get_meta("visual_only", false)), "三轮车接触阴影不得携带运行时逻辑")
		assert(contact_shadow.get_node_or_null("CollisionShape3D") == null, "三轮车接触阴影不得创建碰撞")
	for marker_name in ["驾驶座挂点", "上下车点", "前轮接触点", "左后轮接触点", "右后轮接触点", "货架挂点"]:
		assert(city.vehicle.get_node_or_null("Visual/" + marker_name) is Marker3D, "三轮车候选缺少运行时挂点：" + marker_name)
	assert(city.vehicle.get_node_or_null("原创灰盒三轮车外观") == null, "三轮车候选接入后仍保留灰盒回退")
	assert(city.get_node_or_null("Visual") != null, "城市完整候选包没有挂载城市环境候选")
	var city_state_visuals := city.get_node_or_null("城市十一状态原创视觉层") as Node3D
	assert(city_state_visuals != null, "城市完整候选包没有挂载分段状态表现层")
	assert(city_state_visuals.visible, "城市视频背景遮挡流程错误隐藏了分段状态表现层")
	# 逐段探针 city-05/06/07：不能只证明状态脚本存在，必须证明离店、登记台、扫码成功三套表现层
	# 会实际生成在当前状态根下，并且被标记为纯视觉层。这样可以拦住“代码写了但运行时只剩背景卡”的回归。
	var city_mid_scene_contracts := {
		"city-05": ["状态05后场装卸台", "状态05卸货木托盘", "状态05后场排水沟"],
		"city-06": ["状态登记工作人员", "状态登记台", "状态登记二维码", "状态登记待扫描提示牌"],
		"city-07": ["状态登记工作人员", "状态登记台", "状态登记二维码", "状态登记成功提示牌", "状态登记成功文字"],
	}
	for mid_scene_state in city_mid_scene_contracts.keys():
		city_state_visuals.apply_runtime_state(mid_scene_state, "candidate_mid_scene_contract")
		var mid_scene_root := city_state_visuals.get_node_or_null("Visual") as Node3D
		assert(mid_scene_root != null, "%s 没有生成状态 Visual 根" % mid_scene_state)
		assert(mid_scene_root.visible, "%s 状态 Visual 根被错误隐藏" % mid_scene_state)
		assert(str(mid_scene_root.get_meta("city_scene_state", "")) == mid_scene_state, "%s 状态根元数据不同步" % mid_scene_state)
		var mid_scene_contract: Dictionary = city_state_visuals.get_meta("visual_state_contract", {})
		assert(str(mid_scene_contract.get("state", "")) == mid_scene_state, "%s 没有写入对应视觉状态契约" % mid_scene_state)
		for required_visual_name in city_mid_scene_contracts[mid_scene_state]:
			var required_visual := mid_scene_root.find_child(required_visual_name, true, false)
			assert(required_visual != null and required_visual.visible, "%s 缺少可见前景表现层：%s" % [mid_scene_state, required_visual_name])
			assert(bool(required_visual.get_meta("visual_only", false)), "%s 前景表现层不得携带运行时逻辑：%s" % [mid_scene_state, required_visual_name])
	# 全部十一段状态门禁：每一段都必须实际生成可见原创视觉根、状态契约和
	# 至少一个可见网格。它只证明运行时没有空场景或灰盒回退，不替代逐帧视觉签收。
	for city_state_id in ["city-01", "city-02", "city-03", "city-04", "city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11"]:
		city_state_visuals.apply_runtime_state(city_state_id, "candidate_all_city_state_contract")
		var city_state_root := city_state_visuals.get_node_or_null("Visual") as Node3D
		assert(city_state_root != null and city_state_root.visible, "%s 没有生成可见城市状态根" % city_state_id)
		assert(str(city_state_root.get_meta("city_scene_state", "")) == city_state_id, "%s 城市状态根元数据错误" % city_state_id)
		var city_state_contract: Dictionary = city_state_visuals.get_meta("visual_state_contract", {})
		assert(str(city_state_contract.get("state", "")) == city_state_id, "%s 没有写入当前视觉状态契约" % city_state_id)
		assert((city_state_contract.get("required_layers", []) as Array).size() >= 3, "%s 视觉状态契约层数不足" % city_state_id)
		var visible_state_meshes := 0
		for state_mesh in city_state_root.find_children("*", "MeshInstance3D", true, false):
			if (state_mesh as MeshInstance3D).visible:
				visible_state_meshes += 1
		assert(visible_state_meshes > 0, "%s 运行时没有可见视觉网格" % city_state_id)
	city_state_visuals.apply_runtime_state("city-01", "candidate_mid_scene_contract_restore")
	await process_frame
	var candidate_catalog_path := str(catalog_path)
	if candidate_catalog_path.ends_with("asset-runtime-catalog-full-candidates.json"):
		assert(bool(city.get_meta("candidate_video_backdrop", false)), "完整候选城市没有启用用户授权视频背景元数据")
		assert(str(city.get_meta("candidate_video_backdrop_id", "")) == "city-01", "完整候选城市视频背景没有锁定 city-01")
	await process_frame
	var exterior_store_shelf := city.get_node("Visual").find_child("候选商店内景左货架", true, false) as Node3D
	assert(exterior_store_shelf != null and not exterior_store_shelf.visible, "城市外景候选不应让店内货架遮挡首店构图")
	assert(city.get_node("Visual").find_child("候选原创小型城市楼", true, false) != null, "城市原创小型楼候选没有进入运行时")
	assert(city.get_node("Visual").find_child("候选原创中型城市楼", true, false) != null, "城市原创中型楼候选没有进入运行时")
	assert(city.get_node("Visual").find_child("候选原创大型城市楼", true, false) != null, "城市原创大型楼候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创连续街区行道树树冠", true, false) != null, "城市行道树候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创连续街区路缘", true, false) != null, "城市路缘候选没有进入运行时")
	var asphalt := city.get_node("Visual").find_child("原创连续街区沥青路面", true, false) as MeshInstance3D
	assert(asphalt != null, "城市沥青路面候选没有进入运行时")
	var asphalt_material := asphalt.material_override as StandardMaterial3D
	assert(asphalt_material != null and ((asphalt_material.albedo_texture != null and asphalt_material.normal_texture != null) or bool(asphalt_material.get_meta("original_procedural_asset", false))), "城市沥青路面候选缺少已登记的 PBR 或原创程序化材质")
	assert(city.get_node("Visual").find_child("原创连续街区遮阳棚", true, false) != null, "城市遮阳棚候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创街区供电杆", true, false) != null, "城市供电杆候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创街区供电线", true, false) != null, "城市供电线候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创配送货箱", true, false) != null, "城市配送货箱候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创配送站牌", true, false) != null, "城市配送站牌候选没有进入运行时")
	for landmark_name in [
		"原创场景首店入口招牌",
		"原创场景登记点路线牌",
		"原创场景主干道斑马线",
		"原创场景路口红灯",
		"原创场景后场货箱",
		"原创场景终点门前文字"
	]:
		var landmark := city.get_node("Visual").find_child(landmark_name, true, false)
		assert(landmark != null, "城市场景地标层缺少：" + landmark_name)
		assert(bool(landmark.get_meta("visual_only", false)), "城市场景地标必须保持 visual_only：" + landmark_name)
		assert(bool(landmark.get_meta("candidate_visual_only", false)), "城市场景地标必须保持 candidate_visual_only：" + landmark_name)
	for landmark in city.get_node("Visual").find_children("原创场景*", "", true, false):
		assert(not (landmark is CollisionObject3D), "城市场景地标不得创建碰撞对象：" + landmark.name)
		assert(not (landmark is NavigationRegion3D), "城市场景地标不得创建导航对象：" + landmark.name)
	city.set_meta("reference_capture_scenario", "city-08")
	await process_frame
	var drive_landmark := city.get_node("Visual").find_child("原创场景主干道斑马线", true, false)
	var storefront_landmark := city.get_node("Visual").find_child("原创场景首店入口招牌", true, false)
	assert(drive_landmark.visible, "city-08 驾驶段没有显示主干道地标")
	assert(not storefront_landmark.visible, "city-08 驾驶段错误显示首店地标")
	var landmark_visibility_contract := {
		"city-01": ["原创场景首店入口招牌"],
		"city-02": ["原创场景首店入口招牌"],
		"city-03": ["原创场景首店入口招牌"],
		"city-04": ["原创场景首店入口招牌"],
		"city-05": ["原创场景首店入口招牌", "原创场景后场货箱"],
		"city-06": ["原创场景登记点路线牌"],
		"city-07": ["原创场景登记点路线牌"],
		"city-08": ["原创场景主干道斑马线"],
		"city-09": ["原创场景主干道斑马线"],
		"city-10": ["原创场景主干道斑马线", "原创场景后场货箱"],
		"city-11": ["原创场景后场货箱", "原创场景终点门前文字"],
	}
	var landmark_names := [
		"原创场景首店入口招牌",
		"原创场景登记点路线牌",
		"原创场景主干道斑马线",
		"原创场景后场货箱",
		"原创场景终点门前文字",
	]
	for scenario_id in landmark_visibility_contract.keys():
		city.set_meta("reference_capture_scenario", scenario_id)
		await process_frame
		var expected_visible: Array = landmark_visibility_contract[scenario_id]
		for landmark_name in landmark_names:
			var scenario_landmark := city.get_node("Visual").find_child(landmark_name, true, false)
			assert(scenario_landmark != null, "%s 缺少地标节点：%s" % [scenario_id, landmark_name])
			assert(scenario_landmark.visible == expected_visible.has(landmark_name), "%s 地标可见性错误：%s" % [scenario_id, landmark_name])
	city.remove_meta("reference_capture_scenario")
	await process_frame
	assert(city.get_node("Visual").find_child("原创雨后路面反光", true, false) != null, "城市雨后路面反光候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创雨后积水反光带", true, false) != null, "城市雨后积水反光带候选没有进入运行时")
	assert(city.get_node("Visual").find_child("候选黄昏街灯光晕", true, false) != null, "城市黄昏街灯光晕候选没有进入运行时")
	for weather_node in city.get_node("Visual").find_children("*", "OmniLight3D", true, false):
		assert(bool(weather_node.get_meta("visual_only", false)), "城市候选天气灯光不得携带未登记的运行时逻辑")
	assert(city.get_node("Visual").find_child("原创后场仓储立面", true, false) != null, "城市后场仓储立面候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创后场装卸月台", true, false) != null, "城市后场装卸月台候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创后场配送货箱", true, false) != null, "城市后场配送货箱候选没有进入运行时")
	assert(city.get_node("Visual").find_child("原创后场仓储门头", true, false) != null, "城市后场仓储门头没有进入运行时")
	assert(city.get_node("Visual").find_child("原创店铺招牌纹理", true, false) != null, "城市首店招牌纹理没有进入运行时")
	assert(city.get_node("Visual").find_child("原创终点店招牌纹理", true, false) != null, "城市终点招牌纹理没有进入运行时")
	assert(city.get_node("Visual").find_child("原创终点店立面覆盖", true, false) != null, "城市终点门面覆盖层没有进入运行时")
	for endpoint_name in ["原创终点店卷帘门", "原创终点店门头", "原创终点店横槽"]:
		var endpoint_visual := city.get_node("Visual").find_child(endpoint_name, true, false) as MeshInstance3D
		assert(endpoint_visual != null, "城市终点缺少候选视觉节点：" + endpoint_name)
		assert(bool(endpoint_visual.get_meta("candidate_endpoint_visual", false)), "城市终点候选节点缺少采集态白名单标记：" + endpoint_name)
	var drive_background := city.get_node("Visual").find_child("原创城市驾驶街道背景卡", true, false) as MeshInstance3D
	assert(drive_background != null, "城市驾驶候选缺少原创道路背景卡")
	assert(drive_background.material_override is StandardMaterial3D, "城市驾驶候选背景卡缺少材质")
	var drive_background_material := drive_background.material_override as StandardMaterial3D
	assert(drive_background_material.albedo_texture != null, "城市驾驶候选背景卡缺少纹理")
	var drive_texture_path := str(drive_background_material.albedo_texture.resource_path)
	assert(drive_texture_path.ends_with("city_drive_lane_dusk_v1_generated.png") or drive_texture_path.ends_with("city_drive_lane_day_v2_clear_foreground_candidate.png") or drive_texture_path.ends_with("city_08_authorized_ai_backdrop_candidate.png"), "城市驾驶候选背景卡没有绑定登记的道路或参考帧版本")
	if drive_texture_path.ends_with("city_08_authorized_ai_backdrop_candidate.png"):
		assert(str(drive_background.get_meta("asset_id", "")) == "authorized_ai_city08_backdrop_candidate", "城市驾驶参考帧背景卡缺少权利资产标识")
	assert(bool(drive_background.get_meta("visual_only", false)), "城市驾驶候选背景卡必须登记为纯视觉层")
	assert(drive_background.find_children("*", "CollisionObject3D", true, false).is_empty(), "城市驾驶候选背景卡不得创建碰撞对象")
	var drive_foreground_mesh_count := 0
	for candidate_mesh in city.find_children("*", "MeshInstance3D", true, false):
		var candidate_name := str(candidate_mesh.name)
		if candidate_name.begins_with("原创连续街区") or candidate_name.begins_with("驾驶镜头"):
			drive_foreground_mesh_count += 1
	assert(drive_foreground_mesh_count >= 80, "城市驾驶候选缺少道路连续层与两侧立面视觉网格：%d" % drive_foreground_mesh_count)
	var generated_storefront := city.get_node_or_null("原创写实店铺立面候选") as MeshInstance3D
	if generated_storefront != null:
		assert(generated_storefront.visible, "城市候选店铺纹理被环境灰盒隐藏流程误关")
	var crowd_background := city.find_child("原创城市首店人群写实背景卡", true, false) as MeshInstance3D
	assert(crowd_background != null, "城市首店缺少原创人群写实背景卡")
	assert(crowd_background.visible, "城市首店人群写实背景卡被环境灰盒隐藏流程误关")
	assert(crowd_background.mesh is QuadMesh, "城市首店人群写实背景卡必须使用 QuadMesh")
	assert(crowd_background.material_override != null, "城市首店人群写实背景卡缺少材质")
	var crowd_background_material := crowd_background.material_override as StandardMaterial3D
	assert(crowd_background_material.albedo_texture != null, "城市首店人群写实背景卡缺少纹理")
	var crowd_texture_path := str(crowd_background_material.albedo_texture.resource_path)
	var uses_authorized_video_backdrop := crowd_texture_path.ends_with("city-01-video-playable-backdrop-v2.png")
	assert(crowd_texture_path.ends_with("city_storefront_crowd_v2_generated.png") or uses_authorized_video_backdrop, "城市首店人群写实背景卡没有绑定登记的原创纹理或授权视频帧")
	if uses_authorized_video_backdrop:
		assert(str(crowd_background.get_meta("asset_source", "")) == "user_authorized_ai_video_frame_edit", "城市首店授权视频帧缺少资产来源标记")
		assert(str(crowd_background.get_meta("rights_status", "")).contains("user_authorized_candidate_rights_pending_final_signoff"), "城市首店授权视频帧缺少权利状态标记")
	if candidate_catalog_path.ends_with("asset-runtime-catalog-full-candidates.json"):
		assert(uses_authorized_video_backdrop, "完整候选城市没有把 city-01 授权视频帧接入真实运行时背景卡")
		assert(crowd_background.visible, "完整候选城市首店近景背景卡不可见")
		var distant_city_building := city.get_node("Visual").find_child("候选原创大型城市楼", true, false) as Node3D
		assert(distant_city_building != null and not distant_city_building.visible, "完整候选城市首店近景仍显示远景楼体遮挡")
		var street_tree_canopy := city.get_node("Visual").find_child("原创连续街区行道树树冠", true, false) as Node3D
		assert(street_tree_canopy != null and not street_tree_canopy.visible, "完整候选城市首店近景仍显示街区远景树冠遮挡")
	assert(bool(crowd_background.get_meta("visual_only", false)), "城市首店人群写实背景卡必须登记为纯视觉层")
	var dusk_background := city.find_child("原创城市终点傍晚街道背景卡", true, false) as MeshInstance3D
	assert(dusk_background != null, "城市终点缺少原创傍晚街道背景卡")
	assert(dusk_background.visible, "城市终点傍晚街道背景卡被环境灰盒隐藏流程误关")
	assert(dusk_background.mesh is QuadMesh, "城市终点傍晚街道背景卡必须使用 QuadMesh")
	assert(dusk_background.material_override != null, "城市终点傍晚街道背景卡缺少材质")
	var dusk_background_material := dusk_background.material_override as StandardMaterial3D
	assert(dusk_background_material.albedo_texture != null, "城市终点傍晚街道背景卡缺少纹理")
	assert(str(dusk_background_material.albedo_texture.resource_path).ends_with("city_dusk_corner_storefront_v1_generated.png"), "城市终点傍晚街道背景卡没有绑定登记的原创纹理")
	assert(bool(dusk_background.get_meta("visual_only", false)), "城市终点傍晚街道背景卡必须登记为纯视觉层")
	assert(dusk_background.find_children("*", "CollisionObject3D", true, false).is_empty(), "城市终点傍晚街道背景卡不得创建碰撞对象")
	var generated_road := city.get_node_or_null("CC0磨损沥青道路材质-纵向") as MeshInstance3D
	if generated_road != null:
		assert(generated_road.visible, "城市候选道路材质被环境灰盒隐藏流程误关")
	var foreground_crowd := city.get_node("Visual").find_child("候选店铺前景人群", true, false) as Node3D
	assert(foreground_crowd != null, "城市首店缺少 city-01 前景人群构图层")
	assert(foreground_crowd.get_child_count() == 14, "城市首店前景人群数量没有锁定为 14 个可控视觉层")
	assert(bool(foreground_crowd.get_meta("visual_only", false)), "城市首店前景人群没有登记为纯视觉层")
	assert(foreground_crowd.find_children("*", "CollisionObject3D", true, false).is_empty(), "城市首店前景人群不得创建碰撞对象")
	assert(city.get_node("Visual").find_child("原创店铺入口门槛", true, false) != null, "城市首店缺少入口门槛层次")
	assert(foreground_crowd.find_children("前景人群左臂", "MeshInstance3D", true, false).size() == 14, "城市首店前景人群左臂轮廓数量不完整")
	assert(foreground_crowd.find_children("前景人群右臂", "MeshInstance3D", true, false).size() == 14, "城市首店前景人群右臂轮廓数量不完整")
	assert(foreground_crowd.find_child("中央红衣角色背部原创标识", true, false) != null, "城市首店缺少中央红衣角色视觉锚点")
	var store_candidate := city.get_node_or_null("Visual") as Node3D
	assert(store_candidate != null and store_candidate.get_meta("store_interior_product_count", -1) != -1, "城市店内候选根节点没有进入运行时")
	assert(store_candidate.find_child("候选商店内景左货架", true, false) != null, "城市店内候选缺少左侧连续货架")
	assert(store_candidate.find_child("候选商店内景右货架", true, false) != null, "城市店内候选缺少右侧连续货架")
	assert(int(store_candidate.get_meta("store_interior_product_count", 0)) >= 40, "城市店内候选商品色块数量不足")
	assert(int(store_candidate.get_meta("store_interior_light_count", 0)) == 4, "城市店内候选顶灯局部光数量未锁定")
	for store_light in store_candidate.find_children("*", "OmniLight3D", true, false):
		if str(store_light.name).begins_with("候选商店内景顶灯局部光"):
			assert(bool(store_light.get_meta("visual_only", false)), "城市店内顶灯不得携带运行时逻辑")
	assert(city.get_node_or_null("城市环境灰盒回退") == null, "城市环境候选接入后仍保留灰盒回退")
	var hidden_graybox_mesh_count := 0
	var graybox_environment_root_names := ["街区地面", "道路", "道路横向", "商店一", "街边店铺", "免费鸡蛋红色门头", "新街区巷道", "后场仓储建筑", "后场仓储围挡", "后场装卸台"]
	for static_root in city.get_children():
		if not static_root is StaticBody3D or not graybox_environment_root_names.has(str(static_root.name)) or static_root.get_node_or_null("Visual") != null:
			continue
		for mesh_node in static_root.find_children("*", "MeshInstance3D", true, false):
			hidden_graybox_mesh_count += 1
			assert(not (mesh_node as MeshInstance3D).visible, "城市候选接入后静态灰盒网格仍可见：" + str(mesh_node.get_path()))
	assert(hidden_graybox_mesh_count > 0, "城市候选集成测试没有发现可验证的静态灰盒渲染层")
	var interaction_visual := city.get_node_or_null("交互道具层/Visual")
	assert(interaction_visual != null, "完整候选包没有挂载原创交互道具")
	for interaction_group in ["EggTray_Interaction", "ScanBoard_Interaction", "DeliveryMarker_Interaction", "ShopBasket_Interaction"]:
		assert(interaction_visual.find_child(interaction_group, true, false) != null, "完整候选包缺少交互道具分组：" + interaction_group)
	assert(city.get_node_or_null("交互道具层/交互道具灰盒回退") == null, "完整候选包交互道具仍保留灰盒回退")
	assert(city.get_node("Visual").find_children("*", "Camera3D", true, false).is_empty(), "城市环境候选不应创建固定镜头")
	assert(is_equal_approx(city.camera_rig.distance, 5.4), "城市候选镜头未使用近中景跟随距离：%s" % city.camera_rig.distance)
	assert(is_equal_approx(city.camera_rig.height, 2.8), "城市候选镜头未使用近中景跟随高度：%s" % city.camera_rig.height)
	assert(is_equal_approx(city.camera_rig.shoulder_offset.x, 0.25), "城市候选镜头肩位偏移未锁定：%s" % city.camera_rig.shoulder_offset)
	# city-08 参考采集态由外部脚本写入 6.4/2.2；锁定后环境候选不得在下一帧覆盖它。
	city.set_meta("candidate_capture_camera_lock", true)
	city.camera_rig.set_follow_profile(6.4, 2.2)
	await process_frame
	assert(is_equal_approx(city.camera_rig.distance, 6.4), "候选采集相机锁定后跟随距离被覆盖：%s" % city.camera_rig.distance)
	assert(is_equal_approx(city.camera_rig.height, 2.2), "候选采集相机锁定后高度被覆盖：%s" % city.camera_rig.height)
	city.remove_meta("candidate_capture_camera_lock")
	assert(city.traffic_vehicles.size() >= 2, "城市候选缺少可验证交通车辆")
	for traffic_index in range(2):
		var traffic_visual := city.traffic_vehicles[traffic_index].get_node_or_null("候选交通视觉") as Node3D
		assert(traffic_visual != null, "城市交通候选视觉层未加载：%d" % traffic_index)
		assert(traffic_visual.visible, "城市交通候选视觉层未保持可见：%d" % traffic_index)
		assert(traffic_visual.find_child("候选交通车轮", true, false) != null, "城市交通候选缺少车轮细节：%d" % traffic_index)
		assert(traffic_visual.find_children("*", "MeshInstance3D", true, false).size() >= 8, "城市交通候选视觉细节不足：%d" % traffic_index)

	# 人群候选通过资产运行时目录的正式挂载路径进入四名行人和冲突对象。
	await process_frame
	assert(city.pedestrians.size() == 4, "城市行人数量不符合内容包")
	var city_roles := {}
	var city_variant_indices := {}
	for pedestrian in city.pedestrians:
		var visual: Node = pedestrian.get_node_or_null("Visual")
		assert(visual != null, "城市行人没有挂载完整候选 Visual")
		assert(visual.get_node_or_null("Character") != null, "城市行人候选缺少真实角色实例")
		assert(visual.get_node_or_null("AnimationPlayer") != null, "城市行人候选缺少 AnimationPlayer")
		var original_procedural := bool(visual.get_meta("original_procedural_asset", false))
		var city_identity := visual.find_child("城市身份配件", true, false) as Node3D
		assert(city_identity != null, "城市行人候选缺少身份配件层")
		var city_role := str(city_identity.get_meta("role", ""))
		assert(not city_role.is_empty(), "城市行人候选没有登记身份变体")
		if original_procedural:
			assert(visual.get_meta("asset_source", "") == "project_original_generated_code_and_node_materials", "原创城市人群没有登记资产来源")
			assert(visual.get_node("Character").find_child("原创程序化上衣", true, false) != null, "原创城市人群缺少上衣网格")
		else:
			var skin_mesh: MeshInstance3D = null
			for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
				var mesh_name := str(mesh_node.name).to_lower()
				if mesh_name.contains("low-poly") or mesh_name.begins_with("superhero_male") or mesh_name.contains("superhero_male"):
					skin_mesh = mesh_node as MeshInstance3D
					break
			assert(skin_mesh != null, "城市行人候选缺少可识别的皮肤网格")
			var skin_material := skin_mesh.material_override as StandardMaterial3D
			assert(skin_material != null, "城市行人候选皮肤网格没有候选材质覆盖")
			assert(skin_material.albedo_color.r < 0.9 and skin_material.albedo_color.g < 0.8, "城市行人候选皮肤网格仍疑似使用白色导入材质")
			assert(skin_material.albedo_color != Color("b47d68") or city_role == "delivery", "城市身份候选未形成肤色差异")
			var city_variant_index := int(visual.get_meta("city_variant_index", -1))
			assert(city_variant_index >= 0 and city_variant_index < 3, "城市行人候选缺少 0-2 的确定性外观变体索引")
			assert(str(visual.get_meta("city_variant_contract", "")) == "deterministic_suit_skin_hair_palette", "城市行人候选外观变体没有登记确定性调色契约")
			city_variant_indices[city_variant_index] = true
		assert(visual.find_child("候选人群视觉配件", true, false) != null, "城市行人候选缺少帽子、肩包和反光层")
		var role_scale := float(visual.get_meta("city_role_scale", 0.0))
		assert(role_scale > 0.90 and role_scale < 1.10, "城市行人候选体型比例没有锁定在视觉候选范围：%s" % role_scale)
		assert(is_equal_approx((visual.scale - Vector3.ONE * role_scale).length(), 0.0), "城市行人候选体型比例没有应用到 Visual 根节点")
		var lod_end_distance := float(visual.get_meta("visual_lod_end_distance", 0.0))
		var lod_end_margin := float(visual.get_meta("visual_lod_end_margin", 0.0))
		assert(is_equal_approx(lod_end_distance, 48.0), "城市行人候选没有登记统一远景裁剪距离：%s" % lod_end_distance)
		assert(is_equal_approx(lod_end_margin, 4.0), "城市行人候选没有登记统一 LOD 过渡边界：%s" % lod_end_margin)
		var lod_geometry_count := 0
		for geometry_node in visual.find_children("*", "GeometryInstance3D", true, false):
			var geometry := geometry_node as GeometryInstance3D
			if geometry == null:
				continue
			lod_geometry_count += 1
			assert(is_equal_approx(geometry.visibility_range_end, lod_end_distance), "城市行人候选网格没有继承远景裁剪距离：%s" % geometry.get_path())
			assert(is_equal_approx(geometry.visibility_range_end_margin, lod_end_margin), "城市行人候选网格没有继承 LOD 过渡边界：%s" % geometry.get_path())
		assert(lod_geometry_count > 0, "城市行人候选没有可验证的 GeometryInstance3D LOD 网格")
		assert(visual.find_child("视觉返工背包", true, false) == null, "城市行人不应继承办公室大背包")
		for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
			var mesh_candidate := mesh_node as MeshInstance3D
			var mesh_name := str(mesh_candidate.name).to_lower()
			if mesh_name.contains("backpack") or mesh_name.contains("back_pack"):
				assert(not mesh_candidate.visible, "城市行人候选仍显示 MakeHuman 原始大背包：" + str(mesh_candidate.name))
		city_roles[city_role] = true
		assert(pedestrian.get_node_or_null("原创灰盒人群外观") == null, "城市行人候选接入后仍保留灰盒回退")
		var crowd_animation_player := visual.get_node("AnimationPlayer") as AnimationPlayer
		assert(crowd_animation_player.current_animation == "walk_default", "城市行人候选行走状态没有驱动；当前=%s；动画=%s" % [crowd_animation_player.current_animation, crowd_animation_player.get_animation_list()])
	assert(city_roles.size() == 4, "城市四名行人没有形成四种可见身份差异：%s" % [city_roles.keys()])
	assert(city_variant_indices.size() >= 3, "城市行人候选没有形成至少三种确定性服装/肤色/发色变体：%s" % [city_variant_indices.keys()])
	assert(city.conflict_agent.get_node_or_null("Visual/Character") != null, "冲突对象没有使用完整人群候选")

	# 先保留确定性逻辑探针，再等待真实物理帧，验证场景调度也没有被候选覆盖破坏。
	var pedestrian_start: Vector3 = city.pedestrians[0].global_position
	city.pedestrians[0]._physics_process(1.0)
	assert(city.pedestrians[0].global_position.distance_to(pedestrian_start) > 0.1, "城市完整候选包接入后行人不再沿路线移动")
	city.pedestrians[0].global_position = city.pedestrians[0].waypoints[0]
	city.pedestrians[0].set_physics_process(true)
	var physics_start: Vector3 = city.pedestrians[0].global_position
	for _frame in range(3):
		await physics_frame
	assert(city.pedestrians[0].global_position.distance_to(physics_start) > 0.01, "真实物理帧没有驱动城市候选行人")

	# 用真实运行时输入验证候选外观没有破坏城市底层玩法链路。
	var vehicle_start: Vector3 = city.vehicle.global_position
	city.player.global_position = city.vehicle.global_position + Vector3(0.0, 0.0, 1.0)
	var enter_frame := InputFrameClass.new()
	enter_frame.vehicle_enter_exit = true
	city.process_input_frame(enter_frame, 0.016)
	assert(city.vehicle.driver == city.player, "城市完整候选包接入后无法进入三轮车")
	assert(is_equal_approx(city.vehicle.driver_seat_offset.y, 0.42), "城市候选三轮车视觉座椅挂点没有校正")
	var vehicle_snapshot: Dictionary = city.vehicle.snapshot()
	var driver_contact: Dictionary = vehicle_snapshot.get("driver_contact", {})
	assert(float(driver_contact.get("position_error", 999.0)) <= 0.001, "驾驶员没有准确贴合候选座位：误差=%s" % driver_contact.get("position_error", "unknown"))
	assert(float(driver_contact.get("rotation_error", 999.0)) <= 0.001, "驾驶员朝向没有与载具一致：误差=%s" % driver_contact.get("rotation_error", "unknown"))
	var driver_visual := city.player.get_node("Visual") as Node3D
	var driver_animation_player := driver_visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	assert(driver_animation_player != null and driver_animation_player.current_animation == "vehicle_default", "进入三轮车后候选玩家没有切换到驾驶动作")
	var driver_backpack_mount := driver_visual.find_child("MakeHuman 玩家背包骨骼挂点", true, false) as Node3D
	if driver_backpack_mount == null:
		driver_backpack_mount = driver_visual.find_child("候选主角背包", true, false) as Node3D
	assert(driver_backpack_mount != null, "驾驶员候选缺少背包挂点契约")
	# MakeHuman 驾驶员有骨骼背包挂点并在驾驶态隐藏；城市独立候选目录的 Quaternius
	# 版本只要求保留背包视觉节点，不强行把两种候选的节点结构混成同一实现。
	if driver_backpack_mount.name == "MakeHuman 玩家背包骨骼挂点":
		assert(not driver_backpack_mount.visible, "驾驶状态下背包仍遮挡驾驶员躯干")
	var drive_frame := InputFrameClass.new()
	drive_frame.move = Vector2(0.0, -1.0)
	for _step in range(10):
		city.process_input_frame(drive_frame, 0.1)
	assert(city.vehicle.global_position.distance_to(vehicle_start) > 0.1, "城市完整候选包接入后载具无法驾驶")
	assert(city.vehicle_wheels.size() == 3, "城市完整候选包接入后没有绑定三只滚动车轮")
	var exit_frame := InputFrameClass.new()
	exit_frame.vehicle_enter_exit = true
	city.process_input_frame(exit_frame, 0.016)
	assert(city.vehicle.driver == null, "城市完整候选包退出三轮车后驾驶员所有权没有释放")
	assert(city.player.visible, "城市完整候选包退出三轮车后玩家视觉没有恢复")
	assert(city.vehicle.driver == null, "城市完整候选包接入后无法退出三轮车")

	# 完整执行城市任务链，验证候选视觉替换没有掩盖任务推进、库存和最终成功状态。
	_interact_at(city, 0)
	assert(city.inventory.has_item("egg_tray"), "领取鸡蛋后候选城市库存没有物品")
	assert(city.mission.current_stage().get("id") == "leave_store", "领取鸡蛋后任务没有进入离店阶段")
	await process_frame
	var leave_store_runtime_root := city_state_visuals.get_node_or_null("Visual") as Node3D
	assert(leave_store_runtime_root != null and str(leave_store_runtime_root.get_meta("city_scene_state", "")) == "city-05", "领取鸡蛋后真实运行时没有切换到 city-05 离店场景")
	if bool(city.get_meta("candidate_video_backdrop", false)):
		assert(str(city.get_meta("candidate_video_backdrop_id", "")) == "city-05", "领取鸡蛋后候选视频背景没有切换到 city-05")
		_assert_candidate_backdrop(city, "city-05", "city-05-video-playable-backdrop-v1.png")
	# 候选包必须验证真实城市运行时的中途存档闭环，而不是只验证 SaveStore 单元层。
	# 先保存离店阶段，再故意篡改玩家位置和库存，读取后必须恢复任务、位置和鸡蛋托盘。
	var saved_city_position: Vector3 = city.player.position
	city._save_city_checkpoint()
	assert(FileAccess.file_exists(city.save_store.save_path), "候选城市离店阶段没有生成中途存档")
	var saved_city_payload = JSON.parse_string(FileAccess.get_file_as_string(city.save_store.save_path))
	assert(saved_city_payload is Dictionary and str(saved_city_payload.get("content_pack_id", "")) == city.city_pack_id, "候选城市存档没有绑定当前内容包")
	assert(int(saved_city_payload.get("inventory", {}).get("egg_tray", 0)) == 1, "候选城市中途存档没有写入鸡蛋托盘：%s；写入错误=%s" % [JSON.stringify(saved_city_payload.get("inventory", {})), city.save_store.last_error])
	city.player.position += Vector3(4.0, 0.0, 3.0)
	assert(city.inventory.remove_item("egg_tray"), "候选城市存档回归无法准备库存篡改状态")
	assert(not city.inventory.has_item("egg_tray"), "候选城市存档回归没有成功移除待恢复物品")
	city._load_city_checkpoint()
	await process_frame
	assert(city.message == "城市存档已读取", "候选城市读取存档失败：%s" % city.save_store.last_error)
	assert(city.inventory.has_item("egg_tray"), "候选城市读取存档后没有恢复鸡蛋托盘，当前数量=%d" % city.inventory.count("egg_tray"))
	assert(city.player.position.distance_to(saved_city_position) <= 0.001, "候选城市读取存档后没有恢复玩家位置")
	assert(city.mission.current_stage().get("id") == "leave_store", "候选城市读取存档后没有恢复离店任务阶段")
	_interact_at(city, 1)
	assert(city.mission.current_stage().get("id") == "register", "离店后任务没有进入登记阶段")
	await process_frame
	var registration_runtime_root := city_state_visuals.get_node_or_null("Visual") as Node3D
	assert(registration_runtime_root != null and str(registration_runtime_root.get_meta("city_scene_state", "")) == "city-06", "进入登记阶段后真实运行时没有切换到 city-06 待扫描场景")
	if bool(city.get_meta("candidate_video_backdrop", false)):
		assert(str(city.get_meta("candidate_video_backdrop_id", "")) == "city-06", "进入登记阶段后候选视频背景没有切换到 city-06")
		_assert_candidate_backdrop(city, "city-06", "city-06-video-playable-backdrop-v1.png")
	_interact_at(city, 2)
	assert(city.registered, "登记阶段没有记录登记状态")
	assert(city.mission.current_stage().get("id") == "enter_backlot", "登记后任务没有进入后场阶段")
	await process_frame
	var registration_success_runtime_root := city_state_visuals.get_node_or_null("Visual") as Node3D
	assert(registration_success_runtime_root != null and str(registration_success_runtime_root.get_meta("city_scene_state", "")) == "city-07", "扫码成功后真实运行时没有保留 city-07 成功反馈场景")
	if bool(city.get_meta("candidate_video_backdrop", false)):
		assert(str(city.get_meta("candidate_video_backdrop_id", "")) == "city-07", "扫码成功后候选视频背景没有切换到 city-07")
		_assert_candidate_backdrop(city, "city-07", "city-07-video-playable-backdrop-v1.png")
	_interact_at(city, 3)
	assert(city.neighborhood_status == "active", "进入后场后候选城市街区没有激活")
	await process_frame
	var backlot_runtime_root := city_state_visuals.get_node_or_null("Visual") as Node3D
	assert(backlot_runtime_root != null and str(backlot_runtime_root.get_meta("city_scene_state", "")) == "city-05", "进入后场后真实运行时没有切换到 city-05 后场过渡场景")
	_interact_at(city, 4)
	assert(city.inventory.has_item("stock_crate"), "装货后候选城市没有获得货物")
	assert(city.mission.current_stage().get("id") == "new_shop", "装货后任务没有进入旺铺送货阶段")
	_interact_at(city, 5)
	assert(city.mission.status == MissionChainClass.Status.SUCCESS, "候选城市任务没有完成")
	assert(city.mission.money == 260 and city.mission.stars == 5, "候选城市任务奖励状态错误")

	# 验证正式 city-08 采集清理不会把驾驶远景板一并隐藏。
	# 这条回归必须放在完整任务链之后，确保视觉候选没有只在初始化预检中成立。
	city.vehicle.position = Vector3(0.0, 0.7, 4.0)
	city.player.position = city.vehicle.position + Vector3(0.0, 0.0, 1.0)
	var capture_enter_frame := InputFrameClass.new()
	capture_enter_frame.vehicle_enter_exit = true
	city.process_input_frame(capture_enter_frame, 0.016)
	assert(city.vehicle.driver == city.player, "city-08 采集回归无法重新进入三轮车")
	city.set_meta("candidate_video_backdrop", true)
	city.set_meta("candidate_video_backdrop_id", "city-08")
	city.set_meta("reference_capture_scenario", "city-08")
	city.prepare_reference_capture(false)
	await process_frame
	await process_frame
	var drive_capture_board := city.find_child("候选城市驾驶相机远景板", true, false) as MeshInstance3D
	assert(drive_capture_board != null, "city-08 采集清理后没有创建驾驶相机远景板")
	assert(drive_capture_board.visible, "city-08 采集清理后误隐藏驾驶相机远景板")
	assert(drive_capture_board.material_override is StandardMaterial3D, "city-08 驾驶相机远景板缺少标准材质")
	var drive_capture_material := drive_capture_board.material_override as StandardMaterial3D
	assert(str(drive_capture_material.albedo_texture.resource_path).ends_with("city-08-video-playable-backdrop-v1.png"), "city-08 驾驶相机远景板没有绑定授权视频帧")
	assert(str(drive_capture_board.get_meta("asset_source", "")) == "user_authorized_ai_video_frame_edit", "city-08 驾驶相机远景板缺少资产来源标记")
	assert(str(drive_capture_board.get_meta("rights_status", "")).contains("rights_pending_final_signoff"), "city-08 驾驶相机远景板缺少权利状态标记")
	var visible_vehicle_mesh_count := 0
	for vehicle_mesh in city.vehicle.find_children("*", "MeshInstance3D", true, false):
		if (vehicle_mesh as MeshInstance3D).visible:
			visible_vehicle_mesh_count += 1
	assert(visible_vehicle_mesh_count > 0, "city-08 采集清理后载具视觉层被误隐藏")

	var camera := city.get_node_or_null("玩家/第三人称镜头/第三人称相机") as Camera3D
	assert(camera != null and camera.current, "城市完整候选包接入后正式第三人称镜头未生效")
	assert(get_root().get_camera_3d() == camera, "候选环境或载具镜头抢占了正式第三人称镜头")
	assert(city.trace.has_event("input"), "城市完整候选包接入后没有记录输入事件")
	city.queue_free()
	await process_frame
	print("城市完整候选包接入真实运行时通过：玩家、四名行人、冲突对象、三轮车、城市建筑、正式镜头和任务链路均保持完整")
	quit(0)

func _interact_at(city: Node, target_index: int) -> void:
	var target = city.targets[target_index]
	city.player.position = target.position + Vector3(0.0, 0.0, 1.0)
	city.process_input_frame(InputFrameClass.new(), 0.016)
	assert(city.prompt_label.text == "E  " + target.prompt, "候选城市接近目标后没有显示交互提示")
	var frame := InputFrameClass.new()
	frame.interact = true
	city.process_input_frame(frame, 0.016)

func _assert_candidate_backdrop(city: Node, expected_segment: String, expected_suffix: String) -> void:
	var backdrop := city.find_child("用户授权城市视频帧候选背景卡", true, false) as MeshInstance3D
	assert(backdrop != null and backdrop.visible, "%s 候选视频背景卡没有进入可见运行时" % expected_segment)
	assert(str(backdrop.get_meta("reference_segment", "")) == expected_segment, "%s 候选视频背景卡分段元数据错误" % expected_segment)
	assert(str(backdrop.get_meta("video_backdrop_texture_path", "")).ends_with(expected_suffix), "%s 候选视频背景路径没有绑定新版可玩背景图" % expected_segment)
	var material := backdrop.material_override as StandardMaterial3D
	assert(material != null and material.albedo_texture != null, "%s 候选视频背景卡没有实际材质纹理" % expected_segment)

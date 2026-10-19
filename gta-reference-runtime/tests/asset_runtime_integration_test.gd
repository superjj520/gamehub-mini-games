extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")
const OriginalCityEnvironmentScene = preload("res://assets/environment/original-procedural-city-environment/original_city_environment_candidate.tscn")
const OriginalCityCrowdScene = preload("res://assets/characters/original-procedural-city-crowd/original_procedural_city_crowd_candidate.tscn")
const OriginalCityVehicleScene = preload("res://assets/vehicles/three-wheel-delivery/three_wheel_delivery_candidate.tscn")
const OriginalOfficeNpcScene = preload("res://assets/characters/original-procedural-office-characters/original_office_npc_candidate.tscn")
const OriginalOfficeEnvironmentScene = preload("res://content/candidates/original_office_desk_runtime_candidate.tscn")
const OriginalOfficeVisualEnvironmentScene = preload("res://content/candidates/original_office_visual_runtime_candidate.tscn")
const OriginalInteractionPropsScene = preload("res://assets/props/original-procedural-interaction-props/original_interaction_props_candidate.tscn")
const OfficeSceneVisualsClass = preload("res://scripts/office_scene_visuals.gd")
const CitySceneVisualsClass = preload("res://scripts/city_scene_visuals.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	# 参考分段候选背景必须逐段存在，不能用一张通用图片覆盖多个镜头。
	# 背景卡只负责候选视觉像素，真实角色、碰撞、任务、HUD 和存档仍由运行时承担。
	for scene_prefix in ["office", "city"]:
		var segment_count := 10 if scene_prefix == "office" else 11
		for segment_index in range(1, segment_count + 1):
			var segment_id := "%s-%02d" % [scene_prefix, segment_index]
			var texture_path := "res://assets/reference-video-candidate/%s-video-playable-backdrop-%s.png" % [segment_id, "v2" if segment_id == "city-01" else "v1"]
			assert(FileAccess.file_exists(texture_path), "%s 缺少独立视频背景候选：%s" % [segment_id, texture_path])

	# 背景候选不能代替分段构图。每个办公室/城市状态都必须真实挂载自己的
	# 空间视觉层，并且只能负责表现，不能偷偷创建碰撞、导航或玩法状态。
	var office_visuals := OfficeSceneVisualsClass.new()
	root.add_child(office_visuals)
	await process_frame
	var office_visual_contracts := {
		"office-01": ["状态工位桌面", "状态工位打印机", "状态工位顶灯", "状态工位地毯主面", "状态工位桌下接触暗部", "状态工位后墙暖窗带", "状态工位显示器支架", "状态工位键盘按键行-00", "状态工位桌下柜体", "状态工位椅左扶手", "状态工位后墙窗帘横纹-03"],
		"office-02": ["状态02遮蔽面", "状态02遮蔽上沿", "状态02遮蔽内嵌面", "状态02遮蔽左竖边", "状态02遮蔽中缝高光", "状态02文件箱左", "状态02文件箱纸张右", "状态02文件柜抽屉线", "状态02远处门厅暖光", "状态02远处门框上沿", "状态02顶棚灯带-01", "状态02遮蔽底部踢脚线"],
		"office-03": ["状态03门框左", "状态03门框上沿", "状态03走廊灯带", "状态03门把手", "状态03出口指示牌", "状态03门顶闭门器", "状态03门槛左反光边", "状态03走廊扶手", "状态03门内脚垫", "状态03门内办公桌", "状态03门内显示器屏幕", "状态03门内画框画面", "状态03门内画框上沿"],
		"office-04": ["状态04感知地面圈", "状态04观察窗带", "状态04观察窗横框", "状态04警觉反光条", "状态04感知扇区左", "状态04门内前台桌", "状态04门内显示器屏幕", "状态04门内墙面标语牌", "状态04门内标语牌上沿", "状态04门内地面暖光带"],
		"office-05": ["状态电梯后墙", "状态电梯左门", "状态电梯呼叫面板", "状态电梯楼层牌数字左", "状态电梯呼叫上箭头", "状态电梯门槛左", "状态电梯楼层牌边框", "状态电梯呼叫面板边框", "状态电梯厅引导盲道", "状态电梯门厅顶梁", "状态电梯左门门套", "状态电梯门厅中轴地牌", "状态电梯厅地砖横缝-00", "状态电梯门厅顶棚灯带-00"],
		"office-06": ["状态电梯后墙", "状态电梯右门", "状态电梯呼叫灯", "状态电梯楼层牌数字右", "状态电梯呼叫下箭头", "状态电梯门槛右", "状态电梯左门亮边", "状态电梯右门亮边", "状态电梯厅引导牌", "状态电梯呼叫反馈光", "状态电梯中央导视牌底板", "状态电梯中央导视牌楼层字块-10", "状态电梯中央导视牌平面图边框", "状态电梯呼叫面板上键", "状态电梯右门门套", "状态电梯右门反射带", "状态电梯中央导视牌左框", "状态电梯厅地砖竖缝-01", "状态电梯门厅顶棚灯带-01"],
		"office-07": ["状态07楼梯台阶-00", "状态07楼梯台阶反光边-00", "状态07楼梯扶手", "状态07应急灯", "状态07失败反馈边框", "状态07平台警示牌", "状态07平台门缝", "状态07楼梯入口门框左", "状态07楼梯入口门楣", "状态07楼梯扶手立柱右", "状态07楼梯墙面灯带", "状态07楼梯平台地缝", "状态07楼梯顶棚暗面"],
		"office-08": ["状态对话走廊左墙", "状态对话暖色窗带", "状态对话警觉上沿", "状态对话字幕锚点", "状态对话门牌边框", "状态对话窗格横档", "状态对话左墙踢脚线", "状态对话墙面终端", "状态对话地面导向条", "状态对话窗下沿", "状态对话窗框左", "状态对话墙面竖分格", "状态对话地砖横缝-00", "状态对话交谈站位光带"],
		"office-09": ["状态对话走廊右墙", "状态对话暖色窗带", "状态对话警觉地线", "状态对话门边警示灯", "状态对话窗格竖档", "状态对话右墙踢脚线", "状态对话墙面终端屏", "状态对话天花检修板", "状态对话警觉光", "状态对话窗框右", "状态对话窗下沿", "状态对话地砖横缝-01", "状态对话交谈站位光带"],
		"office-10": ["状态工位桌面", "状态工位打印机出纸口", "状态工位输入反馈灯", "状态工位后排桌面", "状态工位键盘接触暗部", "状态工位桌下抽屉", "状态工位显示器顶部反光", "状态工位键盘中央分割", "状态工位隔断上沿", "状态工位后墙窗带竖分格"],
	}
	for office_state in office_visual_contracts:
		office_visuals.apply_state(office_state)
		assert(office_visuals.active_state == office_state, "办公室视觉层活动状态错误：" + office_state)
		assert(str(office_visuals.state_root.get_meta("office_scene_state", "")) == office_state, "办公室视觉根状态元数据错误：" + office_state)
		for required_node in office_visual_contracts[office_state]:
			assert(office_visuals.find_child(required_node, true, false) != null, "%s 缺少构图节点：%s" % [office_state, required_node])
		assert(office_visuals.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s 视觉层创建了碰撞对象" % office_state)
		for office_visual in office_visuals.find_children("*", "MeshInstance3D", true, false):
			assert(bool(office_visual.get_meta("visual_only", false)), "%s 网格缺少 visual_only 标记：%s" % [office_state, office_visual.name])
			assert(bool(office_visual.get_meta("candidate_visual_only", false)), "%s 网格缺少 candidate_visual_only 标记：%s" % [office_state, office_visual.name])
	office_visuals.free()
	await process_frame

	var city_visuals := CitySceneVisualsClass.new()
	root.add_child(city_visuals)
	await process_frame
	var city_visual_contracts := {
		"city-01": ["状态01店铺门面", "状态01卷帘门", "状态01卷帘门横槽-06", "状态01卷帘门左导轨", "状态01卷帘门右导轨", "状态01卷帘门底导轨", "状态01卷帘门门把手", "状态01店铺入口地垫", "状态01前景人行道", "状态01遮雨篷条纹-00", "状态01任务门头标识", "状态01门头识别牌底板", "状态01店前台阶边缘", "状态01左展窗竖框", "状态01门头电缆盒", "状态人群标记-07", "状态人群围裙", "状态人群店员帽", "状态人群购物袋", "状态人群配送扫码器"],
		"city-02": ["状态01店铺门面", "状态01卷帘门横槽-06", "状态02卷帘门近景横槽-00", "状态02卷帘门近景左导轨", "状态02卷帘门近景右导轨", "状态02拥挤导视线", "状态02拥挤缓冲线", "状态02拥挤近景导流台", "状态02拥挤隔离柱-01", "状态02拥挤排队牌", "状态02拥挤隔离绳高光", "状态02拥挤人群前景遮挡带", "状态02人群前景接触暗部", "状态人群标记-15", "状态人群迎宾手牌", "状态人群购物袋提手", "状态人群配送背箱"],
		"city-03": ["状态03货架侧体", "状态03商品色块", "状态03商品包装-左-00-00", "状态03鸡蛋货架标识", "状态03通道吊牌左吊杆", "状态03通道地砖缝-00", "状态03通道地面反光带-00", "状态03左货架端部立柱-03", "状态03通道尽端冷光", "状态03店内冷白灯板", "状态03通道顶灯-00", "状态03通道顶灯-03", "状态03左货架顶板", "状态03右货架顶板", "状态03通道尽端鸡蛋海报", "状态03通道尽端海报边框", "状态03通道地面导向箭头-00", "状态03通道天花横梁"],
		"city-04": ["状态04鸡蛋托盘", "状态04鸡蛋-00", "状态04冲突警戒带", "状态04隔离柱左", "状态04隔离绳左段", "状态04冲突警示牌", "状态04冲突展示台", "状态04鸡蛋托盘边框", "状态04鸡蛋堆头红色前板", "状态04鸡蛋堆头托盘-02", "状态04鸡蛋堆头前排-01-04", "状态04鸡蛋堆头商品标签", "状态04冲突展示台左侧板", "状态04冲突展示台右侧板", "状态04鸡蛋堆头竖分隔-00", "状态04冲突警示牌顶沿", "状态04冲突地面接触带"],
		"city-05": ["状态05离店道路", "状态05道路标线", "状态05后场装卸台", "状态05卸货木托盘", "状态05后场排水沟", "状态05排水沟格栅-01", "状态05装卸区警示牌面", "状态05装卸棚支撑左", "状态05后场门缝", "状态05巷道导视牌面", "状态05街口斑马线-04", "状态05街口裸树树干", "状态05街口远景车辆细节", "状态05后场门楣", "状态05装卸棚顶沿", "状态05装卸台左侧挡板", "状态05纸箱封带-00", "状态05街口电线下垂段"],
		"city-06": ["状态登记工作人员", "状态登记工作人员背心", "状态登记工作人员扫码器", "状态登记台", "状态登记台面", "状态登记扫描垫", "状态登记牌", "状态登记牌标题条", "状态登记二维码边框", "状态登记二维码", "状态登记二维码格-00", "状态登记二维码格-03", "状态登记牌支柱", "状态登记牌底座", "状态登记隔离绳", "状态登记点顶棚灯带", "状态登记文件盒", "状态登记点道路背景", "状态登记点路边树干", "状态登记点路缘边", "状态登记反馈光带", "状态登记点遮雨篷前沿", "状态登记点左侧信息板", "状态登记待扫描提示牌", "状态登记待扫描文字"],
		"city-07": ["状态登记工作人员", "状态登记工作人员背心", "状态登记工作人员扫码灯", "状态登记台", "状态登记台面", "状态登记扫描器", "状态登记反馈灯", "状态登记引导线", "状态登记排队标记-左", "状态登记隔离柱右", "状态登记隔离绳", "状态登记边缘反光条", "状态登记台脚左", "状态登记点人行道", "状态登记点道路标线", "状态登记二维码格-01", "状态登记二维码格-05", "状态登记牌支柱", "状态登记牌底座", "状态登记点路缘边", "状态登记反馈光带", "状态登记点遮雨篷前沿", "状态登记牌底部高光", "状态登记点左侧信息板", "状态登记成功提示牌", "状态登记成功文字"],
		"city-08": ["状态驾驶道路", "状态驾驶左侧人行道", "状态驾驶裸树树干-00", "状态驾驶裸树上层枝-00-左", "状态驾驶纵向虚线-00-00", "状态驾驶近景方向箭头", "状态驾驶路口导视牌面", "状态驾驶路口导视牌文字", "状态驾驶街角电缆", "状态驾驶左侧立面窗格-00", "状态驾驶右侧立面阳台板-00", "状态驾驶右侧街铺遮雨篷-00", "状态驾驶右侧街铺底部收口-00", "状态驾驶右侧街铺招牌-00", "状态驾驶人行道拼缝-左-00", "状态驾驶远景车辆左细节", "状态驾驶主车路径反光带", "状态驾驶主车接触阴影"],
		"city-09": ["状态驾驶道路", "状态驾驶右侧建筑", "状态驾驶右侧暖窗带", "状态驾驶远景车辆左细节", "状态驾驶交通信号杆", "状态驾驶交通信号红灯", "状态驾驶交通信号绿灯", "状态驾驶交通信号灯罩", "状态驾驶交通信号灯罩顶沿", "状态驾驶路面反光钉左", "状态驾驶右侧立面窗格-00", "状态驾驶右侧街铺招牌-00", "状态驾驶路口导视牌文字", "状态驾驶路口停止线", "状态驾驶路口转向箭头头", "状态驾驶路口转角路缘", "状态驾驶路口横向车流接触带"],
		"city-10": ["状态10目标门面远景", "状态10目标门面入口", "状态10目标门面橱窗左", "状态10目标灯带", "状态10目标门面遮雨篷支撑左", "状态10目标门面识别牌边框", "状态10目标门面识别牌字块-03", "状态10目标门面台阶反光边", "状态10目标门面暖光", "状态驾驶道路", "状态10目标门面识别牌", "状态10目标门面招牌下沿", "状态10目标门面入口门把手", "状态10目标门面橱窗竖分格左", "状态10目标门面门前碎纸"],
		"city-11": ["状态11终点店铺门面", "状态11终点卷帘门", "状态11交付地面标记", "状态11交付地面文字", "状态11卷帘门横槽-03", "状态11卷帘门左导轨", "状态11卷帘门顶部卷轴盒", "状态11卷帘门底部导轨", "状态11终点门槛反光边", "状态11旺铺转让招牌底板", "状态11旺铺转让字块-03", "状态11旺铺转让文字", "状态11侧面转让海报边框", "状态11终点人行道拼缝", "状态11交付隔离柱-01", "状态11终点门前碎纸左", "状态11终点门面暖光边", "状态11终点取货提示"],
	}
	for city_state in city_visual_contracts:
		city_visuals.apply_state(city_state)
		assert(city_visuals.active_state == city_state, "城市视觉层活动状态错误：" + city_state)
		assert(str(city_visuals.state_root.get_meta("city_scene_state", "")) == city_state, "城市视觉根状态元数据错误：" + city_state)
		for required_node in city_visual_contracts[city_state]:
			assert(city_visuals.find_child(required_node, true, false) != null, "%s 缺少构图节点：%s" % [city_state, required_node])
		assert(city_visuals.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s 视觉层创建了碰撞对象" % city_state)
		for city_visual in city_visuals.find_children("*", "MeshInstance3D", true, false):
			assert(bool(city_visual.get_meta("visual_only", false)), "%s 网格缺少 visual_only 标记：%s" % [city_state, city_visual.name])
			assert(bool(city_visual.get_meta("candidate_visual_only", false)), "%s 网格缺少 candidate_visual_only 标记：%s" % [city_state, city_visual.name])
	city_visuals.apply_state("city-01")
	var city_role_probe := city_visuals.find_child("状态人群标记-00", true, false)
	assert(city_role_probe != null and str(city_role_probe.get_meta("crowd_role", "")) == "店员", "city-01 店员角色元数据缺失")
	assert(city_role_probe != null and str(city_role_probe.get_meta("crowd_pose", "")) == "迎宾", "city-01 店员迎宾动作元数据缺失")
	var city_delivery_probe := city_visuals.find_child("状态人群标记-02", true, false)
	assert(city_delivery_probe != null and str(city_delivery_probe.get_meta("crowd_role", "")) == "配送员", "city-01 配送员角色元数据缺失")
	assert(city_delivery_probe != null and city_delivery_probe.find_child("状态人群配送扫码器", true, false) != null, "city-01 配送员扫码道具缺失")
	city_visuals.free()
	await process_frame

	var catalog := AssetRuntimeCatalogClass.load_json("res://content/asset-runtime-catalog.json")
	assert(AssetRuntimeCatalogClass.validate(catalog).is_empty(), "P0 资产运行时目录契约校验失败")
	var expected_slots := {
		"player-character": "Visual",
		"office-npc-set": "Visual",
		"city-crowd-set": "Visual",
		"three-wheel-vehicle": "Visual",
		"office-environment-kit": "Visual",
		"city-environment-kit": "Visual",
		"interaction-props": "Visual",
		"final-audio-library": "Audio",
	}
	for slot in catalog.get("slots", []):
		var slot_id := str(slot.get("id", ""))
		assert(expected_slots.has(slot_id), "资产目录出现未进入 P0 规格的槽位：" + slot_id)
		assert(str(slot.get("root_name", "")) == expected_slots[slot_id], "资产槽位根节点不符合运行时契约：" + slot_id)
		assert(str(slot.get("fallback_policy", "")) == "procedural_graybox", "资产槽位未显式声明灰盒回退：" + slot_id)
	assert(catalog.get("slots", []).size() == expected_slots.size(), "资产目录槽位数量与 P0 规格不一致")

	var original_city_crowd := OriginalCityCrowdScene.instantiate()
	root.add_child(original_city_crowd)
	await process_frame
	assert(original_city_crowd.get_meta("visual_lod_end_distance", 0.0) == 48.0, "原创城市人群缺少固定视觉 LOD 距离")
	assert(original_city_crowd.find_children("*", "CollisionObject3D", true, false).is_empty(), "原创城市人群候选创建了碰撞对象")
	var crowd_meshes := original_city_crowd.find_children("*", "MeshInstance3D", true, false)
	assert(crowd_meshes.size() >= 20, "原创城市人群候选细节网格数量不足")
	assert(original_city_crowd.find_child("原创程序化胸口缝线", true, false) != null, "原创城市人群缺少服装缝线层")
	assert(original_city_crowd.find_child("原创程序化左鞋带", true, false) != null, "原创城市人群缺少鞋带细节")
	assert(original_city_crowd.find_child("原创程序化左眉线", true, false) != null, "原创城市人群缺少眉线细节")
	assert(original_city_crowd.find_child("配送员手持扫码器", true, false) != null, "原创城市配送员缺少手持设备")
	for crowd_mesh in crowd_meshes:
		assert(is_equal_approx((crowd_mesh as GeometryInstance3D).visibility_range_end, 48.0), "原创城市人群网格缺少统一视觉 LOD 距离：" + crowd_mesh.name)
		assert(bool(crowd_mesh.get_meta("visual_only", false)), "原创城市人群网格缺少 visual_only 标记：" + crowd_mesh.name)
		assert(bool(crowd_mesh.get_meta("candidate_visual_only", false)), "原创城市人群网格缺少 candidate_visual_only 标记：" + crowd_mesh.name)
	original_city_crowd.free()
	await process_frame

	# 新增城市视觉候选必须保持纯表现层：禁止偷偷创建碰撞体或承载玩法状态。
	var original_environment := OriginalCityEnvironmentScene.instantiate()
	root.add_child(original_environment)
	await process_frame
	assert(bool(original_environment.get_meta("visual_only", false)), "原创城市环境根节点缺少 visual_only 标记")
	assert(bool(original_environment.get_meta("candidate_visual_only", false)), "原创城市环境根节点缺少 candidate_visual_only 标记")
	assert(original_environment.find_children("*", "CollisionShape3D", true, false).is_empty(), "原创城市视觉候选创建了碰撞形状")
	assert(original_environment.find_children("*", "StaticBody3D", true, false).is_empty(), "原创城市视觉候选创建了静态碰撞体")
	assert(original_environment.find_child("候选店铺入口门框左", true, false) != null, "原创城市视觉候选缺少店铺入口细节")
	assert(original_environment.find_child("候选仓储装卸平台", true, false) != null, "原创城市视觉候选缺少仓储装卸细节")
	assert(original_environment.find_child("原创街区路口指示牌", true, false) != null, "原创城市视觉候选缺少路口指示牌")
	assert(original_environment.find_child("原创店铺空调外机", true, false) != null, "原创城市视觉候选缺少店铺空调外机")
	assert(original_environment.find_child("原创道路路缘反光件", true, false) != null, "原创城市视觉候选缺少路缘反光件")
	var original_drive_card := original_environment.find_child("候选原创城市驾驶街道背景卡", true, false) as MeshInstance3D
	assert(original_drive_card != null, "原创城市视觉候选缺少驾驶街道背景卡")
	assert(original_drive_card.material_override is StandardMaterial3D, "原创城市驾驶背景卡缺少材质")
	var original_drive_material := original_drive_card.material_override as StandardMaterial3D
	assert(original_drive_material.albedo_texture != null, "原创城市驾驶背景卡缺少纹理")
	var original_drive_texture_path := str(original_drive_material.albedo_texture.resource_path)
	assert(original_drive_texture_path.ends_with("city_drive_lane_day_v2_clear_foreground_candidate.png") or original_drive_texture_path.ends_with("city_08_authorized_ai_backdrop_candidate.png"), "原创城市驾驶背景卡没有绑定登记的道路或参考帧版本")
	if original_drive_texture_path.ends_with("city_08_authorized_ai_backdrop_candidate.png"):
		assert(str(original_drive_card.get_meta("asset_id", "")) == "authorized_ai_city08_backdrop_candidate", "原创城市驾驶参考帧背景卡缺少权利资产标识")
	assert(bool(original_drive_card.get_meta("visual_only", false)), "原创城市驾驶背景卡必须登记为纯视觉层")
	assert(original_drive_card.find_children("*", "CollisionObject3D", true, false).is_empty(), "原创城市驾驶背景卡不得创建碰撞对象")
	assert(original_environment.find_children("*", "OmniLight3D", true, false).size() >= 2, "原创城市视觉候选缺少街灯局部光源")
	for environment_visual in original_environment.find_children("*", "MeshInstance3D", true, false):
		assert(bool(environment_visual.get_meta("visual_only", false)), "原创城市环境网格缺少 visual_only 标记：" + environment_visual.name)
	for environment_light in original_environment.find_children("*", "OmniLight3D", true, false):
		assert(bool(environment_light.get_meta("visual_only", false)), "原创城市环境灯光缺少 visual_only 标记：" + environment_light.name)
	original_environment.free()
	await process_frame

	var original_vehicle := OriginalCityVehicleScene.instantiate()
	root.add_child(original_vehicle)
	await process_frame
	assert(original_vehicle.find_children("*", "CollisionShape3D", true, false).is_empty(), "原创三轮车视觉候选创建了碰撞形状")
	assert(original_vehicle.find_children("*", "StaticBody3D", true, false).is_empty(), "原创三轮车视觉候选创建了静态碰撞体")
	assert(original_vehicle.find_child("候选三轮车顶棚", true, false) != null, "原创三轮车视觉候选缺少顶棚细节")
	assert(original_vehicle.find_child("候选三轮车货箱", true, false) != null, "原创三轮车视觉候选缺少货箱细节")
	assert(original_vehicle.find_child("候选三轮车驾驶台", true, false) != null, "原创三轮车视觉候选缺少驾驶台细节")
	assert(original_vehicle.find_child("候选三轮车座椅坐垫", true, false) != null, "原创三轮车视觉候选缺少座椅坐垫细节")
	assert(original_vehicle.find_child("候选三轮车方向盘", true, false) != null, "原创三轮车视觉候选缺少方向盘细节")
	assert(original_vehicle.find_child("候选三轮车脚踏板", true, false) != null, "原创三轮车视觉候选缺少脚踏板细节")
	assert(original_vehicle.find_child("候选三轮车仪表屏", true, false) != null, "原创三轮车视觉候选缺少仪表屏细节")
	assert(original_vehicle.find_child("候选三轮车左侧裙", true, false) != null, "原创三轮车视觉候选缺少侧裙细节")
	assert(original_vehicle.find_child("候选三轮车前轮毂", true, false) != null, "原创三轮车视觉候选缺少前轮毂细节")
	assert(original_vehicle.find_child("候选三轮车左后轮毂", true, false) != null, "原创三轮车视觉候选缺少左后轮毂细节")
	assert(original_vehicle.find_child("候选三轮车右后轮毂", true, false) != null, "原创三轮车视觉候选缺少右后轮毂细节")
	var vehicle_damage_smoke := original_vehicle.find_child("候选三轮车损伤烟雾", true, false) as GPUParticles3D
	assert(vehicle_damage_smoke != null, "原创三轮车视觉候选缺少损伤烟雾反馈")
	assert(bool(vehicle_damage_smoke.get_meta("visual_only", false)), "三轮车损伤烟雾必须标记为 visual_only")
	assert(bool(vehicle_damage_smoke.get_meta("candidate_visual_only", false)), "三轮车损伤烟雾必须标记为 candidate_visual_only")
	assert(not vehicle_damage_smoke.emitting, "三轮车满耐久时不应显示损伤烟雾")
	assert(original_vehicle.has_method("set_candidate_damage_state"), "三轮车视觉候选缺少损伤状态入口")
	original_vehicle.call("set_candidate_damage_state", 60.0)
	assert(vehicle_damage_smoke.emitting, "三轮车中低耐久时没有显示损伤烟雾")
	assert(vehicle_damage_smoke.amount_ratio > 0.0, "三轮车损伤烟雾没有按耐久提高发射强度")
	original_vehicle.call("set_candidate_damage_state", 100.0)
	assert(not vehicle_damage_smoke.emitting, "三轮车恢复满耐久后仍显示损伤烟雾")
	for visual_mesh in original_vehicle.find_children("*", "MeshInstance3D", true, false):
		if visual_mesh.get_parent() == original_vehicle and visual_mesh.name.begins_with("候选三轮车"):
			assert(bool(visual_mesh.get_meta("visual_only", false)), "原创三轮车视觉细节缺少 visual_only 标记：" + visual_mesh.name)
	original_vehicle.free()
	await process_frame

	var original_office_environment := OriginalOfficeEnvironmentScene.instantiate()
	root.add_child(original_office_environment)
	await process_frame
	assert(original_office_environment.find_child("原创左前桌面前沿", true, false) != null, "原创办公室工位缺少桌面前沿层")
	assert(original_office_environment.find_child("原创左前台灯杆", true, false) != null, "原创办公室工位缺少台灯杆")
	assert(original_office_environment.find_child("原创左前台灯罩", true, false) != null, "原创办公室工位缺少可见台灯罩")
	assert(original_office_environment.find_child("原创左前台灯暖光", true, false) != null, "原创办公室工位缺少台灯局部暖光")
	assert(original_office_environment.find_child("原创玻璃隔断上沿", true, false) != null, "原创办公室玻璃隔断缺少上沿框架")
	assert(original_office_environment.find_child("原创玻璃隔断中竖框", true, false) != null, "原创办公室玻璃隔断缺少中竖框")
	assert(original_office_environment.find_child("原创玻璃隔断磨砂腰线", true, false) != null, "原创办公室玻璃隔断缺少磨砂腰线")
	assert(original_office_environment.find_child("原创玻璃隔断门把手", true, false) != null, "原创办公室玻璃隔断缺少门把手")
	assert(original_office_environment.find_child("原创办公室天花格栅横梁", true, false) != null, "原创办公室天花缺少横向格栅")
	assert(original_office_environment.find_child("原创办公室天花格栅纵梁", true, false) != null, "原创办公室天花缺少纵向格栅")
	assert(original_office_environment.find_child("原创办公室灯槽左边框", true, false) != null, "原创办公室灯槽缺少左边框")
	for office_visual_name in ["原创玻璃隔断", "原创玻璃隔断上沿", "原创玻璃隔断中竖框", "原创玻璃隔断磨砂腰线", "原创玻璃隔断门把手"]:
		var office_visual := original_office_environment.find_child(office_visual_name, true, false)
		assert(office_visual is MeshInstance3D, "原创办公室视觉节点不是网格实例：" + office_visual_name)
		assert(bool(office_visual.get_meta("visual_only", false)), "原创办公室玻璃隔断细节缺少 visual_only 标记：" + office_visual_name)
		assert(bool(office_visual.get_meta("candidate_visual_only", false)), "原创办公室玻璃隔断细节缺少 candidate_visual_only 标记：" + office_visual_name)
	for office_ceiling_name in ["原创办公室天花格栅横梁", "原创办公室天花格栅纵梁", "原创办公室灯槽左边框"]:
		var ceiling_visual := original_office_environment.find_child(office_ceiling_name, true, false)
		assert(ceiling_visual is MeshInstance3D, "原创办公室天花节点不是网格实例：" + office_ceiling_name)
		assert(bool(ceiling_visual.get_meta("visual_only", false)), "原创办公室天花节点缺少 visual_only 标记：" + office_ceiling_name)
		assert(bool(ceiling_visual.get_meta("candidate_visual_only", false)), "原创办公室天花节点缺少 candidate_visual_only 标记：" + office_ceiling_name)
	original_office_environment.free()
	await process_frame

	var original_office_visual_environment := OriginalOfficeVisualEnvironmentScene.instantiate()
	root.add_child(original_office_visual_environment)
	await process_frame
	assert(bool(original_office_visual_environment.get_meta("visual_only", false)), "办公室纯视觉环境根节点缺少 visual_only 标记")
	assert(bool(original_office_visual_environment.get_meta("candidate_visual_only", false)), "办公室纯视觉环境根节点缺少 candidate_visual_only 标记")
	assert(original_office_visual_environment.find_children("*", "CollisionShape3D", true, false).is_empty(), "办公室纯视觉候选创建了碰撞形状")
	assert(original_office_visual_environment.find_children("*", "CollisionObject3D", true, false).is_empty(), "办公室纯视觉候选创建了碰撞对象")
	assert(original_office_visual_environment.find_child("原创中前桌面", true, false) != null, "办公室纯视觉候选缺少中前工位")
	original_office_visual_environment.free()
	await process_frame

	var original_office_npc := OriginalOfficeNpcScene.instantiate()
	root.add_child(original_office_npc)
	await process_frame
	for npc_detail_name in ["候选NPC眉毛-左", "候选NPC眉毛-右", "候选NPC下巴轮廓", "候选NPC领口缝线", "候选NPC平板触控笔"]:
		var npc_detail: Node = original_office_npc.find_child(npc_detail_name, true, false)
		assert(npc_detail is MeshInstance3D, "原创办公室 NPC 近景细节不是网格实例：" + npc_detail_name)
		assert(bool(npc_detail.get_meta("visual_only", false)), "原创办公室 NPC 近景细节缺少 visual_only 标记：" + npc_detail_name)
		assert(bool(npc_detail.get_meta("candidate_visual_only", false)), "原创办公室 NPC 近景细节缺少 candidate_visual_only 标记：" + npc_detail_name)
	original_office_npc.free()
	await process_frame

	var original_interaction_props := OriginalInteractionPropsScene.instantiate()
	root.add_child(original_interaction_props)
	await process_frame
	assert(original_interaction_props.get_meta("visual_only", false), "原创交互道具根节点缺少 visual_only 标记")
	assert(original_interaction_props.find_child("货架背板", true, false) != null, "原创交互道具缺少货架背板细节")
	assert(original_interaction_props.find_child("货架价格标签", true, false) != null, "原创交互道具缺少货架价格标签")
	assert(original_interaction_props.find_child("扫码器状态灯", true, false) != null, "原创交互道具缺少扫码器状态灯")
	assert(original_interaction_props.find_child("购物篮提手横梁", true, false) != null, "原创交互道具缺少购物篮提手")
	assert(original_interaction_props.find_children("*", "CollisionObject3D", true, false).is_empty(), "原创交互道具候选创建了碰撞对象")
	for visual_node in original_interaction_props.find_children("*", "MeshInstance3D", true, false):
		assert(bool(visual_node.get_meta("visual_only", false)), "原创交互道具视觉节点缺少 visual_only 标记：" + visual_node.name)
	original_interaction_props.free()
	await process_frame

	var baseline_city = CityScene.instantiate()
	baseline_city.set_meta("asset_catalog_path", "res://content/asset-runtime-catalog.json")
	baseline_city.set_meta("settings_path", OS.get_temp_dir().path_join("reference-asset-baseline-city-%d.json" % Time.get_ticks_usec()))
	root.add_child(baseline_city)
	await process_frame
	assert(baseline_city.initialized, "城市正式空目录没有完成初始化")
	assert(baseline_city.get_node_or_null("交互道具层/Visual/候选鸡蛋货架") != null, "城市正式空目录没有挂载原创交互道具候选")
	assert(baseline_city.get_node_or_null("交互道具层/交互道具灰盒回退") == null, "城市正式空目录仍停留在交互道具灰盒回退")
	assert(baseline_city.get_node_or_null("交互道具层/Visual").find_children("*", "CollisionObject3D", true, false).is_empty(), "原创交互道具候选创建了碰撞对象")
	baseline_city.free()
	await process_frame

	var baseline_office = OfficeScene.instantiate()
	baseline_office.set_meta("asset_catalog_path", "res://content/asset-runtime-catalog.json")
	baseline_office.set_meta("settings_path", OS.get_temp_dir().path_join("reference-asset-baseline-office-%d.json" % Time.get_ticks_usec()))
	root.add_child(baseline_office)
	await process_frame
	assert(baseline_office.initialized, "办公室正式目录没有完成初始化")
	assert(baseline_office.get_node_or_null("Visual/原创中前桌面") != null, "办公室正式目录没有挂载纯视觉原创环境候选")
	assert(baseline_office.get_node_or_null("办公室环境灰盒回退") == null, "办公室正式目录仍停留在环境灰盒回退")
	assert(baseline_office.get_node_or_null("Visual").find_children("*", "CollisionShape3D", true, false).is_empty(), "办公室纯视觉环境候选创建了碰撞形状")
	assert(baseline_office.get_node_or_null("Visual").find_children("*", "CollisionObject3D", true, false).is_empty(), "办公室纯视觉环境候选创建了碰撞对象")
	baseline_office.free()
	await process_frame

	var override_office = OfficeScene.instantiate()
	override_office.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-override.json")
	override_office.set_meta("settings_path", OS.get_temp_dir().path_join("reference-asset-override-office-%d.json" % Time.get_ticks_usec()))
	root.add_child(override_office)
	await process_frame
	assert(override_office.initialized, "办公室资产覆盖目录没有完成初始化")
	assert(override_office.player.get_node_or_null("Visual") != null, "办公室玩家没有挂载资产覆盖场景")
	assert(override_office.player.get_node_or_null("Visual/候选主角身体") != null, "办公室没有挂载 P0 主角候选身体")
	assert(override_office.player.get_node_or_null("Visual/候选主角背包") != null, "办公室没有挂载 P0 主角候选背包")
	assert(override_office.player.get_node_or_null("Visual/AnimationPlayer") != null, "办公室 P0 主角候选缺少动画播放器")
	assert(override_office.player.get_node_or_null("原创灰盒角色外观") == null, "办公室玩家挂载覆盖后仍保留灰盒回退")
	assert(override_office.npc.get_node_or_null("Visual/候选NPC身体") != null, "办公室没有挂载 P0 NPC 候选身体")
	assert(override_office.npc.get_node_or_null("原创灰盒NPC外观") == null, "办公室 NPC 挂载覆盖后仍保留灰盒回退")
	assert(override_office.get_node_or_null("Visual/候选工位细节") != null, "办公室没有挂载 P0 环境候选细节")
	var office_candidate_lights := override_office.find_children("*", "OmniLight3D", true, false)
	assert(office_candidate_lights.size() >= 5, "办公室候选吊顶没有挂载暖色局部光源")
	# 普通候选试玩的任务状态必须驱动背景分段，不得只在截图采集态切换。
	override_office.set_meta("candidate_video_backdrop", true)
	override_office.set_meta("candidate_video_backdrop_id", "office-01")
	override_office._apply_candidate_video_backdrop()
	var office_idle_backdrop := override_office.camera_rig.camera.find_child("用户授权办公室视频帧候选背景卡", true, false) as MeshInstance3D
	assert(office_idle_backdrop != null and str(office_idle_backdrop.get_meta("reference_segment", "")) == "office-01", "办公室候选试玩没有绑定 office-01 背景分段")
	var office_ground := override_office.find_child("灰盒地面", true, false)
	assert(office_ground != null, "办公室候选试玩缺少仍保留的灰盒地面节点")
	var office_ground_meshes := office_ground.find_children("*", "MeshInstance3D", true, false)
	assert(not office_ground_meshes.is_empty() and not (office_ground_meshes[0] as MeshInstance3D).visible, "办公室候选视频背景启用后仍显示灰盒地面网格")
	assert(office_ground is CollisionObject3D and not office_ground.find_children("*", "CollisionShape3D", true, false).is_empty(), "办公室候选视频背景启用后错误移除了灰盒地面碰撞")
	override_office.set_meta("candidate_video_backdrop_id", "office-02")
	override_office._apply_candidate_video_backdrop()
	assert(str(office_idle_backdrop.get_meta("reference_segment", "")) == "office-02", "办公室候选试玩状态变化后仍停留在 office-01 背景")
	# office-10 固定镜头必须保留原创办公室环境的空间上下文；这里用一个
	# 非“原创中前”网格做回归探针，防止采集白名单再次把完整 Visual 根误删。
	override_office.set_meta("reference_capture_scenario", "office-10")
	override_office.set_meta("candidate_video_backdrop", true)
	override_office.prepare_reference_capture(false)
	var office_scene_visual_probe := override_office.office_scene_visuals.find_child("状态工位桌面", true, false) as MeshInstance3D
	assert(office_scene_visual_probe != null and office_scene_visual_probe.visible, "办公室候选背景启用后误隐藏分段场景视觉层")
	var office_capture_kept_light := override_office.find_child("候选暖色灯板", true, false) as MeshInstance3D
	assert(office_capture_kept_light != null and office_capture_kept_light.visible, "office-10 采集态误隐藏原创办公室环境网格")
	assert(override_office.vehicle.get_node_or_null("Visual") != null and override_office.vehicle.get_node("Visual").find_child("候选三轮车车体", true, false) != null, "办公室没有使用覆盖目录中的三轮车候选")
	assert(override_office.vehicle.get_node_or_null("原创灰盒三轮车外观") == null, "办公室载具挂载覆盖后仍保留灰盒回退")
	override_office.free()
	await process_frame

	var override_city = CityScene.instantiate()
	override_city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-override.json")
	override_city.set_meta("settings_path", OS.get_temp_dir().path_join("reference-asset-override-city-%d.json" % Time.get_ticks_usec()))
	root.add_child(override_city)
	await process_frame
	assert(override_city.initialized, "城市资产覆盖目录没有完成初始化")
	assert(override_city.player.get_node_or_null("Visual") != null, "城市玩家没有挂载资产覆盖场景")
	assert(override_city.player.get_node_or_null("原创灰盒角色外观") == null, "城市玩家挂载覆盖后仍保留灰盒回退")
	var city_player_visual: Node = override_city.player.get_node_or_null("Visual")
	if city_player_visual.has_method("set_candidate_context"):
		assert(str(city_player_visual.get_meta("candidate_context", "")) == "city", "城市玩家视觉没有进入 city 表现上下文")
		var city_red_back := city_player_visual.get_node_or_null("候选主角载具红色后片") as Node3D
		assert(city_red_back != null and city_red_back.visible, "城市玩家没有显示参考帧红色外套背片")
	assert(override_city.vehicle.get_node_or_null("Visual") != null and override_city.vehicle.get_node("Visual").find_child("候选三轮车车体", true, false) != null, "城市没有挂载 P0 三轮车候选")
	assert(override_city.vehicle.get_node_or_null("原创灰盒三轮车外观") == null, "城市载具挂载覆盖后仍保留灰盒回退")
	assert(override_city.vehicle_wheels.size() == 3, "城市三轮车候选没有绑定三只滚动车轮")
	var candidate_wheel_rotation: float = override_city.vehicle_wheels[0].rotation.x
	override_city.vehicle.current_speed = 2.0
	override_city._update_vehicle_wheel_visuals(0.1)
	assert(absf(override_city.vehicle_wheels[0].rotation.x - candidate_wheel_rotation) > 0.01, "城市三轮车候选车轮没有随速度滚动")
	assert(override_city.get_node_or_null("Visual/候选原创城市细节/候选店铺门面") != null, "城市没有挂载 P0 原创环境候选")
	assert(override_city.get_node_or_null("Visual/候选CC0小型城市楼") != null, "城市没有挂载 P0 CC0 城市建筑候选")
	override_city.set_meta("reference_capture_scenario", "city-01")
	override_city.set_meta("candidate_video_backdrop", true)
	override_city.prepare_reference_capture(false)
	var city_scene_visual_probe := override_city.city_scene_visuals.find_child("状态01店铺门面", true, false) as MeshInstance3D
	assert(city_scene_visual_probe != null and city_scene_visual_probe.visible, "城市候选背景启用后误隐藏分段场景视觉层")
	var city_scene_crowd_probe: Node = override_city.city_scene_visuals.find_child("状态人群标记-00", true, false)
	assert(city_scene_crowd_probe != null, "城市状态视觉层没有创建店前人群标记")
	assert(city_scene_crowd_probe.find_child("状态人群左臂", true, false) != null, "城市状态人群近景缺少左臂轮廓")
	assert(city_scene_crowd_probe.find_child("状态人群发型", true, false) != null, "城市状态人群近景缺少发型轮廓")
	assert(city_scene_crowd_probe.find_child("状态人群身份牌", true, false) != null, "城市状态人群近景缺少身份牌细节")
	assert(override_city.get_node_or_null("交互道具层/Visual/候选鸡蛋货架") != null, "城市没有挂载 P0 交互道具候选")
	assert(override_city.get_node_or_null("交互道具层/交互道具灰盒回退") == null, "城市交互道具挂载覆盖后仍保留灰盒回退")
	# 普通候选试玩的城市任务状态必须同步切换远景分段，覆盖店铺、登记和驾驶链。
	override_city.set_meta("reference_capture_scenario", "")
	override_city.set_meta("candidate_video_backdrop", true)
	override_city.set_meta("candidate_video_backdrop_id", "city-01")
	override_city._apply_candidate_video_backdrop()
	var city_idle_backdrop := override_city.camera_rig.camera.find_child("用户授权城市视频帧候选背景卡", true, false) as MeshInstance3D
	assert(city_idle_backdrop != null and str(city_idle_backdrop.get_meta("reference_segment", "")) == "city-01", "城市候选试玩没有绑定 city-01 背景分段")
	var city_ground := override_city.find_child("街区地面", true, false)
	assert(city_ground != null, "城市候选试玩缺少仍保留的街区地面节点")
	var city_ground_meshes := city_ground.find_children("*", "MeshInstance3D", true, false)
	assert(not city_ground_meshes.is_empty() and not (city_ground_meshes[0] as MeshInstance3D).visible, "城市候选视频背景启用后仍显示灰盒街区地面网格")
	assert(city_ground is CollisionObject3D and not city_ground.find_children("*", "CollisionShape3D", true, false).is_empty(), "城市候选视频背景启用后错误移除了灰盒街区碰撞")
	override_city.set_meta("candidate_video_backdrop_id", "city-08")
	override_city._apply_candidate_video_backdrop()
	assert(str(city_idle_backdrop.get_meta("reference_segment", "")) == "city-08", "城市候选试玩状态变化后仍停留在 city-01 背景")
	assert(override_city.conflict_agent.get_node_or_null("Visual") != null or override_city.conflict_agent.get_node_or_null("原创程序化冲突对象外观") != null, "城市冲突对象没有挂载视觉表现")
	assert(override_city.pedestrians.size() > 0, "城市没有创建行人")
	for pedestrian in override_city.pedestrians:
		var visual_found := pedestrian.get_node_or_null("Visual") != null
		if not visual_found:
			for child in pedestrian.get_children():
				if str(child.name).begins_with("原创程序化人群外观"):
					visual_found = true
					break
		assert(visual_found, "城市行人没有使用候选或灰盒视觉")
	override_city.free()
	await process_frame
	await process_frame
	await process_frame
	print("资产运行时场景接入测试通过")
	quit(0)

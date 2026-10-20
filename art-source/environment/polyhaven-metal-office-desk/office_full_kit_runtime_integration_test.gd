extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")

var office: Node
var previous_embedded := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	previous_embedded = OS.get_environment("P0_EMBEDDED")
	OS.set_environment("P0_EMBEDDED", "1")
	office = OfficeScene.instantiate()
	if office == null:
		_fail("办公室五工位候选真实运行时实例化失败")
		return
	office.set_meta("asset_catalog_path", "res://asset-runtime-catalog-office-full-kit-override.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("office-full-kit-%d.json" % Time.get_ticks_usec()))
	office.set_meta("save_path", OS.get_temp_dir().path_join("office-full-kit-save-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(office)
	for _frame in range(6):
		await process_frame
	if not bool(office.get("initialized")):
		_fail("办公室五工位候选运行时没有初始化")
		return
	if office.get("mission") == null or office.get("npc") == null or office.get("player") == null or not office.get("office_pack") is Dictionary:
		_fail("办公室五工位候选没有保持任务、NPC、玩家和内容包对象")
		return
	var office_pack: Dictionary = office.get("office_pack")
	if str(office_pack.get("id", "")) != "office-leave-on-time-v1":
		_fail("办公室内容包 ID 不正确")
		return
	var mission: MissionState = office.get("mission")
	if int(mission.status) != 1:
		_fail("办公室任务没有保持 ACTIVE 状态")
		return
	var visual := office.get_node_or_null("Visual")
	if visual == null or visual.get_script() == null or not str(visual.get_script().resource_path).ends_with("office_desk_composition.gd"):
		_fail("办公室五工位候选没有挂载完整环境组合")
		return
	if visual.get_node_or_null("固定审阅镜头") != null:
		_fail("嵌入式五工位候选创建了独立固定镜头")
		return
	if visual.get_node_or_null("候选主管工位视觉") == null or visual.get_node_or_null("候选主管工位视觉/主管显示器屏幕") == null:
		_fail("办公室候选缺少主管工位视觉")
		return
	var workstation_card := visual.get_node_or_null("原创办公室连续工位写实背景卡") as MeshInstance3D
	if workstation_card == null or workstation_card.mesh == null or workstation_card.material_override == null:
		_fail("办公室候选缺少连续工位写实背景卡")
		return
	var elevator_card := visual.get_node_or_null("原创办公室电梯厅写实背景卡") as MeshInstance3D
	if elevator_card == null or elevator_card.mesh == null or elevator_card.material_override == null:
		_fail("办公室候选缺少电梯厅写实背景卡")
		return
	var elevator_material := elevator_card.material_override as StandardMaterial3D
	if elevator_material.albedo_texture == null or not str(elevator_material.albedo_texture.resource_path).ends_with("office_elevator_lobby_v1_generated.png"):
		_fail("办公室电梯厅背景卡没有挂载当前原创候选纹理")
		return
	if not bool(elevator_card.get_meta("candidate_visual_only", false)):
		_fail("办公室电梯厅背景卡不能进入交互或碰撞逻辑")
		return
	if visual.find_children("*", "CollisionShape3D", true, false).size() != 5:
		_fail("办公室候选视觉层新增了非工位碰撞体")
		return
	var environment := visual.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment == null or environment.environment == null:
		_fail("办公室候选缺少环境光照配置")
		return
	if environment.environment.ambient_light_energy > 0.36 or environment.environment.adjustment_brightness > 0.92:
		_fail("办公室候选环境光仍可能冲白角色与玻璃：ambient=%s brightness=%s" % [environment.environment.ambient_light_energy, environment.environment.adjustment_brightness])
		return
	var key_light := visual.get_node_or_null("办公室主光") as DirectionalLight3D
	var fill_light := visual.get_node_or_null("办公室冷色补光") as DirectionalLight3D
	if key_light == null or fill_light == null or key_light.light_energy > 0.34 or fill_light.light_energy > 0.14:
		_fail("办公室候选主光/补光强度未收敛")
		return
	if not visual.find_children("*", "Camera3D", true, false).is_empty():
		_fail("嵌入式五工位候选树中存在额外 Camera3D")
		return
	var desks := visual.find_children("*", "StaticBody3D", true, false)
	if desks.size() != 5:
		_fail("办公室五工位候选数量不是 5：%d" % desks.size())
		return
	for desk in desks:
		var desk_script: Script = desk.get_script()
		if desk_script == null or not str(desk_script.resource_path).ends_with("office_desk_candidate.gd"):
			_fail("五工位中存在非 Poly Haven 办公桌候选节点")
			return
		var geometry := desk.get_node_or_null("Geometry")
		if geometry == null or not str(geometry.scene_file_path).ends_with("metal_office_desk_1k.glb"):
			_fail("五工位中存在未引用 Metal Office Desk GLB 的节点")
			return
		if not geometry.visible:
			_fail("五工位候选隐藏了真实 Metal Office Desk 网格，画面会退化为程序化盒体")
			return
		var collision := desk.get_node_or_null("近似碰撞体") as CollisionShape3D
		var interaction_mount := desk.get_node_or_null("交互挂点") as Marker3D
		var display_mount := desk.get_node_or_null("显示器挂点") as Marker3D
		if collision == null or collision.shape == null or interaction_mount == null or display_mount == null:
			_fail("五工位候选缺少碰撞体或交互挂点")
			return
	if office.get_node_or_null("办公室环境灰盒回退") != null:
		_fail("办公室五工位候选仍保留灰盒环境回退")
		return
	var runtime_camera := office.get_node_or_null("玩家/第三人称镜头/第三人称相机") as Camera3D
	if runtime_camera == null or not runtime_camera.current:
		_fail("正式第三人称相机不存在或不是当前相机")
		return
	var camera_script: Script = runtime_camera.get_parent().get_script()
	if camera_script == null or not str(camera_script.resource_path).ends_with("third_person_camera.gd"):
		_fail("当前相机不属于 ThirdPersonCameraRig")
		return
	var active_camera := get_root().get_camera_3d()
	if active_camera != runtime_camera:
		_fail("视口当前相机不是正式第三人称相机")
		return
	print("办公室五工位完整环境候选接入真实运行时通过：5 个 Poly Haven 工位、正式第三人称镜头、任务、NPC 和内容包保持完整")
	_finish(0)

func _fail(message: String) -> void:
	push_error(message)
	_finish(1)

func _finish(code: int) -> void:
	if is_instance_valid(office):
		office.free()
		office = null
	OS.set_environment("P0_EMBEDDED", previous_embedded)
	quit(code)

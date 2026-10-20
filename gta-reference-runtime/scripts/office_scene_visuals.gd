class_name OfficeSceneVisuals
extends Node3D

## 办公室十个参考状态的原创程序化表现层。
##
## 该节点只负责镜头可见的空间、道具、灯光和状态标识，不创建碰撞、导航、
## 交互、任务或存档数据。这样每个参考分段都有自己的场景构图，同时不会
## 破坏已经通过的底层行为回放。

var active_state := ""
var state_root: Node3D
var active_context: Dictionary = {}

const STATE_BACKDROP_PATHS := {
	"office-01": "res://assets/environment/generated/office_workstation_row_v2_worker_generated.png",
	"office-02": "res://assets/environment/generated/office_glass_partition_v1.png",
	"office-03": "res://assets/environment/generated/office_doorway_threshold_v1_generated.png",
	"office-04": "res://assets/environment/generated/office_perception_room_v1_generated.png",
	"office-05": "res://assets/environment/generated/office_elevator_lobby_v2_generated.png",
	"office-06": "res://assets/environment/generated/office_elevator_call_v1_generated.png",
	"office-07": "res://assets/environment/generated/office_elevator_lobby_v1_generated.png",
	"office-08": "res://assets/environment/generated/office_hallway_encounter_v1_generated.png",
	"office-09": "res://assets/environment/generated/office_hallway_dialogue_v1_generated.png",
	"office-10": "res://assets/environment/generated/office_workstation_row_v2_worker_generated.png",
}

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("visual_only", true)
	set_meta("candidate_visual_only", true)
	apply_state("office-01")
	apply_runtime_context({})

func apply_state(state_id: String) -> void:
	var normalized := state_id.strip_edges()
	if normalized.is_empty() or not normalized.begins_with("office-"):
		normalized = "office-01"
	if normalized == active_state and state_root != null and is_instance_valid(state_root):
		return
	active_state = normalized
	if state_root != null and is_instance_valid(state_root):
		state_root.free()
	state_root = Node3D.new()
	state_root.name = "Visual"
	state_root.set_meta("visual_only", true)
	state_root.set_meta("candidate_visual_only", true)
	state_root.set_meta("original_procedural_asset", true)
	state_root.set_meta("office_scene_state", active_state)
	add_child(state_root)
	match active_state:
		"office-01":
			_build_workstation_state("office-01", false)
		"office-02":
			_build_cover_state()
		"office-03":
			_build_transition_state()
		"office-04":
			_build_perception_state()
		"office-05":
			_build_elevator_state(false)
		"office-06":
			_build_elevator_state(true)
		"office-07":
			_build_stair_state()
		"office-08":
			_build_dialogue_state("office-08")
		"office-09":
			_build_dialogue_state("office-09")
		"office-10":
			_build_workstation_state("office-10", true)
		_:
			_build_workstation_state("office-01", false)
	_add_state_backdrop()
	_apply_runtime_context_visuals()

func apply_runtime_state(state_id: String, source: String = "runtime") -> void:
	## 普通游玩状态入口；保留采集态与运行态共用同一套视觉合同。
	apply_state(state_id)
	set_meta("runtime_state_source", source)

func attach_capture_backdrop(camera: Node3D) -> void:
	## 正式视觉验收时，把当前状态的原创环境稿挂到实际相机后方。
	## 世界坐标卡片适合运行时空间纵深，但不适合跟随玩家的固定参考构图；
	## 采集层只改变渲染挂点，不改变碰撞、导航、任务、交互或存档。
	if camera == null or state_root == null or not is_instance_valid(state_root):
		return
	var backdrop: MeshInstance3D = null
	for child in state_root.get_children():
		if child is MeshInstance3D and bool(child.get_meta("original_procedural_asset", false)) and child.has_meta("backdrop_texture_path"):
			backdrop = child as MeshInstance3D
			break
	if backdrop == null:
		return
	if backdrop.get_parent() != camera:
		backdrop.reparent(camera, false)
	backdrop.position = Vector3(0.0, 0.0, -12.0)
	backdrop.rotation = Vector3.ZERO
	var mesh := backdrop.mesh as QuadMesh
	if mesh != null:
		# 预留相机视锥与嵌入式窗口的边缘余量，避免 16:9 画面四周露出灰盒空间。
		mesh.size = Vector2(32.0, 18.0)
	var material := backdrop.material_override as StandardMaterial3D
	if material != null:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		material.render_priority = -20
	backdrop.set_meta("candidate_background_backdrop", true)
	backdrop.set_meta("capture_camera_backdrop", true)
	backdrop.visible = true

func apply_runtime_context(context: Dictionary) -> void:
	## 将真实玩法的粗粒度状态同步到当前场景表现层；不改变任务、碰撞、导航或存档。
	var next_context := context.duplicate(true)
	if next_context == active_context and state_root != null and is_instance_valid(state_root):
		return
	active_context = next_context
	set_meta("runtime_visual_context", active_context.duplicate(true))
	_apply_runtime_context_visuals()

func _apply_runtime_context_visuals() -> void:
	if state_root == null or not is_instance_valid(state_root):
		return
	var awareness := str(active_context.get("awareness", "clear"))
	var hallway_encounter := bool(active_context.get("hallway_encounter", false))
	var typing := bool(active_context.get("typing", false))
	var mission_failed := bool(active_context.get("mission_failed", false))
	state_root.set_meta("runtime_awareness", awareness)
	state_root.set_meta("runtime_hallway_encounter", hallway_encounter)
	state_root.set_meta("runtime_typing", typing)
	state_root.set_meta("runtime_mission_failed", mission_failed)

	# 搜索状态使用独立的黄色反馈灯，确保 office-02 的画面反馈跟随
	# 感知状态，而不是只依赖 HUD 或 NPC 节点外的调试标记。
	_set_runtime_visual("状态02搜索反馈灯", active_state == "office-02" and awareness == "search", Color("d7a74f"), 0.72)
	# office-04 的警觉标识与真实警觉等级同步；节点仍是表现层，
	# 感知判定本身仍由 benchmark_scene 和 perception_state 负责。
	var alert_visible := active_state == "office-04" and awareness in ["yellow", "search", "red"]
	var alert_color := Color("cf4c4d") if awareness == "red" else Color("e6a74f")
	_set_runtime_visual("状态04警觉标识", alert_visible, alert_color, 0.74 if awareness == "red" else 0.42)
	# 走廊遇见状态使用红色/黄色边缘反馈，保持 office-08/09 的近景识别。
	var dialogue_visible := active_state in ["office-08", "office-09"] and (hallway_encounter or awareness in ["yellow", "search", "red"])
	_set_runtime_visual("状态对话门边警示灯", dialogue_visible, alert_color, 0.68 if awareness == "red" else 0.40)
	_set_runtime_visual("状态对话警觉上沿", dialogue_visible, alert_color, 0.54 if awareness == "red" else 0.30)
	_set_runtime_visual("状态对话警觉地线", dialogue_visible, alert_color, 0.34 if awareness == "red" else 0.18)
	# office-10 的键盘反馈只在真实坐姿打字时亮起，避免待机画面误显示输入状态。
	_set_runtime_visual("状态工位输入反馈灯", active_state == "office-10" and typing, Color("e0ad66"), 0.62)

func _set_runtime_visual(node_name: String, visible: bool, color: Color, energy: float) -> void:
	var node := state_root.get_node_or_null(NodePath(node_name)) as MeshInstance3D
	if node == null:
		return
	node.visible = visible
	var material := node.material_override as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = color
	material.emission_enabled = visible and energy > 0.0
	material.emission = color
	material.emission_energy_multiplier = energy

func _build_workstation_state(state_id: String, typing: bool) -> void:
	var anchor := Vector3(0.0, 0.0, 2.0)
	var desk_color := Color("765845") if not typing else Color("8a6449")
	_add_workstation_depth(anchor, typing)
	_add_box("状态工位桌面", Vector3(2.32, 0.12, 0.96), anchor + Vector3(0.0, 0.88, 0.0), desk_color, 0.66)
	_add_box("状态工位桌面前沿", Vector3(2.38, 0.17, 0.08), anchor + Vector3(0.0, 0.79, -0.45), Color("3e3430"), 0.58)
	_add_box("状态工位显示器", Vector3(0.88, 0.58, 0.07), anchor + Vector3(0.08, 1.30, -0.16), Color("1b2023"), 0.28, 0.18)
	_add_box("状态工位显示器屏幕", Vector3(0.70, 0.42, 0.075), anchor + Vector3(0.08, 1.30, -0.205), Color("285861"), 0.30, 0.10, Color("0b2931"), 0.18)
	_add_box("状态工位显示器支架", Vector3(0.08, 0.22, 0.08), anchor + Vector3(0.08, 1.02, -0.15), Color("30383c"), 0.46, 0.12)
	_add_box("状态工位显示器底座", Vector3(0.38, 0.035, 0.18), anchor + Vector3(0.08, 0.91, -0.14), Color("30383c"), 0.44, 0.16)
	_add_box("状态工位显示器边框高光", Vector3(0.74, 0.025, 0.025), anchor + Vector3(0.08, 1.57, -0.21), Color("a7b3ad"), 0.22, 0.04)
	_add_box("状态工位键盘", Vector3(0.48, 0.035, 0.18), anchor + Vector3(0.02, 0.95, 0.22), Color("4f5b60"), 0.40, 0.24)
	_add_box("状态工位键盘按键行-00", Vector3(0.42, 0.012, 0.018), anchor + Vector3(0.02, 0.976, 0.17), Color("a2aaa7"), 0.26, 0.08)
	_add_box("状态工位键盘按键行-01", Vector3(0.42, 0.012, 0.018), anchor + Vector3(0.02, 0.978, 0.22), Color("a2aaa7"), 0.26, 0.08)
	_add_box("状态工位鼠标垫", Vector3(0.32, 0.018, 0.22), anchor + Vector3(0.42, 0.95, 0.24), Color("252b2e"), 0.36, 0.10)
	_add_box("状态工位鼠标", Vector3(0.08, 0.04, 0.12), anchor + Vector3(0.42, 0.985, 0.24), Color("5e696d"), 0.32, 0.12)
	_add_box("状态工位打印机", Vector3(0.58, 0.34, 0.42), anchor + Vector3(-0.72, 1.10, -0.02), Color("c2b8aa"), 0.48, 0.04)
	_add_box("状态工位打印机出纸口", Vector3(0.34, 0.035, 0.08), anchor + Vector3(-0.72, 1.28, -0.24), Color("2a3135"), 0.32, 0.12)
	_add_box("状态工位文件堆", Vector3(0.34, 0.22, 0.26), anchor + Vector3(-0.40, 1.06, 0.18), Color("ddd0bd"), 0.88)
	_add_box("状态工位桌下柜体", Vector3(0.62, 0.66, 0.56), anchor + Vector3(0.72, 0.43, -0.03), Color("55443c"), 0.62, 0.04)
	_add_box("状态工位桌下柜门缝", Vector3(0.50, 0.018, 0.48), anchor + Vector3(0.72, 0.43, -0.32), Color("2b2928"), 0.28, 0.02)
	_add_box("状态工位桌下柜把手", Vector3(0.18, 0.04, 0.035), anchor + Vector3(0.72, 0.50, -0.35), Color("c6a06b"), 0.34, 0.06)
	_add_box("状态工位隔断侧板", Vector3(0.08, 1.40, 0.76), anchor + Vector3(1.28, 1.08, 0.18), Color("66737a"), 0.72, 0.06)
	_add_box("状态工位椅面", Vector3(0.64, 0.12, 0.62), anchor + Vector3(0.0, 0.45, 0.94), Color("303b42"), 0.62, 0.10)
	_add_box("状态工位椅背", Vector3(0.60, 0.68, 0.10), anchor + Vector3(0.0, 0.76, 1.18), Color("303b42"), 0.62, 0.10)
	_add_box("状态工位椅左扶手", Vector3(0.08, 0.20, 0.42), anchor + Vector3(-0.35, 0.66, 0.92), Color("242d31"), 0.52, 0.12)
	_add_box("状态工位椅右扶手", Vector3(0.08, 0.20, 0.42), anchor + Vector3(0.35, 0.66, 0.92), Color("242d31"), 0.52, 0.12)
	_add_box("状态工位台灯", Vector3(0.28, 0.10, 0.18), anchor + Vector3(0.84, 1.30, 0.18), Color("d59b54"), 0.72, 0.0, Color("9b5f2e"), 0.16)
	_add_box("状态工位顶灯", Vector3(1.60, 0.035, 0.16), anchor + Vector3(0.10, 2.78, -0.12), Color("e8dfc7"), 0.26, 0.0, Color("fff0c7"), 0.70)
	_add_light("状态工位暖光", anchor + Vector3(0.84, 1.25, 0.05), Color("ffd89d"), 0.18, 1.8)
	# 参考 office-01/10 的镜头不是孤立的一张桌子：近景要同时读到
	# 屏风、地面导视、墙面功能带和远处的办公层次。以下节点全是视觉层，
	# 不创建碰撞、导航、交互、任务或存档状态。
	_add_box("状态工位屏风金属压条", Vector3(2.12, 0.035, 0.025), anchor + Vector3(1.30, 1.42, 0.14), Color("b7a58f"), 0.46, 0.08)
	_add_box("状态工位地面导视线", Vector3(2.70, 0.022, 0.035), anchor + Vector3(0.0, 0.14, 1.74), Color("c29a63"), 0.44, 0.0, Color("c29a63"), 0.20)
	_add_box("状态工位墙面功能带", Vector3(0.045, 0.68, 2.20), anchor + Vector3(-3.25, 1.72, -0.35), Color("65777c"), 0.38, 0.05, Color("243d45"), 0.10)
	_add_box("状态工位墙面暖色导视牌", Vector3(0.055, 0.40, 0.90), anchor + Vector3(-3.18, 2.55, 0.78), Color("b88a62"), 0.54, 0.02, Color("8f5d38"), 0.18)
	_add_box("状态工位桌下抽屉", Vector3(0.46, 0.22, 0.40), anchor + Vector3(-0.46, 0.62, -0.10), Color("604b41"), 0.50, 0.04)
	_add_box("状态工位显示器顶部反光", Vector3(0.62, 0.022, 0.025), anchor + Vector3(0.08, 1.58, -0.22), Color("b9c2ba"), 0.22, 0.02, Color("e0e8d9"), 0.14)
	_add_box("状态工位键盘中央分割", Vector3(0.018, 0.014, 0.16), anchor + Vector3(0.02, 0.982, 0.22), Color("c0c8c2"), 0.22, 0.04)
	_add_box("状态工位隔断上沿", Vector3(1.24, 0.06, 0.08), anchor + Vector3(1.28, 1.80, 0.18), Color("a4a49a"), 0.36, 0.04, Color("d7c7a9"), 0.16)
	_add_box("状态工位后墙窗带竖分格", Vector3(0.035, 0.92, 0.025), anchor + Vector3(1.82, 1.94, -2.20), Color("d9b486"), 0.28, 0.0)
	_add_plant(anchor + Vector3(2.82, 0.0, -0.72))
	if typing:
		_add_box("状态工位输入反馈灯", Vector3(0.06, 0.06, 0.06), anchor + Vector3(-0.52, 1.02, -0.28), Color("e0ad66"), 0.40, 0.0, Color("e0ad66"), 0.5)
		_add_box("状态工位文件托盘", Vector3(0.38, 0.04, 0.24), anchor + Vector3(-0.58, 0.96, 0.16), Color("d7cdbb"), 0.82)
	set_meta("visual_state_contract", {
		"state": state_id,
		"anchor": [anchor.x, anchor.y, anchor.z],
		"typing": typing,
		"required_layers": ["workstation", "monitor", "chair", "warm_light", "background_depth", "contact_detail", "office_detail"]
	})

func _add_workstation_depth(anchor: Vector3, typing: bool) -> void:
	# 参考首帧需要读到“人在一排工位里”，而不是一张孤立桌子；这些节点只
	# 增加可见纵深、接触暗部和办公层次，不参与碰撞、导航或交互。
	_add_box("状态工位地毯主面", Vector3(7.20, 0.025, 5.20), anchor + Vector3(0.0, 0.12, 0.52), Color("3f4749"), 0.96)
	for tile_index in range(6):
		var tile_x := -2.70 + float(tile_index % 3) * 2.70
		var tile_z := -0.70 + float(tile_index / 3) * 2.40
		_add_box("状态工位地毯拼缝-%02d" % tile_index, Vector3(2.30, 0.012, 0.022), anchor + Vector3(tile_x, 0.145, tile_z), Color("667071"), 0.98)
	for panel_index in range(3):
		var panel_z := -1.35 + float(panel_index) * 1.55
		_add_box("状态工位顶棚灯板-%02d" % panel_index, Vector3(2.18, 0.035, 0.52), anchor + Vector3(0.0, 2.76, panel_z), Color("d6d0c0"), 0.38, 0.02, Color("fff0c7"), 0.36)
	_add_box("状态工位后排桌面", Vector3(2.70, 0.10, 0.76), anchor + Vector3(-2.35, 0.86, -1.02), Color("665246"), 0.76)
	_add_box("状态工位后排屏风", Vector3(2.82, 1.38, 0.08), anchor + Vector3(-2.35, 1.40, -0.64), Color("56676b"), 0.78, 0.04)
	_add_box("状态工位后排显示器", Vector3(0.72, 0.44, 0.06), anchor + Vector3(-2.35, 1.26, -1.00), Color("202a30"), 0.30, 0.18, Color("285861"), 0.12)
	_add_box("状态工位后排显示器微光", Vector3(0.56, 0.28, 0.025), anchor + Vector3(-2.35, 1.27, -1.045), Color("3c7e84"), 0.26, 0.0, Color("3c7e84"), 0.28)
	_add_box("状态工位后墙暖窗带", Vector3(4.60, 1.16, 0.04), anchor + Vector3(0.85, 1.94, -2.12), Color("8e7665"), 0.36, 0.02, Color("d58f62"), 0.18)
	_add_box("状态工位后墙窗框横", Vector3(4.72, 0.06, 0.06), anchor + Vector3(0.85, 1.94, -2.16), Color("c5aa84"), 0.42, 0.06)
	for blind_index in range(4):
		_add_box("状态工位后墙窗帘横纹-%02d" % blind_index, Vector3(4.20, 0.028, 0.035), anchor + Vector3(0.85, 1.58 + float(blind_index) * 0.20, -2.19), Color("d0a77f"), 0.32, 0.02)
	for window_index in range(3):
		_add_box("状态工位后墙窗框竖-%02d" % window_index, Vector3(0.06, 1.22, 0.07), anchor + Vector3(-0.65 + float(window_index) * 1.50, 1.94, -2.16), Color("c5aa84"), 0.42, 0.06)
	_add_box("状态工位后墙窗下沿", Vector3(4.72, 0.10, 0.08), anchor + Vector3(0.85, 1.32, -2.14), Color("665246"), 0.72)
	for leg_side in [-1.0, 1.0]:
		_add_box("状态工位桌腿-%s" % ("左" if leg_side < 0.0 else "右"), Vector3(0.08, 0.74, 0.08), anchor + Vector3(leg_side * 0.92, 0.44, 0.10), Color("343a3d"), 0.52, 0.30)
	_add_box("状态工位桌下接触暗部", Vector3(1.72, 0.018, 0.46), anchor + Vector3(0.0, 0.185, 0.30), Color("252a2d"), 0.99)
	_add_box("状态工位椅下接触暗部", Vector3(0.86, 0.018, 0.74), anchor + Vector3(0.0, 0.19, 0.94), Color("252a2d"), 0.99)
	_add_box("状态工位椅底座", Vector3(0.46, 0.06, 0.16), anchor + Vector3(0.0, 0.31, 0.94), Color("232a2d"), 0.68, 0.28)
	for wheel_side in [-1.0, 1.0]:
		_add_box("状态工位椅脚-%s" % ("左" if wheel_side < 0.0 else "右"), Vector3(0.08, 0.04, 0.42), anchor + Vector3(wheel_side * 0.18, 0.28, 0.94), Color("2b3336"), 0.72, 0.22)
	_add_box("状态工位桌面线缆槽", Vector3(0.74, 0.045, 0.08), anchor + Vector3(0.52, 0.95, 0.34), Color("252b2e"), 0.40, 0.24)
	if typing:
		_add_box("状态工位键盘接触暗部", Vector3(0.60, 0.014, 0.24), anchor + Vector3(0.02, 0.925, 0.22), Color("202528"), 0.99)

func _build_cover_state() -> void:
	_add_box("状态02遮蔽面", Vector3(2.50, 1.72, 0.08), Vector3(0.0, 1.02, 0.70), Color("566268"), 0.74, 0.04)
	_add_box("状态02遮蔽内嵌面", Vector3(2.18, 1.42, 0.022), Vector3(0.0, 1.02, 0.645), Color("63767a"), 0.68, 0.03)
	_add_box("状态02遮蔽上沿", Vector3(2.58, 0.08, 0.12), Vector3(0.0, 1.90, 0.70), Color("b7a58f"), 0.62, 0.08)
	_add_box("状态02遮蔽左竖边", Vector3(0.08, 1.78, 0.12), Vector3(-1.26, 1.02, 0.70), Color("d0bb8d"), 0.46, 0.10)
	_add_box("状态02遮蔽右竖边", Vector3(0.08, 1.78, 0.12), Vector3(1.26, 1.02, 0.70), Color("d0bb8d"), 0.46, 0.10)
	_add_box("状态02遮蔽中缝高光", Vector3(0.035, 1.56, 0.025), Vector3(0.0, 1.02, 0.625), Color("a9b8ad"), 0.28, 0.02)
	_add_box("状态02遮蔽底部反光", Vector3(2.34, 0.035, 0.035), Vector3(0.0, 0.26, 0.625), Color("c5aa75"), 0.34, 0.0, Color("e3c58b"), 0.16)
	_add_box("状态02文件箱左", Vector3(0.34, 0.42, 0.32), Vector3(-0.72, 0.34, 0.42), Color("7b6154"), 0.82)
	_add_box("状态02文件箱右", Vector3(0.34, 0.42, 0.32), Vector3(0.72, 0.34, 0.42), Color("7b6154"), 0.82)
	_add_box("状态02文件箱纸张左", Vector3(0.22, 0.028, 0.24), Vector3(-0.72, 0.57, 0.24), Color("d7c8ad"), 0.72, 0.02)
	_add_box("状态02文件箱纸张右", Vector3(0.22, 0.028, 0.24), Vector3(0.72, 0.57, 0.24), Color("d7c8ad"), 0.72, 0.02)
	_add_box("状态02侧墙", Vector3(0.12, 2.45, 4.10), Vector3(-2.45, 1.22, -0.90), Color("424d54"), 0.86, 0.10)
	_add_box("状态02文件柜", Vector3(0.72, 1.58, 0.72), Vector3(2.00, 0.92, -0.45), Color("5a656b"), 0.62, 0.16)
	_add_box("状态02文件柜把手", Vector3(0.05, 0.05, 0.30), Vector3(1.63, 1.05, -0.84), Color("c7a778"), 0.42, 0.32)
	_add_box("状态02文件柜抽屉线", Vector3(0.05, 0.035, 0.58), Vector3(1.63, 0.84, -0.84), Color("2b353b"), 0.52, 0.18)
	_add_box("状态02文件柜顶面", Vector3(0.82, 0.06, 0.80), Vector3(2.00, 1.74, -0.45), Color("718086"), 0.54, 0.12)
	_add_box("状态02遮蔽底部踢脚线", Vector3(2.62, 0.12, 0.10), Vector3(0.0, 0.18, 0.67), Color("313b40"), 0.82, 0.18)
	_add_box("状态02文件箱标签左", Vector3(0.035, 0.16, 0.20), Vector3(-0.55, 0.38, 0.25), Color("d6b57c"), 0.46, 0.0, Color("d6b57c"), 0.16)
	_add_box("状态02文件箱标签右", Vector3(0.035, 0.16, 0.20), Vector3(0.89, 0.38, 0.25), Color("d6b57c"), 0.46, 0.0, Color("d6b57c"), 0.16)
	_add_box("状态02远处门厅暖光", Vector3(1.56, 2.16, 0.035), Vector3(2.96, 1.42, -2.16), Color("a87f62"), 0.24, 0.02, Color("e4b184"), 0.24)
	_add_box("状态02远处门框左", Vector3(0.12, 2.86, 0.18), Vector3(2.10, 1.45, -2.12), Color("4a4f55"), 0.42, 0.18)
	_add_box("状态02远处门框右", Vector3(0.12, 2.86, 0.18), Vector3(3.82, 1.45, -2.12), Color("4a4f55"), 0.42, 0.18)
	_add_box("状态02远处门框上沿", Vector3(1.84, 0.14, 0.20), Vector3(2.96, 2.86, -2.12), Color("5f6365"), 0.42, 0.16)
	_add_box("状态02远处门内地面亮带", Vector3(1.52, 0.025, 0.08), Vector3(2.96, 0.15, -1.96), Color("c39a68"), 0.32, 0.0, Color("e2bd82"), 0.16)
	_add_box("状态02顶棚灯带-00", Vector3(1.84, 0.035, 0.28), Vector3(-1.38, 2.76, -0.72), Color("d9d2c3"), 0.32, 0.02, Color("fff0c7"), 0.38)
	_add_box("状态02顶棚灯带-01", Vector3(1.84, 0.035, 0.28), Vector3(1.38, 2.76, -1.72), Color("d9d2c3"), 0.32, 0.02, Color("fff0c7"), 0.38)
	_add_light("状态02掩体顶灯", Vector3(0.0, 2.70, -0.25), Color("ead4ad"), 0.16, 3.5)
	_add_box("状态02地面暖色定位线", Vector3(2.22, 0.025, 0.035), Vector3(0.0, 0.13, 0.02), Color("c29a63"), 0.45, 0.0, Color("c29a63"), 0.25)
	_add_box("状态02搜索反馈灯", Vector3(0.12, 0.06, 0.06), Vector3(0.0, 1.98, 0.62), Color("d7a74f"), 0.36, 0.0, Color("d7a74f"), 0.0)
	set_meta("visual_state_contract", {"state": "office-02", "required_layers": ["cover", "cover_edge", "cover_inset", "props", "doorway_depth", "ceiling_lighting", "floor_marking"]})

func _build_transition_state() -> void:
	var door_center := Vector3(0.0, 1.45, -6.95)
	_add_box("状态03门框左", Vector3(0.16, 2.90, 0.20), door_center + Vector3(-1.25, 0.0, 0.0), Color("4a4f55"), 0.42, 0.22)
	_add_box("状态03门框右", Vector3(0.16, 2.90, 0.20), door_center + Vector3(1.25, 0.0, 0.0), Color("4a4f55"), 0.42, 0.22)
	_add_box("状态03门框上沿", Vector3(2.65, 0.16, 0.20), door_center + Vector3(0.0, 1.38, 0.0), Color("9d826a"), 0.68, 0.08)
	_add_box("状态03走廊灯带", Vector3(2.0, 0.035, 0.09), door_center + Vector3(0.0, 2.30, -0.12), Color("e1b875"), 0.40, 0.0, Color("d59b54"), 0.50)
	_add_box("状态03门内地面带", Vector3(2.10, 0.022, 0.72), door_center + Vector3(0.0, -1.28, -0.38), Color("434d54"), 0.90)
	_add_box("状态03门内办公桌", Vector3(1.92, 0.16, 0.68), door_center + Vector3(0.0, 0.82, -1.08), Color("5d473d"), 0.66, 0.05)
	_add_box("状态03门内办公桌前沿", Vector3(1.98, 0.16, 0.08), door_center + Vector3(0.0, 0.72, -1.42), Color("332f31"), 0.52, 0.04)
	_add_box("状态03门内显示器", Vector3(0.62, 0.42, 0.06), door_center + Vector3(-0.30, 1.22, -1.42), Color("1f292e"), 0.28, 0.16)
	_add_box("状态03门内显示器屏幕", Vector3(0.48, 0.28, 0.025), door_center + Vector3(-0.30, 1.22, -1.46), Color("3d7778"), 0.22, 0.0, Color("8fc2a4"), 0.24)
	_add_box("状态03门内桌腿左", Vector3(0.07, 0.62, 0.07), door_center + Vector3(-0.76, 0.38, -1.10), Color("2e3335"), 0.48, 0.20)
	_add_box("状态03门内桌腿右", Vector3(0.07, 0.62, 0.07), door_center + Vector3(0.76, 0.38, -1.10), Color("2e3335"), 0.48, 0.20)
	_add_box("状态03门内墙面暖色画框", Vector3(0.045, 0.72, 1.02), door_center + Vector3(-0.70, 1.92, -1.90), Color("8d674f"), 0.48, 0.04)
	_add_box("状态03门内画框画面", Vector3(0.025, 0.56, 0.82), door_center + Vector3(-0.70, 1.92, -1.95), Color("b88b68"), 0.34, 0.0, Color("e0b58b"), 0.16)
	_add_box("状态03门内画框上沿", Vector3(0.05, 0.06, 1.06), door_center + Vector3(-0.70, 2.30, -1.90), Color("c09a6b"), 0.30, 0.04)
	_add_box("状态03门内画框下沿", Vector3(0.05, 0.06, 1.06), door_center + Vector3(-0.70, 1.54, -1.90), Color("c09a6b"), 0.30, 0.04)
	_add_box("状态03门侧公告板", Vector3(0.12, 1.35, 1.10), door_center + Vector3(-2.10, -0.25, 0.12), Color("6e594d"), 0.74)
	_add_box("状态03公告板横条", Vector3(0.05, 0.08, 0.74), door_center + Vector3(-2.04, 0.05, -0.03), Color("d3b37c"), 0.52)
	_add_box("状态03公告板白纸", Vector3(0.035, 0.56, 0.42), door_center + Vector3(-2.02, -0.18, -0.03), Color("d8d0bc"), 0.82)
	_add_box("状态03门把手", Vector3(0.08, 0.08, 0.28), door_center + Vector3(0.92, 0.72, -0.16), Color("c8a36e"), 0.36, 0.22)
	_add_box("状态03出口指示牌", Vector3(0.72, 0.24, 0.04), door_center + Vector3(0.0, 2.36, -0.16), Color("477b63"), 0.42, 0.0, Color("74c58b"), 0.50)
	_add_box("状态03门顶闭门器", Vector3(0.54, 0.07, 0.10), door_center + Vector3(0.62, 1.20, -0.18), Color("77736e"), 0.40, 0.20)
	_add_box("状态03门槛左反光边", Vector3(0.06, 0.035, 0.72), door_center + Vector3(-0.98, -1.24, -0.40), Color("c6a06b"), 0.36, 0.0, Color("e7c88e"), 0.26)
	_add_box("状态03门槛右反光边", Vector3(0.06, 0.035, 0.72), door_center + Vector3(0.98, -1.24, -0.40), Color("c6a06b"), 0.36, 0.0, Color("e7c88e"), 0.26)
	_add_box("状态03走廊扶手", Vector3(0.06, 0.06, 3.80), door_center + Vector3(-2.02, 0.38, 0.92), Color("8e7964"), 0.52, 0.12)
	_add_box("状态03公告板钉帽", Vector3(0.09, 0.09, 0.04), door_center + Vector3(-2.02, 0.26, -0.03), Color("d59b54"), 0.38, 0.0, Color("edc477"), 0.38)
	_add_box("状态03门内脚垫", Vector3(1.72, 0.025, 0.44), door_center + Vector3(0.0, -1.255, -0.72), Color("252d32"), 0.76, 0.0, Color("5e6a6c"), 0.16)
	_add_light("状态03走廊顶灯", door_center + Vector3(-1.70, 2.58, 0.84), Color("e6d0a6"), 0.12, 2.3)
	for floor_line in range(4):
		_add_box("状态03走廊地砖缝-%02d" % floor_line, Vector3(2.10, 0.012, 0.018), door_center + Vector3(0.0, 0.15, -1.24 + float(floor_line) * 0.72), Color("8d7e70"), 0.98)
	_add_box("状态03走廊踢脚线", Vector3(0.08, 0.18, 4.80), door_center + Vector3(2.10, -1.18, 1.40), Color("8f7765"), 0.62)
	_add_light("状态03门内暖光", door_center + Vector3(0.0, 1.85, -0.65), Color("e4b184"), 0.22, 2.8)
	set_meta("visual_state_contract", {"state": "office-03", "required_layers": ["door_frame", "corridor_light", "threshold", "interior_desk", "interior_monitor", "wall_art"]})

func _build_perception_state() -> void:
	_add_box("状态04感知地面圈", Vector3(2.6, 0.018, 0.06), Vector3(3.0, 0.14, -3.85), Color("d99a4d"), 0.44, 0.0, Color("d99a4d"), 0.25)
	_add_box("状态04感知地面圈侧", Vector3(0.06, 0.018, 2.4), Vector3(1.72, 0.14, -3.0), Color("d99a4d"), 0.44, 0.0, Color("d99a4d"), 0.25)
	_add_box("状态04感知扇区左", Vector3(0.045, 0.026, 2.35), Vector3(2.22, 0.16, -3.32), Color("d99a4d"), 0.44, 0.0, Color("d99a4d"), 0.20)
	_add_box("状态04感知扇区右", Vector3(0.045, 0.026, 2.35), Vector3(3.78, 0.16, -3.32), Color("d99a4d"), 0.44, 0.0, Color("d99a4d"), 0.20)
	_add_box("状态04门内前台桌", Vector3(2.28, 0.16, 0.72), Vector3(3.0, 0.86, -4.82), Color("5b463d"), 0.64, 0.05)
	_add_box("状态04门内前台前沿", Vector3(2.34, 0.18, 0.08), Vector3(3.0, 0.75, -5.18), Color("302e31"), 0.52, 0.04)
	_add_box("状态04门内显示器", Vector3(0.62, 0.42, 0.06), Vector3(3.05, 1.26, -5.14), Color("202a30"), 0.28, 0.16)
	_add_box("状态04门内显示器屏幕", Vector3(0.48, 0.28, 0.025), Vector3(3.05, 1.26, -5.18), Color("356e73"), 0.22, 0.0, Color("94c1a8"), 0.22)
	_add_box("状态04门内桌腿左", Vector3(0.07, 0.62, 0.07), Vector3(2.22, 0.40, -4.82), Color("2f3437"), 0.46, 0.18)
	_add_box("状态04门内桌腿右", Vector3(0.07, 0.62, 0.07), Vector3(3.78, 0.40, -4.82), Color("2f3437"), 0.46, 0.18)
	_add_box("状态04门内墙面标语牌", Vector3(0.05, 0.52, 1.18), Vector3(3.0, 2.20, -5.58), Color("8f684f"), 0.44, 0.04)
	_add_box("状态04门内标语牌画面", Vector3(0.025, 0.34, 0.94), Vector3(3.0, 2.20, -5.64), Color("d5b890"), 0.28, 0.0, Color("efd6a7"), 0.16)
	_add_box("状态04门内标语牌上沿", Vector3(0.06, 0.06, 1.22), Vector3(3.0, 2.49, -5.58), Color("c3a16e"), 0.28, 0.04)
	_add_box("状态04巡查终端", Vector3(0.34, 0.52, 0.22), Vector3(2.95, 1.08, -3.72), Color("26353b"), 0.30, 0.18)
	_add_box("状态04巡查终端屏", Vector3(0.24, 0.28, 0.03), Vector3(2.95, 1.20, -3.85), Color("dfb35f"), 0.28, 0.0, Color("dfb35f"), 0.48)
	_add_box("状态04警觉标识", Vector3(0.12, 0.52, 0.06), Vector3(4.42, 1.82, -3.36), Color("cf4c4d"), 0.34, 0.0, Color("cf4c4d"), 0.52)
	_add_box("状态04观察窗带", Vector3(0.05, 1.22, 2.25), Vector3(-6.6, 2.18, -3.10), Color("5e7880"), 0.28, 0.05, Color("243e46"), 0.10)
	_add_box("状态04警觉反光条", Vector3(0.045, 0.06, 2.30), Vector3(-6.54, 2.88, -3.10), Color("e0ad66"), 0.40, 0.0, Color("e0ad66"), 0.45)
	_add_box("状态04观察窗竖框", Vector3(0.06, 1.30, 0.05), Vector3(-6.56, 2.18, -3.10), Color("b9a38d"), 0.44, 0.12)
	_add_box("状态04观察窗横框", Vector3(0.05, 0.06, 2.30), Vector3(-6.56, 2.18, -3.08), Color("b9a38d"), 0.44, 0.08)
	_add_box("状态04门内地面暖光带", Vector3(2.18, 0.025, 0.08), Vector3(3.0, 0.15, -4.08), Color("c59b68"), 0.32, 0.0, Color("e6c184"), 0.18)
	_add_box("状态04远端办公桌", Vector3(2.20, 0.10, 0.72), Vector3(-3.80, 0.90, -2.70), Color("665346"), 0.74)
	_add_box("状态04远端显示器", Vector3(0.55, 0.42, 0.06), Vector3(-3.78, 1.22, -2.88), Color("253238"), 0.30, 0.16)
	_add_light("状态04顶灯带", Vector3(-3.80, 2.72, -2.70), Color("f1d6a6"), 0.14, 3.6)
	_add_light("状态04警觉暖光", Vector3(2.75, 1.15, -3.25), Color("f0c752"), 0.12, 2.6)
	set_meta("visual_state_contract", {"state": "office-04", "required_layers": ["perception_zone", "interior_desk", "interior_monitor", "wall_sign", "window_band", "alert_light", "warm_threshold"]})

func _build_elevator_state(active_call: bool) -> void:
	var base := Vector3(7.0, 0.0, -6.85)
	_add_box("状态电梯后墙", Vector3(3.55, 2.95, 0.14), base + Vector3(0.0, 1.48, -0.42), Color("525a63"), 0.62, 0.18)
	_add_box("状态电梯左门", Vector3(1.45, 2.34, 0.10), base + Vector3(-0.78, 1.25, -0.52), Color("343c45"), 0.34, 0.26)
	_add_box("状态电梯右门", Vector3(1.45, 2.34, 0.10), base + Vector3(0.78, 1.25, -0.52), Color("343c45"), 0.34, 0.26)
	_add_box("状态电梯中缝", Vector3(0.06, 2.34, 0.12), base + Vector3(0.0, 1.25, -0.58), Color("b6a894"), 0.54, 0.08)
	_add_box("状态电梯呼叫面板", Vector3(0.24, 0.54, 0.08), base + Vector3(1.84, 1.18, -0.54), Color("252b34"), 0.42, 0.20)
	_add_box("状态电梯呼叫灯", Vector3(0.09, 0.09, 0.04), base + Vector3(1.84, 1.34, -0.60), Color("e8b84a"), 0.38, 0.0, Color("e8b84a"), 0.70 if active_call else 0.18)
	_add_box("状态电梯呼叫上箭头", Vector3(0.07, 0.12, 0.025), base + Vector3(1.84, 1.48, -0.61), Color("d8b36f"), 0.34, 0.0, Color("d8b36f"), 0.34)
	_add_box("状态电梯呼叫下箭头", Vector3(0.07, 0.12, 0.025), base + Vector3(1.84, 1.10, -0.61), Color("d8b36f"), 0.34, 0.0, Color("d8b36f"), 0.34)
	_add_box("状态电梯楼层牌", Vector3(1.10, 0.34, 0.06), base + Vector3(0.0, 2.58, -0.56), Color("20262d"), 0.35, 0.18)
	_add_box("状态电梯楼层牌数字左", Vector3(0.10, 0.18, 0.025), base + Vector3(-0.18, 2.60, -0.61), Color("d8b36f"), 0.30, 0.0, Color("d8b36f"), 0.56)
	_add_box("状态电梯楼层牌数字右", Vector3(0.10, 0.18, 0.025), base + Vector3(0.18, 2.60, -0.61), Color("d8b36f"), 0.30, 0.0, Color("d8b36f"), 0.56)
	_add_box("状态电梯楼层牌边框", Vector3(1.24, 0.05, 0.08), base + Vector3(0.0, 2.78, -0.57), Color("8b8074"), 0.34, 0.0, Color("c9b48d"), 0.22)
	_add_box("状态电梯中央导视牌底板", Vector3(1.42, 0.76, 0.055), base + Vector3(0.0, 1.92, -0.60), Color("77706d"), 0.72, 0.02)
	_add_box("状态电梯中央导视牌标题条", Vector3(1.04, 0.075, 0.026), base + Vector3(0.0, 2.23, -0.635), Color("eee3d0"), 0.42, 0.0, Color("eee3d0"), 0.18)
	_add_box("状态电梯中央导视牌楼层字块-08", Vector3(0.28, 0.055, 0.026), base + Vector3(-0.42, 2.08, -0.635), Color("e7dcc9"), 0.48, 0.0)
	_add_box("状态电梯中央导视牌楼层字块-10", Vector3(0.34, 0.055, 0.026), base + Vector3(0.02, 2.08, -0.635), Color("e7dcc9"), 0.48, 0.0)
	_add_box("状态电梯中央导视牌楼层字块-12", Vector3(0.34, 0.055, 0.026), base + Vector3(0.42, 2.08, -0.635), Color("e7dcc9"), 0.48, 0.0)
	_add_box("状态电梯中央导视牌分隔线-00", Vector3(1.06, 0.018, 0.024), base + Vector3(0.0, 1.98, -0.638), Color("d9cdbd"), 0.52, 0.0)
	_add_box("状态电梯中央导视牌分隔线-01", Vector3(1.06, 0.018, 0.024), base + Vector3(0.0, 1.84, -0.638), Color("d9cdbd"), 0.52, 0.0)
	_add_box("状态电梯中央导视牌平面图边框", Vector3(0.88, 0.22, 0.026), base + Vector3(0.0, 1.64, -0.638), Color("d9cdbd"), 0.52, 0.0)
	_add_box("状态电梯中央导视牌平面图横线", Vector3(0.70, 0.018, 0.028), base + Vector3(0.0, 1.64, -0.654), Color("eee3d0"), 0.46, 0.0)
	_add_box("状态电梯中央导视牌平面图竖线", Vector3(0.018, 0.16, 0.028), base + Vector3(0.12, 1.64, -0.654), Color("eee3d0"), 0.46, 0.0)
	_add_box("状态电梯中央导视牌上行箭头", Vector3(0.06, 0.14, 0.026), base + Vector3(0.58, 1.98, -0.642), Color("eee3d0"), 0.42, 0.0, Color("eee3d0"), 0.16)
	_add_box("状态电梯中央导视牌下行箭头", Vector3(0.06, 0.14, 0.026), base + Vector3(0.58, 1.80, -0.642), Color("eee3d0"), 0.42, 0.0, Color("eee3d0"), 0.16)
	_add_box("状态电梯呼叫面板边框", Vector3(0.30, 0.62, 0.035), base + Vector3(1.84, 1.18, -0.585), Color("8b8074"), 0.34, 0.0, Color("bda77e"), 0.20)
	_add_box("状态电梯呼叫面板上键", Vector3(0.08, 0.08, 0.026), base + Vector3(1.84, 1.38, -0.628), Color("d8b36f"), 0.34, 0.0, Color("d8b36f"), 0.32)
	_add_box("状态电梯呼叫面板下键", Vector3(0.08, 0.08, 0.026), base + Vector3(1.84, 1.00, -0.628), Color("d8b36f"), 0.34, 0.0, Color("d8b36f"), 0.32)
	_add_box("状态电梯左门亮边", Vector3(0.035, 2.26, 0.025), base + Vector3(-1.50, 1.25, -0.59), Color("9e9c98"), 0.30, 0.0, Color("c9b48d"), 0.20)
	_add_box("状态电梯右门亮边", Vector3(0.035, 2.26, 0.025), base + Vector3(1.50, 1.25, -0.59), Color("9e9c98"), 0.30, 0.0, Color("c9b48d"), 0.20)
	_add_box("状态电梯厅引导盲道", Vector3(0.36, 0.028, 2.50), base + Vector3(0.0, 0.145, 1.72), Color("706b64"), 0.58, 0.0, Color("b09a78"), 0.18)
	_add_box("状态电梯厅引导盲道横纹", Vector3(0.44, 0.032, 0.045), base + Vector3(0.0, 0.165, 1.10), Color("c6a46d"), 0.34, 0.0, Color("e0c58e"), 0.22)
	_add_box("状态电梯厅引导牌", Vector3(0.06, 0.64, 0.22), base + Vector3(-2.18, 1.30, 0.94), Color("395b59"), 0.42, 0.0, Color("71b39a"), 0.28)
	_add_box("状态电梯门厅顶梁", Vector3(4.70, 0.12, 0.18), base + Vector3(0.0, 2.84, -0.30), Color("7d7269"), 0.42, 0.14)
	_add_light("状态电梯呼叫反馈光", base + Vector3(1.84, 1.18, -0.66), Color("e8b84a") if active_call else Color("c9a96f"), 0.10 if active_call else 0.04, 1.4)
	_add_box("状态电梯地面压线", Vector3(4.6, 0.025, 0.06), base + Vector3(0.0, 0.13, 0.78), Color("c29a63"), 0.46, 0.0, Color("c29a63"), 0.20)
	_add_box("状态电梯左侧墙灯", Vector3(0.05, 0.82, 0.22), base + Vector3(-2.18, 1.78, -0.32), Color("e1b875"), 0.40, 0.0, Color("e1b875"), 0.44)
	_add_box("状态电梯右侧墙灯", Vector3(0.05, 0.82, 0.22), base + Vector3(2.18, 1.78, -0.32), Color("e1b875"), 0.40, 0.0, Color("e1b875"), 0.44)
	_add_box("状态电梯门槛左", Vector3(1.45, 0.06, 0.12), base + Vector3(-0.78, 0.12, -0.68), Color("9e8c78"), 0.42, 0.18)
	_add_box("状态电梯门槛右", Vector3(1.45, 0.06, 0.12), base + Vector3(0.78, 0.12, -0.68), Color("9e8c78"), 0.42, 0.18)
	_add_box("状态电梯厅侧墙", Vector3(0.14, 2.84, 3.20), base + Vector3(-2.48, 1.42, 0.52), Color("424c55"), 0.80, 0.12)
	_add_box("状态电梯左门门套", Vector3(0.10, 2.48, 0.16), base + Vector3(-1.58, 1.30, -0.48), Color("6b6b68"), 0.44, 0.10, Color("c9b48d"), 0.18)
	_add_box("状态电梯右门门套", Vector3(0.10, 2.48, 0.16), base + Vector3(1.58, 1.30, -0.48), Color("6b6b68"), 0.44, 0.10, Color("c9b48d"), 0.18)
	_add_box("状态电梯左门反射带", Vector3(0.10, 1.78, 0.025), base + Vector3(-1.02, 1.22, -0.60), Color("70767a"), 0.28, 0.0, Color("d6cbb9"), 0.14)
	_add_box("状态电梯右门反射带", Vector3(0.10, 1.78, 0.025), base + Vector3(1.02, 1.22, -0.60), Color("70767a"), 0.28, 0.0, Color("d6cbb9"), 0.14)
	_add_box("状态电梯门厅中轴地牌", Vector3(0.62, 0.025, 0.32), base + Vector3(0.0, 0.18, 0.62), Color("8d8174"), 0.42, 0.0, Color("d7bc8d"), 0.20)
	_add_box("状态电梯门厅中轴地牌内框", Vector3(0.42, 0.030, 0.18), base + Vector3(0.0, 0.20, 0.62), Color("d8c8af"), 0.34, 0.0)
	_add_box("状态电梯厅地砖横缝-00", Vector3(4.34, 0.022, 0.035), base + Vector3(0.0, 0.14, 1.32), Color("a49a8f"), 0.32, 0.0)
	_add_box("状态电梯厅地砖横缝-01", Vector3(4.34, 0.022, 0.035), base + Vector3(0.0, 0.14, 2.02), Color("a49a8f"), 0.28, 0.0)
	_add_box("状态电梯厅地砖竖缝-00", Vector3(0.035, 0.024, 2.30), base + Vector3(-1.38, 0.145, 0.82), Color("aaa097"), 0.24, 0.0)
	_add_box("状态电梯厅地砖竖缝-01", Vector3(0.035, 0.024, 2.30), base + Vector3(1.38, 0.145, 0.82), Color("aaa097"), 0.24, 0.0)
	_add_box("状态电梯门厅顶棚灯带-00", Vector3(1.34, 0.035, 0.08), base + Vector3(-1.18, 2.82, 0.20), Color("d3c6b5"), 0.30, 0.0, Color("ffe5bd"), 0.52)
	_add_box("状态电梯门厅顶棚灯带-01", Vector3(1.34, 0.035, 0.08), base + Vector3(1.18, 2.82, 0.20), Color("d3c6b5"), 0.30, 0.0, Color("ffe5bd"), 0.52)
	_add_box("状态电梯中央导视牌左框", Vector3(0.045, 0.72, 0.028), base + Vector3(-0.72, 1.92, -0.646), Color("d9cdbd"), 0.40, 0.0, Color("eee3d0"), 0.18)
	_add_box("状态电梯中央导视牌右框", Vector3(0.045, 0.72, 0.028), base + Vector3(0.72, 1.92, -0.646), Color("d9cdbd"), 0.40, 0.0, Color("eee3d0"), 0.18)
	_add_light("状态电梯顶灯", base + Vector3(0.0, 2.70, -0.20), Color("ffe2bc"), 0.28, 3.8)
	set_meta("visual_state_contract", {"state": "office-06" if active_call else "office-05", "required_layers": ["elevator_doors", "floor_indicator", "call_panel", "warm_light"], "call_active": active_call})

func _build_stair_state() -> void:
	var base := Vector3(7.0, 0.0, -6.0)
	for index in range(8):
		_add_box("状态07楼梯台阶-%02d" % index, Vector3(2.40, 0.16, 0.48), base + Vector3(0.0, 0.10 + index * 0.18, -0.34 - index * 0.48), Color("3d4b5c"), 0.88)
		_add_box("状态07楼梯台阶反光边-%02d" % index, Vector3(2.28, 0.035, 0.045), base + Vector3(0.0, 0.20 + index * 0.18, -0.58 - index * 0.48), Color("cfa765"), 0.40, 0.0, Color("cfa765"), 0.20)
	for side in [-1.0, 1.0]:
		_add_box("状态07楼梯侧墙", Vector3(0.12, 2.70, 4.80), base + Vector3(side * 1.28, 1.28, -2.28), Color("252d38"), 0.92)
		_add_box("状态07楼梯扶手", Vector3(0.08, 0.08, 4.50), base + Vector3(side * 1.06, 1.62, -2.30), Color("b6a894"), 0.44, 0.18)
		_add_box("状态07楼梯扶手端盖-%s" % ("左" if side < 0.0 else "右"), Vector3(0.16, 0.12, 0.16), base + Vector3(side * 1.06, 1.62, -4.56), Color("d2b37e"), 0.42, 0.16)
		_add_box("状态07楼梯墙面导视", Vector3(0.04, 0.36, 0.88), base + Vector3(side * 1.20, 2.14, -1.40), Color("d0a66e"), 0.48, 0.0, Color("d0a66e"), 0.22)
	_add_box("状态07应急灯", Vector3(0.62, 0.12, 0.05), base + Vector3(0.0, 2.26, -4.55), Color("d86a58"), 0.36, 0.0, Color("d86a58"), 0.55)
	_add_box("状态07失败反馈边框", Vector3(2.46, 0.05, 0.06), base + Vector3(0.0, 2.02, -4.55), Color("b72e3c"), 0.34, 0.0, Color("b72e3c"), 0.42)
	_add_box("状态07楼梯平台", Vector3(2.65, 0.08, 1.05), base + Vector3(0.0, 1.54, -4.92), Color("495662"), 0.84)
	_add_box("状态07平台警示牌", Vector3(0.68, 0.34, 0.045), base + Vector3(0.0, 1.98, -4.96), Color("c64c4b"), 0.38, 0.0, Color("e16b58"), 0.34)
	_add_box("状态07平台门缝", Vector3(2.10, 1.92, 0.05), base + Vector3(0.0, 2.42, -5.32), Color("1f2a31"), 0.36, 0.24)
	_add_box("状态07楼梯入口门框左", Vector3(0.10, 2.08, 0.12), base + Vector3(-1.18, 1.18, -0.12), Color("77716c"), 0.46, 0.10, Color("d0a66e"), 0.16)
	_add_box("状态07楼梯入口门框右", Vector3(0.10, 2.08, 0.12), base + Vector3(1.18, 1.18, -0.12), Color("77716c"), 0.46, 0.10, Color("d0a66e"), 0.16)
	_add_box("状态07楼梯入口门楣", Vector3(2.46, 0.10, 0.12), base + Vector3(0.0, 2.18, -0.12), Color("77716c"), 0.46, 0.10, Color("d0a66e"), 0.16)
	_add_box("状态07楼梯扶手立柱左", Vector3(0.10, 0.82, 0.10), base + Vector3(-1.06, 1.22, -1.02), Color("8d857a"), 0.38, 0.12, Color("d5b47d"), 0.18)
	_add_box("状态07楼梯扶手立柱右", Vector3(0.10, 0.82, 0.10), base + Vector3(1.06, 1.22, -1.02), Color("8d857a"), 0.38, 0.12, Color("d5b47d"), 0.18)
	_add_box("状态07楼梯墙面灯带", Vector3(0.035, 1.26, 0.10), base + Vector3(-1.20, 1.56, -2.18), Color("c7a36d"), 0.34, 0.0, Color("e8c98e"), 0.28)
	_add_box("状态07楼梯平台地缝", Vector3(2.40, 0.025, 0.04), base + Vector3(0.0, 1.60, -4.42), Color("9a8f84"), 0.28, 0.0)
	_add_box("状态07楼梯顶棚暗面", Vector3(2.42, 0.08, 1.40), base + Vector3(0.0, 2.68, -1.18), Color("1d2731"), 0.80, 0.10)
	_add_light("状态07应急暖光", base + Vector3(0.0, 2.05, -3.80), Color("d86a58"), 0.16, 3.0)
	set_meta("visual_state_contract", {"state": "office-07", "required_layers": ["stairs", "rails", "emergency_light", "door_frame", "ceiling_shadow", "landing_detail"]})

func _build_dialogue_state(state_id: String) -> void:
	var base := Vector3(8.2, 0.0, -5.70)
	_add_box("状态对话走廊左墙", Vector3(0.16, 2.85, 4.80), base + Vector3(-1.70, 1.42, -0.55), Color("373d45"), 0.84, 0.16)
	_add_box("状态对话走廊右墙", Vector3(0.16, 2.85, 4.80), base + Vector3(2.40, 1.42, -0.55), Color("373d45"), 0.84, 0.16)
	_add_box("状态对话走廊地面", Vector3(4.20, 0.028, 4.80), base + Vector3(0.35, 0.13, -0.55), Color("5b514d"), 0.90)
	_add_box("状态对话暖色窗带", Vector3(0.04, 1.62, 2.40), base + Vector3(2.31, 2.30, -0.55), Color("6e8790"), 0.30, 0.04, Color("d59b54"), 0.16)
	_add_box("状态对话门牌", Vector3(0.06, 0.34, 0.86), base + Vector3(-1.48, 1.92, -2.90), Color("a98967"), 0.54, 0.04)
	_add_box("状态对话字幕锚点", Vector3(2.20, 0.08, 0.04), base + Vector3(0.35, 1.48, -2.84), Color("d9c19a"), 0.72, 0.0, Color("d9c19a"), 0.18)
	_add_box("状态对话门边警示灯", Vector3(0.08, 0.32, 0.05), base + Vector3(2.16, 1.70, -2.78), Color("cf4c4d"), 0.34, 0.0, Color("cf4c4d"), 0.46)
	_add_box("状态对话天花灯带", Vector3(3.80, 0.04, 0.10), base + Vector3(0.35, 2.78, -0.55), Color("e6d9be"), 0.30, 0.0, Color("fff0c7"), 0.42)
	_add_box("状态对话墙面画框", Vector3(0.04, 0.72, 0.92), base + Vector3(-1.60, 1.72, -0.50), Color("9d8066"), 0.52, 0.06)
	_add_box("状态对话门牌边框", Vector3(0.08, 0.42, 0.96), base + Vector3(-1.43, 1.92, -2.94), Color("c4a77b"), 0.40, 0.02, Color("e0c592"), 0.16)
	_add_box("状态对话窗格横档", Vector3(0.045, 0.05, 2.25), base + Vector3(2.26, 2.30, -0.55), Color("b8a185"), 0.32, 0.0, Color("e1c083"), 0.18)
	_add_box("状态对话窗格竖档", Vector3(0.045, 1.52, 0.05), base + Vector3(2.26, 2.30, -0.55), Color("b8a185"), 0.32, 0.0, Color("e1c083"), 0.18)
	_add_box("状态对话左墙踢脚线", Vector3(0.08, 0.18, 4.55), base + Vector3(-1.48, 0.32, -0.55), Color("8e7765"), 0.54, 0.08)
	_add_box("状态对话右墙踢脚线", Vector3(0.08, 0.18, 4.55), base + Vector3(2.18, 0.32, -0.55), Color("8e7765"), 0.54, 0.08)
	_add_box("状态对话墙面终端", Vector3(0.10, 0.58, 0.46), base + Vector3(-1.45, 1.12, -1.00), Color("27363a"), 0.34, 0.12)
	_add_box("状态对话墙面终端屏", Vector3(0.035, 0.24, 0.26), base + Vector3(-1.39, 1.20, -1.25), Color("d0a85f"), 0.28, 0.0, Color("e5c277"), 0.42)
	_add_box("状态对话地面导向条", Vector3(0.08, 0.03, 3.65), base + Vector3(0.35, 0.16, -0.55), Color("a98760"), 0.36, 0.0, Color("d6b47a"), 0.22)
	_add_box("状态对话天花检修板", Vector3(1.10, 0.035, 0.72), base + Vector3(-0.55, 2.74, -0.55), Color("8e8d88"), 0.40, 0.0, Color("c8b999"), 0.18)
	_add_box("状态对话窗下沿", Vector3(2.48, 0.10, 0.10), base + Vector3(2.31, 1.46, -0.55), Color("78675b"), 0.46, 0.04, Color("d7a366"), 0.16)
	_add_box("状态对话窗框左", Vector3(0.06, 1.72, 0.08), base + Vector3(1.18, 2.30, -0.55), Color("b8a185"), 0.42, 0.05, Color("e1c083"), 0.16)
	_add_box("状态对话窗框右", Vector3(0.06, 1.72, 0.08), base + Vector3(3.44, 2.30, -0.55), Color("b8a185"), 0.42, 0.05, Color("e1c083"), 0.16)
	_add_box("状态对话墙面竖分格", Vector3(0.035, 2.20, 0.05), base + Vector3(-0.72, 1.46, -0.50), Color("6f625b"), 0.34, 0.0)
	_add_box("状态对话地砖横缝-00", Vector3(3.78, 0.022, 0.035), base + Vector3(0.35, 0.145, -1.30), Color("88776b"), 0.30, 0.0)
	_add_box("状态对话地砖横缝-01", Vector3(3.78, 0.022, 0.035), base + Vector3(0.35, 0.145, -2.18), Color("88776b"), 0.30, 0.0)
	_add_box("状态对话交谈站位光带", Vector3(1.32, 0.025, 0.05), base + Vector3(0.92, 0.17, -1.72), Color("b79a70"), 0.36, 0.0, Color("e0bd82"), 0.18)
	var alert_color := Color("b72e3c") if state_id == "office-08" else Color("d45157")
	_add_box("状态对话警觉上沿", Vector3(4.10, 0.045, 0.08), base + Vector3(0.35, 2.82, -2.90), alert_color, 0.34, 0.0, alert_color, 0.60)
	_add_box("状态对话警觉地线", Vector3(4.10, 0.025, 0.06), base + Vector3(0.35, 0.15, -2.90), alert_color, 0.34, 0.0, alert_color, 0.30)
	_add_light("状态对话警觉光", base + Vector3(0.35, 2.35, -1.75), alert_color, 0.16, 4.0)
	set_meta("visual_state_contract", {"state": state_id, "required_layers": ["corridor", "window_band", "alert_edge", "dialogue_light", "window_frame", "floor_detail", "conversation_staging"]})

func _add_state_backdrop() -> void:
	## 将原创环境稿作为当前状态的远景层接入；它不替代三维碰撞、导航、角色、
	## 任务或交互，只负责把状态从灰盒空间提升为可读的办公室场景。
	var texture_path := str(STATE_BACKDROP_PATHS.get(active_state, ""))
	if texture_path.is_empty():
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var backdrop := MeshInstance3D.new()
	backdrop.name = "状态%s原创环境稿" % active_state
	var mesh := QuadMesh.new()
	var backdrop_size := Vector2(12.0, 4.0)
	var backdrop_position := Vector3(0.0, 2.05, -8.80)
	match active_state:
		"office-02":
			backdrop_size = Vector2(10.8, 4.2)
			backdrop_position = Vector3(0.0, 2.08, -7.80)
		"office-05", "office-06":
			backdrop_size = Vector2(6.2, 4.0)
			backdrop_position = Vector3(7.0, 1.92, -8.15)
		"office-07":
			backdrop_size = Vector2(7.0, 4.2)
			backdrop_position = Vector3(7.0, 2.02, -8.10)
		"office-03", "office-04", "office-08", "office-09":
			backdrop_size = Vector2(9.2, 4.0)
			backdrop_position = Vector3(8.2, 2.02, -8.25)
	mesh.size = backdrop_size
	backdrop.mesh = mesh
	backdrop.position = backdrop_position
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.82
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.render_priority = -10
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	backdrop.set_meta("visual_only", true)
	backdrop.set_meta("candidate_visual_only", true)
	backdrop.set_meta("visual_candidate", true)
	backdrop.set_meta("original_procedural_asset", true)
	backdrop.set_meta("asset_source", "project_original_generated_environment_draft")
	backdrop.set_meta("office_scene_state", active_state)
	backdrop.set_meta("backdrop_texture_path", texture_path)
	state_root.add_child(backdrop)

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color, roughness := 0.82, metallic := 0.0, emission := Color(0.0, 0.0, 0.0, 0.0), emission_energy := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	node.material_override = material
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	node.set_meta("original_procedural_asset", true)
	node.set_meta("office_scene_state", active_state)
	state_root.add_child(node)
	return node

func _add_light(node_name: String, at: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	light.set_meta("visual_only", true)
	light.set_meta("candidate_visual_only", true)
	light.set_meta("original_procedural_asset", true)
	light.set_meta("office_scene_state", active_state)
	state_root.add_child(light)
	return light

func _add_plant(at: Vector3) -> void:
	var plant := Node3D.new()
	plant.name = "状态办公室绿植"
	plant.position = at
	plant.set_meta("visual_only", true)
	plant.set_meta("candidate_visual_only", true)
	plant.set_meta("original_procedural_asset", true)
	state_root.add_child(plant)
	var pot := _make_primitive_box("状态办公室绿植花盆", Vector3(0.42, 0.38, 0.42), Vector3(0.0, 0.19, 0.0), Color("6f5547"), 0.78)
	plant.add_child(pot)
	for index in range(5):
		var leaf := MeshInstance3D.new()
		leaf.name = "状态办公室绿植叶片-%02d" % index
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.17
		leaf_mesh.height = 0.58
		leaf_mesh.radial_segments = 16
		leaf_mesh.rings = 8
		leaf.mesh = leaf_mesh
		leaf.scale = Vector3(0.72, 1.0, 0.24)
		leaf.position = Vector3((float(index) - 2.0) * 0.11, 0.62 + float(index % 2) * 0.10, 0.0)
		leaf.rotation_degrees = Vector3(0.0, float(index) * 28.0, (float(index) - 2.0) * 12.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("4c7658").lightened(float(index) * 0.025)
		material.roughness = 0.82
		leaf.material_override = material
		leaf.set_meta("visual_only", true)
		leaf.set_meta("candidate_visual_only", true)
		leaf.set_meta("original_procedural_asset", true)
		plant.add_child(leaf)

func _make_primitive_box(node_name: String, size: Vector3, at: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	node.material_override = material
	node.set_meta("visual_only", true)
	node.set_meta("candidate_visual_only", true)
	node.set_meta("original_procedural_asset", true)
	return node

extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	if not city.initialized:
		_fail("城市任务在交互道具候选覆盖下没有完成初始化")
		return
	var props_root := city.get_node_or_null("交互道具层/Visual")
	if props_root == null:
		_fail("城市没有挂载交互道具候选 Visual 根节点")
		return
	for required_group in ["EggTray_Interaction", "ScanBoard_Interaction", "DeliveryMarker_Interaction", "ShopBasket_Interaction"]:
		if props_root.find_child(required_group, true, false) == null:
			_fail("交互道具候选缺少表现分组：%s" % required_group)
			return
	if city.get_node_or_null("交互道具层/交互道具灰盒回退") != null:
		_fail("交互道具候选挂载后仍保留灰盒回退")
		return
	if city.mission.current_stage().get("id") != "collect_eggs":
		_fail("交互道具候选覆盖后城市初始任务阶段错误")
		return
	var target = city.targets[0]
	city.player.position = target.position + Vector3(0.0, 0.0, 1.0)
	city.process_input_frame(InputFrameClass.new(), 0.016)
	if city.prompt_label.text != "E  " + target.prompt:
		_fail("交互道具候选覆盖后没有保留鸡蛋目标提示")
		return
	var interact_frame := InputFrameClass.new()
	interact_frame.interact = true
	city.process_input_frame(interact_frame, 0.016)
	if not city.inventory.has_item("egg_tray") or city.mission.current_stage().get("id") != "leave_store":
		_fail("交互道具候选覆盖后鸡蛋交互没有推进库存和任务阶段")
		return
	if city.camera_rig == null or city.player == null or city.mission == null:
		_fail("交互道具候选覆盖破坏了角色、镜头或任务运行时")
		return
	print("交互道具候选已接入隔离城市真实运行时：Visual、任务提示、库存交互、镜头和任务状态保持完整")
	city.free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

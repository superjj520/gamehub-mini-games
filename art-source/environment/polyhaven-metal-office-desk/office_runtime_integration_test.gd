extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var office = OfficeScene.instantiate()
	office.set_meta("asset_catalog_path", "res://asset-runtime-catalog-office-desk-override.json")
	office.set_meta("settings_path", OS.get_temp_dir().path_join("office-desk-runtime-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(office)
	for _frame in range(5):
		await process_frame
	assert(office.initialized, "办公室候选运行时没有初始化")
	var visual_parent := office.get_node_or_null("Visual")
	assert(visual_parent != null, "办公室环境候选 Visual 未挂载到运行时")
	assert(visual_parent.get_node_or_null("近似碰撞体") != null, "办公室运行时没有挂载桌面碰撞体")
	assert(visual_parent.get_node_or_null("交互挂点") != null, "办公室运行时没有挂载桌面交互挂点")
	assert(visual_parent.get_node_or_null("显示器挂点") != null, "办公室运行时没有挂载桌面显示器挂点")
	assert(office.get_node_or_null("Visual/Visual") == null, "候选挂载产生了重复 Visual 层")
	office.prepare_reference_capture(false)
	await process_frame
	assert(office.camera_rig != null, "候选挂载破坏办公室第三人称镜头")
	assert(office.npc != null, "候选挂载破坏办公室 NPC")
	assert(office.mission != null, "候选挂载破坏办公室任务状态机")
	print("Poly Haven 办公桌候选接入办公室真实运行时通过：任务、NPC、镜头、碰撞和挂点保持完整")
	office.free()
	await process_frame
	quit(0)

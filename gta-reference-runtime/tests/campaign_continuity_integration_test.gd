extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const MissionStateClass = preload("res://scripts/mission_state.gd")
const MissionChainClass = preload("res://scripts/mission_chain.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var campaign = root.get_node_or_null("CampaignState")
	assert(campaign != null, "战役连续状态没有注册为自动加载单例")
	var state_path := OS.get_temp_dir().path_join("新时代觉醒者-campaign-continuity-%d.json" % Time.get_ticks_usec())
	campaign.configure_path(state_path)
	assert(campaign.reset(), "战役连续状态测试无法清理初始状态")
	assert(not campaign.is_city_unlocked(), "新战役不应提前解锁城市")
	var office = OfficeScene.instantiate()
	office.set_meta("save_path", state_path + ".office.json")
	get_root().add_child(office)
	await process_frame
	assert(office.initialized, "办公室场景没有完成初始化")
	assert(campaign.last_scene == "office", "办公室场景启动没有写入战役位置")
	office.mission.clock_minutes = office.mission.completion_minute
	assert(office.mission.complete(), "办公室任务没有通过真实任务状态机完成")
	assert(office.mission.status == MissionStateClass.Status.SUCCESS, "办公室任务状态机没有进入成功")
	assert(office.trace.has_event("campaign_office_completed"), "办公室成功回调没有记录战役完成事件")
	assert(FileAccess.file_exists(state_path), "办公室成功回调没有写入战役状态文件")
	assert(campaign.office_completed, "办公室完成状态没有写入内存")
	assert(campaign.is_city_unlocked(), "完成办公室后没有解锁城市")
	office.queue_free()
	await process_frame
	campaign.load_state()
	assert(campaign.office_completed and campaign.is_city_unlocked(), "重新加载后办公室完成与城市解锁状态丢失")

	OS.set_environment("REFERENCE_ASSET_PREVIEW", "1")
	var launcher = load("res://scenes/launcher.tscn").instantiate()
	launcher.set_meta("office_checkpoint_path", state_path + ".office.json")
	launcher.set_meta("city_checkpoint_path", state_path + ".city.json")
	root.add_child(launcher)
	await process_frame
	var city_button: Button = null
	for button in launcher.find_children("*", "Button", true, false):
		if str(button.text).contains("城市扩展"):
			city_button = button
			break
	assert(city_button != null, "启动器没有显示内部城市扩展入口")
	assert(not city_button.disabled, "办公室完成后城市扩展入口仍被锁定")
	launcher.queue_free()
	await process_frame

	var city = CityScene.instantiate()
	city.set_meta("save_path", state_path + ".city.json")
	get_root().add_child(city)
	await process_frame
	assert(city.initialized, "城市场景没有完成初始化")
	assert(campaign.last_scene == "city", "城市场景启动没有写入战役位置")
	while city.mission.status == MissionChainClass.Status.ACTIVE:
		assert(city.mission.complete_current(), "城市任务链阶段无法通过真实状态机完成")
	assert(city.mission.status == MissionChainClass.Status.SUCCESS, "城市任务链没有进入成功")
	assert(city.trace.has_event("campaign_city_completed"), "城市成功回调没有记录战役完成事件")
	assert(FileAccess.file_exists(state_path), "城市成功回调没有保留战役状态文件")
	city.queue_free()
	await process_frame
	campaign.load_state()
	assert(campaign.city_completed, "重新加载后城市完成状态丢失")
	assert(campaign.money == 260 and campaign.stars == 5, "城市完成奖励没有跨场景保存")
	OS.set_environment("REFERENCE_ASSET_PREVIEW", "")
	campaign.reset()
	print("办公室→城市战役连续状态集成测试通过")
	quit(0)

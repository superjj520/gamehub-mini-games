extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")
const ConflictStateClass = preload("res://scripts/conflict_state.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	city.set_meta("save_path", OS.get_temp_dir().path_join("新时代觉醒者-fun-loop-%d.json" % Time.get_ticks_usec()))
	get_root().add_child(city)
	await process_frame

	assert(city.initialized, "试玩回路城市没有完成初始化")
	assert(city.mission.current_stage().get("id", "") == "collect_eggs", "试玩回路没有从领取鸡蛋开始")

	# 玩家完成第一个动作后必须看到明确的下一目标，而不是只改变内部整数状态。
	city.player.position = city.targets[0].position + Vector3(0.0, 0.0, 1.0)
	var collect := InputFrameClass.new()
	collect.interact = true
	city.process_input_frame(collect, 0.016)
	assert(city.mission.current_stage().get("id", "") == "leave_store", "试玩回路领取鸡蛋后没有推进到离店")
	assert(city.conflict_encounter_armed, "领取鸡蛋后没有在离店流程中布置冲突遭遇")
	assert(str(city.hud_visual.get("announcement_text")).contains("离开商店"), "任务推进没有给出即时反馈横幅")
	assert(float(city.hud_visual.get("feedback_timer")) > 0.0, "任务推进没有给出即时边缘反馈")

	# 离店遭遇属于任务世界状态，读档后仍必须存在，不能只在首次运行时出现。
	city._save_city_checkpoint()
	city.conflict_encounter_armed = false
	city.conflict_agent.position = Vector3(4.0, 0.9, -2.0)
	city._load_city_checkpoint()
	assert(city.conflict_encounter_armed, "读取城市存档后没有恢复离店冲突遭遇")
	assert(city.conflict_agent.global_position.distance_to(city.targets[1].global_position) < 3.0, "读取城市存档后冲突对象没有恢复到离店出口")

	# 冲突必须形成可理解的闭环：触发、追踪、拉开距离、恢复并得到奖励。
	city.conflict_agent.position = city.player.position + Vector3(1.0, 0.0, 0.0)
	var attack := InputFrameClass.new()
	attack.attack = true
	city.process_input_frame(attack, 0.016)
	assert(city.conflict.status == ConflictStateClass.Status.PURSUED, "冲突触发后没有进入追踪状态")
	assert(not city.conflict_encounter_armed, "冲突触发后遭遇状态没有关闭")
	assert(str(city.hud_visual.get("announcement_text")).contains("冲突升级"), "冲突开始没有给出即时反馈横幅")
	assert(float(city.hud_visual.get("feedback_timer")) > 0.0, "冲突开始没有给出即时边缘反馈")

	city.player.position = Vector3(20.0, 1.0, 20.0)
	for index in range(3):
		city.process_input_frame(InputFrameClass.new(), 0.5)
	assert(city.conflict.status == ConflictStateClass.Status.CALM, "玩家拉开距离后没有结束追踪")
	assert(city.mission.money == 50, "甩开追踪没有结算 20 元奖励")
	assert(city.trace.has_event("conflict_escaped"), "试玩回路没有记录甩开追踪事件")
	assert(str(city.hud_visual.get("announcement_text")).contains("成功甩开追踪"), "甩开追踪没有给出成功反馈横幅")
	assert(float(city.hud_visual.get("feedback_timer")) > 0.0, "甩开追踪没有给出成功边缘反馈")

	print("城市好玩回路集成测试通过：领取 -> 冲突 -> 逃脱 -> 奖励")
	city.queue_free()
	quit()

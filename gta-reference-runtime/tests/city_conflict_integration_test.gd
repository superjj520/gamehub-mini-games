extends SceneTree

const InputFrameClass = preload("res://scripts/input_frame.gd")
const CityScene = preload("res://scenes/city.tscn")
const MissionChainClass = preload("res://scripts/mission_chain.gd")
const ConflictStateClass = preload("res://scripts/conflict_state.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city = CityScene.instantiate()
	get_root().add_child(city)
	await process_frame
	assert(is_equal_approx(city.conflict.max_health, 100.0), "冲突生命上限没有从内容包读取")
	assert(is_equal_approx(city.conflict.damage_per_second, 10.0), "冲突伤害参数没有从内容包读取")
	assert(is_equal_approx(city.conflict_pursuit_speed, 1.8), "冲突追踪速度没有从内容包读取")
	assert(is_equal_approx(city.conflict_trigger_radius, 2.4), "冲突触发半径没有从内容包读取")
	assert(is_equal_approx(city.conflict_damage_radius, 1.35), "冲突伤害半径没有从内容包读取")
	assert(is_equal_approx(city.conflict_dodge_window_seconds, 0.42), "闪避窗口没有从内容包读取")
	assert(is_equal_approx(city.conflict_dodge_cooldown_seconds, 0.70), "闪避冷却没有从内容包读取")
	assert(city.wanted.max_level == 5, "通缉状态上限没有从内容包读取")
	assert(is_equal_approx(city.wanted.decay_delay_seconds, 8.0), "通缉状态衰减延迟没有从内容包读取")

	city.player.position = city.conflict_agent.position + Vector3(0.0, 0.0, 1.0)
	var attack_frame = InputFrameClass.new()
	attack_frame.attack = true
	city.process_input_frame(attack_frame, 0.016)
	assert(city.conflict.status == ConflictStateClass.Status.PURSUED, "攻击后没有进入追踪状态")
	assert(city.wanted.level == 2, "冲突没有提升通缉等级")
	assert(city.trace.has_event("wanted_level"), "通缉等级变化没有写入回放时间轴")
	assert(str(city.hud_visual.get("announcement_text")).contains("通缉升级"), "通缉升级没有给出明确的即时横幅")
	assert(float(city.hud_visual.get("feedback_timer")) > 0.0, "通缉升级没有给出即时边缘反馈")
	assert(float(city.camera_rig.get("feedback_duration")) > 0.0, "通缉升级没有给出相机反馈")
	assert(city.crowd_displaced, "冲突触发后入口人群没有被推开")
	assert(city.pedestrians.all(func(pedestrian): return pedestrian.displaced), "冲突触发后动态行人没有进入被推开状态")
	assert(city.trace.has_event("crowd_displaced"), "入口人群位移没有写入回放时间轴")
	# 闪避必须在对手贴身伤害窗口内生效，并且留下可审计的成功反馈。
	city.conflict_agent.position = city.player.position
	var dodge_health_before: float = city.conflict.health
	var dodge_frame := InputFrameClass.new()
	dodge_frame.dodge = true
	city.process_input_frame(dodge_frame, 0.016)
	assert(is_equal_approx(city.conflict.health, dodge_health_before), "闪避窗口内仍然受到冲突伤害")
	assert(city.player.presentation_snapshot()["state"] == city.player.PresentationState.DODGE, "闪避输入没有进入玩家闪避表现")
	assert(city.trace.has_event("conflict_dodge"), "闪避输入没有写入回放时间轴")
	assert(city.trace.has_event("conflict_dodge_success"), "闪避成功没有写入回放时间轴")
	city.process_input_frame(InputFrameClass.new(), 0.016)
	city.dodge_cooldown_timer = 0.0
	# GTA 类型冲突不能只有逃跑分支；验证玩家可以近身反击并获得另一条可玩结算路径。
	var combat_snapshot: Dictionary = city.conflict.snapshot()
	var combat_money: int = int(city.mission.money)
	for attack_index in range(3):
		city.process_input_frame(InputFrameClass.new(), 0.016)
		city.conflict_agent.position = city.player.position
		var counter_frame := InputFrameClass.new()
		counter_frame.attack = true
		city.process_input_frame(counter_frame, 0.016)
	assert(city.conflict.opponent_defeated, "三次近战反击后对手没有被击败：生命=%f 状态=%d" % [city.conflict.opponent_health, city.conflict.status])
	assert(city.conflict.status == ConflictStateClass.Status.CALM, "对手被击败后冲突没有结束")
	assert(not city.conflict_agent.visible, "对手被击败后仍留在城市中")
	assert(city.mission.money == combat_money + city.conflict_defeat_bonus, "击败冲突对象没有结算奖励")
	assert(city.trace.has_event("player_attack"), "玩家反击没有写入回放时间轴")
	assert(city.trace.has_event("conflict_defeated"), "冲突击败没有写入回放时间轴")
	city.mission.money = combat_money
	city.conflict.restore(combat_snapshot)
	city.conflict_agent.visible = true
	city.attack_lock = false
	city.wanted.decay_timer = city.wanted.decay_delay_seconds
	city.save_store.save_path = OS.get_temp_dir().path_join("reference-city-conflict-%d.json" % Time.get_ticks_usec())
	city._save_city_checkpoint()
	var saved_pedestrian_position: Vector3 = city.pedestrians[0].global_position
	var saved_blocker_position: Vector3 = city.crowd_blockers[0].global_position
	city._reset_crowd()
	city.player.position += Vector3(5.0, 0.0, 5.0)
	city._load_city_checkpoint()
	assert(city.wanted.level == 2, "读取冲突存档没有恢复通缉等级")
	assert(city.crowd_displaced, "读取冲突存档没有恢复入口人群位移状态")
	assert(city.pedestrians[0].displaced, "读取冲突存档没有恢复动态行人冻结状态")
	assert(city.pedestrians[0].global_position.distance_to(saved_pedestrian_position) < 0.001, "读取冲突存档没有恢复动态行人位置")
	assert(city.crowd_blockers[0].global_position.distance_to(saved_blocker_position) < 0.001, "读取冲突存档没有恢复入口人群位置")
	assert(city.crowd_blockers[0].get_node("人群碰撞体").disabled, "读取冲突存档没有恢复入口人群碰撞状态")
	city.wanted.tick(7.99, false)
	assert(city.wanted.level == 2, "冷静时间未达到延迟前不应降低通缉等级")
	city.wanted.tick(0.01, false)
	assert(city.wanted.level == 1, "冷静达到延迟后没有降低一级通缉")
	city.wanted.tick(3.99, false)
	assert(city.wanted.level == 1, "通缉衰减间隔未达到前不应继续降低")
	city.wanted.tick(0.01, false)
	assert(city.wanted.level == 0, "通缉未按衰减间隔归零")
	assert(str(city.hud_visual.get("announcement_text")).contains("通缉降级"), "通缉衰减没有给出明确的即时横幅")
	city.wanted.report(99, "上限回归")
	assert(city.wanted.level == 5, "通缉等级没有遵守内容包上限")
	city.wanted.tick(60.0, true)
	assert(city.wanted.level == 5, "威胁持续时通缉等级不应衰减")
	city.wanted.reset()
	assert(city.wanted.level == 0, "通缉回归后没有恢复到零级")
	var pursuit_event_count := 0
	for event in city.audio_events.history:
		if str(event.get("id", "")) == "conflict_status":
			pursuit_event_count += 1
	city.conflict.pursue()
	var repeated_pursuit_event_count := 0
	for event in city.audio_events.history:
		if str(event.get("id", "")) == "conflict_status":
			repeated_pursuit_event_count += 1
	assert(repeated_pursuit_event_count == pursuit_event_count, "重复进入追踪状态不应重复写入冲突事件")

	for index in range(10):
		city.player.position = city.conflict_agent.position
		city.process_input_frame(InputFrameClass.new(), 1.0)
	assert(city.conflict.status == ConflictStateClass.Status.FAILED, "生命耗尽后没有进入冲突失败")
	assert(city.mission.status == MissionChainClass.Status.FAILED, "冲突失败没有传递到任务")
	assert(city.player.presentation_snapshot()["state"] == city.player.PresentationState.FAIL, "冲突失败后玩家没有进入失败表现")
	assert(city.failure_overlay.visible, "城市任务失败后没有显示失败与重试覆盖层")

	var restart_frame = InputFrameClass.new()
	restart_frame.restart = true
	city.process_input_frame(restart_frame, 0.016)
	assert(city.conflict.status == ConflictStateClass.Status.CALM, "重试后冲突状态没有恢复")
	assert(city.wanted.level == 0, "重试后通缉等级没有清零")
	assert(city.mission.status == MissionChainClass.Status.ACTIVE, "重试后任务没有恢复")
	assert(not city.failure_overlay.visible, "城市重试后失败覆盖层没有隐藏")
	assert(not city.crowd_displaced, "重试后入口人群没有恢复原位")
	assert(city.pedestrians.all(func(pedestrian): return not pedestrian.displaced), "重试后动态行人没有恢复路线状态")
	assert(city.inventory.items.is_empty(), "重试后库存没有清空")
	assert(not city.registered, "重试后登记状态没有清空")
	assert(city.trace.has_event("crowd_reset"), "入口人群恢复没有写入回放时间轴")
	assert(city.trace.has_event("mission_restart"), "城市重试没有写入任务重启事件")
	assert(city.audio_events.history.any(func(event): return str(event.get("id", "")) == "mission_restart"), "城市重试没有发出音频事件")

	city.queue_free()
	await process_frame
	print("城市冲突端到端回放测试通过")
	quit(0)

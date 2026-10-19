extends SceneTree

const AudioEventRouterClass = preload("res://scripts/audio_event_router.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("REFERENCE_ASSET_CATALOG_PATH", "res://content/asset-runtime-catalog-original-only.json")
	var router := AudioEventRouterClass.new()
	get_root().add_child(router)
	await process_frame
	assert(router.audio_resource_catalog.size() == 14, "原创边界音频目录没有完整加载")
	for event_id in router.audio_resource_catalog:
		var entry: Dictionary = router.audio_resource_catalog[event_id]
		assert(str(entry.get("fallback_policy", "")) == "forbid", "原创边界音频事件允许灰盒回退：" + str(event_id))
		assert(not str(entry.get("stream_path", "")).is_empty(), "原创边界音频事件缺少实际 WAV：" + str(event_id))
	router.enabled = true
	router.audio_resource_catalog["missing_probe"] = {
		"stream_path": "res://assets/audio/generated/missing_probe.wav",
		"fallback_policy": "forbid",
	}
	router.emit_event("missing_probe")
	assert(router.history.size() == 1, "禁止回退的音频缺失事件没有保留事件历史")
	assert(router.active_players.is_empty(), "禁止回退的音频缺失事件错误创建了程序化播放器")
	router.free()
	OS.set_environment("REFERENCE_ASSET_CATALOG_PATH", "")
	var launch_context_router := AudioEventRouterClass.new()
	launch_context_router.configure_for_asset_catalog("res://content/asset-runtime-catalog-original-only.json")
	get_root().add_child(launch_context_router)
	await process_frame
	assert(launch_context_router.audio_resource_catalog.size() == 14, "启动上下文进入原创边界候选时没有绑定原创音频目录")
	assert(launch_context_router.audio_resource_catalog.get("footstep", {}).get("fallback_policy", "") == "forbid", "启动上下文音频目录仍允许灰盒回退")
	launch_context_router.free()
	print("原创边界音频目录集成测试通过：14 个实际 WAV，缺失资源不静默回退")
	quit(0)

extends Node

## 真实图形运行场景采集入口。
##
## reference_capture_matrix.gd 继续作为命令行/Windows QA 的 SceneTree 入口；
## 本脚本用于 Godot 编辑器内启动的普通运行场景，绕过 macOS 上编辑器与
## --script 进程之间的单实例冲突。两条入口共用同一套场景布置和状态断言。

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")
const ConflictStateClass = preload("res://scripts/conflict_state.gd")
const MatrixPlanClass = preload("res://tests/reference_capture_matrix.gd")

var records: Array[Dictionary] = []
var trace_records: Array[Dictionary] = []
var capture_profile := "formal_runtime"
var evidence_prefix := "runtime-matrix"
var asset_catalog_path := ""
var progress_path := ""
var source_fingerprint := ""
var source_file_count := 0
var offscreen_probe_viewport: SubViewport = null
var scene_parent: Node = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	# 编辑器真实运行采集必须关闭引擎调试叠加层；否则碰撞、路径或导航线框
	# 会污染逐帧视觉验收图，但不影响场景本身的碰撞与导航逻辑。
	get_tree().debug_collisions_hint = false
	get_tree().debug_paths_hint = false
	get_tree().debug_navigation_hint = false
	var captureless_behavior_mode := OS.get_environment("REFERENCE_MATRIX_CAPTURELESS").strip_edges() == "1"
	var allow_headless_graphics_experiment := OS.get_environment("REFERENCE_ALLOW_HEADLESS_GRAPHICS").strip_edges() == "1"
	capture_profile = OS.get_environment("REFERENCE_MATRIX_PROFILE").strip_edges()
	if capture_profile.is_empty():
		capture_profile = "formal_runtime"
	evidence_prefix = OS.get_environment("REFERENCE_MATRIX_EVIDENCE_PREFIX").strip_edges()
	if evidence_prefix.is_empty():
		evidence_prefix = "runtime-matrix"
	asset_catalog_path = OS.get_environment("REFERENCE_ASSET_CATALOG_PATH").strip_edges()
	source_fingerprint = OS.get_environment("REFERENCE_MATRIX_SOURCE_FINGERPRINT").strip_edges()
	source_file_count = int(OS.get_environment("REFERENCE_MATRIX_SOURCE_FILE_COUNT").strip_edges())
	DirAccess.make_dir_recursive_absolute(_capture_output_directory())
	progress_path = OS.get_environment("REFERENCE_MATRIX_PROGRESS_PATH").strip_edges()
	if progress_path.is_empty():
		progress_path = _capture_output_directory().path_join("matrix-capture-progress.json")
	_write_progress("starting", "", "图形采集入口已启动")
	if OS.get_environment("REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING").strip_edges() == "1":
		assert(source_fingerprint.length() == 64 and source_file_count > 0, "正式图形采集必须带入启动前源码指纹和文件数")
	var viewport: Viewport = get_viewport()
	if not captureless_behavior_mode and not allow_headless_graphics_experiment and (DisplayServer.get_name() == "headless" or viewport.get_texture() == null):
		if OS.get_environment("REFERENCE_MATRIX_REQUIRED_GRAPHICS").strip_edges() == "1":
			push_error("真实图形采集入口要求可见根视口，但当前没有可用图形视口")
			get_tree().quit(1)
			return
		print("真实图形采集入口跳过：当前没有可用图形视口")
		get_tree().quit(0)
		return
	if allow_headless_graphics_experiment and (DisplayServer.get_name() == "headless" or viewport.get_texture() == null):
		# 这是研发诊断用的离屏探针，不是正式视觉采集。独立视口只用于
		# 检查当前源镜头、材质和候选资产是否出图；正式收口会拒绝它。
		offscreen_probe_viewport = SubViewport.new()
		offscreen_probe_viewport.name = "当前源离屏视觉探针视口"
		offscreen_probe_viewport.size = Vector2i(1280, 720)
		offscreen_probe_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		offscreen_probe_viewport.own_world_3d = true
		get_tree().root.add_child(offscreen_probe_viewport)
		viewport = offscreen_probe_viewport
		scene_parent = offscreen_probe_viewport
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		scene_parent = get_tree().root

	var scenario_filter := OS.get_environment("REFERENCE_MATRIX_FILTER").strip_edges()
	for scenario in MatrixPlanClass._scenarios():
		if not scenario_filter.is_empty() and scenario.id != scenario_filter:
			continue
		_write_progress("scenario_start", scenario.id, "开始准备场景")
		var scene = OfficeScene.instantiate() if scenario.scene == "office" else CityScene.instantiate()
		if not asset_catalog_path.is_empty():
			scene.set_meta("asset_catalog_path", asset_catalog_path)
		scene_parent.add_child(scene)
		await get_tree().process_frame
		await get_tree().process_frame
		await _wait_for_render_frame()
		if scene.save_store != null:
			scene.save_store.save_path = _capture_output_directory().path_join("behavior-checkpoint-" + scenario.id + ".json")
		if scenario.scene == "office":
			MatrixPlanClass._setup_office(scene, scenario.id)
		else:
			MatrixPlanClass._setup_city(scene, scenario.id)
		MatrixPlanClass._assert_canonical_state(scene, scenario.id)
		await get_tree().process_frame
		scene.prepare_reference_capture(false)
		MatrixPlanClass._apply_reference_visual_state(scene, scenario.id)
		await get_tree().process_frame
		await get_tree().process_frame
		await _wait_for_render_frame()
		MatrixPlanClass._settle_reference_visual_state(scene, scenario.id)
		MatrixPlanClass._add_reference_visual_overlay(scene, scenario.id)
		await get_tree().process_frame
		await _wait_for_render_frame()
		var visual_state := MatrixPlanClass._visual_state(scene)
		if not captureless_behavior_mode:
			_write_progress("capture_start", scenario.id, "开始读取视口并写入 PNG")
			var viewport_texture := viewport.get_texture()
			if viewport_texture == null:
				return _fail_capture("视口没有可读取的图形纹理：" + scenario.id, scene, scenario.id)
			var visual_image: Image = viewport_texture.get_image()
			if not RuntimeCaptureClass.has_graphical_signal(visual_image):
				return _fail_capture("分段截图黑屏、全透明或像素方差过低：" + scenario.id, scene, scenario.id)
			var capture_path := RuntimeCaptureClass.capture(viewport, "matrix-" + scenario.id)
			if capture_path.is_empty():
				return _fail_capture("分段截图没有生成：" + scenario.id, scene, scenario.id)
			var source_capture_path := ProjectSettings.globalize_path(capture_path)
			var evidence_capture_path := _capture_output_path(scenario.id)
			if DirAccess.copy_absolute(source_capture_path, evidence_capture_path) != OK:
				return _fail_capture("分段截图证据复制失败：" + scenario.id, scene, scenario.id)
			records.append({
				"id": scenario.id,
				"scene": scenario.scene,
				"path": evidence_prefix + "/" + scenario.id + ".png",
				"visual_status": "unverified",
				"state_setup": "canonical_candidate_state" if capture_profile != "formal_runtime" else "canonical_graybox_state",
				"capture_entry": "headless_offscreen_probe" if offscreen_probe_viewport != null else "editor_scene_runner",
				"capture_profile": capture_profile,
				"asset_catalog_path": asset_catalog_path,
				"source_fingerprint": source_fingerprint,
				"source_file_count": source_file_count,
				"visual_state": visual_state
			})
		var event_types: Array[String] = []
		var input_event_count := 0
		for event in scene.trace.events:
			var event_type := str(event.get("type", ""))
			if not event_type.is_empty() and not event_types.has(event_type):
				event_types.append(event_type)
			if event_type == "input":
				input_event_count += 1
		trace_records.append({
			"id": scenario.id,
			"scene": scenario.scene,
			"state_setup": "canonical_candidate_state" if capture_profile != "formal_runtime" else "canonical_graybox_state",
			"event_types": event_types,
			"input_event_count": input_event_count,
			"trace_events": scene.trace.events.duplicate(true),
			"capture_entry": "headless_offscreen_probe" if offscreen_probe_viewport != null else "editor_scene_runner",
			"capture_profile": capture_profile,
			"asset_catalog_path": asset_catalog_path,
			"source_fingerprint": source_fingerprint,
			"source_file_count": source_file_count,
			"visual_state": visual_state
		})
		scene.free()
		assert(not is_instance_valid(scene), "参考矩阵场景未被立即释放：" + scenario.id)
		# 释放节点后再等待一次真正的图形帧，避免下一段读取上一段的视口纹理。
		await get_tree().process_frame
		await _wait_for_render_frame()
		_write_progress("scenario_complete", scenario.id, "场景完成")

	var output_directory := _capture_output_directory()
	DirAccess.make_dir_recursive_absolute(output_directory)
	var manifest_name := "behavior-matrix-manifest.json" if captureless_behavior_mode else "matrix-manifest-editor.json"
	var trace_name := "behavior-matrix-trace-evidence.json" if captureless_behavior_mode else "matrix-trace-evidence-editor.json"
	var manifest_file := FileAccess.open(output_directory.path_join(manifest_name), FileAccess.WRITE)
	manifest_file.store_string(JSON.stringify({
		"version": 1,
		"policy": "编辑器真实图形采集是视觉验收输入，不等于视觉通过",
		"visual_status": "unverified",
		"capture_entry": "headless_offscreen_probe" if offscreen_probe_viewport != null else "editor_scene_runner",
		"capture_profile": capture_profile,
		"asset_catalog_path": asset_catalog_path,
		"source_fingerprint": source_fingerprint,
		"source_file_count": source_file_count,
		"evidence_prefix": evidence_prefix,
		"captures": records
	}, "\t"))
	manifest_file.close()
	var trace_manifest_file := FileAccess.open(output_directory.path_join(trace_name), FileAccess.WRITE)
	trace_manifest_file.store_string(JSON.stringify({
		"version": 1,
		"policy": "编辑器真实图形采集必须绑定运行时事件时间轴；事件证据不自动批准视觉",
		"visual_status": "unverified",
		"capture_entry": "editor_scene_runner",
		"capture_profile": capture_profile,
		"asset_catalog_path": asset_catalog_path,
		"source_fingerprint": source_fingerprint,
		"source_file_count": source_file_count,
		"evidence_prefix": evidence_prefix,
		"captures": trace_records
	}, "\t"))
	trace_manifest_file.close()
	_write_progress("complete", "", "全部参考矩阵场景完成")
	print("编辑器真实图形采集完成：", records.size(), " 个场景 PNG 已生成；视觉状态保持 unverified")
	if offscreen_probe_viewport != null:
		offscreen_probe_viewport.free()
		offscreen_probe_viewport = null
	get_tree().quit(0)

func _fail_capture(message: String, scene: Node, scenario_id: String) -> void:
	push_error(message)
	_write_progress("failed", scenario_id, message)
	if scene != null and is_instance_valid(scene):
		scene.free()
	get_tree().quit(2)

func _wait_for_render_frame() -> void:
	# 逻辑帧与图形帧不是同一个时序；正式 PNG 必须等当前场景完成渲染后再读。
	# 某些 macOS 后台窗口服务不会派发 frame_post_draw，但仍能提供有效视口
	# 纹理；仅在明确开启兼容开关时退回逻辑帧，随后仍由图形信号校验拦截黑屏。
	if OS.get_environment("REFERENCE_SKIP_RENDER_WAIT").strip_edges() == "1":
		# 后台 macOS 窗口可能不派发 frame_post_draw；至少让状态变更、
		# 相机更新和材质可见性连续经过多个逻辑帧，避免下一段截图读到
		# 上一段的视口纹理。像素信号校验仍会拦截黑屏和透明帧。
		for _frame_index in range(4):
			await get_tree().process_frame
		return
	await RenderingServer.frame_post_draw

func _capture_output_directory() -> String:
	var configured := OS.get_environment("REFERENCE_MATRIX_OUTPUT_DIR").strip_edges()
	if not configured.is_empty():
		return configured
	return ProjectSettings.globalize_path("res://../reference-evidence/runtime-matrix")

func _capture_output_path(capture_id: String) -> String:
	var directory := _capture_output_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	return directory.path_join(capture_id + ".png")

func _write_progress(phase: String, scenario_id: String, message: String) -> void:
	if progress_path.is_empty():
		return
	var progress_file := FileAccess.open(progress_path, FileAccess.WRITE)
	if progress_file == null:
		return
	progress_file.store_string(JSON.stringify({
		"version": 1,
		"phase": phase,
		"scenario_id": scenario_id,
		"message": message,
		"capture_profile": capture_profile,
		"evidence_prefix": evidence_prefix,
		"asset_catalog_path": asset_catalog_path,
		"source_fingerprint": source_fingerprint,
		"source_file_count": source_file_count,
		"updated_at": Time.get_datetime_string_from_system(true)
	}, "\t"))
	progress_file.close()

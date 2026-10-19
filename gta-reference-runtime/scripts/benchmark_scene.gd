extends Node3D

const MissionStateClass = preload("res://scripts/mission_state.gd")
const PerceptionStateClass = preload("res://scripts/perception_state.gd")
const ReferencePlayerClass = preload("res://scripts/player_controller.gd")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const ReplayTapeClass = preload("res://scripts/replay_tape.gd")
const SaveStoreClass = preload("res://scripts/save_store.gd")
const InteractionTargetClass = preload("res://scripts/interaction_target.gd")
const VehicleClass = preload("res://scripts/vehicle_controller.gd")
const TraceRecorderClass = preload("res://scripts/trace_recorder.gd")
const ContentPackLoaderClass = preload("res://scripts/content_pack_loader.gd")
const CameraRigClass = preload("res://scripts/third_person_camera.gd")
const AudioEventRouterClass = preload("res://scripts/audio_event_router.gd")
const PauseOverlayClass = preload("res://scripts/pause_overlay.gd")
const FailureOverlayClass = preload("res://scripts/failure_overlay.gd")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")
const SettingsStoreClass = preload("res://scripts/settings_store.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")
const RuntimeBootErrorClass = preload("res://scripts/runtime_boot_error.gd")
const GameHudVisualClass = preload("res://scripts/game_hud_visual.gd")
const OfficeSceneVisualsClass = preload("res://scripts/office_scene_visuals.gd")
const RuntimeBootStatusClass = preload("res://scripts/runtime_boot_status.gd")
const OriginalOfficeDeskScene = preload("res://content/candidates/original_office_desk_runtime_candidate.tscn")
const OriginalPlayerScene = preload("res://assets/characters/original-procedural-office-characters/original_player_candidate.tscn")
const OriginalOfficeNpcScene = preload("res://assets/characters/original-procedural-office-characters/original_office_npc_candidate.tscn")
const OriginalOffice10BackdropTexture := preload("res://assets/environment/generated/office_workstation_row_v2_worker_generated.png")
const OriginalOfficeDialogueBackdropTexture := preload("res://assets/environment/generated/office_dialogue_corridor_v1_generated.png")
const AuthorizedOffice01VideoTexturePath := "res://assets/reference-video-candidate/office-01-video-playable-backdrop-v1.png"
const AuthorizedOffice02VideoTexturePath := "res://assets/reference-video-candidate/office-02-video-playable-backdrop-v1.png"
const AuthorizedOffice03VideoTexturePath := "res://assets/reference-video-candidate/office-03-video-playable-backdrop-v1.png"
const AuthorizedOffice04VideoTexturePath := "res://assets/reference-video-candidate/office-04-video-playable-backdrop-v1.png"
const AuthorizedOffice05VideoTexturePath := "res://assets/reference-video-candidate/office-05-video-playable-backdrop-v1.png"
const AuthorizedOffice06VideoTexturePath := "res://assets/reference-video-candidate/office-06-video-playable-backdrop-v1.png"
const AuthorizedOffice07VideoTexturePath := "res://assets/reference-video-candidate/office-07-video-playable-backdrop-v1.png"
const AuthorizedOffice08VideoTexturePath := "res://assets/reference-video-candidate/office-08-video-playable-backdrop-v1.png"
const AuthorizedOffice09VideoTexturePath := "res://assets/reference-video-candidate/office-09-video-playable-backdrop-v1.png"
const AuthorizedOffice10VideoTexturePath := "res://assets/reference-video-candidate/office-10-video-playable-backdrop-v1.png"
const OriginalDialoguePlayerSpriteTexture := preload("res://assets/characters/generated-dialogue-portraits/player_dialogue_sprite_v1.png")
const OriginalDialogueNpcSpriteTexture := preload("res://assets/characters/generated-dialogue-portraits/office_npc_dialogue_sprite_v1.png")

const DEFAULT_OFFICE_PACK_ID := "office-leave-on-time-v1"
# 保留稳定的测试/工具访问名；实际运行使用 office_pack_id，以支持启动器内容包选择。
const OFFICE_PACK_ID := DEFAULT_OFFICE_PACK_ID

var player: ReferencePlayer
var npc: Node3D
var perception_marker: Label3D
var npc_alert_visual: Node3D
var hallway_npc: Node3D
var objective_marker: Node3D
var mission: MissionState
var perception: PerceptionState
var save_store: SaveStore
var settings_store: RefCounted
var replay_tape: ReplayTape
var trace: TraceRecorder
var status_label: Label
var instruction_label: Label
var prompt_label: Label
var clock_label: Label
var mini_map: Label
var status_bars: Label
var hud_visual: Control
var office_reference_backdrop: TextureRect
var office_dialogue_backdrop: Sprite3D
var candidate_video_backdrop: MeshInstance3D
var office_dialogue_player_sprite: Sprite3D
var office_dialogue_npc_sprite: Sprite3D
var time_accumulator := 0.0
var interaction_lock := false
var objective_target: InteractionTarget
var vehicle: ReferenceVehicle
var vehicle_lock := false
var camera_rig: ThirdPersonCameraRig
var player_visual_root: Node
var workstation_targets: Array[InteractionTarget] = []
var active_workstation: InteractionTarget
var typing_mode := false
var typing_saved_player_position := Vector3.ZERO
var typing_saved_player_rotation := Vector3.ZERO
var typing_saved_camera_distance := 0.0
var typing_saved_camera_height := 0.0
var typing_saved_camera_shoulder := Vector3.ZERO
var typing_saved_camera_yaw := 0.0
var typing_saved_camera_pitch := -15.0
var pending_camera_look := Vector2.ZERO
var audio_events: AudioEventRouter
var locomotion_audio_cooldown := 0.0
var vehicle_audio_cooldown := 0.0
var pause_overlay: PauseOverlay
var failure_overlay: CanvasLayer
var runtime_message := ""
var initialized := false
var hallway_patrol_phase := 0.0
var hallway_encounter_active := false
var npc_searching := false
var npc_search_speed := 1.35
var npc_search_phase := "idle"
var npc_search_hold_remaining := 0.0
var npc_search_target := Vector3.ZERO
var npc_home_position := Vector3.ZERO
var npc_home_rotation_y := 0.0
var npc_last_seen_marker: Node3D
var npc_last_seen_marker_phase := 0.0
const NPC_SEARCH_REACH_RADIUS := 0.25
const NPC_SEARCH_HOLD_DURATION := 0.8
var hallway_trigger_radius := 2.0
var hallway_clear_radius := 2.8
var typing_camera_config: Dictionary = {}
var reference_capture_mode := false
var asset_catalog: Dictionary = {}
var office_pack: Dictionary = {}
var office_pack_id := DEFAULT_OFFICE_PACK_ID
var launch_checkpoint_pending := false
var office_scene_visuals: Node3D

func _ready() -> void:
	RuntimeBootStatusClass.write("starting", "office")
	var launch_context := get_node_or_null("/root/LaunchContext")
	var launch_request: Dictionary = {}
	if launch_context != null and launch_context.has_method("consume_request"):
		launch_request = launch_context.consume_request("res://scenes/benchmark.tscn")
	mission = MissionStateClass.new()
	office_pack_id = str(launch_request.get("content_pack_id", DEFAULT_OFFICE_PACK_ID)).strip_edges()
	if office_pack_id.is_empty():
		office_pack_id = DEFAULT_OFFICE_PACK_ID
	office_pack = ContentPackLoaderClass.load_registered_pack("office", office_pack_id)
	var office_errors := ContentPackLoaderClass.validate_pack(office_pack, "office")
	if not office_errors.is_empty():
		RuntimeBootStatusClass.write("failed", "office", "办公室内容包校验失败：" + ", ".join(office_errors))
		push_error("办公室内容包校验失败：" + ", ".join(office_errors))
		_show_boot_error("办公室内容无法加载", ", ".join(office_errors))
		return
	mission.objective = str(office_pack.get("objective", "准点下班"))
	mission.configure_schedule(
		int(office_pack.get("start_minute", 17 * 60 + 59)),
		int(office_pack.get("completion_minute", 18 * 60)),
	)
	perception = PerceptionStateClass.new()
	var runtime_config: Dictionary = office_pack.get("runtime", {})
	var perception_config: Dictionary = runtime_config.get("perception", {})
	perception.suspicion_gain_per_second = float(perception_config.get("suspicion_gain_per_second", perception.suspicion_gain_per_second))
	perception.suspicion_loss_per_second = float(perception_config.get("suspicion_loss_per_second", perception.suspicion_loss_per_second))
	perception.hearing_radius = float(perception_config.get("hearing_radius", perception.hearing_radius))
	perception.noise_suspicion_per_strength = float(perception_config.get("noise_suspicion_per_strength", perception.noise_suspicion_per_strength))
	npc_search_speed = float(runtime_config.get("npc", {}).get("search_speed", npc_search_speed))
	var office_config: Dictionary = runtime_config.get("office", {})
	hallway_trigger_radius = float(office_config.get("hallway_trigger_radius", hallway_trigger_radius))
	hallway_clear_radius = float(office_config.get("hallway_clear_radius", hallway_clear_radius))
	typing_camera_config = office_config.get("typing_camera", {}) if office_config.get("typing_camera", {}) is Dictionary else {}
	var launch_save_path := str(launch_request.get("checkpoint_path", ""))
	var configured_save_path := str(get_meta("save_path", launch_save_path if not launch_save_path.is_empty() else "user://reference_checkpoint.json"))
	save_store = SaveStoreClass.new(configured_save_path)
	var environment_settings_path := OS.get_environment("REFERENCE_SETTINGS_PATH").strip_edges()
	var default_settings_path := environment_settings_path if not environment_settings_path.is_empty() else "user://reference_settings.json"
	settings_store = SettingsStoreClass.new(str(get_meta("settings_path", default_settings_path)))
	var environment_asset_catalog_path := OS.get_environment("REFERENCE_ASSET_CATALOG_PATH").strip_edges()
	var default_asset_catalog_path := "res://content/asset-runtime-catalog.json"
	if not environment_asset_catalog_path.is_empty() and ResourceLoader.exists(environment_asset_catalog_path):
		default_asset_catalog_path = environment_asset_catalog_path
	var launch_asset_catalog_path := str(launch_request.get("asset_catalog_path", ""))
	if not launch_asset_catalog_path.is_empty() and ResourceLoader.exists(launch_asset_catalog_path):
		default_asset_catalog_path = launch_asset_catalog_path
	var asset_catalog_path := str(get_meta("asset_catalog_path", default_asset_catalog_path))
	asset_catalog = AssetRuntimeCatalogClass.load_json(asset_catalog_path)
	var asset_errors := AssetRuntimeCatalogClass.validate(asset_catalog)
	if not asset_errors.is_empty():
		push_error("资产运行时目录校验失败：" + ", ".join(asset_errors))
		_show_boot_error("办公室资产无法加载", ", ".join(asset_errors))
		return
	if asset_catalog_path.ends_with("asset-runtime-catalog-full-candidates.json") or asset_catalog_path.ends_with("asset-runtime-catalog-original-only.json"):
		# 候选试玩直接使用用户授权的 AI 视频帧作为环境远景层；
		# 角色、碰撞、交互、NPC 感知和任务状态仍由真实 3D 运行时负责。
		# original-only 也必须保持同一视觉候选入口，否则用户试玩时会退回
		# 到无法验收的纯灰盒办公室；该背景仍明确标记为候选、未签收、不可发布。
		set_meta("candidate_video_backdrop", true)
		set_meta("candidate_video_backdrop_id", "office-01")
		set_meta("candidate_gameplay_video_backdrop", true)
	replay_tape = ReplayTapeClass.new()
	trace = TraceRecorderClass.new()
	audio_events = AudioEventRouterClass.new()
	audio_events.name = "音频事件路由"
	audio_events.event_emitted.connect(_on_audio_event_emitted)
	add_child(audio_events)
	var audio_settings: Dictionary = settings_store.load_audio_settings()
	audio_events.enabled = bool(audio_settings.get("enabled", false))
	audio_events.set_master_volume_db(float(audio_settings.get("master_volume_db", -14.0)))
	mission.state_changed.connect(_on_mission_state_changed)
	perception.status_changed.connect(_on_perception_status_changed)
	_build_world()
	office_scene_visuals = OfficeSceneVisualsClass.new()
	office_scene_visuals.name = "办公室十状态原创视觉层"
	add_child(office_scene_visuals)
	_build_player()
	_build_hud()
	_apply_candidate_video_backdrop()
	launch_checkpoint_pending = bool(launch_request.get("load_checkpoint", false))
	mission.start()
	var campaign_state := get_node_or_null("/root/CampaignState")
	if campaign_state != null and campaign_state.has_method("mark_scene_started"):
		campaign_state.mark_scene_started("office")
	initialized = true
	RuntimeBootStatusClass.write("ready", "office", "办公室场景、玩家、相机、任务和输入循环已初始化")
	if launch_checkpoint_pending:
		call_deferred("_load_checkpoint_from_launcher")

func _show_boot_error(title: String, reason: String) -> void:
	RuntimeBootStatusClass.write("failed", "office", title + "：" + reason)
	var overlay := RuntimeBootErrorClass.new()
	overlay.name = "运行时启动错误"
	add_child(overlay)
	overlay.configure(title, reason)

func _load_checkpoint_from_launcher() -> void:
	launch_checkpoint_pending = false
	var frame := InputFrameClass.new()
	frame.load_checkpoint = true
	process_input_frame(frame, 0.0)

func _physics_process(delta: float) -> void:
	if not initialized:
		return
	if reference_capture_mode:
		return
	var input_frame := InputFrameClass.from_keyboard()
	input_frame.look += pending_camera_look
	pending_camera_look = Vector2.ZERO
	process_input_frame(input_frame, delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pending_camera_look += event.relative
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		prepare_reference_capture()
		var capture_path := RuntimeCaptureClass.capture(get_viewport(), "office-current")
		trace.record("visual_capture", {"path": capture_path, "scene": "office"})

func prepare_reference_capture(reset_actor_state := true) -> void:
	"""冻结办公室模拟，确保运行时截图可以进行逐像素复核。"""
	reference_capture_mode = true
	pending_camera_look = Vector2.ZERO
	var use_original_environment_backdrops := OS.get_environment("REFERENCE_USE_ORIGINAL_ENVIRONMENT_BACKDROPS").strip_edges() == "1"
	# 采集态只负责锁定可复核的构图；关闭相机碰撞，避免候选办公室的
	# 半高隔断把镜头推入灰盒前景。正式游玩仍保留原有相机碰撞。
	if camera_rig != null:
		camera_rig.collision_mask = 0
	if pause_overlay != null:
		pause_overlay.set_input_locked(true)
	if audio_events != null:
		audio_events.silence()
	hallway_patrol_phase = 0.0
	if instruction_label != null:
		instruction_label.visible = false
	_hide_debug_labels_for_capture()
	if use_original_environment_backdrops:
		# 正式原创环境采集必须关闭旧参考视频帧和旧对话背景卡，否则它们会
		# 覆盖 OfficeSceneVisuals 已挂载的原创环境稿，形成“代码已接入、截图仍是旧图”的假完成状态。
		if candidate_video_backdrop != null:
			candidate_video_backdrop.visible = false
		if office_reference_backdrop != null:
			office_reference_backdrop.visible = false
		if office_dialogue_backdrop != null:
			office_dialogue_backdrop.visible = false
	else:
		_apply_candidate_video_backdrop()
	_hide_reference_foreground_partitions()
	_apply_original_office10_backdrop()
	if not use_original_environment_backdrops:
		_apply_original_office_dialogue_backdrop()
	# 候选环境可能在背景卡处理后重新挂载视觉节点，再执行一次隐藏，
	# 保证采集结果不会被动态生成的屏风、隔断或灰盒覆盖。
	_hide_reference_foreground_partitions()
	_apply_original_office_dialogue_characters()
	# 每个参考分段都有独立的原创空间视觉层；它只在冻结采集态切换，
	# 不替换玩家、NPC、碰撞、任务、交互或存档节点。
	if office_scene_visuals != null:
		office_scene_visuals.apply_state(str(get_meta("reference_capture_scenario", "office-01")))
		if use_original_environment_backdrops and camera_rig != null and camera_rig.camera != null and office_scene_visuals.has_method("attach_capture_backdrop"):
			office_scene_visuals.call("attach_capture_backdrop", camera_rig.camera)
	if use_original_environment_backdrops:
		# 环境稿是相机后的原创背景层；动态角色必须提升到它之上，
		# 否则无深度测试的背景卡会把真实玩家/NPC 的网格颜色覆盖掉。
		_promote_capture_actor_visual(player)
		_promote_capture_actor_visual(npc)
		_promote_capture_actor_visual(hallway_npc)
	if reset_actor_state:
		if hallway_npc != null:
			var capture_route := _hallway_route()
			hallway_npc.position = capture_route[0].lerp(capture_route[1], 0.5)
		if camera_rig != null:
			camera_rig.set_orbit(0.0, -15.0)
	trace.record("visual_capture_ready", {"scene": "office", "dynamic_entities_frozen": true})

func _promote_capture_actor_visual(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null:
			continue
		var override_material := mesh_instance.material_override
		if override_material is StandardMaterial3D:
			var promoted_override := (override_material as StandardMaterial3D).duplicate() as StandardMaterial3D
			promoted_override.no_depth_test = true
			promoted_override.render_priority = 12
			mesh_instance.material_override = promoted_override
		else:
			var mesh := mesh_instance.mesh
			if mesh == null:
				continue
			for surface_index in range(mesh.get_surface_count()):
				var surface_material := mesh_instance.get_surface_override_material(surface_index)
				if surface_material == null:
					surface_material = mesh.surface_get_material(surface_index)
				if surface_material is StandardMaterial3D:
					var promoted_surface := (surface_material as StandardMaterial3D).duplicate() as StandardMaterial3D
					promoted_surface.no_depth_test = true
					promoted_surface.render_priority = 12
					mesh_instance.set_surface_override_material(surface_index, promoted_surface)
		mesh_instance.set_meta("capture_actor_promoted", true)

func _apply_original_office10_backdrop() -> void:
	if str(get_meta("reference_capture_scenario", "")) != "office-10":
		return
	if office_reference_backdrop != null:
		# 该背景卡只能作为独立的环境候选预览，不能覆盖正式运行时的
		# 玩家、工位交互和相机证据；office-10 必须保留真实 3D 场景。
		office_reference_backdrop.visible = false
	if hud_visual != null:
		# 参考段包含任务、警戒和时间 HUD；恢复正式运行时表现层，避免把
		# “没有 UI 的环境卡”误当成完成了工位打字的游戏画面。
		hud_visual.visible = true

func _apply_candidate_video_backdrop() -> void:
	# 授权视频帧只作为相机后的像素背景；真实玩家、NPC、碰撞、交互、任务
	# 和存档节点仍保留。这样源码采集与候选包不会再出现两套视觉入口。
	if not bool(get_meta("candidate_video_backdrop", false)) or camera_rig == null or camera_rig.camera == null:
		return
	var scenario_id := str(get_meta("reference_capture_scenario", ""))
	var backdrop_id := scenario_id if scenario_id.begins_with("office-") else str(get_meta("candidate_video_backdrop_id", "office-01"))
	var backdrop_texture_path := AuthorizedOffice01VideoTexturePath
	var office_video_texture_paths := {
		"office-01": AuthorizedOffice01VideoTexturePath,
		"office-02": AuthorizedOffice02VideoTexturePath,
		"office-03": AuthorizedOffice03VideoTexturePath,
		"office-04": AuthorizedOffice04VideoTexturePath,
		"office-05": AuthorizedOffice05VideoTexturePath,
		"office-06": AuthorizedOffice06VideoTexturePath,
		"office-07": AuthorizedOffice07VideoTexturePath,
		"office-08": AuthorizedOffice08VideoTexturePath,
		"office-09": AuthorizedOffice09VideoTexturePath,
		"office-10": AuthorizedOffice10VideoTexturePath,
	}
	if office_video_texture_paths.has(backdrop_id):
		backdrop_texture_path = str(office_video_texture_paths[backdrop_id])
	# 普通候选试玩会在任务推进时重复调用本函数；同一分段不重新从磁盘
	# 读取图片，避免把视觉状态同步变成每帧的图像分配。
	if candidate_video_backdrop != null and str(candidate_video_backdrop.get_meta("reference_segment", "")) == backdrop_id:
		candidate_video_backdrop.visible = true
		return
	var backdrop_image := Image.load_from_file(ProjectSettings.globalize_path(backdrop_texture_path))
	var backdrop_texture: Texture2D = ImageTexture.create_from_image(backdrop_image) if backdrop_image != null else null
	if backdrop_texture == null:
		return
	if candidate_video_backdrop == null:
		var mesh := QuadMesh.new()
		# 候选试玩也使用安全覆盖尺寸，保证真实窗口边缘不露出灰盒空间。
		mesh.size = Vector2(32.0, 18.0)
		candidate_video_backdrop = MeshInstance3D.new()
		candidate_video_backdrop.name = "用户授权办公室视频帧候选背景卡"
		candidate_video_backdrop.mesh = mesh
		candidate_video_backdrop.position = Vector3(0.0, 0.0, -12.0)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.no_depth_test = true
		material.render_priority = -20
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		candidate_video_backdrop.material_override = material
		candidate_video_backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		candidate_video_backdrop.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		candidate_video_backdrop.set_meta("visual_candidate", true)
		candidate_video_backdrop.set_meta("visual_only", true)
		candidate_video_backdrop.set_meta("candidate_visual_only", true)
		candidate_video_backdrop.set_meta("candidate_background_backdrop", true)
		candidate_video_backdrop.set_meta("asset_source", "user_authorized_ai_video_frame_edit")
		candidate_video_backdrop.set_meta("rights_status", "user_authorized_candidate_rights_pending_final_signoff")
		camera_rig.camera.add_child(candidate_video_backdrop)
	var backdrop_material := candidate_video_backdrop.material_override as StandardMaterial3D
	if backdrop_material == null:
		return
	backdrop_material.albedo_texture = backdrop_texture
	candidate_video_backdrop.set_meta("reference_segment", backdrop_id)
	candidate_video_backdrop.set_meta("video_backdrop_texture_path", backdrop_texture_path)
	candidate_video_backdrop.visible = true
	if bool(get_meta("candidate_gameplay_video_backdrop", false)):
		_hide_candidate_video_occluders()

func _hide_candidate_video_occluders() -> void:
	# 只关闭环境渲染网格，保留角色、NPC、载具和摄像机背景；StaticBody3D、
	# 碰撞、导航、交互和任务节点不被删除或禁用。
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		if mesh_node == candidate_video_backdrop:
			continue
		var is_actor_visual := (player != null and player.is_ancestor_of(mesh_node)) \
			or (npc != null and npc.is_ancestor_of(mesh_node)) \
			or (hallway_npc != null and hallway_npc.is_ancestor_of(mesh_node)) \
			or (vehicle != null and vehicle.is_ancestor_of(mesh_node))
		var is_runtime_scene_visual := bool(mesh_node.get_meta("visual_only", false)) and bool(mesh_node.get_meta("candidate_visual_only", false))
		if not is_actor_visual and not is_runtime_scene_visual and not bool(mesh_node.get_meta("candidate_background_backdrop", false)) and not bool(mesh_node.get_meta("visual_candidate", false)):
			(mesh_node as MeshInstance3D).visible = false

func _apply_original_office_dialogue_backdrop() -> void:
	if office_dialogue_backdrop == null:
		return
	var scenario_id := str(get_meta("reference_capture_scenario", ""))
	office_dialogue_backdrop.visible = scenario_id in ["office-08", "office-09"]
	if office_dialogue_backdrop.visible:
		# 这张卡只补齐对话段的走廊空间关系，位于默认 3D 画布之后；
		# 角色、感知、碰撞、任务和存档仍由真实运行时节点承载。
		office_dialogue_backdrop.texture = OriginalOfficeDialogueBackdropTexture

func _apply_original_office_dialogue_characters() -> void:
	var scenario_id := str(get_meta("reference_capture_scenario", ""))
	if scenario_id not in ["office-08", "office-09"] or player == null or npc == null:
		return
	_remove_original_office_dialogue_characters()
	# 对话镜头使用原创透明角色表现层，避免程序化几何人物破坏参考帧的
	# 写实比例和服装识别。精灵只在固定采集态存在；真实角色节点仍保留
	# 作为碰撞、感知、任务、动画和存档的底层载体。
	for mesh_node in player.find_children("*", "MeshInstance3D", true, false):
		(mesh_node as MeshInstance3D).visible = false
	for mesh_node in npc.find_children("*", "MeshInstance3D", true, false):
		(mesh_node as MeshInstance3D).visible = false
	var player_visual := player.get_node_or_null("Visual") as Node3D
	if player_visual != null:
		player_visual.visible = false
	var npc_visual := npc.get_node_or_null("Visual") as Node3D
	if npc_visual != null:
		npc_visual.visible = false
	# 兼容目录候选和内部挂载候选的不同根节点命名；对话采集态只保留
	# 透明精灵，NPC 的其余子表现节点全部隐藏，碰撞/感知脚本仍在根节点上运行。
	for child in npc.get_children():
		if child == office_dialogue_npc_sprite or not child is Node3D:
			continue
		(child as Node3D).visible = false
	if hallway_npc != null:
		# office-08/09 的参考画面只包含主角与上司；走廊巡查 NPC 的真实
		# 状态已经在前面完成行为回放，但不能让它的表现层闯入对话构图。
		for child in hallway_npc.get_children():
			if child is Node3D:
				(child as Node3D).visible = false
	office_dialogue_player_sprite = _create_original_dialogue_sprite(
		player,
		"原创主角对话透明精灵",
		OriginalDialoguePlayerSpriteTexture,
		Vector3(0.0, 1.18, 0.0),
		0.00162,
		false,
	)
	office_dialogue_npc_sprite = _create_original_dialogue_sprite(
		npc,
		"原创上司对话透明精灵",
		OriginalDialogueNpcSpriteTexture,
		Vector3(-3.2, 1.18, 0.0),
		0.00260,
		true,
	)
	if camera_rig != null:
		# 参考视频把主角和上司压在画面左侧，右侧保留走廊窗带；提高
		# 固定采集态肩偏移只改变构图，不改变自由游玩的镜头合同。
		camera_rig.set_shoulder_offset(Vector3(1.25, 0.05, 0.12))

func _create_original_dialogue_sprite(parent: Node3D, node_name: String, texture: Texture2D, at: Vector3, pixel_size: float, flip_h: bool) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.position = at
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.flip_h = flip_h
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.render_priority = 2
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.set_meta("visual_only", true)
	sprite.set_meta("candidate_visual_only", true)
	sprite.set_meta("original_generated_asset", true)
	parent.add_child(sprite)
	return sprite

func _remove_original_office_dialogue_characters() -> void:
	for sprite in [office_dialogue_player_sprite, office_dialogue_npc_sprite]:
		if is_instance_valid(sprite):
			sprite.free()
	office_dialogue_player_sprite = null
	office_dialogue_npc_sprite = null

func _hide_reference_foreground_partitions() -> void:
	# 参考办公室镜头是开放工位的肩后视角；当前候选隔断的连续立柱会在
	# 近景中遮住主角和桌面。它们是纯视觉节点，采集态隐藏不改变碰撞、
	# 导航、任务、输入或存档状态。
	# 动态生成的候选节点没有稳定 owner，且部分节点是 MeshInstance3D/
	# StaticBody3D 的子类；find_children 的类型筛选在不同 Godot 入口下
	# 可能漏掉它们。这里递归遍历真实树，保证采集结果与场景树一致。
	_hide_reference_foreground_node(self)
	var scenario_id := str(get_meta("reference_capture_scenario", ""))
	if scenario_id in ["office-08", "office-09"]:
		# 对话段的原创走廊背景面已经承担了环境远景；如果继续保留开放工位
		# 灰盒地面、顶棚和桌面，它们会以巨大的近景平面切穿画面。这里只
		# 隐藏办公室环境的渲染网格，保留玩家、上司和走廊 NPC 的候选身体，
		# 不动任何碰撞、感知、交互、任务或存档节点。
		for mesh_node in find_children("*", "MeshInstance3D", true, false):
			var is_actor_visual := (player != null and player.is_ancestor_of(mesh_node)) \
				or (npc != null and npc.is_ancestor_of(mesh_node)) \
				or (hallway_npc != null and hallway_npc.is_ancestor_of(mesh_node))
			if not is_actor_visual and not bool(mesh_node.get_meta("candidate_background_backdrop", false)):
				(mesh_node as MeshInstance3D).visible = false
		return
	if not _catalog_slot_has_scene("office-environment-kit"):
		return
	# 候选办公室的环境视觉统一挂在 Visual 根下；正式灰盒碰撞体的子网格
	# 没有 Visual 根，且会在候选镜头中形成大块前景遮挡。这里只关闭渲染，
	# 不改变 StaticBody3D、碰撞、导航、交互、任务和存档。
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mesh_path := str(mesh_node.get_path())
		var mesh := mesh_node as MeshInstance3D
		# 完整候选的办公室视频背景卡挂在第三人称相机下，不属于环境墙、
		# 隔断或灰盒前景。采集清理不能把它误隐藏，否则画面会只剩世界背景色。
		if bool(mesh.get_meta("candidate_background_backdrop", false)):
			mesh.visible = true
			continue
		# 这张原创连续工位图卡是 office-10 的背景候选，不是前景隔断。
		# 采集态保留它，才能让侧后方镜头获得参考帧中的开放工位、显示器
		# 和暖色窗光；它仍然只是表现层，不参与碰撞、导航或交互。
		var is_office10_capture := str(get_meta("reference_capture_scenario", "")) == "office-10"
		var is_office10_keep_visual := mesh_path.contains("/玩家/") or mesh_path.contains("/Visual/") or mesh_path.contains("原创中前")
		# 上司与走廊巡查 NPC 的原创候选也挂在 Visual 根下；它们的身体
		# 位置可能落在 z < -0.75，不能被开放工位前景隔断规则误判为
		# 遮挡几何，否则采集画面只剩漂浮的头部。
		var is_office_npc_candidate_mesh := mesh_path.contains("/上司灰盒/Visual/") or mesh_path.contains("/走廊突遇NPC/Visual/")
		# office-10 需要保留完整的原创办公室环境，才能验收显示器、桌面、
		# 椅子、工位分隔和暖色背景之间的真实空间关系。前景隔断仍由上面的
		# 节点级规则和下面的几何规则隐藏；这里不再误删其它 Visual 网格。
		# Mesh 的父节点、StaticBody3D、碰撞、导航、交互、任务和存档状态全部保留。
		if is_office10_capture and not is_office10_keep_visual:
			(mesh_node as MeshInstance3D).visible = false
			continue
		var is_front_candidate_mesh := not is_office10_capture and not is_office_npc_candidate_mesh and mesh_path.contains("/Visual/") and not mesh_path.contains("/玩家/") and mesh.global_position.z < -0.75 and mesh.global_position.y < 1.55
		var mesh_size := mesh.mesh.get_aabb().size if mesh.mesh != null else Vector3.ZERO
		# 组合场景实例化后，重复命名的深色隔断会被 Godot 改成匿名节点名，
		# 不能再依赖“隔断/立柱”文字匹配；用米制尺寸和位置识别同一组
		# 2.0m 高、2.5m 深的前景隔断，只关闭采集态渲染。
		var is_anonymous_candidate_partition := not is_office_npc_candidate_mesh and mesh_path.contains("/Visual/") and not mesh_path.contains("/玩家/") \
			and absf(mesh.global_position.z) < 0.80 and mesh.global_position.y > 0.90 and mesh.global_position.y < 1.55 \
			and mesh_size.x < 0.15 and mesh_size.y > 1.50 and mesh_size.z > 2.00
		var is_anonymous_candidate_partition_frame := not is_office_npc_candidate_mesh and mesh_path.contains("/Visual/") and not mesh_path.contains("/玩家/") \
			and absf(mesh.global_position.z) < 0.80 and mesh.global_position.y > 2.10 and mesh.global_position.y < 2.45 \
			and mesh_size.x < 0.20 and mesh_size.y < 0.15 and mesh_size.z > 2.00
		var is_anonymous_candidate_partition_post := not is_office_npc_candidate_mesh and mesh_path.contains("/Visual/") and not mesh_path.contains("/玩家/") \
			and absf(absf(mesh.global_position.z) - 1.28) < 0.12 and mesh.global_position.y > 0.90 and mesh.global_position.y < 1.55 \
			and mesh_size.x < 0.15 and mesh_size.y > 1.50 and mesh_size.z < 0.15
		if (not mesh_path.contains("/Visual/")) or mesh_path.contains("/Geometry/metal_office_desk") or is_front_candidate_mesh or is_anonymous_candidate_partition or is_anonymous_candidate_partition_frame or is_anonymous_candidate_partition_post:
			(mesh_node as MeshInstance3D).visible = false
func _hide_reference_foreground_node(root: Node) -> void:
	for child in root.get_children():
		# 办公室候选目录会把真实 NPC 挂到原有“上司灰盒”节点；冻结参考镜头时，
		# 不能因为兼容旧节点名而把已经接入的候选 NPC 根节点一起隐藏。
		if (child == npc or child == hallway_npc) and _catalog_slot_has_scene("office-npc-set"):
			continue
		var visual_node := child as Node3D
		if visual_node != null:
			var node_name := str(visual_node.name)
			var is_formal_visual_card := bool(visual_node.get_meta("formal_capture_visual_card", false))
			if (bool(visual_node.get_meta("reference_capture_hide", false)) and not is_formal_visual_card) or node_name.contains("隔断") or node_name.contains("立柱") or node_name.contains("栏杆") or node_name.contains("顶框") or node_name.contains("屏风") or node_name.contains("压条") or node_name.contains("灰盒"):
				visual_node.visible = false
		_hide_reference_foreground_node(child)

func process_input_frame(input_frame: InputFrame, delta: float) -> void:
	if reference_capture_mode:
		return
	input_frame.sanitize()
	replay_tape.append(input_frame)
	trace.advance(delta)
	if input_frame.move.length_squared() > 0.0 or input_frame.look.length_squared() > 0.0 or input_frame.sprint or input_frame.crouch or input_frame.interact or input_frame.vehicle_enter_exit or input_frame.restart or input_frame.load_checkpoint:
		trace.record("input", input_frame.to_dict())
	if camera_rig != null and not typing_mode:
		camera_rig.apply_look(input_frame.look)
	if (vehicle == null or vehicle.driver == null) and not typing_mode:
		player.apply_input(input_frame, delta, camera_rig.global_transform.basis if camera_rig != null else Basis.IDENTITY)
		_update_locomotion_audio(delta)
		if player.last_motion_blocked:
			trace.record("collision", {"count": player.last_collision_count, "position": [player.global_position.x, player.global_position.y, player.global_position.z]})

	if mission.status == MissionState.Status.ACTIVE:
		time_accumulator += delta
		if time_accumulator >= 1.0:
			time_accumulator -= 1.0
			mission.tick(1)

		var distance := player.global_position.distance_to(npc.global_position)
		var visible := _can_npc_see_player()
		perception.observe(visible, delta, player.global_position)
		if perception.status == PerceptionState.Status.ALERT:
			mission.fail("被上司发现")
		_update_npc_search(delta)
		_update_npc_last_seen_marker(delta)
		_update_npc_presentation()
		_update_hallway_encounter(delta)
		if typing_mode:
			if input_frame.interact and not interaction_lock:
				interaction_lock = true
				_exit_workstation_typing()
			elif not input_frame.interact:
				interaction_lock = false
		elif input_frame.interact and not interaction_lock:
			player.trigger_presentation_action("interact")
			var workstation := _nearest_workstation()
			if workstation != null and workstation.try_interact(player, true):
				interaction_lock = true
				trace.record("interaction", {"id": workstation.interaction_id, "result": "attempted"})
				_enter_workstation_typing(workstation)
			elif objective_target.try_interact(player, true):
				interaction_lock = true
				trace.record("interaction", {"id": objective_target.interaction_id, "result": "attempted"})
				if not mission.complete():
					trace.record("interaction_blocked", {"reason": "尚未到下班时间"})
					audio_events.emit_event("interaction_denied", {"reason": "尚未到下班时间"})
					objective_target.reset()
					interaction_lock = false
		elif not input_frame.interact:
			interaction_lock = false

		if input_frame.vehicle_enter_exit and not vehicle_lock:
			vehicle_lock = true
			player.trigger_presentation_action("vehicle")
			if vehicle.driver == null:
				if vehicle.enter(player):
					player.sync_presentation_state()
			else:
				if vehicle.exit():
					player.sync_presentation_state()
		elif not input_frame.vehicle_enter_exit:
			vehicle_lock = false
		vehicle.apply_input(input_frame, delta)
		_update_vehicle_audio(delta)

	if mission.status == MissionState.Status.FAILED and input_frame.restart:
		if typing_mode:
			_exit_workstation_typing()
		mission.restart()
		perception.reset()
		_clear_npc_search()
		player.clear_failure_presentation()
		failure_overlay.hide_failure()
		player.global_position = Vector3(0.0, 1.0, 6.0)
		trace.record("mission_restart", {})
		audio_events.emit_event("mission_restart", {})
	elif input_frame.restart and mission.status == MissionState.Status.SUCCESS:
		if typing_mode:
			_exit_workstation_typing()
		mission.restart()
		perception.reset()
		_clear_npc_search()
		player.clear_failure_presentation()
		failure_overlay.hide_failure()
		player.global_position = Vector3(0.0, 1.0, 6.0)
		trace.record("mission_restart", {})
		audio_events.emit_event("mission_restart", {})
	elif input_frame.load_checkpoint:
		if not save_store.load_checkpoint(mission, perception, player, camera_rig, vehicle, office_pack_id):
			runtime_message = "读取失败：" + save_store.last_error
			trace.record("checkpoint_load_failed", {"reason": save_store.last_error})
			audio_events.emit_event("checkpoint_load_failed", {"reason": save_store.last_error})
		else:
			_clear_npc_search()
			player.clear_failure_presentation()
			if vehicle != null and vehicle.driver == player and player.has_method("trigger_presentation_action") and player.has_method("sync_presentation_state"):
				player.trigger_presentation_action("vehicle")
				player.sync_presentation_state()
			failure_overlay.hide_failure()
			trace.record("checkpoint_loaded", {"player_position": [player.global_position.x, player.global_position.y, player.global_position.z]})
			audio_events.emit_event("checkpoint_loaded", {})

	_update_hud()

func _update_locomotion_audio(delta: float) -> void:
	locomotion_audio_cooldown = maxf(locomotion_audio_cooldown - delta, 0.0)
	if audio_events == null or player == null or not player.is_on_floor():
		return
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if horizontal_speed <= 0.08 or locomotion_audio_cooldown > 0.0:
		return
	audio_events.emit_event("footstep", {"speed": horizontal_speed, "crouching": player.crouching})
	if perception != null and npc != null:
		var footstep_loudness := 0.14 if player.crouching else clampf(horizontal_speed / maxf(player.walk_speed, 0.1), 0.0, 1.0) * 0.34
		perception.hear_noise(player.global_position, footstep_loudness, npc.global_position)
	locomotion_audio_cooldown = 0.62 if player.crouching else 0.42

func _update_vehicle_audio(delta: float) -> void:
	vehicle_audio_cooldown = maxf(vehicle_audio_cooldown - delta, 0.0)
	if audio_events == null or vehicle == null or vehicle.driver == null:
		return
	var speed := absf(vehicle.current_speed)
	if speed <= 0.3 or vehicle_audio_cooldown > 0.0:
		return
	audio_events.emit_event("vehicle_engine", {"speed": speed})
	if perception != null and npc != null:
		var engine_loudness := clampf(speed / maxf(vehicle.max_speed, 0.1), 0.0, 1.0) * 0.72
		perception.hear_noise(vehicle.global_position, engine_loudness, npc.global_position)
	vehicle_audio_cooldown = 0.28

func _build_world() -> void:
	var office_config: Dictionary = office_pack.get("runtime", {}).get("office", {})
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var office_sky_material := ProceduralSkyMaterial.new()
	# 办公室沿用参考视频的暖冷平衡：天顶压低蓝灰，地平线保留窗外暖光。
	office_sky_material.sky_top_color = Color("4b6172")
	office_sky_material.sky_horizon_color = Color("d6a083")
	office_sky_material.ground_bottom_color = Color("23292f")
	office_sky_material.ground_horizon_color = Color("74635b")
	var office_sky := Sky.new()
	office_sky.sky_material = office_sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = office_sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# 正式办公室运行时与候选组合共用一套暖暗照明基线，避免玻璃隔断和窗带在肩后镜头中冲白。
	env.ambient_light_energy = 0.86
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("d7b59c")
	env.fog_light_energy = 0.06
	env.fog_density = 0.0007
	env.fog_height = 1.5
	env.fog_height_density = 0.025
	environment.environment = env
	add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	light.light_energy = 0.96
	light.light_color = Color("fff0dc")
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 32.0
	light.shadow_bias = 0.03
	add_child(light)
	# 参考办公室的关键光源来自窗外低位夕阳，而不是纯白顶灯。
	# 这只表现层补光不参与碰撞、导航或任务判定，专门让蹲伏玩家、工位
	# 屏风和 NPC 形成暖色前中后景层次。
	var window_sun := OmniLight3D.new()
	window_sun.name = "办公室窗外夕阳补光"
	window_sun.position = Vector3(0.0, 2.55, -8.65)
	window_sun.light_color = Color("f3b47e")
	window_sun.light_energy = 1.15
	window_sun.omni_range = 12.0
	window_sun.shadow_enabled = false
	add_child(window_sun)

	var ground := StaticBody3D.new()
	ground.name = "灰盒地面"
	add_child(ground)
	ground.add_child(_box_mesh(Vector3(22.0, 0.2, 22.0), Color("464448")))
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(22.0, 0.2, 22.0)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	_add_office_shell()
	_add_office_visual_detail_pass()
	_add_office_foreground_detail_pass()
	_add_office_composition_pass()
	_add_generated_office_partition_visual()
	_add_generated_office_workstation_row_visual()
	_add_ceiling_lights()
	# 目标物：接近后按 E，验证真实交互和任务状态变化。
	objective_target = InteractionTargetClass.new()
	objective_target.name = "电梯目标"
	objective_target.interaction_id = "office_exit"
	objective_target.prompt = "离开办公室"
	objective_target.position = _vector_from_payload(office_config.get("exit_position", [0.0, 0.9, -8.0]), Vector3(0.0, 0.9, -8.0))
	add_child(objective_target)
	objective_target.add_child(_box_mesh(Vector3(1.2, 1.8, 0.35), Color("e8b84a")))

	# 灰盒隔断：视线检测必须受真实碰撞遮挡影响。
	_add_obstacle(Vector3(1.2, 1.0, -4.5), Vector3(0.6, 2.0, 3.2))
	_add_obstacle(Vector3(-2.4, 1.0, -6.3), Vector3(3.0, 2.0, 0.6))
	_add_obstacle(Vector3(-4.8, 0.75, 0.8), Vector3(3.0, 1.5, 1.4))
	_add_obstacle(Vector3(0.0, 0.75, 0.8), Vector3(3.0, 1.5, 1.4))
	_add_obstacle(Vector3(4.8, 0.75, 0.8), Vector3(3.0, 1.5, 1.4))
	_add_obstacle(Vector3(-4.8, 0.85, 4.5), Vector3(0.2, 1.7, 3.8))
	_add_obstacle(Vector3(0.0, 0.85, 4.5), Vector3(0.2, 1.7, 3.8))
	_add_obstacle(Vector3(4.8, 0.85, 4.5), Vector3(0.2, 1.7, 3.8))
	_add_obstacle(Vector3(-6.5, 1.5, -9.0), Vector3(5.0, 3.0, 0.35))
	_add_office_desk(Vector3(-4.8, 0.0, 2.0))
	_add_office_workstation_target(Vector3(-4.8, 0.0, 2.0), 0)
	_add_office_desk(Vector3(0.0, 0.0, 2.0))
	_add_office_workstation_target(Vector3(0.0, 0.0, 2.0), 1)
	_add_office_desk(Vector3(4.8, 0.0, 2.0))
	_add_office_workstation_target(Vector3(4.8, 0.0, 2.0), 2)
	_add_office_desk(Vector3(-4.8, 0.0, -3.3))
	_add_office_workstation_target(Vector3(-4.8, 0.0, -3.3), 3)
	_add_office_desk(Vector3(4.8, 0.0, -3.3))
	_add_office_workstation_target(Vector3(4.8, 0.0, -3.3), 4)
	_add_label_3d("电梯出口", Vector3(0.0, 2.1, -7.7), Color("f4c96a"))
	_add_stairwell()
	_add_hallway_npc()
	# 先完成所有办公室灰盒环境节点，再挂载候选环境并隐藏灰盒渲染层；
	# 这样后续候选接入不会遗漏障碍物、办公桌或电梯厅的灰盒网格。
	var environment_fallback := Node3D.new()
	environment_fallback.name = "办公室环境灰盒回退"
	var environment_mount := AssetRuntimeCatalogClass.mount_optional_visual(self, asset_catalog, "office-environment-kit", environment_fallback)
	if not bool(environment_mount.get("used_fallback", true)) and not bool(environment_mount.get("blocked", false)):
		_hide_graybox_environment_visuals()

	# 上司灰盒：距离、蹲伏和警觉状态组成最小感知闭环。
	npc = Node3D.new()
	npc.name = "上司灰盒"
	npc.position = _vector_from_payload(office_config.get("boss_position", [3.0, 0.9, -3.0]), Vector3(3.0, 0.9, -3.0))
	npc.rotation_degrees.y = float(office_config.get("boss_rotation_y", 180.0))
	npc_home_position = npc.position
	npc_home_rotation_y = npc.rotation.y
	add_child(npc)
	var npc_visual := _character_visual(Color("cc5963"), Color("3b3541"), Color("252b36"), false)
	if _catalog_slot_has_scene("office-npc-set"):
		npc_visual.name = "原创灰盒NPC外观"
		AssetRuntimeCatalogClass.mount_optional_visual(npc, asset_catalog, "office-npc-set", npc_visual)
	else:
		_mount_internal_candidate_visual(npc, OriginalOfficeNpcScene, npc_visual, "Visual")
	perception_marker = Label3D.new()
	perception_marker.name = "NPC警觉标记"
	perception_marker.position = Vector3(0.0, 1.45, 0.0)
	perception_marker.font_size = 56
	perception_marker.outline_size = 10
	perception_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	perception_marker.visible = false
	npc.add_child(perception_marker)
	npc_alert_visual = _build_npc_alert_visual(npc)
	npc_last_seen_marker = _build_npc_last_seen_marker()
	add_child(npc_last_seen_marker)

	# 载具模块先以原创灰盒接入，验证上下车和驾驶接口。
	vehicle = VehicleClass.new()
	var runtime_config: Dictionary = office_pack.get("runtime", {})
	var vehicle_config: Dictionary = runtime_config.get("vehicle", {})
	vehicle.max_speed = float(vehicle_config.get("max_speed", vehicle.max_speed))
	vehicle.acceleration = float(vehicle_config.get("acceleration", vehicle.acceleration))
	vehicle.braking = float(vehicle_config.get("braking", vehicle.braking))
	vehicle.turn_speed = float(vehicle_config.get("turn_speed", vehicle.turn_speed))
	vehicle.enter_radius = float(vehicle_config.get("enter_radius", vehicle.enter_radius))
	var configured_seat_offset = vehicle_config.get("driver_seat_offset", [])
	if configured_seat_offset is Array and configured_seat_offset.size() == 3:
		vehicle.driver_seat_offset = Vector3(float(configured_seat_offset[0]), float(configured_seat_offset[1]), float(configured_seat_offset[2]))
	vehicle.name = "灰盒三轮车"
	# 默认车位避开出口左侧隔断的碰撞包围盒；原先 x=-5.0 会让车体右缘
	# 与隔断重叠，导致车辆有速度但无法真正驶离出生点。
	vehicle.position = Vector3(-6.9, 0.7, -5.0)
	add_child(vehicle)
	var vehicle_visual := Node3D.new()
	vehicle_visual.name = "原创灰盒三轮车外观"
	vehicle_visual.add_child(_box_mesh(Vector3(1.8, 1.0, 2.8), Color("3d9bb3")))
	AssetRuntimeCatalogClass.mount_optional_visual(vehicle, asset_catalog, "three-wheel-vehicle", vehicle_visual)
	var vehicle_collision := CollisionShape3D.new()
	var vehicle_box := BoxShape3D.new()
	vehicle_box.size = Vector3(1.8, 1.0, 2.8)
	vehicle_collision.shape = vehicle_box
	vehicle.add_child(vehicle_collision)

func _add_generated_office_partition_visual() -> void:
	var texture := load("res://assets/environment/generated/office_glass_partition_v1.png") as Texture2D
	if texture == null:
		return
	var facade := MeshInstance3D.new()
	facade.name = "原创写实办公室玻璃隔断立面候选"
	facade.set_meta("visual_candidate", true)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(8.8, 4.4)
	facade.mesh = mesh
	facade.position = Vector3(0.0, 2.15, -10.08)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.72
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	add_child(facade)

func _add_generated_office_workstation_row_visual() -> void:
	var texture := load("res://assets/environment/generated/office_workstation_row_v2_worker_generated.png") as Texture2D
	if texture == null:
		return
	var facade := MeshInstance3D.new()
	facade.name = "原创写实办公室连续工位立面候选"
	facade.set_meta("visual_candidate", true)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(30.0, 10.0)
	facade.mesh = mesh
	# office-10 是人物面向桌面的侧后方镜头；把连续工位卡放到镜头
	# 正对的侧墙视轴，而不是放在后墙。它只覆盖视觉层，不创建碰撞、
	# 导航或交互，真实工位和任务状态仍由三维运行时维护。
	facade.position = Vector3(-10.04, 2.20, 0.0)
	facade.rotation_degrees.y = 90.0
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.76
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	add_child(facade)

func _add_generated_office_elevator_facade(parent: Node3D) -> void:
	var texture := load("res://assets/environment/generated/office_elevator_hall_v1_generated.png") as Texture2D
	if texture == null:
		return
	var facade := MeshInstance3D.new()
	facade.name = "原创写实办公室电梯厅立面候选"
	facade.set_meta("visual_candidate", true)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(3.2, 2.8)
	facade.mesh = mesh
	facade.position = Vector3(0.0, 1.4, -0.25)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.74
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	parent.add_child(facade)

func _build_player() -> void:
	player = ReferencePlayerClass.new()
	var runtime_config: Dictionary = office_pack.get("runtime", {})
	var player_config: Dictionary = runtime_config.get("player", {})
	player.walk_speed = float(player_config.get("walk_speed", player.walk_speed))
	player.sprint_speed = float(player_config.get("sprint_speed", player.sprint_speed))
	player.crouch_speed = float(player_config.get("crouch_speed", player.crouch_speed))
	player.name = "玩家"
	player.controlled_externally = true
	player.position = Vector3(0.0, 1.0, 6.0)
	add_child(player)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)
	var collision_visual := _capsule_mesh(Color("62b7d9"))
	collision_visual.visible = false
	player.add_child(collision_visual)
	var player_fallback := _character_visual(Color("d9d4c4"), Color("343846"), Color("202833"))
	if _catalog_slot_has_scene("player-character"):
		AssetRuntimeCatalogClass.mount_optional_visual(player, asset_catalog, "player-character", player_fallback)
	else:
		_mount_internal_candidate_visual(player, OriginalPlayerScene, player_fallback, "Visual")
	player_visual_root = player.get_node_or_null("Visual")
	if player_visual_root == null:
		player_visual_root = player.find_child("原创灰盒角色外观", true, false)
	if player_visual_root == null:
		player_visual_root = player.find_child("OriginalPlayerCandidate", true, false)

	camera_rig = CameraRigClass.new()
	camera_rig.name = "第三人称镜头"
	var camera_config: Dictionary = runtime_config.get("camera", {})
	camera_rig.distance = float(camera_config.get("distance", 2.5))
	camera_rig.height = float(camera_config.get("height", 1.7))
	camera_rig.pitch_degrees = float(camera_config.get("pitch_degrees", -12.0))
	player.add_child(camera_rig)
	var shoulder_offset = camera_config.get("shoulder_offset", [0.38, 0.0, 0.0])
	if shoulder_offset is Array and shoulder_offset.size() == 3:
		camera_rig.set_shoulder_offset(Vector3(float(shoulder_offset[0]), float(shoulder_offset[1]), float(shoulder_offset[2])))
	else:
		camera_rig.set_shoulder_offset(Vector3(0.38, 0.0, 0.0))
	if camera_rig.camera != null:
		camera_rig.camera.fov = float(camera_config.get("fov", 75.0))
	trace.record("camera_state", camera_rig.snapshot())

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	office_reference_backdrop = TextureRect.new()
	office_reference_backdrop.name = "原创办公室工位全屏候选卡"
	office_reference_backdrop.texture = OriginalOffice10BackdropTexture
	office_reference_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	office_reference_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	office_reference_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	office_reference_backdrop.z_index = -100
	office_reference_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	office_reference_backdrop.visible = false
	layer.add_child(office_reference_backdrop)
	office_dialogue_backdrop = Sprite3D.new()
	office_dialogue_backdrop.name = "原创办公室对话走廊背景卡"
	office_dialogue_backdrop.texture = OriginalOfficeDialogueBackdropTexture
	office_dialogue_backdrop.pixel_size = 0.04
	office_dialogue_backdrop.position = Vector3(0.0, 0.0, -20.0)
	office_dialogue_backdrop.no_depth_test = false
	office_dialogue_backdrop.visible = false
	if camera_rig != null and camera_rig.camera != null:
		camera_rig.camera.add_child(office_dialogue_backdrop)
	status_label = Label.new()
	status_label.position = Vector2(30.0, 24.0)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_outline_color", Color("172033"))
	status_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(status_label)
	instruction_label = Label.new()
	instruction_label.anchor_left = 0.5
	instruction_label.anchor_right = 0.5
	instruction_label.anchor_top = 1.0
	instruction_label.anchor_bottom = 1.0
	instruction_label.offset_left = -340.0
	instruction_label.offset_right = 340.0
	instruction_label.offset_top = -48.0
	instruction_label.offset_bottom = -18.0
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 15)
	instruction_label.add_theme_color_override("font_outline_color", Color("172033"))
	instruction_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(instruction_label)
	prompt_label = Label.new()
	prompt_label.anchor_left = 1.0
	prompt_label.anchor_right = 1.0
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_left = -240.0
	prompt_label.offset_right = -24.0
	prompt_label.offset_top = -50.0
	prompt_label.offset_bottom = -18.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color("f4c96a"))
	prompt_label.add_theme_color_override("font_outline_color", Color("172033"))
	prompt_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(prompt_label)
	clock_label = Label.new()
	clock_label.anchor_left = 1.0
	clock_label.anchor_right = 1.0
	clock_label.offset_left = -160.0
	clock_label.offset_right = -24.0
	clock_label.offset_top = 24.0
	clock_label.offset_bottom = 52.0
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.add_theme_font_size_override("font_size", 18)
	clock_label.add_theme_color_override("font_outline_color", Color("172033"))
	clock_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(clock_label)
	mini_map = Label.new()
	mini_map.anchor_top = 1.0
	mini_map.anchor_bottom = 1.0
	mini_map.offset_left = 30.0
	mini_map.offset_right = 202.0
	mini_map.offset_top = -210.0
	mini_map.offset_bottom = -28.0
	mini_map.add_theme_font_size_override("font_size", 15)
	mini_map.add_theme_color_override("font_outline_color", Color("172033"))
	mini_map.add_theme_constant_override("outline_size", 5)
	mini_map.text = "┌────────┐\n│ ·  ▲ · │\n│ · ┼ ·  │\n│   ·    │\n└────────┘"
	layer.add_child(mini_map)
	status_bars = Label.new()
	status_bars.anchor_top = 1.0
	status_bars.anchor_bottom = 1.0
	status_bars.offset_left = 30.0
	status_bars.offset_right = 230.0
	status_bars.offset_top = -125.0
	status_bars.offset_bottom = -35.0
	status_bars.add_theme_font_size_override("font_size", 14)
	status_bars.add_theme_color_override("font_color", Color("d8e7d1"))
	status_bars.add_theme_color_override("font_outline_color", Color("172033"))
	status_bars.add_theme_constant_override("outline_size", 4)
	status_bars.text = "生命  ██████████\n体力  ████████░░"
	layer.add_child(status_bars)
	status_label.visible = false
	instruction_label.visible = false
	prompt_label.visible = false
	clock_label.visible = false
	mini_map.visible = false
	status_bars.visible = false
	hud_visual = GameHudVisualClass.new()
	hud_visual.name = "动作游戏 HUD 表现层"
	layer.add_child(hud_visual)
	pause_overlay = PauseOverlayClass.new()
	pause_overlay.name = "暂停菜单"
	pause_overlay.restart_requested.connect(_restart_current_scene)
	pause_overlay.menu_requested.connect(_return_to_launcher)
	pause_overlay.audio_toggled.connect(_on_audio_toggled)
	pause_overlay.audio_volume_changed.connect(_on_audio_volume_changed)
	add_child(pause_overlay)
	pause_overlay.apply_audio_settings(audio_events.enabled, audio_events.master_volume_db)
	failure_overlay = FailureOverlayClass.new()
	failure_overlay.name = "失败反馈"
	failure_overlay.restart_requested.connect(_restart_current_scene)
	failure_overlay.menu_requested.connect(_return_to_launcher)
	add_child(failure_overlay)

func _update_hud() -> void:
	var clock := "%02d:%02d" % [mission.clock_minutes / 60, mission.clock_minutes % 60]
	var state_text := "进行中"
	if mission.status == MissionState.Status.SUCCESS:
		state_text = "成功"
	elif mission.status == MissionState.Status.FAILED:
		state_text = "失败：" + mission.failure_reason
	var awareness := "未被发现"
	var visual_state := "clear"
	var visual_color := Color("e05252")
	if perception.status == PerceptionState.Status.SUSPICIOUS or npc_searching:
		awareness = "NPC正在搜索最后目击点" if npc_searching and perception.status != PerceptionState.Status.SUSPICIOUS else "上司产生怀疑"
		perception_marker.text = "?"
		perception_marker.modulate = Color("f0c752")
		perception_marker.visible = true
		if npc_alert_visual != null:
			npc_alert_visual.visible = true
			visual_state = "search" if npc_searching else "yellow"
			visual_color = Color("e6a74f") if npc_searching else Color("f0c752")
			_set_npc_alert_visual_state(visual_state, visual_color)
	elif perception.status == PerceptionState.Status.ALERT:
		awareness = "已被发现"
		perception_marker.text = "!"
		perception_marker.modulate = Color("e05252")
		perception_marker.visible = true
		if npc_alert_visual != null:
			npc_alert_visual.visible = true
			visual_state = "red"
			_set_npc_alert_visual_state(visual_state, visual_color)
	else:
		perception_marker.text = ""
		perception_marker.visible = false
		if npc_alert_visual != null:
			npc_alert_visual.visible = false
			_set_npc_alert_visual_state(visual_state, visual_color)
	var suspicion_ratio := clampf(perception.suspicion, 0.0, 1.0)
	if npc_alert_visual != null:
		npc_alert_visual.set_meta("mission_failed", mission.status == MissionState.Status.FAILED)
	var prompt := ""
	if typing_mode:
		prompt = "E  离开工位"
	elif _nearest_workstation() != null:
		prompt = "E  " + _nearest_workstation().prompt
	elif objective_target != null and objective_target.can_interact(player.global_position):
		prompt = "E  " + objective_target.prompt
	var hud_signature := "%s|%s|%s|%s|%.2f|%s" % [mission.objective, clock, state_text, awareness, suspicion_ratio, prompt]
	var last_hud_signature := ""
	for event in trace.events:
		if event.get("type") == "hud_state":
			last_hud_signature = str(event.get("payload", {}).get("signature", ""))
	if hud_signature != last_hud_signature:
		trace.record("hud_state", {"signature": hud_signature})
	status_label.text = "%s\n%s  %s\n%s" % [mission.objective, clock, state_text, awareness]
	clock_label.text = clock
	instruction_label.text = "WASD / 左摇杆移动   Shift / 左摇杆按压冲刺   鼠标 / 方向键 / 右摇杆镜头   C 蹲伏   E 完成交互   F 冲突   Space / LB 闪避   V 上下车   R 重试   L 读取存档   Esc / Start 暂停"
	prompt_label.text = prompt
	if not runtime_message.is_empty():
		instruction_label.text += "\n" + runtime_message
	if hud_visual != null:
		var objective_distance := 0.0
		var radar_points: Array[Vector2] = []
		var radar_point_colors: Array[Color] = []
		if player != null and objective_target != null:
			objective_distance = player.global_position.distance_to(objective_target.global_position)
			radar_points.append(_radar_point_for_world(objective_target.global_position))
			radar_point_colors.append(Color("f3d47b"))
		if player != null and npc != null:
			radar_points.append(_radar_point_for_world(npc.global_position))
			radar_point_colors.append(Color("e05252"))
		hud_visual.apply_state({
			"mode": "office",
			"objective": mission.objective,
			"clock": clock,
			"state": state_text,
			"awareness": awareness,
			"suspicion_ratio": suspicion_ratio,
			"distance": "%dm" % roundi(objective_distance),
			"prompt": prompt,
			"life_ratio": 1.0,
			"stamina_ratio": 0.82,
			"radar_heading": player.rotation.y if player != null else 0.0,
			"radar_points": radar_points,
			"radar_point_colors": radar_point_colors
		})
	_sync_office_runtime_visual_state()

func _sync_office_runtime_visual_state() -> void:
	# 采集态由 prepare_reference_capture 明确指定分段；普通游玩则由真实
	# 交互、感知、潜伏和空间位置驱动视觉层，避免出现“截图有状态、游戏没状态”。
	if reference_capture_mode or office_scene_visuals == null or player == null:
		return
	var state_id := "office-01"
	var source := "office_idle"
	if typing_mode:
		state_id = "office-10"
		source = "workstation_typing"
	elif hallway_encounter_active:
		state_id = "office-09" if player.crouching else "office-08"
		source = "hallway_encounter"
	elif perception.status == PerceptionState.Status.ALERT:
		state_id = "office-04"
		source = "perception_alert"
	elif npc_searching or player.crouching:
		state_id = "office-02"
		source = "cover_or_search"
	elif player.global_position.x > 5.5 and player.global_position.z < -4.0:
		state_id = "office-07"
		source = "stair_area"
	elif objective_target != null:
		var objective_distance := player.global_position.distance_to(objective_target.global_position)
		if objective_distance <= 1.8:
			state_id = "office-06"
			source = "elevator_interaction"
		elif objective_distance <= 4.5:
			state_id = "office-05"
			source = "elevator_approach"
		elif player.global_position.z < -4.5:
			state_id = "office-03"
			source = "office_transition"
	office_scene_visuals.apply_runtime_state(state_id, source)
	var awareness := "clear"
	if perception.status == PerceptionState.Status.ALERT:
		awareness = "red"
	elif npc_searching:
		awareness = "search"
	elif perception.status == PerceptionState.Status.SUSPICIOUS:
		awareness = "yellow"
	office_scene_visuals.apply_runtime_context({
		"awareness": awareness,
		"hallway_encounter": hallway_encounter_active,
		"typing": typing_mode,
		"mission_failed": mission.status == MissionState.Status.FAILED
	})
	# 普通候选试玩也必须随着真实任务状态切换分段背景；否则 office-02
	# 之后虽然有新的构图节点，远景仍会错误地停留在 office-01。
	if bool(get_meta("candidate_video_backdrop", false)):
		var backdrop_changed := str(get_meta("candidate_video_backdrop_id", "")) != state_id
		set_meta("candidate_video_backdrop_id", state_id)
		if backdrop_changed:
			_apply_candidate_video_backdrop()

func _radar_point_for_world(world_position: Vector3, max_distance := 18.0) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var delta := world_position - player.global_position
	var forward := -player.global_transform.basis.z.normalized()
	var right := player.global_transform.basis.x.normalized()
	return Vector2(
		clampf(delta.dot(right) / max_distance, -1.0, 1.0),
		clampf(-delta.dot(forward) / max_distance, -1.0, 1.0)
	)

func _on_mission_state_changed(_previous_status: int, _current_status: int) -> void:
	if launch_checkpoint_pending:
		return
	trace.record("mission_state", {"status": mission.status, "reason": mission.failure_reason})
	if mission.status == MissionState.Status.SUCCESS:
		trace.record("mission_completed", {})
		var campaign_state := get_node_or_null("/root/CampaignState")
		if campaign_state != null and campaign_state.has_method("mark_office_completed"):
			var campaign_saved: bool = campaign_state.mark_office_completed({"money": 0, "stars": 1})
			trace.record("campaign_office_completed", {"saved": campaign_saved, "reason": campaign_state.last_error})
		audio_events.emit_event("mission_success", {})
		if hud_visual != null and hud_visual.has_method("trigger_feedback"):
			hud_visual.trigger_feedback(Color("8fe0a2"), 0.28, 0.38)
		if camera_rig != null and camera_rig.has_method("pulse_feedback"):
			camera_rig.pulse_feedback(0.14, 0.18, 14.0)
		# 成功结算必须立即写入检查点，避免玩家完成首发垂直切片后因
		# 崩溃、退出或下一次启动而丢失最终任务状态。保存失败仍通过
		# 运行时消息、轨迹和音频事件显式暴露，不能静默回退。
		if not save_store.save_checkpoint(mission, perception, player.position, camera_rig.snapshot(), vehicle.snapshot(), office_pack_id):
			runtime_message = "存档失败：" + save_store.last_error
			trace.record("save_failed", {"operation": "mission_success", "reason": save_store.last_error})
			audio_events.emit_event("save_failed", {"reason": save_store.last_error})
	elif mission.status == MissionState.Status.FAILED:
		if hud_visual != null and hud_visual.has_method("trigger_feedback"):
			hud_visual.trigger_feedback(Color("e05252"), 0.42, 0.55)
		if camera_rig != null and camera_rig.has_method("pulse_feedback"):
			camera_rig.pulse_feedback(0.30, 0.28, 12.0)
		player.trigger_presentation_action("fail")
		failure_overlay.show_failure(mission.failure_reason)
		trace.record("mission_failed", {"reason": mission.failure_reason})
		audio_events.emit_event("mission_failed", {"reason": mission.failure_reason})
		if not save_store.save_checkpoint(mission, perception, player.position, camera_rig.snapshot(), vehicle.snapshot(), office_pack_id):
			runtime_message = "存档失败：" + save_store.last_error
			trace.record("save_failed", {"operation": "save", "reason": save_store.last_error})
			audio_events.emit_event("save_failed", {"reason": save_store.last_error})
	var replay_file := FileAccess.open("user://reference_last_replay.json", FileAccess.WRITE)
	if replay_file != null:
		replay_file.store_string(replay_tape.to_json())
		replay_file.flush()
		replay_file.close()
		replay_file = null
	trace.save("user://office_last_trace.json")

func _on_perception_status_changed(_previous_status: int, current_status: int) -> void:
	trace.record("perception_state", {"status": current_status, "suspicion": perception.suspicion})
	if current_status == PerceptionState.Status.SUSPICIOUS:
		audio_events.emit_event("perception_suspicious", {})
		if hud_visual != null and hud_visual.has_method("trigger_feedback"):
			hud_visual.trigger_feedback(Color("f0c752"), 0.18, 0.24)
	elif current_status == PerceptionState.Status.ALERT:
		audio_events.emit_event("perception_alert", {})
		if hud_visual != null and hud_visual.has_method("trigger_feedback"):
			hud_visual.trigger_feedback(Color("e05252"), 0.34, 0.34)

func _on_audio_event_emitted(event_id: String, payload: Dictionary) -> void:
	trace.record("audio_event", {"id": event_id, "payload": payload})

func _restart_current_scene() -> void:
	var scene_tree := get_tree()
	if scene_tree.current_scene != null:
		scene_tree.reload_current_scene()
		return
	# 集成测试、编辑器预览和嵌入式宿主可能只把场景挂到树上，
	# 此时没有 SceneTree.current_scene，仍应沿用真实场景文件重载路径。
	if not scene_file_path.is_empty():
		scene_tree.change_scene_to_file(scene_file_path)

func _return_to_launcher() -> void:
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")

func _on_audio_toggled(enabled: bool) -> void:
	audio_events.enabled = enabled
	settings_store.save_audio_settings(audio_events.enabled, audio_events.master_volume_db)

func _on_audio_volume_changed(volume_db: float) -> void:
	audio_events.set_master_volume_db(volume_db)
	settings_store.save_audio_settings(audio_events.enabled, audio_events.master_volume_db)

func _can_npc_see_player() -> bool:
	if player.crouching:
		return false
	var observer := npc.global_position + Vector3.UP * 0.7
	var target := player.global_position + Vector3.UP * 0.7
	var excluded: Array[RID] = [player.get_rid()]
	var observer_forward := -npc.global_transform.basis.z
	var runtime_config: Dictionary = office_pack.get("runtime", {})
	var perception_config: Dictionary = runtime_config.get("perception", {})
	var max_distance := float(perception_config.get("max_distance", 7.0))
	var field_of_view := float(perception_config.get("field_of_view_degrees", 110.0))
	return perception.is_visible_from(observer, target, get_world_3d().direct_space_state, max_distance, field_of_view, excluded, observer_forward)

func _box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	return mesh_instance

func _build_npc_alert_visual(parent: Node3D) -> Node3D:
	# 这是感知状态的纯视觉提示，不参与视线检测、碰撞、导航或任务判定。
	var alert_root := Node3D.new()
	alert_root.name = "NPC警觉视觉层"
	alert_root.set_meta("visual_only", true)
	alert_root.set_meta("state_color", "clear")
	alert_root.visible = false
	parent.add_child(alert_root)
	var beam_specs := [
		{"name": "NPC警觉视线主束", "size": Vector3(0.16, 0.025, 2.8), "position": Vector3(0.0, 0.32, -1.45), "rotation": 0.0},
		{"name": "NPC警觉视线左束", "size": Vector3(0.12, 0.025, 2.2), "position": Vector3(-0.46, 0.32, -1.22), "rotation": -13.0},
		{"name": "NPC警觉视线右束", "size": Vector3(0.12, 0.025, 2.2), "position": Vector3(0.46, 0.32, -1.22), "rotation": 13.0},
	]
	for beam_spec in beam_specs:
		var beam := _box_mesh(beam_spec["size"], Color("e05252"))
		beam.name = str(beam_spec["name"])
		beam.position = beam_spec["position"]
		beam.rotation_degrees.y = float(beam_spec["rotation"])
		beam.set_meta("visual_only", true)
		var beam_material := StandardMaterial3D.new()
		beam_material.albedo_color = Color(0.88, 0.32, 0.28, 0.24)
		beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = beam_material
		alert_root.add_child(beam)
	var ring := MeshInstance3D.new()
	ring.name = "NPC警觉脚下范围环"
	ring.set_meta("visual_only", true)
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.62
	ring_mesh.bottom_radius = 0.62
	ring_mesh.height = 0.018
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, -0.84, 0.0)
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.88, 0.32, 0.28, 0.22)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	alert_root.add_child(ring)
	var search_ring := MeshInstance3D.new()
	search_ring.name = "NPC警觉搜索扫描环"
	search_ring.set_meta("visual_only", true)
	var search_ring_mesh := CylinderMesh.new()
	search_ring_mesh.top_radius = 0.84
	search_ring_mesh.bottom_radius = 0.84
	search_ring_mesh.height = 0.012
	search_ring.mesh = search_ring_mesh
	search_ring.position = Vector3(0.0, -0.82, 0.0)
	var search_ring_material := StandardMaterial3D.new()
	search_ring_material.albedo_color = Color(0.90, 0.58, 0.20, 0.18)
	search_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	search_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	search_ring.material_override = search_ring_material
	search_ring.visible = false
	alert_root.add_child(search_ring)
	return alert_root

func _build_npc_last_seen_marker() -> Node3D:
	# 最后目击点是运行时反馈层，不拥有感知、任务、碰撞或存档状态。
	var marker := Node3D.new()
	marker.name = "NPC最后目击点标记"
	marker.set_meta("visual_only", true)
	marker.set_meta("state_source", "perception.last_seen_position")
	marker.visible = false

	var ring := MeshInstance3D.new()
	ring.name = "最后目击点扫描环"
	ring.set_meta("visual_only", true)
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.55
	ring_mesh.bottom_radius = 0.55
	ring_mesh.height = 0.014
	ring.mesh = ring_mesh
	ring.position.y = 0.03
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.96, 0.67, 0.22, 0.68)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	marker.add_child(ring)

	var beacon := MeshInstance3D.new()
	beacon.name = "最后目击点信标"
	beacon.set_meta("visual_only", true)
	var beacon_mesh := BoxMesh.new()
	beacon_mesh.size = Vector3(0.07, 0.48, 0.07)
	beacon.mesh = beacon_mesh
	beacon.position.y = 0.27
	var beacon_material := StandardMaterial3D.new()
	beacon_material.albedo_color = Color(1.0, 0.78, 0.30, 0.78)
	beacon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon.material_override = beacon_material
	marker.add_child(beacon)
	return marker

func _set_npc_alert_visual_state(state_name: String, color: Color) -> void:
	if npc_alert_visual == null:
		return
	npc_alert_visual.set_meta("state_color", state_name)
	var search_ring := npc_alert_visual.get_node_or_null("NPC警觉搜索扫描环") as MeshInstance3D
	if search_ring != null:
		search_ring.visible = state_name == "search"
	for child in npc_alert_visual.get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).material_override as StandardMaterial3D
			if material != null:
				material.albedo_color = Color(color.r, color.g, color.b, material.albedo_color.a)

func _update_npc_last_seen_marker(delta: float) -> void:
	if npc_last_seen_marker == null:
		return
	var is_active := npc_searching and not npc_search_target.is_equal_approx(Vector3.ZERO)
	npc_last_seen_marker.visible = is_active
	if not is_active:
		return
	npc_last_seen_marker_phase = fmod(npc_last_seen_marker_phase + delta * 3.2, TAU)
	var target := npc_search_target
	npc_last_seen_marker.global_position = Vector3(target.x, 0.0, target.z)
	npc_last_seen_marker.rotation.y = npc_last_seen_marker_phase
	var pulse := 1.0 + sin(npc_last_seen_marker_phase * 1.6) * 0.08
	npc_last_seen_marker.scale = Vector3.ONE * pulse
	npc_last_seen_marker.set_meta("last_seen_position", [target.x, target.y, target.z])

func _hide_graybox_environment_visuals() -> void:
	# 候选环境只接管渲染层；灰盒碰撞体、导航边界和任务节点继续保留。
	var preserve_roots := {
		"音频事件路由": true,
		"电梯目标": true,
		"走廊突遇NPC": true,
		"Visual": true,
	}
	for child in get_children():
		if preserve_roots.has(str(child.name)):
			continue
		_hide_graybox_visual_nodes(child)

func _hide_graybox_visual_nodes(root: Node) -> void:
	# 运行时会隐藏灰盒渲染层，但候选视觉层可能与灰盒节点同属一个场景树。
	# 以显式元数据作为边界，避免把已接入的原创贴图/几何候选一并隐藏。
	if bool(root.get_meta("visual_candidate", false)) or bool(root.get_meta("visual_only", false)):
		return
	if root is MeshInstance3D or root is Label3D:
		(root as Node3D).visible = false
	for child in root.get_children():
		_hide_graybox_visual_nodes(child)

func _capsule_mesh(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.8
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	return mesh_instance

func _character_visual(jacket_color: Color, pants_color: Color, backpack_color: Color, with_backpack: bool = true) -> Node3D:
	var visual := Node3D.new()
	visual.name = "原创灰盒角色外观"
	var torso := _box_mesh(Vector3(0.68, 0.82, 0.42), jacket_color)
	visual.add_child(torso)
	var shirt_panel := _box_mesh(Vector3(0.44, 0.58, 0.06), Color("e7e1d6"))
	shirt_panel.position = Vector3(0.0, 0.02, -0.235)
	visual.add_child(shirt_panel)
	var lapel_left := _box_mesh(Vector3(0.09, 0.40, 0.045), jacket_color.lightened(0.16))
	lapel_left.position = Vector3(-0.15, 0.14, -0.275)
	lapel_left.rotation_degrees.z = -18.0
	visual.add_child(lapel_left)
	var lapel_right := _box_mesh(Vector3(0.09, 0.40, 0.045), jacket_color.lightened(0.16))
	lapel_right.position = Vector3(0.15, 0.14, -0.275)
	lapel_right.rotation_degrees.z = 18.0
	visual.add_child(lapel_right)
	var tie := _box_mesh(Vector3(0.075, 0.34, 0.045), Color("26364c"))
	tie.position = Vector3(0.0, -0.04, -0.285)
	visual.add_child(tie)
	var belt := _box_mesh(Vector3(0.62, 0.09, 0.46), Color("242b33"))
	belt.position = Vector3(0.0, -0.34, 0.0)
	visual.add_child(belt)
	# 先用可替换的程序化人体比例建立近景轮廓；正式模型接入后仍沿用同一 Visual 根节点契约。
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.12
		arm_mesh.height = 0.72
		arm.mesh = arm_mesh
		arm.rotation_degrees.z = 90.0
		arm.position = Vector3(side * 0.46, 0.0, 0.0)
		var arm_material := StandardMaterial3D.new()
		arm_material.albedo_color = jacket_color
		arm.material_override = arm_material
		visual.add_child(arm)
		var cuff := _box_mesh(Vector3(0.18, 0.13, 0.16), Color("e7e1d6"))
		cuff.position = Vector3(side * 0.72, -0.01, 0.0)
		visual.add_child(cuff)
		var hand := MeshInstance3D.new()
		var hand_mesh := SphereMesh.new()
		hand_mesh.radius = 0.14
		hand_mesh.height = 0.28
		hand.mesh = hand_mesh
		hand.position = Vector3(side * 0.84, -0.02, 0.0)
		var hand_material := StandardMaterial3D.new()
		hand_material.albedo_color = Color("c78c6a")
		hand.material_override = hand_material
		visual.add_child(hand)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.24
	head_mesh.height = 0.48
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.65, 0.0)
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("c78c6a")
	head.material_override = head_material
	head.scale = Vector3(0.92, 1.08, 0.96)
	visual.add_child(head)
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.10
	neck_mesh.bottom_radius = 0.12
	neck_mesh.height = 0.16
	var neck := MeshInstance3D.new()
	neck.name = "程序化角色颈部"
	neck.mesh = neck_mesh
	neck.position = Vector3(0.0, 0.45, 0.0)
	neck.material_override = head_material
	visual.add_child(neck)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.25
	hair_mesh.height = 0.5
	hair.mesh = hair_mesh
	hair.scale = Vector3(1.0, 0.42, 1.0)
	hair.position = Vector3(0.0, 0.82, -0.02)
	var hair_material := StandardMaterial3D.new()
	hair_material.albedo_color = Color("20232b")
	hair.material_override = hair_material
	visual.add_child(hair)
	var hair_back := _box_mesh(Vector3(0.42, 0.24, 0.16), Color("20232b"))
	hair_back.position = Vector3(0.0, 0.70, 0.18)
	visual.add_child(hair_back)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := SphereMesh.new()
		ear_mesh.radius = 0.065
		ear_mesh.height = 0.13
		ear.mesh = ear_mesh
		ear.position = Vector3(side * 0.235, 0.66, 0.0)
		ear.material_override = head_material
		visual.add_child(ear)
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.032
		eye_mesh.height = 0.064
		eye.mesh = eye_mesh
		eye.position = Vector3(side * 0.085, 0.72, -0.225)
		var eye_material := StandardMaterial3D.new()
		eye_material.albedo_color = Color("17191d")
		eye.material_override = eye_material
		visual.add_child(eye)
	var nose := _box_mesh(Vector3(0.07, 0.07, 0.12), head_material.albedo_color.lightened(0.05))
	nose.position = Vector3(0.0, 0.65, -0.255)
	visual.add_child(nose)
	for side in [-1.0, 1.0]:
		var leg := _box_mesh(Vector3(0.22, 0.72, 0.24), pants_color)
		leg.position = Vector3(side * 0.18, -0.68, 0.0)
		visual.add_child(leg)
		var shoe := _box_mesh(Vector3(0.28, 0.16, 0.42), Color("1b2028"))
		shoe.position = Vector3(side * 0.18, -1.08, -0.08)
		visual.add_child(shoe)
	if with_backpack:
		var backpack := _box_mesh(Vector3(0.52, 0.65, 0.18), backpack_color)
		backpack.position = Vector3(0.0, 0.06, 0.28)
		visual.add_child(backpack)
		for side in [-1.0, 1.0]:
			var strap := _box_mesh(Vector3(0.07, 0.58, 0.06), backpack_color.lightened(0.18))
			strap.position = Vector3(side * 0.20, 0.08, 0.16)
			strap.rotation_degrees.z = side * 8.0
			visual.add_child(strap)
		var badge := _box_mesh(Vector3(0.12, 0.13, 0.025), Color("e5bd69"))
		badge.position = Vector3(0.0, 0.15, -0.285)
		visual.add_child(badge)
	return visual

func _add_obstacle(position: Vector3, size: Vector3) -> void:
	var obstacle := StaticBody3D.new()
	obstacle.name = "灰盒隔断"
	obstacle.position = position
	add_child(obstacle)
	obstacle.add_child(_box_mesh(size, Color("77736c")))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	obstacle.add_child(shape)

func _catalog_slot_has_scene(slot_id: String) -> bool:
	for slot in asset_catalog.get("slots", []):
		if slot is Dictionary and str(slot.get("id", "")) == slot_id:
			return not str(slot.get("scene_path", "")).strip_edges().is_empty()
	return false

func _mount_internal_candidate_visual(parent: Node3D, scene: PackedScene, fallback: Node3D, visual_name: String) -> Node:
	if parent == null or fallback == null:
		return null
	if scene != null:
		var candidate: Node = scene.instantiate()
		if candidate != null:
			candidate.name = visual_name
			parent.add_child(candidate)
			if fallback.is_inside_tree():
				fallback.queue_free()
			else:
				fallback.free()
			return candidate
	parent.add_child(fallback)
	return fallback

func _add_office_desk(location: Vector3) -> void:
	# 第一轮 P0 视觉替换：使用项目原创程序化工位候选。
	# 候选场景自身包含近似碰撞和交互挂点；若资源被移除，继续使用旧灰盒，
	# 保证行为测试与启动器不会因为视觉候选缺失而中断。
	if OriginalOfficeDeskScene != null:
		var candidate := OriginalOfficeDeskScene.instantiate()
		if candidate != null:
			candidate.name = "办公桌"
			candidate.position = location
			add_child(candidate)
			return
	var desk := Node3D.new()
	desk.name = "办公桌"
	desk.position = location
	add_child(desk)
	desk.add_child(_box_mesh(Vector3(2.6, 0.12, 1.0), Color("9a7255")))
	var leg_a := _box_mesh(Vector3(0.12, 1.0, 0.12), Color("303846"))
	leg_a.position = Vector3(-1.05, -0.5, -0.35)
	desk.add_child(leg_a)
	var leg_b := _box_mesh(Vector3(0.12, 1.0, 0.12), Color("303846"))
	leg_b.position = Vector3(1.05, -0.5, -0.35)
	desk.add_child(leg_b)
	var monitor := _box_mesh(Vector3(0.65, 0.5, 0.08), Color("25334a"))
	monitor.position = Vector3(0.0, 0.42, 0.05)
	desk.add_child(monitor)
	var monitor_stand := _box_mesh(Vector3(0.08, 0.28, 0.08), Color("4b4e52"))
	monitor_stand.position = Vector3(0.0, 0.16, 0.05)
	desk.add_child(monitor_stand)
	var keyboard := _box_mesh(Vector3(0.42, 0.025, 0.18), Color("d5d0c8"))
	keyboard.position = Vector3(0.0, 0.1, 0.36)
	desk.add_child(keyboard)
	var chair := _box_mesh(Vector3(0.52, 0.08, 0.52), Color("34383d"))
	chair.position = Vector3(0.0, -0.42, 0.72)
	desk.add_child(chair)
	var chair_back := _box_mesh(Vector3(0.52, 0.62, 0.08), Color("34383d"))
	chair_back.position = Vector3(0.0, -0.1, 0.94)
	desk.add_child(chair_back)

func _add_office_workstation_target(location: Vector3, index: int) -> void:
	# 工位交互点位于椅面后侧；它只负责把真实输入接入坐姿打字表现，
	# 不改变下班任务的电梯目标，也不参与NPC视线和碰撞判定。
	var workstation := InteractionTargetClass.new()
	workstation.name = "工位交互目标-%02d" % index
	workstation.interaction_id = "office_workstation_%02d" % index
	workstation.prompt = "坐下打字"
	workstation.interaction_radius = 1.35
	workstation.one_shot = false
	workstation.position = location + Vector3(0.0, 1.0, 1.05)
	workstation.set_meta("visual_only", true)
	add_child(workstation)
	workstation_targets.append(workstation)

func _nearest_workstation() -> InteractionTarget:
	if player == null or typing_mode:
		return null
	var nearest: InteractionTarget
	var nearest_distance := INF
	for workstation in workstation_targets:
		if workstation == null or not workstation.can_interact(player.global_position):
			continue
		var distance := workstation.global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			nearest = workstation
			nearest_distance = distance
	return nearest

func _enter_workstation_typing(workstation: InteractionTarget) -> void:
	if workstation == null or player == null or camera_rig == null:
		return
	active_workstation = workstation
	typing_saved_player_position = player.global_position
	typing_saved_player_rotation = player.rotation
	typing_saved_camera_distance = camera_rig.distance
	typing_saved_camera_height = camera_rig.height
	typing_saved_camera_shoulder = camera_rig.shoulder_offset
	typing_saved_camera_yaw = camera_rig.yaw_degrees
	typing_saved_camera_pitch = camera_rig.pitch_degrees
	typing_mode = true
	player.velocity = Vector3.ZERO
	player.crouching = false
	player.global_position = workstation.global_position
	player.rotation_degrees.y = 0.0
	# 近景构图由正式相机状态机持有，而不是由截图脚本临时摆拍。
	# 参考 office-10 的主体是人物、键盘和椅面接触线；候选镜头不能过近俯视，
	# 否则桌面会吞掉角色。保持侧后方中近景，给人物和工位接触关系留出空间，
	# 只改变表现层镜头，不改变玩家根节点、碰撞、交互挂点或存档坐标。
	var typing_distance := float(typing_camera_config.get("distance", 1.60))
	var typing_height := float(typing_camera_config.get("height", 1.22))
	var typing_yaw := float(typing_camera_config.get("yaw_degrees", 98.0))
	var typing_pitch := float(typing_camera_config.get("pitch_degrees", -6.0))
	var typing_shoulder_value = typing_camera_config.get("shoulder_offset", [0.70, 0.02, 0.28])
	# MakeHuman 只在隔离视觉候选采集中使用更近的主体镜头，避免把候选
	# 调参写回正式内容包。交互点、玩家坐标、碰撞和任务状态仍保持同一合同。
	if OS.get_environment("REFERENCE_MATRIX_PROFILE").strip_edges() == "makehuman-office-candidate":
		# 候选角色比例较大时，1.55 米会把人物推到画面前景，吞掉桌面、
		# 键盘和显示器。拉到中近景，让人物与工位接触线同时可读；这只
		# 作用于隔离候选采集态，不改变正式内容包的普通游玩镜头。
		typing_distance = 2.05
		typing_height = 1.42
		typing_yaw = 90.0
		typing_pitch = -8.0
		typing_shoulder_value = [0.45, 0.02, 0.14]
	var typing_shoulder: Array = typing_shoulder_value if typing_shoulder_value is Array else [0.70, 0.02, 0.28]
	if typing_shoulder.size() != 3:
		typing_shoulder = [0.70, 0.02, 0.28]
	camera_rig.set_follow_profile(typing_distance, typing_height)
	camera_rig.set_shoulder_offset(Vector3(float(typing_shoulder[0]), float(typing_shoulder[1]), float(typing_shoulder[2])))
	camera_rig.set_orbit(typing_yaw, typing_pitch)
	var driven := AssetRuntimeCatalogClass.drive_animation_state(player_visual_root, "typing_default")
	trace.record("workstation_typing_enter", {
		"target": workstation.interaction_id,
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"camera": camera_rig.snapshot(),
		"camera_contract": {
			"distance": typing_distance,
			"height": typing_height,
			"yaw_degrees": typing_yaw,
			"pitch_degrees": typing_pitch,
			"shoulder_offset": [float(typing_shoulder[0]), float(typing_shoulder[1]), float(typing_shoulder[2])]
		},
		"animation": driven
	})

func _exit_workstation_typing() -> void:
	if not typing_mode or player == null or camera_rig == null:
		return
	var exited_target := active_workstation.interaction_id if active_workstation != null else ""
	typing_mode = false
	active_workstation = null
	player.global_position = typing_saved_player_position
	player.rotation = typing_saved_player_rotation
	player.velocity = Vector3.ZERO
	camera_rig.set_follow_profile(typing_saved_camera_distance, typing_saved_camera_height)
	camera_rig.set_shoulder_offset(typing_saved_camera_shoulder)
	camera_rig.set_orbit(typing_saved_camera_yaw, typing_saved_camera_pitch)
	# 退出工位时一次性消化进入/退出交互动作的短暂表现锁，
	# 否则紧接着蹲伏会被残留的 interact_default 覆盖一帧。
	player.sync_presentation_state(0.5)
	trace.record("workstation_typing_exit", {
		"target": exited_target,
		"player_position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"camera": camera_rig.snapshot()
	})

func _add_office_shell() -> void:
	# 用暖色墙体、玻璃窗和踢脚线建立参考视频中的封闭办公空间。
	_add_obstacle(Vector3(0.0, 2.1, -10.5), Vector3(22.0, 4.2, 0.35))
	_add_obstacle(Vector3(-10.8, 2.1, 0.0), Vector3(0.35, 4.2, 22.0))
	_add_obstacle(Vector3(10.8, 2.1, 0.0), Vector3(0.35, 4.2, 22.0))
	# 吊顶只承担视觉层，遮住天空回退并建立办公室顶面尺度；不创建碰撞或导航边界。
	var ceiling := _box_mesh(Vector3(21.0, 0.16, 21.0), Color("ded8ce"))
	ceiling.name = "原创办公室吊顶视觉层"
	ceiling.position = Vector3(0.0, 4.05, 0.0)
	var ceiling_material := StandardMaterial3D.new()
	# 参考画面是暖暗办公空间；吊顶保持受光材质，避免整片无材质白块吞掉灯具和格栅层次。
	ceiling_material.albedo_color = Color("b9b0a5")
	ceiling_material.roughness = 0.94
	ceiling_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	ceiling_material.emission_enabled = true
	ceiling_material.emission = Color("756b62")
	ceiling_material.emission_energy_multiplier = 0.10
	ceiling.material_override = ceiling_material
	add_child(ceiling)
	for z in [-8.5, -5.5, -2.5, 0.5, 3.5, 6.5]:
		var ceiling_joint := _box_mesh(Vector3(20.8, 0.035, 0.045), Color("b4a99d"))
		ceiling_joint.name = "原创办公室吊顶格栅横梁"
		ceiling_joint.position = Vector3(0.0, 3.955, z)
		add_child(ceiling_joint)
	for x in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0]:
		var ceiling_cross := _box_mesh(Vector3(0.045, 0.035, 20.8), Color("b4a99d"))
		ceiling_cross.name = "原创办公室吊顶格栅纵梁"
		ceiling_cross.position = Vector3(x, 3.95, 0.0)
		add_child(ceiling_cross)
	var window_positions := [-7.2, -3.6, 0.0, 3.6, 7.2]
	for x in window_positions:
		var window := _box_mesh(Vector3(2.6, 1.6, 0.06), Color("9eb7bf"))
		window.position = Vector3(x, 2.5, -10.28)
		var window_material := StandardMaterial3D.new()
		window_material.albedo_color = Color("9eb7bf")
		window_material.roughness = 0.22
		window_material.emission_enabled = true
		window_material.emission = Color("b9d4da")
		window_material.emission_energy_multiplier = 0.22
		window.material_override = window_material
		var frame_top := _box_mesh(Vector3(2.75, 0.08, 0.12), Color("d8c9b9"))
		frame_top.position = Vector3(x, 3.34, -10.2)
		add_child(window)
		add_child(frame_top)
		var frame_bottom := _box_mesh(Vector3(2.75, 0.08, 0.12), Color("d8c9b9"))
		frame_bottom.position = Vector3(x, 1.66, -10.2)
		add_child(frame_bottom)
		var frame_left := _box_mesh(Vector3(0.08, 1.75, 0.12), Color("d8c9b9"))
		frame_left.position = Vector3(x - 1.32, 2.5, -10.2)
		add_child(frame_left)
		var frame_right := _box_mesh(Vector3(0.08, 1.75, 0.12), Color("d8c9b9"))
		frame_right.position = Vector3(x + 1.32, 2.5, -10.2)
		add_child(frame_right)
	var trim := _box_mesh(Vector3(21.2, 0.12, 0.12), Color("c0aa91"))
	trim.position = Vector3(0.0, 0.26, -10.25)
	add_child(trim)

func _add_office_visual_detail_pass() -> void:
	# 纯可见层细节：不创建碰撞、导航、任务或交互节点。
	# 这些元素让办公室从“几何灰盒”过渡到可审阅的原创中等细节候选，
	# 同时保持可撤回、可替换和不影响行为回放的边界。
	for z in [-8.8, -7.6, -6.4, -5.2, -4.0, -2.8, -1.6, -0.4, 0.8, 2.0, 3.2, 4.4, 5.6, 6.8, 8.0]:
		var aisle_marker := _office_visual_box("原创办公室地面导视", Vector3(1.35, 0.018, 0.34), Vector3(0.0, 0.115, z), Color("716b65"))
		add_child(aisle_marker)
		var aisle_inlay := _office_visual_box("原创办公室地面导视内嵌线", Vector3(0.92, 0.021, 0.035), Vector3(0.0, 0.128, z), Color("c1a16f"))
		add_child(aisle_inlay)
	for x in [-9.85, 9.85]:
		var side_baseboard := _office_visual_box("原创办公室侧墙踢脚线", Vector3(0.08, 0.34, 20.0), Vector3(x, 0.43, 0.0), Color("a18f7f"))
		add_child(side_baseboard)
	for x in [-8.8, -5.5, -2.2, 1.1, 4.4, 7.7]:
		var rear_panel := _office_visual_box("原创办公室后墙分格", Vector3(0.055, 2.35, 0.08), Vector3(x, 1.65, -10.29), Color("b7a38e"))
		add_child(rear_panel)
	for x in [-8.7, 8.7]:
		_add_office_plant(Vector3(x, 0.18, -7.4 if x < 0.0 else -6.4))
	for x in [-6.8, -3.4, 3.4, 6.8]:
		var ceiling_glow := _office_visual_box("原创办公室吊顶发光分区", Vector3(0.42, 0.025, 0.18), Vector3(x, 3.87, 1.9), Color("f7dcae"), true)
		add_child(ceiling_glow)

func _add_office_foreground_detail_pass() -> void:
	# 纯表现层的第二轮补强：用屏风、桌面设备和局部暖光建立前中后景，
	# 让肩后镜头能读出真实办公空间，而不是只有几排孤立几何体。
	var foreground_locations := [
		Vector3(-4.8, 0.86, 1.48), Vector3(0.0, 0.86, 1.48), Vector3(4.8, 0.86, 1.48),
		Vector3(-4.8, 0.86, -3.82), Vector3(4.8, 0.86, -3.82)
	]
	for location_index in range(foreground_locations.size()):
		var location: Vector3 = foreground_locations[location_index]
		var screen := _office_visual_box("原创办公室工位半高屏风", Vector3(2.30, 0.86, 0.07), location, Color("68757a"))
		screen.name = "原创办公室工位半高屏风-%02d" % location_index
		screen.set_meta("visual_only", true)
		add_child(screen)
		var screen_trim := _office_visual_box("原创办公室工位屏风金属压条", Vector3(2.08, 0.035, 0.025), location + Vector3(0.0, 0.34, -0.05), Color("b7a58f"))
		screen_trim.name = "原创办公室工位屏风金属压条-%02d" % location_index
		screen_trim.set_meta("visual_only", true)
		add_child(screen_trim)
		for side_index in range(2):
			var side := -1.0 if side_index == 0 else 1.0
			var monitor_glow := _office_visual_box("原创办公室工位屏幕微光", Vector3(0.34, 0.20, 0.018), location + Vector3(side * 0.48, 0.47, -0.10), Color("9bb9b2"), true)
			monitor_glow.name = "原创办公室工位屏幕微光-%02d-%02d" % [location_index, side_index]
			monitor_glow.set_meta("visual_only", true)
			add_child(monitor_glow)
	var wall_positions := [-10.26, 10.26]
	for wall_index in range(wall_positions.size()):
		var wall_x: float = wall_positions[wall_index]
		for index in range(4):
			var acoustic_panel := _office_visual_box("原创办公室侧墙吸音板", Vector3(0.045, 0.68, 1.22), Vector3(wall_x, 1.45, -6.6 + float(index) * 3.45), Color("746c68" if index % 2 == 0 else "877d72"))
			acoustic_panel.name = "原创办公室侧墙吸音板-%02d-%02d" % [wall_index, index]
			acoustic_panel.set_meta("visual_only", true)
			add_child(acoustic_panel)
	var light_locations := [Vector3(-6.9, 1.05, 1.55), Vector3(6.9, 1.05, 1.55), Vector3(-6.9, 1.05, -3.75), Vector3(6.9, 1.05, -3.75)]
	for light_index in range(light_locations.size()):
		var location: Vector3 = light_locations[light_index]
		var desk_light := OmniLight3D.new()
		desk_light.name = "原创办公室工位暖光-%02d" % light_index
		desk_light.position = location + Vector3(0.0, 1.10, -0.28)
		desk_light.light_color = Color("f2c98e")
		desk_light.light_energy = 0.16
		desk_light.omni_range = 2.2
		desk_light.shadow_enabled = false
		desk_light.set_meta("visual_only", true)
		add_child(desk_light)

func _add_office_composition_pass() -> void:
	# 纯视觉构图层：用地面材质分区、墙面色带和出口色温建立可读的空间层级。
	# 不创建碰撞、导航、任务或交互节点；它只服务于肩后镜头中的前进方向和场景识别。
	var carpet_runner := _office_visual_box("原创办公室中央地毯分区", Vector3(4.6, 0.016, 15.8), Vector3(0.0, 0.112, -0.15), Color("3f4b52"))
	carpet_runner.set_meta("visual_only", true)
	carpet_runner.set_meta("candidate_visual_only", true)
	add_child(carpet_runner)
	var carpet_index := 0
	for z in [-7.2, -4.0, -0.8, 2.4, 5.6]:
		var carpet_inlay := _office_visual_box("原创办公室地毯分区暖色压线", Vector3(3.8, 0.022, 0.035), Vector3(0.0, 0.13, z), Color("c29a63"), true)
		carpet_inlay.name = "原创办公室地毯分区暖色压线-%02d" % carpet_index
		carpet_inlay.set_meta("visual_only", true)
		carpet_inlay.set_meta("candidate_visual_only", true)
		add_child(carpet_inlay)
		carpet_index += 1
	var wall_band_index := 0
	for x in [-8.9, -5.7, -2.5, 0.7, 3.9, 7.1]:
		var wall_band := _office_visual_box("原创办公室后墙暖色分区带", Vector3(2.45, 0.08, 0.055), Vector3(x, 2.02, -10.31), Color("a77c67" if int(abs(x)) % 2 == 0 else "6f8790"))
		wall_band.name = "原创办公室后墙暖色分区带-%02d" % wall_band_index
		wall_band.set_meta("visual_only", true)
		wall_band.set_meta("candidate_visual_only", true)
		add_child(wall_band)
		wall_band_index += 1
	var exit_marker := _office_visual_box("原创办公室出口暖色识别灯", Vector3(1.5, 0.035, 0.08), Vector3(0.0, 2.88, -10.16), Color("f0bd69"), true)
	exit_marker.set_meta("visual_only", true)
	exit_marker.set_meta("candidate_visual_only", true)
	add_child(exit_marker)

func _office_visual_box(node_name: String, size: Vector3, at: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var node := _box_mesh(size, color)
	node.name = node_name
	node.set_meta("visual_candidate", true)
	if emissive:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.8
		material.roughness = 0.38
		node.material_override = material
	node.position = at
	return node

func _add_office_plant(at: Vector3) -> void:
	var plant := Node3D.new()
	plant.name = "原创办公室绿植候选"
	plant.set_meta("visual_candidate", true)
	plant.position = at
	add_child(plant)
	var pot := _office_visual_box("原创办公室绿植花盆", Vector3(0.42, 0.38, 0.42), Vector3(0.0, 0.18, 0.0), Color("6f5547"))
	plant.add_child(pot)
	for index in range(5):
		var leaf := MeshInstance3D.new()
		leaf.name = "原创办公室绿植叶片"
		leaf.set_meta("visual_candidate", true)
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.18
		leaf_mesh.height = 0.64
		leaf.mesh = leaf_mesh
		leaf.scale = Vector3(0.7, 1.0, 0.25)
		leaf.position = Vector3((float(index) - 2.0) * 0.10, 0.64 + float(index % 2) * 0.10, 0.0)
		leaf.rotation_degrees = Vector3(0.0, float(index) * 28.0, (float(index) - 2.0) * 12.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("4c7658").lightened(float(index) * 0.025)
		material.roughness = 0.82
		leaf.material_override = material
		plant.add_child(leaf)

func _add_ceiling_lights() -> void:
	for x in [-7.2, -3.6, 0.0, 3.6, 7.2]:
		var light_panel := _office_visual_box("原创办公室暖白顶灯前排", Vector3(2.1, 0.06, 0.32), Vector3(x, 3.85, -1.5), Color("fff1d0"), true)
		add_child(light_panel)
		_add_office_omni_light(Vector3(x, 3.56, -1.5))
		var rear_panel := _office_visual_box("原创办公室暖白顶灯后排", Vector3(2.1, 0.06, 0.32), Vector3(x, 3.85, 5.6), Color("fff1d0"), true)
		add_child(rear_panel)
		_add_office_omni_light(Vector3(x, 3.56, 5.6))

func _add_office_omni_light(location: Vector3) -> void:
	# 吊顶灯只负责室内照明表现，不参与碰撞、导航或任务判定。
	var light := OmniLight3D.new()
	light.name = "办公室暖白吊顶灯"
	light.position = location
	light.light_color = Color("ffe5c4")
	light.light_energy = 0.62
	light.omni_range = 5.8
	light.shadow_enabled = false
	add_child(light)

func _add_stairwell() -> void:
	var stairwell := Node3D.new()
	stairwell.name = "楼梯出口"
	stairwell.position = Vector3(7.0, 0.0, -6.0)
	add_child(stairwell)
	var elevator_bank := Node3D.new()
	elevator_bank.name = "电梯组"
	elevator_bank.position = Vector3(0.0, 0.0, -0.85)
	stairwell.add_child(elevator_bank)
	# 参考段 office-06 的主体是电梯厅；这里先用原创灰盒建立门缝、门框、楼层牌
	# 和呼叫面板的构图契约，最终材质和动画仍由资产阶段替换。
	var elevator_back := _box_mesh(Vector3(3.2, 2.8, 0.12), Color("5d626d"))
	elevator_back.position = Vector3(0.0, 1.4, -0.08)
	elevator_bank.add_child(elevator_back)
	_add_generated_office_elevator_facade(elevator_bank)
	# 导视牌只承担视觉层：用原创几何线条表达楼层与方向，不创建文字交互、碰撞或导航。
	var wayfinding_panel := _box_mesh(Vector3(1.02, 0.34, 0.05), Color("20262d"))
	wayfinding_panel.name = "原创电梯厅楼层导视"
	wayfinding_panel.position = Vector3(0.0, 2.48, -0.29)
	elevator_bank.add_child(wayfinding_panel)
	for row in range(3):
		var guide_line := _box_mesh(Vector3(0.60 - row * 0.10, 0.018, 0.018), Color("c8bda9"))
		guide_line.name = "原创电梯导视线"
		guide_line.position = Vector3(-0.10, 2.56 - row * 0.085, -0.325)
		elevator_bank.add_child(guide_line)
	var guide_arrow := _box_mesh(Vector3(0.18, 0.035, 0.02), Color("d2a65b"))
	guide_arrow.name = "原创电梯导视方向箭头"
	guide_arrow.position = Vector3(0.31, 2.56, -0.33)
	elevator_bank.add_child(guide_arrow)
	for x in [-0.82, 0.82]:
		var door := _box_mesh(Vector3(1.45, 2.35, 0.08), Color("353b46"))
		door.position = Vector3(x, 1.25, -0.16)
		elevator_bank.add_child(door)
		var door_frame := _box_mesh(Vector3(1.56, 0.08, 0.12), Color("b6a894"))
		door_frame.position = Vector3(x, 2.47, -0.2)
		elevator_bank.add_child(door_frame)
	var center_seam := _box_mesh(Vector3(0.06, 2.32, 0.1), Color("b6a894"))
	center_seam.position = Vector3(0.0, 1.25, -0.22)
	elevator_bank.add_child(center_seam)
	var call_panel := _box_mesh(Vector3(0.22, 0.48, 0.08), Color("252b34"))
	call_panel.position = Vector3(1.78, 1.2, -0.22)
	elevator_bank.add_child(call_panel)
	var call_button := _box_mesh(Vector3(0.08, 0.08, 0.04), Color("e8b84a"))
	call_button.position = Vector3(1.78, 1.32, -0.27)
	elevator_bank.add_child(call_button)
	_add_label_3d("电梯 11", stairwell.position + elevator_bank.position + Vector3(0.0, 2.7, -0.25), Color("d8d0c2"))
	for index in range(6):
		var step := _box_mesh(Vector3(2.2, 0.18, 0.5), Color("4b596e"))
		step.position = Vector3(0.0, 0.09 + index * 0.18, -index * 0.5)
		stairwell.add_child(step)
	_add_label_3d("楼梯", stairwell.position + Vector3(0.0, 1.5, 0.4), Color("b7c3d8"))

func _add_hallway_npc() -> void:
	var office_config: Dictionary = office_pack.get("runtime", {}).get("office", {})
	hallway_npc = Node3D.new()
	hallway_npc.name = "走廊突遇NPC"
	hallway_npc.position = _hallway_route_start(office_config)
	add_child(hallway_npc)
	var hallway_fallback := _character_visual(Color("6d7ca8"), Color("2f3544"), Color("252b3a"), false)
	if _catalog_slot_has_scene("office-npc-set"):
		AssetRuntimeCatalogClass.mount_optional_visual(hallway_npc, asset_catalog, "office-npc-set", hallway_fallback)
	else:
		# 正式空目录入口也使用项目原创候选表现，避免走廊遭遇仍显示单色灰盒；
		# 候选仍只拥有视觉与动画，不接管感知、任务、碰撞或存档状态。
		_mount_internal_candidate_visual(hallway_npc, OriginalOfficeNpcScene, hallway_fallback, "Visual")
	_add_label_3d("走廊巡查", hallway_npc.position + Vector3(0.0, 1.55, 0.0), Color("b7c3d8"))

func _update_hallway_encounter(delta: float) -> void:
	if hallway_npc == null or mission.status != MissionState.Status.ACTIVE:
		return
	hallway_patrol_phase = fmod(hallway_patrol_phase + delta * 0.55, TAU)
	var patrol_progress := (sin(hallway_patrol_phase) + 1.0) * 0.5
	var hallway_route := _hallway_route()
	hallway_npc.position = hallway_route[0].lerp(hallway_route[1], patrol_progress)
	AssetRuntimeCatalogClass.drive_animation_state(hallway_npc, "walk_default")
	var distance := player.global_position.distance_to(hallway_npc.global_position)
	if distance <= hallway_trigger_radius and not hallway_encounter_active:
		hallway_encounter_active = true
		runtime_message = "走廊突然有人"
		trace.record("hallway_encounter", {"distance": snappedf(distance, 0.01), "crouching": player.crouching})
		audio_events.emit_event("hallway_encounter", {"crouching": player.crouching})
		if not player.crouching:
			mission.fail("走廊突遇")
	elif distance > hallway_clear_radius:
		hallway_encounter_active = false

func _hallway_route(config: Dictionary = {}) -> Array[Vector3]:
	var office_config := config
	if office_config.is_empty():
		office_config = office_pack.get("runtime", {}).get("office", {})
	var raw_route = office_config.get("hallway_route", [[7.0, 0.9, -7.0], [7.0, 0.9, -2.0]])
	var route: Array[Vector3] = []
	if raw_route is Array:
		for raw_point in raw_route:
			if raw_point is Array and raw_point.size() == 3:
				route.append(_vector_from_payload(raw_point, Vector3.ZERO))
	if route.size() < 2:
		return [Vector3(7.0, 0.9, -7.0), Vector3(7.0, 0.9, -2.0)]
	return route

func _hallway_route_start(config: Dictionary = {}) -> Vector3:
	return _hallway_route(config)[0]

func _vector_from_payload(raw_position, fallback: Vector3) -> Vector3:
	if raw_position is Array and raw_position.size() == 3:
		return Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	return fallback

func _update_npc_search(delta: float) -> void:
	if npc == null or mission.status != MissionState.Status.ACTIVE:
		_clear_npc_search()
		return
	if perception.status == PerceptionState.Status.ALERT:
		_clear_npc_search()
		return
	if npc_search_phase == "idle":
		if perception.status != PerceptionState.Status.SUSPICIOUS:
			return
		var last_known_position := perception.last_known_position()
		npc_search_target = Vector3(last_known_position.x, npc.global_position.y, last_known_position.z)
		npc_search_phase = "investigate"
		npc_searching = true
		trace.record("npc_search_started", {"last_seen_position": [npc_search_target.x, npc_search_target.y, npc_search_target.z], "stimulus": "noise" if perception.last_heard_strength > 0.0 else "sight"})
		audio_events.emit_event("npc_search_started", {})

	match npc_search_phase:
		"investigate":
			if _move_npc_search_actor(npc_search_target, delta):
				npc_search_phase = "hold"
				npc_search_hold_remaining = NPC_SEARCH_HOLD_DURATION
				trace.record("npc_search_reached", {"last_seen_position": [npc_search_target.x, npc_search_target.y, npc_search_target.z]})
				audio_events.emit_event("npc_search_reached", {})
		"hold":
			npc.look_at(Vector3(npc_search_target.x, npc.global_position.y, npc_search_target.z), Vector3.UP)
			npc_search_hold_remaining = maxf(npc_search_hold_remaining - maxf(delta, 0.0), 0.0)
			if npc_search_hold_remaining <= 0.0:
				npc_search_phase = "return"
				trace.record("npc_search_return_started", {"home_position": [npc_home_position.x, npc_home_position.y, npc_home_position.z]})
				audio_events.emit_event("npc_search_return_started", {})
		"return":
			if _move_npc_search_actor(npc_home_position, delta):
				npc.position = npc_home_position
				npc.rotation.y = npc_home_rotation_y
				npc_search_phase = "idle"
				npc_searching = false
				trace.record("npc_search_finished", {"home_position": [npc_home_position.x, npc_home_position.y, npc_home_position.z]})
				audio_events.emit_event("npc_search_finished", {})
				perception.reset()

func _move_npc_search_actor(target: Vector3, delta: float) -> bool:
	var flat_target := Vector3(target.x, npc.global_position.y, target.z)
	var offset := flat_target - npc.global_position
	var distance := offset.length()
	if distance <= NPC_SEARCH_REACH_RADIUS:
		return true
	var step := minf(distance, npc_search_speed * maxf(delta, 0.0))
	if step <= 0.0:
		return false
	npc.global_position += offset.normalized() * step
	npc.look_at(Vector3(flat_target.x, npc.global_position.y, flat_target.z), Vector3.UP)
	return npc.global_position.distance_to(flat_target) <= NPC_SEARCH_REACH_RADIUS

func _clear_npc_search() -> void:
	npc_search_phase = "idle"
	npc_search_hold_remaining = 0.0
	npc_search_target = Vector3.ZERO
	npc_searching = false
	if npc != null and not npc_home_position.is_equal_approx(Vector3.ZERO):
		npc.position = npc_home_position
		npc.rotation.y = npc_home_rotation_y

func _update_npc_presentation() -> void:
	if npc == null:
		return
	var state_name := "idle_default"
	if perception.status == PerceptionState.Status.ALERT:
		state_name = "alert_default"
	elif npc_searching:
		state_name = "search_default"
	AssetRuntimeCatalogClass.drive_animation_state(npc, state_name)

func _add_label_3d(text: String, location: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "标识-" + text
	label.text = text
	label.position = location
	label.modulate = color
	label.font_size = 42
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _hide_debug_labels_for_capture() -> void:
	for node in find_children("", "Label3D", true, false):
		if node is Label3D:
			node.visible = false

extends Node3D

const MissionChainClass = preload("res://scripts/mission_chain.gd")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const ReferencePlayerClass = preload("res://scripts/player_controller.gd")
const InteractionTargetClass = preload("res://scripts/interaction_target.gd")
const VehicleClass = preload("res://scripts/vehicle_controller.gd")
const PedestrianClass = preload("res://scripts/city_pedestrian.gd")
const TrafficVehicleClass = preload("res://scripts/city_traffic_vehicle.gd")
const InventoryStateClass = preload("res://scripts/inventory_state.gd")
const SaveStoreClass = preload("res://scripts/save_store.gd")
const ConflictStateClass = preload("res://scripts/conflict_state.gd")
const WantedStateClass = preload("res://scripts/wanted_state.gd")
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
const CitySceneVisualsClass = preload("res://scripts/city_scene_visuals.gd")
const RuntimeBootStatusClass = preload("res://scripts/runtime_boot_status.gd")
const OriginalCityCrowdScene = preload("res://assets/characters/original-procedural-city-crowd/original_procedural_city_crowd_candidate.tscn")
const OriginalCityVehicleScene = preload("res://assets/vehicles/three-wheel-delivery/three_wheel_delivery_candidate.tscn")
const OriginalCityEnvironmentScene = preload("res://assets/environment/original-procedural-city-environment/original_city_environment_candidate.tscn")
const OriginalPlayerScene = preload("res://assets/characters/original-procedural-office-characters/original_player_candidate.tscn")
const OriginalInteractionPropsScene = preload("res://assets/props/original-procedural-interaction-props/original_interaction_props_candidate.tscn")
const AuthorizedCity01BackdropTexture := preload("res://assets/environment/generated/city_storefront_crowd_v3_generated.png")
const OriginalCity08BackdropTexture := preload("res://assets/environment/generated/city_drive_lane_dusk_v1_generated.png")
const AuthorizedCity01VideoTexturePath := "res://assets/reference-video-candidate/city-01-video-playable-backdrop-v2.png"
const AuthorizedCity02VideoTexturePath := "res://assets/reference-video-candidate/city-02-video-playable-backdrop-v1.png"
const AuthorizedCity03VideoTexturePath := "res://assets/reference-video-candidate/city-03-video-playable-backdrop-v1.png"
const AuthorizedCity04VideoTexturePath := "res://assets/reference-video-candidate/city-04-video-playable-backdrop-v1.png"
const AuthorizedCity05VideoTexturePath := "res://assets/reference-video-candidate/city-05-video-playable-backdrop-v1.png"
const AuthorizedCity06VideoTexturePath := "res://assets/reference-video-candidate/city-06-video-playable-backdrop-v1.png"
const AuthorizedCity07VideoTexturePath := "res://assets/reference-video-candidate/city-07-video-playable-backdrop-v1.png"
const AuthorizedCity08VideoTexturePath := "res://assets/reference-video-candidate/city-08-video-playable-backdrop-v1.png"
const AuthorizedCity09VideoTexturePath := "res://assets/reference-video-candidate/city-09-video-playable-backdrop-v1.png"
const AuthorizedCity10VideoTexturePath := "res://assets/reference-video-candidate/city-10-video-playable-backdrop-v1.png"
const AuthorizedCity11VideoTexturePath := "res://assets/reference-video-candidate/city-11-video-playable-backdrop-v1.png"
const OriginalCityVehicleDriverSpriteTexture := preload("res://assets/vehicles/three-wheel-delivery/vehicle_driver_sprite_v1.png")
const ORIGINAL_CITY_CROWD_FOOT_OFFSET := 1.075
const CITY_SIGNAL_CYCLE_SECONDS := 12.0

const DEFAULT_CITY_PACK_ID := "city-free-eggs-v1"
# 保留稳定的测试/工具访问名；实际运行使用 city_pack_id，以支持启动器内容包选择。
const CITY_PACK_ID := DEFAULT_CITY_PACK_ID

var player: ReferencePlayer
var vehicle: ReferenceVehicle
var mission: MissionChain
var inventory: InventoryState
var save_store: SaveStore
var settings_store: RefCounted
var conflict: ConflictState
var wanted: RefCounted
var conflict_trigger_radius := 2.4
var conflict_damage_radius := 1.35
var conflict_pursuit_speed := 1.8
var conflict_escape_distance := 8.5
var conflict_escape_hold_seconds := 0.9
var conflict_escape_bonus := 20
var conflict_defeat_bonus := 30
var conflict_dodge_window_seconds := 0.42
var conflict_dodge_cooldown_seconds := 0.70
var conflict_escape_progress := 0.0
var conflict_escape_bonus_awarded := false
var conflict_encounter_armed := false
var dodge_cooldown_timer := 0.0
var dodge_lock := false
var dodge_feedback_lock := false
var conflict_hit_feedback_timer := 0.0
var vehicle_camera_distance := 5.2
var vehicle_camera_height := 2.8
var vehicle_camera_pitch_degrees := -12.0
var vehicle_camera_yaw_degrees := 0.0
var vehicle_camera_previous_yaw := 0.0
var vehicle_camera_previous_pitch := -18.0
var vehicle_camera_state_saved := false
var vehicle_damage_per_speed := 3.5
var vehicle_integrity := 100.0
var vehicle_collision_cooldown := 0.0
var vehicle_damage_phase := 0.0
var conflict_agent: Node3D
var trace: TraceRecorder
var targets: Array[InteractionTarget] = []
var side_activity_target: InteractionTarget
var side_activity_id := ""
var side_activity_label := ""
var side_activity_unlock_after := ""
var side_activity_reward := 0
var side_activity_completed := false
var side_activity_unlocked := false
var side_activity_accepted := false
var side_activity_delivery_label := ""
var side_activity_delivery_target: InteractionTarget
var side_activity_runtimes: Array[Dictionary] = []
var pedestrians: Array[CityPedestrian] = []
var traffic_vehicles: Array[Node3D] = []
var police_vehicles: Array[Node3D] = []
var city_environment_visual: Node
var candidate_video_backdrop: MeshInstance3D
var city_signal_elapsed := 0.0
var city_story_light_elapsed := 0.0
var city_story_lights: Array[Dictionary] = []
var crowd_blockers: Array[StaticBody3D] = []
var visual_crowd_root: Node3D
var crowd_home_positions: Array[Vector3] = []
var crowd_displaced := false
var crowd_avoidance_count := 0
var last_crowd_avoidance_count := -1
var pedestrian_near_miss_cooldown := 0.0
var police_siren_cooldown := 0.0
var police_capture_cooldown := 0.0
var police_escape_timer := 0.0
var police_escape_hold_seconds := 1.5
var inside_store_aisle := false
var hud_label: Label
var hint_label: Label
var prompt_label: Label
var mini_map: Label
var hud_visual: Control
var mission_title_label: Label
var money_label: Label
var wanted_label: Label
var vehicle_status_label: Label
var cargo_visual: MeshInstance3D
var vehicle_damage_visual: MeshInstance3D
var vehicle_damage_side_visual: MeshInstance3D
var vehicle_damage_warning_visual: MeshInstance3D
var vehicle_damage_smoke: Array[MeshInstance3D] = []
var vehicle_wheels: Array[MeshInstance3D] = []
var vehicle_visual_handles_damage_feedback := false
var vehicle_driver_sprite: Sprite3D
var vehicle_lock := false
var restart_lock := false
var load_lock := false
var registered := false
var message := ""
var attack_lock := false
var last_hud_signature := ""
var camera_rig: ThirdPersonCameraRig
var pending_camera_look := Vector2.ZERO
var audio_events: AudioEventRouter
var locomotion_audio_cooldown := 0.0
var vehicle_audio_cooldown := 0.0
var pause_overlay: PauseOverlay
var failure_overlay: FailureOverlay
var city_pack: Dictionary = {}
var city_pack_id := DEFAULT_CITY_PACK_ID
var initialized := false
var reference_capture_mode := false
var asset_catalog: Dictionary = {}
var launch_checkpoint_pending := false
var city_environment: WorldEnvironment
var city_sun: DirectionalLight3D
var city_sky_material: ProceduralSkyMaterial
var city_reference_backdrop: TextureRect
var city_reference_world_backdrop: MeshInstance3D
var weather_effect_root: Node3D
var weather_profile := "day"
var neighborhood_status := "locked"
var neighborhood_entry := Vector3(11.5, 0.9, -11.5)
var city_scene_visuals: Node3D

func _ready() -> void:
	RuntimeBootStatusClass.write("starting", "city")
	var launch_context := get_node_or_null("/root/LaunchContext")
	var launch_request: Dictionary = {}
	if launch_context != null and launch_context.has_method("consume_request"):
		launch_request = launch_context.consume_request("res://scenes/city.tscn")
	mission = MissionChainClass.new()
	inventory = InventoryStateClass.new()
	var launch_save_path := str(launch_request.get("checkpoint_path", ""))
	var configured_save_path := str(get_meta("save_path", launch_save_path if not launch_save_path.is_empty() else "user://city_checkpoint.json"))
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
		_show_boot_error("城市资产无法加载", ", ".join(asset_errors))
		return
	if asset_catalog_path.ends_with("asset-runtime-catalog-full-candidates.json") or asset_catalog_path.ends_with("asset-runtime-catalog-original-only.json"):
		# 完整候选和原创边界候选城市试玩使用用户授权的 AI 视频帧作为首店远景层；
		# 行走、载具、行人、冲突、任务和存档仍由真实城市运行时负责。
		# 原创边界候选必须保持同一试玩入口，否则城市段会退回无法验收的灰盒。
		set_meta("candidate_video_backdrop", true)
		set_meta("candidate_gameplay_video_backdrop", true)
		set_meta("candidate_video_backdrop_id", "city-01")
	conflict = ConflictStateClass.new()
	wanted = WantedStateClass.new()
	trace = TraceRecorderClass.new()
	audio_events = AudioEventRouterClass.new()
	audio_events.name = "音频事件路由"
	audio_events.configure_for_asset_catalog(asset_catalog_path)
	audio_events.event_emitted.connect(_on_audio_event_emitted)
	add_child(audio_events)
	var audio_settings: Dictionary = settings_store.load_audio_settings()
	audio_events.enabled = bool(audio_settings.get("enabled", false))
	audio_events.set_master_volume_db(float(audio_settings.get("master_volume_db", -14.0)))
	city_pack_id = str(launch_request.get("content_pack_id", DEFAULT_CITY_PACK_ID)).strip_edges()
	if city_pack_id.is_empty():
		city_pack_id = DEFAULT_CITY_PACK_ID
	city_pack = ContentPackLoaderClass.load_registered_pack("city", city_pack_id)
	var city_errors := ContentPackLoaderClass.validate_pack(city_pack, "city")
	if not city_errors.is_empty():
		RuntimeBootStatusClass.write("failed", "city", "城市内容包校验失败：" + ", ".join(city_errors))
		push_error("城市内容包校验失败：" + ", ".join(city_errors))
		_show_boot_error("城市内容无法加载", ", ".join(city_errors))
		return
	var conflict_config: Dictionary = city_pack.get("runtime", {}).get("conflict", {})
	conflict.max_health = float(conflict_config.get("max_health", conflict.max_health))
	conflict.health = conflict.max_health
	conflict.damage_per_second = float(conflict_config.get("damage_per_second", conflict.damage_per_second))
	conflict.opponent_max_health = float(conflict_config.get("opponent_max_health", conflict.opponent_max_health))
	conflict.opponent_health = conflict.opponent_max_health
	conflict.player_attack_damage = float(conflict_config.get("player_attack_damage", conflict.player_attack_damage))
	conflict_dodge_window_seconds = clampf(float(conflict_config.get("dodge_window_seconds", conflict_dodge_window_seconds)), 0.05, 2.0)
	conflict_dodge_cooldown_seconds = maxf(float(conflict_config.get("dodge_cooldown_seconds", conflict_dodge_cooldown_seconds)), 0.0)
	conflict.dodge_window_seconds = conflict_dodge_window_seconds
	conflict_defeat_bonus = maxi(int(conflict_config.get("defeat_bonus", conflict_defeat_bonus)), 0)
	conflict_pursuit_speed = float(conflict_config.get("pursuit_speed", conflict_pursuit_speed))
	conflict_trigger_radius = float(conflict_config.get("trigger_radius", conflict_trigger_radius))
	conflict_damage_radius = float(conflict_config.get("damage_radius", conflict_damage_radius))
	conflict_escape_distance = maxf(float(conflict_config.get("escape_distance", conflict_escape_distance)), conflict_damage_radius + 1.0)
	conflict_escape_hold_seconds = maxf(float(conflict_config.get("escape_hold_seconds", conflict_escape_hold_seconds)), 0.1)
	conflict_escape_bonus = maxi(int(conflict_config.get("escape_bonus", conflict_escape_bonus)), 0)
	wanted.configure(city_pack.get("runtime", {}).get("wanted", {}))
	wanted.level_changed.connect(_on_wanted_level_changed)
	conflict.status_changed.connect(_on_conflict_status_changed)
	mission.configure(ContentPackLoaderClass.stages_from_payload(city_pack))
	mission.stage_changed.connect(_on_stage_changed)
	mission.completed.connect(_on_mission_completed)
	mission.failed.connect(_on_mission_failed)
	inventory.changed.connect(_on_inventory_changed)
	_build_environment()
	city_scene_visuals = CitySceneVisualsClass.new()
	city_scene_visuals.name = "城市十一状态原创视觉层"
	add_child(city_scene_visuals)
	_build_player()
	_build_targets()
	_build_vehicle()
	_build_pedestrians()
	_build_traffic()
	_build_hud()
	_apply_candidate_video_backdrop()
	var visual_profile_config: Dictionary = city_pack.get("runtime", {}).get("visual_profiles", {})
	var default_visual_profile := str(visual_profile_config.get("default", "day"))
	if not apply_visual_profile(default_visual_profile):
		push_error("城市内容包默认视觉配置无法应用：" + default_visual_profile)
	launch_checkpoint_pending = bool(launch_request.get("load_checkpoint", get_meta("load_checkpoint", false)))
	mission.start()
	_sync_side_activity_state()
	var campaign_state := get_node_or_null("/root/CampaignState")
	if campaign_state != null and campaign_state.has_method("mark_scene_started"):
		campaign_state.mark_scene_started("city")
	initialized = true
	RuntimeBootStatusClass.write("ready", "city", "城市场景、玩家、相机、任务、载具和输入循环已初始化")
	if launch_checkpoint_pending:
		call_deferred("_load_checkpoint_from_launcher")

func _show_boot_error(title: String, reason: String) -> void:
	RuntimeBootStatusClass.write("failed", "city", title + "：" + reason)
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
	var frame := InputFrameClass.from_keyboard()
	frame.look += pending_camera_look
	pending_camera_look = Vector2.ZERO
	process_input_frame(frame, delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pending_camera_look += event.relative
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		prepare_reference_capture()
		var capture_path := RuntimeCaptureClass.capture(get_viewport(), "city-current")
		trace.record("visual_capture", {"path": capture_path, "scene": "city"})

func prepare_reference_capture(reset_actor_state := true) -> void:
	"""冻结动态实体，确保同一场景的运行时截图可重复比较。"""
	reference_capture_mode = true
	pending_camera_look = Vector2.ZERO
	var use_original_environment_backdrops := OS.get_environment("REFERENCE_USE_ORIGINAL_ENVIRONMENT_BACKDROPS").strip_edges() == "1"
	# 参考采集在场景初始化后才进入冻结态；此时再执行一次视觉层清理，
	# 避免街道立面候选根节点以悬浮窗格形式盖在写实背景卡前面。
	_hide_graybox_environment_visuals()
	_hide_reference_vehicle_cover()
	if pause_overlay != null:
		pause_overlay.set_input_locked(true)
	if audio_events != null:
		audio_events.silence()
	if hint_label != null:
		hint_label.visible = false
	if hud_visual != null and hud_visual.has_method("clear_announcement"):
		hud_visual.clear_announcement()
	_hide_debug_labels_for_capture()
	for pedestrian in pedestrians:
		pedestrian.prepare_reference_capture()
	for traffic in traffic_vehicles:
		traffic.prepare_reference_capture()
	if reset_actor_state:
		player.position = Vector3(0.0, 1.0, 9.0)
		vehicle.position = Vector3(-6.0, 0.7, 5.0)
		vehicle.rotation = Vector3.ZERO
		vehicle.current_speed = 0.0
		if camera_rig != null:
			camera_rig.set_orbit(0.0, -18.0)
	# 矩阵场景会直接放置角色，必须在冻结前重新计算室内/室外镜头档位。
	_update_navigation_zone()
	if camera_rig != null:
		# 只在视觉采集冻结后应用分段专用镜头；正常游戏不强制改变玩家
		# 的镜头朝向，避免影响基于相机基准的移动输入和真实出口路径。
		if inside_store_aisle:
			# city-04 对应参考视频的店内冲突段：镜头应停在主角右后肩，
			# 看向前方冲突对象；统一使用 180° 会把镜头推到主角正面，
			# 造成身体占满画面并被裁切。其余店内段仍保持原镜头合同。
			var capture_scenario := str(get_meta("reference_capture_scenario", ""))
			camera_rig.set_orbit(0.0, -12.0) if capture_scenario == "city-04" else camera_rig.set_orbit(180.0, -12.0)
		else:
			var capture_yaw := float(get_meta("reference_capture_yaw", 0.0))
			var capture_pitch := float(get_meta("reference_capture_pitch", -18.0))
			camera_rig.set_orbit(capture_yaw, capture_pitch)
	if use_original_environment_backdrops:
		# 正式原创环境采集关闭旧视频帧，避免城市原创环境稿已接入但截图
		# 仍被授权视频覆盖的假完成状态。
		if candidate_video_backdrop != null:
			candidate_video_backdrop.visible = false
	else:
		_apply_candidate_video_backdrop()
	_hide_reference_geometry()
	var capture_scenario := str(get_meta("reference_capture_scenario", ""))
	if capture_scenario == "city-04":
		var store_roof := get_node_or_null("免费鸡蛋商店屋顶") as Node3D
		if store_roof != null:
			# 冻结阶段最后再关一次，避免区域切换在采集前把纯视觉屋顶恢复可见。
			store_roof.visible = false
		var store_fascia := get_node_or_null("免费鸡蛋商店门头") as Node3D
		if store_fascia != null:
			# 门头与屋顶同属店外立面，后肩店内冲突镜头不应被其横向体块压住。
			store_fascia.visible = false
		var story_awning := find_child("街区故事-免费鸡蛋遮阳棚", true, false) as Node3D
		if story_awning != null:
			# 该遮阳棚属于原创候选视觉层；city-04 的店内后肩镜头中会形成
			# 橙色横梁遮挡，只在采集态隐藏，不改变碰撞、导航或任务逻辑。
			story_awning.visible = false
	_apply_authorized_city_backdrop()
	if capture_scenario.begins_with("city-"):
		# 城市状态默认是白天；参考视频从离店段开始进入黄昏。
		# 采集态必须在冻结动态实体后再次绑定分段环境参数，避免场景
		# 初始化覆盖 _setup_city 已经选定的黄昏配置。该分支只影响
		# 参考采集，不改变普通游玩的任务、交通、碰撞、导航或存档逻辑。
		var capture_profile := "dusk" if capture_scenario in ["city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11"] else "day"
		apply_visual_profile(capture_profile)
	_apply_vehicle_driver_sprite_for_capture()
	# 城市每个参考分段都使用自己的原创空间构图层；该层只改变表现，
	# 不改变真实载具、交通、碰撞、任务、冲突或存档状态。
	if city_scene_visuals != null:
		city_scene_visuals.apply_state(capture_scenario if capture_scenario.begins_with("city-") else "city-01")
		if use_original_environment_backdrops and camera_rig != null and camera_rig.camera != null and city_scene_visuals.has_method("attach_capture_backdrop"):
			city_scene_visuals.call("attach_capture_backdrop", camera_rig.camera)
		if capture_scenario == "city-11":
			# 终点段的参考采集由当前源绑定的傍晚街景卡承接完整门面；
			# apply_state 会在冻结流程末尾重新创建 city-11 节点，因此
			# 这里必须再做一次表现层清理，不能只依赖前面的旧门面规则。
			_hide_descendant_visual_meshes(city_scene_visuals)
	if use_original_environment_backdrops:
		# 相机背景稿只承担连续环境；玩家、三轮车、冲突对象和交通人群
		# 仍必须由真实运行时网格覆盖在背景稿之上，避免出现“只有 HUD
		# 和一张环境图、没有可操作实体”的假游戏画面。
		_promote_capture_actor_visual(player)
		_promote_capture_actor_visual(vehicle)
		_promote_capture_actor_visual(conflict_agent)
		for pedestrian in pedestrians:
			_promote_capture_actor_visual(pedestrian)
		for traffic in traffic_vehicles:
			_promote_capture_actor_visual(traffic)
	trace.record("visual_capture_ready", {"scene": "city", "dynamic_entities_frozen": true})

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

func _apply_authorized_city_backdrop() -> void:
	# 正式逐帧验收只使用当前运行时的三维场景。写实背景卡保留在项目中
	# 作为美术方向参考，但不能覆盖相机视口或与角色、载具形成双重透视。
	if city_reference_backdrop != null:
		city_reference_backdrop.visible = false
	if city_reference_world_backdrop != null:
		city_reference_world_backdrop.visible = false

func _apply_candidate_video_backdrop() -> void:
	# 授权视频帧只提供远景像素，真实玩家、载具、行人、交通、碰撞、冲突、
	# 任务和存档仍由城市运行时驱动。分段镜头与普通试玩共用同一张卡，
	# 解决源码采集和候选包视觉分叉的问题。
	if not bool(get_meta("candidate_video_backdrop", false)) or camera_rig == null or camera_rig.camera == null:
		return
	var scenario_id := str(get_meta("reference_capture_scenario", ""))
	if scenario_id == "city-04":
		if candidate_video_backdrop != null:
			candidate_video_backdrop.visible = true
	var backdrop_id := scenario_id if scenario_id.begins_with("city-") else str(get_meta("candidate_video_backdrop_id", "city-01"))
	var backdrop_texture_path := AuthorizedCity01VideoTexturePath
	var backdrop_asset_source := "user_authorized_ai_video_frame_edit"
	# 每个城市分段使用自己的用户授权视频帧候选，避免不同镜头之间
	# 复用通用背景造成的透视、色温和空间语义错位。背景卡只补远景像素，
	# 玩家、载具、行人、碰撞、任务和 HUD 仍由真实运行时绘制。
	var city_video_texture_paths := {
		"city-01": AuthorizedCity01VideoTexturePath,
		"city-02": AuthorizedCity02VideoTexturePath,
		"city-03": AuthorizedCity03VideoTexturePath,
		"city-04": AuthorizedCity04VideoTexturePath,
		"city-05": AuthorizedCity05VideoTexturePath,
		"city-06": AuthorizedCity06VideoTexturePath,
		"city-07": AuthorizedCity07VideoTexturePath,
		"city-08": AuthorizedCity08VideoTexturePath,
		"city-09": AuthorizedCity09VideoTexturePath,
		"city-10": AuthorizedCity10VideoTexturePath,
		"city-11": AuthorizedCity11VideoTexturePath,
	}
	if city_video_texture_paths.has(backdrop_id):
		backdrop_texture_path = str(city_video_texture_paths[backdrop_id])
	# 普通候选试玩会在任务推进时重复调用本函数；同一分段不重新从磁盘
	# 读取图片，避免驾驶、登记和冲突状态同步造成持续图像分配。
	if candidate_video_backdrop != null and str(candidate_video_backdrop.get_meta("reference_segment", "")) == backdrop_id:
		candidate_video_backdrop.visible = true
		return
	var backdrop_image := Image.load_from_file(ProjectSettings.globalize_path(backdrop_texture_path))
	var backdrop_texture: Texture2D = ImageTexture.create_from_image(backdrop_image) if backdrop_image != null else null
	if backdrop_texture == null:
		return
	if candidate_video_backdrop == null:
		var mesh := QuadMesh.new()
		# 城市镜头的俯仰、跟拍距离和窗口安全区比办公室更宽；背景卡
		# 必须覆盖相机视锥边缘，否则会在正式 PNG 中露出灰色视口。
		# 卡片放在相机前方过近时，会与 city-04 的主角/冲突对象落在同一
		# 深度层，导致背景把前景演员遮掉；后移并放大后只承接远景像素，
		# 主角、冲突对象、载具和碰撞仍由真实运行时绘制在前面。
		mesh.size = Vector2(96.0, 56.0)
		candidate_video_backdrop = MeshInstance3D.new()
		candidate_video_backdrop.name = "用户授权城市视频帧候选背景卡"
		candidate_video_backdrop.mesh = mesh
		candidate_video_backdrop.position = Vector3(0.0, 0.0, -32.0)
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
		candidate_video_backdrop.set_meta("asset_source", backdrop_asset_source)
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
		_hide_city_video_occluders()

func _hide_city_video_occluders() -> void:
	# 只关闭环境渲染网格；角色、载具、行人和交通的渲染仍保留，所有物理
	# 和状态节点继续工作，保证这仍然是一款可玩的城市而不是视频播放器。
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		if mesh_node == candidate_video_backdrop:
			continue
		var is_actor_visual := (player != null and player.is_ancestor_of(mesh_node)) \
			or (vehicle != null and vehicle.is_ancestor_of(mesh_node))
		if not is_actor_visual:
			for pedestrian in pedestrians:
				if pedestrian != null and pedestrian.is_ancestor_of(mesh_node):
					is_actor_visual = true
					break
		if not is_actor_visual:
			for traffic in traffic_vehicles + police_vehicles:
				if traffic != null and traffic.is_ancestor_of(mesh_node):
					is_actor_visual = true
					break
		var is_runtime_scene_visual := bool(mesh_node.get_meta("visual_only", false)) and bool(mesh_node.get_meta("candidate_visual_only", false))
		if not is_actor_visual and not is_runtime_scene_visual and not bool(mesh_node.get_meta("candidate_background_backdrop", false)) and not bool(mesh_node.get_meta("visual_candidate", false)):
			(mesh_node as MeshInstance3D).visible = false

func process_input_frame(frame: InputFrame, delta: float) -> void:
	if reference_capture_mode:
		return
	frame.sanitize()
	trace.advance(delta)
	dodge_cooldown_timer = maxf(dodge_cooldown_timer - maxf(delta, 0.0), 0.0)
	conflict_hit_feedback_timer = maxf(conflict_hit_feedback_timer - maxf(delta, 0.0), 0.0)
	if not conflict.is_dodging():
		dodge_feedback_lock = false
	if frame.move.length_squared() > 0.0 or frame.look.length_squared() > 0.0 or frame.sprint or frame.crouch or frame.interact or frame.attack or frame.dodge or frame.vehicle_enter_exit or frame.restart or frame.load_checkpoint:
		trace.record("input", frame.to_dict())
	if camera_rig != null:
		camera_rig.apply_look(frame.look)
	if vehicle.driver == null:
		player.apply_input(frame, delta, camera_rig.global_transform.basis if camera_rig != null else Basis.IDENTITY)
		_update_locomotion_audio(delta)
		if player.last_motion_blocked:
			trace.record("collision", {"count": player.last_collision_count, "position": [player.global_position.x, player.global_position.y, player.global_position.z]})
	else:
		vehicle.apply_input(frame, delta)
		_update_vehicle_audio(delta)
		_check_vehicle_collisions(delta)
	_update_vehicle_wheel_visuals(delta)

	if frame.vehicle_enter_exit and not vehicle_lock:
		vehicle_lock = true
		player.trigger_presentation_action("vehicle")
		if vehicle.driver == null:
			if vehicle.enter(player):
				player.sync_presentation_state()
		else:
			if vehicle.exit():
				player.sync_presentation_state()
	elif not frame.vehicle_enter_exit:
		vehicle_lock = false

	if frame.dodge and not dodge_lock:
		dodge_lock = true
		if conflict.status in [ConflictState.Status.ENGAGED, ConflictState.Status.PURSUED]:
			if dodge_cooldown_timer <= 0.0 and conflict.begin_dodge(conflict_dodge_window_seconds):
				player.trigger_presentation_action("dodge")
				dodge_cooldown_timer = conflict_dodge_cooldown_seconds
				message = "闪避窗口已开启"
				trace.record("conflict_dodge", {"window": conflict_dodge_window_seconds})
				audio_events.emit_event("conflict_dodge", {"window": conflict_dodge_window_seconds})
				if camera_rig != null and camera_rig.has_method("pulse_feedback"):
					camera_rig.pulse_feedback(0.10, 0.06, 8.0)
				if hud_visual != null and hud_visual.has_method("trigger_feedback"):
					hud_visual.trigger_feedback(Color("75b6d0"), 0.18, 0.18)
			elif dodge_cooldown_timer > 0.0:
				message = "闪避冷却中"
	elif not frame.dodge:
		dodge_lock = false

	if frame.attack and not attack_lock and conflict_agent != null and conflict_agent.visible and player.global_position.distance_to(conflict_agent.global_position) <= conflict_trigger_radius:
		attack_lock = true
		if conflict.status == ConflictState.Status.CALM:
			conflict_encounter_armed = false
			conflict.trigger("街区冲突")
			if camera_rig != null and camera_rig.has_method("pulse_feedback"):
				camera_rig.pulse_feedback(0.22, 0.12, 18.0)
			wanted.report(2, "街区冲突")
			_displace_crowd()
			message = "冲突发生，靠近对手可按 F 反击，或拉开距离逃脱"
			audio_events.emit_event("conflict_started", {})
		else:
			player.trigger_presentation_action("attack")
			conflict.attack()
			var defeated := conflict.opponent_defeated
			trace.record("player_attack", {"damage": conflict.player_attack_damage, "opponent_health": conflict.opponent_health})
			audio_events.emit_event("player_attack", {"damage": conflict.player_attack_damage, "opponent_health": conflict.opponent_health})
			if camera_rig != null and camera_rig.has_method("pulse_feedback"):
				camera_rig.pulse_feedback(0.16, 0.08, 12.0)
			if hud_visual != null and hud_visual.has_method("trigger_feedback"):
				hud_visual.trigger_feedback(Color("f0c752"), 0.18, 0.16)
			if defeated:
				conflict_agent.visible = false
				conflict_encounter_armed = false
				conflict_escape_progress = 0.0
				conflict_escape_bonus_awarded = false
				mission.money += conflict_defeat_bonus
				message = "冲突压制，奖励 ¥%d" % conflict_defeat_bonus
				trace.record("conflict_defeated", {"bonus": conflict_defeat_bonus})
				audio_events.emit_event("interaction_success", {"id": "conflict_defeated", "bonus": conflict_defeat_bonus})
				if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
					hud_visual.announce("冲突压制 · +¥%d" % conflict_defeat_bonus, Color("8fe0a2"), 2.8)
			else:
				message = "反击命中，对手生命 %d" % roundi(conflict.opponent_health)
	elif not frame.attack:
		attack_lock = false

	if conflict.status == ConflictState.Status.ENGAGED:
		conflict.pursue()
	if conflict.status == ConflictState.Status.PURSUED and conflict_agent != null:
		var pursuit_offset: Vector3 = player.global_position - conflict_agent.global_position
		if pursuit_offset.length() > 0.1:
			conflict_agent.global_position += pursuit_offset.normalized() * delta * conflict_pursuit_speed
		var health_before := conflict.health
		var damage_avoided := conflict.tick(delta, pursuit_offset.length() < conflict_damage_radius)
		if damage_avoided and not dodge_feedback_lock:
			dodge_feedback_lock = true
			message = "闪避成功，未受伤"
			trace.record("conflict_dodge_success", {"health": conflict.health})
			audio_events.emit_event("conflict_dodge_success", {})
			if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
				hud_visual.announce("闪避成功", Color("75b6d0"), 1.2)
		if conflict.health < health_before and conflict_hit_feedback_timer <= 0.0:
			conflict_hit_feedback_timer = 0.24
			player.trigger_presentation_action("hit")
			trace.record("player_hit", {"health": conflict.health, "damage": health_before - conflict.health})
			audio_events.emit_event("player_hit", {"health": conflict.health, "damage": health_before - conflict.health})
			if hud_visual != null and hud_visual.has_method("trigger_feedback"):
				hud_visual.trigger_feedback(Color("e05252"), 0.20, 0.20)
		if conflict.status == ConflictState.Status.FAILED:
			message = "冲突失败：生命耗尽"
			mission.fail("冲突中倒下")
	_update_conflict_escape(delta)
	wanted.tick(delta, conflict.status == ConflictState.Status.ENGAGED or conflict.status == ConflictState.Status.PURSUED or not police_vehicles.is_empty())
	_update_conflict_presentation()

	var city_interaction_handled := false
	for target in targets:
		if target.interaction_id == _current_stage_id() and _try_city_interaction(target, frame):
			city_interaction_handled = true
			break
	if not city_interaction_handled and _try_side_activity_interaction(frame):
		city_interaction_handled = true
	if not city_interaction_handled and frame.interact:
		_try_vehicle_service_interaction(frame)

	if frame.restart and not restart_lock and mission.status != MissionChain.Status.ACTIVE:
		restart_lock = true
		# 先清理世界状态，再让任务状态机发出阶段变更并写入正确的起点存档。
		inventory.clear()
		registered = false
		message = ""
		player.position = Vector3(0.0, 1.0, 9.0)
		vehicle.position = Vector3(-6.0, 0.7, 5.0)
		vehicle.exit()
		if conflict_agent != null:
			conflict_agent.visible = true
		vehicle_integrity = 100.0
		for runtime_index in range(side_activity_runtimes.size()):
			var runtime: Dictionary = side_activity_runtimes[runtime_index]
			var cargo_item := str(runtime.get("cargo_item", ""))
			if not cargo_item.is_empty():
				inventory.remove_item(cargo_item, inventory.count(cargo_item))
			runtime["completed"] = false
			runtime["accepted"] = false
			runtime["unlocked"] = false
			side_activity_runtimes[runtime_index] = runtime
		side_activity_completed = false
		side_activity_accepted = false
		vehicle_collision_cooldown = 0.0
		neighborhood_status = "locked"
		_update_vehicle_damage_feedback()
		conflict.reset()
		dodge_cooldown_timer = 0.0
		dodge_lock = false
		dodge_feedback_lock = false
		conflict_hit_feedback_timer = 0.0
		conflict_encounter_armed = false
		conflict_escape_progress = 0.0
		conflict_escape_bonus_awarded = false
		wanted.reset()
		_clear_police_response()
		_reset_crowd()
		if conflict_agent != null:
			conflict_agent.position = Vector3(4.0, 0.9, -2.0)
		mission.restart()
		player.clear_failure_presentation()
		failure_overlay.hide_failure()
		trace.record("mission_restart", {})
		audio_events.emit_event("mission_restart", {})
		for target in targets:
			target.reset()
		_sync_side_activity_state()
	elif not frame.restart:
		restart_lock = false

	if frame.load_checkpoint and not load_lock:
		load_lock = true
		_load_city_checkpoint()
	elif not frame.load_checkpoint:
		load_lock = false

	_update_navigation_zone()
	_update_traffic_signal_logic(delta)
	_update_city_story_lights(delta)
	_update_police_response(delta)
	_update_crowd_traffic_avoidance()

	_update_hud()

func _update_crowd_traffic_avoidance() -> void:
	var active_count := 0
	for pedestrian in pedestrians:
		if is_instance_valid(pedestrian) and pedestrian.traffic_avoidance_active:
			active_count += 1
	crowd_avoidance_count = active_count
	if active_count == last_crowd_avoidance_count:
		return
	last_crowd_avoidance_count = active_count
	trace.record("crowd_traffic_avoidance", {"active_pedestrians": active_count})

func _update_traffic_signal_logic(delta: float) -> void:
	city_signal_elapsed = fmod(city_signal_elapsed + maxf(delta, 0.0), CITY_SIGNAL_CYCLE_SECONDS)
	var signal_red := city_signal_elapsed >= 7.5
	if is_instance_valid(city_environment_visual) and city_environment_visual.has_method("drive_visual_signal_phase"):
		city_environment_visual.drive_visual_signal_phase(city_signal_elapsed)
	for traffic in traffic_vehicles:
		if is_instance_valid(traffic) and traffic.has_method("set_signal_red"):
			traffic.set_signal_red(signal_red)

func _update_police_response(delta: float) -> void:
	police_siren_cooldown = maxf(police_siren_cooldown - maxf(delta, 0.0), 0.0)
	police_capture_cooldown = maxf(police_capture_cooldown - maxf(delta, 0.0), 0.0)
	if wanted == null or player == null:
		return
	var desired_count := 0
	if wanted.level >= 2:
		desired_count = 2 if wanted.level >= 3 else 1
	while police_vehicles.size() < desired_count:
		_spawn_police_vehicle(police_vehicles.size())
	if desired_count == 0 and not police_vehicles.is_empty():
		_clear_police_response()
		return
	if not police_vehicles.is_empty() and (inside_store_aisle or neighborhood_status == "active"):
		police_escape_timer += maxf(delta, 0.0)
		if police_escape_timer >= police_escape_hold_seconds:
			_clear_police_response()
			message = "已甩开警车，保持低调等待通缉衰减"
			trace.record("police_lost", {"hold_seconds": police_escape_timer})
			audio_events.emit_event("interaction_success", {"id": "police_lost"})
			if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
				hud_visual.announce("已甩开警车 · 保持低调", Color("8fe0a2"), 1.8)
		return
	police_escape_timer = 0.0
	var active_count := 0
	for police_index in range(police_vehicles.size()):
		var police := police_vehicles[police_index]
		if not is_instance_valid(police):
			continue
		active_count += 1
		if police.has_method("configure_pursuit"):
			police.configure_pursuit(player, 4.8 + police_index * 0.35)
		if player.global_position.distance_to(police.global_position) <= 2.1 and police_capture_cooldown <= 0.0:
			police_capture_cooldown = 3.0
			if vehicle != null and vehicle.driver != null:
				vehicle.exit()
			var capture_distance := player.global_position.distance_to(police.global_position)
			trace.record("police_intercept", {"wanted_level": wanted.level, "distance": capture_distance})
			trace.record("police_capture", {"wanted_level": wanted.level, "distance": capture_distance})
			message = "被警车抓住，任务失败"
			audio_events.emit_event("perception_alert", {"source": "警车拦截"})
			if mission != null and mission.status == MissionChain.Status.ACTIVE:
				mission.fail("被警车抓住")
			wanted.reset()
			_clear_police_response()
			return
	if active_count > 0 and police_siren_cooldown <= 0.0:
		police_siren_cooldown = 1.2
		audio_events.emit_event("perception_alert", {"source": "警笛", "wanted_level": wanted.level})

func _spawn_police_vehicle(index: int) -> void:
	if player == null:
		return
	var police := TrafficVehicleClass.new()
	police.name = "警车追捕-%d" % (index + 1)
	police.position = player.global_position + (Vector3(-10.0, 0.0, -6.0) if index == 0 else Vector3(10.0, 0.0, 6.0))
	police.add_police_body()
	add_child(police)
	police.configure_pursuit(player, 4.8 + index * 0.35)
	police_vehicles.append(police)
	trace.record("police_spawned", {"index": index, "wanted_level": wanted.level})

func _clear_police_response() -> void:
	for police in police_vehicles:
		if is_instance_valid(police):
			police.stop_pursuit()
			police.queue_free()
	police_vehicles.clear()
	police_siren_cooldown = 0.0
	police_capture_cooldown = 0.0
	police_escape_timer = 0.0
	trace.record("police_cleared", {})

func _update_locomotion_audio(delta: float) -> void:
	locomotion_audio_cooldown = maxf(locomotion_audio_cooldown - delta, 0.0)
	if audio_events == null or player == null or not player.is_on_floor():
		return
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if horizontal_speed <= 0.08 or locomotion_audio_cooldown > 0.0:
		return
	audio_events.emit_event("footstep", {"speed": horizontal_speed, "crouching": player.crouching})
	locomotion_audio_cooldown = 0.62 if player.crouching else 0.42

func _update_vehicle_audio(delta: float) -> void:
	vehicle_audio_cooldown = maxf(vehicle_audio_cooldown - delta, 0.0)
	if audio_events == null or vehicle == null or vehicle.driver == null:
		return
	var speed := absf(vehicle.current_speed)
	if speed <= 0.3 or vehicle_audio_cooldown > 0.0:
		return
	audio_events.emit_event("vehicle_engine", {"speed": speed})
	vehicle_audio_cooldown = 0.28

func _build_environment() -> void:
	city_environment = WorldEnvironment.new()
	var env := Environment.new()
	city_sky_material = ProceduralSkyMaterial.new()
	# 城市默认状态是白天；天顶保留蓝灰层次，地平线与地面改为偏中性
	# 的浅色，避免把白天场景渲染成棕色黄昏。这里只改视觉光照，不改变
	# 城市碰撞、导航、交通或任务状态。
	city_sky_material.sky_top_color = Color("355776")
	city_sky_material.sky_horizon_color = Color("c7c5bc")
	city_sky_material.ground_bottom_color = Color("353d3d")
	city_sky_material.ground_horizon_color = Color("a39d8e")
	city_sky_material.sun_angle_max = 18.0
	city_sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = city_sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.76
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.10
	env.ssao_enabled = true
	env.ssao_radius = 2.2
	env.ssao_intensity = 1.25
	env.fog_enabled = true
	env.fog_light_color = Color("aeb7b5")
	env.fog_light_energy = 0.12
	env.fog_density = 0.0009
	env.fog_height = 3.0
	env.fog_height_density = 0.018
	city_environment.environment = env
	add_child(city_environment)

	city_sun = DirectionalLight3D.new()
	city_sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	city_sun.light_energy = 0.82
	city_sun.light_color = Color("f6d7ae")
	city_sun.shadow_enabled = true
	city_sun.directional_shadow_max_distance = 48.0
	city_sun.shadow_bias = 0.035
	add_child(city_sun)

	_add_static_box("街区地面", Vector3(34.0, 0.2, 34.0), Vector3(0.0, -0.1, 0.0), Color("b7a98b"))
	_add_static_box("道路", Vector3(7.0, 0.04, 34.0), Vector3(0.0, 0.03, 0.0), Color("42474c"))
	_add_static_box("道路横向", Vector3(34.0, 0.04, 5.0), Vector3(0.0, 0.04, 0.0), Color("42474c"))
	if not _catalog_slot_has_scene("city-environment-kit"):
		_add_cc0_worn_asphalt_visuals()
	_add_road_visual_details()
	_add_city_composition_pass()
	_add_static_box("商店一", Vector3(8.0, 3.5, 4.0), Vector3(8.0, 1.75, -8.0), Color("d6c3a5"))
	_add_open_store("免费鸡蛋商店", Vector3(7.0, 3.0, 4.0), Vector3(-9.0, 1.5, -10.0), Color("c7d1c1"))
	_add_static_box("街边店铺", Vector3(5.0, 2.5, 4.0), Vector3(10.0, 1.25, 9.0), Color("d3a2a2"))
	_add_static_box("免费鸡蛋红色门头", Vector3(6.4, 0.75, 0.18), Vector3(-9.0, 3.15, -7.82), Color("c9342e"))
	_add_store_front_details(Vector3(-9.0, 0.0, -10.0))
	_add_generated_storefront_visual()
	_add_background_buildings()
	_add_city_horizon_visuals()
	_add_label_3d("免费鸡蛋", Vector3(-9.0, 3.18, -7.68), Color("fff4d8"))
	_add_store_shelves(Vector3(-9.0, 0.0, -9.8))
	_add_store_interior_visuals(Vector3(-9.0, 0.0, -10.0))
	_add_new_shop_front(Vector3(10.0, 0.0, 9.0))
	_add_label_3d("街区任务", Vector3(8.0, 3.45, -7.68), Color("fff4d8"))
	_add_scan_board(Vector3(8.5, 0.95, 5.5))
	_add_city_storytelling_visuals()
	_add_street_lamp(Vector3(5.5, 0.0, 2.8))
	_add_street_lamp(Vector3(-4.8, 0.0, 2.8))
	_add_tree(Vector3(13.0, 0.0, -3.5))
	_add_tree(Vector3(-13.0, 0.0, 4.8))
	_build_neighborhood_extension()
	var environment_fallback := Node3D.new()
	environment_fallback.name = "城市环境灰盒回退"
	var environment_mount: Dictionary
	if _catalog_slot_has_scene("city-environment-kit"):
		environment_mount = AssetRuntimeCatalogClass.mount_optional_visual(self, asset_catalog, "city-environment-kit", environment_fallback)
	else:
		var internal_environment_visual := _mount_internal_candidate_visual(self, OriginalCityEnvironmentScene, environment_fallback, "Visual")
		environment_mount = {"used_fallback": false, "blocked": false, "node": internal_environment_visual}
	city_environment_visual = environment_mount.get("node") as Node
	if is_instance_valid(city_environment_visual) and city_environment_visual.has_method("bind_external_signal_clock"):
		city_environment_visual.bind_external_signal_clock()
	if not bool(environment_mount.get("used_fallback", true)) and not bool(environment_mount.get("blocked", false)):
		_hide_graybox_environment_visuals()
	var interaction_props_fallback := Node3D.new()
	interaction_props_fallback.name = "交互道具灰盒回退"
	var interaction_props_mount := Node3D.new()
	interaction_props_mount.name = "交互道具层"
	add_child(interaction_props_mount)
	if _catalog_slot_has_scene("interaction-props"):
		AssetRuntimeCatalogClass.mount_optional_visual(interaction_props_mount, asset_catalog, "interaction-props", interaction_props_fallback)
	else:
		# 正式空目录也使用项目内原创候选表现，候选只拥有渲染，不接管交互、碰撞、导航、任务或存档。
		_mount_internal_candidate_visual(interaction_props_mount, OriginalInteractionPropsScene, interaction_props_fallback, "Visual")
	var crowd_locations := [
		Vector3(-8.0, 0.9, -7.0), Vector3(-6.8, 0.9, -7.1),
		Vector3(-5.6, 0.9, -7.0), Vector3(-7.4, 0.9, -5.8),
		Vector3(-6.1, 0.9, -5.9), Vector3(-10.5, 0.9, -6.2),
		Vector3(-10.8, 0.9, -5.3), Vector3(-9.8, 0.9, -4.8),
		Vector3(-8.8, 0.9, -4.5), Vector3(-7.5, 0.9, -4.6),
		Vector3(-6.2, 0.9, -4.7), Vector3(-5.0, 0.9, -5.1),
		Vector3(-10.4, 0.9, -4.6)
	]
	var crowd_colors := [Color("6a6470"), Color("80685b"), Color("52677b"), Color("8b6b58")]
	for index in range(crowd_locations.size()):
		_add_crowd_blocker(crowd_locations[index], crowd_colors[index % crowd_colors.size()])
	_build_visual_crowd()

func _build_visual_crowd() -> void:
	# 这是店铺前景的纯渲染人群层：不创建碰撞、路线、导航、感知或任务状态。
	# 通过前景、中景、远景三层站位补足参考视频中的街边人流密度，
	# 同时保留原有 CityPedestrian 作为可交互人群的唯一逻辑来源。
	visual_crowd_root = Node3D.new()
	visual_crowd_root.name = "原创城市视觉人群层"
	visual_crowd_root.set_meta("visual_only", true)
	visual_crowd_root.set_meta("visual_candidate", true)
	add_child(visual_crowd_root)
	var positions := [
		Vector3(-12.0, 0.92, -7.0), Vector3(-10.8, 0.92, -7.25),
		Vector3(-9.6, 0.92, -7.05), Vector3(-8.4, 0.92, -7.28),
		Vector3(-7.2, 0.92, -7.0), Vector3(-6.0, 0.92, -7.24),
		Vector3(-11.4, 0.92, -5.9), Vector3(-10.2, 0.92, -5.55),
		Vector3(-8.9, 0.92, -5.8), Vector3(-7.6, 0.92, -5.52),
		Vector3(-6.4, 0.92, -5.82), Vector3(-5.2, 0.92, -5.56),
		Vector3(-12.8, 0.92, -4.4), Vector3(-11.4, 0.92, -4.15),
		Vector3(-9.9, 0.92, -4.3), Vector3(-8.3, 0.92, -4.08),
		Vector3(-6.8, 0.92, -4.35), Vector3(-5.3, 0.92, -4.10)
	]
	var crowd_role_scales := [1.02, 0.98, 0.94, 1.05]
	for index in range(positions.size()):
		var wrapper := Node3D.new()
		wrapper.name = "视觉人群_%02d" % index
		wrapper.position = positions[index]
		wrapper.rotation_degrees.y = -18.0 + float((index * 37) % 72)
		var visual_scale := 0.98 + float(index % 4) * 0.055
		var candidate_role_scale: float = crowd_role_scales[index % crowd_role_scales.size()]
		wrapper.scale = Vector3.ONE * visual_scale
		# 候选角色的脚底原点位于局部 y=-1.075；同时计入角色体型缩放，避免人群漂浮或陷入路面。
		wrapper.position.y = 1.075 * visual_scale * candidate_role_scale
		wrapper.set_meta("candidate_role_scale", candidate_role_scale)
		wrapper.set_meta("visual_only", true)
		visual_crowd_root.add_child(wrapper)
		var candidate := OriginalCityCrowdScene.instantiate()
		if candidate == null:
			continue
		candidate.name = "原创城市视觉角色外观"
		wrapper.add_child(candidate)

func _hide_graybox_environment_visuals() -> void:
	# 候选环境只接管渲染层；灰盒碰撞体和任务节点继续保留。
	var preserve_roots := {
		"音频事件路由": true,
		"Visual": true,
		"玩家": true,
		"蓝色三轮车": true,
		"交互道具层": true,
		# 正式采集已关闭整张写实背景卡；首店镜头必须继续保留
		# 原创三维人群，否则画面只剩店面和主角，无法审阅真实的
		# 人群密度、脚底接触、遮挡关系和近景材质。
		"原创城市视觉人群层": true,
	}
	for child in get_children():
		if preserve_roots.has(str(child.name)):
			if str(child.name) == "Visual" and bool(get("reference_capture_mode")):
				# Visual 根同时承载候选环境和完整候选建筑；让专用采集递归
				# 只隐藏明确的 CC0 遮挡楼体，保留其它候选视觉节点。
				_hide_graybox_visual_nodes(child)
			continue
		_hide_graybox_visual_nodes(child)

func _hide_reference_vehicle_cover() -> void:
	# 参考视频中的蓝色载人车是开放式车斗；当前原创候选的顶棚、挡风玻璃
	# 和篷架会在车尾镜头中遮住主角躯干。它们只属于视觉候选节点，隐藏不
	# 改变载具碰撞、驾驶挂点、任务状态或输入回放。
	if vehicle == null:
		return
	for node in vehicle.find_children("*", "Node3D", true, false):
		var visual_node := node as Node3D
		if visual_node == null:
			continue
		var node_name := str(visual_node.name)
		# 不能按导入场景根节点 ThreeWheelDelivery 整体隐藏；完整候选车体
		# 本身就使用这个根名，整棵树关闭会让参考截图只剩驾驶员和悬浮细节。
		# 这里只隐藏会遮挡开放式车斗的顶棚、挡风和篷架子节点。
		if node_name.contains("顶棚") or node_name.contains("挡风") or node_name.contains("篷架"):
			visual_node.visible = false

func _ensure_vehicle_driver_sprite() -> void:
	if vehicle == null or is_instance_valid(vehicle_driver_sprite):
		return
	vehicle_driver_sprite = Sprite3D.new()
	vehicle_driver_sprite.name = "原创蓝色三轮车车尾驾驶精灵"
	vehicle_driver_sprite.texture = OriginalCityVehicleDriverSpriteTexture
	vehicle_driver_sprite.pixel_size = 0.00235
	vehicle_driver_sprite.position = Vector3(0.0, 1.52, 0.04)
	vehicle_driver_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	vehicle_driver_sprite.shaded = false
	vehicle_driver_sprite.no_depth_test = false
	vehicle_driver_sprite.render_priority = 3
	vehicle_driver_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	vehicle_driver_sprite.visible = false
	vehicle_driver_sprite.set_meta("visual_only", true)
	vehicle_driver_sprite.set_meta("candidate_visual_only", true)
	vehicle_driver_sprite.set_meta("original_generated_asset", true)
	vehicle.add_child(vehicle_driver_sprite)

func _apply_vehicle_driver_sprite_for_capture() -> void:
	_ensure_vehicle_driver_sprite()
	if vehicle == null or vehicle_driver_sprite == null:
		return
	var capture_scenario := str(get_meta("reference_capture_scenario", ""))
	var use_sprite := reference_capture_mode and capture_scenario == "city-08"
	vehicle_driver_sprite.visible = use_sprite
	if not use_sprite:
		return
	# city-08 是参考视频中的车尾跟拍。原创透明精灵只替代这一固定镜头的
	# 车辆可见层，保留 VehicleController、碰撞、驾驶挂点、速度和任务逻辑。
	# 普通游玩与其它分段继续使用可交互的三维载具，不把位图冒充完整车辆。
	_hide_descendant_visual_meshes(vehicle)
	# 完整候选回放还需要保留一个真实载具网格作为运行时视觉层存在性证据；
	# 只恢复尾灯这一处细节，避免旧低模车体与原创透明精灵重叠。
	for contract_mesh_name in ["候选三轮车后尾灯", "候选三轮车后尾灯组", "候选三轮车后牌照"]:
		var contract_mesh := vehicle.find_child(contract_mesh_name, true, false) as MeshInstance3D
		if contract_mesh != null:
			contract_mesh.visible = true
			break
	if player != null:
		# 驾驶员已被透明精灵完整呈现；隐藏玩家候选视觉，不隐藏玩家碰撞
		# 或 VehicleController 的 driver 状态，避免同一镜头出现两个驾驶员。
		_hide_descendant_visual_meshes(player)

func _hide_graybox_visual_nodes(root: Node) -> void:
	# 候选环境与灰盒碰撞/任务节点可能共享父级；只有显式标记的候选视觉层
	# 可以跳过隐藏，避免把已接入的贴图、道路材质和表现层一起清掉。
	var capture_active := bool(get("reference_capture_mode"))
	var capture_scene_name := str(get_meta("reference_capture_scenario", ""))
	if capture_active and root.name == "Visual":
		# 完整候选的 Visual 根同时承载原创环境和 CC0 建筑候选；这里继续
		# 递归一层，只处理下面明确命名的参考采集遮挡物，不改变正常游玩。
		for child in root.get_children():
			_hide_graybox_visual_nodes(child)
		return
	if capture_active and root.name == "原创城市远景层":
		# city-07 到 city-11 的车尾/远景镜头由当前源绑定的原创街景卡承接
		# 天际线；旧的程序化远景楼体会在前景形成整片灰盒。city-05/06
		# 仍保留它们，以维持离店和扫描登记镜头的三维空间关系。
		if root is Node3D:
			(root as Node3D).visible = capture_scene_name not in ["city-07", "city-08", "city-09", "city-10", "city-11"]
		return
	if capture_active and capture_scene_name in ["city-07", "city-08", "city-09", "city-10", "city-11"] and root.name in ["候选CC0小型城市楼", "候选CC0中型城市楼", "候选CC0大型城市楼"]:
		# 这些楼体是完整候选的局部几何，不是任务空间或碰撞体；驾驶参考
		# 镜头已经有当前源绑定的原创街景背景卡承接天际线，隐藏它们可以
		# 消除灰盒遮挡，同时保留载具、道路、玩家和所有任务状态。
		if root is Node3D:
			(root as Node3D).visible = false
		return
	if bool(get("reference_capture_mode")) and str(get_meta("reference_capture_scenario", "")) == "city-08" and root.name in ["街区地面", "道路", "道路横向"]:
		# 混合渲染候选仍需要真实三维地面承接载具轮胎和角色阴影；
		# 只保留视觉网格，碰撞体与任务空间始终不被改写。
		if root is Node3D:
			(root as Node3D).visible = true
		return
	if bool(get("reference_capture_mode")) and root.name == "街道立面细节":
		# 驾驶参考段需要连续的三维街墙、窗带和店铺尺度；其它段仍隐藏
		# 这组开发期远景，避免把办公室或店内镜头的灰盒带进画面。
		var capture_scenario := str(get_meta("reference_capture_scenario", ""))
		# city-08 使用跟随相机的原创街景背景卡承接远景；开发期街墙会
		# 在车尾构图里变成大块灰盒，遮掉道路消失点和载具轮廓。
		(root as Node3D).visible = capture_scenario in ["city-07", "city-09", "city-10"]
		return
	if bool(root.get_meta("visual_candidate", false)) or bool(root.get_meta("visual_only", false)):
		return
	if root is MeshInstance3D or root is Label3D:
		(root as Node3D).visible = false
	for child in root.get_children():
		_hide_graybox_visual_nodes(child)

func _hide_descendant_visual_meshes(root: Node) -> void:
	# 采集态视觉清理只改渲染节点；碰撞、导航、交互和任务节点保持原样。
	if root is MeshInstance3D or root is Label3D:
		(root as Node3D).visible = false
	for child in root.get_children():
		_hide_descendant_visual_meshes(child)

func _add_generated_storefront_visual() -> void:
	var texture := load("res://assets/environment/generated/urban_storefront_v2_generated.png") as Texture2D
	if texture == null:
		return
	var facade := MeshInstance3D.new()
	facade.name = "原创写实店铺立面候选"
	facade.set_meta("visual_candidate", true)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(6.8, 4.4)
	facade.mesh = mesh
	facade.position = Vector3(-9.0, 1.85, -7.86)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.78
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	add_child(facade)

func _add_cc0_worn_asphalt_visuals() -> void:
	var material := _cc0_worn_asphalt_material()
	if material == null:
		return
	var north_south := MeshInstance3D.new()
	north_south.name = "CC0磨损沥青道路材质-纵向"
	north_south.set_meta("visual_candidate", true)
	var north_south_mesh := PlaneMesh.new()
	north_south_mesh.size = Vector2(7.0, 34.0)
	north_south.mesh = north_south_mesh
	north_south.position = Vector3(0.0, 0.056, 0.0)
	north_south.material_override = material.duplicate()
	add_child(north_south)
	var east_west := MeshInstance3D.new()
	east_west.name = "CC0磨损沥青道路材质-横向"
	east_west.set_meta("visual_candidate", true)
	var east_west_mesh := PlaneMesh.new()
	east_west_mesh.size = Vector2(34.0, 5.0)
	east_west.mesh = east_west_mesh
	east_west.position = Vector3(0.0, 0.066, 0.0)
	east_west.material_override = material
	add_child(east_west)

func _cc0_worn_asphalt_material() -> StandardMaterial3D:
	var diffuse := load("res://assets/environment/cc0/worn_asphalt/worn_asphalt_diff_1k.jpg") as Texture2D
	var normal := load("res://assets/environment/cc0/worn_asphalt/worn_asphalt_nor_gl_1k.jpg") as Texture2D
	var roughness := load("res://assets/environment/cc0/worn_asphalt/worn_asphalt_rough_1k.jpg") as Texture2D
	if diffuse == null or normal == null or roughness == null:
		return null
	var material := StandardMaterial3D.new()
	material.albedo_texture = diffuse
	material.normal_enabled = true
	material.normal_texture = normal
	material.normal_scale = 0.7
	material.roughness_texture = roughness
	material.roughness = 0.92
	material.metallic = 0.0
	material.uv1_scale = Vector3(2.8, 2.8, 2.8)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func _build_neighborhood_extension() -> void:
	var extension_config: Dictionary = city_pack.get("runtime", {}).get("neighborhood", {})
	if not bool(extension_config.get("enabled", true)):
		return
	var entry_data = extension_config.get("entry", [11.5, 0.9, -11.5])
	if entry_data is Array and entry_data.size() == 3:
		neighborhood_entry = Vector3(float(entry_data[0]), float(entry_data[1]), float(entry_data[2]))
	_add_static_box("新街区巷道", Vector3(5.0, 0.04, 7.0), Vector3(-4.5, 0.03, -5.5), Color("5d6260"))
	_add_static_box("后场仓储建筑", Vector3(4.5, 3.6, 2.8), Vector3(-6.5, 1.8, -6.5), Color("88766d"))
	_add_static_box("后场仓储围挡", Vector3(0.18, 1.6, 6.0), Vector3(-2.0, 0.8, -5.5), Color("6c625b"))
	_add_static_box("后场装卸台", Vector3(2.4, 0.4, 1.2), Vector3(-7.6, 0.35, -4.9), Color("b18a62"))
	_add_generated_warehouse_facade_visual()
	var warehouse_facade := Node3D.new()
	warehouse_facade.name = "后场仓储门面细节"
	add_child(warehouse_facade)
	var warehouse_sign := _box_mesh(Vector3(3.7, 0.42, 0.12), Color("c98c62"))
	warehouse_sign.position = Vector3(-6.5, 3.0, -5.03)
	warehouse_facade.add_child(warehouse_sign)
	var loading_door := _box_mesh(Vector3(1.5, 1.85, 0.12), Color("3d4850"))
	loading_door.position = Vector3(-6.5, 1.25, -5.03)
	warehouse_facade.add_child(loading_door)
	_add_label_3d("后场仓储", Vector3(-6.5, 3.9, -5.0), Color("f5d9a2"))
	_add_label_3d("巷道入口", neighborhood_entry + Vector3(0.0, 1.8, 0.0), Color("c9d8d0"))
	_add_candidate_neighborhood_details(warehouse_facade)

func _add_candidate_neighborhood_details(parent: Node3D) -> void:
	# 新街区必须让玩家读懂“可进入、可装卸、可交付”，但这些节点只能是
	# 原创候选表现层，不能改变真实碰撞、导航、交互、任务或存档边界。
	parent.set_meta("visual_only", true)
	parent.set_meta("candidate_visual_only", true)
	parent.set_meta("original_procedural_asset", true)
	_add_candidate_visual_box(parent, "后场仓储装卸雨棚", Vector3(3.0, 0.08, 1.10), Vector3(-7.55, 1.68, -4.05), Color("6d7170"))
	_add_candidate_visual_box(parent, "后场仓储装卸雨棚支架左", Vector3(0.08, 1.55, 0.08), Vector3(-8.85, 0.86, -4.05), Color("3e4b50"))
	_add_candidate_visual_box(parent, "后场仓储装卸雨棚支架右", Vector3(0.08, 1.55, 0.08), Vector3(-6.25, 0.86, -4.05), Color("3e4b50"))
	_add_candidate_visual_box(parent, "后场仓储木托盘-01", Vector3(1.05, 0.12, 0.72), Vector3(-7.80, 0.50, -4.42), Color("8a6044"))
	_add_candidate_visual_box(parent, "后场仓储木托盘-02", Vector3(0.90, 0.10, 0.62), Vector3(-6.82, 0.48, -4.42), Color("9b6a48"))
	_add_candidate_visual_box(parent, "后场仓储纸箱-01", Vector3(0.48, 0.46, 0.42), Vector3(-7.72, 0.82, -4.42), Color("b88758"))
	_add_candidate_visual_box(parent, "后场仓储纸箱-02", Vector3(0.40, 0.34, 0.38), Vector3(-7.18, 0.76, -4.42), Color("c49462"))
	_add_candidate_visual_box(parent, "后场仓储警示条", Vector3(1.24, 0.06, 0.035), Vector3(-6.50, 1.90, -5.12), Color("d8a04e"))
	_add_candidate_visual_box(parent, "后场仓储警示灯", Vector3(0.10, 0.22, 0.05), Vector3(-5.58, 1.78, -5.12), Color("e0ad66"))
	_add_candidate_visual_box(parent, "后场仓储地面导视线", Vector3(0.10, 0.018, 3.20), Vector3(-7.55, 0.17, -5.82), Color("c29a63"))
	_add_candidate_visual_box(parent, "后场仓储排水沟", Vector3(3.10, 0.022, 0.16), Vector3(-7.55, 0.13, -4.82), Color("343a3d"))
	_add_candidate_visual_box(parent, "后场仓储侧面垃圾桶", Vector3(0.48, 0.82, 0.48), Vector3(-3.05, 0.52, -6.55), Color("465156"))
	_add_candidate_visual_box(parent, "后场仓储墙面电缆", Vector3(3.30, 0.05, 0.045), Vector3(-6.50, 2.72, -5.13), Color("282f33"))

func _add_candidate_visual_box(parent: Node3D, node_name: String, size: Vector3, location: Vector3, color: Color) -> MeshInstance3D:
	var visual := _box_mesh(size, color)
	visual.name = node_name
	visual.position = location
	visual.set_meta("visual_only", true)
	visual.set_meta("candidate_visual_only", true)
	visual.set_meta("original_procedural_asset", true)
	parent.add_child(visual)
	return visual

func _add_generated_warehouse_facade_visual() -> void:
	var texture := load("res://assets/environment/generated/warehouse_backlot_facade_v1_generated.png") as Texture2D
	if texture == null:
		return
	var facade := MeshInstance3D.new()
	facade.name = "原创写实后场仓储门面候选"
	facade.set_meta("visual_candidate", true)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4.5, 1.5)
	facade.mesh = mesh
	# 只覆盖仓储建筑正面的表现层，不替代装卸碰撞、入口导航或任务状态。
	facade.position = Vector3(-6.5, 1.78, -4.96)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.82
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	add_child(facade)

func apply_visual_profile(profile: String) -> bool:
	if city_environment == null or city_environment.environment == null:
		return false
	if not ["day", "dusk", "rain_after"].has(profile):
		return false
	weather_profile = profile
	_clear_weather_visuals()
	match profile:
		"dusk":
			city_sky_material.sky_top_color = Color("27334d")
			city_sky_material.sky_horizon_color = Color("b67e72")
			city_sky_material.ground_bottom_color = Color("282d35")
			city_sky_material.ground_horizon_color = Color("786b6d")
			city_environment.environment.fog_light_color = Color("7c8495")
			city_environment.environment.ambient_light_energy = 0.52
			city_sun.light_color = Color("e09b79")
			city_sun.light_energy = 0.38
		"rain_after":
			city_sky_material.sky_top_color = Color("4d6671")
			city_sky_material.sky_horizon_color = Color("b5c0c0")
			city_sky_material.ground_bottom_color = Color("3d4649")
			city_sky_material.ground_horizon_color = Color("8e9b9e")
			city_environment.environment.fog_light_color = Color("9eafb4")
			city_environment.environment.ambient_light_energy = 0.64
			city_sun.light_color = Color("b9c9d0")
			city_sun.light_energy = 0.5
			_build_rain_after_visuals()
		_:
			city_sky_material.sky_top_color = Color("355776")
			city_sky_material.sky_horizon_color = Color("c7c5bc")
			city_sky_material.ground_bottom_color = Color("353d3d")
			city_sky_material.ground_horizon_color = Color("a39d8e")
			city_environment.environment.fog_light_color = Color("aeb7b5")
			city_environment.environment.ambient_light_energy = 0.76
			city_sun.light_color = Color("f6d7ae")
			city_sun.light_energy = 0.82
	_sync_city_story_lights()
	message = "环境配置：" + profile
	trace.record("visual_profile", {"profile": profile})
	_update_hud()
	return true

func _clear_weather_visuals() -> void:
	if weather_effect_root != null and is_instance_valid(weather_effect_root):
		weather_effect_root.queue_free()
	weather_effect_root = null

func _build_rain_after_visuals() -> void:
	weather_effect_root = Node3D.new()
	weather_effect_root.name = "雨后视觉层"
	weather_effect_root.set_meta("visual_only", true)
	weather_effect_root.set_meta("visual_candidate", true)
	weather_effect_root.set_meta("candidate_visual_only", true)
	weather_effect_root.set_meta("original_procedural_asset", true)
	add_child(weather_effect_root)
	var wet_surface := _box_mesh(Vector3(6.7, 0.018, 30.0), Color("526b73"))
	wet_surface.name = "雨后湿润路面"
	wet_surface.position = Vector3(0.0, 0.085, 0.0)
	wet_surface.set_meta("visual_only", true)
	wet_surface.set_meta("candidate_visual_only", true)
	wet_surface.set_meta("original_procedural_asset", true)
	weather_effect_root.add_child(wet_surface)
	var puddle_positions := [Vector3(-2.2, 0.098, -6.0), Vector3(1.6, 0.099, -1.8), Vector3(3.4, 0.100, 5.4)]
	for puddle_index in range(puddle_positions.size()):
		var puddle := _box_mesh(Vector3(1.35, 0.012, 0.46), Color("718e96"))
		puddle.name = "雨后路面积水反光-%02d" % puddle_index
		puddle.position = puddle_positions[puddle_index]
		puddle.set_meta("visual_only", true)
		puddle.set_meta("candidate_visual_only", true)
		puddle.set_meta("original_procedural_asset", true)
		weather_effect_root.add_child(puddle)
	for drain_index in range(3):
		var drain_reflection := _box_mesh(Vector3(0.72, 0.014, 0.08), Color("9cb8bb"))
		drain_reflection.name = "雨后排水沟反光-%02d" % drain_index
		drain_reflection.position = Vector3(-3.0 + float(drain_index) * 2.8, 0.102, -4.6 + float(drain_index) * 4.4)
		drain_reflection.set_meta("visual_only", true)
		drain_reflection.set_meta("candidate_visual_only", true)
		drain_reflection.set_meta("original_procedural_asset", true)
		weather_effect_root.add_child(drain_reflection)
	for index in range(20):
		var rain_streak := _box_mesh(Vector3(0.018, 0.7, 0.018), Color("b9d6db"))
		rain_streak.name = "雨痕-%02d" % index
		rain_streak.position = Vector3(-15.0 + float(index % 10) * 3.2, 2.6 + float(index % 3) * 0.35, -14.0 + float(index / 10) * 8.0)
		rain_streak.set_meta("visual_only", true)
		rain_streak.set_meta("candidate_visual_only", true)
		rain_streak.set_meta("original_procedural_asset", true)
		weather_effect_root.add_child(rain_streak)

func enter_neighborhood_extension() -> bool:
	if player == null or player.global_position.distance_to(neighborhood_entry) > 4.0:
		message = "需要前往巷道入口"
		return false
	neighborhood_status = "active"
	message = "已进入后场仓储街区"
	trace.record("neighborhood_entered", {"zone": "back_lot_warehouse"})
	_update_hud()
	return true

func _add_road_visual_details() -> void:
	var details := Node3D.new()
	details.name = "道路视觉细节"
	details.set_meta("visual_candidate", true)
	details.set_meta("candidate_visual_only", true)
	add_child(details)
	var marking_color := Color("d8d2c4")
	var curb_color := Color("8d9290")
	var sidewalk_color := Color("9b9b91")
	var sidewalk_seam_color := Color("777b79")
	var crosswalk_color := Color("e6e1d5")
	var drainage_color := Color("343a3d")
	# 连续人行道只负责补足路缘与建筑之间的视觉层，不创建碰撞体。
	for x in [-4.25, 4.25]:
		var longitudinal_sidewalk := _box_mesh(Vector3(1.65, 0.06, 34.0), sidewalk_color)
		longitudinal_sidewalk.name = "人行道-纵向-%s" % str(x)
		longitudinal_sidewalk.position = Vector3(x, 0.09, 0.0)
		details.add_child(longitudinal_sidewalk)
	for z in [-3.65, 3.65]:
		var lateral_sidewalk := _box_mesh(Vector3(34.0, 0.06, 1.65), sidewalk_color)
		lateral_sidewalk.name = "人行道-横向-%s" % str(z)
		lateral_sidewalk.position = Vector3(0.0, 0.095, z)
		details.add_child(lateral_sidewalk)
	for x in [-4.25, 4.25]:
		for seam_index in range(8):
			var seam := _box_mesh(Vector3(1.7, 0.012, 0.035), sidewalk_seam_color)
			seam.name = "人行道接缝-纵向-%s-%d" % [str(x), seam_index]
			seam.position = Vector3(x, 0.125, -14.0 + seam_index * 4.0)
			details.add_child(seam)
	for z in [-14.0, -8.0, -2.0, 4.0, 10.0, 16.0]:
		var vertical_marking := _box_mesh(Vector3(0.16, 0.018, 2.0), marking_color)
		vertical_marking.name = "车道线-纵向-%s" % str(z)
		vertical_marking.position = Vector3(0.0, 0.065, z)
		details.add_child(vertical_marking)
	for x in [-14.0, -8.0, -2.0, 4.0, 10.0, 16.0]:
		var horizontal_marking := _box_mesh(Vector3(2.0, 0.018, 0.16), marking_color)
		horizontal_marking.name = "车道线-横向-%s" % str(x)
		horizontal_marking.position = Vector3(x, 0.07, 0.0)
		details.add_child(horizontal_marking)
	for x in [-3.35, 3.35]:
		for z in [-8.5, 8.5]:
			var vertical_curb := _box_mesh(Vector3(0.12, 0.08, 17.0), curb_color)
			vertical_curb.name = "路缘-纵向-%s-%s" % [str(x), str(z)]
			vertical_curb.position = Vector3(x, 0.07, z)
			details.add_child(vertical_curb)
	for z in [-2.4, 2.4]:
		for x in [-8.5, 8.5]:
			var horizontal_curb := _box_mesh(Vector3(17.0, 0.08, 0.12), curb_color)
			horizontal_curb.name = "路缘-横向-%s-%s" % [str(z), str(x)]
			horizontal_curb.position = Vector3(x, 0.075, z)
			details.add_child(horizontal_curb)
	# 仅增加道路的可读性，不创建碰撞体，避免改变车辆、导航和任务边界。
	for stripe_index in range(7):
		var north_crosswalk := _box_mesh(Vector3(0.42, 0.019, 2.1), crosswalk_color)
		north_crosswalk.name = "北侧斑马线-%d" % stripe_index
		north_crosswalk.position = Vector3(-2.4 + stripe_index * 0.8, 0.082, -3.05)
		details.add_child(north_crosswalk)
		var south_crosswalk := _box_mesh(Vector3(0.42, 0.019, 2.1), crosswalk_color)
		south_crosswalk.name = "南侧斑马线-%d" % stripe_index
		south_crosswalk.position = Vector3(-2.4 + stripe_index * 0.8, 0.082, 3.05)
		details.add_child(south_crosswalk)
	var grate_positions := [Vector3(-3.05, 0.085, -5.0), Vector3(3.05, 0.085, 5.0), Vector3(-5.0, 0.085, 3.05), Vector3(5.0, 0.085, -3.05)]
	for grate_index in range(grate_positions.size()):
		var grate_position: Vector3 = grate_positions[grate_index]
		var drainage_grate := _box_mesh(Vector3(0.42, 0.022, 0.9), drainage_color)
		drainage_grate.name = "路缘排水沟-%d" % grate_index
		drainage_grate.position = grate_position
		details.add_child(drainage_grate)
	var cover_positions := [Vector3(-1.9, 0.086, -1.35), Vector3(1.9, 0.086, 1.35)]
	for cover_index in range(cover_positions.size()):
		var cover_position: Vector3 = cover_positions[cover_index]
		var utility_cover := _box_mesh(Vector3(0.62, 0.024, 0.62), drainage_color)
		utility_cover.name = "道路检修井盖-%d" % cover_index
		utility_cover.position = cover_position
		details.add_child(utility_cover)

func _add_city_composition_pass() -> void:
	var composition := Node3D.new()
	composition.name = "原创城市构图层"
	composition.set_meta("visual_only", true)
	composition.set_meta("visual_candidate", true)
	composition.set_meta("candidate_visual_only", true)
	add_child(composition)
	var post_color := Color("4b555b")
	var head_color := Color("26333a")
	var signal_color := Color("d7a64a")
	var guide_color := Color("d0b07b")
	var bollard_color := Color("b76a46")
	var signal_corners := [Vector3(-3.25, 0.0, -2.35), Vector3(3.25, 0.0, -2.35), Vector3(-3.25, 0.0, 2.35), Vector3(3.25, 0.0, 2.35)]
	for index in range(signal_corners.size()):
		var corner: Vector3 = signal_corners[index]
		var post := _box_mesh(Vector3(0.12, 2.6, 0.12), post_color)
		post.name = "城市构图-信号杆-%02d" % (index + 1)
		post.position = corner + Vector3(0.0, 1.3, 0.0)
		post.set_meta("visual_only", true)
		post.set_meta("candidate_visual_only", true)
		composition.add_child(post)
		var head := _box_mesh(Vector3(0.32, 0.55, 0.24), head_color)
		head.name = "城市构图-信号头-%02d" % (index + 1)
		head.position = corner + Vector3(0.0, 2.25, 0.0)
		head.set_meta("visual_only", true)
		head.set_meta("candidate_visual_only", true)
		composition.add_child(head)
		var signal_lens := _box_mesh(Vector3(0.18, 0.08, 0.04), signal_color)
		signal_lens.name = "城市构图-信号灯-%02d" % (index + 1)
		signal_lens.position = corner + Vector3(0.0, 2.28, 0.125)
		signal_lens.set_meta("visual_only", true)
		signal_lens.set_meta("candidate_visual_only", true)
		composition.add_child(signal_lens)
	var guide_panel := _box_mesh(Vector3(1.8, 0.9, 0.08), guide_color)
	guide_panel.name = "城市构图-街区导视牌"
	guide_panel.position = Vector3(5.2, 1.55, 5.1)
	guide_panel.set_meta("visual_only", true)
	guide_panel.set_meta("candidate_visual_only", true)
	composition.add_child(guide_panel)
	var guide_label := Label3D.new()
	guide_label.name = "城市构图-街区导视字"
	guide_label.text = "后场仓储  ·  任务街区"
	guide_label.position = Vector3(5.2, 1.58, 5.03)
	guide_label.modulate = Color("fff1c7")
	guide_label.font_size = 20
	guide_label.outline_size = 4
	guide_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guide_label.set_meta("visual_only", true)
	guide_label.set_meta("candidate_visual_only", true)
	composition.add_child(guide_label)
	for index in range(4):
		var bollard := _box_mesh(Vector3(0.16, 0.55, 0.16), bollard_color)
		bollard.name = "城市构图-路缘识别柱-%02d" % (index + 1)
		bollard.position = Vector3(-4.0 + float(index % 2) * 8.0, 0.35, 6.5 + float(index / 2) * 1.1)
		bollard.set_meta("visual_only", true)
		bollard.set_meta("candidate_visual_only", true)
		composition.add_child(bollard)

func _build_player() -> void:
	player = ReferencePlayerClass.new()
	var runtime_config: Dictionary = city_pack.get("runtime", {})
	var player_config: Dictionary = runtime_config.get("player", {})
	player.walk_speed = float(player_config.get("walk_speed", player.walk_speed))
	player.sprint_speed = float(player_config.get("sprint_speed", player.sprint_speed))
	player.crouch_speed = float(player_config.get("crouch_speed", player.crouch_speed))
	player.name = "玩家"
	player.controlled_externally = true
	player.position = Vector3(0.0, 1.0, 9.0)
	add_child(player)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)
	var collision_visual := _capsule_mesh(Color("427eaa"))
	collision_visual.visible = false
	player.add_child(collision_visual)
	var player_slot_id := "city-player-character" if AssetRuntimeCatalogClass.has_slot(asset_catalog, "city-player-character") else "player-character"
	var player_fallback := _character_visual(Color("a63d35"), Color("1e2430"), Color("252a35"))
	if _catalog_slot_has_scene(player_slot_id):
		AssetRuntimeCatalogClass.mount_optional_visual(player, asset_catalog, player_slot_id, player_fallback)
	else:
		_mount_internal_candidate_visual(player, OriginalPlayerScene, player_fallback, "Visual")
	var mounted_player_visual := player.get_node_or_null("Visual") as Node3D
	if mounted_player_visual != null and mounted_player_visual.has_method("set_candidate_context"):
		mounted_player_visual.call("set_candidate_context", "city")
	cargo_visual = _box_mesh(Vector3(0.72, 0.12, 0.50), Color("9b643e"))
	cargo_visual.name = "玩家携带鸡蛋托盘"
	cargo_visual.position = Vector3(-0.50, 0.64, -0.13)
	cargo_visual.rotation_degrees = Vector3(-8.0, 0.0, -4.0)
	cargo_visual.set_meta("visual_only", true)
	var cargo_rim := Color("c18a52")
	for rim_index in range(2):
		var rim_x := -0.30 + float(rim_index) * 0.60
		var rim_side := _box_mesh(Vector3(0.055, 0.24, 0.50), cargo_rim)
		rim_side.name = "鸡蛋托盘侧框-%d" % rim_index
		rim_side.position = Vector3(rim_x, 0.17, 0.0)
		rim_side.set_meta("visual_only", true)
		cargo_visual.add_child(rim_side)
	for rim_index in range(2):
		var rim_z := -0.21 + float(rim_index) * 0.42
		var rim_end := _box_mesh(Vector3(0.72, 0.24, 0.055), cargo_rim)
		rim_end.name = "鸡蛋托盘前后框-%d" % rim_index
		rim_end.position = Vector3(0.0, 0.17, rim_z)
		rim_end.set_meta("visual_only", true)
		cargo_visual.add_child(rim_end)
	for row in range(2):
		for column in range(4):
			var egg_mesh := SphereMesh.new()
			egg_mesh.radius = 0.055
			egg_mesh.height = 0.11
			var egg_visual := MeshInstance3D.new()
			egg_visual.name = "鸡蛋托盘鸡蛋-%d-%d" % [row, column]
			egg_visual.mesh = egg_mesh
			egg_visual.position = Vector3(-0.22 + float(column) * 0.145, 0.20, -0.13 + float(row) * 0.26)
			var egg_material := StandardMaterial3D.new()
			egg_material.albedo_color = Color("f0e2bd")
			egg_material.roughness = 0.58
			egg_visual.material_override = egg_material
			egg_visual.set_meta("visual_only", true)
			cargo_visual.add_child(egg_visual)
	cargo_visual.visible = false
	player.add_child(cargo_visual)
	camera_rig = CameraRigClass.new()
	camera_rig.name = "第三人称镜头"
	# 城市首段参考镜头需要同时读出主角、店铺立面和前景人群；原先距离过近，
	# 主角占据画面后会把街景压成背景。只调整第三人称表现镜头，不改变移动
	# 输入、射线、碰撞、任务或存档坐标。
	camera_rig.distance = 4.35
	camera_rig.height = 2.35
	camera_rig.pitch_degrees = -18.0
	player.add_child(camera_rig)
	trace.record("camera_state", camera_rig.snapshot())

func _build_targets() -> void:
	var raw_targets = city_pack.get("targets", [])
	if not raw_targets is Array:
		return
	for target_data in raw_targets:
		if not target_data is Dictionary:
			continue
		var raw_position = target_data.get("position", [])
		if not raw_position is Array or raw_position.size() != 3:
			continue
		var location: Vector3 = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
		var identifier := str(target_data.get("id", ""))
		var label := str(target_data.get("label", identifier))
		var color: Color = _color_from_hex(target_data.get("color", "ffffff"), Color("e0a45d"))
		_add_target(identifier, label, location, color)
	_build_side_activity_target()

func _color_from_hex(value: Variant, fallback: Color) -> Color:
	var raw := str(value).strip_edges()
	if raw.begins_with("#"):
		raw = raw.substr(1)
	if raw.length() != 6 and raw.length() != 8:
		return fallback
	return Color("#" + raw)

func _add_activity_beacon(parent: Node3D, marker_name: String, color: Color) -> Node3D:
	var beacon_root := Node3D.new()
	beacon_root.name = marker_name
	beacon_root.set_meta("visual_only", true)
	beacon_root.set_meta("candidate_visual_only", true)
	parent.add_child(beacon_root)
	var base := _cylinder_mesh(0.30, 0.08, color.darkened(0.30))
	base.name = marker_name + "底座"
	base.position = Vector3(0.0, 0.04, 0.0)
	base.set_meta("visual_only", true)
	beacon_root.add_child(base)
	var stem := _cylinder_mesh(0.05, 0.68, color)
	stem.name = marker_name + "灯柱"
	stem.position = Vector3(0.0, 0.40, 0.0)
	stem.set_meta("visual_only", true)
	beacon_root.add_child(stem)
	var cap := _box_mesh(Vector3(0.30, 0.12, 0.30), color.lightened(0.12))
	cap.name = marker_name + "识别片"
	cap.position = Vector3(0.0, 0.76, 0.0)
	cap.set_meta("visual_only", true)
	beacon_root.add_child(cap)
	return beacon_root

func _build_side_activity_target() -> void:
	var activities = city_pack.get("side_activities", [])
	if not activities is Array or activities.is_empty():
		return
	for activity_index in range(activities.size()):
		if activities[activity_index] is Dictionary:
			_build_side_activity_runtime(activities[activity_index], activity_index)
	_sync_side_activity_state()

func _build_side_activity_runtime(activity: Dictionary, activity_index: int) -> void:
	var raw_position = activity.get("position", [])
	if not raw_position is Array or raw_position.size() != 3:
		return
	var activity_id := str(activity.get("id", "side_activity_%d" % activity_index))
	var activity_label := str(activity.get("label", "街边支线"))
	var delivery: Dictionary = activity.get("delivery", {}) if activity.get("delivery", {}) is Dictionary else {}
	var delivery_label := str(delivery.get("label", "完成支线交付"))
	var target := InteractionTargetClass.new()
	target.name = "支线-%s" % activity_label
	target.interaction_id = activity_id
	target.prompt = activity_label
	target.position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))
	target.interaction_radius = 2.0
	target.one_shot = true
	target.set_meta("side_activity", true)
	add_child(target)
	_add_activity_beacon(target, "支线接单标记", _color_from_hex(activity.get("color", "e0a45d"), Color("e0a45d")))
	var delivery_target: InteractionTarget
	var delivery_position = delivery.get("position", [])
	if delivery_position is Array and delivery_position.size() == 3:
		delivery_target = InteractionTargetClass.new()
		delivery_target.name = "支线交付-%s" % activity_label
		delivery_target.interaction_id = activity_id + "_delivery"
		delivery_target.prompt = delivery_label
		delivery_target.position = Vector3(float(delivery_position[0]), float(delivery_position[1]), float(delivery_position[2]))
		delivery_target.interaction_radius = 2.0
		delivery_target.one_shot = true
		delivery_target.set_meta("side_activity_delivery", true)
		add_child(delivery_target)
		_add_activity_beacon(delivery_target, "支线交付标记", _color_from_hex(delivery.get("color", "7db6c8"), Color("7db6c8")))
	var runtime: Dictionary = {
		"id": activity_id,
		"label": activity_label,
		"unlock_after": str(activity.get("unlock_after", "register")),
		"reward": maxi(int(activity.get("reward", 0)), 0),
		"delivery_label": delivery_label,
		"cargo_item": "vendor_parcel" if activity_index == 0 else "vendor_parcel_%d" % activity_index,
		"target": target,
		"delivery_target": delivery_target,
		"accepted": false,
		"completed": false,
		"unlocked": false
	}
	side_activity_runtimes.append(runtime)
	if activity_index == 0:
		side_activity_id = activity_id
		side_activity_label = activity_label
		side_activity_unlock_after = str(runtime["unlock_after"])
		side_activity_reward = int(runtime["reward"])
		side_activity_delivery_label = delivery_label
		side_activity_target = target
		side_activity_delivery_target = delivery_target

func _sync_side_activity_state() -> void:
	if side_activity_runtimes.is_empty():
		return
	for runtime_index in range(side_activity_runtimes.size()):
		var runtime: Dictionary = side_activity_runtimes[runtime_index]
		var unlock_index := -1
		for stage_index in range(mission.stages.size()):
			if str(mission.stages[stage_index].get("id", "")) == str(runtime.get("unlock_after", "register")):
				unlock_index = stage_index
				break
		var was_unlocked := bool(runtime.get("unlocked", false))
		var accepted := bool(runtime.get("accepted", false))
		var completed := bool(runtime.get("completed", false))
		var unlocked := not completed and not accepted and mission.status == MissionChain.Status.ACTIVE and mission.current_index >= unlock_index and unlock_index >= 0
		runtime["unlocked"] = unlocked
		var target := runtime.get("target") as InteractionTarget
		var delivery_target := runtime.get("delivery_target") as InteractionTarget
		if target != null:
			target.completed = completed
			target.visible = unlocked
		if delivery_target != null:
			delivery_target.completed = completed
			delivery_target.visible = accepted and not completed and mission.status == MissionChain.Status.ACTIVE
		if unlocked and not was_unlocked:
			trace.record("side_activity_unlocked", {"id": runtime.get("id", ""), "unlock_after": runtime.get("unlock_after", "")})
			audio_events.emit_event("mission_stage", {"side_activity": runtime.get("id", "")})
		side_activity_runtimes[runtime_index] = runtime
	var primary: Dictionary = side_activity_runtimes[0]
	side_activity_unlocked = bool(primary.get("unlocked", false))
	side_activity_accepted = bool(primary.get("accepted", false))
	side_activity_completed = bool(primary.get("completed", false))

func _side_activity_can_interact() -> bool:
	if player == null:
		return false
	var runtime_index := _active_side_activity_index()
	if runtime_index < 0:
		return false
	var runtime: Dictionary = side_activity_runtimes[runtime_index]
	var target := _side_activity_current_target_for_runtime(runtime)
	return target != null and target.can_interact(player.global_position)

func _side_activity_current_target() -> InteractionTarget:
	var runtime_index := _active_side_activity_index()
	if runtime_index >= 0:
		return _side_activity_current_target_for_runtime(side_activity_runtimes[runtime_index])
	return null

func _active_side_activity_index() -> int:
	for runtime_index in range(side_activity_runtimes.size()):
		if bool(side_activity_runtimes[runtime_index].get("accepted", false)) and not bool(side_activity_runtimes[runtime_index].get("completed", false)):
			return runtime_index
	for runtime_index in range(side_activity_runtimes.size()):
		if bool(side_activity_runtimes[runtime_index].get("unlocked", false)):
			return runtime_index
	return -1

func _side_activity_current_target_for_runtime(runtime: Dictionary) -> InteractionTarget:
	var delivery_target := runtime.get("delivery_target") as InteractionTarget
	if bool(runtime.get("accepted", false)) and delivery_target != null and delivery_target.visible:
		return delivery_target
	var target := runtime.get("target") as InteractionTarget
	if bool(runtime.get("unlocked", false)) and target != null and target.visible:
		return target
	return null

func _build_vehicle() -> void:
	vehicle = VehicleClass.new()
	var runtime_config: Dictionary = city_pack.get("runtime", {})
	var vehicle_config: Dictionary = runtime_config.get("vehicle", {})
	vehicle.max_speed = float(vehicle_config.get("max_speed", vehicle.max_speed))
	vehicle.acceleration = float(vehicle_config.get("acceleration", vehicle.acceleration))
	vehicle.braking = float(vehicle_config.get("braking", vehicle.braking))
	vehicle.turn_speed = float(vehicle_config.get("turn_speed", vehicle.turn_speed))
	vehicle.enter_radius = float(vehicle_config.get("enter_radius", vehicle.enter_radius))
	var configured_seat_offset = vehicle_config.get("driver_seat_offset", [])
	if configured_seat_offset is Array and configured_seat_offset.size() == 3:
		vehicle.driver_seat_offset = Vector3(float(configured_seat_offset[0]), float(configured_seat_offset[1]), float(configured_seat_offset[2]))
	vehicle_camera_distance = float(vehicle_config.get("camera_distance", vehicle_camera_distance))
	vehicle_camera_height = float(vehicle_config.get("camera_height", vehicle_camera_height))
	vehicle_camera_pitch_degrees = clampf(float(vehicle_config.get("camera_pitch_degrees", vehicle_camera_pitch_degrees)), -55.0, -5.0)
	vehicle_damage_per_speed = float(vehicle_config.get("collision_damage_per_speed", vehicle_damage_per_speed))
	vehicle.name = "蓝色三轮车"
	vehicle.position = Vector3(-6.0, 0.7, 5.0)
	add_child(vehicle)
	vehicle.driver_changed.connect(_on_vehicle_driver_changed)
	var vehicle_visual := Node3D.new()
	vehicle_visual.name = "原创灰盒三轮车外观"
	var chassis := _box_mesh(Vector3(1.8, 1.0, 2.8), Color("277fa4"))
	chassis.name = "三轮车底盘"
	vehicle_visual.add_child(chassis)
	var front_guard := _box_mesh(Vector3(1.35, 0.45, 1.1), Color("d8a83f"))
	front_guard.name = "三轮车前挡板"
	front_guard.position = Vector3(0.0, 0.72, -0.65)
	vehicle_visual.add_child(front_guard)
	var headlight := _box_mesh(Vector3(0.9, 0.18, 0.7), Color("f0c752"))
	headlight.name = "三轮车前灯"
	headlight.position = Vector3(0.0, 1.0, -0.65)
	var headlight_material := StandardMaterial3D.new()
	headlight_material.albedo_color = Color("f0c752")
	headlight_material.emission_enabled = true
	headlight_material.emission = Color("ffd978")
	headlight_material.emission_energy_multiplier = 1.45
	headlight_material.roughness = 0.32
	headlight.material_override = headlight_material
	vehicle_visual.add_child(headlight)
	var headlight_glow := OmniLight3D.new()
	headlight_glow.name = "三轮车前灯照明"
	headlight_glow.position = Vector3(0.0, 1.0, -1.03)
	headlight_glow.light_color = Color("ffd88a")
	headlight_glow.light_energy = 0.18
	headlight_glow.omni_range = 3.4
	headlight_glow.shadow_enabled = false
	headlight_glow.set_meta("visual_only", true)
	vehicle_visual.add_child(headlight_glow)
	var cargo_bed := _box_mesh(Vector3(1.45, 0.18, 0.92), Color("1e5368"))
	cargo_bed.name = "三轮车货架"
	cargo_bed.position = Vector3(0.0, 0.92, 0.58)
	vehicle_visual.add_child(cargo_bed)
	var seat := _box_mesh(Vector3(0.72, 0.18, 0.62), Color("3b2d2a"))
	seat.name = "三轮车座椅"
	seat.position = Vector3(0.0, 0.92, 0.18)
	vehicle_visual.add_child(seat)
	var seat_back := _box_mesh(Vector3(0.72, 0.52, 0.12), Color("3b2d2a"))
	seat_back.name = "三轮车靠背"
	seat_back.position = Vector3(0.0, 1.15, 0.48)
	vehicle_visual.add_child(seat_back)
	var steering_post := _box_mesh(Vector3(0.08, 0.58, 0.08), Color("2c333b"))
	steering_post.name = "三轮车车把立柱"
	steering_post.position = Vector3(0.0, 1.28, -0.76)
	steering_post.rotation_degrees.x = -12.0
	vehicle_visual.add_child(steering_post)
	var handlebar := _box_mesh(Vector3(0.96, 0.08, 0.08), Color("2c333b"))
	handlebar.name = "三轮车车把"
	handlebar.position = Vector3(0.0, 1.55, -0.86)
	vehicle_visual.add_child(handlebar)
	for side in [-1.0, 1.0]:
		var mirror_stem := _box_mesh(Vector3(0.05, 0.34, 0.05), Color("313841"))
		mirror_stem.name = "三轮车后视镜支架-%s" % ("左" if side < 0.0 else "右")
		mirror_stem.position = Vector3(side * 0.55, 1.69, -0.86)
		mirror_stem.rotation_degrees.z = side * -16.0
		vehicle_visual.add_child(mirror_stem)
		var mirror := _box_mesh(Vector3(0.22, 0.16, 0.05), Color("9aa3a8"))
		mirror.name = "三轮车后视镜-%s" % ("左" if side < 0.0 else "右")
		mirror.position = Vector3(side * 0.68, 1.84, -0.84)
		vehicle_visual.add_child(mirror)
	for side in [-1.0, 1.0]:
		var wheel_arch := _box_mesh(Vector3(0.16, 0.22, 0.92), Color("1a5c73"))
		wheel_arch.name = "三轮车后轮挡泥板-%s" % ("左" if side < 0.0 else "右")
		wheel_arch.position = Vector3(side * 0.94, 0.02, 0.72)
		wheel_arch.rotation_degrees.x = 8.0
		vehicle_visual.add_child(wheel_arch)
	# 驾驶后视镜头的识别重点：尾门、尾灯、货架和侧护板必须形成清晰
	# 的三轮配送车轮廓，避免只靠一块蓝色方盒承担整辆车的视觉信息。
	var rear_panel := _box_mesh(Vector3(1.58, 0.72, 0.12), Color("2c91b4"))
	rear_panel.name = "三轮车货厢尾门"
	rear_panel.position = Vector3(0.0, 0.88, 1.30)
	vehicle_visual.add_child(rear_panel)
	var rear_bumper := _box_mesh(Vector3(1.76, 0.14, 0.16), Color("174b5d"))
	rear_bumper.name = "三轮车后保险杠"
	rear_bumper.position = Vector3(0.0, 0.48, 1.42)
	vehicle_visual.add_child(rear_bumper)
	for side in [-1.0, 1.0]:
		var tail_light := _box_mesh(Vector3(0.18, 0.16, 0.06), Color("d94848"))
		tail_light.name = "三轮车尾灯-%s" % ("左" if side < 0.0 else "右")
		tail_light.position = Vector3(side * 0.58, 0.92, 1.37)
		var tail_light_material := StandardMaterial3D.new()
		tail_light_material.albedo_color = Color("d94848")
		tail_light_material.emission_enabled = true
		tail_light_material.emission = Color("ef554d")
		tail_light_material.emission_energy_multiplier = 0.65
		tail_light.material_override = tail_light_material
		vehicle_visual.add_child(tail_light)
		var side_guard := _box_mesh(Vector3(0.10, 0.46, 1.18), Color("236d86"))
		side_guard.name = "三轮车货厢侧护板-%s" % ("左" if side < 0.0 else "右")
		side_guard.position = Vector3(side * 0.78, 1.06, 0.72)
		vehicle_visual.add_child(side_guard)
	for cargo_index in range(2):
		var cargo_box := _box_mesh(Vector3(0.48, 0.22, 0.48), Color("d6a43c" if cargo_index == 0 else "e0b850"))
		cargo_box.name = "三轮车货厢货物-%d" % cargo_index
		cargo_box.position = Vector3(-0.38 + cargo_index * 0.76, 1.12, 0.70)
		vehicle_visual.add_child(cargo_box)
	var cargo_separator := _box_mesh(Vector3(1.34, 0.08, 0.08), Color("8e692a"))
	cargo_separator.name = "三轮车货厢横向固定条"
	cargo_separator.position = Vector3(0.0, 1.29, 0.72)
	vehicle_visual.add_child(cargo_separator)
	var rear_plate := _box_mesh(Vector3(0.42, 0.16, 0.035), Color("f0d36e"))
	rear_plate.name = "三轮车后牌照占位"
	rear_plate.position = Vector3(0.0, 0.82, 1.375)
	vehicle_visual.add_child(rear_plate)
	_add_vehicle_wheels(vehicle_visual)
	var vehicle_mount: Dictionary
	if _catalog_slot_has_scene("three-wheel-vehicle"):
		vehicle_mount = AssetRuntimeCatalogClass.mount_optional_visual(vehicle, asset_catalog, "three-wheel-vehicle", vehicle_visual)
	else:
		var internal_vehicle_visual := _mount_internal_candidate_visual(vehicle, OriginalCityVehicleScene, vehicle_visual, "Visual")
		vehicle_mount = {"used_fallback": false, "blocked": false, "node": internal_vehicle_visual}
	if not bool(vehicle_mount.get("used_fallback", true)):
		var mounted_visual := vehicle_mount.get("node") as Node
		_bind_vehicle_wheels_from_visual(mounted_visual)
		# 成品候选载具可以提供与自身材质、灯组和尺寸绑定的损伤反馈。
		# 只有明确存在该面板时才屏蔽灰盒回退，避免普通候选缺少反馈时静默丢失信息。
		vehicle_visual_handles_damage_feedback = mounted_visual != null and mounted_visual.find_child("候选三轮车损伤面板", true, false) != null
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.0, 2.8)
	collision.shape = box
	vehicle.add_child(collision)
	vehicle_damage_visual = _box_mesh(Vector3(1.55, 0.06, 0.12), Color("e05252"))
	vehicle_damage_visual.name = "三轮车损伤标记"
	vehicle_damage_visual.position = Vector3(0.0, 1.42, -0.25)
	vehicle_damage_visual.visible = false
	vehicle.add_child(vehicle_damage_visual)
	vehicle_damage_side_visual = _box_mesh(Vector3(0.05, 0.34, 0.62), Color("8c2930"))
	vehicle_damage_side_visual.name = "三轮车损伤侧板"
	vehicle_damage_side_visual.position = Vector3(-0.86, 0.92, 0.08)
	vehicle_damage_side_visual.rotation_degrees.z = -8.0
	vehicle_damage_side_visual.visible = false
	vehicle.add_child(vehicle_damage_side_visual)
	vehicle_damage_warning_visual = _box_mesh(Vector3(0.22, 0.07, 0.07), Color("f0c752"))
	vehicle_damage_warning_visual.name = "三轮车损伤警示灯"
	vehicle_damage_warning_visual.position = Vector3(0.0, 1.58, -0.84)
	vehicle_damage_warning_visual.visible = false
	vehicle.add_child(vehicle_damage_warning_visual)
	for smoke_index in range(3):
		var smoke := MeshInstance3D.new()
		smoke.name = "三轮车损伤烟雾-%d" % smoke_index
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.13 + smoke_index * 0.025
		smoke_mesh.height = (0.26 + smoke_index * 0.05)
		smoke.mesh = smoke_mesh
		var smoke_material := StandardMaterial3D.new()
		smoke_material.albedo_color = Color(0.12, 0.14, 0.15, 0.62)
		smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_material.roughness = 0.92
		smoke.material_override = smoke_material
		smoke.position = Vector3(-0.22 + smoke_index * 0.20, 1.48 + smoke_index * 0.07, 0.18)
		smoke.visible = false
		vehicle.add_child(smoke)
		vehicle_damage_smoke.append(smoke)

func _check_vehicle_collisions(delta: float) -> void:
	vehicle_collision_cooldown = maxf(vehicle_collision_cooldown - delta, 0.0)
	pedestrian_near_miss_cooldown = maxf(pedestrian_near_miss_cooldown - delta, 0.0)
	if vehicle == null or vehicle.driver == null or vehicle_collision_cooldown > 0.0:
		return
	if absf(vehicle.current_speed) < 0.2:
		return
	if absf(vehicle.current_speed) >= 1.5:
		for pedestrian in pedestrians:
			if not is_instance_valid(pedestrian) or pedestrian.displaced:
				continue
			if vehicle.global_position.distance_to(pedestrian.global_position) > 1.55:
				continue
			if not pedestrian.react_to_vehicle(vehicle.global_position):
				continue
			trace.record("pedestrian_near_miss", {"pedestrian": pedestrian.role_id, "speed": vehicle.current_speed})
			audio_events.emit_event("perception_alert", {"source": "载具近失", "pedestrian": pedestrian.role_id})
			if pedestrian_near_miss_cooldown <= 0.0:
				pedestrian_near_miss_cooldown = 1.0
				wanted.report(1, "险些撞到行人")
				message = "行人受到惊吓，保持低速驾驶"
				if hud_visual != null and hud_visual.has_method("trigger_feedback"):
					hud_visual.trigger_feedback(Color("f0c752"), 0.16, 0.20)
			break
	if vehicle.get_slide_collision_count() > 0:
		apply_vehicle_collision_damage(maxf(8.0, absf(vehicle.current_speed) * 3.0), "环境碰撞")
		return
	for traffic in traffic_vehicles:
		if is_instance_valid(traffic) and vehicle.global_position.distance_to(traffic.global_position) < 2.0:
			apply_vehicle_collision_damage(maxf(10.0, absf(vehicle.current_speed) * vehicle_damage_per_speed), str(traffic.name))
			return

func apply_vehicle_collision_damage(amount: float, source := "交通车辆") -> bool:
	if vehicle == null or amount <= 0.0 or vehicle_integrity <= 0.0:
		return false
	vehicle_integrity = clampf(vehicle_integrity - amount, 0.0, 100.0)
	vehicle_collision_cooldown = 0.8
	wanted.report(1, source)
	message = "载具碰撞：耐久 %d%%" % roundi(vehicle_integrity)
	trace.record("vehicle_damage", {"amount": amount, "source": source, "integrity": vehicle_integrity})
	if audio_events != null:
		audio_events.emit_event("vehicle_collision", {"amount": amount, "source": source, "integrity": vehicle_integrity})
	if hud_visual != null and hud_visual.has_method("trigger_feedback"):
		hud_visual.trigger_feedback(Color("e05252"), minf(0.48, 0.18 + amount / 180.0), 0.24)
	if camera_rig != null and camera_rig.has_method("pulse_feedback"):
		camera_rig.pulse_feedback(clampf(amount / 60.0, 0.14, 0.55), 0.16, 22.0)
	if vehicle_integrity <= 0.0:
		message = "载具损毁，任务失败"
		trace.record("vehicle_failed", {"source": source})
		if audio_events != null:
			audio_events.emit_event("vehicle_destroyed", {"source": source})
		mission.fail("载具损毁")
	_update_vehicle_damage_feedback()
	_update_hud()
	return true

func _update_vehicle_damage_feedback() -> void:
	if vehicle_status_label == null:
		return
	var damaged := vehicle_integrity < 100.0
	if vehicle_visual_handles_damage_feedback:
		# 候选视觉脚本会读取父级 vehicle_integrity 并驱动自己的损伤面板、灯光与材质。
		# 城市层的这些节点只作为灰盒回退，不能与成品候选叠加造成漂浮标记。
		var mounted_visual := vehicle.get_node_or_null("Visual")
		if mounted_visual != null and mounted_visual.has_method("set_candidate_damage_state"):
			mounted_visual.call("set_candidate_damage_state", vehicle_integrity)
		if vehicle_damage_visual != null:
			vehicle_damage_visual.visible = false
		if vehicle_damage_side_visual != null:
			vehicle_damage_side_visual.visible = false
		if vehicle_damage_warning_visual != null:
			vehicle_damage_warning_visual.visible = false
		for smoke in vehicle_damage_smoke:
			if is_instance_valid(smoke):
				smoke.visible = false
	else:
		if vehicle_damage_visual != null:
			vehicle_damage_visual.visible = damaged
			if vehicle_damage_visual.visible:
				var damage_ratio := 1.0 - vehicle_integrity / 100.0
				vehicle_damage_visual.scale = Vector3(1.0 + damage_ratio * 0.25, 1.0, 1.0 + damage_ratio * 0.1)
				var damage_material := vehicle_damage_visual.material_override as StandardMaterial3D
				if damage_material != null:
					damage_material.albedo_color = Color("e05252") if vehicle_integrity < 35.0 else Color("f0c752")
		if vehicle_damage_side_visual != null:
			vehicle_damage_side_visual.visible = damaged
			var side_material := vehicle_damage_side_visual.material_override as StandardMaterial3D
			if side_material != null:
				side_material.albedo_color = Color("c6323a") if vehicle_integrity < 35.0 else Color("8c2930")
		if vehicle_damage_warning_visual != null:
			vehicle_damage_warning_visual.visible = damaged
			var warning_material := vehicle_damage_warning_visual.material_override as StandardMaterial3D
			if warning_material != null:
				warning_material.albedo_color = Color("e05252") if vehicle_integrity < 35.0 else Color("f0c752")
		for smoke in vehicle_damage_smoke:
			if is_instance_valid(smoke):
				smoke.visible = damaged
	if vehicle_integrity >= 100.0:
		vehicle_status_label.text = ""
		vehicle_status_label.visible = false
	else:
		vehicle_status_label.text = "载具耐久：%d%%" % roundi(vehicle_integrity)
		vehicle_status_label.visible = true
		vehicle_status_label.add_theme_color_override("font_color", Color("e05252") if vehicle_integrity < 35.0 else Color("f0c752"))

func _build_pedestrians() -> void:
	var default_routes := [
		[Vector3(-4.0, 0.9, -2.0), Vector3(4.0, 0.9, -2.0)],
		[Vector3(6.0, 0.9, 4.0), Vector3(6.0, 0.9, 12.0)],
		[Vector3(-10.0, 0.9, 4.0), Vector3(-10.0, 0.9, -4.0)],
		[Vector3(3.0, 0.9, 12.0), Vector3(10.0, 0.9, 12.0)]
	]
	var crowd_config: Dictionary = city_pack.get("runtime", {}).get("crowd", {})
	var raw_routes = crowd_config.get("routes", [])
	var crowd_routes: Array = default_routes
	if raw_routes is Array and not raw_routes.is_empty():
		crowd_routes = []
		for raw_route in raw_routes:
			var route: Array[Vector3] = []
			if raw_route is Array:
				for raw_point in raw_route:
					if raw_point is Array and raw_point.size() == 3:
						route.append(Vector3(float(raw_point[0]), float(raw_point[1]), float(raw_point[2])))
			if route.size() >= 2:
				crowd_routes.append(route)
	var crowd_walk_speed := float(crowd_config.get("walk_speed", 1.4))
	for index in range(crowd_routes.size()):
		var pedestrian: CityPedestrian = PedestrianClass.new()
		pedestrian.name = "行人_%d" % index
		pedestrian.walk_speed = crowd_walk_speed
		var role := _crowd_role(index)
		pedestrian.role_id = role.id
		pedestrian.role_label = role.label
		pedestrian.position = crowd_routes[index][0]
		pedestrian.waypoints = crowd_routes[index]
		add_child(pedestrian)
		var jacket_color := Color("6f6877" if index % 2 == 0 else "8e715f")
		var pants_color := Color("303641" if index % 2 == 0 else "4a3d3a")
		var pedestrian_visual := _character_visual(jacket_color, pants_color, Color("252b36"), false)
		pedestrian_visual.name = "原创程序化人群外观-" + role.id
		_add_crowd_role_details(pedestrian_visual, index, role)
		var mounted_visual: Node
		if _catalog_slot_has_scene("city-crowd-set"):
			var mount_result: Dictionary = AssetRuntimeCatalogClass.mount_optional_visual(pedestrian, asset_catalog, "city-crowd-set", pedestrian_visual)
			mounted_visual = mount_result.get("node") as Node
		else:
			mounted_visual = _mount_internal_candidate_visual(pedestrian, OriginalCityCrowdScene, pedestrian_visual, "Visual")
		_align_original_city_crowd_visual_to_ground(mounted_visual)
		if mounted_visual != null:
			# 运行时统一登记城市人群的确定性外观契约；候选场景可以是
			# MakeHuman、Quaternius 或原创程序化实现，但验收读取同一组元数据。
			mounted_visual.set_meta("city_variant_index", index % 3)
			mounted_visual.set_meta("city_variant_contract", "deterministic_suit_skin_hair_palette")
		pedestrians.append(pedestrian)
	conflict_agent = Node3D.new()
	conflict_agent.name = "冲突对象"
	conflict_agent.position = Vector3(4.0, 0.9, -2.0)
	add_child(conflict_agent)
	var conflict_visual := _character_visual(Color("a83f45"), Color("252b36"), Color("4b2027"), true)
	conflict_visual.name = "原创程序化冲突对象外观"
	_add_conflict_role_details(conflict_visual)
	var mounted_conflict_visual: Node
	if _catalog_slot_has_scene("city-crowd-set"):
		var conflict_mount_result: Dictionary = AssetRuntimeCatalogClass.mount_optional_visual(conflict_agent, asset_catalog, "city-crowd-set", conflict_visual)
		mounted_conflict_visual = conflict_mount_result.get("node") as Node
	else:
		mounted_conflict_visual = _mount_internal_candidate_visual(conflict_agent, OriginalCityCrowdScene, conflict_visual, "Visual")
	_align_original_city_crowd_visual_to_ground(mounted_conflict_visual)

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

func _align_original_city_crowd_visual_to_ground(visual: Node) -> void:
	if not visual is Node3D:
		return
	var visual_3d := visual as Node3D
	if visual_3d.has_meta("city_makehuman_asset"):
		# MakeHuman 候选 GLB 的技术契约记录底部局部坐标；候选根可能带有
		# 城市角色体型缩放，因此按当前根缩放反推出世界接地偏移。
		var foot_origin_y := float(visual_3d.get_meta("city_makehuman_foot_origin_y", -0.0143))
		var role_scale := maxf(absf(visual_3d.scale.y), 0.001)
		visual_3d.position.y = -foot_origin_y * role_scale
		visual_3d.set_meta("ground_contact_offset", visual_3d.position.y)
		return
	if not visual_3d.has_meta("original_procedural_asset"):
		return
	var role_scale := maxf(absf(visual_3d.scale.y), 0.001)
	# 原创城市角色的局部鞋底约为 y=-1.075；将角色根节点抬到路线高度，避免穿过道路。
	visual_3d.position.y = ORIGINAL_CITY_CROWD_FOOT_OFFSET * role_scale
	visual_3d.set_meta("ground_contact_offset", visual_3d.position.y)

func _crowd_role(index: int) -> Dictionary:
	var roles := [
		{"id": "courier", "label": "配送员"},
		{"id": "office_worker", "label": "上班族"},
		{"id": "shopper", "label": "买菜居民"},
		{"id": "street_vendor", "label": "街边摊主"}
	]
	return roles[index % roles.size()]

func _add_crowd_role_details(visual: Node3D, index: int, role: Dictionary) -> void:
	# 角色差异只使用原创程序化几何，保证候选资产仍可安全回退且不改变碰撞体。
	var role_id := str(role.get("id", "street_walker"))
	match role_id:
		"courier":
			var cap := _cylinder_mesh(0.29, 0.08, Color("d39a3d"))
			cap.name = "配送员帽"
			cap.position = Vector3(0.0, 0.9, -0.02)
			visual.add_child(cap)
			var shoulder_bag := _box_mesh(Vector3(0.32, 0.42, 0.14), Color("3e596b"))
			shoulder_bag.name = "配送员肩包"
			shoulder_bag.position = Vector3(0.42, -0.05, 0.16)
			shoulder_bag.rotation_degrees.z = -12.0
			visual.add_child(shoulder_bag)
		"office_worker":
			var tie := _box_mesh(Vector3(0.11, 0.36, 0.05), Color("c84c4c"))
			tie.name = "上班族领带"
			tie.position = Vector3(0.0, 0.05, -0.23)
			visual.add_child(tie)
			var badge := _box_mesh(Vector3(0.18, 0.14, 0.04), Color("f0c752"))
			badge.name = "上班族工牌"
			badge.position = Vector3(0.23, 0.12, -0.23)
			visual.add_child(badge)
		"shopper":
			var tote := _box_mesh(Vector3(0.34, 0.42, 0.2), Color("6b8d69"))
			tote.name = "居民手提袋"
			tote.position = Vector3(-0.58, -0.28, -0.04)
			visual.add_child(tote)
			var tote_handle := _box_mesh(Vector3(0.04, 0.26, 0.04), Color("d0b27a"))
			tote_handle.name = "居民手提袋提手"
			tote_handle.position = Vector3(-0.58, -0.02, -0.04)
			visual.add_child(tote_handle)
		"street_vendor":
			var apron := _box_mesh(Vector3(0.5, 0.48, 0.04), Color("d2a55c"))
			apron.name = "摊主围裙"
			apron.position = Vector3(0.0, -0.13, -0.24)
			visual.add_child(apron)
			var hat := _cylinder_mesh(0.28, 0.1, Color("e0d6bd"))
			hat.name = "摊主遮阳帽"
			hat.position = Vector3(0.0, 0.91, 0.0)
			visual.add_child(hat)

func _add_conflict_role_details(visual: Node3D) -> void:
	var warning_band := _box_mesh(Vector3(0.76, 0.12, 0.46), Color("e05252"))
	warning_band.name = "冲突对象警示带"
	warning_band.position = Vector3(0.0, 0.1, -0.02)
	visual.add_child(warning_band)
	var warning_marker := _cylinder_mesh(0.16, 0.06, Color("f0c752"))
	warning_marker.name = "冲突对象警示标记"
	warning_marker.position = Vector3(0.0, 1.02, 0.0)
	visual.add_child(warning_marker)

func _build_traffic() -> void:
	var default_specs := [
		{"id": "街道车辆_北行", "travel_speed": 2.2, "color": "7b3f3f", "route": [[-2.0, 0.55, 15.0], [-2.0, 0.55, -15.0]]},
		{"id": "街道车辆_南行", "travel_speed": 2.2, "color": "3b6076", "route": [[2.0, 0.55, -15.0], [2.0, 0.55, 15.0]]},
		{"id": "街道车辆_东行", "travel_speed": 1.8, "color": "9b7c3a", "route": [[-15.0, 0.55, 1.2], [15.0, 0.55, 1.2]]}
	]
	var traffic_config: Dictionary = city_pack.get("runtime", {}).get("traffic", {})
	var vehicle_specs = traffic_config.get("vehicles", default_specs)
	if not vehicle_specs is Array or vehicle_specs.is_empty():
		vehicle_specs = default_specs
	for spec in vehicle_specs:
		if not spec is Dictionary:
			continue
		var points: Array[Vector3] = []
		for raw_point in spec.get("route", []):
			if raw_point is Array and raw_point.size() == 3:
				points.append(Vector3(float(raw_point[0]), float(raw_point[1]), float(raw_point[2])))
		if points.size() >= 2:
			_add_traffic_vehicle(str(spec.get("id", "街道车辆")), points, _color_from_hex(spec.get("color", "7b3f3f"), Color("7b3f3f")), float(spec.get("travel_speed", 2.0)))
	for pedestrian in pedestrians:
		pedestrian.set_traffic_sources(traffic_vehicles)

func _add_traffic_vehicle(label: String, points: Array[Vector3], color: Color, configured_speed := -1.0) -> void:
	var traffic = TrafficVehicleClass.new()
	traffic.name = label
	traffic.travel_speed = configured_speed if configured_speed >= 0.0 else (2.2 if traffic_vehicles.size() < 2 else 1.8)
	traffic.configure_path(points)
	if points.size() >= 2 and is_equal_approx(points[0].x, points[1].x) and absf(points[0].x) <= 2.1:
		var stop_z := 3.2 if points[1].z < points[0].z else -3.2
		traffic.configure_signal_stop(Vector3(points[0].x, points[0].y, stop_z))
	traffic.set_signal_red(city_signal_elapsed >= 7.5)
	traffic.add_body(color)
	add_child(traffic)
	traffic_vehicles.append(traffic)

func _build_hud() -> void:
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.name = "候选背景卡层"
	backdrop_layer.layer = -1
	add_child(backdrop_layer)
	var layer := CanvasLayer.new()
	add_child(layer)
	city_reference_backdrop = TextureRect.new()
	city_reference_backdrop.name = "原创城市驾驶远景全屏候选卡"
	city_reference_backdrop.texture = OriginalCity08BackdropTexture
	city_reference_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	city_reference_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	city_reference_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_reference_backdrop.z_index = -100
	city_reference_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_reference_backdrop.visible = false
	backdrop_layer.add_child(city_reference_backdrop)
	hud_label = Label.new()
	hud_label.position = Vector2(28.0, 24.0)
	hud_label.add_theme_font_size_override("font_size", 15)
	hud_label.add_theme_color_override("font_outline_color", Color("172033"))
	hud_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud_label)
	mission_title_label = Label.new()
	mission_title_label.anchor_left = 0.5
	mission_title_label.anchor_right = 0.5
	mission_title_label.offset_left = -180.0
	mission_title_label.offset_right = 180.0
	mission_title_label.offset_top = 22.0
	mission_title_label.offset_bottom = 62.0
	mission_title_label.add_theme_font_size_override("font_size", 17)
	mission_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_title_label.add_theme_color_override("font_outline_color", Color("172033"))
	mission_title_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(mission_title_label)
	money_label = Label.new()
	money_label.anchor_left = 1.0
	money_label.anchor_right = 1.0
	money_label.offset_left = -140.0
	money_label.offset_right = -24.0
	money_label.offset_top = 24.0
	money_label.offset_bottom = 52.0
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.add_theme_font_size_override("font_size", 18)
	money_label.add_theme_color_override("font_color", Color("ffe5a8"))
	money_label.add_theme_color_override("font_outline_color", Color("172033"))
	money_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(money_label)
	wanted_label = Label.new()
	wanted_label.anchor_left = 1.0
	wanted_label.anchor_right = 1.0
	wanted_label.offset_left = -190.0
	wanted_label.offset_right = -24.0
	wanted_label.offset_top = 54.0
	wanted_label.offset_bottom = 82.0
	wanted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wanted_label.add_theme_font_size_override("font_size", 17)
	wanted_label.add_theme_color_override("font_color", Color("f0c752"))
	wanted_label.add_theme_color_override("font_outline_color", Color("172033"))
	wanted_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(wanted_label)
	vehicle_status_label = Label.new()
	vehicle_status_label.anchor_left = 1.0
	vehicle_status_label.anchor_right = 1.0
	vehicle_status_label.offset_left = -260.0
	vehicle_status_label.offset_right = -24.0
	vehicle_status_label.offset_top = 86.0
	vehicle_status_label.offset_bottom = 116.0
	vehicle_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vehicle_status_label.add_theme_font_size_override("font_size", 16)
	vehicle_status_label.add_theme_color_override("font_outline_color", Color("172033"))
	vehicle_status_label.add_theme_constant_override("outline_size", 6)
	vehicle_status_label.visible = false
	layer.add_child(vehicle_status_label)
	hint_label = Label.new()
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -340.0
	hint_label.offset_right = 340.0
	hint_label.offset_top = -48.0
	hint_label.offset_bottom = -18.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_outline_color", Color("172033"))
	hint_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(hint_label)
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
	prompt_label.add_theme_color_override("font_color", Color("f0c752"))
	prompt_label.add_theme_color_override("font_outline_color", Color("172033"))
	prompt_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(prompt_label)
	mini_map = Label.new()
	mini_map.anchor_top = 1.0
	mini_map.anchor_bottom = 1.0
	mini_map.offset_left = 30.0
	mini_map.offset_right = 202.0
	mini_map.offset_top = -210.0
	mini_map.offset_bottom = -28.0
	mini_map.add_theme_font_size_override("font_size", 18)
	mini_map.add_theme_color_override("font_outline_color", Color("172033"))
	mini_map.add_theme_constant_override("outline_size", 6)
	mini_map.text = "┌────────┐\n│  ·  ▲  │\n│ · ┼ ·  │\n│  ·  ·  │\n└────────┘"
	layer.add_child(mini_map)
	hud_label.visible = false
	mission_title_label.visible = false
	money_label.visible = false
	wanted_label.visible = false
	hint_label.visible = false
	prompt_label.visible = false
	mini_map.visible = false
	hud_visual = GameHudVisualClass.new()
	hud_visual.name = "城市 HUD 表现层"
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

func _add_target(identifier: String, label: String, location: Vector3, color: Color) -> void:
	var target: InteractionTarget = InteractionTargetClass.new()
	target.name = label
	target.interaction_id = identifier
	target.prompt = label
	target.position = location
	target.interaction_radius = 2.0
	target.one_shot = true
	add_child(target)
	# 任务点只保留可读的视觉信标，不再用大块方盒挡住城市街景。
	var beacon_root := Node3D.new()
	beacon_root.name = "任务目标视觉信标"
	beacon_root.set_meta("visual_only", true)
	beacon_root.set_meta("candidate_visual_only", true)
	target.add_child(beacon_root)
	var beacon_color := color if color != Color.WHITE else Color("e0a45d")
	var base := _cylinder_mesh(0.34, 0.08, beacon_color.darkened(0.28))
	base.name = "任务信标底座"
	base.position = Vector3(0.0, 0.04, 0.0)
	base.set_meta("visual_only", true)
	beacon_root.add_child(base)
	var stem := _cylinder_mesh(0.055, 0.76, beacon_color)
	stem.name = "任务信标灯柱"
	stem.position = Vector3(0.0, 0.43, 0.0)
	stem.set_meta("visual_only", true)
	beacon_root.add_child(stem)
	var cap := _box_mesh(Vector3(0.34, 0.14, 0.34), beacon_color.lightened(0.16))
	cap.name = "任务信标识别片"
	cap.position = Vector3(0.0, 0.84, 0.0)
	cap.set_meta("visual_only", true)
	beacon_root.add_child(cap)
	targets.append(target)

func _add_static_box(label: String, size: Vector3, location: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = location
	add_child(body)
	body.add_child(_box_mesh(size, color))
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)

func _add_open_store(label: String, size: Vector3, center: Vector3, color: Color) -> void:
	var wall_thickness := 0.22
	_add_static_box(label + "后墙", Vector3(size.x, size.y, wall_thickness), center + Vector3(0.0, 0.0, -size.z * 0.5 + wall_thickness * 0.5), color)
	_add_static_box(label + "左墙", Vector3(wall_thickness, size.y, size.z), center + Vector3(-size.x * 0.5 + wall_thickness * 0.5, 0.0, 0.0), color)
	_add_static_box(label + "右墙", Vector3(wall_thickness, size.y, size.z), center + Vector3(size.x * 0.5 - wall_thickness * 0.5, 0.0, 0.0), color)
	_add_static_box(label + "门头", Vector3(size.x, 0.55, wall_thickness), center + Vector3(0.0, size.y * 0.5 - 0.28, size.z * 0.5 - wall_thickness * 0.5), color)
	# 店内镜头会把顶面占据画面上半部；用偏暖的哑光灰替代近黑色，
	# 让室内灯光、写实背景卡和程序化道具保持同一曝光层级。
	var roof := _box_mesh(Vector3(size.x, 0.12, size.z), Color("514942"))
	roof.name = label + "屋顶"
	roof.position = center + Vector3(0.0, size.y * 0.5 + 0.06, 0.0)
	add_child(roof)
	_add_store_interior_lights(center)
	_add_label_3d("进入商店", center + Vector3(0.0, 2.15, size.z * 0.5 + 0.18), Color("f5e2b6"))

func _add_store_front_details(center: Vector3) -> void:
	var details := Node3D.new()
	details.name = "商店门面细节"
	add_child(details)
	var front_z := center.z + 2.18
	for index in range(7):
		var awning := _box_mesh(Vector3(0.85, 0.18, 0.62), Color("f2e4cc" if index % 2 == 0 else "c9342e"))
		awning.position = Vector3(center.x - 3.0 + index * 1.0, 2.7, front_z)
		details.add_child(awning)
	var counter := _box_mesh(Vector3(6.2, 0.7, 0.12), Color("725b49"))
	counter.position = Vector3(center.x, 1.0, front_z + 0.12)
	details.add_child(counter)
	for index in range(5):
		var window := _box_mesh(Vector3(1.0, 1.2, 0.05), Color("6e8a91"))
		window.position = Vector3(center.x - 2.5 + index * 1.25, 1.95, front_z + 0.02)
		details.add_child(window)

func _add_new_shop_front(center: Vector3) -> void:
	# 新阶段目标的原创灰盒门面，避免矩阵采集只看到无语义的整块建筑。
	var facade := Node3D.new()
	facade.name = "旺铺转让门面"
	facade.set_meta("visual_candidate", true)
	facade.set_meta("visual_only", true)
	add_child(facade)
	var shutter := _box_mesh(Vector3(5.6, 2.0, 0.12), Color("b84a43"))
	shutter.name = "旺铺转让卷帘门主体"
	shutter.set_meta("visual_only", true)
	shutter.position = center + Vector3(0.0, 1.35, 2.02)
	facade.add_child(shutter)
	var shutter_detail := Node3D.new()
	shutter_detail.name = "旺铺转让卷帘门细节"
	shutter_detail.set_meta("visual_only", true)
	facade.add_child(shutter_detail)
	for index in range(8):
		var shutter_slat := _box_mesh(Vector3(5.32, 0.065, 0.045), Color("d07062" if index % 2 == 0 else "983f3b"))
		shutter_slat.name = "旺铺转让卷帘门横槽-%02d" % index
		shutter_slat.position = center + Vector3(0.0, 0.52 + index * 0.22, 1.93)
		shutter_slat.set_meta("visual_only", true)
		shutter_detail.add_child(shutter_slat)
	var left_post := _box_mesh(Vector3(0.16, 2.12, 0.15), Color("6c4d49"))
	left_post.name = "旺铺转让门框左柱"
	left_post.position = center + Vector3(-2.75, 1.35, 2.0)
	left_post.set_meta("visual_only", true)
	facade.add_child(left_post)
	var right_post := _box_mesh(Vector3(0.16, 2.12, 0.15), Color("6c4d49"))
	right_post.name = "旺铺转让门框右柱"
	right_post.position = center + Vector3(2.75, 1.35, 2.0)
	right_post.set_meta("visual_only", true)
	facade.add_child(right_post)
	var fascia := _box_mesh(Vector3(6.0, 0.55, 0.16), Color("d8b36a"))
	fascia.name = "旺铺转让招牌底板"
	fascia.set_meta("visual_only", true)
	fascia.position = center + Vector3(0.0, 2.65, 2.02)
	facade.add_child(fascia)
	var sign := _box_mesh(Vector3(4.2, 0.28, 0.18), Color("f2e5c3"))
	sign.name = "旺铺转让招牌面板"
	sign.set_meta("visual_only", true)
	sign.position = center + Vector3(0.0, 2.65, 1.9)
	facade.add_child(sign)
	var sign_light := OmniLight3D.new()
	sign_light.name = "旺铺转让招牌局部暖光"
	sign_light.light_color = Color("ffd59c")
	sign_light.light_energy = 0.20
	sign_light.omni_range = 3.2
	sign_light.position = center + Vector3(0.0, 2.95, 1.60)
	sign_light.set_meta("visual_only", true)
	facade.add_child(sign_light)
	_add_label_3d("旺铺转让", center + Vector3(0.0, 2.68, 1.78), Color("7a302a"))
	var service_board := _box_mesh(Vector3(1.55, 0.42, 0.10), Color("4e8b87"))
	service_board.name = "三轮车维修点提示牌"
	service_board.set_meta("visual_only", true)
	service_board.position = center + Vector3(0.0, 1.05, 1.86)
	facade.add_child(service_board)
	_add_label_3d("维修点", center + Vector3(0.0, 1.08, 1.78), Color("d9f0d0"))

func _add_background_buildings() -> void:
	var frontage_details := Node3D.new()
	frontage_details.name = "街道立面细节"
	frontage_details.set_meta("visual_candidate", true)
	frontage_details.set_meta("candidate_visual_only", true)
	add_child(frontage_details)
	var storefront_texture := load("res://assets/environment/generated/urban_storefront_v2_generated.png") as Texture2D
	var buildings := [
		[Vector3(-15.0, 3.0, -2.0), Vector3(6.0, 6.0, 4.0), Color("706e6d")],
		[Vector3(15.0, 4.0, -3.0), Vector3(7.0, 8.0, 5.0), Color("827b74")],
		[Vector3(-14.0, 2.4, 12.0), Vector3(8.0, 4.8, 5.0), Color("9a8f80")],
		[Vector3(14.0, 2.8, 13.0), Vector3(8.0, 5.6, 5.0), Color("8e817a")]
	]
	for building in buildings:
		var center: Vector3 = building[0]
		var size: Vector3 = building[1]
		_add_static_box("街区背景建筑", size, center, building[2])
		# 只增加视觉细节，不增加碰撞体，避免改变城市导航、交通和交互边界。
		var road_side := -1.0 if center.x > 0.0 else 1.0
		var facade_x := center.x + road_side * (size.x * 0.5 + 0.035)
		for row in range(2):
			for column in range(3):
				var window := _box_mesh(Vector3(0.08, 0.55, 0.82), Color("b9c8c5" if (row + column) % 2 == 0 else "7f9b9e"))
				window.position = Vector3(facade_x, 1.7 + row * 1.45, center.z - 1.35 + column * 1.35)
				frontage_details.add_child(window)
		var fascia := _box_mesh(Vector3(0.1, 0.18, size.z * 0.82), Color("c98c62" if center.x > 0.0 else "a7b6a1"))
		fascia.position = Vector3(facade_x + road_side * 0.03, 0.75, center.z)
		frontage_details.add_child(fascia)
		_add_front_facing_facade(frontage_details, center, size, center.z < 0.0)
		if storefront_texture != null and center.z < 0.0:
			_add_photo_storefront_facade(frontage_details, center, size, storefront_texture)
	_add_distant_skyline(frontage_details)

func _add_photo_storefront_facade(parent: Node3D, center: Vector3, size: Vector3, texture: Texture2D) -> void:
	# 原创店铺图只作为候选立面材质，不承担碰撞、导航、交互或任务逻辑。
	var facade := MeshInstance3D.new()
	facade.name = "原创写实店铺立面候选"
	facade.set_meta("visual_candidate", true)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size.x * 0.82, minf(size.y * 0.62, 3.35))
	facade.mesh = mesh
	facade.position = Vector3(center.x, maxf(1.45, center.y - size.y * 0.05), center.z + size.z * 0.5 + 0.055)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.82
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	facade.material_override = material
	parent.add_child(facade)

func _add_front_facing_facade(parent: Node3D, center: Vector3, size: Vector3, faces_camera: bool) -> void:
	# 仅增加可见几何，不增加碰撞体；让街道不再被空白方盒和灰色天际线切断。
	var facing := -1.0 if faces_camera else 1.0
	var facade_z := center.z + facing * (size.z * 0.5 + 0.045)
	var columns := maxi(2, int(floor(size.x / 1.2)))
	var rows := maxi(2, int(floor(size.y / 1.35)))
	for row in range(rows):
		for column in range(columns):
			var glass := _box_mesh(Vector3(0.72, 0.58, 0.055), Color("8ea9ad" if (row + column) % 2 == 0 else "5e7e87"))
			glass.position = Vector3(
				center.x - (columns - 1) * 0.6 + column * 1.2,
				1.25 + row * 1.22,
				facade_z
			)
			parent.add_child(glass)
	for column in range(columns):
		var vertical_trim := _box_mesh(Vector3(0.08, size.y * 0.78, 0.07), Color("b78f6b" if faces_camera else "7c8b87"))
		vertical_trim.position = Vector3(center.x - size.x * 0.5 + 0.34 + column * 1.2, size.y * 0.48, facade_z - facing * 0.045)
		parent.add_child(vertical_trim)
	if faces_camera:
		for row in range(mini(3, rows)):
			var balcony := _box_mesh(Vector3(size.x * 0.72, 0.08, 0.55), Color("6a6d69"))
			balcony.position = Vector3(center.x, 1.02 + row * 1.35, facade_z - facing * 0.20)
			parent.add_child(balcony)
			var balcony_rail := _box_mesh(Vector3(size.x * 0.72, 0.48, 0.06), Color("41484b"))
			balcony_rail.position = balcony.position + Vector3(0.0, 0.25, -facing * 0.24)
			parent.add_child(balcony_rail)

func _add_distant_skyline(parent: Node3D) -> void:
	var skyline := [
		[Vector3(-13.5, 5.2, -16.0), Vector3(5.0, 10.4, 2.4), Color("66717a")],
		[Vector3(-7.5, 3.7, -17.0), Vector3(4.0, 7.4, 2.0), Color("8b8379")],
		[Vector3(7.0, 4.8, -17.5), Vector3(5.4, 9.6, 2.6), Color("706c70")],
		[Vector3(14.0, 6.0, -16.5), Vector3(4.8, 12.0, 2.2), Color("5e6871")]
	]
	for item in skyline:
		var center: Vector3 = item[0]
		var size: Vector3 = item[1]
		var block := _box_mesh(size, item[2])
		block.position = center
		parent.add_child(block)
		for row in range(maxi(2, int(size.y / 1.45))):
			var window := _box_mesh(Vector3(size.x * 0.58, 0.22, 0.045), Color("8da2a4" if row % 2 == 0 else "516c77"))
			window.position = center + Vector3(0.0, -size.y * 0.38 + row * 1.25, -size.z * 0.5 - 0.025)
			parent.add_child(window)

func _add_city_horizon_visuals() -> void:
	# 这是普通游玩态的原创城市远景层：补足街区外沿的地面、楼群和窗带，
	# 只拥有渲染节点，不创建碰撞、导航、交互、交通或任务状态。
	# 远景层独立于参考采集的图片卡，避免驾驶镜头在街区边缘露出空白地平线。
	var horizon := Node3D.new()
	horizon.name = "原创城市远景层"
	horizon.set_meta("visual_only", true)
	horizon.set_meta("visual_candidate", true)
	horizon.set_meta("candidate_visual_only", true)
	add_child(horizon)

	var far_ground := _box_mesh(Vector3(72.0, 0.08, 72.0), Color("5c625f"))
	far_ground.name = "城市远景连续地面"
	far_ground.position = Vector3(0.0, -0.16, 0.0)
	horizon.add_child(far_ground)

	var skyline := [
		[Vector3(-23.0, 4.6, -20.0), Vector3(7.0, 9.2, 3.6), Color("59636b")],
		[Vector3(-15.0, 3.5, -24.0), Vector3(5.5, 7.0, 3.0), Color("6b7072")],
		[Vector3(-6.0, 5.4, -25.0), Vector3(6.0, 10.8, 3.4), Color("4f5b65")],
		[Vector3(5.0, 3.8, -24.0), Vector3(7.0, 7.6, 3.6), Color("687078")],
		[Vector3(16.5, 5.1, -22.0), Vector3(8.0, 10.2, 3.8), Color("505b62")],
		[Vector3(24.0, 3.6, -18.0), Vector3(6.0, 7.2, 3.0), Color("73716d")],
		[Vector3(-24.0, 2.6, -8.0), Vector3(4.5, 5.2, 3.0), Color("766f6d")],
		[Vector3(25.0, 2.8, -6.0), Vector3(5.0, 5.6, 3.2), Color("6b6d70")]
	]
	for index in range(skyline.size()):
		var item: Array = skyline[index]
		var center: Vector3 = item[0]
		var size: Vector3 = item[1]
		var building := _box_mesh(size, item[2])
		building.name = "城市远景楼体_%02d" % index
		building.position = center
		horizon.add_child(building)
		var window_rows := maxi(2, int(size.y / 1.45))
		for row in range(window_rows):
			var window := _box_mesh(Vector3(size.x * 0.58, 0.18, 0.045), Color("a6b5b1" if (row + index) % 3 == 0 else "536a73"))
			window.name = "城市远景窗带_%02d_%02d" % [index, row]
			window.position = center + Vector3(0.0, -size.y * 0.38 + row * 1.2, -size.z * 0.5 - 0.03)
			horizon.add_child(window)

	var roof_towers := [
		[Vector3(-23.0, 10.0, -20.0), Vector3(1.0, 1.2, 1.0)],
		[Vector3(-6.0, 11.1, -25.0), Vector3(1.2, 1.0, 1.2)],
		[Vector3(16.5, 10.8, -22.0), Vector3(1.1, 1.4, 1.1)]
	]
	for index in range(roof_towers.size()):
		var item: Array = roof_towers[index]
		var tower := _box_mesh(item[1], Color("3f4b52"))
		tower.name = "城市远景屋顶设备_%02d" % index
		tower.position = item[0]
		horizon.add_child(tower)

func _add_city_storytelling_visuals() -> void:
	# 街区故事层只补足可读的生活痕迹，不创建碰撞、导航、感知、交通或任务状态。
	# 这些节点是原创候选视觉，方便在真实窗口中逐项审阅，也方便后续替换成最终资产。
	var story := Node3D.new()
	story.name = "原创街区故事层"
	story.set_meta("visual_only", true)
	story.set_meta("visual_candidate", true)
	story.set_meta("candidate_visual_only", true)
	add_child(story)

	var awnings := [
		["街区故事-免费鸡蛋遮阳棚", Vector3(-9.0, 2.85, -7.35), Vector3(5.2, 0.10, 0.95), Color("d79a61")],
		["街区故事-街边店遮阳棚", Vector3(10.0, 2.20, 6.95), Vector3(4.1, 0.10, 0.85), Color("b86e6b")],
		["街区故事-仓储点遮阳棚", Vector3(-11.0, 2.35, 11.3), Vector3(3.6, 0.10, 0.75), Color("718895")]
	]
	for item in awnings:
		var awning := _box_mesh(item[2], item[3])
		awning.name = item[0]
		awning.position = item[1]
		awning.rotation_degrees.z = -4.0
		awning.set_meta("visual_only", true)
		story.add_child(awning)

	var crates := [
		["街区故事-货箱-01", Vector3(5.35, 0.34, -6.45), Color("9b6a48")],
		["街区故事-货箱-02", Vector3(5.95, 0.34, -6.35), Color("a9784d")],
		["街区故事-货箱-03", Vector3(5.65, 1.02, -6.40), Color("7e5840")],
		["街区故事-货箱-04", Vector3(11.55, 0.34, 7.15), Color("8f6b4d")]
	]
	for item in crates:
		var crate := _box_mesh(Vector3(0.62, 0.62, 0.62), item[2])
		crate.name = item[0]
		crate.position = item[1]
		crate.set_meta("visual_only", true)
		story.add_child(crate)

	for index in range(4):
		var bollard := _cylinder_mesh(0.09, 0.72, Color("3d4a50"))
		bollard.name = "街区故事-路桩-%02d" % index
		bollard.position = [Vector3(3.65, 0.36, -4.95), Vector3(4.05, 0.36, -4.95), Vector3(7.2, 0.36, 5.25), Vector3(7.65, 0.36, 5.25)][index]
		bollard.set_meta("visual_only", true)
		story.add_child(bollard)

	for index in range(2):
		var utility_box := _box_mesh(Vector3(0.48, 0.85, 0.28), Color("4f5c60"))
		utility_box.name = "街区故事-配电箱-%02d" % index
		utility_box.position = [Vector3(-13.2, 0.43, 1.2), Vector3(13.2, 0.43, 2.0)][index]
		utility_box.set_meta("visual_only", true)
		story.add_child(utility_box)

	for index in range(2):
		var cable := _box_mesh(Vector3(23.0, 0.035, 0.035), Color("202a30"))
		cable.name = "街区故事-横跨线缆-%02d" % index
		cable.position = Vector3(0.0, 4.15 + index * 0.38, -1.8 + index * 3.6)
		cable.rotation_degrees.z = -1.5 if index == 0 else 1.2
		cable.set_meta("visual_only", true)
		story.add_child(cable)

	var signs := [
		["街区故事-仓储指示牌", Vector3(-12.4, 1.65, 10.85), Vector3(0.85, 1.05, 0.08), Color("d6b56d")],
		["街区故事-装卸提示牌", Vector3(12.35, 1.45, 8.10), Vector3(0.72, 0.90, 0.08), Color("7ba4a2")],
		["街区故事-街角编号牌", Vector3(4.75, 1.60, 4.10), Vector3(0.62, 0.72, 0.08), Color("c4c8b7")]
	]
	for item in signs:
		var sign := _box_mesh(item[2], item[3])
		sign.name = item[0]
		sign.position = item[1]
		sign.set_meta("visual_only", true)
		story.add_child(sign)

	_add_city_story_lights(story)

func _add_city_story_lights(parent: Node3D) -> void:
	# 黄昏配送需要一个明确的夜市氛围锚点；灯具只属于视觉层，不创建碰撞、
	# 导航、感知、交通或任务状态。正式资产替换时可沿用同一挂点契约。
	var lanterns := [
		["夜市灯串-仓储入口", Vector3(-4.2, 3.35, -4.45), Color("f6c879"), 0.88],
		["夜市灯串-街角摊位", Vector3(7.9, 3.05, 7.75), Color("f4a969"), 1.05],
		["夜市灯串-登记点", Vector3(7.25, 2.85, 5.15), Color("9ed2d1"), 0.62],
		["夜市灯串-交付点", Vector3(4.4, 2.75, 4.0), Color("f3d47b"), 0.76]
	]
	for item in lanterns:
		var lantern := _box_mesh(Vector3(0.22, 0.34, 0.22), item[2])
		lantern.name = item[0]
		lantern.position = item[1]
		lantern.set_meta("visual_only", true)
		lantern.set_meta("visual_candidate", true)
		lantern.set_meta("candidate_visual_only", true)
		var lantern_material := StandardMaterial3D.new()
		lantern_material.albedo_color = item[2]
		lantern_material.emission_enabled = true
		lantern_material.emission = item[2]
		lantern_material.emission_energy_multiplier = 2.1
		lantern.material_override = lantern_material
		parent.add_child(lantern)

		var light := OmniLight3D.new()
		light.name = item[0] + "-光源"
		light.position = item[1]
		light.light_color = item[2]
		light.light_energy = 0.0
		light.omni_range = 4.2
		light.shadow_enabled = false
		light.set_meta("visual_only", true)
		light.set_meta("visual_candidate", true)
		light.set_meta("candidate_visual_only", true)
		parent.add_child(light)
		city_story_lights.append({"light": light, "lantern": lantern, "base_energy": float(item[3])})

	_sync_city_story_lights()

func _sync_city_story_lights() -> void:
	var profile_energy := 0.0
	match weather_profile:
		"dusk":
			profile_energy = 1.0
		"rain_after":
			profile_energy = 0.72
		_:
			profile_energy = 0.08
	for entry in city_story_lights:
		var light := entry.get("light") as OmniLight3D
		var lantern := entry.get("lantern") as MeshInstance3D
		if light == null or not is_instance_valid(light):
			continue
		var base_energy := float(entry.get("base_energy", 0.0))
		light.light_energy = base_energy * profile_energy
		if lantern != null and is_instance_valid(lantern):
			# 固定参考采集态会在视觉准备阶段关闭开发期灯串；
			# 采集态最后重新绑定黄昏配置时不能把它们恢复成画面中的
			# 白色块状物。普通游玩仍按天气配置显示灯串。
			lantern.visible = profile_energy > 0.0 and not reference_capture_mode

func _update_city_story_lights(delta: float) -> void:
	if city_story_lights.is_empty() or reference_capture_mode:
		return
	city_story_light_elapsed = fmod(city_story_light_elapsed + maxf(delta, 0.0), TAU)
	var profile_energy := 0.0
	match weather_profile:
		"dusk":
			profile_energy = 1.0
		"rain_after":
			profile_energy = 0.72
		_:
			profile_energy = 0.08
	for index in range(city_story_lights.size()):
		var entry: Dictionary = city_story_lights[index]
		var light := entry.get("light") as OmniLight3D
		if light == null or not is_instance_valid(light):
			continue
		var base_energy := float(entry.get("base_energy", 0.0))
		var flicker := 0.96 + sin(city_story_light_elapsed * 2.4 + float(index) * 1.7) * 0.04
		light.light_energy = base_energy * profile_energy * flicker

func _update_hud() -> void:
	var state := "进行中"
	if mission.status == MissionChain.Status.SUCCESS:
		state = "任务完成"
	elif mission.status == MissionChain.Status.FAILED:
		state = "任务失败：" + mission.failure_reason
	var cargo := "无"
	if inventory.has_item("egg_tray"):
		cargo = "鸡蛋×%d" % inventory.count("egg_tray")
	cargo_visual.visible = inventory.has_item("egg_tray")
	_update_cargo_visual_pose()
	var conflict_text := "平静"
	if conflict.status == ConflictState.Status.ENGAGED:
		conflict_text = "冲突"
	elif conflict.status == ConflictState.Status.PURSUED:
		conflict_text = "追踪"
	var prompt := ""
	if conflict.status == ConflictState.Status.PURSUED:
		var escape_distance := player.global_position.distance_to(conflict_agent.global_position) if conflict_agent != null else 0.0
		prompt = "F 反击（对手生命 %d）  Space 闪避  或逃离追踪 %dm" % [roundi(conflict.opponent_health), roundi(maxf(conflict_escape_distance - escape_distance, 0.0))]
	elif conflict.status == ConflictState.Status.ENGAGED:
		prompt = "F 反击（对手生命 %d）  Space 闪避" % roundi(conflict.opponent_health)
	elif conflict.status == ConflictState.Status.CALM and conflict_encounter_armed and conflict_agent != null and player.global_position.distance_to(conflict_agent.global_position) <= conflict_trigger_radius:
		prompt = "F  触发冲突"
	else:
		var service_prompt := _vehicle_service_prompt()
		if not service_prompt.is_empty() and _current_stage_id() != "new_shop":
			prompt = service_prompt
		else:
			for target in targets:
				if target.interaction_id == _current_stage_id() and target.can_interact(player.global_position):
					prompt = "E  " + target.prompt
					break
		if prompt.is_empty() and _side_activity_can_interact():
			var prompt_index := _active_side_activity_index()
			if prompt_index >= 0:
				var prompt_runtime: Dictionary = side_activity_runtimes[prompt_index]
				prompt = "E  " + (str(prompt_runtime.get("label", "街边支线")) if bool(prompt_runtime.get("unlocked", false)) else str(prompt_runtime.get("delivery_label", "完成支线交付")))
	var wanted_level := 0
	if wanted != null:
		wanted_level = int(wanted.level)
	var hud_signature := "%s|%s|%d|%d|%d|%s|%d|%s|%s" % [mission.current_objective(), state, mission.money, mission.stars, wanted_level, cargo, roundi(conflict.health), conflict_text, prompt]
	if hud_signature != last_hud_signature:
		last_hud_signature = hud_signature
		trace.record("hud_state", {"signature": hud_signature})
	var area_status := ""
	if neighborhood_status == "active":
		area_status = "\n区域：后场仓储已开放"
	hud_label.text = "目标：%s\n%s  生命：%d%s" % [mission.current_objective(), state, roundi(conflict.health), area_status]
	mission_title_label.text = "街区任务\n" + mission.current_objective()
	money_label.text = "¥%d" % mission.money
	wanted_label.text = "★".repeat(wanted_level) + "☆".repeat(5 - wanted_level)
	hint_label.text = "WASD / 左摇杆移动   Shift / 左摇杆按压冲刺   鼠标 / 方向键 / 右摇杆镜头   C 蹲伏   E 交互   F 冲突   Space / 手柄 LB 闪避   V 上下车   R 重试   L 读取存档"
	prompt_label.text = prompt
	_update_vehicle_damage_feedback()
	if neighborhood_status == "active":
		hint_label.text += "\n扩展街区：后场仓储已开放"
	var active_side_index := _active_side_activity_index()
	if active_side_index >= 0:
		var active_side: Dictionary = side_activity_runtimes[active_side_index]
		if bool(active_side.get("unlocked", false)):
			hint_label.text += "\n支线：驾驶三轮车靠近%s可接单" % str(active_side.get("label", "摊主"))
		elif bool(active_side.get("accepted", false)):
			hint_label.text += "\n支线：%s后交付" % str(active_side.get("delivery_label", "前往交付点"))
	if message != "":
		hint_label.text += "\n" + message
	if hud_visual != null:
		var current_target_position := player.global_position if player != null else Vector3.ZERO
		var radar_points: Array[Vector2] = []
		var radar_point_colors: Array[Color] = []
		for target in targets:
			if target.interaction_id == _current_stage_id():
				current_target_position = target.global_position
				break
		if player != null:
			radar_points.append(_radar_point_for_world(current_target_position))
			radar_point_colors.append(Color("f3d47b"))
			var side_target := _side_activity_current_target()
			if side_target != null:
				radar_points.append(_radar_point_for_world(side_target.global_position))
				radar_point_colors.append(Color("7db6c8"))
			if vehicle != null:
				radar_points.append(_radar_point_for_world(vehicle.global_position))
				radar_point_colors.append(Color("75b6d0"))
			if conflict_agent != null and conflict_agent.visible:
				radar_points.append(_radar_point_for_world(conflict_agent.global_position))
				radar_point_colors.append(Color("e05252"))
		var objective_distance := player.global_position.distance_to(current_target_position) if player != null else 0.0
		hud_visual.apply_state({
			"mode": "city",
			"objective": mission.current_objective(),
			"state": state,
			"distance": "%dm" % roundi(objective_distance),
			"money": mission.money,
			"wanted_stars": wanted_level,
			"cargo": cargo,
			"conflict": conflict_text,
			"prompt": prompt,
			"vehicle": vehicle_status_label.text if vehicle_status_label != null else "",
			"life_ratio": clampf(conflict.health / 100.0, 0.0, 1.0),
			"stamina_ratio": player.stamina_ratio() if player != null else 1.0,
			"escape_ratio": conflict_escape_progress / conflict_escape_hold_seconds if conflict_escape_hold_seconds > 0.0 else 0.0,
			"radar_heading": player.rotation.y if player != null else 0.0,
			"radar_points": radar_points,
			"radar_point_colors": radar_point_colors
		})
	_sync_city_runtime_visual_state()

func _update_cargo_visual_pose() -> void:
	# city-05 的参考镜头中，主角在离店奔跑时把鸡蛋托盘举到肩膀以上；
	# 领取和登记阶段仍保持身体前方的低位携带。这里只调整表现节点，
	# 不改变库存、任务、碰撞、导航或存档数据。
	if cargo_visual == null:
		return
	var stage_id := _current_stage_id()
	var capture_scenario := str(get_meta("reference_capture_scenario", ""))
	var raised := capture_scenario == "city-05" or stage_id in ["leave_store", "enter_backlot"]
	if raised:
		cargo_visual.position = Vector3(-0.18, 1.46, -0.08)
		cargo_visual.rotation_degrees = Vector3(-12.0, -8.0, -4.0)
		cargo_visual.set_meta("carry_pose", "raised_exit")
	else:
		cargo_visual.position = Vector3(-0.50, 0.64, -0.13)
		cargo_visual.rotation_degrees = Vector3(-8.0, 0.0, -4.0)
		cargo_visual.set_meta("carry_pose", "front_carry")

func _sync_city_runtime_visual_state() -> void:
	# 城市视觉层跟随真实任务、冲突、店内空间、登记和载具状态切换。
	# 这里只更新 candidate_visual_only 节点，不改变任务、碰撞、导航或存档。
	if reference_capture_mode or city_scene_visuals == null or player == null or mission == null:
		return
	var state_id := "city-01"
	var source := "city_storefront_idle"
	var stage_id := _current_stage_id()
	if mission.status == MissionChain.Status.SUCCESS:
		state_id = "city-11"
		source = "mission_completed"
	elif conflict.status == ConflictState.Status.ENGAGED or conflict.status == ConflictState.Status.PURSUED:
		state_id = "city-04"
		source = "street_conflict"
	elif stage_id == "leave_store":
		# 领取货物后即进入离店过渡；即使玩家仍停在店内交互点，镜头也必须
		# 先显示“高位携物—离开店铺—前往登记台”的 city-05，而不是继续停留在
		# city-03 货架通道。这样任务阶段与参考视频中的离店构图保持一一对应。
		state_id = "city-05"
		source = "leave_store_transition"
	elif inside_store_aisle:
		state_id = "city-04" if conflict_encounter_armed else "city-03"
		source = "store_aisle"
	elif stage_id == "register":
		state_id = "city-07" if registered else "city-06"
		source = "registration"
	elif registered and stage_id == "enter_backlot" and neighborhood_status != "active":
		# 扫码成功会推进任务到 enter_backlot，但登记成功反馈仍需保留到玩家
		# 真正进入后场；否则 city-07 只存在于构建函数，游戏态没有成功画面。
		state_id = "city-07"
		source = "registration_success_feedback"
	elif stage_id == "new_shop":
		state_id = "city-10" if vehicle != null and vehicle.driver != null else "city-09"
		source = "delivery_drive"
	elif stage_id in ["enter_backlot", "load_stock"] or neighborhood_status == "active":
		state_id = "city-05"
		source = "backlot_transition"
	elif vehicle != null and vehicle.driver != null:
		state_id = "city-09" if not traffic_vehicles.is_empty() else "city-08"
		source = "vehicle_drive"
	elif crowd_displaced or (wanted != null and wanted.level > 0):
		state_id = "city-02"
		source = "crowd_pressure"
	city_scene_visuals.apply_runtime_state(state_id, source)
	city_scene_visuals.apply_runtime_context({
		"store_transition": inside_store_aisle,
		"neighborhood_active": neighborhood_status == "active",
		"weather_profile": weather_profile,
		"traffic_active": not traffic_vehicles.is_empty() or state_id in ["city-09", "city-10"],
		"traffic_signal_red": city_signal_elapsed >= 7.5,
		"vehicle_integrity": vehicle_integrity,
		"delivery_completed": mission.status == MissionChain.Status.SUCCESS,
		"delivery_reward": mission.money,
		"delivery_stars": mission.stars,
	})
	# 普通候选试玩也必须随着真实任务状态切换分段背景；否则进入商店、
	# 登记点和驾驶段时，远景仍会错误地停留在 city-01。
	if bool(get_meta("candidate_video_backdrop", false)):
		var backdrop_changed := str(get_meta("candidate_video_backdrop_id", "")) != state_id
		set_meta("candidate_video_backdrop_id", state_id)
		if backdrop_changed:
			_apply_candidate_video_backdrop()

func _radar_point_for_world(world_position: Vector3, max_distance := 24.0) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var delta := world_position - player.global_position
	var forward := -player.global_transform.basis.z.normalized()
	var right := player.global_transform.basis.x.normalized()
	return Vector2(
		clampf(delta.dot(right) / max_distance, -1.0, 1.0),
		clampf(-delta.dot(forward) / max_distance, -1.0, 1.0)
	)

func _current_stage_id() -> String:
	return str(mission.current_stage().get("id", ""))

func _on_stage_changed(_previous: int, _current: int) -> void:
	if launch_checkpoint_pending:
		return
	trace.record("mission_stage", {"stage": mission.current_index, "objective": mission.current_objective()})
	audio_events.emit_event("mission_stage", {"stage": mission.current_index})
	if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
		hud_visual.announce("新目标 · " + mission.current_objective(), Color("f0e5c9"), 2.4)
	if hud_visual != null and hud_visual.has_method("trigger_feedback"):
		hud_visual.trigger_feedback(Color("f0c752"), 0.18, 0.30)
	for target in targets:
		target.reset()
	_sync_side_activity_state()
	_save_city_checkpoint()

func _on_mission_completed() -> void:
	message = "任务完成：奖励 ¥%d" % mission.money
	var campaign_state := get_node_or_null("/root/CampaignState")
	if campaign_state != null and campaign_state.has_method("mark_city_completed"):
		var campaign_saved: bool = campaign_state.mark_city_completed({"money": mission.money, "stars": mission.stars})
		trace.record("campaign_city_completed", {"saved": campaign_saved, "reason": campaign_state.last_error})
	if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
		hud_visual.announce("任务完成 · ¥%d" % mission.money, Color("8fe0a2"), 3.0)
	if hud_visual != null and hud_visual.has_method("trigger_feedback"):
		hud_visual.trigger_feedback(Color("8fe0a2"), 0.28, 0.38)
	if camera_rig != null and camera_rig.has_method("pulse_feedback"):
		camera_rig.pulse_feedback(0.14, 0.18, 14.0)
	trace.record("mission_completed", {"money": mission.money, "stars": mission.stars})
	audio_events.emit_event("mission_success", {"money": mission.money, "stars": mission.stars})
	for target in targets:
		target.completed = true
	_save_city_checkpoint()

func _on_mission_failed(reason: String) -> void:
	if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
		hud_visual.announce("任务失败 · " + reason, Color("e46a61"), 3.0)
	if hud_visual != null and hud_visual.has_method("trigger_feedback"):
		hud_visual.trigger_feedback(Color("e05252"), 0.42, 0.55)
	if camera_rig != null and camera_rig.has_method("pulse_feedback"):
		camera_rig.pulse_feedback(0.30, 0.28, 12.0)
	player.trigger_presentation_action("fail")
	failure_overlay.show_failure(reason)
	trace.record("mission_failed", {"reason": reason})
	audio_events.emit_event("mission_failed", {"reason": reason})
	_save_city_checkpoint()

func _on_inventory_changed(item_id: String, amount: int) -> void:
	trace.record("inventory_changed", {"item_id": item_id, "amount": amount})
	audio_events.emit_event("inventory_changed", {"item_id": item_id, "amount": amount})

func _try_city_interaction(target: InteractionTarget, frame: InputFrame) -> bool:
	if not target.can_interact(player.global_position) or not frame.interact:
		return false
	var stage := mission.current_stage()
	var requirement_failure := _stage_requirement_failure(stage)
	if not requirement_failure.is_empty():
		message = requirement_failure
		trace.record("interaction_blocked", {"id": target.interaction_id, "reason": requirement_failure})
		audio_events.emit_event("interaction_denied", {"id": target.interaction_id, "reason": requirement_failure})
		return false
	if not target.try_interact(player, true):
		return false
	_apply_stage_effects(stage.get("effects", {}))
	if str(stage.get("id", "")) == "collect_eggs":
		_arm_conflict_encounter()
	trace.record("interaction", {"id": target.interaction_id})
	player.trigger_presentation_action("interact")
	audio_events.emit_event("interaction_success", {"id": target.interaction_id})
	mission.complete_current()
	_save_city_checkpoint()
	return true

func _vehicle_service_settings() -> Dictionary:
	var runtime = city_pack.get("runtime", {})
	if not runtime is Dictionary:
		return {}
	var settings = runtime.get("vehicle_service", {})
	return settings if settings is Dictionary else {}

func _vehicle_service_target() -> InteractionTarget:
	for target in targets:
		if target.interaction_id == "new_shop":
			return target
	return null

func _vehicle_service_prompt() -> String:
	var settings := _vehicle_service_settings()
	if not bool(settings.get("enabled", false)) or mission.status == MissionChain.Status.FAILED:
		return ""
	if vehicle == null or player == null or vehicle.driver != null or vehicle_integrity >= 100.0:
		return ""
	var target := _vehicle_service_target()
	var interaction_radius := maxf(float(settings.get("interaction_radius", 2.0)), 0.1)
	if target == null or target.global_position.distance_to(player.global_position) > interaction_radius:
		return ""
	return "E  维修三轮车 · ¥%d" % int(settings.get("cost", 0))

func _try_vehicle_service_interaction(frame: InputFrame) -> bool:
	if not frame.interact or _vehicle_service_prompt().is_empty():
		return false
	var settings := _vehicle_service_settings()
	var cost := maxi(int(settings.get("cost", 0)), 0)
	if not mission.spend_money(cost):
		message = "维修需要 ¥%d" % cost
		trace.record("interaction_blocked", {"id": "vehicle_service", "reason": message})
		audio_events.emit_event("interaction_denied", {"id": "vehicle_service", "reason": message})
		return true
	var previous_integrity := vehicle_integrity
	vehicle_integrity = clampf(float(settings.get("repair_amount", 100.0)), 0.0, 100.0)
	vehicle_collision_cooldown = 0.0
	_update_vehicle_damage_feedback()
	message = str(settings.get("message", "三轮车已修复"))
	trace.record("vehicle_repaired", {"cost": cost, "previous_integrity": previous_integrity, "integrity": vehicle_integrity})
	audio_events.emit_event("interaction_success", {"id": "vehicle_repair", "cost": cost})
	if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
		hud_visual.announce(message + " · -¥%d" % cost, Color("8fe0a2"), 2.4)
	if hud_visual != null and hud_visual.has_method("trigger_feedback"):
		hud_visual.trigger_feedback(Color("8fe0a2"), 0.18, 0.28)
	_save_city_checkpoint()
	return true

func _try_side_activity_interaction(frame: InputFrame) -> bool:
	if not frame.interact or not _side_activity_can_interact():
		return false
	var runtime_index := _active_side_activity_index()
	if runtime_index < 0:
		return false
	var runtime: Dictionary = side_activity_runtimes[runtime_index]
	var activity_id := str(runtime.get("id", "side_activity"))
	var cargo_item := str(runtime.get("cargo_item", "vendor_parcel"))
	var delivery_label := str(runtime.get("delivery_label", "完成支线交付"))
	var reward := int(runtime.get("reward", 0))
	if vehicle == null or vehicle.driver != player:
		var failure := "需要驾驶三轮车送货"
		message = failure
		trace.record("side_activity_blocked", {"id": activity_id, "reason": failure})
		audio_events.emit_event("interaction_denied", {"id": activity_id, "reason": failure})
		return true
	if bool(runtime.get("unlocked", false)):
		runtime["accepted"] = true
		runtime["unlocked"] = false
		side_activity_runtimes[runtime_index] = runtime
		inventory.add_item(cargo_item, 1)
		message = "已接单：" + delivery_label
		trace.record("side_activity_accepted", {"id": activity_id, "cargo": cargo_item})
		audio_events.emit_event("interaction_success", {"id": activity_id, "phase": "accepted"})
		if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
			hud_visual.announce("支线接单 · " + delivery_label, Color("7db6c8"), 2.8)
		if hud_visual != null and not reference_capture_mode and hud_visual.has_method("trigger_feedback"):
			hud_visual.trigger_feedback(Color("7db6c8"), 0.18, 0.30)
		_sync_side_activity_state()
		_save_city_checkpoint()
		return true
	var delivery_target := runtime.get("delivery_target") as InteractionTarget
	if not bool(runtime.get("accepted", false)) or delivery_target == null:
		return true
	runtime["accepted"] = false
	runtime["completed"] = true
	runtime["unlocked"] = false
	side_activity_runtimes[runtime_index] = runtime
	inventory.remove_item(cargo_item, 1)
	mission.money += reward
	message = "支线完成：货物已交付，奖励 ¥%d" % reward
	trace.record("side_activity_completed", {"id": activity_id, "reward": reward, "delivery": delivery_label})
	audio_events.emit_event("interaction_success", {"id": activity_id, "reward": reward, "phase": "delivered"})
	if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
		hud_visual.announce("支线完成 · +¥%d" % reward, Color("f0c752"), 2.8)
	if hud_visual != null and hud_visual.has_method("trigger_feedback"):
		hud_visual.trigger_feedback(Color("f0c752"), 0.20, 0.32)
	_sync_side_activity_state()
	_save_city_checkpoint()
	return true

func _side_activity_target_cleanup() -> void:
	for runtime_index in range(side_activity_runtimes.size()):
		var runtime: Dictionary = side_activity_runtimes[runtime_index]
		runtime["unlocked"] = false
		runtime["accepted"] = false
		runtime["completed"] = true
		side_activity_runtimes[runtime_index] = runtime
	_sync_side_activity_state()

func _stage_requirement_failure(stage: Dictionary) -> String:
	var requirements = stage.get("requirements", [])
	if not requirements is Array:
		return "任务条件无效"
	for requirement in requirements:
		if not requirement is Dictionary:
			continue
		var requirement_type := str(requirement.get("type", "item"))
		if requirement_type == "item":
			var item_id := str(requirement.get("item_id", ""))
			var amount := int(requirement.get("amount", 1))
			if not inventory.has_item(item_id, amount):
				return str(requirement.get("failure_message", "缺少任务所需物品"))
		elif requirement_type == "flag":
			var flag := str(requirement.get("flag", ""))
			var flag_satisfied := (flag == "registered" and registered) or (flag == "neighborhood_active" and neighborhood_status == "active")
			if not flag_satisfied:
				return str(requirement.get("failure_message", "任务条件未满足"))
	return ""

func _apply_stage_effects(effects) -> void:
	if not effects is Dictionary:
		message = "目标完成"
		return
	for item_rule in effects.get("add_items", []):
		if item_rule is Dictionary:
			inventory.add_item(str(item_rule.get("item_id", "")), int(item_rule.get("amount", 1)))
	for item_rule in effects.get("remove_items", []):
		if item_rule is Dictionary:
			inventory.remove_item(str(item_rule.get("item_id", "")), int(item_rule.get("amount", 1)))
	if effects.has("set_registered"):
		registered = bool(effects.get("set_registered", false))
	if effects.has("set_neighborhood_active"):
		neighborhood_status = "active" if bool(effects.get("set_neighborhood_active", false)) else "inactive"
	message = str(effects.get("message", "目标完成"))
	for event in effects.get("trace_events", []):
		if event is Dictionary:
			var trace_payload = event.get("payload", {})
			if not trace_payload is Dictionary:
				trace_payload = {}
			trace.record(str(event.get("id", "")), trace_payload)
	for event in effects.get("audio_events", []):
		if event is Dictionary:
			var audio_payload = event.get("payload", {})
			if not audio_payload is Dictionary:
				audio_payload = {}
			audio_events.emit_event(str(event.get("id", "")), audio_payload)

func _arm_conflict_encounter() -> void:
	if conflict_agent == null or targets.size() < 2:
		return
	conflict_encounter_armed = true
	conflict_agent.visible = true
	conflict_agent.global_position = targets[1].global_position + Vector3(2.1, 0.0, 0.0)
	conflict.reset()
	_update_conflict_presentation()
	message = "出口附近有人拦路，靠近后按 F 应对"
	trace.record("conflict_encounter_armed", {"position": [conflict_agent.global_position.x, conflict_agent.global_position.y, conflict_agent.global_position.z]})

func _save_city_checkpoint() -> void:
	if player != null:
		var vehicle_snapshot := vehicle.snapshot()
		vehicle_snapshot["integrity"] = vehicle_integrity
		var world_state := _snapshot_city_world_state()
		if not save_store.save_city_checkpoint(mission, inventory, player.position, registered, conflict.snapshot(), camera_rig.snapshot(), vehicle_snapshot, city_pack_id, world_state):
			message = "存档失败：" + save_store.last_error
			trace.record("save_failed", {"operation": "save", "reason": save_store.last_error})
			audio_events.emit_event("save_failed", {"reason": save_store.last_error})
		trace.save("user://city_last_trace.json")

func _load_city_checkpoint() -> void:
	var data := save_store.load_city_checkpoint(mission, inventory, city_pack_id)
	if data.is_empty():
		message = "读取失败：" + save_store.last_error
		trace.record("checkpoint_load_failed", {"reason": save_store.last_error})
		audio_events.emit_event("checkpoint_load_failed", {"reason": save_store.last_error})
		return
	player.position = data["player_position"]
	registered = data["registered"]
	conflict.restore(data.get("conflict", {}))
	if conflict_agent != null:
		conflict_agent.visible = not conflict.opponent_defeated
	var camera_data = data.get("camera", {})
	if camera_data is Dictionary and camera_data.has("yaw") and camera_data.has("pitch"):
		camera_rig.set_orbit(float(camera_data["yaw"]), float(camera_data["pitch"]))
	vehicle.exit()
	var vehicle_data = data.get("vehicle", {})
	vehicle_integrity = 100.0
	if vehicle_data is Dictionary and not vehicle_data.is_empty():
		var stored_integrity = vehicle_data.get("integrity", 100.0)
		if typeof(stored_integrity) == TYPE_INT or typeof(stored_integrity) == TYPE_FLOAT:
			vehicle_integrity = clampf(float(stored_integrity), 0.0, 100.0)
		vehicle.restore_snapshot(vehicle_data)
		if bool(vehicle_data.get("has_driver", false)):
			player.global_position = vehicle.global_position + Vector3.UP
			if vehicle.enter(player) and player.has_method("sync_presentation_state"):
				if player.has_method("trigger_presentation_action"):
					player.trigger_presentation_action("vehicle")
				player.sync_presentation_state()
	var world_state = data.get("world_state", {})
	weather_profile = "day"
	neighborhood_status = "inactive"
	if world_state is Dictionary:
		side_activity_completed = bool(world_state.get("side_activity_completed", false))
		side_activity_accepted = bool(world_state.get("side_activity_accepted", false))
		var stored_side_activities = world_state.get("side_activities", [])
		if stored_side_activities is Array:
			for stored_activity in stored_side_activities:
				if not stored_activity is Dictionary:
					continue
				for runtime_index in range(side_activity_runtimes.size()):
					var runtime: Dictionary = side_activity_runtimes[runtime_index]
					if str(runtime.get("id", "")) != str(stored_activity.get("id", "")):
						continue
					runtime["accepted"] = bool(stored_activity.get("accepted", false))
					runtime["completed"] = bool(stored_activity.get("completed", false))
					side_activity_runtimes[runtime_index] = runtime
		conflict_encounter_armed = bool(world_state.get("conflict_encounter_armed", false))
		var stored_profile := str(world_state.get("weather_profile", "day"))
		if ["day", "dusk", "rain_after"].has(stored_profile):
			apply_visual_profile(stored_profile)
		var stored_neighborhood_status := str(world_state.get("neighborhood_status", "inactive"))
		if ["inactive", "active"].has(stored_neighborhood_status):
			neighborhood_status = stored_neighborhood_status
	_restore_city_world_state(world_state)
	_sync_side_activity_state()
	# 兼容早期没有记录冲突遭遇字段的城市存档：只在仍处于离店阶段且没有
	# 正在进行的冲突时重新布置遭遇，不覆盖已经完成或正在追踪的状态。
	if world_state is Dictionary and not world_state.has("conflict_encounter_armed") and _current_stage_id() == "leave_store" and conflict.status == ConflictState.Status.CALM:
		_arm_conflict_encounter()
	_update_vehicle_damage_feedback()
	player.clear_failure_presentation()
	failure_overlay.hide_failure()
	if vehicle != null and vehicle.driver == player and player.has_method("trigger_presentation_action") and player.has_method("sync_presentation_state"):
		player.trigger_presentation_action("vehicle")
		player.sync_presentation_state()
	for target in targets:
		target.completed = target.interaction_id != _current_stage_id()
	message = "城市存档已读取"
	trace.record("checkpoint_loaded", {"stage": mission.current_index})
	audio_events.emit_event("checkpoint_loaded", {"stage": mission.current_index})

func _snapshot_city_world_state() -> Dictionary:
	var pedestrian_states: Array[Dictionary] = []
	for pedestrian in pedestrians:
		if is_instance_valid(pedestrian):
			pedestrian_states.append(pedestrian.snapshot_state())
	var blocker_states: Array[Dictionary] = []
	for blocker in crowd_blockers:
		if is_instance_valid(blocker):
			blocker_states.append({
				"position": {"x": blocker.position.x, "y": blocker.position.y, "z": blocker.position.z},
				"collision_disabled": blocker.get_node("人群碰撞体").disabled
			})
	var side_activity_states: Array[Dictionary] = []
	for runtime in side_activity_runtimes:
		side_activity_states.append({
			"id": str(runtime.get("id", "")),
			"accepted": bool(runtime.get("accepted", false)),
			"completed": bool(runtime.get("completed", false))
		})
	return {
		"weather_profile": weather_profile,
		"neighborhood_status": neighborhood_status,
		"side_activity_completed": side_activity_completed,
		"side_activity_accepted": side_activity_accepted,
		"side_activities": side_activity_states,
		"wanted": wanted.snapshot() if wanted != null else {},
		"conflict_encounter_armed": conflict_encounter_armed,
		"conflict_agent_position": {
			"x": conflict_agent.global_position.x,
			"y": conflict_agent.global_position.y,
			"z": conflict_agent.global_position.z
		} if conflict_agent != null else {},
		"crowd_displaced": crowd_displaced,
		"pedestrians": pedestrian_states,
		"crowd_blockers": blocker_states
	}

func _restore_city_world_state(world_state) -> void:
	if not world_state is Dictionary:
		return
	if wanted != null:
		wanted.restore(world_state.get("wanted", {}))
	side_activity_completed = bool(world_state.get("side_activity_completed", side_activity_completed))
	side_activity_accepted = bool(world_state.get("side_activity_accepted", side_activity_accepted))
	var stored_side_activities = world_state.get("side_activities", [])
	if stored_side_activities is Array:
		for stored_activity in stored_side_activities:
			if not stored_activity is Dictionary:
				continue
			for runtime_index in range(side_activity_runtimes.size()):
				var runtime: Dictionary = side_activity_runtimes[runtime_index]
				if str(runtime.get("id", "")) != str(stored_activity.get("id", "")):
					continue
				runtime["accepted"] = bool(stored_activity.get("accepted", false))
				runtime["completed"] = bool(stored_activity.get("completed", false))
				side_activity_runtimes[runtime_index] = runtime
	conflict_encounter_armed = bool(world_state.get("conflict_encounter_armed", conflict_encounter_armed))
	var stored_conflict_position = world_state.get("conflict_agent_position", {})
	if conflict_agent != null and stored_conflict_position is Dictionary and stored_conflict_position.has("x"):
		conflict_agent.global_position = Vector3(
			float(stored_conflict_position.get("x", conflict_agent.global_position.x)),
			float(stored_conflict_position.get("y", conflict_agent.global_position.y)),
			float(stored_conflict_position.get("z", conflict_agent.global_position.z))
		)
	if not world_state.has("crowd_displaced"):
		return
	for pedestrian in pedestrians:
		if is_instance_valid(pedestrian):
			pedestrian.reset_displacement()
	for index in range(crowd_blockers.size()):
		var blocker: StaticBody3D = crowd_blockers[index]
		blocker.position = crowd_home_positions[index]
		var collision: CollisionShape3D = blocker.get_node("人群碰撞体")
		collision.disabled = false
		AssetRuntimeCatalogClass.drive_animation_state(blocker, "idle_default")
	var pedestrian_states = world_state.get("pedestrians", [])
	if pedestrian_states is Array:
		for index in range(mini(pedestrians.size(), pedestrian_states.size())):
			if pedestrian_states[index] is Dictionary:
				pedestrians[index].restore_state(pedestrian_states[index])
	var blocker_states = world_state.get("crowd_blockers", [])
	if blocker_states is Array:
		for index in range(mini(crowd_blockers.size(), blocker_states.size())):
			if not blocker_states[index] is Dictionary:
				continue
			var blocker_data: Dictionary = blocker_states[index]
			var position_data = blocker_data.get("position", {})
			if position_data is Dictionary:
				crowd_blockers[index].position = Vector3(
					float(position_data.get("x", crowd_blockers[index].position.x)),
					float(position_data.get("y", crowd_blockers[index].position.y)),
					float(position_data.get("z", crowd_blockers[index].position.z))
				)
			crowd_blockers[index].get_node("人群碰撞体").disabled = bool(blocker_data.get("collision_disabled", false))
			if crowd_blockers[index].get_node("人群碰撞体").disabled:
				AssetRuntimeCatalogClass.drive_animation_state(crowd_blockers[index], "displaced_default")
	crowd_displaced = bool(world_state.get("crowd_displaced", false))

func _on_conflict_status_changed(_previous_status: int, current_status: int) -> void:
	trace.record("conflict_status", {"status": current_status})
	conflict_escape_progress = 0.0
	conflict_escape_bonus_awarded = false
	if current_status == ConflictState.Status.ENGAGED or current_status == ConflictState.Status.PURSUED:
		_displace_crowd()
		player.trigger_presentation_action("hit")
		if current_status == ConflictState.Status.ENGAGED and hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
			hud_visual.announce("冲突升级 · 逃离红色追踪范围", Color("e05252"), 2.4)
		if hud_visual != null and hud_visual.has_method("trigger_feedback"):
			hud_visual.trigger_feedback(Color("e05252"), 0.34, 0.26)
	_update_conflict_presentation()
	audio_events.emit_event("conflict_status", {"status": current_status})

func _update_conflict_escape(delta: float) -> void:
	if conflict == null or conflict_agent == null or conflict.status != ConflictState.Status.PURSUED:
		conflict_escape_progress = 0.0
		return
	var distance := player.global_position.distance_to(conflict_agent.global_position)
	if distance >= conflict_escape_distance:
		conflict_escape_progress = minf(conflict_escape_progress + maxf(delta, 0.0), conflict_escape_hold_seconds)
	else:
		conflict_escape_progress = maxf(conflict_escape_progress - maxf(delta, 0.0) * 0.8, 0.0)
	if conflict_escape_progress < conflict_escape_hold_seconds or conflict_escape_bonus_awarded:
		return
	conflict_escape_bonus_awarded = true
	conflict.reset()
	conflict_escape_progress = 0.0
	if conflict_escape_bonus > 0:
		mission.money += conflict_escape_bonus
	message = "成功甩开追踪，奖励 ¥%d" % conflict_escape_bonus
	trace.record("conflict_escaped", {"distance": distance, "bonus": conflict_escape_bonus})
	audio_events.emit_event("interaction_success", {"id": "conflict_escape", "bonus": conflict_escape_bonus})
	if hud_visual != null and not reference_capture_mode and hud_visual.has_method("announce"):
		hud_visual.announce("成功甩开追踪 · +¥%d" % conflict_escape_bonus, Color("8fe0a2"), 2.8)
	_update_conflict_presentation()

func _on_wanted_level_changed(previous_level: int, current_level: int, source: String) -> void:
	trace.record("wanted_level", {"previous": previous_level, "current": current_level, "source": source})
	var increased := current_level > previous_level
	var decreased := current_level < previous_level
	var feedback_color := Color("e05252") if increased else Color("8fe0a2")
	var feedback_strength := 0.34 if increased else 0.18
	var feedback_duration := 0.26 if increased else 0.2
	if hud_visual != null:
		if hud_visual.has_method("trigger_feedback"):
			hud_visual.trigger_feedback(feedback_color, feedback_strength, feedback_duration)
		if not reference_capture_mode and hud_visual.has_method("announce"):
			if increased:
				var prefix := "冲突升级 · " if source == "街区冲突" else ""
				hud_visual.announce("%s通缉升级 · %d 星 · %s" % [prefix, current_level, source], feedback_color, 2.2)
			elif decreased:
				hud_visual.announce("通缉降级 · %d 星 · 保持低调" % current_level, feedback_color, 1.8)
	if camera_rig != null and camera_rig.has_method("pulse_feedback") and increased:
		camera_rig.pulse_feedback(clampf(0.12 + current_level * 0.035, 0.12, 0.3), 0.14, 16.0)
	if audio_events != null and (increased or decreased):
		audio_events.emit_event("wanted_level", {"previous": previous_level, "current": current_level, "source": source})

func _update_conflict_presentation() -> void:
	if conflict_agent == null:
		return
	var state_name := "idle_default"
	match conflict.status:
		ConflictState.Status.ENGAGED:
			state_name = "hit_default"
		ConflictState.Status.PURSUED:
			state_name = "walk_default"
		ConflictState.Status.FAILED:
			state_name = "hit_default"
	AssetRuntimeCatalogClass.drive_animation_state(conflict_agent, state_name)

func _on_vehicle_driver_changed(has_driver: bool) -> void:
	trace.record("vehicle_driver", {"has_driver": has_driver})
	audio_events.emit_event("vehicle_driver", {"has_driver": has_driver})
	if camera_rig == null:
		return
	if has_driver:
		vehicle_camera_previous_yaw = camera_rig.yaw_degrees
		vehicle_camera_previous_pitch = camera_rig.pitch_degrees
		vehicle_camera_state_saved = true
		camera_rig.set_follow_profile(vehicle_camera_distance, vehicle_camera_height)
		# GTA 类型载具镜头默认锁在车辆正后方的低位跟随角度；玩家仍可在进入后用视角输入调整。
		camera_rig.set_orbit(vehicle_camera_yaw_degrees, vehicle_camera_pitch_degrees)
	else:
		if vehicle_camera_state_saved:
			camera_rig.set_orbit(vehicle_camera_previous_yaw, vehicle_camera_previous_pitch)
			vehicle_camera_state_saved = false
		_update_navigation_zone()

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

func _box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	return mesh_instance

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

func _cylinder_mesh(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	return mesh_instance

func _character_visual(jacket_color: Color, pants_color: Color, backpack_color: Color, with_backpack: bool = true) -> Node3D:
	var visual := Node3D.new()
	visual.name = "原创灰盒角色外观"
	var torso := _box_mesh(Vector3(0.68, 0.82, 0.42), jacket_color)
	torso.position = Vector3(0.0, 0.0, 0.0)
	visual.add_child(torso)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		arm.name = "手臂-左" if side < 0.0 else "手臂-右"
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
		var hand := MeshInstance3D.new()
		hand.name = "手部-左" if side < 0.0 else "手部-右"
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
	visual.add_child(head)
	var hair := MeshInstance3D.new()
	hair.name = "发型"
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
	for side in [-1.0, 1.0]:
		var leg := _box_mesh(Vector3(0.22, 0.72, 0.24), pants_color)
		leg.position = Vector3(side * 0.18, -0.68, 0.0)
		visual.add_child(leg)
	if with_backpack:
		var backpack := _box_mesh(Vector3(0.52, 0.65, 0.18), backpack_color)
		backpack.position = Vector3(0.0, 0.06, 0.28)
		visual.add_child(backpack)
	return visual

func _add_vehicle_wheels(target: Node3D) -> void:
	vehicle_wheels.clear()
	var wheel_index := 0
	for wheel_location in [Vector3(-0.92, -0.48, 0.72), Vector3(0.92, -0.48, 0.72), Vector3(0.0, -0.48, -0.92)]:
		var wheel := MeshInstance3D.new()
		wheel.name = "三轮车滚动车轮-%d" % wheel_index
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.32
		wheel_mesh.bottom_radius = 0.32
		wheel_mesh.height = 0.16
		wheel.mesh = wheel_mesh
		wheel.position = wheel_location
		wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("1d2228")
		wheel.material_override = material
		target.add_child(wheel)
		vehicle_wheels.append(wheel)
		wheel_index += 1

func _bind_vehicle_wheels_from_visual(root: Variant) -> void:
	vehicle_wheels.clear()
	if not root is Node:
		push_error("三轮车候选视觉根节点不是 Node，无法绑定滚动车轮")
		return
	for wheel_name in ["候选三轮车左后轮胎", "候选三轮车右后轮胎", "候选三轮车前轮胎"]:
		var wheel := (root as Node).find_child(wheel_name, true, false) as MeshInstance3D
		if wheel != null:
			vehicle_wheels.append(wheel)
	if vehicle_wheels.size() != 3:
		push_error("三轮车候选视觉缺少完整车轮绑定，实际数量：" + str(vehicle_wheels.size()))

func _update_vehicle_wheel_visuals(delta: float) -> void:
	if vehicle != null and not vehicle_wheels.is_empty():
		var wheel_radius := 0.32
		var rotation_delta := -vehicle.current_speed * delta / wheel_radius
		var front_steering := clampf(vehicle.steering_input, -1.0, 1.0) * 0.34
		for wheel_index in range(vehicle_wheels.size()):
			var wheel := vehicle_wheels[wheel_index]
			if is_instance_valid(wheel):
				# 直接累加欧拉角，兼容 GLB 导入节点的初始四元数和局部轴向。
				# 使用 rotate_x 时，部分导入器生成的网格节点读回 rotation.x 仍为 0，
				# 导致候选车轮实际没有留下可验证的滚动状态。
				wheel.rotation.x += rotation_delta
				# 列表最后一只轮胎是前轮；转角只作用于视觉节点，车辆根节点的
				# 真实朝向、碰撞和导航仍由 ReferenceVehicle 负责。
				if wheel_index == vehicle_wheels.size() - 1:
					wheel.rotation.y = front_steering
	_update_vehicle_damage_motion(delta)

func _update_vehicle_damage_motion(delta: float) -> void:
	if vehicle == null or vehicle_damage_smoke.is_empty():
		return
	if vehicle_visual_handles_damage_feedback:
		return
	vehicle_damage_phase += delta
	var damaged := vehicle_integrity < 100.0
	if vehicle_damage_warning_visual != null and damaged:
		var warning_visible := fmod(vehicle_damage_phase * (3.0 if vehicle_integrity < 35.0 else 1.8), 1.0) < 0.52
		vehicle_damage_warning_visual.visible = warning_visible
	for smoke_index in range(vehicle_damage_smoke.size()):
		var smoke := vehicle_damage_smoke[smoke_index]
		if not is_instance_valid(smoke):
			continue
		if not damaged:
			smoke.visible = false
			continue
		var drift := sin(vehicle_damage_phase * 1.7 + smoke_index * 1.4) * 0.045
		smoke.position.y = 1.48 + smoke_index * 0.07 + fmod(vehicle_damage_phase * 0.08 + smoke_index * 0.04, 0.12)
		smoke.position.x = -0.22 + smoke_index * 0.20 + drift
		smoke.scale = Vector3.ONE * (1.0 + 0.12 * sin(vehicle_damage_phase * 2.0 + smoke_index))

func _add_label_3d(text: String, location: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.name = "标识-" + text
	label.text = text
	label.position = location
	label.modulate = color
	label.font_size = 32
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _add_scan_board(location: Vector3) -> void:
	var board := Node3D.new()
	board.name = "扫码登记牌"
	board.position = location
	board.set_meta("visual_only", true)
	add_child(board)
	var board_panel := _box_mesh(Vector3(1.4, 1.8, 0.12), Color("354651"))
	board_panel.name = "扫码登记牌深色面板"
	board_panel.set_meta("visual_only", true)
	board.add_child(board_panel)
	var board_header := _box_mesh(Vector3(1.22, 0.20, 0.045), Color("263d4d"))
	board_header.name = "扫码登记牌深色标题带"
	board_header.position = Vector3(0.0, 0.70, -0.085)
	board_header.set_meta("visual_only", true)
	board.add_child(board_header)
	for frame_position in [Vector3(-0.53, 0.25, -0.10), Vector3(0.53, 0.25, -0.10), Vector3(0.0, 0.78, -0.10), Vector3(0.0, -0.28, -0.10)]:
		var qr_frame := _box_mesh(Vector3(0.055, 1.10, 0.035) if absf(frame_position.x) > 0.4 else Vector3(1.12, 0.055, 0.035), Color("34434b"))
		qr_frame.name = "扫码登记牌二维码边框"
		qr_frame.position = frame_position
		qr_frame.set_meta("visual_only", true)
		board.add_child(qr_frame)
	var code_back := _box_mesh(Vector3(0.72, 0.72, 0.03), Color("d8e7d1"))
	code_back.name = "扫码登记牌二维码底"
	code_back.position = Vector3(0.0, 0.25, -0.08)
	code_back.set_meta("visual_only", true)
	board.add_child(code_back)
	var qr_pattern := [
		"111000111", "101010101", "111001111", "000110000", "101011101",
		"011100110", "111001011", "101010101", "111000111"
	]
	for row in range(qr_pattern.size()):
		for column in range(qr_pattern[row].length()):
			if qr_pattern[row][column] != "1":
				continue
			var module := _box_mesh(Vector3(0.075, 0.075, 0.035), Color("20232a"))
			module.name = "扫码登记牌二维码模块"
			module.position = Vector3(-0.3 + column * 0.075, 0.25 + 0.3 - row * 0.075, -0.105)
			module.set_meta("visual_only", true)
			board.add_child(module)
	var status_light := _box_mesh(Vector3(0.12, 0.07, 0.025), Color("8ed3b0"))
	status_light.name = "扫码登记牌状态灯"
	status_light.position = Vector3(0.0, -0.48, -0.10)
	status_light.set_meta("visual_only", true)
	board.add_child(status_light)
	var board_leg_left := _box_mesh(Vector3(0.08, 0.72, 0.08), Color("27343b"))
	board_leg_left.name = "扫码登记牌左支腿"
	board_leg_left.position = Vector3(-0.40, -1.22, 0.0)
	board_leg_left.set_meta("visual_only", true)
	board.add_child(board_leg_left)
	var board_leg_right := _box_mesh(Vector3(0.08, 0.72, 0.08), Color("27343b"))
	board_leg_right.name = "扫码登记牌右支腿"
	board_leg_right.position = Vector3(0.40, -1.22, 0.0)
	board_leg_right.set_meta("visual_only", true)
	board.add_child(board_leg_right)
	_add_label_3d("扫码", location + Vector3(0.0, -0.88, -0.12), Color("f5f0dc"))
	var clerk := Node3D.new()
	clerk.name = "登记员"
	clerk.position = location + Vector3(1.5, 0.0, -0.2)
	clerk.set_meta("visual_only", true)
	add_child(clerk)
	var clerk_visual := _character_visual(Color("c83f46"), Color("283342"), Color("4f6e84"))
	clerk_visual.name = "登记员原创外观"
	clerk.add_child(clerk_visual)
	var clerk_badge := _box_mesh(Vector3(0.14, 0.16, 0.035), Color("e4c16d"))
	clerk_badge.name = "登记员胸牌"
	clerk_badge.position = Vector3(0.0, 0.05, -0.235)
	clerk_badge.set_meta("visual_only", true)
	clerk_visual.add_child(clerk_badge)
	var clerk_phone := _box_mesh(Vector3(0.12, 0.22, 0.035), Color("1e2730"))
	clerk_phone.name = "登记员手持设备"
	clerk_phone.position = Vector3(-0.82, -0.06, -0.10)
	clerk_phone.rotation_degrees = Vector3(-12.0, 0.0, -8.0)
	clerk_phone.set_meta("visual_only", true)
	clerk_visual.add_child(clerk_phone)
	var scan_light := OmniLight3D.new()
	scan_light.name = "扫码登记局部暖光"
	scan_light.light_color = Color("ffd59c")
	scan_light.light_energy = 0.24
	scan_light.omni_range = 2.4
	scan_light.position = location + Vector3(0.0, 0.55, -0.28)
	scan_light.set_meta("visual_only", true)
	add_child(scan_light)
	_add_label_3d("登记员", clerk.position + Vector3(0.0, 1.55, 0.0), Color("fff4d8"))

func _add_crowd_blocker(location: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "入口人群"
	body.position = location
	add_child(body)
	var crowd_visual := _character_visual(color, Color("313844"), Color("252b36"), false)
	crowd_visual.name = "原创灰盒入口人群外观"
	AssetRuntimeCatalogClass.mount_optional_visual(body, asset_catalog, "city-crowd-set", crowd_visual)
	var collision := CollisionShape3D.new()
	collision.name = "人群碰撞体"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collision.shape = capsule
	body.add_child(collision)
	crowd_blockers.append(body)
	crowd_home_positions.append(location)

func _displace_crowd() -> void:
	if crowd_displaced:
		return
	crowd_displaced = true
	for pedestrian in pedestrians:
		if is_instance_valid(pedestrian):
			pedestrian.displace_from(player.global_position)
	for index in range(crowd_blockers.size()):
		var body: StaticBody3D = crowd_blockers[index]
		var direction := body.global_position - player.global_position
		direction.y = 0.0
		if direction.length_squared() < 0.01:
			direction = Vector3(0.0, 0.0, 1.0)
		body.global_position += direction.normalized() * 0.72
		var collision: CollisionShape3D = body.get_node("人群碰撞体")
		collision.disabled = true
		AssetRuntimeCatalogClass.drive_animation_state(body, "displaced_default")
	var displaced_pedestrian_count := pedestrians.filter(func(pedestrian): return is_instance_valid(pedestrian) and pedestrian.displaced).size()
	trace.record("crowd_displaced", {"count": crowd_blockers.size(), "pedestrian_count": displaced_pedestrian_count})
	audio_events.emit_event("crowd_displaced", {"count": crowd_blockers.size(), "pedestrian_count": displaced_pedestrian_count})

func _reset_crowd() -> void:
	if not crowd_displaced:
		return
	for index in range(crowd_blockers.size()):
		var body: StaticBody3D = crowd_blockers[index]
		body.position = crowd_home_positions[index]
		var collision: CollisionShape3D = body.get_node("人群碰撞体")
		collision.disabled = false
		AssetRuntimeCatalogClass.drive_animation_state(body, "idle_default")
	for pedestrian in pedestrians:
		if is_instance_valid(pedestrian):
			pedestrian.reset_displacement()
	crowd_displaced = false
	trace.record("crowd_reset", {"count": crowd_blockers.size()})

func _add_store_shelves(center: Vector3) -> void:
	for side in [-1.0, 1.0]:
		var shelf := StaticBody3D.new()
		shelf.name = "商店货架_左" if side < 0.0 else "商店货架_右"
		shelf.position = center + Vector3(side * 1.6, 1.1, 0.0)
		add_child(shelf)
		shelf.add_child(_box_mesh(Vector3(0.55, 2.2, 4.0), Color("8f745d")))
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.55, 2.2, 4.0)
		collision.shape = box
		shelf.add_child(collision)
		for row in range(3):
			var shelf_board := _box_mesh(Vector3(0.72, 0.08, 3.75), Color("b48d68"))
			shelf_board.position = Vector3(-side * 0.08, -0.72 + row * 0.62, 0.0)
			shelf.add_child(shelf_board)
		for row in range(3):
			for column in range(3):
				var product := _box_mesh(Vector3(0.3, 0.24, 0.38), Color("d6a84f" if (row + column) % 2 == 0 else "6fa6a0"))
				product.position = Vector3(-side * 0.38, -0.55 + row * 0.62, -1.2 + column * 1.05)
				shelf.add_child(product)
	_add_label_3d("货架通道", center + Vector3(0.0, 2.45, 0.0), Color("f5e2b6"))

func _add_store_interior_lights(center: Vector3) -> void:
	for index in range(3):
		var light_panel := _box_mesh(Vector3(0.18, 0.06, 2.7), Color("fff1cf"))
		light_panel.position = center + Vector3(-2.0 + index * 2.0, 2.85, 0.0)
		add_child(light_panel)

func _add_store_interior_visuals(center: Vector3) -> void:
	# 只增加商店内部的可见层，避免玩家进入后看到空白墙面；不创建碰撞、导航、
	# 交互或任务节点，正式逻辑仍由原有灰盒商店承担。
	var interior := Node3D.new()
	interior.name = "免费鸡蛋商店内部视觉层"
	interior.set_meta("visual_candidate", true)
	interior.set_meta("visual_only", true)
	add_child(interior)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("75675b")
	floor_material.roughness = 0.86
	var floor := _box_mesh(Vector3(6.65, 0.035, 3.55), Color("75675b"))
	floor.name = "商店内部磨砂地面"
	floor.position = center + Vector3(0.0, 0.13, 0.05)
	floor.material_override = floor_material
	interior.add_child(floor)
	for index in range(8):
		var tile := _box_mesh(Vector3(0.76, 0.018, 0.34), Color("b79b79" if index % 2 == 0 else "4e555b"))
		tile.name = "商店内部地面导视块-%02d" % index
		tile.position = center + Vector3(-2.65 + float(index) * 0.76, 0.17, 1.22)
		interior.add_child(tile)
	var rear_panel := _box_mesh(Vector3(6.25, 2.35, 0.06), Color("8a6d61"))
	rear_panel.name = "商店内部后墙暖色面板"
	rear_panel.position = center + Vector3(0.0, 1.38, -1.88)
	interior.add_child(rear_panel)
	for index in range(5):
		var poster := _box_mesh(Vector3(0.74, 0.86, 0.035), Color("d9bd80" if index % 2 == 0 else "6d8c88"))
		poster.name = "商店内部商品海报-%02d" % index
		poster.position = center + Vector3(-2.42 + float(index) * 1.20, 1.52, -1.93)
		interior.add_child(poster)
	var counter := _box_mesh(Vector3(2.80, 0.76, 0.56), Color("6f4e3e"))
	counter.name = "商店内部收银台"
	counter.position = center + Vector3(0.0, 0.55, 1.10)
	interior.add_child(counter)
	var counter_top := _box_mesh(Vector3(2.92, 0.08, 0.62), Color("c39868"))
	counter_top.name = "商店内部收银台台面"
	counter_top.position = center + Vector3(0.0, 0.98, 1.10)
	interior.add_child(counter_top)
	var register := _box_mesh(Vector3(0.42, 0.22, 0.34), Color("263a43"))
	register.name = "商店内部收银机"
	register.position = center + Vector3(0.42, 1.13, 1.10)
	interior.add_child(register)
	for index in range(4):
		var basket := _box_mesh(Vector3(0.50, 0.34, 0.40), Color("d2a64c" if index % 2 == 0 else "6a9b91"))
		basket.name = "商店内部商品筐-%02d" % index
		basket.position = center + Vector3(-1.70 + float(index) * 1.10, 0.35, 1.02)
		interior.add_child(basket)
	var hanging_sign := _box_mesh(Vector3(1.35, 0.48, 0.05), Color("c9342e"))
	hanging_sign.name = "商店内部悬挂招牌"
	hanging_sign.position = center + Vector3(0.0, 2.30, -0.10)
	interior.add_child(hanging_sign)
	_add_label_3d("店内收银台", center + Vector3(0.0, 1.22, 1.00), Color("ffe8bd"))

func _update_navigation_zone() -> void:
	var in_aisle := player.global_position.x > -10.8 and player.global_position.x < -7.2 and player.global_position.z > -11.7 and player.global_position.z < -7.9
	if in_aisle == inside_store_aisle:
		return
	inside_store_aisle = in_aisle
	if camera_rig != null:
		if in_aisle:
			camera_rig.set_follow_profile(2.5, 1.75)
		else:
			camera_rig.set_follow_profile(3.4, 2.1)
	_set_storefront_exterior_visibility(not in_aisle)
	var sign := get_node_or_null("免费鸡蛋红色门头")
	var title := get_node_or_null("标识-免费鸡蛋")
	var details := get_node_or_null("商店门面细节")
	var roof := get_node_or_null("免费鸡蛋商店屋顶")
	var fascia := get_node_or_null("免费鸡蛋商店门头")
	var back_wall := get_node_or_null("免费鸡蛋商店后墙")
	if sign != null:
		sign.visible = not in_aisle
	if title != null:
		title.visible = not in_aisle
	if details != null:
		details.visible = not in_aisle
	if roof != null:
		# city-04 的参考镜头位于店内，封闭顶面会压住画面上半部并遮掉
		# 冲突主体；屋顶只属于视觉层，采集态隐藏不影响碰撞、导航或任务。
		var capture_scenario := str(get_meta("reference_capture_scenario", ""))
		roof.visible = not (in_aisle and reference_capture_mode and capture_scenario == "city-04")
	if fascia != null:
		fascia.visible = not in_aisle
	if back_wall != null and reference_capture_mode:
		back_wall.visible = not in_aisle
	trace.record("navigation", {"zone": "store_aisle", "entered": in_aisle})

func _set_storefront_exterior_visibility(visible: bool) -> void:
	# 原创候选立面卡和门头只服务于店外镜头；进入店内后关闭它们，避免
	# 外立面平面穿过门洞遮挡货架。该切换不影响实体墙、导航或任务节点。
	var visual_root := get_node_or_null("Visual")
	if visual_root == null:
		return
	# 候选城市环境层当前主要是店外立面卡；店内镜头关闭整层，避免任意
	# 未登记的立面子节点穿过门洞。店内货架、收银台和灯光属于本场景的
	# 独立视觉层，不受此开关影响。
	visual_root.visible = visible
	var root_exterior_names := [
		"免费鸡蛋红色门头", "免费鸡蛋商店门头", "原创写实店铺立面候选",
		"原创首店招牌底板", "原创首店招牌文字", "标识-免费鸡蛋"
	]
	for node_name in root_exterior_names:
		var root_node := find_child(str(node_name), true, false)
		if root_node != null:
			root_node.visible = visible
	for sign_node in find_children("*门头*", "Node3D", true, false):
		if sign_node != null:
			sign_node.visible = visible
	for sign_node in find_children("*招牌*", "Node3D", true, false):
		if sign_node != null:
			sign_node.visible = visible
	var exterior_names := [
		"候选原创写实店铺人群背景卡", "候选原创写实店铺材质卡", "候选店铺门面",
		"候选店铺门头", "候选店铺门头装饰", "候选店铺左窗", "候选店铺右窗",
		"候选店铺中柱", "候选店铺遮阳条", "候选店铺招牌灯", "候选店铺门头内嵌线",
		"候选店铺入口门框左", "候选店铺入口门框右", "候选店铺入口门楣", "候选店铺入口门把手",
		"候选店铺遮阳棚褶线"
	]
	for node_name in exterior_names:
		var node := visual_root.find_child(str(node_name), true, false)
		if node != null:
			node.visible = visible

func _add_street_lamp(location: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "街灯"
	lamp.position = location
	add_child(lamp)
	lamp.add_child(_box_mesh(Vector3(0.12, 3.6, 0.12), Color("333943")))
	var head := _box_mesh(Vector3(0.65, 0.12, 0.18), Color("e7c16d"))
	head.position = Vector3(0.22, 3.45, 0.0)
	lamp.add_child(head)

func _add_tree(location: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "行道树"
	tree.position = location
	add_child(tree)
	tree.add_child(_box_mesh(Vector3(0.28, 2.2, 0.28), Color("60483c")))
	var crown := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.25
	sphere.height = 2.5
	crown.mesh = sphere
	crown.position = Vector3(0.0, 2.8, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4d704e")
	crown.material_override = material
	tree.add_child(crown)

func _hide_debug_labels_for_capture() -> void:
	for node in find_children("", "Label3D", true, false):
		if node is Label3D:
			node.visible = false
	if mission_title_label != null:
		mission_title_label.visible = false

func _hide_reference_geometry() -> void:
	# 交互目标的彩色方块和商店后墙是开发辅助物，不应冒充参考游戏中的可见资产。
	for target in targets:
		target.visible = false
	for node in find_children("*", "InteractionTarget", true, false):
		if node.get_meta("side_activity", false) or node.get_meta("side_activity_delivery", false):
			node.visible = false
	# 城市参考段各自使用不同的背景层：首店使用人群店铺卡，驾驶和终点
	# 使用道路/傍晚街景卡。其余候选卡在同一镜头中全部关闭，避免多个
	# 透视平面互相叠加；这只影响采集态表现，不改变普通游戏的场景、碰撞
	# 或任务状态。
	var capture_scenario := str(get_meta("reference_capture_scenario", ""))
	# 首店和驾驶段现在统一使用三维环境；背景卡已在正式采集入口关闭，
	# 这里不能再把城市环境根节点整体隐藏，否则会留下空色背景。
	var capture_card_by_scenario := {
		# 首店镜头使用原创写实人群店铺卡；程序化人群会在下方关闭，
		# 保留玩家与店铺入口的三维交互关系。
		"city-01": "",
		"city-02": "",
		"city-03": "",
		"city-04": "",
		"city-05": "",
		"city-06": "",
		# 驾驶段使用连续三维街道；关闭整张远景图片卡，避免低模载具
		# 与照片景深发生明显风格断层。
		"city-07": "",
		"city-08": "",
		"city-09": "",
		"city-10": "",
		"city-11": "",
	}
	if capture_card_by_scenario.has(capture_scenario):
		var keep_card_name := str(capture_card_by_scenario[capture_scenario])
		var standalone_storefront := get_node_or_null("原创写实店铺立面候选")
		if standalone_storefront != null:
			standalone_storefront.visible = capture_scenario == "city-03"
		var warehouse_visual := get_node_or_null("原创写实后场仓储门面候选")
		if warehouse_visual != null:
			warehouse_visual.visible = capture_scenario == "city-06"
		var visual_root := get_node_or_null("Visual")
		if visual_root != null:
			var card_names := [
				"候选原创写实店铺人群背景卡", "候选原创写实店铺材质卡",
				"候选原创写实仓储材质卡", "候选原创左侧连续街墙",
				"候选原创右侧连续街墙", "候选原创右侧街角门面",
				"候选原创远端街墙", "候选原创终点傍晚街道背景卡",
				"候选原创城市驾驶街道背景卡", "候选原创近景店铺人群图卡",
				"候选原创近景城市店铺图卡",
			]
			for card_name in card_names:
				var card := visual_root.find_child(card_name, true, false)
				if card != null:
					card.visible = card_name == keep_card_name
	if capture_scenario in ["city-08", "city-11"]:
		var endpoint_facade := get_node_or_null("旺铺转让门面")
		if endpoint_facade != null:
			endpoint_facade.visible = false
		for endpoint_visual in find_children("*", "Node3D", true, false):
			# city-08 不应出现终点识别层；city-11 则使用当前源绑定的
			# 傍晚背景卡，采集态仍要隐藏所有终点程序化门面，避免两套
			# 透视叠加。普通 apply_state 的视觉契约不受此采集清理影响。
			if capture_scenario == "city-08" and city_scene_visuals != null and city_scene_visuals.is_ancestor_of(endpoint_visual):
				continue
			if endpoint_visual.name.contains("原创终点店") or endpoint_visual.name.contains("旺铺转让"):
				endpoint_visual.visible = false
	else:
		# 终点门面只属于 city-11；在驾驶、仓储和店内镜头中隐藏，
		# 避免同一画面叠入不属于当前任务段的红色卷帘门。
		var non_endpoint_facade := get_node_or_null("旺铺转让门面")
		if non_endpoint_facade != null:
			non_endpoint_facade.visible = false
		for non_endpoint_visual in find_children("*", "Node3D", true, false):
			if city_scene_visuals != null and city_scene_visuals.is_ancestor_of(non_endpoint_visual):
				continue
			if non_endpoint_visual.name.contains("原创终点店") or non_endpoint_visual.name.contains("旺铺转让"):
				non_endpoint_visual.visible = false
	if capture_scenario in ["city-07", "city-08", "city-09", "city-10"]:
		# 关闭侧街照片材质，只保留刚才恢复的三维立面，保持角色、载具和
		# 环境使用同一套光照与透视，避免局部又出现照片贴片。
		for photo_facade in find_children("*", "Node3D", true, false):
			if photo_facade.name == "原创写实店铺立面候选":
				photo_facade.visible = false
		# 这些开发期街景道具会落在驾驶相机的中心线，遮住玩家、车辆和道路
		# 方向；驾驶参考段保留路缘、窗带和店面尺度，但隐藏中心遮挡物。
		for drive_blocker in find_children("*", "Node3D", true, false):
			if drive_blocker.name.begins_with("街灯") or drive_blocker.name.begins_with("行道树") \
				or drive_blocker.name.begins_with("候选街灯") \
				or drive_blocker.name.contains("原创连续街区行道树") \
				or drive_blocker.name.contains("原创街区电缆"):
				drive_blocker.visible = false
	if capture_scenario in ["city-01", "city-08", "city-09", "city-10", "city-11"]:
		for auxiliary_name in ["扫码登记牌", "登记员"]:
			var auxiliary := get_node_or_null(auxiliary_name)
			if auxiliary != null:
				auxiliary.visible = false
		for auxiliary in find_children("*扫码*", "Node3D", true, false):
			auxiliary.visible = false
		for auxiliary in find_children("*登记*", "Node3D", true, false):
			auxiliary.visible = false
	if capture_scenario == "city-08":
		# city-08 是车尾跟拍：远景由原创街景背景卡承接，开发期静态盒体仍需
		# 保留碰撞但不能继续作为可见墙体盖住车辆、道路消失点和背景卡。
		# 这里只隐藏非主体树下的 MeshInstance3D，不隐藏 StaticBody3D 或
		# CollisionShape3D，因此不会改变驾驶、碰撞、导航或任务状态。使用
		# 白名单而不是依赖若干重复节点名，避免新增灰盒建筑再次漏进画面。
		# 车尾跟拍需要保留同一套原创三维环境：城市候选环境根节点负责
		# 店面、楼体和街灯，远景层负责消失点，道路视觉细节负责车道线、
		# 路缘和斑马线。这里只放行渲染根，不放行任何额外碰撞或任务节点。
		var drive_capture_visual_roots := [
			"玩家", "蓝色三轮车", "Visual", "原创城市远景层", "道路视觉细节"
		]
		for drive_root in get_children():
			if str(drive_root.name) in drive_capture_visual_roots:
				continue
			if city_reference_world_backdrop != null and (drive_root == city_reference_world_backdrop or drive_root.is_ancestor_of(city_reference_world_backdrop)):
				continue
			_hide_descendant_visual_meshes(drive_root)
	if capture_scenario in ["city-01", "city-02", "city-04", "city-05"]:
		# 当前正式矩阵不再使用整张写实背景卡，因此不能沿用“照片卡已含
		# 人群”的旧隐藏规则。保留原创三维人群，才能验收真实遮挡、碰撞
		# 关系、脚底接触和角色材质；人群仍不接管任务、导航或感知逻辑。
		for pedestrian in pedestrians:
			pedestrian.visible = true
		for crowd_blocker in crowd_blockers:
			crowd_blocker.visible = true
		if visual_crowd_root != null:
			visual_crowd_root.visible = true
	else:
		if visual_crowd_root != null:
			# city-08 的参考段只有车尾跟拍主体；把纯表现人群留在其它
			# 街景段，避免近景低模行人抢占车辆和驾驶员的视觉层级。
			visual_crowd_root.visible = capture_scenario in ["city-07", "city-09", "city-10"]
	if capture_scenario in ["city-07", "city-08", "city-09", "city-10", "city-11"]:
		# 驾驶段和终点段都使用当前源绑定的完整街景卡承接远景、道路和
		# 建筑透视；采集态只保留主动体与载具，避免开发期低模几何再次
		# 盖住卡片。该白名单只改渲染可见性，不改碰撞、导航、任务或存档。
		var capture_backdrop_name := "候选原创终点傍晚街道背景卡" if capture_scenario == "city-11" else "候选原创城市驾驶街道背景卡"
		var capture_backdrop := find_child(capture_backdrop_name, true, false)
		for capture_mesh in find_children("*", "MeshInstance3D", true, false):
			if capture_mesh == capture_backdrop:
				continue
			var is_runtime_scene_visual := bool(capture_mesh.get_meta("visual_only", false)) and bool(capture_mesh.get_meta("candidate_visual_only", false))
			if is_runtime_scene_visual:
				continue
			if player != null and player.is_ancestor_of(capture_mesh):
				continue
			if vehicle != null and vehicle.is_ancestor_of(capture_mesh):
				continue
			(capture_mesh as MeshInstance3D).visible = false
	if capture_scenario == "city-11":
		for traffic in traffic_vehicles:
			traffic.visible = false
		for pedestrian in pedestrians:
			pedestrian.visible = false
		for crowd_blocker in crowd_blockers:
			crowd_blocker.visible = false
		if visual_crowd_root != null:
			visual_crowd_root.visible = false
		if conflict_agent != null:
			conflict_agent.visible = false
		var road_details := get_node_or_null("道路视觉细节")
		if road_details != null:
			road_details.visible = false
		# 终点镜头由当前源绑定的原创傍晚街景卡承担完整的街道透视；Visual
		# 下仍可能挂有不同来源的候选楼体、店面和远景结构。它们只属于采集态
		# 的渲染候选，不能继续盖住背景卡右侧，也不参与碰撞、导航或任务判断。
		# 保留傍晚卡本身，其余 Visual 子树只关闭 MeshInstance3D/Label3D。
		var endpoint_visual_root := get_node_or_null("Visual")
		if endpoint_visual_root != null:
			var endpoint_backdrop := endpoint_visual_root.find_child("候选原创终点傍晚街道背景卡", true, false)
			for endpoint_visual_child in endpoint_visual_root.get_children():
				if endpoint_visual_child == endpoint_backdrop:
					continue
				_hide_descendant_visual_meshes(endpoint_visual_child)
		if vehicle != null:
			var vehicle_visual := vehicle.get_node_or_null("Visual")
			if vehicle_visual != null:
				var direct_imported_canopy := vehicle.get_node_or_null("Visual/ThreeWheelDelivery/候选三轮车顶篷")
				if direct_imported_canopy != null:
					direct_imported_canopy.visible = false
				var canopy := vehicle_visual.find_child("候选三轮车顶棚", true, false)
				if canopy != null:
					canopy.visible = false
				var imported_canopy := vehicle_visual.find_child("候选三轮车顶篷", true, false)
				if imported_canopy != null:
					imported_canopy.visible = false
				for vehicle_mesh in vehicle_visual.find_children("*", "MeshInstance3D", true, false):
					if vehicle_mesh.name.contains("顶篷") or vehicle_mesh.name.contains("顶棚"):
						vehicle_mesh.visible = false
	if capture_scenario == "city-01":
		var road_details := get_node_or_null("道路视觉细节")
		if road_details != null:
			road_details.visible = false
		var interaction_props := get_node_or_null("交互道具层")
		if interaction_props != null:
			interaction_props.visible = false
		# 首店参考帧没有三轮车；只隐藏车辆的渲染根，不改变车辆碰撞、
		# 驾驶状态、任务状态或后续正常游戏中的车辆可见性。
		if vehicle != null:
			vehicle.visible = false
			for vehicle_visual_child in vehicle.find_children("*", "Node3D", true, false):
				vehicle_visual_child.visible = false
		# 原创候选目录可能以不同 root_name 挂载多个表现层；首店采集只保留
		# 玩家和远景平面，统一关闭其余三维网格，避免挂载名差异造成漏网的
		# 灰盒桌面、道具或车辆面板。碰撞、导航和任务节点不在此循环内修改。
		for candidate_mesh in find_children("*", "MeshInstance3D", true, false):
			if candidate_mesh == city_reference_world_backdrop:
				continue
			var is_runtime_scene_visual := bool(candidate_mesh.get_meta("visual_only", false)) and bool(candidate_mesh.get_meta("candidate_visual_only", false))
			if is_runtime_scene_visual:
				continue
			if player != null and player.is_ancestor_of(candidate_mesh):
				continue
			if visual_crowd_root != null and visual_crowd_root.is_ancestor_of(candidate_mesh):
				continue
			(candidate_mesh as MeshInstance3D).visible = false
	var back_wall := get_node_or_null("免费鸡蛋商店后墙")
	if back_wall != null and inside_store_aisle:
		back_wall.visible = false

class_name ThirdPersonCameraRig
extends Node3D

signal orbit_changed(state: Dictionary)

@export var distance := 6.8
@export var height := 3.4
@export var pitch_degrees := -15.0
@export var yaw_degrees := 0.0
@export var shoulder_offset := Vector3.ZERO
@export var look_sensitivity := 0.08
@export var min_pitch_degrees := -55.0
@export var max_pitch_degrees := -5.0
@export var collision_margin := 0.35
@export var collision_mask := 1
@export var collision_probe_radius := 0.18
@export var collision_probe_steps := 8
@export var feedback_enabled := true

var camera: Camera3D
var last_collision_distance := 0.0
var last_collision := false
var collision_probe_shape: SphereShape3D
var feedback_elapsed := 0.0
var feedback_duration := 0.0
var feedback_amplitude := 0.0
var feedback_frequency := 22.0

func _ready() -> void:
	collision_probe_shape = SphereShape3D.new()
	collision_probe_shape.radius = maxf(0.05, collision_probe_radius)
	camera = Camera3D.new()
	camera.name = "第三人称相机"
	camera.current = true
	add_child(camera)
	_update_transform()

func _process(delta: float) -> void:
	if camera == null:
		return
	if feedback_duration <= 0.0:
		camera.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)
		return
	feedback_elapsed += delta
	var progress := clampf(feedback_elapsed / feedback_duration, 0.0, 1.0)
	var envelope := (1.0 - progress) * (1.0 - progress)
	var pulse := sin(feedback_elapsed * feedback_frequency * TAU)
	var pitch_offset := pulse * feedback_amplitude * 0.55 * envelope
	var roll_offset := pulse * feedback_amplitude * 0.8 * envelope
	camera.rotation_degrees = Vector3(pitch_degrees + pitch_offset, 0.0, roll_offset)
	if progress >= 1.0:
		feedback_duration = 0.0
		feedback_elapsed = 0.0
		feedback_amplitude = 0.0

func pulse_feedback(amplitude: float, duration: float, frequency := 22.0) -> void:
	if not feedback_enabled:
		return
	feedback_elapsed = 0.0
	feedback_duration = maxf(0.0, duration)
	feedback_amplitude = clampf(amplitude, 0.0, 2.0)
	feedback_frequency = clampf(frequency, 4.0, 40.0)

func set_feedback_enabled(enabled: bool) -> void:
	feedback_enabled = enabled
	if not enabled:
		feedback_duration = 0.0
		feedback_elapsed = 0.0
		feedback_amplitude = 0.0
		if camera != null:
			camera.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)

func apply_look(look: Vector2) -> void:
	if look.length_squared() < 0.000001:
		# 镜头碰撞不只由视角变化触发。玩家移动离开墙角后，也必须重新
		# 计算安全距离，否则镜头会永久停留在上一次收近的位置。
		_update_transform()
		return
	yaw_degrees -= look.x * look_sensitivity
	pitch_degrees = clamp(pitch_degrees - look.y * look_sensitivity, min_pitch_degrees, max_pitch_degrees)
	_update_transform()
	orbit_changed.emit(snapshot())

func set_orbit(yaw: float, pitch: float) -> void:
	yaw_degrees = yaw
	pitch_degrees = clamp(pitch, min_pitch_degrees, max_pitch_degrees)
	_update_transform()
	orbit_changed.emit(snapshot())

func set_follow_profile(follow_distance: float, follow_height: float) -> void:
	distance = maxf(0.8, follow_distance)
	height = maxf(0.8, follow_height)
	_update_transform()

func set_shoulder_offset(offset: Vector3) -> void:
	shoulder_offset = offset
	_update_transform()

func snapshot() -> Dictionary:
	return {
		"yaw": yaw_degrees,
		"pitch": pitch_degrees,
		"shoulder_offset": [shoulder_offset.x, shoulder_offset.y, shoulder_offset.z],
		"position": [camera.position.x, camera.position.y, camera.position.z],
		"rotation": [camera.rotation_degrees.x, camera.rotation_degrees.y, camera.rotation_degrees.z],
		"collision": last_collision,
		"collision_distance": snappedf(last_collision_distance, 0.001)
	}

func _update_transform() -> void:
	rotation_degrees.y = yaw_degrees
	if camera == null:
		return
	var desired_local := Vector3(shoulder_offset.x, height + shoulder_offset.y, distance + shoulder_offset.z)
	last_collision = false
	last_collision_distance = distance
	if is_inside_tree() and get_world_3d() != null:
		# 从角色胸口高度发射，避免射线从矮墙上方穿过而错误认为镜头无遮挡。
		var pivot_global := global_position + Vector3.UP * 0.15
		var desired_global := global_position + global_transform.basis * desired_local
		var excluded: Array[RID] = []
		var parent_node := get_parent()
		if parent_node is CollisionObject3D:
			excluded.append(parent_node.get_rid())
		# 射线命中时也要尝试侧向避障，不能把镜头停在隔断正面；
		# 否则玩家虽然没有穿墙，画面却会被墙面永久占满。
		var safe_global := _find_probe_safe_position(pivot_global, desired_global, excluded)
		camera.global_position = safe_global
		last_collision = safe_global.distance_squared_to(desired_global) > 0.0001
		last_collision_distance = pivot_global.distance_to(safe_global) if last_collision else distance
	else:
		camera.position = desired_local
	camera.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)

func _find_probe_safe_position(pivot_global: Vector3, desired_global: Vector3, excluded: Array[RID]) -> Vector3:
	if _camera_candidate_is_clear(pivot_global, desired_global, excluded):
		return desired_global
	var steps := maxi(1, collision_probe_steps)
	var camera_vector := desired_global - pivot_global
	for step in range(steps - 1, 0, -1):
		var candidate := pivot_global + camera_vector * (float(step) / float(steps))
		if _camera_candidate_is_clear(pivot_global, candidate, excluded):
			return candidate
	# 玩家贴着桌角或隔断前进时，单纯沿相机后轴收近会把镜头留在
	# 隔断正面，形成“灰墙占满画面”。在保持相同跟随距离的前提下，
	# 依次尝试左右小幅侧移，优先找到一条从玩家胸口到镜头的无遮挡路径。
	# 这不是改变玩家朝向，而是第三人称相机的局部避障，避免把视觉阻塞
	# 转化成玩家必须盲操作的问题。
	var orbit_offsets := [-24.0, 24.0, -42.0, 42.0, -66.0, 66.0, -90.0, 90.0]
	for offset_degrees in orbit_offsets:
		var candidate_vector := camera_vector.rotated(Vector3.UP, deg_to_rad(offset_degrees))
		var candidate := pivot_global + candidate_vector
		if _camera_candidate_is_clear(pivot_global, candidate, excluded):
			return candidate
	# 隔断或桌角同时挡住所有探测点时，不能把镜头退回到几乎贴在
	# 玩家胸口的碰撞余量位置；那会形成贴地、穿模式的“镜头失明”。
	# 保留一个可读的最小第三人称距离，让玩家仍能看见角色和障碍边界。
	var fallback_distance := minf(camera_vector.length(), maxf(1.25, collision_margin * 3.0))
	return pivot_global + camera_vector.normalized() * fallback_distance

func _camera_candidate_is_clear(pivot_global: Vector3, candidate_global: Vector3, excluded: Array[RID]) -> bool:
	var ray_query := PhysicsRayQueryParameters3D.create(pivot_global, candidate_global, collision_mask, excluded)
	if not get_world_3d().direct_space_state.intersect_ray(ray_query).is_empty():
		return false
	return _probe_position_is_clear(candidate_global, excluded)

func _probe_position_is_clear(position: Vector3, excluded: Array[RID]) -> bool:
	if collision_probe_shape == null or get_world_3d() == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_probe_shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = collision_mask
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

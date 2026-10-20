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
		var query := PhysicsRayQueryParameters3D.create(pivot_global, desired_global, collision_mask, excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Vector3 = hit["position"]
			var safe_global := hit_position + (pivot_global - hit_position).normalized() * collision_margin
			camera.global_position = safe_global
			last_collision = true
			last_collision_distance = pivot_global.distance_to(safe_global)
		else:
			# 中心线没有命中并不等于镜头体积没有穿过柱体或墙角。
			# 只在射线通过时进行球形探测，保留原有构图和碰撞距离契约。
			var safe_global := _find_probe_safe_position(pivot_global, desired_global, excluded)
			if safe_global.distance_squared_to(desired_global) > 0.0001:
				camera.global_position = safe_global
				last_collision = true
				last_collision_distance = pivot_global.distance_to(safe_global)
			else:
				camera.position = desired_local
	else:
		camera.position = desired_local
	camera.rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)

func _find_probe_safe_position(pivot_global: Vector3, desired_global: Vector3, excluded: Array[RID]) -> Vector3:
	if _probe_position_is_clear(desired_global, excluded):
		return desired_global
	var steps := maxi(1, collision_probe_steps)
	var camera_vector := desired_global - pivot_global
	for step in range(steps - 1, 0, -1):
		var candidate := pivot_global + camera_vector * (float(step) / float(steps))
		if _probe_position_is_clear(candidate, excluded):
			return candidate
	return pivot_global + camera_vector.normalized() * collision_margin

func _probe_position_is_clear(position: Vector3, excluded: Array[RID]) -> bool:
	if collision_probe_shape == null or get_world_3d() == null:
		return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_probe_shape
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = collision_mask
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

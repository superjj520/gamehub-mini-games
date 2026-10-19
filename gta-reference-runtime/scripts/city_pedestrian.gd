class_name CityPedestrian
extends Node3D

const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")

@export var walk_speed := 1.4
@export var role_id := "street_walker"
@export var role_label := "街区行人"
@export var traffic_avoidance_radius := 1.8
@export var traffic_avoidance_weight := 0.85

var waypoints: Array = []
var waypoint_index := 0
var traffic_sources: Array[Node3D] = []
var traffic_avoidance_active := false
var traffic_avoidance_source: Node3D
var displaced := false
var displacement_return_position := Vector3.ZERO
var displacement_return_waypoint_index := 0
var panic_timer := 0.0
var panic_source_position := Vector3.ZERO

func _physics_process(delta: float) -> void:
	if displaced:
		AssetRuntimeCatalogClass.drive_animation_state(self, "displaced_default")
		return
	if panic_timer > 0.0:
		panic_timer = maxf(panic_timer - maxf(delta, 0.0), 0.0)
		var panic_direction := global_position - panic_source_position
		panic_direction.y = 0.0
		if panic_direction.length_squared() < 0.01:
			panic_direction = Vector3(0.0, 0.0, 1.0)
		panic_direction = panic_direction.normalized()
		global_position += panic_direction * walk_speed * 2.2 * maxf(delta, 0.0)
		look_at(global_position + Vector3(panic_direction.x, 0.0, panic_direction.z), Vector3.UP)
		traffic_avoidance_active = true
		traffic_avoidance_source = null
		AssetRuntimeCatalogClass.drive_animation_state(self, "displaced_default")
		return
	if waypoints.is_empty():
		traffic_avoidance_active = false
		traffic_avoidance_source = null
		AssetRuntimeCatalogClass.drive_animation_state(self, "idle_default")
		return
	var target: Vector3 = waypoints[waypoint_index]
	var offset: Vector3 = target - global_position
	if offset.length() < 0.15:
		global_position = target
		waypoint_index = (waypoint_index + 1) % waypoints.size()
		target = waypoints[waypoint_index]
		offset = target - global_position
	if offset.length() < 0.001:
		traffic_avoidance_active = false
		traffic_avoidance_source = null
		AssetRuntimeCatalogClass.drive_animation_state(self, "idle_default")
		return
	var move_direction := offset.normalized()
	var avoidance := _traffic_avoidance_vector()
	if avoidance.length_squared() > 0.0:
		move_direction = (move_direction + avoidance * traffic_avoidance_weight).normalized()
	global_position += move_direction * walk_speed * maxf(delta, 0.0)
	look_at(global_position + Vector3(move_direction.x, 0.0, move_direction.z), Vector3.UP)
	AssetRuntimeCatalogClass.drive_animation_state(self, "walk_default")

func set_traffic_sources(sources: Array[Node3D]) -> void:
	traffic_sources = sources

func react_to_vehicle(source_position: Vector3, duration := 1.2) -> bool:
	if displaced or panic_timer > 0.0:
		return false
	panic_source_position = source_position
	panic_timer = clampf(duration, 0.2, 4.0)
	traffic_avoidance_active = true
	traffic_avoidance_source = null
	AssetRuntimeCatalogClass.drive_animation_state(self, "displaced_default")
	return true

func displace_from(source_position: Vector3, distance := 0.72) -> void:
	if displaced:
		return
	displaced = true
	displacement_return_position = global_position
	displacement_return_waypoint_index = waypoint_index
	var direction := global_position - source_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3(0.0, 0.0, 1.0)
	global_position += direction.normalized() * distance
	traffic_avoidance_active = false
	traffic_avoidance_source = null
	AssetRuntimeCatalogClass.drive_animation_state(self, "displaced_default")

func reset_displacement() -> void:
	if not displaced:
		return
	global_position = displacement_return_position
	waypoint_index = displacement_return_waypoint_index
	displaced = false
	AssetRuntimeCatalogClass.drive_animation_state(self, "idle_default")

func snapshot_state() -> Dictionary:
	return {
		"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z},
		"waypoint_index": waypoint_index,
		"displaced": displaced,
		"panic_timer": panic_timer,
		"panic_source_position": {"x": panic_source_position.x, "y": panic_source_position.y, "z": panic_source_position.z},
		"return_position": {"x": displacement_return_position.x, "y": displacement_return_position.y, "z": displacement_return_position.z},
		"return_waypoint_index": displacement_return_waypoint_index
	}

func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var position_data = state.get("position", {})
	if position_data is Dictionary:
		global_position = Vector3(
			float(position_data.get("x", global_position.x)),
			float(position_data.get("y", global_position.y)),
			float(position_data.get("z", global_position.z))
		)
	waypoint_index = clampi(int(state.get("waypoint_index", waypoint_index)), 0, maxi(waypoints.size() - 1, 0))
	panic_timer = clampf(float(state.get("panic_timer", 0.0)), 0.0, 4.0)
	var panic_data = state.get("panic_source_position", {})
	if panic_data is Dictionary:
		panic_source_position = Vector3(
			float(panic_data.get("x", panic_source_position.x)),
			float(panic_data.get("y", panic_source_position.y)),
			float(panic_data.get("z", panic_source_position.z))
		)
	var return_data = state.get("return_position", {})
	if return_data is Dictionary:
		displacement_return_position = Vector3(
			float(return_data.get("x", global_position.x)),
			float(return_data.get("y", global_position.y)),
			float(return_data.get("z", global_position.z))
		)
	displacement_return_waypoint_index = maxi(int(state.get("return_waypoint_index", waypoint_index)), 0)
	displaced = bool(state.get("displaced", false))
	traffic_avoidance_active = false
	traffic_avoidance_source = null
	AssetRuntimeCatalogClass.drive_animation_state(self, "displaced_default" if displaced or panic_timer > 0.0 else "idle_default")

func _traffic_avoidance_vector() -> Vector3:
	var strongest_weight := 0.0
	var strongest_avoidance := Vector3.ZERO
	traffic_avoidance_source = null
	for source in traffic_sources:
		if not is_instance_valid(source) or source == self:
			continue
		var offset := global_position - source.global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= 0.001 or distance >= traffic_avoidance_radius:
			continue
		var proximity_weight := 1.0 - distance / traffic_avoidance_radius
		var source_velocity := Vector3.ZERO
		if source is CharacterBody3D:
			source_velocity = (source as CharacterBody3D).velocity
			source_velocity.y = 0.0
		if source_velocity.length_squared() > 0.01:
			var toward_pedestrian := offset.normalized()
			if source_velocity.normalized().dot(toward_pedestrian) < 0.05:
				proximity_weight *= 0.35
		if proximity_weight > strongest_weight:
			strongest_weight = proximity_weight
			strongest_avoidance = offset.normalized() * proximity_weight
			traffic_avoidance_source = source
	traffic_avoidance_active = true
	if strongest_weight <= 0.0:
		traffic_avoidance_active = false
	return strongest_avoidance

func prepare_reference_capture() -> void:
	set_physics_process(false)
	AssetRuntimeCatalogClass.drive_animation_state(self, "idle_default")
	waypoint_index = 0
	traffic_avoidance_active = false
	traffic_avoidance_source = null
	displaced = false
	panic_timer = 0.0
	panic_source_position = Vector3.ZERO
	if not waypoints.is_empty():
		global_position = waypoints[0]
		if waypoints.size() > 1:
			look_at(Vector3(waypoints[1].x, global_position.y, waypoints[1].z), Vector3.UP)

func snapshot_role() -> Dictionary:
	return {
		"role_id": role_id,
		"role_label": role_label,
		"walk_speed": walk_speed,
		"waypoint_count": waypoints.size()
	}

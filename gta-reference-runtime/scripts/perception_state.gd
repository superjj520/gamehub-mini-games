class_name PerceptionState
extends RefCounted

signal status_changed(previous_status: int, current_status: int)

enum Status { CALM, SUSPICIOUS, ALERT, LOST }

var status: Status = Status.CALM
var suspicion: float = 0.0
var last_seen_position := Vector3.ZERO
var last_heard_position := Vector3.ZERO
var last_heard_strength := 0.0
var last_heard_age := 999.0
var suspicion_gain_per_second := 1.8
var suspicion_loss_per_second := 0.55
var hearing_radius := 10.0
var noise_suspicion_per_strength := 0.45
var noise_memory_seconds := 6.0

func observe(is_visible: bool, delta: float, player_position := Vector3.ZERO) -> void:
	last_heard_age += maxf(delta, 0.0)
	last_heard_strength = maxf(last_heard_strength - maxf(delta, 0.0) / maxf(noise_memory_seconds, 0.1), 0.0)
	if is_visible:
		last_seen_position = player_position
		suspicion = minf(suspicion + delta * suspicion_gain_per_second, 1.0)
		if suspicion >= 1.0:
			_set_status(Status.ALERT)
		elif suspicion >= 0.35:
			_set_status(Status.SUSPICIOUS)
	else:
		suspicion = maxf(suspicion - delta * suspicion_loss_per_second, 0.0)
		if status == Status.ALERT:
			_set_status(Status.LOST)
		elif suspicion <= 0.0:
			_set_status(Status.CALM)

func hear_noise(source_position: Vector3, loudness: float, observer_position: Vector3, max_hearing_distance := -1.0) -> bool:
	var radius := hearing_radius if max_hearing_distance <= 0.0 else max_hearing_distance
	if radius <= 0.0 or loudness <= 0.0:
		return false
	var distance := observer_position.distance_to(source_position)
	var audible_strength := clampf(loudness, 0.0, 1.0) * clampf(1.0 - distance / radius, 0.0, 1.0)
	if audible_strength <= 0.0:
		return false
	last_heard_position = source_position
	last_heard_strength = audible_strength
	last_heard_age = 0.0
	suspicion = minf(suspicion + audible_strength * noise_suspicion_per_strength, 1.0)
	if suspicion >= 1.0:
		_set_status(Status.ALERT)
	elif suspicion >= 0.35:
		_set_status(Status.SUSPICIOUS)
	return true

func last_known_position() -> Vector3:
	if last_heard_strength > 0.0 and last_heard_age <= noise_memory_seconds:
		return last_heard_position
	return last_seen_position

func is_visible_from(observer_position: Vector3, target_position: Vector3, space_state: PhysicsDirectSpaceState3D, max_distance: float, field_of_view_degrees: float, excluded: Array[RID] = [], observer_forward := Vector3.FORWARD) -> bool:
	var offset := target_position - observer_position
	if offset.length() > max_distance:
		return false
	var forward := observer_forward.normalized()
	var direction := offset.normalized()
	var angle := rad_to_deg(acos(clampf(forward.dot(direction), -1.0, 1.0)))
	if angle > field_of_view_degrees * 0.5:
		return false
	var query := PhysicsRayQueryParameters3D.create(observer_position, target_position, 4294967295, excluded)
	var hit := space_state.intersect_ray(query)
	return hit.is_empty()

func reset() -> void:
	_set_status(Status.CALM)
	suspicion = 0.0
	last_seen_position = Vector3.ZERO
	last_heard_position = Vector3.ZERO
	last_heard_strength = 0.0
	last_heard_age = 999.0

func _set_status(next_status: Status) -> void:
	if status == next_status:
		return
	var previous := status
	status = next_status
	status_changed.emit(previous, status)

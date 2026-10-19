class_name ReferencePlayer
extends CharacterBody3D

const InputFrameClass = preload("res://scripts/input_frame.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")

@export var walk_speed := 4.2
@export var sprint_speed := 6.4
@export var crouch_speed := 2.0
@export var movement_acceleration := 26.0
@export var movement_deceleration := 34.0
@export var air_control := 0.82
@export var gravity := 18.0
@export var max_stamina := 100.0
@export var sprint_stamina_drain_per_second := 28.0
@export var stamina_recovery_per_second := 20.0
@export var stamina_recovery_delay := 0.35

var crouching := false
var sprinting := false
var stamina := max_stamina
var stamina_recovery_timer := 0.0

var controlled_externally := false
var walk_cycle := 0.0
var presentation_base_position := Vector3.ZERO
var presentation_base_rotation_y := 0.0
var presentation_initialized := false
var last_motion_blocked := false
var last_collision_count := 0
var failure_presentation_locked := false
enum PresentationState { IDLE, WALK, CROUCH, INTERACT, VEHICLE, ATTACK, DODGE, HIT, FAIL }
var presentation_state: PresentationState = PresentationState.IDLE
var action_state: PresentationState = PresentationState.IDLE
var action_remaining := 0.0

func _physics_process(delta: float) -> void:
	if controlled_externally:
		return
	apply_input(InputFrameClass.from_keyboard(), delta)

func apply_input(frame: InputFrame, delta: float, movement_basis := Basis.IDENTITY) -> void:
	crouching = frame.crouch
	var direction := movement_direction(frame, movement_basis)
	var wants_sprint := frame.sprint and not crouching and direction.length_squared() > 0.0001
	if wants_sprint and stamina > 0.0:
		sprinting = true
		stamina = maxf(stamina - sprint_stamina_drain_per_second * delta, 0.0)
		stamina_recovery_timer = stamina_recovery_delay
	else:
		sprinting = false
		stamina_recovery_timer = maxf(stamina_recovery_timer - delta, 0.0)
		if stamina_recovery_timer <= 0.0:
			stamina = minf(stamina + stamina_recovery_per_second * delta, max_stamina)
	var speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
	var target_velocity := direction * speed
	var control_scale := 1.0 if is_on_floor() else air_control
	var response := movement_acceleration if direction.length_squared() > 0.0001 else movement_deceleration
	response *= maxf(control_scale, 0.0)
	# 使用确定性的逐轴逼近，避免角色一按方向就瞬移到最高速；
	# 释放方向后也会快速刹停，保留 GTA 类型第三人称移动的重量感。
	velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	last_collision_count = get_slide_collision_count()
	last_motion_blocked = direction.length_squared() > 0.0001 and last_collision_count > 0
	_update_presentation(delta)

func stamina_ratio() -> float:
	return clampf(stamina / maxf(max_stamina, 0.001), 0.0, 1.0)

func reset_stamina() -> void:
	stamina = max_stamina
	stamina_recovery_timer = 0.0
	sprinting = false

func movement_direction(frame: InputFrame, movement_basis := Basis.IDENTITY) -> Vector3:
	var forward := -movement_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.000001 else Vector3(0.0, 0.0, -1.0)
	var right := movement_basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.000001 else Vector3.RIGHT
	var direction := right * frame.move.x + forward * -frame.move.y
	return direction.normalized() if direction.length_squared() > 1.0 else direction

func trigger_presentation_action(action_id: String) -> void:
	match action_id:
		"interact":
			action_state = PresentationState.INTERACT
			action_remaining = 0.28
		"vehicle":
			action_state = PresentationState.VEHICLE
			action_remaining = 0.36
		"attack":
			action_state = PresentationState.ATTACK
			action_remaining = 0.28
		"dodge":
			action_state = PresentationState.DODGE
			action_remaining = 0.42
		"hit":
			action_state = PresentationState.HIT
			action_remaining = 0.22
		"fail":
			action_state = PresentationState.FAIL
			action_remaining = 0.5
			failure_presentation_locked = true
		_:
			return
	presentation_state = action_state

func presentation_snapshot() -> Dictionary:
	return {
		"state": presentation_state,
		"action_remaining": snappedf(action_remaining, 0.001)
	}

func sync_presentation_state(delta: float = 0.0) -> void:
	# 进入载具后玩家不再走普通 apply_input，必须显式刷新一次视觉状态。
	_update_presentation(delta)

func _update_presentation(delta: float) -> void:
	var presentation := get_node_or_null("Visual") as Node3D
	if presentation == null:
		presentation = get_node_or_null("原创灰盒角色外观") as Node3D
	if presentation == null:
		return
	if not presentation_initialized:
		presentation_base_position = presentation.position
		presentation_base_rotation_y = presentation.rotation.y
		presentation_initialized = true
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horizontal_speed > 0.08
	var movement_direction_3d := Vector3(velocity.x, 0.0, velocity.z)
	if moving and movement_direction_3d.length_squared() > 0.0001:
		var target_yaw := atan2(-movement_direction_3d.x, -movement_direction_3d.z)
		presentation_base_rotation_y = lerp_angle(presentation_base_rotation_y, target_yaw, clampf(delta * 12.0, 0.0, 1.0))
	if moving:
		walk_cycle += delta * (8.0 if crouching else (16.0 if sprinting else 12.0))
	action_remaining = maxf(action_remaining - delta, 0.0)
	var locomotion_state: PresentationState = PresentationState.CROUCH if crouching else (PresentationState.WALK if moving else PresentationState.IDLE)
	presentation_state = action_state if failure_presentation_locked or action_remaining > 0.0 else locomotion_state
	var bob := absf(sin(walk_cycle)) * (0.035 if moving else 0.0)
	var crouch_offset := -0.22 if crouching else 0.0
	var action_offset := Vector3.ZERO
	var action_tilt := 0.0
	var action_pitch := 0.0
	if presentation_state == PresentationState.INTERACT:
		action_offset = Vector3(0.0, -0.06, -0.08)
		action_pitch = -0.08
	elif presentation_state == PresentationState.VEHICLE:
		action_offset = Vector3(0.0, -0.12, -0.12)
		action_pitch = -0.12
	elif presentation_state == PresentationState.ATTACK:
		action_offset = Vector3(0.0, 0.02, -0.10)
		action_pitch = -0.10
		action_tilt = -0.18
	elif presentation_state == PresentationState.DODGE:
		action_offset = Vector3(0.0, -0.03, -0.16)
		action_pitch = 0.08
		action_tilt = 0.24
	elif presentation_state == PresentationState.HIT:
		action_offset = Vector3(0.0, 0.04, 0.0)
		action_tilt = 0.14
	elif presentation_state == PresentationState.FAIL:
		action_offset = Vector3(0.0, -0.08, 0.02)
		action_pitch = 0.12
		action_tilt = 0.22
	presentation.position = presentation_base_position + Vector3(0.0, crouch_offset + bob, 0.0) + action_offset
	presentation.rotation.y = presentation_base_rotation_y
	var target_scale_y := 0.82 if crouching else 1.0
	if presentation_state == PresentationState.HIT:
		target_scale_y = 0.94
	elif presentation_state == PresentationState.FAIL:
		target_scale_y = 0.88
	presentation.scale.y = move_toward(presentation.scale.y, target_scale_y, delta * 8.0)
	presentation.rotation.x = lerpf(presentation.rotation.x, action_pitch, delta * 10.0)
	presentation.rotation.z = lerpf(presentation.rotation.z, (sin(walk_cycle) * 0.025 if moving else 0.0) + action_tilt, delta * 10.0)
	_apply_animation_state(presentation, presentation_state)

func _apply_animation_state(presentation: Node3D, state: PresentationState) -> void:
	var animation_name := _animation_name_for_state(state)
	AssetRuntimeCatalogClass.drive_animation_state(presentation, animation_name)

func clear_failure_presentation() -> void:
	failure_presentation_locked = false
	action_remaining = 0.0
	action_state = PresentationState.IDLE
	presentation_state = PresentationState.IDLE

func _animation_name_for_state(state: PresentationState) -> String:
	match state:
		PresentationState.WALK:
			return "walk_default"
		PresentationState.CROUCH:
			return "crouch_default"
		PresentationState.INTERACT:
			return "interact_default"
		PresentationState.VEHICLE:
			return "vehicle_default"
		PresentationState.ATTACK:
			return "attack_default"
		PresentationState.DODGE:
			return "dodge_default"
		PresentationState.HIT:
			return "hit_default"
		PresentationState.FAIL:
			return "fail_default"
		_:
			return "idle_default"

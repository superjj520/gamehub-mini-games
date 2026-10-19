class_name InteractionTarget
extends Node3D

signal interacted(actor: Node3D, interaction_id: String)

@export var interaction_id := "target"
@export var prompt := "交互"
@export var interaction_radius := 2.0
@export var one_shot := false

var completed := false

func can_interact(actor_position: Vector3) -> bool:
	return not completed and _world_position().distance_to(actor_position) <= interaction_radius

func try_interact(actor: Node3D, pressed: bool) -> bool:
	if not pressed or not can_interact(_actor_world_position(actor)):
		return false
	completed = true if one_shot else completed
	interacted.emit(actor, interaction_id)
	return true

func reset() -> void:
	completed = false

func _world_position() -> Vector3:
	return global_position if is_inside_tree() else position

func _actor_world_position(actor: Node3D) -> Vector3:
	return actor.global_position if actor.is_inside_tree() else actor.position

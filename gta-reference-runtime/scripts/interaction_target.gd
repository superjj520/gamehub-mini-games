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

func has_line_of_sight(actor: Node3D) -> bool:
	if actor == null or not is_inside_tree() or get_world_3d() == null:
		return true
	var from := actor.global_position + Vector3.UP * 0.82
	var to := _world_position() + Vector3.UP * 0.55
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = 1
	query.exclude = _collision_exclusion_rids(actor)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	# 某些候选交互点把碰撞体挂在 StaticBody3D 子节点上，射线命中
	# 子节点仍属于交互目标本身，不能把它误判成遮挡物。
	if collider == actor or collider == self:
		return true
	if collider != null and (actor.is_ancestor_of(collider) or is_ancestor_of(collider)):
		return true
	if _has_los_ignore_meta(collider):
		return true
	return false

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

func _collision_exclusion_rids(actor: Node3D) -> Array[RID]:
	var excluded: Array[RID] = []
	for root in [actor, self]:
		if root == null:
			continue
		if root is CollisionObject3D:
			excluded.append((root as CollisionObject3D).get_rid())
		for node in root.find_children("*", "CollisionObject3D", true, false):
			var collision_object := node as CollisionObject3D
			if collision_object != null:
				excluded.append(collision_object.get_rid())
	return excluded

func _has_los_ignore_meta(node: Node) -> bool:
	var current := node
	while current != null:
		if current.has_meta("interaction_los_ignore") and bool(current.get_meta("interaction_los_ignore")):
			return true
		current = current.get_parent()
	return false

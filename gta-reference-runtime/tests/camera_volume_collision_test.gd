extends SceneTree

const CameraRigClass = preload("res://scripts/third_person_camera.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	root.name = "镜头体积碰撞测试场景"
	get_root().add_child(root)
	var player := CharacterBody3D.new()
	player.name = "测试玩家"
	root.add_child(player)
	var camera_rig := CameraRigClass.new()
	player.add_child(camera_rig)
	await process_frame
	camera_rig.set_follow_profile(4.0, 2.0)
	camera_rig.set_orbit(0.0, -15.0)
	camera_rig.pulse_feedback(0.35, 0.18, 18.0)
	await process_frame
	assert(absf(camera_rig.camera.rotation_degrees.z) > 0.001, "镜头反馈脉冲没有产生可见滚转")
	camera_rig.set_feedback_enabled(false)
	camera_rig.pulse_feedback(0.8, 0.18, 18.0)
	await process_frame
	assert(is_zero_approx(camera_rig.camera.rotation_degrees.z), "关闭镜头反馈后仍然保留滚转")
	assert(not camera_rig.last_collision, "空场景中的第三人称镜头不应误报碰撞")
	var unobstructed_position := camera_rig.camera.global_position

	# 将障碍物放在镜头中心线侧方：射线不会命中，但镜头球体会进入障碍物。
	var obstacle := StaticBody3D.new()
	obstacle.name = "侧方薄柱"
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(0.18, 0.18, 0.18)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	root.add_child(obstacle)
	obstacle.global_position = unobstructed_position + Vector3(0.2, 0.0, 0.0)
	await process_frame
	camera_rig.apply_look(Vector2.ZERO)
	assert(camera_rig.last_collision, "镜头球体进入侧方薄柱时没有触发体积碰撞")
	assert(camera_rig.camera.global_position.distance_to(unobstructed_position) > 0.01, "镜头体积碰撞后没有回退到安全位置")
	assert(camera_rig.last_collision_distance < camera_rig.distance, "镜头体积碰撞后没有更新安全距离")

	obstacle.queue_free()
	player.position = Vector3(0.0, 0.0, -2.0)
	camera_rig.apply_look(Vector2.ZERO)
	assert(not camera_rig.last_collision, "移开障碍物后镜头仍保留体积碰撞状态")
	assert(is_equal_approx(camera_rig.last_collision_distance, camera_rig.distance), "移开障碍物后镜头没有恢复完整距离")
	root.queue_free()
	await process_frame
	print("第三人称镜头体积碰撞回归测试通过")
	quit(0)

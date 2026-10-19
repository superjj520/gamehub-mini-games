extends SceneTree

## 只验证离屏视口是否能在当前渲染后端产生可读取像素。
## 不写入正式参考矩阵，也不改变视觉验收状态。

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var strict := OS.get_environment("OFFSCREEN_CAPTURE_STRICT").strip_edges() == "1"
	if DisplayServer.get_name().to_lower() == "headless":
		print("离屏 SubViewport 探针跳过：当前为无头渲染后端；请在可见窗口环境运行")
		quit(0)
		return
	var viewport := SubViewport.new()
	viewport.name = "离屏视口探针"
	viewport.size = Vector2i(64, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	get_root().add_child(viewport)

	var world := World3D.new()
	viewport.world_3d = world
	var root := Node3D.new()
	root.name = "探针场景"
	viewport.add_child(root)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.0, 4.0)
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	camera.current = true
	root.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	light.light_energy = 1.2
	root.add_child(light)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 1.4, 1.4)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e5b85f")
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

	await process_frame
	await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		print("离屏 SubViewport 当前不可用：渲染后端没有生成纹理；严格模式=%s" % strict)
		viewport.queue_free()
		quit(1 if strict else 0)
		return
	var image := texture.get_image()
	if image == null:
		print("离屏 SubViewport 当前不可用：纹理无法读取为图像；严格模式=%s" % strict)
		viewport.queue_free()
		quit(1 if strict else 0)
		return
	if image.get_width() != 64 or image.get_height() != 64:
		print("离屏 SubViewport 当前不可用：图像尺寸异常 %dx%d；严格模式=%s" % [image.get_width(), image.get_height(), strict])
		viewport.queue_free()
		quit(1 if strict else 0)
		return
	var center_pixel := image.get_pixel(32, 32)
	if center_pixel.get_luminance() <= 0.01:
		print("离屏 SubViewport 当前不可用：中心像素为空白；严格模式=%s" % strict)
		viewport.queue_free()
		quit(1 if strict else 0)
		return
	print("离屏 SubViewport 像素探针通过：%dx%d，中心像素亮度 %.3f" % [image.get_width(), image.get_height(), center_pixel.get_luminance()])
	viewport.queue_free()
	await process_frame
	quit(0)

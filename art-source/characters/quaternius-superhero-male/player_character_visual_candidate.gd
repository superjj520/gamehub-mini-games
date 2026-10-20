extends "res://assets/characters/quaternius-superhero-male/player_character_quaternius_candidate.gd"

## 城市玩家视觉候选 V4：对应城市参考帧的砖红外套、深色背包和低饱和反光细节，不进入正式运行时。

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("candidate_visual_only", true)
	set_meta("asset_source", "quaternius_cc0_base_project_original_city_outfit_wrapper")
	super._ready()

func _build_outfit() -> void:
	super._build_outfit()
	_retouch_silhouette()
	var backpack := find_child("候选主角背包", true, false) as MeshInstance3D
	if backpack != null:
		backpack.scale = Vector3(0.82, 0.86, 0.78)
		var pocket := MeshInstance3D.new()
		pocket.name = "原创背包前袋"
		var pocket_mesh := BoxMesh.new()
		pocket_mesh.size = Vector3(0.30, 0.16, 0.055)
		pocket_mesh.subdivide_width = 2
		pocket_mesh.subdivide_height = 2
		pocket_mesh.subdivide_depth = 2
		pocket.mesh = pocket_mesh
		pocket.position = Vector3(0.0, -0.08, 0.095)
		pocket.material_override = _visual_material(Color("244e67"), 0.62, 0.05)
		backpack.add_child(pocket)
		var reflective_strip := MeshInstance3D.new()
		reflective_strip.name = "原创背包反光条"
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = Vector3(0.24, 0.035, 0.022)
		reflective_strip.mesh = strip_mesh
		reflective_strip.position = Vector3(0.0, 0.075, 0.126)
		reflective_strip.material_override = _visual_material(Color("79b8c1"), 0.38, 0.02)
		backpack.add_child(reflective_strip)
	# 参考驾驶/店外镜头主要从角色背面观察；补一层朝向镜头的黑色背板，
	# 避免基础角色网格的冷色材质从背包轮廓中穿出。
	var rear_pack := MeshInstance3D.new()
	rear_pack.name = "原创背包后背板"
	var rear_pack_mesh := CapsuleMesh.new()
	rear_pack_mesh.radius = 0.24
	rear_pack_mesh.height = 0.68
	rear_pack.mesh = rear_pack_mesh
	rear_pack.position = Vector3(0.0, 1.18, 0.34)
	rear_pack.scale = Vector3(0.82, 0.84, 0.30)
	rear_pack.material_override = _visual_material(Color("151b20"), 0.82, 0.02)
	add_child(rear_pack)
	var rear_jacket := MeshInstance3D.new()
	rear_jacket.name = "原创夹克后背板"
	var rear_jacket_mesh := CapsuleMesh.new()
	rear_jacket_mesh.radius = 0.31
	rear_jacket_mesh.height = 0.84
	rear_jacket.mesh = rear_jacket_mesh
	rear_jacket.position = Vector3(0.0, 1.16, 0.27)
	rear_jacket.scale = Vector3(1.0, 1.0, 0.18)
	rear_jacket.material_override = _visual_material(Color("8f302c"), 0.70, 0.02)
	add_child(rear_jacket)
	# 由新的红夹克后背板和黑色背包承担参考镜头轮廓，隐藏基础背包的
	# 冷色外沿，避免与参考视频中的砖红外套发生颜色冲突。
	backpack.visible = false
	var flap := find_child("原创背包翻盖", true, false) as MeshInstance3D
	if flap != null:
		flap.scale = Vector3(0.84, 0.78, 0.76)
	assert(_recolor("候选主角身体", Color("8f302c"), 0.70, 0.02), "候选主角缺少视觉节点：候选主角身体")
	assert(_recolor("原创夹克肩部", Color("a83a34"), 0.70, 0.02), "候选主角缺少视觉节点：原创夹克肩部")
	assert(_recolor("原创夹克下摆", Color("6e2528"), 0.62, 0.02), "候选主角缺少视觉节点：原创夹克下摆")
	assert(_recolor("原创夹克腰带", Color("642125"), 0.70, 0.02), "候选主角缺少视觉节点：原创夹克腰带")
	assert(_recolor("原创左袖", Color("a83a34"), 0.70, 0.02), "候选主角缺少视觉节点：原创左袖")
	assert(_recolor("原创右袖", Color("a83a34"), 0.70, 0.02), "候选主角缺少视觉节点：原创右袖")
	assert(_recolor("原创衬衣前襟", Color("899493"), 0.78, 0.0), "候选主角缺少视觉节点：原创衬衣前襟")
	assert(_recolor("原创衬衣领口", Color("a9b2ad"), 0.78, 0.0), "候选主角缺少视觉节点：原创衬衣领口")
	assert(_recolor("候选主角背包", Color("151b20"), 0.82, 0.02), "候选主角缺少视觉节点：候选主角背包")
	assert(_recolor("原创背包翻盖", Color("222a2e"), 0.76, 0.02), "候选主角缺少视觉节点：原创背包翻盖")
	assert(_recolor("原创背包肩带左", Color("24383a"), 0.76, 0.02), "候选主角缺少视觉节点：原创背包肩带左")
	assert(_recolor("原创背包肩带右", Color("24383a"), 0.76, 0.02), "候选主角缺少视觉节点：原创背包肩带右")
	assert(_recolor("原创左裤腿", Color("182024"), 0.80, 0.02), "候选主角缺少视觉节点：原创左裤腿")
	assert(_recolor("原创右裤腿", Color("182024"), 0.80, 0.02), "候选主角缺少视觉节点：原创右裤腿")
	assert(_recolor("原创左鞋", Color("10151a"), 0.70, 0.05), "候选主角缺少视觉节点：原创左鞋")
	assert(_recolor("原创右鞋", Color("10151a"), 0.70, 0.05), "候选主角缺少视觉节点：原创右鞋")
	assert(_recolor("原创主角短发", Color("171a1d"), 0.86, 0.0), "候选主角缺少视觉节点：原创主角短发")
	assert(_recolor("原创胸牌", Color("b7944d"), 0.46, 0.16), "候选主角缺少视觉节点：原创胸牌")
	assert(_recolor("原创背包前袋", Color("24383a"), 0.76, 0.02), "候选主角缺少视觉节点：原创背包前袋")
	assert(_recolor("原创背包反光条", Color("b4ab7b"), 0.52, 0.02), "候选主角缺少视觉节点：原创背包反光条")
	# 服装候选 GLB 已经自带 Outfit_* 网格；在该资产存在时优先重绑其
	# 实际材质，否则运行时会继续显示基础冷色服装，覆盖上面的原创轮廓层。
	_recolor("Outfit_Torso", Color("8f302c"), 0.70, 0.02)
	_recolor("Outfit_ShoulderShell", Color("a83a34"), 0.70, 0.02)
	_recolor("Outfit_Sleeve_L", Color("a83a34"), 0.70, 0.02)
	_recolor("Outfit_Sleeve_R", Color("a83a34"), 0.70, 0.02)
	_recolor("Outfit_WaistTrim", Color("642125"), 0.70, 0.02)
	_recolor("Outfit_Backpack", Color("151b20"), 0.82, 0.02)
	_recolor("Outfit_BackpackFlap", Color("222a2e"), 0.76, 0.02)
	_recolor("Outfit_ShirtFront", Color("899493"), 0.78, 0.0)
	_recolor("Outfit_ShirtCollar", Color("a9b2ad"), 0.78, 0.0)
	_recolor("Outfit_Trousers_L", Color("182024"), 0.80, 0.02)
	_recolor("Outfit_Trousers_R", Color("182024"), 0.80, 0.02)
	_recolor("Outfit_Shoe_L", Color("10151a"), 0.70, 0.05)
	_recolor("Outfit_Shoe_R", Color("10151a"), 0.70, 0.05)
	_recolor("Outfit_Hair", Color("171a1d"), 0.86, 0.0)
	_recolor("Outfit_Badge", Color("b7944d"), 0.46, 0.16)

func _retouch_silhouette() -> void:
	# 只替换候选服装网格，不添加碰撞体；让主角从背面也保持完整的人形轮廓。
	_replace_with_capsule("候选主角身体", 0.32, 0.82, Vector3(0.0, 1.10, 0.0))
	_replace_with_capsule("原创夹克肩部", 0.34, 0.40, Vector3(0.0, 1.48, 0.0))
	_replace_with_capsule("原创左裤腿", 0.145, 0.74, Vector3(-0.16, 0.45, 0.0))
	_replace_with_capsule("原创右裤腿", 0.145, 0.74, Vector3(0.16, 0.45, 0.0))
	_add_round_visual("原创夹克侧片左", 0.105, 0.52, Vector3(-0.29, 1.10, 0.06), Color("8f302c"))
	_add_round_visual("原创夹克侧片右", 0.105, 0.52, Vector3(0.29, 1.10, 0.06), Color("8f302c"))
	_add_round_visual("原创左鞋帮", 0.145, 0.22, Vector3(-0.16, 0.19, 0.08), Color("10151a"))
	_add_round_visual("原创右鞋帮", 0.145, 0.22, Vector3(0.16, 0.19, 0.08), Color("10151a"))
	var left_shoe := find_child("原创左鞋", true, false) as MeshInstance3D
	var right_shoe := find_child("原创右鞋", true, false) as MeshInstance3D
	if left_shoe != null:
		left_shoe.position = Vector3(-0.16, 0.10, 0.08)
		left_shoe.scale = Vector3(1.0, 1.18, 1.08)
	if right_shoe != null:
		right_shoe.position = Vector3(0.16, 0.10, 0.08)
		right_shoe.scale = Vector3(1.0, 1.18, 1.08)

func _replace_with_capsule(node_name: String, radius: float, height: float, at: Vector3) -> void:
	var mesh_instance := find_child(node_name, true, false) as MeshInstance3D
	if mesh_instance == null:
		return
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh_instance.mesh = capsule
	mesh_instance.position = at

func _add_round_visual(node_name: String, radius: float, height: float, at: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	visual.mesh = capsule
	visual.position = at
	visual.material_override = _visual_material(color, 0.70, 0.02)
	add_child(visual)

func _visual_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _recolor(node_name: String, color: Color, roughness: float, metallic: float) -> bool:
	var mesh := find_child(node_name, true, false) as MeshInstance3D
	if mesh == null:
		return false
	mesh.material_override = _visual_material(color, roughness, metallic)
	return true

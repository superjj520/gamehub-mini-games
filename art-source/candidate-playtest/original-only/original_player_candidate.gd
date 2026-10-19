extends Node3D

## P0 主角原创程序化候选。
## 这是正式运行时的内部可玩视觉候选，不代表最终发布资产。

var _animation_player: AnimationPlayer
var _state := "idle_default"
var _ground_contact_shadows: Array[MeshInstance3D] = []

func _ready() -> void:
	set_meta("original_procedural_asset", true)
	set_meta("asset_source", "project_original_generated_code_and_node_materials")
	set_meta("reference_board", "art-source/characters/player-design/new-era-awakener-player-turnaround-v1-generated.png")
	set_meta("visual_direction", "原创写实_中等细节")
	_build_visual()
	_build_mount_points()
	_build_ground_contact_shadows()
	_build_animation_library()

func _build_visual() -> void:
	var jacket := Color("343b40")
	var jacket_highlight := Color("596268")
	var skin := Color("b27d69")
	var hair := Color("24272a")
	var backpack := Color("20272b")
	var backpack_trim := Color("5f6a6f")
	var shirt := Color("7f403e")
	var shirt_edge := Color("b1aaa1")
	var pants := Color("24282d")
	var sole := Color("101316")

	_add_scaled_capsule("候选主角身体", 0.34, 0.92, Vector3(0.0, 1.10, 0.0), shirt, Vector3(0.96, 1.0, 0.70))
	_add_box("候选主角马甲前片", Vector3(0.42, 0.58, 0.07), Vector3(0.0, 1.12, -0.205), jacket, 0.045)
	_add_box("候选主角马甲后片", Vector3(0.44, 0.54, 0.06), Vector3(0.0, 1.12, 0.205), jacket, 0.04)
	_add_box("候选主角夹克下摆", Vector3(0.54, 0.18, 0.34), Vector3(0.0, 0.76, 0.0), jacket_highlight, 0.06)
	_add_box("候选主角衬衣", Vector3(0.24, 0.44, 0.05), Vector3(0.0, 1.15, -0.22), shirt, 0.02)
	_add_box("候选主角衬衣领口", Vector3(0.32, 0.08, 0.06), Vector3(0.0, 1.48, -0.215), shirt_edge, 0.018)
	_add_box("候选主角内层拉链", Vector3(0.025, 0.30, 0.018), Vector3(0.0, 1.22, -0.252), shirt_edge, 0.006)
	_add_box("候选主角腰带", Vector3(0.52, 0.075, 0.40), Vector3(0.0, 0.78, 0.0), jacket, 0.02)
	_add_box("候选主角背包", Vector3(0.36, 0.52, 0.12), Vector3(0.0, 1.13, 0.25), backpack, 0.08)
	_add_box("候选主角背包翻盖", Vector3(0.32, 0.10, 0.14), Vector3(0.0, 1.40, 0.21), backpack_trim, 0.04)
	_add_box("候选主角背包底部", Vector3(0.30, 0.07, 0.14), Vector3(0.0, 0.88, 0.22), backpack_trim, 0.025)
	_add_box("候选主角背包肩带-左", Vector3(0.055, 0.48, 0.035), Vector3(-0.20, 1.18, 0.20), backpack_trim, 0.012)
	_add_box("候选主角背包肩带-右", Vector3(0.055, 0.48, 0.035), Vector3(0.20, 1.18, 0.20), backpack_trim, 0.012)
	_add_box("候选主角连帽外圈", Vector3(0.62, 0.16, 0.38), Vector3(0.0, 1.57, 0.16), jacket, 0.06)
	_add_box("候选主角连帽内衬", Vector3(0.46, 0.08, 0.28), Vector3(0.0, 1.58, 0.12), jacket_highlight, 0.035)
	_add_box("候选主角肩部拼接-左", Vector3(0.20, 0.055, 0.18), Vector3(-0.29, 1.43, 0.01), jacket_highlight, 0.018)
	_add_box("候选主角肩部拼接-右", Vector3(0.20, 0.055, 0.18), Vector3(0.29, 1.43, 0.01), jacket_highlight, 0.018)
	_add_box("候选主角袖口-左", Vector3(0.14, 0.09, 0.16), Vector3(-0.49, 0.69, -0.01), jacket, 0.025)
	_add_box("候选主角袖口-右", Vector3(0.14, 0.09, 0.16), Vector3(0.49, 0.69, -0.01), jacket, 0.025)
	_add_box("候选主角背包侧袋-左", Vector3(0.10, 0.24, 0.14), Vector3(-0.24, 1.06, 0.29), backpack, 0.025)
	_add_box("候选主角背包侧袋-右", Vector3(0.10, 0.24, 0.14), Vector3(0.24, 1.06, 0.29), backpack, 0.025)
	_add_box("候选主角背包扣带-左", Vector3(0.045, 0.08, 0.03), Vector3(-0.14, 1.27, 0.285), backpack_trim, 0.008)
	_add_box("候选主角背包扣带-右", Vector3(0.045, 0.08, 0.03), Vector3(0.14, 1.27, 0.285), backpack_trim, 0.008)
	_add_cylinder("候选主角颈部", Vector3(0.0, 1.56, 0.0), 0.10, 0.15, skin)
	_add_sphere("候选主角头部", Vector3(0.0, 1.76, 0.0), 0.205, skin, Vector3(0.92, 1.0, 0.88))
	_add_sphere("候选主角头发", Vector3(0.0, 1.91, 0.0), 0.215, hair, Vector3(1.0, 0.38, 0.94))
	_add_sphere("候选主角耳朵-左", Vector3(-0.195, 1.76, 0.0), 0.048, skin, Vector3(1.0, 1.0, 0.72))
	_add_sphere("候选主角耳朵-右", Vector3(0.195, 1.76, 0.0), 0.048, skin, Vector3(1.0, 1.0, 0.72))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_add_capsule("候选主角上臂" + suffix, Vector3(side * 0.37, 1.00, 0.0), 0.075, 0.36, jacket, Vector3(0.0, 0.0, side * -10.0))
		_add_capsule("候选主角前臂" + suffix, Vector3(side * 0.49, 0.84, -0.015), 0.065, 0.30, jacket_highlight, Vector3(0.0, 0.0, side * -24.0))
		_add_sphere("候选主角手部" + suffix, Vector3(side * 0.59, 0.70, -0.03), 0.085, skin, Vector3(1.0, 0.86, 0.9))
		_add_capsule("候选主角腿部" + suffix, Vector3(side * 0.15, 0.46, 0.0), 0.10, 0.62, pants, Vector3.ZERO)
		_add_box("候选主角工装袋" + suffix, Vector3(0.18, 0.18, 0.08), Vector3(side * 0.23, 0.48, -0.08), pants, 0.025)
		_add_box("候选主角膝部拼接" + suffix, Vector3(0.16, 0.08, 0.08), Vector3(side * 0.15, 0.36, -0.105), jacket_highlight, 0.018)
		_add_box("候选主角鞋子" + suffix, Vector3(0.22, 0.13, 0.36), Vector3(side * 0.15, 0.11, -0.08), sole, 0.05)
		_add_box("候选主角鞋面侧条" + suffix, Vector3(0.20, 0.055, 0.06), Vector3(side * 0.15, 0.16, -0.25), jacket_highlight, 0.015)
		_add_box("候选主角鞋底" + suffix, Vector3(0.24, 0.04, 0.38), Vector3(side * 0.15, 0.035, -0.08), Color("333b43"), 0.015)
	_add_box("候选主角工牌", Vector3(0.10, 0.14, 0.025), Vector3(0.0, 1.28, -0.255), Color("d8b66a"), 0.01)
	_add_box("候选主角工牌挂绳", Vector3(0.025, 0.20, 0.02), Vector3(0.0, 1.42, -0.245), Color("5a6672"), 0.006)
	_add_sphere("候选主角鼻梁", Vector3(0.0, 1.76, -0.218), 0.035, skin, Vector3(0.72, 0.8, 1.2))
	_add_sphere("候选主角眼睛-左", Vector3(-0.078, 1.80, -0.202), 0.018, Color("14191e"), Vector3(1.0, 0.75, 0.55))
	_add_sphere("候选主角眼睛-右", Vector3(0.078, 1.80, -0.202), 0.018, Color("14191e"), Vector3(1.0, 0.75, 0.55))
	_build_surface_details()

func _build_surface_details() -> void:
	# 这一层只增加原创表面信息，不改变碰撞体、挂点或状态机。
	# 目标是让中近景能读出服装结构，而不是继续堆叠无意义的几何体。
	var seam := Color("1f2529")
	var metal := Color("b89a68")
	var hair := Color("1b1e21")
	var skin_shadow := Color("9b685a")
	var jacket_detail := Color("6b757a")

	_add_box("候选主角夹克前襟-左", Vector3(0.018, 0.40, 0.014), Vector3(-0.20, 1.15, -0.247), seam, 0.004)
	_add_box("候选主角夹克前襟-右", Vector3(0.018, 0.40, 0.014), Vector3(0.20, 1.15, -0.247), seam, 0.004)
	_add_box("候选主角拉链头", Vector3(0.052, 0.072, 0.030), Vector3(0.0, 1.04, -0.266), metal, 0.010)
	_add_box("候选主角胸袋-左", Vector3(0.15, 0.045, 0.032), Vector3(-0.22, 1.30, -0.244), jacket_detail, 0.010)
	_add_box("候选主角胸袋-右", Vector3(0.15, 0.045, 0.032), Vector3(0.22, 1.30, -0.244), jacket_detail, 0.010)
	_add_box("候选主角下摆口袋-左", Vector3(0.18, 0.075, 0.042), Vector3(-0.22, 0.91, -0.226), jacket_detail, 0.014)
	_add_box("候选主角下摆口袋-右", Vector3(0.18, 0.075, 0.042), Vector3(0.22, 0.91, -0.226), jacket_detail, 0.014)
	_add_box("候选主角连帽抽绳-左", Vector3(0.018, 0.18, 0.018), Vector3(-0.105, 1.49, -0.235), metal, 0.006)
	_add_box("候选主角连帽抽绳-右", Vector3(0.018, 0.18, 0.018), Vector3(0.105, 1.49, -0.235), metal, 0.006)
	_add_box("候选主角背包中央扣", Vector3(0.09, 0.065, 0.035), Vector3(0.0, 1.22, 0.326), metal, 0.012)
	_add_box("候选主角背包底部缝线", Vector3(0.26, 0.018, 0.018), Vector3(0.0, 0.90, 0.296), seam, 0.004)
	_add_box("候选主角眉毛-左", Vector3(0.10, 0.022, 0.024), Vector3(-0.078, 1.842, -0.221), hair, 0.008)
	_add_box("候选主角眉毛-右", Vector3(0.10, 0.022, 0.024), Vector3(0.078, 1.842, -0.221), hair, 0.008)
	_add_box("候选主角嘴部", Vector3(0.10, 0.018, 0.018), Vector3(0.0, 1.67, -0.214), Color("743d3c"), 0.005)
	_add_sphere("候选主角下巴", Vector3(0.0, 1.68, -0.175), 0.082, skin_shadow, Vector3(0.95, 0.58, 0.62))
	_add_sphere("候选主角额前发束-左", Vector3(-0.092, 1.93, -0.145), 0.10, hair, Vector3(0.58, 0.72, 0.95))
	_add_sphere("候选主角额前发束-右", Vector3(0.092, 1.93, -0.145), 0.10, hair, Vector3(0.58, 0.72, 0.95))
	_add_sphere("候选主角额前碎发", Vector3(0.0, 1.96, -0.14), 0.09, hair, Vector3(0.46, 0.62, 0.84))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_add_box("候选主角鞋带上" + suffix, Vector3(0.17, 0.018, 0.026), Vector3(side * 0.15, 0.17, -0.265), metal, 0.006)
		_add_box("候选主角鞋带下" + suffix, Vector3(0.16, 0.018, 0.026), Vector3(side * 0.15, 0.14, -0.273), metal, 0.006)

func _build_mount_points() -> void:
	var mounts := {
		"交互手部挂点": Vector3(0.0, 0.78, -0.28),
		"载具挂点": Vector3(0.0, 0.92, 0.30),
		"视线起点": Vector3(0.0, 1.78, -0.12),
		"脚底碰撞参考点": Vector3(0.0, 0.04, 0.0)
	}
	for mount_name in mounts:
		var marker := Marker3D.new()
		marker.name = mount_name
		marker.position = mounts[mount_name]
		add_child(marker)

func _build_ground_contact_shadows() -> void:
	# 接地阴影只表达人物与地面的视觉接触，不创建碰撞、导航或任务逻辑。
	var shadow_material := _soft_shadow_material()
	for side in [-1.0, 1.0]:
		var suffix := "左" if side < 0.0 else "右"
		var shadow := MeshInstance3D.new()
		shadow.name = "候选主角" + suffix + "脚软接触阴影"
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.28, 0.42)
		shadow.mesh = mesh
		shadow.position = Vector3(side * 0.15, 0.018, -0.08)
		shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		shadow.material_override = shadow_material.duplicate()
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		shadow.set_meta("visual_only", true)
		shadow.set_meta("candidate_visual_only", true)
		shadow.set_meta("ground_contact_visual", true)
		shadow.set_meta("original_procedural_asset", true)
		add_child(shadow)
		_ground_contact_shadows.append(shadow)

func _soft_shadow_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.015, 0.019, 0.022, 0.30),
		Color(0.015, 0.019, 0.022, 0.0),
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 64
	gradient_texture.height = 64
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = gradient_texture
	material.albedo_color = Color.WHITE
	return material

func _build_animation_library() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ["idle_default", "walk_default", "crouch_default", "interact_default", "vehicle_default", "hit_default", "fail_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if animation_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		library.add_animation(animation_name, animation)
	_add_animation_track(library.get_animation("idle_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 1.0, 0.0))
	_add_animation_track(library.get_animation("walk_default"), "候选主角上臂-左:rotation_degrees", Vector3(0.0, 0.0, -10.0), Vector3(0.0, 0.0, 18.0))
	_add_animation_track(library.get_animation("walk_default"), "候选主角上臂-右:rotation_degrees", Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -18.0))
	_add_animation_track(library.get_animation("interact_default"), "候选主角前臂-右:rotation_degrees", Vector3(0.0, 0.0, -24.0), Vector3(-28.0, 0.0, -6.0))
	_add_animation_track(library.get_animation("vehicle_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, 8.0, 0.0))
	_add_animation_track(library.get_animation("hit_default"), "候选主角头部:rotation_degrees", Vector3.ZERO, Vector3(0.0, -12.0, 0.0))
	_add_animation_track(library.get_animation("crouch_default"), "候选主角身体:position", Vector3(0.0, 1.10, 0.0), Vector3(0.0, 0.92, 0.0))
	_add_animation_track(library.get_animation("fail_default"), "候选主角身体:rotation_degrees", Vector3.ZERO, Vector3(0.0, 0.0, -12.0))
	_animation_player.add_animation_library("", library)
	_animation_player.play("idle_default")

func drive_candidate_state(state_name: String) -> void:
	_state = state_name
	if _animation_player != null and _animation_player.has_animation(state_name):
		_animation_player.play(state_name)
	_apply_state_pose()

func _apply_state_pose() -> void:
	var body := get_node_or_null("候选主角身体") as Node3D
	if body == null:
		return
	var crouched := _state == "crouch_default"
	body.position.y = -0.75 if _state == "vehicle_default" else (0.92 if crouched else 1.10)
	body.position.z = -0.65 if _state == "vehicle_default" else 0.0
	# 参考帧中的蹲伏不是单纯的整体缩放：背包、头部、手臂和腿都要
	# 同步降低并略微前倾，才能在偏肩近景里保持完整的人体轮廓。
	_pose_node("候选主角马甲前片", Vector3(0.0, 1.12, -0.205), Vector3(0.0, 0.94, -0.235), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角马甲后片", Vector3(0.0, 1.12, 0.205), Vector3(0.0, 0.94, 0.225), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角夹克下摆", Vector3(0.0, 0.76, 0.0), Vector3(0.0, 0.64, -0.01), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角衬衣", Vector3(0.0, 1.15, -0.22), Vector3(0.0, 0.97, -0.25), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角衬衣领口", Vector3(0.0, 1.48, -0.215), Vector3(0.0, 1.29, -0.235), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角内层拉链", Vector3(0.0, 1.22, -0.252), Vector3(0.0, 1.04, -0.275), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角腰带", Vector3(0.0, 0.78, 0.0), Vector3(0.0, 0.66, -0.01), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包", Vector3(0.0, 1.13, 0.25), Vector3(0.0, 0.97, 0.27), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包翻盖", Vector3(0.0, 1.40, 0.21), Vector3(0.0, 1.22, 0.23), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包底部", Vector3(0.0, 0.88, 0.22), Vector3(0.0, 0.76, 0.24), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包肩带-左", Vector3(-0.20, 1.18, 0.20), Vector3(-0.20, 1.02, 0.22), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包肩带-右", Vector3(0.20, 1.18, 0.20), Vector3(0.20, 1.02, 0.22), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角连帽外圈", Vector3(0.0, 1.57, 0.16), Vector3(0.0, 1.38, 0.18), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角连帽内衬", Vector3(0.0, 1.58, 0.12), Vector3(0.0, 1.39, 0.14), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角肩部拼接-左", Vector3(-0.29, 1.43, 0.01), Vector3(-0.29, 1.25, -0.03), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角肩部拼接-右", Vector3(0.29, 1.43, 0.01), Vector3(0.29, 1.25, -0.03), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角袖口-左", Vector3(-0.49, 0.69, -0.01), Vector3(-0.49, 0.57, -0.12), Vector3.ZERO, Vector3(0.0, 0.0, -34.0))
	_pose_node("候选主角袖口-右", Vector3(0.49, 0.69, -0.01), Vector3(0.49, 0.57, -0.12), Vector3.ZERO, Vector3(0.0, 0.0, 34.0))
	_pose_node("候选主角背包侧袋-左", Vector3(-0.24, 1.06, 0.29), Vector3(-0.24, 0.90, 0.31), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包侧袋-右", Vector3(0.24, 1.06, 0.29), Vector3(0.24, 0.90, 0.31), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包扣带-左", Vector3(-0.14, 1.27, 0.285), Vector3(-0.14, 1.11, 0.305), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包扣带-右", Vector3(0.14, 1.27, 0.285), Vector3(0.14, 1.11, 0.305), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角颈部", Vector3(0.0, 1.56, 0.0), Vector3(0.0, 1.37, -0.03), Vector3.ZERO, Vector3.ZERO)
	_pose_node("候选主角头部", Vector3(0.0, 1.76, 0.0), Vector3(0.0, 1.54, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角头发", Vector3(0.0, 1.91, 0.0), Vector3(0.0, 1.69, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角耳朵-左", Vector3(-0.195, 1.76, 0.0), Vector3(-0.195, 1.54, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角耳朵-右", Vector3(0.195, 1.76, 0.0), Vector3(0.195, 1.54, -0.055), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角鼻梁", Vector3(0.0, 1.76, -0.218), Vector3(0.0, 1.54, -0.273), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眼睛-左", Vector3(-0.078, 1.80, -0.202), Vector3(-0.078, 1.58, -0.257), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眼睛-右", Vector3(0.078, 1.80, -0.202), Vector3(0.078, 1.58, -0.257), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_pose_node("候选主角上臂" + suffix, Vector3(side * 0.37, 1.00, 0.0), Vector3(side * 0.37, 0.84, -0.045), Vector3(0.0, 0.0, side * -10.0), Vector3(0.0, 0.0, side * -18.0))
		_pose_node("候选主角前臂" + suffix, Vector3(side * 0.49, 0.84, -0.015), Vector3(side * 0.49, 0.69, -0.095), Vector3(0.0, 0.0, side * -24.0), Vector3(0.0, 0.0, side * -34.0))
		_pose_node("候选主角手部" + suffix, Vector3(side * 0.59, 0.70, -0.03), Vector3(side * 0.59, 0.58, -0.13), Vector3.ZERO, Vector3.ZERO)
		_pose_node("候选主角腿部" + suffix, Vector3(side * 0.15, 0.46, 0.0), Vector3(side * 0.15, 0.34, -0.035), Vector3.ZERO, Vector3(-18.0, 0.0, 0.0), Vector3.ONE, Vector3(1.0, 0.86, 1.0))
		_pose_node("候选主角工装袋" + suffix, Vector3(side * 0.23, 0.48, -0.08), Vector3(side * 0.23, 0.36, -0.12), Vector3.ZERO, Vector3(-18.0, 0.0, 0.0))
		_pose_node("候选主角膝部拼接" + suffix, Vector3(side * 0.15, 0.36, -0.105), Vector3(side * 0.15, 0.27, -0.14), Vector3.ZERO, Vector3(-18.0, 0.0, 0.0))
		_pose_node("候选主角鞋子" + suffix, Vector3(side * 0.15, 0.11, -0.08), Vector3(side * 0.15, 0.08, -0.18), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
		_pose_node("候选主角鞋面侧条" + suffix, Vector3(side * 0.15, 0.16, -0.25), Vector3(side * 0.15, 0.12, -0.34), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
		_pose_node("候选主角鞋底" + suffix, Vector3(side * 0.15, 0.035, -0.08), Vector3(side * 0.15, 0.02, -0.18), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
	_pose_node("候选主角工牌", Vector3(0.0, 1.28, -0.255), Vector3(0.0, 1.10, -0.29), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角工牌挂绳", Vector3(0.0, 1.42, -0.245), Vector3(0.0, 1.24, -0.27), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角夹克前襟-左", Vector3(-0.20, 1.15, -0.247), Vector3(-0.20, 0.97, -0.277), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角夹克前襟-右", Vector3(0.20, 1.15, -0.247), Vector3(0.20, 0.97, -0.277), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角拉链头", Vector3(0.0, 1.04, -0.266), Vector3(0.0, 0.86, -0.296), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角胸袋-左", Vector3(-0.22, 1.30, -0.244), Vector3(-0.22, 1.12, -0.274), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角胸袋-右", Vector3(0.22, 1.30, -0.244), Vector3(0.22, 1.12, -0.274), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角下摆口袋-左", Vector3(-0.22, 0.91, -0.226), Vector3(-0.22, 0.77, -0.256), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角下摆口袋-右", Vector3(0.22, 0.91, -0.226), Vector3(0.22, 0.77, -0.256), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角连帽抽绳-左", Vector3(-0.105, 1.49, -0.235), Vector3(-0.105, 1.31, -0.265), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角连帽抽绳-右", Vector3(0.105, 1.49, -0.235), Vector3(0.105, 1.31, -0.265), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包中央扣", Vector3(0.0, 1.22, 0.326), Vector3(0.0, 1.06, 0.346), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角背包底部缝线", Vector3(0.0, 0.90, 0.296), Vector3(0.0, 0.78, 0.316), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眉毛-左", Vector3(-0.078, 1.842, -0.221), Vector3(-0.078, 1.622, -0.276), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角眉毛-右", Vector3(0.078, 1.842, -0.221), Vector3(0.078, 1.622, -0.276), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角嘴部", Vector3(0.0, 1.67, -0.214), Vector3(0.0, 1.45, -0.269), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角下巴", Vector3(0.0, 1.68, -0.175), Vector3(0.0, 1.46, -0.23), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角额前发束-左", Vector3(-0.092, 1.93, -0.145), Vector3(-0.092, 1.71, -0.20), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角额前发束-右", Vector3(0.092, 1.93, -0.145), Vector3(0.092, 1.71, -0.20), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	_pose_node("候选主角额前碎发", Vector3(0.0, 1.96, -0.14), Vector3(0.0, 1.74, -0.195), Vector3.ZERO, Vector3(-8.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_pose_node("候选主角鞋带上" + suffix, Vector3(side * 0.15, 0.17, -0.265), Vector3(side * 0.15, 0.13, -0.365), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
		_pose_node("候选主角鞋带下" + suffix, Vector3(side * 0.15, 0.14, -0.273), Vector3(side * 0.15, 0.105, -0.373), Vector3.ZERO, Vector3(-12.0, 0.0, 0.0))
	if _state == "vehicle_default":
		_apply_vehicle_pose()
	_update_ground_contact_shadow_visibility()

func _update_ground_contact_shadow_visibility() -> void:
	for shadow in _ground_contact_shadows:
		if is_instance_valid(shadow):
			shadow.visible = _state != "vehicle_default"

func _apply_vehicle_pose() -> void:
	# 载具挂载点位于座椅上方；所有表现节点必须一起下沉并向车把
	# 前倾，否则只移动躯干会形成“站在车顶”的错误视觉。
	_set_vehicle_pose("候选主角身体", Vector3(0.0, -0.15, -0.32), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角马甲前片", Vector3(0.0, -0.15, -0.53), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角马甲后片", Vector3(0.0, -0.15, -0.12), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角夹克下摆", Vector3(0.0, -0.37, -0.30), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角衬衣", Vector3(0.0, -0.13, -0.55), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角衬衣领口", Vector3(0.0, 0.19, -0.52), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角内层拉链", Vector3(0.0, -0.05, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角腰带", Vector3(0.0, -0.37, -0.30), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包", Vector3(0.0, -0.13, 0.28), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包翻盖", Vector3(0.0, 0.15, 0.26), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包底部", Vector3(0.0, -0.37, 0.28), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包肩带-左", Vector3(-0.20, -0.07, 0.24), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包肩带-右", Vector3(0.20, -0.07, 0.24), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角连帽外圈", Vector3(0.0, 0.27, -0.22), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角连帽内衬", Vector3(0.0, 0.28, -0.26), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角肩部拼接-左", Vector3(-0.29, 0.13, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角肩部拼接-右", Vector3(0.29, 0.13, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角袖口-左", Vector3(-0.45, -0.52, -0.70), Vector3(-30.0, 0.0, -16.0))
	_set_vehicle_pose("候选主角袖口-右", Vector3(0.45, -0.52, -0.70), Vector3(-30.0, 0.0, 16.0))
	_set_vehicle_pose("候选主角背包侧袋-左", Vector3(-0.24, -0.07, 0.32), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包侧袋-右", Vector3(0.24, -0.07, 0.32), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包扣带-左", Vector3(-0.14, 0.14, 0.31), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包扣带-右", Vector3(0.14, 0.14, 0.31), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角颈部", Vector3(0.0, 0.25, -0.32), Vector3.ZERO)
	_set_vehicle_pose("候选主角头部", Vector3(0.0, 0.57, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角头发", Vector3(0.0, 0.74, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角耳朵-左", Vector3(-0.195, 0.57, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角耳朵-右", Vector3(0.195, 0.57, -0.38), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角鼻梁", Vector3(0.0, 0.57, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眼睛-左", Vector3(-0.078, 0.61, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眼睛-右", Vector3(0.078, 0.61, -0.58), Vector3(-8.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var suffix := "-左" if side < 0.0 else "-右"
		_set_vehicle_pose("候选主角上臂" + suffix, Vector3(side * 0.34, 0.29, -0.50), Vector3(-30.0, 0.0, side * -16.0))
		_set_vehicle_pose("候选主角前臂" + suffix, Vector3(side * 0.40, 0.14, -0.70), Vector3(-42.0, 0.0, side * -10.0))
		_set_vehicle_pose("候选主角手部" + suffix, Vector3(side * 0.42, 0.08, -0.86), Vector3.ZERO)
		_set_vehicle_pose("候选主角腿部" + suffix, Vector3(side * 0.18, -1.02, 0.02), Vector3(-72.0, 0.0, 0.0), Vector3(1.0, 0.88, 1.0))
		_set_vehicle_pose("候选主角工装袋" + suffix, Vector3(side * 0.20, -1.02, -0.12), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角膝部拼接" + suffix, Vector3(side * 0.18, -1.13, -0.18), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角鞋子" + suffix, Vector3(side * 0.20, -1.18, -0.30), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角鞋面侧条" + suffix, Vector3(side * 0.20, -1.24, -0.42), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角鞋底" + suffix, Vector3(side * 0.20, -1.22, -0.34), Vector3(-72.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角工牌", Vector3(0.0, 0.03, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角工牌挂绳", Vector3(0.0, 0.21, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角夹克前襟-左", Vector3(-0.20, -0.13, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角夹克前襟-右", Vector3(0.20, -0.13, -0.58), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角拉链头", Vector3(0.0, -0.32, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角胸袋-左", Vector3(-0.22, 0.15, -0.57), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角胸袋-右", Vector3(0.22, 0.15, -0.57), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角下摆口袋-左", Vector3(-0.22, -0.29, -0.55), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角下摆口袋-右", Vector3(0.22, -0.29, -0.55), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角连帽抽绳-左", Vector3(-0.105, 0.20, -0.56), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角连帽抽绳-右", Vector3(0.105, 0.20, -0.56), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包中央扣", Vector3(0.0, 0.13, 0.36), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角背包底部缝线", Vector3(0.0, -0.35, 0.34), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眉毛-左", Vector3(-0.078, 0.61, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角眉毛-右", Vector3(0.078, 0.61, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角嘴部", Vector3(0.0, 0.57, -0.60), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角下巴", Vector3(0.0, 0.47, -0.56), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角额前发束-左", Vector3(-0.092, 0.74, -0.52), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角额前发束-右", Vector3(0.092, 0.74, -0.52), Vector3(-8.0, 0.0, 0.0))
	_set_vehicle_pose("候选主角额前碎发", Vector3(0.0, 0.77, -0.52), Vector3(-8.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var detail_suffix := "-左" if side < 0.0 else "-右"
		_set_vehicle_pose("候选主角鞋带上" + detail_suffix, Vector3(side * 0.20, -1.30, -0.54), Vector3(-72.0, 0.0, 0.0))
		_set_vehicle_pose("候选主角鞋带下" + detail_suffix, Vector3(side * 0.20, -1.33, -0.55), Vector3(-72.0, 0.0, 0.0))

func _set_vehicle_pose(node_name: String, position: Vector3, rotation: Vector3, scale := Vector3.ONE) -> void:
	var node := get_node_or_null(node_name) as Node3D
	if node == null:
		return
	node.position = position
	node.rotation_degrees = rotation
	node.scale = scale

func _pose_node(node_name: String, standing_position: Vector3, crouch_position: Vector3, standing_rotation: Vector3, crouch_rotation: Vector3, standing_scale := Vector3.ONE, crouch_scale := Vector3.ONE) -> void:
	var node := get_node_or_null(node_name) as Node3D
	if node == null:
		return
	var crouched := _state == "crouch_default"
	node.position = crouch_position if crouched else standing_position
	node.rotation_degrees = crouch_rotation if crouched else standing_rotation
	node.scale = crouch_scale if crouched else standing_scale

func _add_animation_track(animation: Animation, property_path: String, first_value: Vector3, second_value: Vector3) -> void:
	if animation == null:
		return
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(property_path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, first_value)
	animation.track_insert_key(track, 0.5, second_value)
	animation.track_insert_key(track, 1.0, first_value)

func _material(color: Color, roughness: float = 0.68) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.set_meta("original_procedural_asset", true)
	return material

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color, bevel: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	if bevel > 0.0:
		mesh.subdivide_width = 2
		mesh.subdivide_height = 2
		mesh.subdivide_depth = 2
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	add_child(node)

func _add_sphere(node_name: String, at: Vector3, radius: float, color: Color, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	add_child(node)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	add_child(node)

func _add_capsule(node_name: String, at: Vector3, radius: float, height: float, color: Color, rotation: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	add_child(node)

func _add_scaled_capsule(node_name: String, radius: float, height: float, at: Vector3, color: Color, scale: Vector3) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = scale
	node.material_override = _material(color)
	node.set_meta("original_procedural_asset", true)
	add_child(node)

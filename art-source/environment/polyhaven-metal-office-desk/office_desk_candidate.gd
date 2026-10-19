extends Node3D

## 办公桌候选的运行时封装：视觉、近似碰撞和交互挂点。
## 不进入正式运行时；最终接入前仍需做精确碰撞和固定镜头验收。

func _ready() -> void:
	var visual := get_node_or_null("Geometry")
	if visual == null:
		return
	# 真实桌体承担桌面、抽屉和金属边缘的材质细节；组合场景只在其上补显示器、
	# 键盘、低隔断和椅子，避免把 office-10 重新降级成程序化盒体。
	visual.visible = true
	visual.set_meta("candidate_visual_only", true)
	visual.set_meta("asset_source", "polyhaven_metal_office_desk_1k")
	visual.set_meta("asset_license", "CC0-1.0")
	var interaction_mount := Marker3D.new()
	interaction_mount.name = "交互挂点"
	interaction_mount.position = Vector3(0.0, 0.86, -0.42)
	add_child(interaction_mount)
	var screen_mount := Marker3D.new()
	screen_mount.name = "显示器挂点"
	screen_mount.position = Vector3(0.0, 0.98, 0.0)
	add_child(screen_mount)
	var collision := CollisionShape3D.new()
	collision.name = "近似碰撞体"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.04, 0.82, 0.98)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.41, 0.0)
	add_child(collision)

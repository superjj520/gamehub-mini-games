extends Node3D

## 城市环境 P0 资产候选层。
## 组合当前原创场景细节与 Quaternius CC0 城市模型，仅用于隔离预览；
## 不提供碰撞、导航或任务状态，所有交互仍由原运行时灰盒负责。

const CANDIDATE_BUILDINGS := [
	{
		"name": "候选CC0小型城市楼",
		"path": "res://assets/environment/quaternius-downtown/b_small.glb",
		"scale": Vector3(0.34, 0.34, 0.34),
		"position": Vector3(8.3, 0.0, -8.6),
		"yaw": 180.0,
	},
	{
		"name": "候选CC0中型城市楼",
		"path": "res://assets/environment/quaternius-downtown/b_medium.glb",
		"scale": Vector3(0.24, 0.24, 0.24),
		"position": Vector3(12.2, 0.0, -3.8),
		"yaw": 90.0,
	},
	{
		"name": "候选CC0大型城市楼",
		"path": "res://assets/environment/quaternius-downtown/b_large.glb",
		"scale": Vector3(0.18, 0.18, 0.18),
		"position": Vector3(-12.6, 0.0, 4.6),
		"yaw": 0.0,
	},
]

func _ready() -> void:
	var procedural_details_scene := load("res://tests/city_environment_candidate.tscn") as PackedScene
	if procedural_details_scene != null:
		var procedural_details := procedural_details_scene.instantiate()
		procedural_details.name = "候选原创城市细节"
		add_child(procedural_details)
	else:
		push_warning("候选原创城市细节场景暂不可用；继续保留城市候选审阅入口")

	for building_spec in CANDIDATE_BUILDINGS:
		var building_scene := load(str(building_spec.get("path", ""))) as PackedScene
		if building_scene == null:
			push_warning("候选城市楼资源暂不可用：%s；跳过该楼体但不阻断正式运行时" % building_spec.get("path", ""))
			continue
		_add_building(
			str(building_spec.get("name", "候选城市楼")),
			building_scene,
			building_spec.get("scale", Vector3.ONE),
			building_spec.get("position", Vector3.ZERO),
			float(building_spec.get("yaw", 0.0)),
		)

	var air_conditioner_scene := load("res://assets/environment/quaternius-downtown/prop_ac.glb") as PackedScene
	if air_conditioner_scene == null:
		push_warning("候选CC0空调外机资源暂不可用；跳过该装饰但不阻断正式运行时")
		return
	var air_conditioner := air_conditioner_scene.instantiate()
	air_conditioner.name = "候选CC0空调外机"
	air_conditioner.position = Vector3(8.3, 3.0, -8.15)
	air_conditioner.scale = Vector3(1.4, 1.4, 1.4)
	add_child(air_conditioner)

func _add_building(node_name: String, scene: PackedScene, asset_scale: Vector3, at: Vector3, yaw: float) -> void:
	var building := scene.instantiate()
	building.name = node_name
	building.position = at
	building.rotation_degrees.y = yaw
	building.scale = asset_scale
	add_child(building)

extends SceneTree

const OfficeSceneVisualsClass = preload("res://scripts/office_scene_visuals.gd")
const CitySceneVisualsClass = preload("res://scripts/city_scene_visuals.gd")

var failures: Array[String] = []
var results: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for state_id in [
		"office-01", "office-02", "office-03", "office-04", "office-05",
		"office-06", "office-07", "office-08", "office-09", "office-10",
	]:
		await _probe_state(OfficeSceneVisualsClass.new(), state_id, "office")
	for state_id in [
		"city-01", "city-02", "city-03", "city-04", "city-05", "city-06",
		"city-07", "city-08", "city-09", "city-10", "city-11",
	]:
		await _probe_state(CitySceneVisualsClass.new(), state_id, "city")
	if not failures.is_empty():
		_write_evidence("failed")
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	_write_evidence("passed")
	print("场景视觉运行时完整性通过：%d/21 个状态生成可见原创表现层；视觉签收仍需当前源图形证据" % results.size())
	quit(0)

func _probe_state(visual_root: Node3D, state_id: String, scope: String) -> void:
	root.add_child(visual_root)
	if visual_root.has_method("apply_state"):
		visual_root.apply_state(state_id)
	await process_frame
	var state_root: Node3D = visual_root.get("state_root") as Node3D
	_require(state_root != null and is_instance_valid(state_root), "%s 缺少 Visual 根节点：%s" % [scope, state_id])
	if state_root == null or not is_instance_valid(state_root):
		visual_root.queue_free()
		await process_frame
		return
	_require(str(state_root.get_meta("%s_scene_state" % scope, "")) == state_id, "%s Visual 根节点状态标记错误：%s" % [scope, state_id])
	_require(bool(state_root.get_meta("visual_only", false)), "%s Visual 根节点没有 visual_only 标记：%s" % [scope, state_id])
	_require(bool(state_root.get_meta("candidate_visual_only", false)), "%s Visual 根节点没有 candidate_visual_only 标记：%s" % [scope, state_id])
	_require(bool(state_root.get_meta("original_procedural_asset", false)), "%s Visual 根节点没有原创资产标记：%s" % [scope, state_id])
	var contract: Dictionary = visual_root.get_meta("visual_state_contract", {}) as Dictionary
	_require(not contract.is_empty(), "%s 缺少视觉契约：%s" % [scope, state_id])
	_require(str(contract.get("state", "")) == state_id, "%s 视觉契约状态不匹配：%s" % [scope, state_id])
	var required_layers: Array = contract.get("required_layers", []) as Array
	_require(not required_layers.is_empty(), "%s 视觉契约没有 required_layers：%s" % [scope, state_id])
	var meshes := state_root.find_children("*", "MeshInstance3D", true, false)
	var visible_mesh_count := 0
	var backdrop_nodes: Array[Node] = []
	for mesh in meshes:
		if mesh is MeshInstance3D and (mesh as MeshInstance3D).visible:
			visible_mesh_count += 1
		if str(mesh.get_meta("backdrop_texture_path", "")).begins_with("res://"):
			backdrop_nodes.append(mesh)
		_require(bool(mesh.get_meta("visual_only", false)), "%s 状态出现未隔离 MeshInstance3D：%s/%s" % [scope, state_id, str(mesh.name)])
	_require(visible_mesh_count >= 3, "%s 状态可见表现层过少：%s，实际 %d 个 MeshInstance3D" % [scope, state_id, visible_mesh_count])
	_require(backdrop_nodes.size() == 1, "%s 状态必须恰好挂载 1 个原创候选环境稿：%s，实际 %d 个" % [scope, state_id, backdrop_nodes.size()])
	if backdrop_nodes.size() == 1:
		var backdrop := backdrop_nodes[0]
		var backdrop_path := str(backdrop.get_meta("backdrop_texture_path", ""))
		_require(ResourceLoader.exists(backdrop_path, "Texture2D"), "%s 状态环境稿资源不存在：%s/%s -> %s" % [scope, state_id, str(backdrop.name), backdrop_path])
		_require(bool(backdrop.get_meta("candidate_visual_only", false)), "%s 状态环境稿没有候选视觉隔离标记：%s" % [scope, state_id])
	var gameplay_nodes := state_root.find_children("*", "CollisionObject3D", true, false)
	_require(gameplay_nodes.is_empty(), "%s 状态视觉根混入碰撞/玩法节点：%s" % [scope, state_id])
	results.append({
		"id": state_id,
		"scope": scope,
		"visible_meshes": visible_mesh_count,
		"backdrop_texture_path": str(backdrop_nodes[0].get_meta("backdrop_texture_path", "")) if backdrop_nodes.size() == 1 else "",
		"required_layers": required_layers,
	})
	visual_root.queue_free()
	await process_frame

func _require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _write_evidence(status: String) -> void:
	var evidence_path := ProjectSettings.globalize_path("res://../reference-evidence/candidate-runtime/scene-visual-runtime-completeness.json")
	DirAccess.make_dir_recursive_absolute(evidence_path.get_base_dir())
	var file := FileAccess.open(evidence_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"status": status,
		"scope": "office-01..10 + city-01..11",
		"state_count": results.size(),
		"expected_state_count": 21,
		"results": results,
		"failures": failures,
		"visual_acceptance": "unverified",
		"release_allowed": false,
		"evidence_boundary": "runtime_structure_only_not_framewise_visual_signoff",
		"generated_at": Time.get_datetime_string_from_system(true),
	}, "\t") + "\n")

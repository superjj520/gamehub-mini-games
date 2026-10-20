extends SceneTree

## MakeHuman 候选人物的运行时状态接口验收。
## 该脚本只验证候选模型能够被统一状态驱动器控制，不代表视觉通过。

const AssetRuntimeCatalog = preload("res://scripts/asset_runtime_catalog.gd")
const STATES := ["idle_default", "walk_default", "search_default", "alert_default"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate_path := OS.get_environment("P0_CANDIDATE_GLB_PATH").strip_edges()
	if candidate_path.is_empty():
		push_error("缺少 P0_CANDIDATE_GLB_PATH")
		quit(1)
		return
	var packed := load(candidate_path) as PackedScene
	if packed == null:
		push_error("候选 GLB 无法作为 PackedScene 加载：" + candidate_path)
		quit(1)
		return

	var character := packed.instantiate()
	character.name = "MakeHumanOfficeWorker"
	get_root().add_child(character)
	var marker := Node3D.new()
	marker.name = "AnimationMarker"
	character.add_child(marker)
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	character.add_child(animation_player)
	var library := AnimationLibrary.new()
	for state_name in STATES:
		var animation := Animation.new()
		animation.length = 1.0
		animation.loop_mode = Animation.LOOP_LINEAR if state_name in ["idle_default", "walk_default"] else Animation.LOOP_NONE
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("AnimationMarker:rotation_degrees"))
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		animation.track_insert_key(track, 0.0, Vector3.ZERO)
		animation.track_insert_key(track, 0.5, Vector3(0.0, 9.0, 0.0))
		animation.track_insert_key(track, 1.0, Vector3.ZERO)
		library.add_animation(state_name, animation)
	animation_player.add_animation_library("", library)

	var report := {}
	var failed := false
	for state_name in STATES:
		marker.rotation_degrees = Vector3.ZERO
		var result: Dictionary = AssetRuntimeCatalog.drive_animation_state(character, state_name)
		animation_player.advance(0.25)
		var changed := not is_equal_approx(marker.rotation_degrees.y, 0.0)
		var driven := bool(result.get("driven", false))
		report[state_name] = {
			"driven": driven,
			"animation_player": bool(result.get("animation_player", false)),
			"current_animation": animation_player.current_animation,
			"marker_changed": changed
		}
		if not driven or not changed:
			failed = true

	var output_path := OS.get_environment("P0_ANIMATION_CONTRACT_OUTPUT").strip_edges()
	if output_path.is_empty():
		output_path = OS.get_temp_dir().path_join("makehuman-animation-contract.json")
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"candidate": candidate_path, "states": report}))
		file.close()
	print("MakeHuman 候选动画状态契约：", JSON.stringify(report))
	character.free()
	await process_frame
	quit(1 if failed else 0)

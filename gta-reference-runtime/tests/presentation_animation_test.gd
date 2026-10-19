extends SceneTree

const PlayerClass = preload("res://scripts/player_controller.gd")
const PedestrianClass = preload("res://scripts/city_pedestrian.gd")
const AssetRuntimeCatalogClass = preload("res://scripts/asset_runtime_catalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player: ReferencePlayer = PlayerClass.new()
	root.add_child(player)
	var visual := Node3D.new()
	visual.name = "Visual"
	player.add_child(visual)
	var animation_player := AnimationPlayer.new()
	visual.add_child(animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ["idle_default", "walk_default", "crouch_default", "interact_default", "vehicle_default", "hit_default", "fail_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		assert(library.add_animation(animation_name, animation) == OK, "动画夹具注册失败：" + animation_name)
	assert(animation_player.add_animation_library("", library) == OK, "动画夹具库挂载失败")

	player._update_presentation(0.016)
	assert(animation_player.current_animation == "idle_default", "站立状态没有驱动 idle_default")
	player.crouching = true
	player._update_presentation(0.016)
	assert(animation_player.current_animation == "crouch_default", "蹲伏状态没有驱动 crouch_default")
	player.crouching = false
	player.trigger_presentation_action("interact")
	player._update_presentation(0.016)
	assert(animation_player.current_animation == "interact_default", "交互状态没有驱动 interact_default")
	player.trigger_presentation_action("vehicle")
	player._update_presentation(0.016)
	assert(animation_player.current_animation == "vehicle_default", "载具状态没有驱动 vehicle_default")
	player.trigger_presentation_action("hit")
	player._update_presentation(0.016)
	assert(animation_player.current_animation == "hit_default", "受击状态没有驱动 hit_default")
	player.trigger_presentation_action("fail")
	player._update_presentation(0.016)
	assert(animation_player.current_animation == "fail_default", "失败状态没有驱动 fail_default")
	player.free()
	var pedestrian: CityPedestrian = PedestrianClass.new()
	root.add_child(pedestrian)
	var pedestrian_visual := Node3D.new()
	pedestrian_visual.name = "Visual"
	pedestrian.add_child(pedestrian_visual)
	var pedestrian_player := AnimationPlayer.new()
	pedestrian_visual.add_child(pedestrian_player)
	var pedestrian_library := AnimationLibrary.new()
	for animation_name in ["idle_default", "walk_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		assert(pedestrian_library.add_animation(animation_name, animation) == OK, "行人动画夹具注册失败：" + animation_name)
	assert(pedestrian_player.add_animation_library("", pedestrian_library) == OK, "行人动画夹具库挂载失败")
	pedestrian.waypoints = [Vector3(2.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0)]
	pedestrian._physics_process(0.1)
	assert(pedestrian_player.current_animation == "walk_default", "行人移动状态没有驱动 walk_default")
	pedestrian.prepare_reference_capture()
	assert(pedestrian_player.current_animation == "idle_default", "行人采集冻结没有驱动 idle_default")
	pedestrian.free()
	var npc_root := Node3D.new()
	root.add_child(npc_root)
	var npc_visual := Node3D.new()
	npc_root.add_child(npc_visual)
	var npc_player := AnimationPlayer.new()
	npc_visual.add_child(npc_player)
	var npc_library := AnimationLibrary.new()
	for animation_name in ["idle_default", "search_default", "alert_default", "displaced_default", "hit_default"]:
		var animation := Animation.new()
		animation.length = 1.0
		assert(npc_library.add_animation(animation_name, animation) == OK, "NPC 动画夹具注册失败：" + animation_name)
	assert(npc_player.add_animation_library("", npc_library) == OK, "NPC 动画夹具库挂载失败")
	assert(AssetRuntimeCatalogClass.drive_animation_state(npc_root, "search_default").get("driven", false), "NPC 搜索状态没有驱动动画")
	assert(npc_player.current_animation == "search_default", "NPC 搜索状态动画名错误")
	assert(AssetRuntimeCatalogClass.drive_animation_state(npc_root, "alert_default").get("driven", false), "NPC 警觉状态没有驱动动画")
	assert(npc_player.current_animation == "alert_default", "NPC 警觉状态动画名错误")
	assert(AssetRuntimeCatalogClass.drive_animation_state(npc_root, "displaced_default").get("driven", false), "人群位移状态没有驱动动画")
	assert(npc_player.current_animation == "displaced_default", "人群位移状态动画名错误")
	npc_root.free()
	print("角色表现动画状态桥接测试通过")
	quit(0)

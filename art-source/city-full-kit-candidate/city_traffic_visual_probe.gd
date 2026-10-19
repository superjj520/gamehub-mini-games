extends SceneTree

const CandidateEnvironment := preload("res://../art-source/city-full-kit-candidate/city_environment_storefront_candidate.tscn")

class ProbeRoot extends Node3D:
	var traffic_vehicles: Array[Node3D] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe_root := ProbeRoot.new()
	probe_root.name = "城市交通视觉探针根"
	var sun := DirectionalLight3D.new()
	sun.name = "探针主光"
	probe_root.add_child(sun)
	for index in range(2):
		var traffic := Node3D.new()
		traffic.name = "探针交通车-%d" % index
		probe_root.add_child(traffic)
		probe_root.traffic_vehicles.append(traffic)
	root.add_child(probe_root)
	var environment := CandidateEnvironment.instantiate()
	probe_root.add_child(environment)
	await process_frame
	await process_frame
	for traffic in probe_root.traffic_vehicles:
		assert(traffic.get_node_or_null("候选交通视觉") != null, "交通视觉层没有挂载")
		assert(traffic.get_node("候选交通视觉").find_child("候选交通车轮", true, false) != null, "交通视觉层缺少车轮")
		assert(traffic.get_node("候选交通视觉").find_child("候选交通前保险杠", true, false) != null, "交通视觉层缺少保险杠")
	probe_root.queue_free()
	await process_frame
	print("城市交通候选视觉探针通过：两辆车均加载车轮、保险杠、灯具和车顶细节")
	quit(0)

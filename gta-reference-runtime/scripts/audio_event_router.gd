class_name AudioEventRouter
extends Node

signal event_emitted(event_id: String, payload: Dictionary)
signal cue_played(event_id: String, category: String)

@export var enabled := false
@export var master_volume_db := -14.0

var history: Array[Dictionary] = []
var cue_catalog: Dictionary = {}
var audio_resource_catalog: Dictionary = {}
var active_players: Array[AudioStreamPlayer] = []
var configured_audio_catalog_path := ""

func _ready() -> void:
	_load_cue_catalog()
	_load_audio_resource_catalog()
	tree_exiting.connect(_dispose_all_audio_players)

func _exit_tree() -> void:
	# 场景可能在提示音自然结束前被重启或销毁；先停止并解除流引用，
	# 避免 AudioStreamGeneratorPlayback 在 Godot 进程退出时成为孤儿引用。
	_dispose_all_audio_players()

func emit_event(event_id: String, payload: Dictionary = {}) -> void:
	var event := {"id": event_id, "payload": payload}
	history.append(event)
	event_emitted.emit(event_id, payload)
	# 当前灰盒阶段不播放临时音效，避免把占位声音误当成参考还原结果。
	if not enabled:
		return
	_play_catalog_cue_or_fallback(event_id)

func clear() -> void:
	history.clear()

func silence() -> void:
	# 参考采集和场景销毁前必须主动停止真实播放，避免播放器或生成器回放
	# 在图形进程退出时仍被音频服务持有。
	enabled = false
	_dispose_all_audio_players()

func set_master_volume_db(value: float) -> void:
	master_volume_db = clampf(value, -40.0, 0.0)

func configure_for_asset_catalog(asset_catalog_path: String) -> void:
	# 启动器把资产目录通过 LaunchContext 传给场景；此时还没有可靠的进程级环境变量。
	# 原创边界候选必须同步切换到实际 WAV 清单，不能因为缺少环境变量而回到默认目录。
	if asset_catalog_path.strip_edges().ends_with("asset-runtime-catalog-original-only.json"):
		configured_audio_catalog_path = "res://content/audio-runtime-catalog-original-only.json"

func volume_snapshot() -> Dictionary:
	return {"master_volume_db": master_volume_db, "enabled": enabled}

func _play_procedural_cue(event_id: String) -> void:
	if not is_inside_tree():
		return
	var cue := _cue_for(event_id)
	if cue.is_empty():
		return
	var category := str(cue.get("category", "effects"))
	cue_played.emit(event_id, category)
	# 无头 Godot 没有可用的音频设备；创建 AudioStreamGeneratorPlayback 会在
	# 引擎退出时留下引用。无头测试仍保留事件和 cue_played 证据，真实音频只在
	# 有音频设备的运行时执行。
	if DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = float(cue.get("duration", 0.12))
	var player := AudioStreamPlayer.new()
	player.name = "程序化提示音-" + event_id
	player.stream = stream
	player.volume_db = master_volume_db
	add_child(player)
	_register_audio_player(player)
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		_dispose_audio_player(player)
		return
	var frame_count := int(stream.mix_rate * stream.buffer_length)
	var buffer := PackedVector2Array()
	buffer.resize(frame_count)
	var frequency := float(cue.get("frequency", 440.0))
	for index in range(frame_count):
		var progress := float(index) / maxf(1.0, float(frame_count - 1))
		var envelope := 1.0 - progress
		var sample := sin(TAU * frequency * float(index) / stream.mix_rate) * envelope * 0.18
		buffer[index] = Vector2(sample, sample)
	playback.push_buffer(buffer)
	get_tree().create_timer(stream.buffer_length + 0.2).timeout.connect(func(): _dispose_audio_player(player))

func _play_catalog_cue_or_fallback(event_id: String) -> void:
	var catalog_entry: Dictionary = audio_resource_catalog.get(event_id, {})
	var stream_path := str(catalog_entry.get("stream_path", ""))
	var fallback_policy := str(catalog_entry.get("fallback_policy", "procedural_graybox"))
	if stream_path.is_empty():
		if fallback_policy == "forbid":
			push_error("音频事件禁止回退且没有 stream_path：" + event_id)
			return
		_play_procedural_cue(event_id)
		return
	var stream = ResourceLoader.load(stream_path)
	if stream is AudioStream:
		_play_audio_stream(event_id, stream)
	elif fallback_policy == "forbid":
		push_error("音频事件禁止回退且资源无法加载：" + event_id + " / " + stream_path)
	else:
		_play_procedural_cue(event_id)

func _play_audio_stream(event_id: String, stream: AudioStream) -> void:
	if not is_inside_tree():
		return
	var cue := _cue_for(event_id)
	var category := str(cue.get("category", "effects"))
	cue_played.emit(event_id, category)
	var player := AudioStreamPlayer.new()
	player.name = "正式音频-" + event_id
	player.stream = stream
	player.volume_db = master_volume_db
	player.finished.connect(func(): _dispose_audio_player(player))
	add_child(player)
	_register_audio_player(player)
	player.play()

func _register_audio_player(player: AudioStreamPlayer) -> void:
	active_players.append(player)

func _dispose_all_audio_players() -> void:
	for player in active_players.duplicate():
		_dispose_audio_player(player)
	active_players.clear()

func _dispose_audio_player(player: AudioStreamPlayer) -> void:
	active_players.erase(player)
	if not is_instance_valid(player):
		return
	player.stop()
	player.stream = null
	player.free()

func _cue_for(event_id: String) -> Dictionary:
	return cue_catalog.get(event_id, {})

func _load_cue_catalog() -> void:
	var file := FileAccess.open("res://content/audio_cues.json", FileAccess.READ)
	if file == null:
		push_error("音频提示音清单无法读取")
		return
	var raw_text := file.get_as_text()
	file.close()
	file = null
	var payload = JSON.parse_string(raw_text)
	if not payload is Dictionary:
		push_error("音频提示音清单格式无效")
		return
	var errors := validate_cue_catalog(payload)
	if not errors.is_empty():
		push_error("音频提示音清单校验失败：" + ", ".join(errors))
		return
	for cue in payload["cues"]:
		if cue is Dictionary and not str(cue.get("id", "")).is_empty():
			cue_catalog[str(cue["id"])] = cue.duplicate(true)

func _load_audio_resource_catalog() -> void:
	var catalog_path := "res://content/audio-runtime-catalog.json"
	var requested_catalog_path := configured_audio_catalog_path.strip_edges()
	if requested_catalog_path.is_empty():
		requested_catalog_path = OS.get_environment("REFERENCE_AUDIO_CATALOG_PATH").strip_edges()
	if requested_catalog_path.is_empty():
		var asset_catalog_path := OS.get_environment("REFERENCE_ASSET_CATALOG_PATH").strip_edges()
		if asset_catalog_path.ends_with("asset-runtime-catalog-original-only.json"):
			requested_catalog_path = "res://content/audio-runtime-catalog-original-only.json"
	if not requested_catalog_path.is_empty():
		if not requested_catalog_path.begins_with("res://") or not ResourceLoader.exists(requested_catalog_path):
			push_error("指定的运行时音频目录不存在：" + requested_catalog_path)
			return
		catalog_path = requested_catalog_path
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null:
		push_error("运行时音频目录无法读取：" + catalog_path)
		return
	var raw_text := file.get_as_text()
	file.close()
	file = null
	var payload = JSON.parse_string(raw_text)
	if not payload is Dictionary:
		push_error("运行时音频目录格式无效")
		return
	var errors := validate_audio_resource_catalog(payload)
	if not errors.is_empty():
		push_error("运行时音频目录校验失败：" + ", ".join(errors))
		return
	for event in payload["events"]:
		if event is Dictionary and not str(event.get("id", "")).is_empty():
			audio_resource_catalog[str(event["id"])] = event.duplicate(true)

static func validate_audio_resource_catalog(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(payload.get("schema_version", 0)) != 1:
		errors.append("运行时音频目录 schema_version 必须为 1")
	var events = payload.get("events", [])
	if not events is Array or events.is_empty():
		errors.append("运行时音频目录缺少 events")
		return errors
	var identifiers: Dictionary = {}
	for index in range(events.size()):
		var event = events[index]
		if not event is Dictionary:
			errors.append("运行时音频事件 %d 不是对象" % index)
			continue
		var event_id := str(event.get("id", ""))
		if event_id.is_empty():
			errors.append("运行时音频事件 %d 缺少 id" % index)
		elif identifiers.has(event_id):
			errors.append("运行时音频事件 id 重复：" + event_id)
		else:
			identifiers[event_id] = true
		for required_field in ["stream_path", "fallback_policy"]:
			if not event.has(required_field):
				errors.append("运行时音频事件 %s 缺少字段：%s" % [event_id, required_field])
		var stream_path := str(event.get("stream_path", ""))
		if not stream_path.is_empty():
			if not stream_path.begins_with("res://"):
				errors.append("运行时音频事件 %s 的 stream_path 必须位于 res://" % event_id)
			elif not ResourceLoader.exists(stream_path):
				errors.append("运行时音频事件 %s 的 stream_path 不存在：%s" % [event_id, stream_path])
			else:
				var resource = ResourceLoader.load(stream_path)
				if not resource is AudioStream:
					errors.append("运行时音频事件 %s 的 stream_path 必须指向 AudioStream：%s" % [event_id, stream_path])
	return errors

static func validate_cue_catalog(payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for required_field in ["id", "version", "display_name", "cues"]:
		if not payload.has(required_field):
			errors.append("缺少字段：" + required_field)
	if int(payload.get("version", 0)) < 1:
		errors.append("版本必须是正整数")
	var cues = payload.get("cues", [])
	if not cues is Array or cues.is_empty():
		errors.append("提示音数组不能为空")
		return errors
	var cue_ids: Dictionary = {}
	for index in range(cues.size()):
		var cue = cues[index]
		if not cue is Dictionary:
			errors.append("提示音 %d 不是对象" % index)
			continue
		for required_field in ["id", "category", "frequency", "duration"]:
			if not cue.has(required_field):
				errors.append("提示音 %d 缺少字段：%s" % [index, required_field])
		var cue_id := str(cue.get("id", ""))
		if cue_id.is_empty():
			errors.append("提示音 %d 的 id 不能为空" % index)
		elif cue_ids.has(cue_id):
			errors.append("提示音 id 重复：" + cue_id)
		cue_ids[cue_id] = true
		if str(cue.get("category", "")).is_empty():
			errors.append("提示音类别不能为空：" + cue_id)
		var frequency := float(cue.get("frequency", -1.0))
		if frequency < 20.0 or frequency > 20000.0:
			errors.append("提示音频率超出范围：" + cue_id)
		var duration := float(cue.get("duration", -1.0))
		if duration <= 0.0 or duration > 3.0:
			errors.append("提示音时长超出范围：" + cue_id)
	return errors

static func validate_catalog_alignment(cue_payload: Dictionary, resource_payload: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var cue_ids: Dictionary = {}
	for cue in cue_payload.get("cues", []):
		if cue is Dictionary:
			var cue_id := str(cue.get("id", ""))
			if not cue_id.is_empty():
				cue_ids[cue_id] = true
	var resource_ids: Dictionary = {}
	for event in resource_payload.get("events", []):
		if event is Dictionary:
			var event_id := str(event.get("id", ""))
			if not event_id.is_empty():
				resource_ids[event_id] = true
	for cue_id in cue_ids:
		if not resource_ids.has(cue_id):
			errors.append("提示音没有运行时资源目录事件：" + str(cue_id))
	for event_id in resource_ids:
		if not cue_ids.has(event_id):
			errors.append("运行时音频事件没有提示音定义：" + str(event_id))
	return errors

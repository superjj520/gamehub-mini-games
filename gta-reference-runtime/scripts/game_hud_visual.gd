extends Control

## 运行时 HUD 表现层。
## 这里只消费场景已经计算好的状态，不拥有任务、交互或输入逻辑。

var hud_mode := "office"
var objective := ""
var clock_text := ""
var state_text := "进行中"
var awareness_text := ""
var suspicion_ratio := 0.0
var distance_text := ""
var prompt_text := ""
var money := 0
var wanted_stars := 0
var cargo_text := ""
var conflict_text := "平静"
var vehicle_text := ""
var life_ratio := 1.0
var stamina_ratio := 0.82
var radar_points: Array[Vector2] = [Vector2(0.0, 0.0)]
var radar_point_colors: Array[Color] = [Color("f3d47b")]
var radar_heading := 0.0
var escape_ratio := 0.0
var announcement_text := ""
var announcement_color := Color("f0e5c9")
var announcement_timer := 0.0
var feedback_timer := 0.0
var feedback_duration := 0.0
var feedback_strength := 0.0
var feedback_color := Color("e05252")
var accent := Color("e5b85f")
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _process(delta: float) -> void:
	if announcement_timer <= 0.0 and feedback_timer <= 0.0:
		return
	announcement_timer = maxf(announcement_timer - maxf(delta, 0.0), 0.0)
	feedback_timer = maxf(feedback_timer - maxf(delta, 0.0), 0.0)
	queue_redraw()

func announce(text: String, color := Color("f0e5c9"), duration := 2.2) -> void:
	announcement_text = text
	announcement_color = color
	announcement_timer = maxf(duration, 0.0)
	queue_redraw()

func clear_announcement() -> void:
	announcement_text = ""
	announcement_timer = 0.0
	queue_redraw()

func trigger_feedback(color := Color("e05252"), strength := 0.32, duration := 0.24) -> void:
	# 渐隐边缘反馈作为辅助层，不使用刺眼闪屏，也不替代横幅、音频和状态文字。
	feedback_color = color
	feedback_strength = clampf(float(strength), 0.0, 0.75)
	feedback_duration = maxf(float(duration), 0.05)
	feedback_timer = feedback_duration
	queue_redraw()

func apply_state(payload: Dictionary) -> void:
	hud_mode = str(payload.get("mode", hud_mode))
	objective = str(payload.get("objective", objective))
	clock_text = str(payload.get("clock", clock_text))
	state_text = str(payload.get("state", state_text))
	awareness_text = str(payload.get("awareness", awareness_text))
	suspicion_ratio = clampf(float(payload.get("suspicion_ratio", suspicion_ratio)), 0.0, 1.0)
	distance_text = str(payload.get("distance", distance_text))
	prompt_text = str(payload.get("prompt", prompt_text))
	money = int(payload.get("money", money))
	wanted_stars = clampi(int(payload.get("wanted_stars", wanted_stars)), 0, 5)
	cargo_text = str(payload.get("cargo", cargo_text))
	conflict_text = str(payload.get("conflict", conflict_text))
	vehicle_text = str(payload.get("vehicle", vehicle_text))
	life_ratio = clampf(float(payload.get("life_ratio", life_ratio)), 0.0, 1.0)
	stamina_ratio = clampf(float(payload.get("stamina_ratio", stamina_ratio)), 0.0, 1.0)
	escape_ratio = clampf(float(payload.get("escape_ratio", escape_ratio)), 0.0, 1.0)
	var next_points = payload.get("radar_points", radar_points)
	if next_points is Array:
		radar_points.clear()
		for point in next_points:
			if point is Vector2:
				radar_points.append(point)
	var next_colors = payload.get("radar_point_colors", radar_point_colors)
	if next_colors is Array:
		radar_point_colors.clear()
		for point_color in next_colors:
			if point_color is Color:
				radar_point_colors.append(point_color)
	if payload.has("radar_heading"):
		radar_heading = float(payload.get("radar_heading", radar_heading))
	accent = Color(str(payload.get("accent", "e5b85f")))
	queue_redraw()

func _draw() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	_draw_feedback_edge()
	if hud_mode == "city":
		_draw_city_reference_hud()
		return
	_draw_task_card()
	_draw_status_card()
	_draw_radar()
	_draw_bottom_prompts()

func _draw_feedback_edge() -> void:
	if feedback_timer <= 0.0 or feedback_duration <= 0.0 or feedback_strength <= 0.0:
		return
	var progress := clampf(feedback_timer / feedback_duration, 0.0, 1.0)
	var fade := progress * progress * (3.0 - 2.0 * progress)
	var edge_width := maxf(2.0, minf(14.0, size.y * 0.018))
	var edge_color := Color(feedback_color.r, feedback_color.g, feedback_color.b, feedback_strength * fade)
	draw_rect(Rect2(Vector2.ZERO, size), edge_color, false, edge_width)

func _draw_city_reference_hud() -> void:
	# 城市镜头沿用参考视频的极简 GTA 式 HUD：只保留左下导航/生命条、
	# 右上通缉标识和必要的即时提示，避免开发期任务卡覆盖街景主体。
	var scale_factor := minf(size.x / 480.0, size.y / 270.0)
	var origin := (size - Vector2(480.0, 270.0) * scale_factor) * 0.5
	var map_rect := Rect2(_city_point(origin, scale_factor, Vector2(7.0, 225.0)), Vector2(42.0, 31.0) * scale_factor)
	draw_rect(map_rect, Color(0.08, 0.10, 0.12, 0.82), true)
	draw_rect(map_rect, Color(0.53, 0.57, 0.56, 0.42), false, maxf(1.0, scale_factor))
	var map_center := map_rect.position + map_rect.size * 0.5
	draw_line(map_center + Vector2(-map_rect.size.x * 0.42, 0.0), map_center + Vector2(map_rect.size.x * 0.42, 0.0), Color(0.72, 0.76, 0.72, 0.42), maxf(1.0, scale_factor))
	draw_line(map_center + Vector2(0.0, -map_rect.size.y * 0.42), map_center + Vector2(0.0, map_rect.size.y * 0.42), Color(0.72, 0.76, 0.72, 0.42), maxf(1.0, scale_factor))
	var heading := Vector2.from_angle(radar_heading - PI * 0.5)
	draw_line(map_center, map_center + heading * map_rect.size.y * 0.36, Color("d8ded1"), maxf(1.0, scale_factor))
	for index in radar_points.size():
		var point: Vector2 = radar_points[index]
		var marker := map_center + Vector2(clampf(point.x, -1.0, 1.0), clampf(point.y, -1.0, 1.0)) * map_rect.size * 0.34
		var marker_color := Color("d6dcd0")
		if index < radar_point_colors.size():
			marker_color = radar_point_colors[index]
		draw_circle(marker, maxf(1.5, scale_factor * 1.4), marker_color)

	var health_icon := _city_point(origin, scale_factor, Vector2(8.0, 257.0))
	_draw_city_cross(health_icon, scale_factor, Color("e2e7dc"))
	var health_track := Rect2(_city_point(origin, scale_factor, Vector2(48.0, 256.0)), Vector2(55.0, 4.0) * scale_factor)
	draw_rect(health_track, Color(0.10, 0.13, 0.13, 0.88), true)
	var health_color := Color("76c88c") if life_ratio > 0.30 else Color("d85e59")
	draw_rect(Rect2(health_track.position, Vector2(health_track.size.x * life_ratio, health_track.size.y)), health_color, true)

	_draw_city_chip(origin, scale_factor, Vector2(378.0, 4.0), "现金  ¥%d" % money, Color("ffe5a8"), 95.0)
	var wanted_text := "通缉  " + "★".repeat(wanted_stars) + "☆".repeat(5 - wanted_stars)
	_draw_city_chip(origin, scale_factor, Vector2(378.0, 27.0), wanted_text, Color("f0c752") if wanted_stars == 0 else Color("e75c62"), 95.0)
	if state_text != "进行中" and not objective.is_empty():
		_draw_city_text(_city_point(origin, scale_factor, Vector2(240.0, 8.0)), "新任务：" + objective, 11, Color("f0e5c9"), scale_factor, HORIZONTAL_ALIGNMENT_CENTER, 220.0 * scale_factor)
	if announcement_timer > 0.0 and not announcement_text.is_empty():
		var banner_rect := Rect2(_city_point(origin, scale_factor, Vector2(135.0, 72.0)), Vector2(210.0, 30.0) * scale_factor)
		draw_rect(banner_rect, Color(0.04, 0.06, 0.08, 0.90), true)
		draw_rect(banner_rect, Color(announcement_color.r, announcement_color.g, announcement_color.b, 0.72), false, maxf(1.0, scale_factor))
		_draw_city_text(banner_rect.position + Vector2(10.0, 20.0) * scale_factor, announcement_text, 11, announcement_color, scale_factor, HORIZONTAL_ALIGNMENT_CENTER, 190.0 * scale_factor)
	if not vehicle_text.is_empty():
		_draw_city_chip(origin, scale_factor, Vector2(57.0, 225.0), "载具  " + vehicle_text, Color("a7d2df"), 112.0)
	if not cargo_text.is_empty():
		_draw_city_chip(origin, scale_factor, Vector2(57.0, 247.0), "货物  " + cargo_text, Color("d8e7d1"), 112.0)
	if not prompt_text.is_empty():
		var prompt_rect := Rect2(_city_point(origin, scale_factor, Vector2(300.0, 116.0)), Vector2(170.0, 25.0) * scale_factor)
		draw_rect(prompt_rect, Color(0.04, 0.06, 0.08, 0.90), true)
		draw_rect(prompt_rect, Color(0.73, 0.66, 0.43, 0.72), false, maxf(1.0, scale_factor))
		_draw_city_text(prompt_rect.position + Vector2(8.0, 17.0) * scale_factor, prompt_text, 11, Color("f0e5c9"), scale_factor, HORIZONTAL_ALIGNMENT_LEFT, 154.0 * scale_factor)
	if conflict_text != "平静":
		_draw_city_chip(origin, scale_factor, Vector2(346.0, 54.0), "冲突  " + conflict_text, Color("e05252"), 127.0)
	if escape_ratio > 0.0 and conflict_text != "平静":
		_draw_city_chip(origin, scale_factor, Vector2(346.0, 77.0), "甩开追踪  %d%%" % roundi(escape_ratio * 100.0), Color("f0c752"), 127.0)

func _city_point(origin: Vector2, scale_factor: float, point: Vector2) -> Vector2:
	return origin + point * scale_factor

func _draw_city_cross(center: Vector2, scale_factor: float, color: Color) -> void:
	var arm := 4.0 * scale_factor
	var thickness := maxf(1.5, 2.0 * scale_factor)
	draw_rect(Rect2(center - Vector2(thickness * 0.5, arm), Vector2(thickness, arm * 2.0)), color, true)
	draw_rect(Rect2(center - Vector2(arm, thickness * 0.5), Vector2(arm * 2.0, thickness)), color, true)

func _draw_city_text(position: Vector2, text: String, font_size: int, color: Color, scale_factor: float, alignment: HorizontalAlignment, width: float) -> void:
	draw_string(_font, position, text, alignment, width, maxi(14, int(float(font_size) * scale_factor)), color)

func _draw_city_chip(origin: Vector2, scale_factor: float, point: Vector2, text: String, color: Color, width: float) -> void:
	var rect := Rect2(_city_point(origin, scale_factor, point), Vector2(width, 18.0) * scale_factor)
	draw_rect(rect, Color(0.04, 0.06, 0.08, 0.88), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.48), false, maxf(1.0, scale_factor))
	draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), color, true)
	_draw_city_text(rect.position + Vector2(8.0, 13.0) * scale_factor, text, 10, color, scale_factor, HORIZONTAL_ALIGNMENT_LEFT, (width - 12.0) * scale_factor)

func _draw_task_card() -> void:
	var panel := Rect2(Vector2(24.0, 22.0), Vector2(minf(350.0, size.x * 0.42), 88.0))
	draw_rect(panel, Color(0.035, 0.055, 0.08, 0.86), true)
	draw_rect(Rect2(panel.position, Vector2(4.0, panel.size.y)), accent, true)
	draw_line(panel.position + Vector2(18.0, 26.0), panel.position + Vector2(panel.size.x - 18.0, 26.0), Color(1.0, 1.0, 1.0, 0.13), 1.0)
	_draw_text(panel.position + Vector2(18.0, 20.0), "当前目标", 12, Color("a6b6bf"))
	_draw_text(panel.position + Vector2(18.0, 52.0), objective if not objective.is_empty() else "等待任务", 19, Color("f1f4ee"))
	if not distance_text.is_empty():
		_draw_text(panel.position + Vector2(panel.size.x - 78.0, 52.0), distance_text, 14, Color("f3d47b"))
	var state_color := Color("b9d6c5")
	if state_text.contains("失败"):
		state_color = Color("e46a61")
	elif state_text.contains("完成") or state_text == "成功":
		state_color = Color("8fe0a2")
	_draw_text(panel.position + Vector2(18.0, 75.0), state_text, 12, state_color)
	if hud_mode == "office" and not awareness_text.is_empty():
		_draw_text(panel.position + Vector2(panel.size.x - 150.0, 75.0), awareness_text, 12, Color("e3c978"))

func _draw_status_card() -> void:
	var panel_width := 220.0 if hud_mode == "office" else 240.0
	var panel_height := 106.0 if hud_mode == "office" else 88.0
	var panel := Rect2(Vector2(size.x - panel_width - 24.0, 22.0), Vector2(panel_width, panel_height))
	draw_rect(panel, Color(0.035, 0.055, 0.08, 0.82), true)
	_draw_text(panel.position + Vector2(16.0, 25.0), clock_text if not clock_text.is_empty() else "17:59", 24, Color("f6f3e8"))
	if hud_mode == "city":
		_draw_text(panel.position + Vector2(16.0, 51.0), "现金  ¥%d" % money, 14, Color("ffe5a8"))
		var stars := "★".repeat(wanted_stars) + "☆".repeat(5 - wanted_stars)
		_draw_text(panel.position + Vector2(16.0, 74.0), "通缉  " + stars, 14, Color("f0c752"))
	else:
		_draw_text(panel.position + Vector2(16.0, 54.0), "现场状态", 12, Color("a6b6bf"))
		_draw_text(panel.position + Vector2(16.0, 77.0), awareness_text if not awareness_text.is_empty() else "未被发现", 14, Color("dce7dc"))
		var suspicion_color := Color("dce7dc")
		if suspicion_ratio >= 1.0:
			suspicion_color = Color("e05252")
		elif suspicion_ratio >= 0.35:
			suspicion_color = Color("f0c752")
		_draw_text(panel.position + Vector2(16.0, 99.0), "警觉  %d%%" % roundi(suspicion_ratio * 100.0), 11, suspicion_color)
		var suspicion_track := Rect2(panel.position + Vector2(86.0, 91.0), Vector2(panel.size.x - 102.0, 5.0))
		draw_rect(suspicion_track, Color(0.10, 0.13, 0.13, 0.90), true)
		draw_rect(Rect2(suspicion_track.position, Vector2(suspicion_track.size.x * suspicion_ratio, suspicion_track.size.y)), suspicion_color, true)
	_draw_text(panel.position + Vector2(panel.size.x - 96.0, 77.0), "觉醒者", 12, Color(1.0, 1.0, 1.0, 0.45))

func _draw_radar() -> void:
	var center := Vector2(120.0, size.y - 126.0)
	var radius := minf(78.0, maxf(58.0, size.y * 0.11))
	draw_circle(center, radius + 13.0, Color(0.02, 0.04, 0.06, 0.72))
	draw_circle(center, radius, Color(0.04, 0.13, 0.14, 0.92))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.62, 0.77, 0.69, 0.75), 2.0)
	draw_arc(center, radius * 0.68, 0.0, TAU, 64, Color(0.62, 0.77, 0.69, 0.22), 1.0)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), Color(0.62, 0.77, 0.69, 0.16), 1.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), Color(0.62, 0.77, 0.69, 0.16), 1.0)
	var heading := Vector2.from_angle(radar_heading - PI * 0.5)
	var left := Vector2.from_angle(radar_heading - PI * 0.5 - 0.23)
	var right := Vector2.from_angle(radar_heading - PI * 0.5 + 0.23)
	draw_colored_polygon(PackedVector2Array([center, center + left * radius * 0.78, center + right * radius * 0.78]), Color(accent.r, accent.g, accent.b, 0.18))
	draw_line(center, center + heading * radius * 0.66, accent, 2.0)
	for index in radar_points.size():
		var point: Vector2 = radar_points[index]
		var clamped := Vector2(clampf(point.x, -1.0, 1.0), clampf(point.y, -1.0, 1.0))
		var marker := center + Vector2(clamped.x, clamped.y) * radius * 0.78
		var marker_color := Color("f3d47b")
		if index < radar_point_colors.size():
			marker_color = radar_point_colors[index]
		draw_circle(marker, 4.0 if clamped.length() < 0.2 else 3.0, marker_color)
	draw_circle(center, 5.0, Color("e8f0d8"))
	_draw_text(center + Vector2(-radius, radius + 25.0), "雷达", 12, Color("a6b6bf"))

func _draw_bottom_prompts() -> void:
	var bar_origin := Vector2(224.0, size.y - 84.0)
	var bar_width := minf(220.0, size.x * 0.24)
	_draw_bar(bar_origin, bar_width, "生命", life_ratio, Color("db7064"))
	_draw_bar(bar_origin + Vector2(0.0, 24.0), bar_width, "体力", stamina_ratio, Color("7fbe82"))
	if hud_mode == "city" and not cargo_text.is_empty():
		_draw_text(bar_origin + Vector2(0.0, 66.0), "携带  " + cargo_text, 13, Color("d8e7d1"))
	if not prompt_text.is_empty():
		var prompt_width := minf(330.0, size.x * 0.34)
		var prompt_rect := Rect2(Vector2(size.x - prompt_width - 24.0, size.y - 72.0), Vector2(prompt_width, 42.0))
		draw_rect(prompt_rect, Color(0.04, 0.06, 0.08, 0.9), true)
		draw_rect(Rect2(prompt_rect.position, Vector2(4.0, prompt_rect.size.y)), accent, true)
		_draw_text(prompt_rect.position + Vector2(16.0, 27.0), prompt_text, 15, Color("f5e9c0"))

func _draw_bar(origin: Vector2, width: float, label: String, ratio: float, color: Color) -> void:
	_draw_text(origin, label, 12, Color("a6b6bf"))
	var track := Rect2(origin + Vector2(38.0, -11.0), Vector2(width - 38.0, 8.0))
	draw_rect(track, Color(0.02, 0.03, 0.04, 0.82), true)
	draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track.size.y)), color, true)

func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

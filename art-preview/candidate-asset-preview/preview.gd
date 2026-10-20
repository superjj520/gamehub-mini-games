extends Node3D

const NPC_SCENE := preload("res://assets/office_npc_atlas_candidate.glb")
const VEHICLE_SCENE := preload("res://assets/three_wheel_delivery_atlas_candidate.glb")
const RETOUCHED_NPC_SCENE := preload("res://assets/office_npc_retouch_candidate.tscn")
const DESK_SCENE := preload("res://assets/metal_office_desk_1k.glb")
const COMBINED_OUTPUT_PATH := "res://../../reference-evidence/candidate-runtime/office-vehicle-atlas-graphical-preview.png"
const OFFICE_OUTPUT_PATH := "res://../../reference-evidence/candidate-runtime/office-visual-supplement-preview.png"

var preview_profile := "office"

func _ready() -> void:
    preview_profile = OS.get_environment("CANDIDATE_PREVIEW_PROFILE").strip_edges()
    if preview_profile.is_empty():
        preview_profile = "office"
    _build_environment()
    _mount_candidates()
    _build_camera()
    _build_hud()
    var npc := get_node_or_null("办公室 NPC 图集返工候选")
    var vehicle := get_node_or_null("三轮配送车图集候选")
    if npc == null or _count_renderable_meshes(npc) == 0:
        push_error("办公室 NPC 图集候选没有可渲染网格")
        get_tree().quit(1)
        return
    if vehicle == null or _count_renderable_meshes(vehicle) == 0:
        push_error("三轮配送车图集候选没有可渲染网格")
        get_tree().quit(1)
        return
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    var viewport_texture := get_viewport().get_texture()
    if viewport_texture == null:
        push_error("候选资产预览没有可读视口纹理")
        get_tree().quit(1)
        return
    var image := viewport_texture.get_image()
    if image == null or image.is_empty():
        push_error("候选资产预览没有有效像素")
        get_tree().quit(1)
        return
    if _is_black_or_low_variance(image):
        push_error("候选资产预览像素接近黑屏或方差过低")
        get_tree().quit(1)
        return
    var relative_output_path := OFFICE_OUTPUT_PATH if preview_profile == "office" else COMBINED_OUTPUT_PATH
    var output_path := ProjectSettings.globalize_path(relative_output_path)
    var save_error := image.save_png(output_path)
    if save_error != OK or not FileAccess.file_exists(output_path):
        push_error("候选资产预览 PNG 写入失败：" + str(save_error))
        get_tree().quit(1)
        return
    print("候选资产图形预览已输出（", preview_profile, "）：", output_path)
    await get_tree().create_timer(0.2).timeout
    get_tree().quit()

func _build_environment() -> void:
    var environment := WorldEnvironment.new()
    var settings := Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color("1d2730")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("aeb9c2")
    settings.ambient_light_energy = 0.72
    settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    settings.tonemap_exposure = 1.08
    settings.ssao_enabled = true
    settings.ssao_radius = 1.4
    settings.ssao_intensity = 1.0
    environment.environment = settings
    add_child(environment)

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    key.light_color = Color("ffd3a0")
    key.light_energy = 1.15
    key.shadow_enabled = true
    add_child(key)
    var fill := OmniLight3D.new()
    fill.position = Vector3(0.0, 3.4, 3.8)
    fill.light_color = Color("9fc6e5")
    fill.light_energy = 4.0
    fill.omni_range = 12.0
    add_child(fill)
    var warm := OmniLight3D.new()
    warm.position = Vector3(-2.4, 2.6, -1.6)
    warm.light_color = Color("ffb875")
    warm.light_energy = 3.0
    warm.omni_range = 8.0
    add_child(warm)

    _add_box("地面", Vector3(12.0, 0.18, 10.0), Vector3(0.0, -0.09, 0.0), Color("343c40"), 0.82)
    _add_box("暖色地毯", Vector3(8.4, 0.025, 5.8), Vector3(0.0, 0.015, 0.75), Color("66554c"), 0.92)
    _add_box("后墙", Vector3(12.0, 4.4, 0.18), Vector3(0.0, 2.2, -3.6), Color("9b8f82"), 0.78)
    _add_box("左玻璃隔断", Vector3(0.12, 3.3, 5.6), Vector3(-5.3, 1.65, -0.1), Color("506b74"), 0.48)
    _add_box("右玻璃隔断", Vector3(0.12, 3.3, 5.6), Vector3(5.3, 1.65, -0.1), Color("506b74"), 0.48)
    var window_material := _material(Color("cfe4e8"), 0.18)
    window_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    window_material.albedo_color.a = 0.62
    _add_box("后墙落地窗", Vector3(8.4, 2.25, 0.045), Vector3(0.0, 2.3, -3.48), Color("cfe4e8"), 0.18, window_material)
    for x in [-4.2, -2.1, 0.0, 2.1, 4.2]:
        _add_box("落地窗竖框", Vector3(0.055, 2.35, 0.08), Vector3(x, 2.3, -3.43), Color("e0d4c1"), 0.42)
    for x in [-3.5, 0.0, 3.5]:
        _add_real_desk(Vector3(x, 0.0, -1.25), 0.0)
    for x in [-2.0, 2.0]:
        _add_real_desk(Vector3(x, 0.0, 2.35), 180.0)
    _add_wall_art()
    _add_plant(Vector3(-4.5, 0.0, -2.85))
    _add_ceiling_panels()

func _mount_candidates() -> void:
    var npc := RETOUCHED_NPC_SCENE.instantiate()
    npc.name = "办公室 NPC 图集返工候选"
    npc.set_meta("preserve_imported_materials", true)
    npc.set_meta("reference_office_materials", true)
    npc.set_meta("use_elegant_suit_skinned", true)
    npc.position = Vector3(1.05, 0.0, -0.45)
    npc.rotation_degrees = Vector3(0.0, 180.0, 0.0)
    npc.scale = Vector3(1.22, 1.22, 1.22)
    add_child(npc)

    var player := RETOUCHED_NPC_SCENE.instantiate()
    player.name = "办公室玩家返工候选"
    player.set_meta("preserve_imported_materials", true)
    player.set_meta("reference_office_materials", true)
    player.set_meta("use_elegant_suit_skinned", true)
    player.position = Vector3(-1.0, 0.0, 2.40) if preview_profile == "office" else Vector3(-0.72, 0.0, 1.35)
    player.rotation_degrees = Vector3(0.0, 180.0 if preview_profile == "office" else 0.0, 0.0)
    var player_scale := 1.62 if preview_profile == "office" else 1.42
    player.scale = Vector3(player_scale, player_scale, player_scale)
    add_child(player)

    var vehicle := VEHICLE_SCENE.instantiate()
    vehicle.name = "三轮配送车图集候选"
    vehicle.position = Vector3(4.25, 0.08, -1.65)
    vehicle.rotation_degrees = Vector3(0.0, -28.0, 0.0)
    vehicle.scale = Vector3(0.78, 0.78, 0.78)
    vehicle.visible = preview_profile != "office"
    add_child(vehicle)

func _build_camera() -> void:
    var camera := Camera3D.new()
    camera.position = Vector3(2.85, 2.35, 5.95) if preview_profile == "office" else Vector3(3.65, 2.45, 5.55)
    camera.fov = 58.0
    add_child(camera)
    var target := Vector3(-0.05, 1.38, 0.62) if preview_profile == "office" else Vector3(0.15, 1.25, 0.05)
    camera.look_at(target, Vector3.UP)
    camera.current = true

func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "办公室候选 HUD"
    add_child(canvas)
    var objective := Label.new()
    objective.text = "准点下班\n17:59 进行中\n未被发现"
    objective.position = Vector2(28.0, 24.0)
    objective.add_theme_font_size_override("font_size", 20)
    objective.add_theme_color_override("font_color", Color("f6f0df"))
    canvas.add_child(objective)
    var time := Label.new()
    time.text = "17:59"
    time.position = Vector2(1150.0, 24.0)
    time.add_theme_font_size_override("font_size", 20)
    time.add_theme_color_override("font_color", Color("f6f0df"))
    canvas.add_child(time)
    var status := Label.new()
    status.text = "生命  ████████\n体力  ██████"
    status.position = Vector2(28.0, 650.0)
    status.add_theme_font_size_override("font_size", 18)
    status.add_theme_color_override("font_color", Color("dbe6d6"))
    canvas.add_child(status)

func _add_real_desk(at: Vector3, yaw: float) -> void:
    var desk := DESK_SCENE.instantiate()
    desk.name = "PolyHaven真实办公桌候选"
    desk.position = at
    desk.rotation_degrees.y = yaw
    desk.scale = Vector3(0.86, 0.86, 0.86)
    add_child(desk)
    _add_box("显示器候选", Vector3(0.72, 0.48, 0.06), at + Vector3(0.0, 1.22, -0.05), Color("244c5d"), 0.30)
    _add_box("显示器支架候选", Vector3(0.06, 0.22, 0.06), at + Vector3(0.0, 0.96, -0.05), Color("202a2d"), 0.48)

func _add_wall_art() -> void:
    _add_box("办公室品牌墙", Vector3(2.2, 0.92, 0.045), Vector3(-2.6, 2.72, -3.47), Color("d8c3a9"), 0.55)
    _add_box("办公室品牌色带", Vector3(2.2, 0.10, 0.05), Vector3(-2.6, 3.13, -3.42), Color("bb604d"), 0.42)
    _add_box("公告栏", Vector3(1.65, 0.92, 0.05), Vector3(2.15, 2.65, -3.46), Color("6d8080"), 0.72)
    for x in [1.72, 2.15, 2.58]:
        _add_box("公告栏便签", Vector3(0.20, 0.18, 0.06), Vector3(x, 2.72, -3.40), Color("e8c77d"), 0.68)

func _add_plant(at: Vector3) -> void:
    _add_box("绿植花盆", Vector3(0.58, 0.46, 0.58), at + Vector3(0.0, 0.23, 0.0), Color("8a684c"), 0.68)
    var stem := CylinderMesh.new()
    stem.top_radius = 0.035
    stem.bottom_radius = 0.055
    stem.height = 0.8
    var stem_node := MeshInstance3D.new()
    stem_node.name = "绿植枝干"
    stem_node.mesh = stem
    stem_node.position = at + Vector3(0.0, 0.88, 0.0)
    stem_node.material_override = _material(Color("47674f"), 0.86)
    add_child(stem_node)
    _add_box("绿植叶冠", Vector3(0.95, 0.62, 0.95), at + Vector3(0.0, 1.26, 0.0), Color("587b5c"), 0.86)

func _add_ceiling_panels() -> void:
    var panel_material := _material(Color("fff0cf"), 0.24)
    panel_material.emission_enabled = true
    panel_material.emission = Color("fff0cf")
    panel_material.emission_energy_multiplier = 0.72
    for x in [-3.6, 0.0, 3.6]:
        _add_box("办公室暖色灯板", Vector3(2.35, 0.055, 0.34), Vector3(x, 4.12, 0.25), Color("fff0cf"), 0.24, panel_material)

func _count_renderable_meshes(root: Node) -> int:
    var count := 0
    for child in root.get_children():
        if child is MeshInstance3D and child.mesh != null:
            count += 1
        count += _count_renderable_meshes(child)
    return count

func _is_black_or_low_variance(image: Image) -> bool:
    var sample_width := 16
    var sample_height := 9
    var sum := 0.0
    var sum_squared := 0.0
    var sample_count := 0
    var maximum := 0.0
    for y in range(sample_height):
        var pixel_y := int(float(y) * float(image.get_height() - 1) / float(sample_height - 1))
        for x in range(sample_width):
            var pixel_x := int(float(x) * float(image.get_width() - 1) / float(sample_width - 1))
            var pixel: Color = image.get_pixel(pixel_x, pixel_y)
            var luminance: float = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b
            sum += luminance
            sum_squared += luminance * luminance
            maximum = max(maximum, luminance)
            sample_count += 1
    var mean := sum / float(sample_count)
    var variance: float = max(0.0, sum_squared / float(sample_count) - mean * mean)
    return maximum < 0.03 or variance < 0.00005

func _add_desk(at: Vector3) -> void:
    _add_box("办公桌", Vector3(2.25, 0.12, 0.9), at + Vector3(0.0, 1.0, 0.0), Color("756c65"), 0.72)
    _add_box("桌腿", Vector3(0.10, 1.0, 0.10), at + Vector3(-0.86, 0.5, -0.28), Color("30383d"), 0.58)
    _add_box("桌腿", Vector3(0.10, 1.0, 0.10), at + Vector3(0.86, 0.5, -0.28), Color("30383d"), 0.58)
    _add_box("显示器", Vector3(0.62, 0.34, 0.06), at + Vector3(0.0, 1.32, -0.12), Color("273744"), 0.55)

func _add_box(node_name: String, size: Vector3, at: Vector3, color: Color, roughness: float, override_material: Material = null) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = node_name
    node.mesh = mesh
    node.position = at
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    node.material_override = override_material if override_material != null else material
    add_child(node)

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = metallic
    return material

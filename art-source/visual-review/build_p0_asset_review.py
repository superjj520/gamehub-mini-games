"""生成新时代觉醒者 P0 候选资产的统一灯光审阅图。

这些图只用于资产筛选和比例/材质审阅，不替代 Godot 正式运行时截图，
也不会改变资产权利或发布状态。
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "reference-evidence" / "p0-asset-review"
OUTPUT.mkdir(parents=True, exist_ok=True)


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.6, metallic: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat


def plane(name: str, size: float, z: float, mat: bpy.types.Material) -> None:
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0.0, 0.0, z))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)


def box(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material, bevel: float = 0.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("软边", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
    return obj


def import_asset(path: Path, location: tuple[float, float, float], target_height: float | None = None, tint: tuple[float, float, float, float] | None = None) -> list[bpy.types.Object]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = [obj for obj in bpy.context.scene.objects if obj not in before]
    if not imported:
        raise RuntimeError(f"没有导入资产：{path}")
    root = bpy.data.objects.new(path.stem + "_审阅根", None)
    bpy.context.collection.objects.link(root)
    for obj in imported:
        if obj.parent is None:
            obj.parent = root
    if target_height:
        points: list[Vector] = []
        for obj in imported:
            if obj.type == "MESH":
                points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
        if points:
            height = max(point.z for point in points) - min(point.z for point in points)
            if height > 0.001:
                root.scale = (target_height / height,) * 3
    root.location = location
    if tint:
        tint_materials(imported, tint)
    return imported + [root]


def tint_materials(objects: list[bpy.types.Object], tint: tuple[float, float, float, float]) -> None:
    for obj in objects:
        if obj.type != "MESH":
            continue
        for slot in obj.material_slots:
            if not slot.material:
                continue
            mat = slot.material.copy()
            mat.name = f"{mat.name}_审阅配色"
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                base = bsdf.inputs["Base Color"].default_value
                bsdf.inputs["Base Color"].default_value = tuple(min(1.0, base[i] * tint[i]) for i in range(3)) + (base[3],)
            slot.material = mat


def look_at(camera: bpy.types.Object, target: tuple[float, float, float]) -> None:
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def setup_camera(location: tuple[float, float, float], target: tuple[float, float, float], lens: float = 52.0) -> bpy.types.Object:
    camera_data = bpy.data.cameras.new("固定审阅镜头")
    camera = bpy.data.objects.new("固定审阅镜头", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = location
    camera_data.lens = lens
    look_at(camera, target)
    bpy.context.scene.camera = camera
    return camera


def setup_lighting() -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("审阅世界")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.018, 0.026, 0.035, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22
    for name, location, energy, size, color in [
        ("主光", (4.5, -5.0, 7.0), 1100.0, 4.0, (1.0, 0.84, 0.68)),
        ("轮廓光", (-5.0, 3.0, 5.4), 900.0, 3.0, (0.42, 0.62, 1.0)),
        ("顶光", (0.0, 0.0, 8.5), 700.0, 3.0, (1.0, 0.96, 0.86)),
    ]:
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.shape = "DISK"
        light_data.size = size
        light_data.color = color
        light = bpy.data.objects.new(name, light_data)
        bpy.context.collection.objects.link(light)
        light.location = location
        look_at(light, (0.0, 0.0, 1.0))


def setup_render(name: str) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(OUTPUT / f"{name}.png")
    scene.render.film_transparent = False
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.look = "AgX - Medium High Contrast"


def render_office_npc() -> None:
    clear_scene()
    setup_lighting()
    floor = material("办公室地板", (0.12, 0.15, 0.17, 1.0), 0.72)
    wall = material("办公室墙面", (0.32, 0.39, 0.40, 1.0), 0.62)
    wood = material("办公室桌面", (0.34, 0.19, 0.12, 1.0), 0.58)
    glass = material("办公室玻璃", (0.18, 0.42, 0.46, 0.42), 0.2)
    screen = material("显示器发光", (0.05, 0.22, 0.31, 1.0), 0.26)
    plane("办公室地面", 18.0, 0.0, floor)
    box("背景墙", (0.0, 2.1, 2.1), (5.5, 0.12, 2.1), wall, 0.08)
    for x in (-2.7, 0.0, 2.7):
        box("玻璃隔断", (x, 0.3, 1.35), (0.05, 1.55, 1.25), glass, 0.03)
    box("桌面", (-1.65, 0.65, 0.82), (1.5, 0.48, 0.07), wood, 0.04)
    box("显示器", (-1.65, 0.68, 1.28), (0.42, 0.04, 0.28), screen, 0.02)
    char = ROOT / "art-source/characters/makehuman-office-worker/makehuman_office_worker_candidate_recolor.glb"
    import_asset(char, (0.7, 0.0, 0.0), target_height=1.82)
    setup_camera((3.8, -5.8, 2.25), (0.35, 0.3, 1.15), 58.0)
    setup_render("office-npc-makehuman-candidate")
    bpy.ops.render.render(write_still=True)


def render_city_crowd() -> None:
    clear_scene()
    setup_lighting()
    asphalt = material("城市道路", (0.075, 0.088, 0.098, 1.0), 0.88)
    sidewalk = material("城市人行道", (0.24, 0.26, 0.27, 1.0), 0.72)
    plane("城市道路", 28.0, 0.0, asphalt)
    box("人行道左", (-4.0, 0.0, 0.08), (1.5, 6.0, 0.08), sidewalk, 0.04)
    box("人行道右", (4.0, 0.0, 0.08), (1.5, 6.0, 0.08), sidewalk, 0.04)
    char = ROOT / "gta-reference-runtime/assets/characters/quaternius-superhero-male/character_npc_outfitted.glb"
    for index, (x, y, tint) in enumerate([
        (-2.4, 1.1, (0.72, 0.82, 0.92, 1.0)),
        (-0.8, -0.4, (0.92, 0.72, 0.64, 1.0)),
        (1.0, 0.8, (0.68, 0.88, 0.76, 1.0)),
        (2.3, -1.0, (0.92, 0.84, 0.62, 1.0)),
    ]):
        root = import_asset(char, (x, y, 0.0), target_height=1.78, tint=tint)[-1]
        root.rotation_euler[2] = math.radians(180.0 if index % 2 else 0.0)
    setup_camera((7.8, -9.8, 5.1), (0.0, 0.2, 0.9), 54.0)
    setup_render("city-crowd-quaternius-candidate")
    bpy.ops.render.render(write_still=True)


def render_vehicle() -> None:
    clear_scene()
    setup_lighting()
    asphalt = material("载具展示地面", (0.085, 0.095, 0.11, 1.0), 0.86)
    line = material("道路标线", (0.78, 0.67, 0.32, 1.0), 0.42)
    plane("载具展示地面", 16.0, 0.0, asphalt)
    box("道路标线", (0.0, 1.0, 0.012), (0.08, 5.0, 0.012), line, 0.01)
    vehicle = ROOT / "gta-reference-runtime/assets/vehicles/three-wheel-delivery/three_wheel_delivery.glb"
    import_asset(vehicle, (0.0, 0.0, 0.0), target_height=1.95)
    setup_camera((4.5, -5.8, 2.5), (0.0, 0.1, 0.85), 55.0)
    setup_render("three-wheel-delivery-candidate")
    bpy.ops.render.render(write_still=True)


def render_original_player() -> None:
    """用统一灯光检查原创主角 GLB 的人体比例、材质和背包轮廓。"""
    clear_scene()
    setup_lighting()
    floor = material("主角审阅地面", (0.075, 0.088, 0.098, 1.0), 0.86)
    wall = material("主角审阅背景", (0.13, 0.16, 0.18, 1.0), 0.78)
    plane("主角审阅地面", 12.0, 0.0, floor)
    box("主角审阅背景墙", (0.0, 2.4, 2.8), (4.8, 0.12, 2.4), wall, 0.08)
    player = ROOT / "gta-reference-runtime/assets/characters/original-procedural-office-characters/original_player_visual_v1.glb"
    import_asset(player, (0.0, 0.0, 0.0), target_height=2.08)
    setup_camera((3.45, -5.6, 2.55), (0.0, 0.0, 1.05), 58.0)
    setup_render("original-player-visual-candidate")
    bpy.ops.render.render(write_still=True)


def render_city_environment() -> None:
    clear_scene()
    setup_lighting()
    road = material("城市路面", (0.07, 0.08, 0.09, 1.0), 0.9)
    sidewalk = material("城市路缘", (0.27, 0.28, 0.29, 1.0), 0.75)
    plane("城市路面", 46.0, 0.0, road)
    box("左侧人行道", (-7.0, 0.0, 0.08), (1.8, 18.0, 0.08), sidewalk, 0.05)
    box("右侧人行道", (7.0, 0.0, 0.08), (1.8, 18.0, 0.08), sidewalk, 0.05)
    for path, loc, scale in [
        ("b_small.glb", (-7.5, 5.0, 0.0), 0.34),
        ("b_medium.glb", (7.5, 0.0, 0.0), 0.25),
        ("b_large.glb", (-7.5, -8.0, 0.0), 0.19),
    ]:
        asset = ROOT / "gta-reference-runtime/assets/environment/quaternius-downtown" / path
        imported = import_asset(asset, loc)
        imported[-1].scale = (scale, scale, scale)
    setup_camera((19.0, -24.0, 12.0), (0.0, 1.5, 3.5), 48.0)
    setup_render("city-environment-quaternius-candidate")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    render_office_npc()
    render_city_crowd()
    render_vehicle()
    render_original_player()
    render_city_environment()
    print(f"P0 资产审阅图已生成：{OUTPUT}")

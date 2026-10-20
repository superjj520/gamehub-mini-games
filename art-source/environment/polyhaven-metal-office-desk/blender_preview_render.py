import hashlib
import json
import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
ASSET_DIR = ROOT / "art-source" / "environment" / "polyhaven-metal-office-desk"
DESK_GLB = ASSET_DIR / "metal_office_desk_1k.glb"
OUTPUT_DIR = ROOT / "reference-evidence" / "candidates" / "p0-office"


def material(name, color, roughness=0.6, metallic=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if emission:
        principled.inputs["Emission Color"].default_value = (*emission, 1.0)
        principled.inputs["Emission Strength"].default_value = 2.5
    return mat


def cube(name, location, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2.0, scale[1] / 2.0, scale[2] / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0:
        modifier = obj.modifiers.new("软化边缘", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
    return obj


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def import_desk(location, rotation_y, index):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(DESK_GLB))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    root = bpy.data.objects.new(f"PolyHaven工位候选_{index:02d}", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in imported:
        if obj.parent is None:
            obj.parent = root
            obj.matrix_parent_inverse = root.matrix_world.inverted()
    root.location = location
    root.rotation_euler[1] = math.radians(rotation_y)
    return root


def build_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        if collection.name != "Collection":
            bpy.data.collections.remove(collection)

    floor_mat = material("地毯", (0.18, 0.21, 0.22), 0.92)
    wall_mat = material("隔断暖灰", (0.34, 0.39, 0.40), 0.78)
    glass_mat = material("玻璃隔断", (0.30, 0.48, 0.51), 0.35, 0.0)
    chair_mat = material("办公椅", (0.035, 0.055, 0.07), 0.62)
    screen_mat = material("显示器冷光", (0.03, 0.17, 0.22), 0.25, emission=(0.02, 0.16, 0.22))
    screen_dark_mat = material("显示器边框", (0.015, 0.02, 0.024), 0.35, metallic=0.2)
    ceiling_mat = material("天花板", (0.62, 0.64, 0.62), 0.9)
    light_mat = material("灯具", (0.85, 0.9, 0.82), 0.25, emission=(0.85, 0.9, 0.82))

    cube("地面", (0, -0.08, 0), (16, 0.16, 12), floor_mat)
    cube("后墙", (0, 2.0, 5.85), (16, 4, 0.14), wall_mat)
    cube("左墙", (-7.85, 2.0, 0), (0.14, 4, 12), wall_mat)
    cube("右墙", (7.85, 2.0, 0), (0.14, 4, 12), wall_mat)
    cube("天花板", (0, 4.0, 0), (16, 0.12, 12), ceiling_mat)
    cube("窗带", (0, 2.15, 5.72), (8.6, 1.75, 0.05), glass_mat)

    for x in (-5.4, -1.8, 1.8, 5.4):
        cube("玻璃隔断", (x, 1.25, 0), (0.06, 2.3, 2.5), glass_mat)
        cube("隔断底座", (x, 0.12, 0), (0.16, 0.24, 2.55), wall_mat, 0.02)

    desk_locations = [(-4.1, -2.0, 0.0), (0.0, -2.0, 0.0), (4.1, -2.0, 0.0), (-2.05, 2.0, 180.0), (2.05, 2.0, 180.0)]
    for index, (x, z, yaw) in enumerate(desk_locations, start=1):
        import_desk((x, 0.0, z), yaw, index)
        yaw_rad = math.radians(yaw)
        forward = Vector((math.sin(yaw_rad), 0, -math.cos(yaw_rad)))
        screen_center = Vector((x, 1.02, z)) + forward * 0.05
        cube(f"显示器边框_{index:02d}", screen_center, (0.86, 0.56, 0.07), screen_dark_mat, 0.025)
        cube(f"显示器屏幕_{index:02d}", screen_center + forward * 0.04, (0.70, 0.40, 0.02), screen_mat, 0.015)
        stand = Vector((x, 0.84, z)) + forward * 0.02
        cube(f"显示器支架_{index:02d}", stand, (0.06, 0.22, 0.06), screen_dark_mat, 0.01)
        chair = Vector((x, 0.43, z)) - forward * 1.02
        cube(f"办公椅坐垫_{index:02d}", chair, (0.72, 0.13, 0.72), chair_mat, 0.08)
        cube(f"办公椅靠背_{index:02d}", chair - forward * 0.26 + Vector((0, 0.40, 0)), (0.70, 0.72, 0.12), chair_mat, 0.06)

    for x in (-4.0, 0.0, 4.0):
        cube("线性灯具", (x, 3.88, -1.0), (2.8, 0.08, 0.20), light_mat, 0.03)
        light_data = bpy.data.lights.new(f"线性灯光_{x}", "AREA")
        light_data.energy = 380
        light_data.shape = "RECTANGLE"
        light_data.size = 2.6
        light_data.size_y = 0.22
        light_obj = bpy.data.objects.new(f"线性灯光_{x}", light_data)
        bpy.context.scene.collection.objects.link(light_obj)
        light_obj.location = (x, 3.7, -1.0)
        light_obj.rotation_euler = (0, 0, 0)

    world = bpy.context.scene.world or bpy.data.worlds.new("办公室世界")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.035, 0.055, 0.065, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.32

    key_data = bpy.data.lights.new("办公室主光", "AREA")
    key_data.energy = 900
    key_data.shape = "DISK"
    key_data.size = 7.0
    key = bpy.data.objects.new("办公室主光", key_data)
    bpy.context.scene.collection.objects.link(key)
    key.location = (0.0, 5.5, -1.0)
    look_at(key, (0, 0, 0))


def render_view(name, location, target, lens=48):
    camera_data = bpy.data.cameras.new(name)
    camera = bpy.data.objects.new(name, camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = location
    camera_data.lens = lens
    look_at(camera, target)
    bpy.context.scene.camera = camera
    bpy.context.scene.render.filepath = str(OUTPUT_DIR / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    return Path(bpy.context.scene.render.filepath)


def write_metadata(image_path, camera_name, view_kind):
    digest = hashlib.sha256(image_path.read_bytes()).hexdigest()
    meta_path = image_path.with_suffix(".json")
    payload = {
        "candidate_only": True,
        "visual_status": "unverified",
        "formal_acceptance": False,
        "view_kind": view_kind,
        "scene": "blender_offline_office_full_kit_preview",
        "source_asset": "metal_office_desk_1k.glb",
        "reference_frames": ["video-2/office-01.jpg", "video-2/office-06.jpg"],
        "camera": camera_name,
        "image_sha256": digest,
        "note": "离线 Blender 候选构图，不是 Godot 正式运行时视觉验收。",
    }
    meta_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    build_scene()
    wide = render_view("office-full-kit-blender-wide", (11.0, 6.2, -13.0), (0, 1.0, -0.4), 50)
    close = render_view("office-full-kit-blender-close", (4.6, 2.7, -5.4), (0.0, 1.05, -1.5), 55)
    write_metadata(wide, "office-full-kit-blender-wide", "wide")
    write_metadata(close, "office-full-kit-blender-close", "close")
    print(f"离线办公室候选渲染完成：{wide}")
    print(f"离线办公室候选渲染完成：{close}")


if __name__ == "__main__":
    main()

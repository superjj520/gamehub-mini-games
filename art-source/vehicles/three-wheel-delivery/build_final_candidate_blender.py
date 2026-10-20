"""生成原创低矮开放货斗三轮配送车的 Blender 源文件、GLB 和静态预览。

资产约定：米制、+Y 向上、局部 -Z 为车头、原点位于车体几何中心。
该生成器只创建原创几何和程序化材质，不复制参考视频或商业游戏资产。
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
OUTPUT_DIR = ROOT / "art-source/vehicles/three-wheel-delivery/final-candidate"
BLEND_PATH = OUTPUT_DIR / "three_wheel_delivery_final_candidate.blend"
GLB_PATH = OUTPUT_DIR / "three_wheel_delivery_final_candidate.glb"
PREVIEW_PATH = OUTPUT_DIR / "three_wheel_delivery_final_candidate_preview.png"
CARD_PATH = OUTPUT_DIR / "asset-card.json"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float], metallic: float, roughness: float, emission=None):
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    node = result.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = color
    node.inputs["Metallic"].default_value = metallic
    node.inputs["Roughness"].default_value = roughness
    if emission is not None:
        node.inputs["Emission Color"].default_value = (*emission, 1.0)
        node.inputs["Emission Strength"].default_value = 1.8
    return result


def parent_to(obj, root) -> None:
    obj.parent = root


def bevelled_box(name, size, location, mat, root, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("原创倒角", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    parent_to(obj, root)
    return obj


def cylinder(name, radius, depth, location, rotation, mat, root, vertices=32, bevel=0.025):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    if bevel > 0:
        modifier = obj.modifiers.new("原创倒角", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    parent_to(obj, root)
    return obj


def torus(name, major_radius, minor_radius, location, rotation, mat, root):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius,
        minor_radius=minor_radius,
        major_segments=32,
        minor_segments=12,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    parent_to(obj, root)
    return obj


def sphere(name, scale, location, mat, root):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    parent_to(obj, root)
    return obj


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def build_vehicle():
    clear_scene()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    root = bpy.data.objects.new("ThreeWheelDeliveryFinalCandidate", None)
    bpy.context.collection.objects.link(root)
    root["asset_role"] = "original_three_wheel_delivery_final_candidate"
    root["unit"] = "meter"
    root["forward_axis"] = "-Z"
    root["pivot"] = "body_center"
    root["release_status"] = "candidate_visual_signoff_pending"

    blue = material("原创车体蓝", (0.035, 0.24, 0.42, 1.0), 0.42, 0.28)
    blue_light = material("原创车体高光蓝", (0.08, 0.38, 0.58, 1.0), 0.32, 0.24)
    dark = material("原创底盘深蓝", (0.018, 0.055, 0.09, 1.0), 0.56, 0.36)
    metal = material("原创拉丝金属", (0.30, 0.36, 0.39, 1.0), 0.72, 0.24)
    rubber = material("原创轮胎橡胶", (0.006, 0.009, 0.012, 1.0), 0.02, 0.86)
    seat = material("原创座椅皮革", (0.10, 0.065, 0.048, 1.0), 0.08, 0.62)
    yellow = material("原创货物安全黄", (0.92, 0.48, 0.06, 1.0), 0.16, 0.38)
    glass = material("原创蓝灰玻璃", (0.08, 0.30, 0.38, 0.52), 0.28, 0.16)
    lamp = material("原创暖色灯", (1.0, 0.48, 0.08, 1.0), 0.05, 0.24, (1.0, 0.16, 0.02))
    red = material("原创尾灯红", (0.72, 0.02, 0.018, 1.0), 0.08, 0.26, (0.50, 0.0, 0.0))
    plate = material("原创车牌浅色", (0.76, 0.72, 0.52, 1.0), 0.18, 0.48)

    bevelled_box("候选三轮车车体", (1.72, 0.52, 2.28), (0.0, -0.02, 0.0), blue, root, 0.12)
    bevelled_box("候选三轮车前鼻", (1.36, 0.48, 0.74), (0.0, 0.25, -0.80), blue_light, root, 0.14)
    bevelled_box("候选三轮车底盘", (1.56, 0.18, 2.58), (0.0, -0.34, 0.04), dark, root, 0.05)
    bevelled_box("候选三轮车前饰条", (1.08, 0.10, 0.10), (0.0, 0.58, -1.12), metal, root, 0.03)
    bevelled_box("候选三轮车座椅", (0.72, 0.14, 0.56), (0.0, 0.38, -0.13), seat, root, 0.06)
    bevelled_box("候选三轮车靠背", (0.72, 0.42, 0.10), (0.0, 0.58, 0.20), seat, root, 0.05)

    # 开放货斗：保留参考帧最重要的低矮、无顶篷识别特征。
    bevelled_box("候选三轮车货斗底板", (1.30, 0.12, 0.98), (0.0, 0.28, 0.72), dark, root, 0.035)
    bevelled_box("候选三轮车货斗左栏", (0.08, 0.48, 1.02), (-0.62, 0.54, 0.72), metal, root, 0.035)
    bevelled_box("候选三轮车货斗右栏", (0.08, 0.48, 1.02), (0.62, 0.54, 0.72), metal, root, 0.035)
    bevelled_box("候选三轮车货斗后栏", (1.30, 0.48, 0.08), (0.0, 0.54, 1.20), metal, root, 0.035)
    bevelled_box("候选三轮车货斗门板", (1.18, 0.32, 0.08), (0.0, 0.38, 1.19), blue_light, root, 0.035)
    bevelled_box("候选三轮车左货物托盘", (0.36, 0.11, 0.40), (-0.25, 0.55, 0.73), yellow, root, 0.045)
    bevelled_box("候选三轮车右货物托盘", (0.36, 0.11, 0.40), (0.25, 0.55, 0.73), yellow, root, 0.045)
    bevelled_box("候选三轮车货斗横向绑带", (1.12, 0.045, 0.045), (0.0, 0.75, 0.72), plate, root, 0.012)

    # 车轮和轮毂使用圆角环，避免纯方盒在近距离镜头中失去车辆质感。
    wheel_cases = [
        ("候选三轮车前", (0.0, -0.43, -1.02)),
        ("候选三轮车左后", (-0.88, -0.43, 0.72)),
        ("候选三轮车右后", (0.88, -0.43, 0.72)),
    ]
    for prefix, location in wheel_cases:
        torus(prefix + "轮胎", 0.28, 0.085, location, (0.0, math.pi / 2.0, 0.0), rubber, root)
        cylinder(prefix + "轮毂", 0.13, 0.08, (location[0] - 0.04, location[1], location[2]), (0.0, math.pi / 2.0, 0.0), metal, root, 24, 0.018)

    cylinder("候选三轮车车把立柱", 0.05, 0.48, (0.0, 0.88, -0.78), (0.0, 0.0, math.radians(-12.0)), metal, root, 20, 0.018)
    bevelled_box("候选三轮车车把", (0.98, 0.075, 0.075), (0.0, 1.10, -0.84), metal, root, 0.025)
    sphere("候选三轮车左后视镜", (0.11, 0.07, 0.025), (-0.63, 1.04, -0.94), glass, root)
    sphere("候选三轮车右后视镜", (0.11, 0.07, 0.025), (0.63, 1.04, -0.94), glass, root)
    bevelled_box("候选三轮车前灯", (0.42, 0.13, 0.09), (0.0, 0.55, -1.16), lamp, root, 0.03)
    bevelled_box("候选三轮车左尾灯", (0.18, 0.12, 0.05), (-0.46, 0.40, 1.25), red, root, 0.018)
    bevelled_box("候选三轮车右尾灯", (0.18, 0.12, 0.05), (0.46, 0.40, 1.25), red, root, 0.018)
    bevelled_box("候选三轮车车牌", (0.38, 0.12, 0.03), (0.0, 0.40, 1.28), plate, root, 0.012)
    bevelled_box("候选三轮车左转向灯", (0.13, 0.11, 0.06), (-0.61, 0.42, -1.08), lamp, root, 0.018)
    bevelled_box("候选三轮车右转向灯", (0.13, 0.11, 0.06), (0.61, 0.42, -1.08), lamp, root, 0.018)

    for obj in root.children:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    return root


def render_preview(root):
    bpy.ops.object.camera_add(location=(4.6, 2.75, 5.7))
    camera = bpy.context.object
    camera.name = "预览相机"
    camera.data.lens = 52
    look_at(camera, (0.0, 0.35, 0.25))
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(3.2, 4.8, 2.6))
    key = bpy.context.object
    key.name = "预览主光"
    key.data.energy = 750
    key.data.shape = "DISK"
    key.data.size = 4.0
    look_at(key, (0.0, 0.3, 0.2))

    bpy.ops.object.light_add(type="AREA", location=(-3.5, 2.6, 1.8))
    fill = bpy.context.object
    fill.name = "预览补光"
    fill.data.energy = 420
    fill.data.size = 3.0
    look_at(fill, (0.0, 0.3, 0.3))

    bpy.ops.mesh.primitive_plane_add(size=20, location=(0.0, -0.52, 0.0))
    floor = bpy.context.object
    floor.name = "预览地面"
    floor.data.materials.append(material("预览地面材质", (0.035, 0.048, 0.055, 1.0), 0.0, 0.82))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.world.color = (0.025, 0.038, 0.055)
    scene.render.film_transparent = False
    bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(camera, do_unlink=True)
    bpy.data.objects.remove(key, do_unlink=True)
    bpy.data.objects.remove(fill, do_unlink=True)
    bpy.data.objects.remove(floor, do_unlink=True)


def export_runtime(root):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in root.children:
        obj.select_set(True)
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
        export_texcoords=True,
        export_normals=True,
    )

    CARD_PATH.write_text(json.dumps({
        "schema_version": 1,
        "asset_id": "three-wheel-delivery-final-candidate-v1",
        "category": "vehicles",
        "source": {
            "type": "original_blender_procedural_generation",
            "source_file": "art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.blend",
            "license": "原创生成，项目方自有候选源",
        },
        "conventions": {
            "unit": "meter",
            "up_axis": "+Y",
            "forward_axis": "-Z",
            "pivot": "body_center",
        },
        "runtime_file": "art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.glb",
        "preview_file": "art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate_preview.png",
        "release_allowed": False,
        "visual_status": "unverified",
        "remaining_acceptance": ["Godot 运行时截图", "载具行为回放", "Windows 10/11 性能", "产品负责人视觉签收"],
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    root = build_vehicle()
    render_preview(root)
    export_runtime(root)
    print(f"原创三轮配送车候选已生成：{GLB_PATH}")


if __name__ == "__main__":
    main()

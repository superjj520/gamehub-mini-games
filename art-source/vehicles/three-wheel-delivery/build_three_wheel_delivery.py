"""导出新时代觉醒者三轮配送车的第一版独立 GLB 候选。

约定：米制、+Y 向上、局部 -Z 为车头，原点位于车体几何中心。
该资产是内部候选，不代表最终写实资产或发布权利签收。
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[3]
RUNTIME_ASSET = ROOT / "gta-reference-runtime/assets/vehicles/three-wheel-delivery"
BLEND_OUTPUT = ROOT / "art-source/vehicles/three-wheel-delivery/three_wheel_delivery.blend"
GLB_OUTPUT = RUNTIME_ASSET / "three_wheel_delivery.glb"


def material(name: str, color: tuple[float, float, float, float], roughness: float, metallic: float = 0.0, emission: tuple[float, float, float, float] | None = None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if emission is not None:
        principled.inputs["Emission Color"].default_value = emission
        principled.inputs["Emission Strength"].default_value = 1.4
    return mat


def apply_bevel(obj, amount: float, segments: int = 3):
    if amount <= 0.0:
        return
    modifier = obj.modifiers.new("候选圆角", "BEVEL")
    modifier.width = amount
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)


def add_box(name: str, size: tuple[float, float, float], location: tuple[float, float, float], mat, bevel: float = 0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(obj, bevel)
    obj.data.materials.append(mat)
    return obj


def add_cylinder(name: str, location: tuple[float, float, float], radius: float, depth: float, mat, rotation=(0.0, 0.0, 0.0), vertices: int = 24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def add_wheel(prefix: str, location: tuple[float, float, float], tire, hub, axle: bool = False):
    # 默认圆柱轴为 Z；绕 Y 旋转 90 度后，轮轴沿 X。
    add_cylinder(prefix + "轮胎", location, 0.30, 0.16, tire, rotation=(0.0, math.pi / 2.0, 0.0))
    hub_location = (location[0] - 0.085, location[1], location[2])
    add_cylinder(prefix + "轮毂", hub_location, 0.13, 0.03, hub, rotation=(0.0, math.pi / 2.0, 0.0), vertices=20)
    if axle:
        add_cylinder(prefix + "轮轴", location, 0.055, 0.32, hub, rotation=(0.0, math.pi / 2.0, 0.0), vertices=16)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.unit_settings.length_unit = "METERS"

    root = bpy.data.objects.new("ThreeWheelDelivery", None)
    bpy.context.collection.objects.link(root)

    blue = material("车体蓝", (0.114, 0.384, 0.522, 1.0), 0.36, 0.16)
    blue_dark = material("车体深蓝", (0.047, 0.145, 0.20, 1.0), 0.48, 0.10)
    yellow = material("安全黄", (0.80, 0.49, 0.10, 1.0), 0.34, 0.05)
    rubber = material("轮胎橡胶", (0.012, 0.016, 0.021, 1.0), 0.88)
    metal = material("结构金属", (0.26, 0.31, 0.35, 1.0), 0.28, 0.55)
    glass = material("挡风玻璃", (0.18, 0.54, 0.62, 0.52), 0.18, 0.05)
    glass.blend_method = "BLEND"
    glass.use_screen_refraction = True
    fabric = material("顶篷织物", (0.62, 0.44, 0.20, 1.0), 0.82)
    seat_mat = material("座椅皮革", (0.12, 0.095, 0.09, 1.0), 0.72)
    indicator = material("转向灯", (0.95, 0.63, 0.16, 1.0), 0.24, emission=(0.42, 0.18, 0.02, 1.0))
    plate = material("车牌", (0.86, 0.79, 0.55, 1.0), 0.58)

    objects = []
    # 对齐参考视频的第一识别特征：低矮蓝色车身、开放后货斗、驾驶员无遮挡。
    objects += [add_box("候选三轮车车体", (1.64, 0.44, 2.30), (0.0, -0.02, 0.0), blue, 0.10)]
    objects += [add_box("候选三轮车底盘", (1.48, 0.16, 2.52), (0.0, -0.30, 0.03), blue_dark, 0.05)]
    objects += [add_box("候选三轮车前挡板", (1.22, 0.34, 0.58), (0.0, 0.30, -0.78), blue, 0.08)]
    objects += [add_box("候选三轮车前饰条", (1.08, 0.10, 0.40), (0.0, 0.52, -0.68), blue_dark, 0.025)]
    objects += [add_box("候选三轮车货斗底板", (1.24, 0.10, 0.92), (0.0, 0.25, 0.67), blue_dark, 0.03)]
    objects += [add_box("候选三轮车货斗左栏", (0.07, 0.24, 0.92), (-0.59, 0.40, 0.67), metal, 0.02)]
    objects += [add_box("候选三轮车货斗右栏", (0.07, 0.24, 0.92), (0.59, 0.40, 0.67), metal, 0.02)]
    objects += [add_box("候选三轮车货斗后栏", (1.24, 0.24, 0.07), (0.0, 0.40, 1.11), metal, 0.02)]
    objects += [add_box("候选三轮车货斗门板", (1.14, 0.20, 0.06), (0.0, 0.31, 1.08), blue, 0.02)]
    objects += [add_box("候选三轮车左货物托盘", (0.32, 0.10, 0.34), (-0.25, 0.46, 0.70), yellow, 0.02)]
    objects += [add_box("候选三轮车右货物托盘", (0.32, 0.10, 0.34), (0.25, 0.46, 0.70), yellow, 0.02)]
    objects += [add_box("候选三轮车左托盘隔条", (0.035, 0.10, 0.38), (-0.25, 0.51, 0.70), plate, 0.01)]
    objects += [add_box("候选三轮车右托盘隔条", (0.035, 0.10, 0.38), (0.25, 0.51, 0.70), plate, 0.01)]
    objects += [add_box("候选三轮车座椅", (0.68, 0.13, 0.56), (0.0, 0.34, -0.08), seat_mat, 0.06)]
    objects += [add_box("候选三轮车靠背", (0.68, 0.38, 0.09), (0.0, 0.53, 0.25), seat_mat, 0.04)]
    objects += [add_cylinder("候选三轮车车把立柱", (0.0, 1.02, -0.76), 0.045, 0.58, metal, rotation=(0.0, 0.0, math.radians(-12.0)), vertices=16)]
    objects += [add_box("候选三轮车车把", (0.92, 0.08, 0.08), (0.0, 1.30, -0.80), metal, 0.02)]
    objects += [add_box("候选三轮车前灯", (0.42, 0.12, 0.08), (0.0, 0.52, -1.08), yellow, 0.025)]
    objects += [add_box("候选三轮车左转向灯", (0.13, 0.11, 0.06), (-0.58, 0.39, -1.10), indicator, 0.015)]
    objects += [add_box("候选三轮车右转向灯", (0.13, 0.11, 0.06), (0.58, 0.39, -1.10), indicator, 0.015)]
    objects += [add_box("候选三轮车左后视镜", (0.16, 0.12, 0.035), (-0.62, 1.15, -0.90), glass, 0.018)]
    objects += [add_box("候选三轮车右后视镜", (0.16, 0.12, 0.035), (0.62, 1.15, -0.90), glass, 0.018)]
    objects += [add_cylinder("候选三轮车左后视镜杆", (-0.56, 1.08, -0.86), 0.018, 0.26, metal, rotation=(0.0, 0.0, math.radians(-28.0)), vertices=12)]
    objects += [add_cylinder("候选三轮车右后视镜杆", (0.56, 1.08, -0.86), 0.018, 0.26, metal, rotation=(0.0, 0.0, math.radians(28.0)), vertices=12)]
    objects += [add_box("候选三轮车车牌", (0.34, 0.12, 0.025), (0.0, 0.34, -1.08), plate, 0.01)]
    objects += [add_box("候选三轮车后保险杠", (1.28, 0.10, 0.12), (0.0, 0.16, 1.27), metal, 0.02)]
    objects += [add_box("候选三轮车车牌", (0.34, 0.14, 0.025), (0.0, 0.34, -1.08), plate, 0.01)]
    objects += [add_box("候选三轮车后保险杠", (1.34, 0.12, 0.12), (0.0, 0.16, 1.27), metal, 0.02)]
    add_wheel("候选三轮车左后", (-0.88, -0.38, 0.70), rubber, metal, axle=True)
    add_wheel("候选三轮车右后", (0.88, -0.38, 0.70), rubber, metal, axle=True)
    add_wheel("候选三轮车前", (0.0, -0.38, -0.96), rubber, metal, axle=False)

    for obj in bpy.context.scene.objects:
        if obj is root:
            continue
        if obj.parent is None:
            obj.parent = root
        obj.select_set(False)

    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUTPUT))

    RUNTIME_ASSET.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_OUTPUT),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    print(f"三轮车候选已导出：{GLB_OUTPUT}")


def main():
    parser = argparse.ArgumentParser()
    parser.parse_args()
    build()


if __name__ == "__main__":
    main()

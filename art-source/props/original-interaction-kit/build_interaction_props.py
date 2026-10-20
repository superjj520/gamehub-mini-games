import math
import os

import bpy
from mathutils import Vector


ROOT = os.path.dirname(os.path.abspath(__file__))


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def make_material(name, color, metallic=0.0, roughness=0.55, emission=None):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1.0)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    if emission is not None:
        principled.inputs["Emission Color"].default_value = (*emission, 1.0)
        principled.inputs["Emission Strength"].default_value = 2.2
    return material


def assign_material(obj, material):
    obj.data.materials.append(material)


def add_box(name, location, size, material, bevel=0.025, parent=None):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("小倒角", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    assign_material(obj, material)
    if parent is not None:
        obj.parent = parent
    return obj


def add_cylinder(name, location, radius, depth, material, parent=None, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    assign_material(obj, material)
    if parent is not None:
        obj.parent = parent
    return obj


def add_sphere(name, location, scale, material, parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign_material(obj, material)
    if parent is not None:
        obj.parent = parent
    return obj


def add_empty(name, location, parent):
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "PLAIN_AXES"
    empty.location = location
    bpy.context.collection.objects.link(empty)
    empty.parent = parent
    return empty


def build_egg_tray(root, materials):
    tray = add_empty("EggTray_Interaction", (0.0, 0.0, 0.0), root)
    add_box("托盘底", (0.0, 0.08, 0.0), (0.72, 0.12, 0.48), materials["tray"], 0.04, tray)
    for row in range(2):
        for column in range(5):
            x = -0.25 + column * 0.125
            z = -0.13 + row * 0.26
            add_sphere("鸡蛋_%d_%d" % (row, column), (x, 0.22, z), (0.055, 0.08, 0.055), materials["egg"], tray)
    return tray


def build_scan_board(root, materials):
    board = add_empty("ScanBoard_Interaction", (1.45, 0.0, 0.0), root)
    add_box("扫码台底座", (1.45, 0.48, 0.0), (0.95, 0.96, 0.72), materials["counter"], 0.05, board)
    add_box("扫码台台面", (1.45, 0.98, 0.0), (1.05, 0.08, 0.78), materials["trim"], 0.02, board)
    screen = add_box("扫码屏", (1.45, 1.38, -0.05), (0.58, 0.46, 0.06), materials["screen"], 0.015, board)
    screen.rotation_euler.x = math.radians(-10.0)
    add_box("扫码灯", (1.45, 1.36, 0.02), (0.18, 0.04, 0.03), materials["emission"], 0.01, board)
    return board


def build_delivery_marker(root, materials):
    marker = add_empty("DeliveryMarker_Interaction", (2.95, 0.0, 0.0), root)
    add_cylinder("标识柱", (2.95, 0.7, 0.0), 0.055, 1.4, materials["warning"], marker)
    add_box("交付标识牌", (2.95, 1.38, 0.0), (0.62, 0.36, 0.06), materials["paper"], 0.02, marker)
    add_box("交付灯带", (2.95, 1.38, 0.035), (0.28, 0.035, 0.02), materials["emission"], 0.005, marker)
    return marker


def build_basket(root, materials):
    basket = add_empty("ShopBasket_Interaction", (0.0, 0.0, 1.35), root)
    add_box("篮筐底", (0.0, 0.22, 1.35), (0.72, 0.08, 0.48), materials["basket"], 0.03, basket)
    for x in (-0.32, 0.32):
        add_box("篮筐侧边", (x, 0.42, 1.35), (0.06, 0.42, 0.5), materials["basket"], 0.02, basket)
    for z in (1.13, 1.57):
        add_box("篮筐前后边", (0.0, 0.42, z), (0.72, 0.42, 0.06), materials["basket"], 0.02, basket)
    add_box("篮筐提手", (0.0, 0.75, 1.35), (0.08, 0.62, 0.08), materials["basket"], 0.02, basket)
    return basket


def main():
    clear_scene()
    root = bpy.data.objects.new("InteractionPropsKit", None)
    bpy.context.collection.objects.link(root)
    root["asset_role"] = "original_interaction_props_candidate"
    root["unit"] = "meter"
    root["up_axis"] = "+Y"
    root["release_status"] = "candidate_only"

    materials = {
        "tray": make_material("托盘_暖灰", (0.22, 0.25, 0.25), metallic=0.1, roughness=0.48),
        "egg": make_material("鸡蛋_象牙白", (0.88, 0.77, 0.58), roughness=0.42),
        "counter": make_material("扫码台_深青", (0.08, 0.16, 0.17), metallic=0.15, roughness=0.35),
        "trim": make_material("扫码台_金属边", (0.48, 0.52, 0.46), metallic=0.65, roughness=0.28),
        "screen": make_material("扫码屏_黑玻璃", (0.015, 0.035, 0.04), metallic=0.1, roughness=0.16),
        "emission": make_material("状态灯_青色", (0.04, 0.5, 0.55), roughness=0.25, emission=(0.0, 0.85, 0.95)),
        "warning": make_material("交付柱_橙色", (0.72, 0.2, 0.06), roughness=0.35, emission=(0.35, 0.03, 0.0)),
        "paper": make_material("标识牌_纸张", (0.82, 0.75, 0.58), roughness=0.78),
        "basket": make_material("购物篮_蓝灰", (0.08, 0.24, 0.32), metallic=0.1, roughness=0.5),
    }

    build_egg_tray(root, materials)
    build_scan_board(root, materials)
    build_delivery_marker(root, materials)
    build_basket(root, materials)

    for obj in bpy.context.scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root

    blend_path = os.path.join(ROOT, "interaction_props_kit.blend")
    glb_path = os.path.join(ROOT, "interaction_props_kit.glb")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
    )
    print("原创交互道具候选已导出：%s" % glb_path)


if __name__ == "__main__":
    main()

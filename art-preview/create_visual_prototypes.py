import bpy
import math
import os
from mathutils import Vector


OUTPUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "assets"))


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name, color, roughness=0.58, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return mat


def apply_bevel(obj, width=0.04, segments=3):
    modifier = obj.modifiers.new("统一倒角", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def cube(name, location, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (scale[0] / 2.0, scale[1] / 2.0, scale[2] / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel > 0.0:
        apply_bevel(obj, bevel)
    return obj


def sphere(name, location, radius, mat, scale=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def cylinder(name, location, radius, depth, mat, rotation=(0.0, 0.0, 0.0), vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return obj


def text_object(name, text, location, size, mat, extrude=0.008):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = extrude
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    obj.data.materials.append(mat)
    return obj


def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )


def create_player():
    clear_scene()
    skin = material("skin_warm", (0.55, 0.29, 0.17), 0.72)
    hair = material("hair_black", (0.018, 0.014, 0.012), 0.45)
    jacket = material("jacket_charcoal", (0.10, 0.12, 0.15), 0.62)
    shirt = material("shirt_cream", (0.78, 0.72, 0.62), 0.7)
    pants = material("pants_dark", (0.055, 0.065, 0.08), 0.72)
    shoes = material("shoes_rubber", (0.018, 0.021, 0.026), 0.5)
    backpack = material("backpack_navy", (0.035, 0.09, 0.16), 0.64)
    metal = material("zipper_metal", (0.32, 0.35, 0.38), 0.28, 0.55)

    cube("torso", (0.0, 1.10, 0.0), (0.66, 0.78, 0.40), jacket, 0.07)
    cube("shirt_panel", (0.0, 1.13, -0.215), (0.26, 0.48, 0.035), shirt, 0.015)
    cube("backpack", (0.0, 1.12, 0.28), (0.48, 0.62, 0.20), backpack, 0.06)
    for side in (-1.0, 1.0):
        cylinder("arm_%s" % side, (side * 0.45, 1.10, 0.0), 0.105, 0.66, jacket, (0.0, math.radians(90.0), 0.0))
        sphere("hand_%s" % side, (side * 0.82, 1.10, 0.0), 0.12, skin, (1.0, 0.85, 0.9))
        cube("leg_%s" % side, (side * 0.18, 0.50, 0.0), (0.22, 0.72, 0.24), pants, 0.045)
        cube("shoe_%s" % side, (side * 0.18, 0.12, -0.08), (0.28, 0.16, 0.42), shoes, 0.04)
    sphere("head", (0.0, 1.77, 0.0), 0.245, skin, (0.92, 1.0, 0.88))
    sphere("hair_cap", (0.0, 1.94, -0.015), 0.255, hair, (1.0, 0.48, 0.95))
    cube("backpack_strap_left", (-0.22, 1.20, -0.20), (0.055, 0.60, 0.035), metal, 0.01)
    cube("backpack_strap_right", (0.22, 1.20, -0.20), (0.055, 0.60, 0.035), metal, 0.01)

    # 原点放在脚底中心，符合运行时角色挂载契约。
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0.0, 0.0, 0.0))
    root = bpy.context.object
    root.name = "Visual"
    for obj in list(bpy.context.scene.objects):
        if obj != root:
            obj.parent = root
    export_glb(os.path.join(OUTPUT_DIR, "characters", "player-character-preview.glb"))


def create_storefront():
    clear_scene()
    wall = material("wall_warm", (0.48, 0.38, 0.30), 0.82)
    trim = material("trim_cream", (0.86, 0.78, 0.62), 0.65)
    red = material("awning_red", (0.62, 0.045, 0.03), 0.58)
    glass = material("window_tinted", (0.08, 0.18, 0.21), 0.25, 0.1)
    shutter = material("shutter_metal", (0.28, 0.30, 0.31), 0.42, 0.35)
    sign = material("sign_cream", (0.96, 0.85, 0.57), 0.64)
    dark = material("sign_dark", (0.12, 0.06, 0.035), 0.56)
    egg = material("egg_carton", (0.86, 0.69, 0.35), 0.78)

    cube("store_back_wall", (0.0, 2.4, 0.15), (8.0, 4.8, 0.24), wall, 0.06)
    cube("store_left_pillar", (-3.82, 2.4, -0.05), (0.36, 4.8, 0.50), trim, 0.03)
    cube("store_right_pillar", (3.82, 2.4, -0.05), (0.36, 4.8, 0.50), trim, 0.03)
    cube("awning_header", (0.0, 4.28, -0.42), (7.8, 0.72, 0.24), red, 0.04)
    for x in (-3.0, -1.8, -0.6, 0.6, 1.8, 3.0):
        cube("awning_fold_%s" % x, (x, 3.94, -0.55), (0.92, 0.20, 0.54), red if int(abs(x) * 10) % 2 else trim, 0.025)
    cube("window_left", (-2.35, 2.2, -0.36), (2.45, 1.95, 0.08), glass, 0.025)
    cube("window_right", (2.35, 2.2, -0.36), (2.45, 1.95, 0.08), glass, 0.025)
    cube("window_frame_mid", (0.0, 2.2, -0.42), (0.14, 2.12, 0.12), trim, 0.02)
    cube("counter", (0.0, 1.05, -0.65), (7.3, 0.24, 0.44), trim, 0.035)
    cube("roller_shutter", (0.0, 1.55, 0.03), (5.8, 2.65, 0.12), shutter, 0.025)
    for y in (0.45, 0.80, 1.15, 1.50, 1.85, 2.20, 2.55):
        cube("shutter_rib_%s" % y, (0.0, y, -0.10), (5.8, 0.035, 0.04), dark, 0.006)
    cube("sign_panel", (0.0, 4.32, -0.58), (5.5, 0.46, 0.06), sign, 0.02)
    text_object("sign_text", "鲜蛋铺", (0.0, 4.33, -0.63), 0.30, dark)
    for x in (-1.6, 0.0, 1.6):
        cube("display_crate_%s" % x, (x, 0.30, -0.80), (1.05, 0.36, 0.72), egg, 0.05)
        for dx in (-0.27, 0.0, 0.27):
            sphere("egg_%s_%s" % (x, dx), (x + dx, 0.56, -0.80), 0.10, sign, (0.85, 1.0, 1.12))

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0.0, 0.0, 0.0))
    root = bpy.context.object
    root.name = "Visual"
    for obj in list(bpy.context.scene.objects):
        if obj != root:
            obj.parent = root
    export_glb(os.path.join(OUTPUT_DIR, "environment", "city-storefront-preview.glb"))


if __name__ == "__main__":
    create_player()
    create_storefront()
    print("已生成原创视觉预览资产：", OUTPUT_DIR)

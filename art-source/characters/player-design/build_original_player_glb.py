import bpy
import math
import os
from mathutils import Vector


OUTPUT = "/Users/superjj/gamehub-mini-games/gta-reference-runtime/assets/characters/original-procedural-office-characters/original_player_visual_v1.glb"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.7, metallic: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return mat


def finish(obj: bpy.types.Object, mat: bpy.types.Material, bevel: float = 0.0) -> bpy.types.Object:
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new("柔和服装边缘", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = "ANGLE"
    if hasattr(obj.data, "polygons"):
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def cube(name: str, location: tuple[float, float, float], dimensions: tuple[float, float, float], mat: bpy.types.Material, bevel: float = 0.0) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel)


def sphere(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat)


def cylinder(name: str, location: tuple[float, float, float], radius: float, depth: float, mat: bpy.types.Material, rotation: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, mat, radius * 0.18)


def build() -> None:
    clear_scene()

    jacket = material("原创夹克深灰", (0.075, 0.095, 0.105, 1.0), 0.78)
    jacket_edge = material("原创夹克边缘", (0.16, 0.19, 0.20, 1.0), 0.68)
    shirt = material("原创红色内层", (0.34, 0.075, 0.065, 1.0), 0.74)
    skin = material("原创皮肤", (0.46, 0.25, 0.18, 1.0), 0.62)
    hair = material("原创黑色发束", (0.018, 0.022, 0.027, 1.0), 0.55)
    pants = material("原创工装裤", (0.055, 0.065, 0.075, 1.0), 0.84)
    backpack = material("原创背包", (0.045, 0.055, 0.060, 1.0), 0.88)
    backpack_edge = material("原创背包皮带", (0.20, 0.14, 0.09, 1.0), 0.76)
    sole = material("原创鞋底", (0.025, 0.032, 0.038, 1.0), 0.58)
    rubber = material("原创鞋面", (0.12, 0.15, 0.16, 1.0), 0.68)
    metal = material("原创拉链与扣件", (0.45, 0.31, 0.17, 1.0), 0.32, 0.25)
    eye = material("原创眼睛", (0.008, 0.010, 0.012, 1.0), 0.22)

    # 身体比例按参考板的成人写实比例压缩到约 1.9 米，脚底位于 Y=0。
    cube("AdvancedBody", (0.0, 1.18, 0.0), (0.72, 0.86, 0.48), jacket, 0.13)
    cube("AdvancedShirtFront", (0.0, 1.23, -0.255), (0.34, 0.52, 0.035), shirt, 0.025)
    cube("AdvancedJacketHem", (0.0, 0.78, 0.0), (0.78, 0.18, 0.52), jacket_edge, 0.06)
    cube("AdvancedZipper", (0.0, 1.24, -0.285), (0.025, 0.42, 0.018), metal, 0.006)
    cube("AdvancedCollarLeft", (-0.12, 1.48, -0.255), (0.22, 0.11, 0.035), jacket_edge, 0.018)
    cube("AdvancedCollarRight", (0.12, 1.48, -0.255), (0.22, 0.11, 0.035), jacket_edge, 0.018)

    # 低矮分段兜帽，避免形成遮挡头部的球状黑块。
    hood_back = cube("AdvancedHoodBack", (0.0, 1.61, 0.19), (0.66, 0.55, 0.16), jacket, 0.12)
    hood_back.rotation_euler.x = math.radians(-10.0)
    hood_left = cube("AdvancedHoodLeft", (-0.27, 1.58, 0.04), (0.13, 0.42, 0.18), jacket_edge, 0.055)
    hood_left.rotation_euler.z = math.radians(-12.0)
    hood_right = cube("AdvancedHoodRight", (0.27, 1.58, 0.04), (0.13, 0.42, 0.18), jacket_edge, 0.055)
    hood_right.rotation_euler.z = math.radians(12.0)

    sphere("AdvancedHead", (0.0, 1.78, -0.005), (0.235, 0.285, 0.225), skin)
    cylinder("AdvancedNeck", (0.0, 1.56, 0.0), 0.105, 0.18, skin)
    # 发束由多个受控椭球组成，保持侧面和后脑轮廓而不遮住脸。
    sphere("AdvancedHairTop", (0.0, 1.98, 0.03), (0.235, 0.105, 0.22), hair)
    sphere("AdvancedHairLeft", (-0.19, 1.91, 0.015), (0.09, 0.16, 0.19), hair)
    sphere("AdvancedHairRight", (0.19, 1.91, 0.015), (0.09, 0.16, 0.19), hair)
    sphere("AdvancedHairBack", (0.0, 1.88, 0.17), (0.20, 0.16, 0.08), hair)
    for side in (-1.0, 1.0):
        sphere("AdvancedEye" + ("L" if side < 0 else "R"), (side * 0.082, 1.81, -0.215), (0.022, 0.014, 0.010), eye)
        sphere("AdvancedEar" + ("L" if side < 0 else "R"), (side * 0.225, 1.78, 0.0), (0.045, 0.072, 0.035), skin)
    sphere("AdvancedNose", (0.0, 1.77, -0.232), (0.028, 0.032, 0.052), skin)

    # 肩、手臂和手掌使用平滑椭球，避免原候选的圆柱断面。
    for side in (-1.0, 1.0):
        label = "L" if side < 0 else "R"
        sphere("AdvancedUpperArm" + label, (side * 0.43, 1.04, 0.0), (0.14, 0.38, 0.14), jacket)
        sphere("AdvancedForearm" + label, (side * 0.51, 0.76, -0.025), (0.115, 0.31, 0.115), jacket_edge)
        sphere("AdvancedHand" + label, (side * 0.55, 0.54, -0.045), (0.095, 0.115, 0.09), skin)
        sphere("AdvancedLeg" + label, (side * 0.17, 0.42, 0.0), (0.145, 0.43, 0.16), pants)
        cube("AdvancedCargoPocket" + label, (side * 0.17, 0.48, -0.155), (0.22, 0.20, 0.045), jacket_edge, 0.018)
        cube("AdvancedCargoPocketFlap" + label, (side * 0.17, 0.59, -0.18), (0.23, 0.035, 0.055), backpack_edge, 0.008)
        cube("AdvancedShoe" + label, (side * 0.17, 0.105, -0.12), (0.30, 0.18, 0.48), rubber, 0.065)
        cube("AdvancedSole" + label, (side * 0.17, 0.035, -0.12), (0.33, 0.06, 0.52), sole, 0.02)

    cube("AdvancedBackpack", (0.0, 1.12, 0.29), (0.56, 0.70, 0.18), backpack, 0.10)
    cube("AdvancedBackpackFlap", (0.0, 1.48, 0.25), (0.48, 0.13, 0.22), backpack_edge, 0.045)
    for side in (-1.0, 1.0):
        label = "L" if side < 0 else "R"
        strap = cube("AdvancedStrap" + label, (side * 0.24, 1.21, 0.16), (0.07, 0.58, 0.035), backpack_edge, 0.012)
        strap.rotation_euler.z = math.radians(side * -5.0)
        cube("AdvancedSidePocket" + label, (side * 0.31, 1.07, 0.31), (0.13, 0.25, 0.16), backpack, 0.025)
    cube("AdvancedBadge", (0.0, 1.30, -0.285), (0.13, 0.17, 0.025), metal, 0.01)

    root = bpy.data.objects.new("OriginalPlayerVisual", None)
    bpy.context.collection.objects.link(root)
    for obj in list(bpy.context.scene.objects):
        if obj != root:
            obj.parent = root
    root["asset_source"] = "project_original_blender_generated"
    root["reference_board"] = "art-source/characters/player-design/new-era-awakener-player-turnaround-v1-generated.png"
    root["unit_scale"] = "1 Blender unit = 1 meter"
    root["forward_axis"] = "-Z"
    root["visual_status"] = "candidate_only"

    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT,
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_materials="EXPORT",
        export_normals=True,
        export_texcoords=True,
    )
    print(f"已导出原创主角三维候选：{OUTPUT}")


if __name__ == "__main__":
    build()

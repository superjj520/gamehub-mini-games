"""为新时代觉醒者生成可独立导出的角色服装候选网格。

源角色使用 Quaternius 基础网格和骨架；本脚本只增加本项目原创服装、背包、鞋和短发。
服装网格以骨骼父子关系挂载，导出后仍使用米制、脚底原点和 glTF Y-up 约定。
"""

from __future__ import annotations

import bpy
from mathutils import Vector


SOURCE_GLB = "gta-reference-runtime/assets/characters/quaternius-superhero-male/character.glb"
OUTPUT_GLB = "gta-reference-runtime/assets/characters/quaternius-superhero-male/character_outfitted.glb"
OUTPUT_BLEND = "art-source/characters/quaternius-superhero-male/character_outfitted.blend"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float, float], roughness: float = 0.65, metallic: float = 0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return mat


def finish_mesh(obj, mat, bevel: float = 0.0):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("服装圆角", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(mat)
    obj.select_set(False)
    return obj


def box(name: str, location: tuple[float, float, float], dimensions: tuple[float, float, float], mat, bevel: float = 0.03):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    return finish_mesh(obj, mat, bevel)


def rounded_body(name: str, location: tuple[float, float, float], scale: tuple[float, float, float], mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish_mesh(obj, mat, 0.0)


def parent_to_bone(obj, armature, bone_name: str):
    world_matrix = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world_matrix


def create_outfit(armature):
    jacket = material("原创夹克深蓝", (0.075, 0.13, 0.18, 1.0), 0.58, 0.05)
    trim = material("原创夹克蓝灰滚边", (0.24, 0.42, 0.50, 1.0), 0.46, 0.04)
    shirt = material("原创衬衣浅灰", (0.70, 0.78, 0.77, 1.0), 0.72, 0.0)
    trousers = material("原创长裤炭黑", (0.055, 0.075, 0.10, 1.0), 0.76, 0.02)
    shoes = material("原创鞋面黑色", (0.025, 0.035, 0.045, 1.0), 0.62, 0.10)
    backpack = material("原创背包蓝黑", (0.035, 0.12, 0.18, 1.0), 0.68, 0.06)
    badge = material("原创胸牌金色", (0.72, 0.48, 0.17, 1.0), 0.38, 0.18)
    hair = material("原创短发黑色", (0.018, 0.022, 0.028, 1.0), 0.82, 0.0)

    parts = []
    parts.append((rounded_body("Outfit_Torso", (0.0, 0.0, 1.15), (0.38, 0.28, 0.43), jacket), "spine_02"))
    parts.append((rounded_body("Outfit_ShoulderShell", (0.0, 0.0, 1.49), (0.40, 0.29, 0.20), jacket), "spine_03"))
    parts.append((box("Outfit_ShirtFront", (0.0, -0.30, 1.23), (0.32, 0.035, 0.34), shirt, 0.012), "spine_03"))
    parts.append((box("Outfit_ShirtCollar", (0.0, -0.32, 1.43), (0.20, 0.04, 0.07), shirt, 0.012), "spine_03"))
    parts.append((box("Outfit_WaistTrim", (0.0, -0.01, 0.89), (0.66, 0.48, 0.09), trim, 0.02), "pelvis"))
    parts.append((box("Outfit_Badge", (0.18, -0.33, 1.25), (0.11, 0.025, 0.12), badge, 0.01), "spine_03"))
    parts.append((box("Outfit_Backpack", (0.0, 0.29, 1.14), (0.44, 0.18, 0.56), backpack, 0.06), "spine_01"))
    parts.append((box("Outfit_BackpackFlap", (0.0, 0.22, 1.45), (0.42, 0.20, 0.11), trim, 0.03), "spine_01"))

    for side, suffix in ((1.0, "L"), (-1.0, "R")):
        parts.append((rounded_body(f"Outfit_Sleeve_{suffix}", (0.39 * side, 0.0, 1.40), (0.17, 0.17, 0.30), jacket), f"upperarm_{suffix.lower()}"))
        parts.append((rounded_body(f"Outfit_Trousers_{suffix}", (0.115 * side, 0.0, 0.54), (0.145, 0.17, 0.34), trousers), f"thigh_{suffix.lower()}"))
        parts.append((box(f"Outfit_Shoe_{suffix}", (0.115 * side, -0.07, 0.09), (0.23, 0.38, 0.14), shoes, 0.035), f"foot_{suffix.lower()}"))

    parts.append((rounded_body("Outfit_Hair", (0.0, 0.0, 1.82), (0.24, 0.20, 0.12), hair), "Head"))
    for obj, bone in parts:
        parent_to_bone(obj, armature, bone)


def main():
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=SOURCE_GLB)
    armature = bpy.data.objects.get("Armature")
    if armature is None:
        raise RuntimeError("源角色 GLB 缺少 Armature")
    create_outfit(armature)
    bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_BLEND)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT_GLB,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_animations=True,
        export_skins=True,
        export_materials="EXPORT",
    )
    print(f"原创角色服装 GLB 已生成：{OUTPUT_GLB}")


if __name__ == "__main__":
    main()

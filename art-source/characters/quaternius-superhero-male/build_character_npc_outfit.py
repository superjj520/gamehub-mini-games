"""生成办公室巡查 NPC 的原创制服 GLB，使用与主角相同的 CC0 骨架但不带背包。"""

from __future__ import annotations

import bpy


SOURCE_GLB = "gta-reference-runtime/assets/characters/quaternius-superhero-male/character.glb"
OUTPUT_GLB = "gta-reference-runtime/assets/characters/quaternius-superhero-male/character_npc_outfitted.glb"
OUTPUT_BLEND = "art-source/characters/quaternius-superhero-male/character_npc_outfitted.blend"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def make_material(name: str, color: tuple[float, float, float, float], roughness: float, metallic: float = 0.0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = color
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    return material


def finish(obj, material, bevel: float = 0.0):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        modifier = obj.modifiers.new("制服圆角", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        modifier.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    obj.select_set(False)
    return obj


def box(name, location, dimensions, material, bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    return finish(obj, material, bevel)


def rounded(name, location, scale, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    return finish(obj, material)


def bone_parent(obj, armature, bone):
    matrix = obj.matrix_world.copy()
    obj.parent = armature
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = matrix


def main():
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=SOURCE_GLB)
    armature = bpy.data.objects.get("Armature")
    if armature is None:
        raise RuntimeError("源角色 GLB 缺少 Armature")

    uniform = make_material("原创NPC制服蓝灰", (0.20, 0.28, 0.34, 1.0), 0.62, 0.02)
    trim = make_material("原创NPC制服金色滚边", (0.68, 0.48, 0.18, 1.0), 0.40, 0.12)
    shirt = make_material("原创NPC衬衣浅灰", (0.76, 0.81, 0.79, 1.0), 0.72)
    trousers = make_material("原创NPC长裤炭黑", (0.06, 0.07, 0.09, 1.0), 0.76, 0.02)
    shoes = make_material("原创NPC鞋面黑色", (0.025, 0.032, 0.04, 1.0), 0.62, 0.10)
    hair = make_material("原创NPC短发黑色", (0.015, 0.018, 0.022, 1.0), 0.82)

    parts = [
        (rounded("Outfit_Torso", (0.0, 0.0, 1.15), (0.38, 0.28, 0.43), uniform), "spine_02"),
        (rounded("Outfit_ShoulderShell", (0.0, 0.0, 1.49), (0.40, 0.29, 0.20), uniform), "spine_03"),
        (box("Outfit_ShirtFront", (0.0, -0.30, 1.23), (0.32, 0.035, 0.34), shirt, 0.012), "spine_03"),
        (box("Outfit_ShirtCollar", (0.0, -0.32, 1.43), (0.20, 0.04, 0.07), shirt, 0.012), "spine_03"),
        (box("Outfit_WaistTrim", (0.0, -0.01, 0.89), (0.66, 0.48, 0.09), trim, 0.02), "pelvis"),
        (box("Outfit_Badge", (0.18, -0.33, 1.25), (0.11, 0.025, 0.12), trim, 0.01), "spine_03"),
        (rounded("Outfit_Hair", (0.0, 0.0, 1.82), (0.24, 0.20, 0.12), hair), "Head"),
    ]
    for side, suffix in ((1.0, "L"), (-1.0, "R")):
        parts.append((rounded(f"Outfit_Sleeve_{suffix}", (0.39 * side, 0.0, 1.40), (0.17, 0.17, 0.30), uniform), f"upperarm_{suffix.lower()}"))
        parts.append((rounded(f"Outfit_Trousers_{suffix}", (0.115 * side, 0.0, 0.54), (0.145, 0.17, 0.34), trousers), f"thigh_{suffix.lower()}"))
        parts.append((box(f"Outfit_Shoe_{suffix}", (0.115 * side, -0.07, 0.09), (0.23, 0.38, 0.14), shoes, 0.035), f"foot_{suffix.lower()}"))
    for obj, bone in parts:
        bone_parent(obj, armature, bone)

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
    print(f"原创NPC制服 GLB 已生成：{OUTPUT_GLB}")


if __name__ == "__main__":
    main()

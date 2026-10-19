"""使用 MPFB2 生成可追溯的人物候选，并导出为 Godot 可消费的 GLB。

该脚本只属于资产生产工具，不会被复制进游戏运行时或发布包。生成结果在进入
候选登记前仍需完成许可证、运行时契约、固定镜头和人工视觉验收。
"""

import importlib
import os
import sys
import traceback

import bpy


MPFB_SOURCE = os.environ["MPFB_SOURCE"]
ASSET_ROOT = os.environ["MPFB_ASSET_ROOT"]
OUTPUT_GLB = os.environ["MPFB_OUTPUT_GLB"]
OUTPUT_OBJ = os.environ.get("MPFB_OUTPUT_OBJ", "")
OUTPUT_DAE = os.environ.get("MPFB_OUTPUT_DAE", "")
CLOTHING_ASSET = os.environ.get("MPFB_CLOTHING_ASSET", "male_worksuit01.mhclo")
HAIR_ASSET = os.environ.get("MPFB_HAIR_ASSET", "short02.mhclo")

with open("/private/tmp/new-age-makehuman/mpfb-env.txt", "w", encoding="utf-8") as _env_handle:
    _env_handle.write(repr({"source": MPFB_SOURCE, "assets": ASSET_ROOT, "glb": OUTPUT_GLB, "obj": OUTPUT_OBJ, "dae": OUTPUT_DAE, "clothing": CLOTHING_ASSET, "hair": HAIR_ASSET}))


def _dynamic_import(module_suffix, symbol):
    """兼容 MPFB 从 Blender 外部源码路径加载时的包名差异。"""
    for module_name in list(sys.modules):
        if module_name.endswith(module_suffix):
            module = importlib.import_module(module_name)
            return getattr(module, symbol)
    raise RuntimeError(f"未找到 MPFB 模块或符号：{module_suffix}.{symbol}")


def _reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def main():
    sys.path.insert(0, MPFB_SOURCE)
    # Blender 5.2 的扩展 API 不接受源码包名；资产生产工具使用隔离的临时用户目录。
    bpy.utils.extension_path_user = lambda _package: "/private/tmp/new-age-makehuman/mpfb-user"
    sys.path.insert(0, MPFB_SOURCE)
    mpfb = importlib.import_module("mpfb")
    preferences = {
        "mpfb_user_data": "/private/tmp/new-age-makehuman/mpfb-user",
        "mpfb_second_root": os.path.abspath(ASSET_ROOT),
        "mh_user_data": "",
        "mh_auto_user_data": False,
        "mpfb_shelf_label": "",
        "mpfb_codechecks": False,
    }
    mpfb.get_preference = lambda name: preferences.get(name)
    # 让 Blender 建立真实的插件偏好节点；服务初始化阶段会读取它。
    enabled = bpy.ops.preferences.addon_enable(module="mpfb")
    if "mpfb" not in bpy.context.preferences.addons:
        raise RuntimeError(f"MPFB 插件启用失败：{enabled}")

    from mpfb.services import AssetService, ExportService, HumanService, LocationService, ObjectService

    # MPFB 的生产 API 会从 LocationService 的第二资产根扫描 CC0 资产包。
    LocationService._second_root = os.path.abspath(ASSET_ROOT)
    if not os.path.isdir(LocationService._second_root):
        raise RuntimeError(f"人物资产根目录不存在：{LocationService._second_root}")

    _reset_scene()
    basemesh = HumanService.create_human(feet_on_ground=True, scale=0.1)

    skin_path = AssetService.find_asset_absolute_path("young_caucasian_male.mhmat", asset_subdir="skins")
    if not skin_path:
        raise RuntimeError("没有找到 young_caucasian_male.mhmat")
    HumanService.set_character_skin(skin_path, basemesh, skin_type="GAMEENGINE")
    HumanService.add_builtin_rig(basemesh, "game_engine")

    # 这些都是官方系统资产包中的 CC0 候选；服装暂选工作服，贴合办公室 NPC 场景。
    asset_specs = [
        ("eyes", "low-poly.mhclo", "Eyes"),
        ("eyebrows", "eyebrow001.mhclo", "Eyebrows"),
        ("eyelashes", "eyelashes01.mhclo", "Eyelashes"),
        ("hair", HAIR_ASSET, "Hair"),
        ("teeth", "teeth_base.mhclo", "Teeth"),
        ("clothes", CLOTHING_ASSET, "Clothes"),
        ("clothes", "shoes02.mhclo", "Clothes"),
    ]
    for asset_subdir, filename, asset_type in asset_specs:
        asset_path = AssetService.find_asset_absolute_path(filename, asset_subdir=asset_subdir)
        if not asset_path:
            print(f"跳过缺失资产：{asset_subdir}/{filename}")
            continue
        HumanService.add_mhclo_asset(asset_path, basemesh, asset_type=asset_type, material_type="GAMEENGINE")

    export_root = ExportService.create_character_copy(basemesh, name_suffix="_export")
    export_basemesh = ObjectService.find_object_of_type_amongst_nearest_relatives(export_root, "Basemesh")
    ExportService.bake_modifiers_remove_helpers(
        export_basemesh,
        bake_masks=True,
        bake_subdiv=True,
        remove_helpers=True,
        also_proxy=True,
    )

    bpy.ops.object.select_all(action="DESELECT")
    export_root.select_set(True)
    for child in ObjectService.get_list_of_children(export_root):
        child.select_set(True)
    bpy.context.view_layer.objects.active = export_root

    output_dir = os.path.dirname(os.path.abspath(OUTPUT_GLB))
    os.makedirs(output_dir, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(OUTPUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_image_format="AUTO",
    )
    print(f"人物候选已导出：{os.path.abspath(OUTPUT_GLB)}")

    if OUTPUT_OBJ:
        obj_dir = os.path.dirname(os.path.abspath(OUTPUT_OBJ))
        os.makedirs(obj_dir, exist_ok=True)
        bpy.ops.wm.obj_export(
            filepath=os.path.abspath(OUTPUT_OBJ),
            export_materials=True,
            export_normals=True,
            export_uv=True,
            export_selected_objects=True,
            path_mode="COPY",
        )
        print(f"人物候选 OBJ 已导出：{os.path.abspath(OUTPUT_OBJ)}")

    if OUTPUT_DAE:
        dae_dir = os.path.dirname(os.path.abspath(OUTPUT_DAE))
        os.makedirs(dae_dir, exist_ok=True)
        bpy.ops.wm.collada_export(
            filepath=os.path.abspath(OUTPUT_DAE),
            selected=True,
            include_armatures=True,
            include_shapekeys=False,
            include_material_textures=True,
        )
        print(f"人物候选 DAE 已导出：{os.path.abspath(OUTPUT_DAE)}")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        error_path = "/private/tmp/new-age-makehuman/mpfb-generation-error.txt"
        with open(error_path, "w", encoding="utf-8") as handle:
            traceback.print_exc(file=handle)
        raise

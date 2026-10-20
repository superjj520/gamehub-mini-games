"""在无 Blender 图形后端时生成原创三轮配送车的最终资产候选。

复用项目已有的无外部依赖 GLB 几何生成器，但把输出隔离到 final-candidate，
绝不覆盖正式运行时资产；资产仍需 Godot 运行时截图、行为和目标设备验收。
"""

from __future__ import annotations

import importlib.util
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(__file__).with_name("build_three_wheel_delivery_glb.py")
OUTPUT_DIR = Path(__file__).with_name("final-candidate")
OUTPUT_GLB = OUTPUT_DIR / "three_wheel_delivery_final_candidate.glb"
CARD_PATH = OUTPUT_DIR / "asset-card.json"


def load_builder():
    spec = importlib.util.spec_from_file_location("three_wheel_delivery_builder", SOURCE)
    if spec is None or spec.loader is None:
        raise RuntimeError("无法加载三轮配送车无外部依赖生成器")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.OUTPUT_DIR = OUTPUT_DIR
    module.OUTPUT_GLB = OUTPUT_GLB
    original_material = module.Builder.material

    def budgeted_material(self, name, color, roughness, metallic=0.0, alpha=1.0, emission=None):
        """把候选车体压到项目车辆预算的五个材质槽内。

        这是技术预算候选，不宣称已经完成最终写实材质；正式美术仍需在 DCC 中制作并验收。
        """
        palettes = {
            "车体蓝": ("车体蓝", (0.114, 0.384, 0.522), 0.36, 0.16, 1.0, None),
            "安全黄": ("安全黄", (0.80, 0.49, 0.10), 0.34, 0.05, 1.0, None),
            "轮胎橡胶": ("轮胎橡胶", (0.012, 0.016, 0.021), 0.88, 0.0, 1.0, None),
            "结构金属": ("结构金属", (0.26, 0.31, 0.35), 0.28, 0.55, 1.0, None),
            "座椅皮革": ("座椅皮革", (0.12, 0.095, 0.09), 0.72, 0.0, 1.0, None),
        }
        if name in {"车体蓝", "车体深蓝"}:
            palette = palettes["车体蓝"]
        elif name in {"安全黄", "转向灯"}:
            palette = palettes["安全黄"]
        elif name == "轮胎橡胶":
            palette = palettes["轮胎橡胶"]
        elif name in {"结构金属", "挡风玻璃", "车牌"}:
            palette = palettes["结构金属"]
        else:
            palette = palettes["座椅皮革"]
        return original_material(self, *palette)

    module.Builder.material = budgeted_material

    original_build_glb = module.Builder.build_glb

    def build_with_final_details(self):
        """为原创候选补齐开放货斗和驾驶舱的可读性细节。"""
        if getattr(self, "_final_details_added", False):
            return original_build_glb(self)
        self._final_details_added = True

        blue = self.material("车体蓝", (0.114, 0.384, 0.522), 0.36, 0.16)
        yellow = self.material("安全黄", (0.80, 0.49, 0.10), 0.34, 0.05)
        rubber = self.material("轮胎橡胶", (0.012, 0.016, 0.021), 0.88)
        metal = self.material("结构金属", (0.26, 0.31, 0.35), 0.28, 0.55)
        seat = self.material("座椅皮革", (0.12, 0.095, 0.09), 0.72)
        # 保留运行时资产检查与挂点系统使用的语义节点；节点本身不增加渲染几何。
        if "候选三轮车货箱" not in self.semantic_nodes:
            self.semantic_nodes.append("候选三轮车货箱")

        def box(name, size, location, material, rotation=(0.0, 0.0, 0.0)):
            self.add(name, module.box_geometry(size), location, material, rotation)

        def cylinder(name, location, radius, depth, material, rotation=(0.0, 0.0, 0.0), segments=16):
            self.add(name, module.cylinder_geometry(radius, depth, segments), location, material, rotation)

        # 货斗上沿和立柱：保持开放结构，不增加顶篷或整块挡风玻璃。
        for side in (-1.0, 1.0):
            side_label = "左" if side < 0 else "右"
            for depth_label, z in (("前", 0.22), ("后", 1.12)):
                cylinder(f"候选三轮车货斗{side_label}{depth_label}立柱", (side * 0.59, 0.62, z), 0.035, 0.62, metal, (math.pi / 2.0, 0.0, 0.0), 12)
            box(f"候选三轮车货斗{side_label}上沿", (0.05, 0.05, 0.96), (side * 0.59, 0.70, 0.67), metal)
        box("候选三轮车货斗后上沿", (1.18, 0.05, 0.05), (0.0, 0.70, 1.12), metal)

        # 车体侧裙和脚踏，强化驾驶位的尺度关系。
        for side in (-1.0, 1.0):
            side_label = "左" if side < 0 else "右"
            box(f"候选三轮车{side_label}侧裙", (0.07, 0.24, 1.52), (side * 0.82, 0.02, -0.10), blue)
            box(f"候选三轮车{side_label}脚踏", (0.34, 0.06, 0.52), (side * 0.70, -0.10, -0.20), rubber)
            box(f"候选三轮车{side_label}侧防护条", (0.045, 0.08, 1.38), (side * 0.86, 0.24, 0.05), metal)

        # 驾驶舱细节、前灯外壳和尾部灯组。
        box("候选三轮车仪表台", (0.62, 0.12, 0.18), (0.0, 0.72, -0.70), metal)
        box("候选三轮车仪表屏", (0.28, 0.035, 0.08), (0.0, 0.80, -0.79), yellow)
        box("候选三轮车前灯外壳", (0.52, 0.16, 0.12), (0.0, 0.55, -1.12), metal)
        box("候选三轮车前保险杠", (0.98, 0.08, 0.08), (0.0, 0.17, -1.18), metal)
        box("候选三轮车左尾灯", (0.16, 0.08, 0.08), (-0.48, 0.34, 1.30), yellow)
        box("候选三轮车右尾灯", (0.16, 0.08, 0.08), (0.48, 0.34, 1.30), yellow)
        box("候选三轮车尾部反光条", (0.72, 0.035, 0.035), (0.0, 0.43, 1.29), yellow)

        # 货物固定带和座椅底部结构，使开放货斗不再是单层盒体。
        box("候选三轮车货斗前固定带", (1.02, 0.045, 0.045), (0.0, 0.72, 0.23), yellow)
        box("候选三轮车货斗后固定带", (1.02, 0.045, 0.045), (0.0, 0.72, 1.08), yellow)
        box("候选三轮车座椅底座", (0.74, 0.09, 0.46), (0.0, 0.20, -0.08), metal)
        box("候选三轮车座椅靠背包边", (0.76, 0.045, 0.05), (0.0, 0.74, 0.25), seat)

        return original_build_glb(self)

    module.Builder.build_glb = build_with_final_details
    return module


def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    module = load_builder()
    module.build()
    runtime_sha256 = hashlib.sha256(OUTPUT_GLB.read_bytes()).hexdigest()
    CARD_PATH.write_text(json.dumps({
        "schema_version": 1,
        "asset_id": "three-wheel-delivery-final-candidate-detailed-v2",
        "category": "vehicles",
        "source": {
            "type": "original_procedural_generation",
            "source_file": "art-source/vehicles/three-wheel-delivery/build_three_wheel_delivery_glb.py",
            "license": "原创生成，项目方自有候选源",
        },
        "conventions": {
            "unit": "meter",
            "up_axis": "+Y",
            "forward_axis": "-Z",
            "pivot": "body_center",
        },
        "technical_budget_variant": "five_material_slots_detailed_v2",
        "runtime_file": "art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.glb",
        "runtime_sha256": runtime_sha256,
        "release_allowed": False,
        "visual_status": "unverified",
        "remaining_acceptance": ["当前 Godot 图形运行时截图", "Windows 10/11 性能", "产品负责人视觉签收", "正式候选场景挂载与版本绑定"],
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"原创三轮配送车最终资产候选已生成：{OUTPUT_GLB}")


if __name__ == "__main__":
    main()

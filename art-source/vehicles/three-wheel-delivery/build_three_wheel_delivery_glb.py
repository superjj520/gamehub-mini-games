"""用无外部依赖的几何生成器导出三轮配送车 GLB 候选。

坐标约定与项目一致：米制、+Y 向上、局部 -Z 为车头，原点位于车体几何中心。
这是 DCC 不可用时的可重复候选生成器，不代表最终写实资产。
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
OUTPUT_DIR = ROOT / "gta-reference-runtime/assets/vehicles/three-wheel-delivery"
OUTPUT_GLB = OUTPUT_DIR / "three_wheel_delivery.glb"


def quaternion_xyz(euler):
    x, y, z = (value * 0.5 for value in euler)
    cx, sx = math.cos(x), math.sin(x)
    cy, sy = math.cos(y), math.sin(y)
    cz, sz = math.cos(z), math.sin(z)
    return [
        sx * cy * cz - cx * sy * sz,
        cx * sy * cz + sx * cy * sz,
        cx * cy * sz - sx * sy * cz,
        cx * cy * cz + sx * sy * sz,
    ]


def box_geometry(size):
    sx, sy, sz = (value * 0.5 for value in size)
    faces = [
        ((0.0, 0.0, 1.0), [(-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]),
        ((0.0, 0.0, -1.0), [(sx, -sy, -sz), (-sx, -sy, -sz), (-sx, sy, -sz), (sx, sy, -sz)]),
        ((1.0, 0.0, 0.0), [(sx, -sy, sz), (sx, -sy, -sz), (sx, sy, -sz), (sx, sy, sz)]),
        ((-1.0, 0.0, 0.0), [(-sx, -sy, -sz), (-sx, -sy, sz), (-sx, sy, sz), (-sx, sy, -sz)]),
        ((0.0, 1.0, 0.0), [(-sx, sy, sz), (sx, sy, sz), (sx, sy, -sz), (-sx, sy, -sz)]),
        ((0.0, -1.0, 0.0), [(-sx, -sy, -sz), (-sx, -sy, sz), (sx, -sy, sz), (sx, -sy, -sz)]),
    ]
    positions, normals, indices = [], [], []
    for normal, corners in faces:
        start = len(positions)
        positions.extend(corners)
        normals.extend([normal] * 4)
        indices.extend([start, start + 1, start + 2, start, start + 2, start + 3])
    return positions, normals, indices


def cylinder_geometry(radius, depth, segments=24):
    half = depth * 0.5
    positions, normals, indices = [], [], []
    for side in (1, -1):
        z = half * side
        start = len(positions)
        center = len(positions)
        positions.append((0.0, 0.0, z))
        normals.append((0.0, 0.0, float(side)))
        ring_start = len(positions)
        for index in range(segments):
            angle = math.tau * index / segments
            positions.append((radius * math.cos(angle), radius * math.sin(angle), z))
            normals.append((0.0, 0.0, float(side)))
        for index in range(segments):
            current = ring_start + index
            following = ring_start + ((index + 1) % segments)
            if side > 0:
                indices.extend([center, current, following])
            else:
                indices.extend([center, following, current])

    side_start = len(positions)
    for index in range(segments):
        angle = math.tau * index / segments
        x, y = radius * math.cos(angle), radius * math.sin(angle)
        positions.extend([(x, y, -half), (x, y, half)])
        normals.extend([(math.cos(angle), math.sin(angle), 0.0)] * 2)
    for index in range(segments):
        current = side_start + index * 2
        following = side_start + ((index + 1) % segments) * 2
        indices.extend([current, following, following + 1, current, following + 1, current + 1])
    return positions, normals, indices


class Builder:
    def __init__(self):
        self.materials = []
        self.material_lookup = {}
        self.objects = []
        self.semantic_nodes = []

    def material(self, name, color, roughness, metallic=0.0, alpha=1.0, emission=None):
        key = (name, tuple(color), roughness, metallic, alpha, tuple(emission or ()))
        if key in self.material_lookup:
            return self.material_lookup[key]
        payload = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [*color, alpha],
                "metallicFactor": metallic,
                "roughnessFactor": roughness,
            },
        }
        if alpha < 1.0:
            payload.update({"alphaMode": "BLEND", "doubleSided": True})
        if emission is not None:
            payload["emissiveFactor"] = list(emission)
        index = len(self.materials)
        self.materials.append(payload)
        self.material_lookup[key] = index
        return index

    def add(self, name, geometry, location, material, rotation=(0.0, 0.0, 0.0)):
        positions, normals, indices = geometry
        self.objects.append({
            "name": name,
            "positions": positions,
            "normals": normals,
            "indices": indices,
            "location": list(location),
            "rotation": quaternion_xyz(rotation),
            "material": material,
        })

    def build_glb(self):
        binary = bytearray()
        buffer_views = []
        accessors = []
        meshes = []
        nodes = [{"name": "ThreeWheelDelivery", "children": []}]

        def append_bytes(data, target=None):
            while len(binary) % 4:
                binary.append(0)
            offset = len(binary)
            binary.extend(data)
            view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
            if target is not None:
                view["target"] = target
            index = len(buffer_views)
            buffer_views.append(view)
            return index

        for item in self.objects:
            pos_bytes = b"".join(struct.pack("<fff", *value) for value in item["positions"])
            normal_bytes = b"".join(struct.pack("<fff", *value) for value in item["normals"])
            index_bytes = b"".join(struct.pack("<H", value) for value in item["indices"])
            pos_view = append_bytes(pos_bytes, 34962)
            normal_view = append_bytes(normal_bytes, 34962)
            index_view = append_bytes(index_bytes, 34963)
            min_pos = [min(value[index] for value in item["positions"]) for index in range(3)]
            max_pos = [max(value[index] for value in item["positions"]) for index in range(3)]
            pos_accessor = len(accessors)
            accessors.append({"bufferView": pos_view, "componentType": 5126, "count": len(item["positions"]), "type": "VEC3", "min": min_pos, "max": max_pos})
            normal_accessor = len(accessors)
            accessors.append({"bufferView": normal_view, "componentType": 5126, "count": len(item["normals"]), "type": "VEC3"})
            index_accessor = len(accessors)
            accessors.append({"bufferView": index_view, "componentType": 5123, "count": len(item["indices"]), "type": "SCALAR"})
            mesh_index = len(meshes)
            meshes.append({
                "name": item["name"],
                "primitives": [{
                    "attributes": {"POSITION": pos_accessor, "NORMAL": normal_accessor},
                    "indices": index_accessor,
                    "material": item["material"],
                }],
            })
            node = {"name": item["name"], "mesh": mesh_index, "translation": item["location"], "rotation": item["rotation"]}
            nodes.append(node)
            nodes[0]["children"].append(len(nodes) - 1)

        for semantic_name in self.semantic_nodes:
            nodes.append({"name": semantic_name})
            nodes[0]["children"].append(len(nodes) - 1)

        document = {
            "asset": {"version": "2.0", "generator": "新时代觉醒者三轮车候选生成器"},
            "scene": 0,
            "scenes": [{"name": "ThreeWheelDeliveryScene", "nodes": [0]}],
            "nodes": nodes,
            "meshes": meshes,
            "materials": self.materials,
            "bufferViews": buffer_views,
            "accessors": accessors,
            "buffers": [{"byteLength": len(binary)}],
        }
        json_bytes = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
        binary += b"\x00" * ((4 - len(binary) % 4) % 4)
        total_length = 12 + 8 + len(json_bytes) + 8 + len(binary)
        return b"glTF" + struct.pack("<II", 2, total_length) + struct.pack("<I4s", len(json_bytes), b"JSON") + json_bytes + struct.pack("<I4s", len(binary), b"BIN\x00") + binary


def build():
    builder = Builder()
    blue = builder.material("车体蓝", (0.114, 0.384, 0.522), 0.36, 0.16)
    blue_dark = builder.material("车体深蓝", (0.047, 0.145, 0.20), 0.48, 0.10)
    yellow = builder.material("安全黄", (0.80, 0.49, 0.10), 0.34, 0.05)
    rubber = builder.material("轮胎橡胶", (0.012, 0.016, 0.021), 0.88)
    metal = builder.material("结构金属", (0.26, 0.31, 0.35), 0.28, 0.55)
    glass = builder.material("挡风玻璃", (0.18, 0.54, 0.62), 0.18, 0.05, 0.52)
    fabric = builder.material("顶篷织物", (0.62, 0.44, 0.20), 0.82)
    seat = builder.material("座椅皮革", (0.12, 0.095, 0.09), 0.72)
    indicator = builder.material("转向灯", (0.95, 0.63, 0.16), 0.24, emission=(0.42, 0.18, 0.02))
    plate = builder.material("车牌", (0.86, 0.79, 0.55), 0.58)

    def box(name, size, location, material, rotation=(0.0, 0.0, 0.0)):
        builder.add(name, box_geometry(size), location, material, rotation)

    def cylinder(name, location, radius, depth, material, rotation=(0.0, 0.0, 0.0), segments=24):
        builder.add(name, cylinder_geometry(radius, depth, segments), location, material, rotation)

    # 对齐参考视频的第一识别特征：低矮蓝色车身、开放后货斗、驾驶员无遮挡。
    # 顶篷和整块挡风玻璃不再作为候选视觉的一部分，避免把车辆误读成封闭式观光车。
    box("候选三轮车车体", (1.64, 0.44, 2.30), (0.0, -0.02, 0.0), blue)
    box("候选三轮车底盘", (1.48, 0.16, 2.52), (0.0, -0.30, 0.03), blue_dark)
    box("候选三轮车前挡板", (1.22, 0.34, 0.58), (0.0, 0.30, -0.78), blue)
    box("候选三轮车前饰条", (1.08, 0.10, 0.40), (0.0, 0.52, -0.68), blue_dark)
    box("候选三轮车货斗底板", (1.24, 0.10, 0.92), (0.0, 0.25, 0.67), blue_dark)
    box("候选三轮车货斗左栏", (0.07, 0.24, 0.92), (-0.59, 0.40, 0.67), metal)
    box("候选三轮车货斗右栏", (0.07, 0.24, 0.92), (0.59, 0.40, 0.67), metal)
    box("候选三轮车货斗后栏", (1.24, 0.24, 0.07), (0.0, 0.40, 1.11), metal)
    box("候选三轮车货斗门板", (1.14, 0.20, 0.06), (0.0, 0.31, 1.08), blue)
    box("候选三轮车左货物托盘", (0.32, 0.10, 0.34), (-0.25, 0.46, 0.70), yellow, (0.0, 0.0, 0.04))
    box("候选三轮车右货物托盘", (0.32, 0.10, 0.34), (0.25, 0.46, 0.70), yellow, (0.0, 0.0, -0.04))
    box("候选三轮车左托盘隔条", (0.035, 0.10, 0.38), (-0.25, 0.51, 0.70), plate)
    box("候选三轮车右托盘隔条", (0.035, 0.10, 0.38), (0.25, 0.51, 0.70), plate)
    box("候选三轮车座椅", (0.68, 0.13, 0.56), (0.0, 0.34, -0.08), seat)
    box("候选三轮车靠背", (0.68, 0.38, 0.09), (0.0, 0.53, 0.25), seat)
    cylinder("候选三轮车车把立柱", (0.0, 0.86, -0.76), 0.045, 0.48, metal, (0.0, 0.0, math.radians(-12.0)), 16)
    box("候选三轮车车把", (0.92, 0.08, 0.08), (0.0, 1.08, -0.80), metal)
    box("候选三轮车前灯", (0.42, 0.12, 0.08), (0.0, 0.52, -1.08), yellow)
    box("候选三轮车左转向灯", (0.13, 0.11, 0.06), (-0.58, 0.39, -1.10), indicator)
    box("候选三轮车右转向灯", (0.13, 0.11, 0.06), (0.58, 0.39, -1.10), indicator)
    box("候选三轮车左后视镜", (0.16, 0.12, 0.035), (-0.62, 0.98, -0.90), glass)
    box("候选三轮车右后视镜", (0.16, 0.12, 0.035), (0.62, 0.98, -0.90), glass)
    cylinder("候选三轮车左后视镜杆", (-0.56, 0.92, -0.86), 0.018, 0.22, metal, (0.0, 0.0, math.radians(-28.0)), 12)
    cylinder("候选三轮车右后视镜杆", (0.56, 0.92, -0.86), 0.018, 0.22, metal, (0.0, 0.0, math.radians(28.0)), 12)
    box("候选三轮车车牌", (0.34, 0.12, 0.025), (0.0, 0.34, -1.08), plate)
    box("候选三轮车后保险杠", (1.28, 0.10, 0.12), (0.0, 0.16, 1.27), metal)
    for prefix, location in (("候选三轮车左后", (-0.88, -0.38, 0.70)), ("候选三轮车右后", (0.88, -0.38, 0.70)), ("候选三轮车前", (0.0, -0.38, -0.96))):
        cylinder(prefix + "轮胎", location, 0.30, 0.16, rubber, (0.0, math.pi / 2.0, 0.0))
        cylinder(prefix + "轮毂", (location[0] - 0.085, location[1], location[2]), 0.13, 0.03, metal, (0.0, math.pi / 2.0, 0.0), 20)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_GLB.write_bytes(builder.build_glb())
    print(f"三轮车候选 GLB 已生成：{OUTPUT_GLB}，网格对象 {len(builder.objects)}，大小 {OUTPUT_GLB.stat().st_size} 字节")


if __name__ == "__main__":
    build()

import {NodeIO} from "@gltf-transform/core";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const assetPath = process.env.CANDIDATE_VEHICLE_ASSET_PATH
  ? path.resolve(root, process.env.CANDIDATE_VEHICLE_ASSET_PATH)
  : path.join(root, "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb");
if (!fs.existsSync(assetPath)) throw new Error(`候选三轮车不存在：${assetPath}`);

const document = await new NodeIO().read(assetPath);
const nodeNames = new Set(document.getRoot().listNodes().map((node) => node.getName()).filter(Boolean));
const requiredNodes = [
  "候选三轮车货斗底板",
  "候选三轮车货斗左栏",
  "候选三轮车货斗右栏",
  "候选三轮车左货物托盘",
  "候选三轮车右货物托盘",
  "候选三轮车座椅",
  "候选三轮车靠背",
];
const forbiddenNodes = ["候选三轮车顶篷", "候选三轮车挡风玻璃"];
for (const name of requiredNodes) {
  if (!nodeNames.has(name)) throw new Error(`候选三轮车缺少开放货斗轮廓节点：${name}`);
}
for (const name of forbiddenNodes) {
  if (nodeNames.has(name)) throw new Error(`候选三轮车仍包含与参考轮廓冲突的封闭结构：${name}`);
}

const min = [Infinity, Infinity, Infinity];
const max = [-Infinity, -Infinity, -Infinity];
for (const node of document.getRoot().listNodes()) {
  const mesh = node.getMesh();
  if (!mesh) continue;
  const translation = node.getTranslation();
  for (const primitive of mesh.listPrimitives()) {
    const position = primitive.getAttribute("POSITION");
    if (!position) throw new Error(`候选三轮车图元缺少 POSITION：${mesh.getName()}`);
    const values = position.getArray();
    for (let offset = 0; offset < values.length; offset += 3) {
      for (let axis = 0; axis < 3; axis += 1) {
        min[axis] = Math.min(min[axis], values[offset + axis] + translation[axis]);
        max[axis] = Math.max(max[axis], values[offset + axis] + translation[axis]);
      }
    }
  }
}
const size = max.map((value, axis) => value - min[axis]);
if (size[1] > 2.15) throw new Error(`候选三轮车高度超过低矮轮廓预算：${size[1].toFixed(3)}m`);
if (size[0] < 1.8 || size[2] < 2.3) throw new Error(`候选三轮车车体尺寸过小：${size.map((value) => value.toFixed(3)).join(" × ")}m`);

console.log(`候选三轮车轮廓契约通过：节点 ${nodeNames.size} 个；尺寸 ${size.map((value) => value.toFixed(3)).join(" × ")}m；开放货斗与无遮挡驾驶位已锁定`);

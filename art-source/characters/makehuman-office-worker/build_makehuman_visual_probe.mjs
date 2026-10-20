import fs from "node:fs";
import {NodeIO} from "@gltf-transform/core";
import {prune} from "@gltf-transform/functions";

const [, , input, output] = process.argv;
if (!input || !output) throw new Error("用法：node build_makehuman_visual_probe.mjs 输入.glb 输出.glb");
if (!fs.existsSync(input)) throw new Error(`输入 GLB 不存在：${input}`);

const io = new NodeIO();
const document = await io.read(input);
const removedNodeNames = new Set([
  "Human.male_worksuit01_export",
  "Human.teeth_base_export",
]);

for (const node of document.getRoot().listNodes()) {
  if (removedNodeNames.has(node.getName())) node.setMesh(null).setSkin(null);
}

await document.transform(prune({keepLeaves: false}));
await io.write(output, document);
console.log(`MakeHuman 轻量视觉探针已生成：${output}`);
console.log(`移除隐藏工装和牙齿网格：${[...removedNodeNames].join("、")}`);

import fs from "node:fs";
import path from "node:path";
import {NodeIO} from "@gltf-transform/core";

const [, , bodyGlb, suitGlb, outputGlb] = process.argv;
if (!bodyGlb || !suitGlb || !outputGlb) {
  throw new Error("用法：node skin_makehuman_elegant_suit.mjs 身体GLB 未蒙皮西装GLB 输出GLB");
}

function nearestWeights(sourcePositions, sourceJoints, sourceWeights, targetPositions) {
  const cellSize = 0.045;
  const cells = new Map();
  const key = (x, y, z) => `${Math.floor(x / cellSize)}:${Math.floor(y / cellSize)}:${Math.floor(z / cellSize)}`;
  for (let i = 0; i < sourcePositions.length; i += 3) {
    const cell = key(sourcePositions[i], sourcePositions[i + 1], sourcePositions[i + 2]);
    const list = cells.get(cell) || [];
    list.push(i / 3);
    cells.set(cell, list);
  }
  const joints = new Uint8Array((targetPositions.length / 3) * 4);
  const weights = new Float32Array((targetPositions.length / 3) * 4);
  for (let i = 0; i < targetPositions.length; i += 3) {
    const tx = targetPositions[i];
    const ty = targetPositions[i + 1];
    const tz = targetPositions[i + 2];
    const cx = Math.floor(tx / cellSize);
    const cy = Math.floor(ty / cellSize);
    const cz = Math.floor(tz / cellSize);
    let candidates = [];
    for (let radius = 0; radius <= 3 && candidates.length === 0; radius++) {
      for (let dx = -radius; dx <= radius; dx++) for (let dy = -radius; dy <= radius; dy++) for (let dz = -radius; dz <= radius; dz++) {
        candidates.push(...(cells.get(`${cx + dx}:${cy + dy}:${cz + dz}`) || []));
      }
    }
    if (candidates.length === 0) candidates = Array.from({length: sourcePositions.length / 3}, (_, index) => index);
    let best = candidates[0];
    let bestDistance = Infinity;
    for (const sourceIndex of candidates) {
      const si = sourceIndex * 3;
      const dx = sourcePositions[si] - tx;
      const dy = sourcePositions[si + 1] - ty;
      const dz = sourcePositions[si + 2] - tz;
      const distance = dx * dx + dy * dy + dz * dz;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = sourceIndex;
      }
    }
    const sourceJointOffset = best * 4;
    const targetOffset = (i / 3) * 4;
    for (let channel = 0; channel < 4; channel++) {
      joints[targetOffset + channel] = sourceJoints[sourceJointOffset + channel];
      weights[targetOffset + channel] = sourceWeights[sourceJointOffset + channel];
    }
  }
  return {joints, weights};
}

const io = new NodeIO();
const bodyDocument = await io.read(bodyGlb);
const suitDocument = await io.read(suitGlb);
const bodyMesh = bodyDocument.getRoot().listMeshes().find((mesh) => mesh.getName() === "male_worksuit01.001");
const bodyPrimitive = bodyMesh?.listPrimitives()[0];
const suitMesh = suitDocument.getRoot().listMeshes()[0];
const suitPrimitive = suitMesh?.listPrimitives()[0];
const skin = bodyDocument.getRoot().listSkins()[0];
const bodyRoot = bodyDocument.getRoot().listNodes().find((node) => node.getName() === "Human.rig_export");
if (!bodyPrimitive || !suitPrimitive || !skin || !bodyRoot) throw new Error("身体 GLB 或西装 GLB 缺少预期网格/骨骼结构");

const bodyPositions = bodyPrimitive.getAttribute("POSITION").getArray();
const bodyJoints = bodyPrimitive.getAttribute("JOINTS_0").getArray();
const bodyWeights = bodyPrimitive.getAttribute("WEIGHTS_0").getArray();
const suitPositions = suitPrimitive.getAttribute("POSITION").getArray();
const suitNormals = suitPrimitive.getAttribute("NORMAL")?.getArray();
const suitUvs = suitPrimitive.getAttribute("TEXCOORD_0")?.getArray();
const suitIndices = suitPrimitive.getIndices()?.getArray();
const transferred = nearestWeights(bodyPositions, bodyJoints, bodyWeights, suitPositions);

const mesh = bodyDocument.createMesh("male_elegantsuit01_skinned");
const primitive = bodyDocument.createPrimitive();
primitive.setAttribute("POSITION", bodyDocument.createAccessor("西装位置").setType("VEC3").setArray(new Float32Array(suitPositions)));
if (suitNormals) primitive.setAttribute("NORMAL", bodyDocument.createAccessor("西装法线").setType("VEC3").setArray(new Float32Array(suitNormals)));
if (suitUvs) primitive.setAttribute("TEXCOORD_0", bodyDocument.createAccessor("西装纹理坐标").setType("VEC2").setArray(new Float32Array(suitUvs)));
if (suitIndices) primitive.setIndices(bodyDocument.createAccessor("西装索引").setType("SCALAR").setArray(new Uint32Array(suitIndices)));
primitive.setAttribute("JOINTS_0", bodyDocument.createAccessor("西装骨骼索引").setType("VEC4").setArray(transferred.joints));
primitive.setAttribute("WEIGHTS_0", bodyDocument.createAccessor("西装骨骼权重").setType("VEC4").setArray(transferred.weights));
const sourceMaterial = suitPrimitive.getMaterial();
if (sourceMaterial) {
  const material = bodyDocument.createMaterial("male_elegantsuit01_skinned");
  const sourceTexture = sourceMaterial.getBaseColorTexture();
  if (sourceTexture?.getImage()) {
    const texture = bodyDocument.createTexture("male_elegantsuit01_diffuse").setImage(sourceTexture.getImage()).setMimeType(sourceTexture.getMimeType() || "image/png");
    material.setBaseColorTexture(texture);
  }
  material.setRoughnessFactor(sourceMaterial.getRoughnessFactor()).setMetallicFactor(sourceMaterial.getMetallicFactor());
  primitive.setMaterial(material);
}
mesh.addPrimitive(primitive);
const node = bodyDocument.createNode("Human.male_elegantsuit01_skinned_export").setMesh(mesh).setSkin(skin);
bodyRoot.addChild(node);
await io.write(outputGlb, bodyDocument);
console.log(`共享 MakeHuman 骨骼的西装 GLB 已生成：${outputGlb}`);
console.log(`西装顶点：${suitPositions.length / 3}；权重来源顶点：${bodyPositions.length / 3}；骨骼：${skin.listJoints().length}`);

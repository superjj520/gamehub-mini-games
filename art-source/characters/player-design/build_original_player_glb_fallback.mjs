import fs from "node:fs";
import path from "node:path";
import {Document, NodeIO} from "@gltf-transform/core";

// Blender 在本机 Metal 后端初始化阶段不可用时的纯 Node 候选生成器。
// 该文件只生成原创候选 GLB，不改变正式运行时目录，也不自动提升权利或视觉状态。
const root = process.cwd();
const output = path.join(root, "art-source/characters/player-design/generated/original_player_visual_v1.glb");
const document = new Document();
const buffer = document.createBuffer("OriginalPlayerCandidateBuffer");
const scene = document.createScene("OriginalPlayerCandidateScene");
const rootNode = document.createNode("OriginalPlayerVisualCandidate");
rootNode.setExtras({
  asset_source: "project_original_generated_code",
  visual_status: "candidate_only",
  unit_scale: "1 Blender unit = 1 meter",
  forward_axis: "-Z",
  reference_board: "art-source/characters/player-design/new-era-awakener-player-turnaround-v1-generated.png",
});
scene.addChild(rootNode);

const materials = new Map();
function material(name, color, roughness = 0.7, metallic = 0) {
  if (materials.has(name)) return materials.get(name);
  const value = document.createMaterial(name)
    .setBaseColorFactor([...color, 1])
    .setRoughnessFactor(roughness)
    .setMetallicFactor(metallic);
  materials.set(name, value);
  return value;
}

const palette = {
  jacket: material("原创夹克深灰", [0.10, 0.13, 0.14], 0.78),
  jacketEdge: material("原创夹克边缘", [0.22, 0.27, 0.28], 0.68),
  shirt: material("原创红色内层", [0.42, 0.09, 0.075], 0.74),
  skin: material("原创皮肤", [0.55, 0.31, 0.23], 0.62),
  hair: material("原创黑色发束", [0.025, 0.032, 0.038], 0.55),
  pants: material("原创工装裤", [0.075, 0.09, 0.11], 0.84),
  backpack: material("原创背包", [0.06, 0.075, 0.085], 0.88),
  leather: material("原创背包皮带", [0.28, 0.18, 0.10], 0.76),
  sole: material("原创鞋底", [0.03, 0.04, 0.05], 0.58),
  rubber: material("原创鞋面", [0.18, 0.23, 0.25], 0.68),
  metal: material("原创拉链与扣件", [0.62, 0.43, 0.20], 0.32, 0.25),
  eye: material("原创眼睛", [0.008, 0.012, 0.016], 0.22),
};

function accessor(values, type, name) {
  return document.createAccessor(name).setType(type).setArray(new Float32Array(values)).setBuffer(buffer);
}

function indices(values, name) {
  return document.createAccessor(name).setType("SCALAR").setArray(new Uint16Array(values)).setBuffer(buffer);
}

function meshFor(name, positions, triangles, materialValue, normals = null) {
  const primitive = document.createPrimitive()
    .setAttribute("POSITION", accessor(positions, "VEC3", `${name}位置`))
    .setIndices(indices(triangles, `${name}索引`))
    .setMaterial(materialValue);
  if (normals) primitive.setAttribute("NORMAL", accessor(normals, "VEC3", `${name}法线`));
  return document.createMesh(name).addPrimitive(primitive);
}

function boxGeometry() {
  const positions = [
    -1, -1, -1, 1, -1, -1, 1, 1, -1, -1, 1, -1,
    -1, -1, 1, 1, -1, 1, 1, 1, 1, -1, 1, 1,
  ];
  const triangles = [
    0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7,
    0, 1, 5, 0, 5, 4, 3, 7, 6, 3, 6, 2,
    0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5,
  ];
  return {positions, triangles};
}

function sphereGeometry(segments = 24, rings = 12) {
  const positions = [];
  const normals = [];
  const triangles = [];
  for (let ring = 0; ring <= rings; ring += 1) {
    const v = ring / rings;
    const phi = Math.PI * v;
    const y = Math.cos(phi);
    const radius = Math.sin(phi);
    for (let segment = 0; segment <= segments; segment += 1) {
      const u = segment / segments;
      const theta = Math.PI * 2 * u;
      const x = Math.cos(theta) * radius;
      const z = Math.sin(theta) * radius;
      positions.push(x, y, z);
      normals.push(x, y, z);
    }
  }
  for (let ring = 0; ring < rings; ring += 1) {
    for (let segment = 0; segment < segments; segment += 1) {
      const a = ring * (segments + 1) + segment;
      const b = a + segments + 1;
      triangles.push(a, b, a + 1, a + 1, b, b + 1);
    }
  }
  return {positions, normals, triangles};
}

const box = boxGeometry();
const sphere = sphereGeometry();

function addBox(name, position, scale, materialValue, rotation = [0, 0, 0, 1]) {
  const node = document.createNode(name);
  node.setMesh(meshFor(name, box.positions, box.triangles, materialValue));
  node.setTranslation(position).setScale(scale).setRotation(rotation);
  rootNode.addChild(node);
  return node;
}

function addSphere(name, position, scale, materialValue) {
  const node = document.createNode(name);
  node.setMesh(meshFor(name, sphere.positions, sphere.triangles, materialValue, sphere.normals));
  node.setTranslation(position).setScale(scale);
  rootNode.addChild(node);
  return node;
}

// 视觉候选采用成熟的成人比例和多层服装节点，避免把角色做成单一积木体。
addBox("AdvancedBody", [0, 1.18, 0], [0.36, 0.43, 0.24], palette.jacket);
addBox("AdvancedShirtFront", [0, 1.23, -0.255], [0.17, 0.26, 0.018], palette.shirt);
addBox("AdvancedJacketHem", [0, 0.78, 0], [0.39, 0.09, 0.26], palette.jacketEdge);
addBox("AdvancedZipper", [0, 1.24, -0.285], [0.013, 0.21, 0.009], palette.metal);
addBox("AdvancedCollarLeft", [-0.12, 1.48, -0.255], [0.11, 0.055, 0.018], palette.jacketEdge);
addBox("AdvancedCollarRight", [0.12, 1.48, -0.255], [0.11, 0.055, 0.018], palette.jacketEdge);
addBox("AdvancedHoodBack", [0, 1.61, 0.19], [0.33, 0.275, 0.08], palette.jacket, [-0.043472, 0, 0, 0.999055]);
addBox("AdvancedHoodLeft", [-0.27, 1.58, 0.04], [0.065, 0.21, 0.09], palette.jacketEdge, [0, 0, -0.104807, 0.994492]);
addBox("AdvancedHoodRight", [0.27, 1.58, 0.04], [0.065, 0.21, 0.09], palette.jacketEdge, [0, 0, 0.104807, 0.994492]);
addSphere("AdvancedHead", [0, 1.78, -0.005], [0.235, 0.285, 0.225], palette.skin);
addSphere("AdvancedHairTop", [0, 1.98, 0.03], [0.235, 0.105, 0.22], palette.hair);
addSphere("AdvancedHairLeft", [-0.19, 1.91, 0.015], [0.09, 0.16, 0.19], palette.hair);
addSphere("AdvancedHairRight", [0.19, 1.91, 0.015], [0.09, 0.16, 0.19], palette.hair);
addSphere("AdvancedHairBack", [0, 1.88, 0.17], [0.20, 0.16, 0.08], palette.hair);
addBox("AdvancedNeck", [0, 1.56, 0], [0.10, 0.09, 0.10], palette.skin);
addSphere("AdvancedNose", [0, 1.77, -0.232], [0.028, 0.032, 0.052], palette.skin);
for (const side of [-1, 1]) {
  const label = side < 0 ? "L" : "R";
  addSphere(`AdvancedEye${label}`, [side * 0.082, 1.81, -0.215], [0.022, 0.014, 0.010], palette.eye);
  addSphere(`AdvancedEar${label}`, [side * 0.225, 1.78, 0], [0.045, 0.072, 0.035], palette.skin);
  addSphere(`AdvancedUpperArm${label}`, [side * 0.43, 1.04, 0], [0.14, 0.38, 0.14], palette.jacket);
  addSphere(`AdvancedForearm${label}`, [side * 0.51, 0.76, -0.025], [0.115, 0.31, 0.115], palette.jacketEdge);
  addSphere(`AdvancedHand${label}`, [side * 0.55, 0.54, -0.045], [0.095, 0.115, 0.09], palette.skin);
  addSphere(`AdvancedLeg${label}`, [side * 0.17, 0.42, 0], [0.145, 0.43, 0.16], palette.pants);
  addBox(`AdvancedCargoPocket${label}`, [side * 0.17, 0.48, -0.155], [0.11, 0.10, 0.022], palette.jacketEdge);
  addBox(`AdvancedCargoPocketFlap${label}`, [side * 0.17, 0.59, -0.18], [0.115, 0.018, 0.028], palette.leather);
  addBox(`AdvancedShoe${label}`, [side * 0.17, 0.105, -0.12], [0.15, 0.09, 0.24], palette.rubber);
  addBox(`AdvancedSole${label}`, [side * 0.17, 0.035, -0.12], [0.165, 0.03, 0.26], palette.sole);
}
addBox("AdvancedBackpack", [0, 1.12, 0.29], [0.28, 0.35, 0.09], palette.backpack);
addBox("AdvancedBackpackFlap", [0, 1.48, 0.25], [0.24, 0.065, 0.11], palette.leather);
for (const side of [-1, 1]) {
  const label = side < 0 ? "L" : "R";
  addBox(`AdvancedStrap${label}`, [side * 0.24, 1.21, 0.16], [0.035, 0.29, 0.018], palette.leather, [0, 0, side * -0.043472, 0.999055]);
  addBox(`AdvancedSidePocket${label}`, [side * 0.31, 1.07, 0.31], [0.065, 0.125, 0.08], palette.backpack);
}
addBox("AdvancedBadge", [0, 1.30, -0.285], [0.065, 0.085, 0.013], palette.metal);

fs.mkdirSync(path.dirname(output), {recursive: true});
await new NodeIO().write(output, document);
console.log(`原创主角 GLB 候选已生成：${path.relative(root, output)}`);

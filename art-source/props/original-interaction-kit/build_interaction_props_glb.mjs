import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import sharp from "sharp";

const outputPath = path.join(path.dirname(fileURLToPath(import.meta.url)), "interaction_props_kit.glb");
const nodes = [];
const meshes = [];
const materials = [];
const materialRegions = [];
const accessors = [];
const bufferViews = [];
const chunks = [];
let binaryLength = 0;

function align4(value) {
  return (value + 3) & ~3;
}

function appendBinary(buffer, target) {
  const aligned = align4(binaryLength);
  if (aligned > binaryLength) {
    chunks.push(Buffer.alloc(aligned - binaryLength));
    binaryLength = aligned;
  }
  const offset = binaryLength;
  chunks.push(buffer);
  binaryLength += buffer.length;
  const view = {buffer: 0, byteOffset: offset, byteLength: buffer.length};
  if (target !== undefined) view.target = target;
  bufferViews.push(view);
  return bufferViews.length - 1;
}

function addAccessor(buffer, componentType, count, type, min, max) {
  const bufferView = appendBinary(buffer, type === "SCALAR" ? 34963 : 34962);
  accessors.push({bufferView, componentType, count, type, min, max});
  return accessors.length - 1;
}

function material(name, color, metallic = 0.0, roughness = 0.55, emission = null) {
  const index = materialRegions.length;
  const column = index % 3;
  const row = Math.floor(index / 3);
  const inset = 0.035;
  materialRegions.push({name, color, metallic, roughness, emission, region: [column / 3 + inset, row / 3 + inset, (column + 1) / 3 - inset, (row + 1) / 3 - inset]});
  return index;
}

function addPrimitive(name, positions, normals, indices, materialIndex) {
  const positionArray = new Float32Array(positions.flat());
  const normalArray = new Float32Array(normals.flat());
  const indexArray = new Uint16Array(indices);
  const region = materialRegions[materialIndex]?.region || [0.0, 0.0, 1.0, 1.0];
  const uvArray = new Float32Array(positions.length * 2);
  const centerU = (region[0] + region[2]) / 2;
  const centerV = 1.0 - (region[1] + region[3]) / 2;
  for (let vertexIndex = 0; vertexIndex < positions.length; vertexIndex += 1) {
    uvArray[vertexIndex * 2] = centerU;
    uvArray[vertexIndex * 2 + 1] = centerV;
  }
  const positionAccessor = addAccessor(positionArrayToBuffer(positionArray), 5126, positions.length, "VEC3", minMax(positions), minMax(positions, true));
  const normalAccessor = addAccessor(positionArrayToBuffer(normalArray), 5126, normals.length, "VEC3");
  const uvAccessor = addAccessor(positionArrayToBuffer(uvArray), 5126, positions.length, "VEC2");
  const indexAccessor = addAccessor(Buffer.from(indexArray.buffer), 5123, indices.length, "SCALAR", [0], [Math.max(...indices)]);
  meshes.push({
    name,
    primitives: [{
      attributes: {POSITION: positionAccessor, NORMAL: normalAccessor, TEXCOORD_0: uvAccessor},
      indices: indexAccessor,
      material: 0,
    }],
  });
  return meshes.length - 1;
}

function positionArrayToBuffer(array) {
  return Buffer.from(array.buffer, array.byteOffset, array.byteLength);
}

function minMax(values, maximum = false) {
  const result = [Infinity, Infinity, Infinity];
  for (const value of values) {
    for (let axis = 0; axis < 3; axis += 1) {
      result[axis] = maximum ? Math.max(result[axis] === Infinity ? -Infinity : result[axis], value[axis]) : Math.min(result[axis], value[axis]);
    }
  }
  return result;
}

function addNode(name, parent = null, translation = [0, 0, 0]) {
  const node = {name, translation};
  nodes.push(node);
  const index = nodes.length - 1;
  if (parent !== null) {
    nodes[parent].children ??= [];
    nodes[parent].children.push(index);
  }
  return index;
}

function addMeshNode(name, mesh, parent) {
  const node = addNode(name, parent);
  nodes[node].mesh = mesh;
  return node;
}

function addBox(name, center, size, materialIndex, parent) {
  const [cx, cy, cz] = center;
  const [sx, sy, sz] = size;
  const x = sx / 2;
  const y = sy / 2;
  const z = sz / 2;
  const faces = [
    {normal: [0, 0, 1], corners: [[-x, -y, z], [x, -y, z], [x, y, z], [-x, y, z]]},
    {normal: [0, 0, -1], corners: [[x, -y, -z], [-x, -y, -z], [-x, y, -z], [x, y, -z]]},
    {normal: [1, 0, 0], corners: [[x, -y, z], [x, -y, -z], [x, y, -z], [x, y, z]]},
    {normal: [-1, 0, 0], corners: [[-x, -y, -z], [-x, -y, z], [-x, y, z], [-x, y, -z]]},
    {normal: [0, 1, 0], corners: [[-x, y, z], [x, y, z], [x, y, -z], [-x, y, -z]]},
    {normal: [0, -1, 0], corners: [[-x, -y, -z], [x, -y, -z], [x, -y, z], [-x, -y, z]]},
  ];
  const positions = [];
  const normals = [];
  const indices = [];
  for (const face of faces) {
    const offset = positions.length;
    for (const corner of face.corners) {
      positions.push([corner[0] + cx, corner[1] + cy, corner[2] + cz]);
      normals.push(face.normal);
    }
    indices.push(offset, offset + 1, offset + 2, offset, offset + 2, offset + 3);
  }
  return addMeshNode(name, addPrimitive(name, positions, normals, indices, materialIndex), parent);
}

function addCylinder(name, center, radius, depth, materialIndex, parent, segments = 20) {
  const [cx, cy, cz] = center;
  const positions = [];
  const normals = [];
  const indices = [];
  for (let index = 0; index < segments; index += 1) {
    const a0 = (index / segments) * Math.PI * 2;
    const a1 = ((index + 1) / segments) * Math.PI * 2;
    const base = positions.length;
    const ring = [[Math.cos(a0) * radius, -depth / 2, Math.sin(a0) * radius], [Math.cos(a1) * radius, -depth / 2, Math.sin(a1) * radius], [Math.cos(a1) * radius, depth / 2, Math.sin(a1) * radius], [Math.cos(a0) * radius, depth / 2, Math.sin(a0) * radius]];
    for (let pointIndex = 0; pointIndex < ring.length; pointIndex += 1) {
      const point = ring[pointIndex];
      const angle = pointIndex === 0 || pointIndex === 3 ? a0 : a1;
      positions.push([point[0] + cx, point[1] + cy, point[2] + cz]);
      normals.push([Math.cos(angle), 0, Math.sin(angle)]);
    }
    indices.push(base, base + 3, base + 2, base, base + 2, base + 1);
  }
  return addMeshNode(name, addPrimitive(name, positions, normals, indices, materialIndex), parent);
}

function addEgg(name, center, scale, materialIndex, parent) {
  const [cx, cy, cz] = center;
  const [sx, sy, sz] = scale;
  const segments = 16;
  const rings = 8;
  const positions = [];
  const normals = [];
  const indices = [];
  for (let ring = 0; ring <= rings; ring += 1) {
    const v = ring / rings;
    const phi = v * Math.PI;
    for (let segment = 0; segment < segments; segment += 1) {
      const theta = (segment / segments) * Math.PI * 2;
      const nx = Math.sin(phi) * Math.cos(theta);
      const ny = Math.cos(phi);
      const nz = Math.sin(phi) * Math.sin(theta);
      positions.push([cx + nx * sx, cy + ny * sy, cz + nz * sz]);
      normals.push([nx, ny, nz]);
    }
  }
  for (let ring = 0; ring < rings; ring += 1) {
    for (let segment = 0; segment < segments; segment += 1) {
      const next = (segment + 1) % segments;
      const a = ring * segments + segment;
      const b = ring * segments + next;
      const c = (ring + 1) * segments + next;
      const d = (ring + 1) * segments + segment;
      indices.push(a, b, c, a, c, d);
    }
  }
  return addMeshNode(name, addPrimitive(name, positions, normals, indices, materialIndex), parent);
}

const root = addNode("InteractionPropsKit", null);
nodes[root].extras = {asset_role: "original_interaction_props_candidate", unit: "meter", up_axis: "+Y", release_status: "candidate_only"};
const eggTray = addNode("EggTray_Interaction", root);
const scanBoard = addNode("ScanBoard_Interaction", root);
const deliveryMarker = addNode("DeliveryMarker_Interaction", root);
const basket = addNode("ShopBasket_Interaction", root);

const tray = material("托盘_暖灰", [0.22, 0.25, 0.25], 0.1, 0.48);
const egg = material("鸡蛋_象牙白", [0.88, 0.77, 0.58], 0.0, 0.42);
const counter = material("扫码台_深青", [0.08, 0.16, 0.17], 0.15, 0.35);
const trim = material("扫码台_金属边", [0.48, 0.52, 0.46], 0.65, 0.28);
const screen = material("扫码屏_黑玻璃", [0.015, 0.035, 0.04], 0.1, 0.16);
const emission = material("状态灯_青色", [0.04, 0.5, 0.55], 0.0, 0.25, [0.0, 0.85, 0.95]);
const warning = material("交付柱_橙色", [0.72, 0.2, 0.06], 0.0, 0.35, [0.35, 0.03, 0.0]);
const paper = material("标识牌_纸张", [0.82, 0.75, 0.58], 0.0, 0.78);
const basketMaterial = material("购物篮_蓝灰", [0.08, 0.24, 0.32], 0.1, 0.5);

addBox("托盘底", [0, 0.08, 0], [0.72, 0.12, 0.48], tray, eggTray);
for (let row = 0; row < 2; row += 1) {
  for (let column = 0; column < 5; column += 1) {
    addEgg(`鸡蛋_${row}_${column}`, [-0.25 + column * 0.125, 0.22, -0.13 + row * 0.26], [0.055, 0.08, 0.055], egg, eggTray);
  }
}

addBox("扫码台底座", [0, 0.48, 0], [0.95, 0.96, 0.72], counter, scanBoard);
addBox("扫码台台面", [0, 0.98, 0], [1.05, 0.08, 0.78], trim, scanBoard);
addBox("扫码屏", [0, 1.38, -0.05], [0.58, 0.46, 0.06], screen, scanBoard);
addBox("扫码灯", [0, 1.36, 0.02], [0.18, 0.04, 0.03], emission, scanBoard);

addCylinder("标识柱", [0, 0.7, 0], 0.055, 1.4, warning, deliveryMarker);
addBox("交付标识牌", [0, 1.38, 0], [0.62, 0.36, 0.06], paper, deliveryMarker);
addBox("交付灯带", [0, 1.38, 0.035], [0.28, 0.035, 0.02], emission, deliveryMarker);

addBox("篮筐底", [0, 0.22, 0], [0.72, 0.08, 0.48], basketMaterial, basket);
for (const x of [-0.32, 0.32]) addBox("篮筐侧边", [x, 0.42, 0], [0.06, 0.42, 0.5], basketMaterial, basket);
for (const z of [-0.22, 0.22]) addBox("篮筐前后边", [0, 0.42, z], [0.72, 0.42, 0.06], basketMaterial, basket);
addBox("篮筐提手", [0, 0.75, 0], [0.08, 0.62, 0.08], basketMaterial, basket);

const atlasSize = 512;
const cellSize = atlasSize / 3;
const atlasRects = materialRegions.map((entry, index) => {
  const column = index % 3;
  const row = Math.floor(index / 3);
  const [red, green, blue] = entry.color.map((channel) => Math.round(channel * 255));
  const hex = [red, green, blue].map((channel) => channel.toString(16).padStart(2, "0")).join("");
  return `<rect x="${column * cellSize}" y="${row * cellSize}" width="${cellSize}" height="${cellSize}" fill="#${hex}"/>`;
}).join("");
const atlasSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="${atlasSize}" height="${atlasSize}" viewBox="0 0 ${atlasSize} ${atlasSize}">${atlasRects}</svg>`;
const atlasPng = await sharp(Buffer.from(atlasSvg)).png().toBuffer();
const atlasPath = path.join(path.dirname(outputPath), "interaction_props_atlas_v1.png");
fs.writeFileSync(atlasPath, atlasPng);
const atlasImageBufferView = appendBinary(atlasPng);
materials.push({
  name: "交互道具共享颜色图集",
  pbrMetallicRoughness: {
    baseColorTexture: {index: 0},
    metallicFactor: 0.12,
    roughnessFactor: 0.56,
  },
});

const binary = Buffer.concat(chunks);
const gltf = {
  asset: {version: "2.0", generator: "新时代觉醒者原创交互道具 GLB 构建器", extras: {material_strategy: "single_shared_color_atlas", atlas_size: "512x512"}},
  scene: 0,
  scenes: [{nodes: [root]}],
  nodes,
  meshes,
  materials,
  images: [{bufferView: atlasImageBufferView, mimeType: "image/png"}],
  textures: [{source: 0}],
  accessors,
  bufferViews,
  buffers: [{byteLength: binary.length}],
};
const json = Buffer.from(JSON.stringify(gltf), "utf8");
const jsonPadded = Buffer.concat([json, Buffer.alloc(align4(json.length) - json.length, 0x20)]);
const binaryPadded = Buffer.concat([binary, Buffer.alloc(align4(binary.length) - binary.length)]);
const totalLength = 12 + 8 + jsonPadded.length + 8 + binaryPadded.length;
const header = Buffer.alloc(12);
header.writeUInt32LE(0x46546c67, 0);
header.writeUInt32LE(2, 4);
header.writeUInt32LE(totalLength, 8);
const jsonHeader = Buffer.alloc(8);
jsonHeader.writeUInt32LE(jsonPadded.length, 0);
jsonHeader.writeUInt32LE(0x4e4f534a, 4);
const binaryHeader = Buffer.alloc(8);
binaryHeader.writeUInt32LE(binaryPadded.length, 0);
binaryHeader.writeUInt32LE(0x004e4942, 4);
fs.writeFileSync(outputPath, Buffer.concat([header, jsonHeader, jsonPadded, binaryHeader, binaryPadded]));
console.log(`原创交互道具候选已导出：${outputPath}`);

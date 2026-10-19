import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import sharp from "sharp";
import {Accessor, NodeIO} from "@gltf-transform/core";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(rootDir, "../../..");
const inputPath = path.resolve(process.env.THREE_WHEEL_ATLAS_INPUT || path.join(workspaceRoot, "gta-reference-runtime/assets/vehicles/three-wheel-delivery/three_wheel_delivery.glb"));
const outputPath = path.resolve(process.env.THREE_WHEEL_ATLAS_OUTPUT || path.join(rootDir, "three_wheel_delivery_atlas_candidate.glb"));
const tileSize = 512;
const columns = 4;
const rows = 2;
const atlasWidth = tileSize * columns;
const atlasHeight = tileSize * rows;

const OPAQUE_MATERIALS = [
  "车体蓝",
  "车体深蓝",
  "安全黄",
  "轮胎橡胶",
  "结构金属",
  "顶篷织物",
  "座椅皮革",
  "车牌",
];
const SPECIAL_MATERIALS = new Set(["挡风玻璃", "转向灯"]);

function linearToSrgb(value) {
  return value <= 0.0031308 ? value * 12.92 : 1.055 * value ** (1 / 2.4) - 0.055;
}

function cellForIndex(index) {
  return {left: (index % columns) * tileSize, top: Math.floor(index / columns) * tileSize};
}

function findMaterial(document, name) {
  const material = document.getRoot().listMaterials().find((candidate) => candidate.getName() === name);
  if (!material) throw new Error(`缺少三轮车源材质：${name}`);
  return material;
}

function solidTile(material, channelMode) {
  const pixels = Buffer.alloc(tileSize * tileSize * 4);
  const base = material.getBaseColorFactor();
  const metallic = Math.round(material.getMetallicFactor() * 255);
  const roughness = Math.round(material.getRoughnessFactor() * 255);
  for (let offset = 0; offset < pixels.length; offset += 4) {
    if (channelMode === "base") {
      pixels[offset] = Math.round(linearToSrgb(base[0]) * 255);
      pixels[offset + 1] = Math.round(linearToSrgb(base[1]) * 255);
      pixels[offset + 2] = Math.round(linearToSrgb(base[2]) * 255);
      pixels[offset + 3] = Math.round(base[3] * 255);
    } else {
      pixels[offset] = 0;
      pixels[offset + 1] = roughness;
      pixels[offset + 2] = metallic;
      pixels[offset + 3] = 255;
    }
  }
  return sharp(pixels, {raw: {width: tileSize, height: tileSize, channels: 4}}).png().toBuffer();
}

async function composeAtlas(entries, channelMode) {
  const layers = [];
  for (const [index, entry] of entries.entries()) {
    const cell = cellForIndex(index);
    layers.push({input: await solidTile(entry.material, channelMode), left: cell.left, top: cell.top});
  }
  return sharp({
    create: {
      width: atlasWidth,
      height: atlasHeight,
      channels: 4,
      background: {r: 0, g: 0, b: 0, alpha: 0},
    },
  }).composite(layers).png().toBuffer();
}

function createPrimitiveUv(document, primitive, index) {
  const position = primitive.getAttribute("POSITION");
  if (!position) throw new Error("三轮车图元缺少 POSITION 属性");
  const cell = cellForIndex(index);
  const u = (cell.left + tileSize * 0.5) / atlasWidth;
  const v = (cell.top + tileSize * 0.5) / atlasHeight;
  const values = new Float32Array(position.getCount() * 2);
  for (let offset = 0; offset < values.length; offset += 2) {
    values[offset] = u;
    values[offset + 1] = v;
  }
  return document.createAccessor(`three_wheel_atlas_uv_${index}_${position.getCount()}`)
    .setType(Accessor.Type.VEC2)
    .setArray(values);
}

async function main() {
  const document = await new NodeIO().read(inputPath);
  const opaqueEntries = OPAQUE_MATERIALS.map((name) => ({material: findMaterial(document, name), name}));
  const baseAtlas = await composeAtlas(opaqueEntries, "base");
  const metallicRoughnessAtlas = await composeAtlas(opaqueEntries, "metallic_roughness");
  const baseTexture = document.createTexture("three_wheel_opaque_base_color_atlas").setMimeType("image/png").setImage(baseAtlas);
  const metallicRoughnessTexture = document.createTexture("three_wheel_opaque_metallic_roughness_atlas").setMimeType("image/png").setImage(metallicRoughnessAtlas);
  const opaqueMaterial = document.createMaterial("three_wheel_opaque_atlas")
    .setBaseColorTexture(baseTexture)
    .setMetallicRoughnessTexture(metallicRoughnessTexture)
    .setBaseColorFactor([1, 1, 1, 1])
    .setMetallicFactor(1)
    .setRoughnessFactor(1)
    .setAlphaMode("OPAQUE")
    .setDoubleSided(false);
  const sourceToIndex = new Map(OPAQUE_MATERIALS.map((name, index) => [name, index]));
  let remappedPrimitives = 0;
  for (const mesh of document.getRoot().listMeshes()) {
    for (const primitive of mesh.listPrimitives()) {
      const sourceMaterial = primitive.getMaterial();
      if (!sourceMaterial) throw new Error(`三轮车图元缺少材质：${mesh.getName()}`);
      const materialName = sourceMaterial.getName();
      if (sourceToIndex.has(materialName)) {
        primitive.setAttribute("TEXCOORD_0", createPrimitiveUv(document, primitive, sourceToIndex.get(materialName)));
        primitive.setMaterial(opaqueMaterial);
        remappedPrimitives += 1;
      } else if (!SPECIAL_MATERIALS.has(materialName)) {
        throw new Error(`三轮车存在未登记材质：${materialName}`);
      }
    }
  }
  for (const material of document.getRoot().listMaterials()) {
    if (!OPAQUE_MATERIALS.includes(material.getName())) continue;
    material.dispose();
  }
  for (const texture of document.getRoot().listTextures()) {
    if (!texture.getName().includes("atlas")) texture.dispose();
  }
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  const temporaryOutputPath = `${outputPath}.tmp-${process.pid}.glb`;
  try {
    await new NodeIO().write(temporaryOutputPath, document);
    fs.renameSync(temporaryOutputPath, outputPath);
  } finally {
    fs.rmSync(temporaryOutputPath, {force: true});
  }
  console.log(`三轮车材质图集候选已生成：${path.relative(workspaceRoot, outputPath)}`);
  console.log(`不透明材质：${OPAQUE_MATERIALS.length} → 1；透明/发光特殊材质保留 2 个；重映射图元：${remappedPrimitives}`);
}

await main();

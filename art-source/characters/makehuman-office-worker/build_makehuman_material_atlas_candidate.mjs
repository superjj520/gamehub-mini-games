import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import sharp from "sharp";
import {NodeIO} from "@gltf-transform/core";

const rootDir = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(rootDir, "../../..");
const inputPath = path.resolve(process.env.MAKEHUMAN_ATLAS_INPUT || path.join(rootDir, "makehuman_office_worker_elegant_suit_skinned_probe_512_simplified.glb"));
const outputPath = path.resolve(process.env.MAKEHUMAN_ATLAS_OUTPUT || path.join(rootDir, "makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb"));
const tileSize = 512;
const atlasSize = tileSize * 2;

const GROUPS = {
  skin: {
    materialNames: ["Human.low-poly", "Human.body"],
    atlasNames: ["brown_eye", "young_lightskinned_male_diffuse"],
    materialName: "makehuman_atlas_skin",
  },
  hair: {
    materialNames: ["Human.eyebrow001", "Human.eyelashes01", "Human.short02"],
    atlasNames: ["eyebrow001", "eyelashes01", "short02_diffuse"],
    materialName: "makehuman_atlas_hair_detail",
  },
  outfit: {
    materialNames: ["Human.shoes02", "male_elegantsuit01_skinned"],
    atlasNames: ["shoes02_diffuse", "male_elegantsuit01_diffuse"],
    materialName: "makehuman_atlas_outfit",
  },
};

function cellForIndex(index) {
  return {left: (index % 2) * tileSize, top: Math.floor(index / 2) * tileSize};
}

function createSolidTile(material) {
  const pixels = Buffer.alloc(tileSize * tileSize * 4);
  const metallic = Math.round(material.getMetallicFactor() * 255);
  const roughness = Math.round(material.getRoughnessFactor() * 255);
  for (let index = 0; index < pixels.length; index += 4) {
    pixels[index] = 0;
    pixels[index + 1] = roughness;
    pixels[index + 2] = metallic;
    pixels[index + 3] = 255;
  }
  return sharp(pixels, {raw: {width: tileSize, height: tileSize, channels: 4}}).png().toBuffer();
}

async function composeAtlas(entries, imageForEntry) {
  const layers = [];
  for (const [index, entry] of entries.entries()) {
    const cell = cellForIndex(index);
    layers.push({input: await imageForEntry(entry), left: cell.left, top: cell.top});
  }
  return sharp({
    create: {
      width: atlasSize,
      height: atlasSize,
      channels: 4,
      background: {r: 0, g: 0, b: 0, alpha: 0},
    },
  }).composite(layers).png().toBuffer();
}

function findMaterial(document, name) {
  const material = document.getRoot().listMaterials().find((candidate) => candidate.getName() === name);
  if (!material) throw new Error(`缺少源材质：${name}`);
  return material;
}

function findTexture(material, expectedName) {
  const texture = material.getBaseColorTexture();
  if (!texture || texture.getName() !== expectedName) throw new Error(`材质 ${material.getName()} 的基础色贴图不符合预期：${expectedName}`);
  return texture;
}

function materialEntries(document, group) {
  return group.materialNames.map((materialName, index) => {
    const material = findMaterial(document, materialName);
    const texture = findTexture(material, group.atlasNames[index]);
    return {material, texture};
  });
}

function remapUv(accessor, cell, transformedAccessors, document) {
  const previous = transformedAccessors.get(accessor);
  if (previous) {
    if (previous.cell.left === cell.left && previous.cell.top === cell.top) return accessor;
    const clone = document.createAccessor().copy(accessor);
    const cloneArray = clone.getArray();
    if (!cloneArray) throw new Error("TEXCOORD_0 访问器没有可写数组");
    for (let index = 0; index < cloneArray.length; index += 2) {
      cloneArray[index] = cloneArray[index] * 0.5 + cell.left / atlasSize;
      cloneArray[index + 1] = cloneArray[index + 1] * 0.5 + cell.top / atlasSize;
    }
    return clone;
  }
  const array = accessor.getArray();
  if (!array) throw new Error("TEXCOORD_0 访问器没有可写数组");
  for (let index = 0; index < array.length; index += 2) {
    array[index] = array[index] * 0.5 + cell.left / atlasSize;
    array[index + 1] = array[index + 1] * 0.5 + cell.top / atlasSize;
  }
  transformedAccessors.set(accessor, {cell});
  return accessor;
}

async function main() {
  const document = await new NodeIO().read(inputPath);
  const groupMaterials = new Map();
  const materialGroups = new Map();
  for (const group of Object.values(GROUPS)) {
    const entries = materialEntries(document, group);
    const baseAtlas = await composeAtlas(entries, (entry) => entry.texture.getImage());
    const metallicRoughnessAtlas = await composeAtlas(entries, (entry) => createSolidTile(entry.material));
    const baseTexture = document.createTexture(`${group.materialName}_base_color_atlas`).setMimeType("image/png").setImage(baseAtlas);
    const metallicRoughnessTexture = document.createTexture(`${group.materialName}_metallic_roughness_atlas`).setMimeType("image/png").setImage(metallicRoughnessAtlas);
    const representative = entries[0].material;
    const atlasMaterial = document.createMaterial(group.materialName)
      .copy(representative)
      .setName(group.materialName)
      .setBaseColorTexture(baseTexture)
      .setMetallicRoughnessTexture(metallicRoughnessTexture)
      .setMetallicFactor(1)
      .setRoughnessFactor(1)
      .setDoubleSided(true)
      .setAlphaMode("OPAQUE");
    groupMaterials.set(group.materialName, atlasMaterial);
    group.materialNames.forEach((materialName, index) => {
      materialGroups.set(materialName, {group, index, atlasMaterial});
    });
  }

  const transformedAccessors = new Map();
  let remappedPrimitives = 0;
  for (const mesh of document.getRoot().listMeshes()) {
    for (const primitive of mesh.listPrimitives()) {
      const sourceMaterial = primitive.getMaterial();
      if (!sourceMaterial) continue;
      const mapping = materialGroups.get(sourceMaterial.getName());
      if (!mapping) throw new Error(`没有图集分组的材质：${sourceMaterial.getName()}`);
      const uv = primitive.getAttribute("TEXCOORD_0");
      if (!uv) throw new Error(`材质 ${sourceMaterial.getName()} 的网格缺少 TEXCOORD_0`);
      const remapped = remapUv(uv, cellForIndex(mapping.index), transformedAccessors, document);
      if (remapped !== uv) primitive.setAttribute("TEXCOORD_0", remapped);
      primitive.setMaterial(mapping.atlasMaterial);
      remappedPrimitives += 1;
    }
  }

  for (const material of document.getRoot().listMaterials()) {
    if (!groupMaterials.has(material.getName())) material.dispose();
  }
  for (const texture of document.getRoot().listTextures()) {
    if (!texture.getName().includes("_atlas")) texture.dispose();
  }

  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  const temporaryOutputPath = `${outputPath}.tmp-${process.pid}.glb`;
  try {
    await new NodeIO().write(temporaryOutputPath, document);
    fs.renameSync(temporaryOutputPath, outputPath);
  } finally {
    fs.rmSync(temporaryOutputPath, {force: true});
  }
  console.log(`MakeHuman 材质图集候选已生成：${path.relative(workspaceRoot, outputPath)}`);
  console.log(`图集材质：${[...groupMaterials.keys()].join("、")}；重映射图元：${remappedPrimitives}`);
}

await main();

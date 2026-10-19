import fs from "node:fs";
import path from "node:path";
import {Document, NodeIO, Primitive} from "@gltf-transform/core";
import {normals, weld} from "@gltf-transform/functions";

const [, , inputObj, inputTexture, outputGlb] = process.argv;
if (!inputObj || !inputTexture || !outputGlb) {
  throw new Error("用法：node build_makehuman_obj_glb.mjs 输入OBJ 漫反射纹理 输出GLB");
}

const SCALE = 0.1;
const Y_OFFSET = 0.82;

function parseObj(text) {
  const positions = [];
  const texcoords = [];
  const normalsIn = [];
  const vertices = [];
  const uvs = [];
  const normalValues = [];
  const indices = [];
  const lookup = new Map();

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const parts = line.split(/\s+/);
    if (parts[0] === "v") positions.push(parts.slice(1, 4).map(Number));
    else if (parts[0] === "vt") texcoords.push(parts.slice(1, 3).map(Number));
    else if (parts[0] === "vn") normalsIn.push(parts.slice(1, 4).map(Number));
    else if (parts[0] === "f") {
      const face = parts.slice(1).map((token) => {
        const [positionIndex, uvIndex = "", normalIndex = ""] = token.split("/");
        return {positionIndex: Number(positionIndex), uvIndex: uvIndex ? Number(uvIndex) : 0, normalIndex: normalIndex ? Number(normalIndex) : 0};
      });
      for (let i = 1; i < face.length - 1; i++) {
        for (const corner of [face[0], face[i], face[i + 1]]) {
          const key = `${corner.positionIndex}/${corner.uvIndex}/${corner.normalIndex}`;
          let vertexIndex = lookup.get(key);
          if (vertexIndex == null) {
            const position = positions[corner.positionIndex > 0 ? corner.positionIndex - 1 : positions.length + corner.positionIndex];
            if (!position) throw new Error(`OBJ 顶点索引无效：${key}`);
            vertices.push(position[0] * SCALE, position[1] * SCALE + Y_OFFSET, position[2] * SCALE);
            const uv = texcoords[corner.uvIndex > 0 ? corner.uvIndex - 1 : texcoords.length + corner.uvIndex] || [0, 0];
            uvs.push(uv[0], 1 - uv[1]);
            const normal = normalsIn[corner.normalIndex > 0 ? corner.normalIndex - 1 : normalsIn.length + corner.normalIndex] || [0, 1, 0];
            normalValues.push(normal[0], normal[1], normal[2]);
            vertexIndex = vertices.length / 3 - 1;
            lookup.set(key, vertexIndex);
          }
          indices.push(vertexIndex);
        }
      }
    }
  }
  return {vertices, uvs, normalValues, indices};
}

const parsed = parseObj(fs.readFileSync(inputObj, "utf8"));
const document = new Document();
const buffer = document.createBuffer(path.basename(outputGlb));
const positionAccessor = document.createAccessor("位置").setType("VEC3").setArray(new Float32Array(parsed.vertices)).setBuffer(buffer);
const uvAccessor = document.createAccessor("纹理坐标").setType("VEC2").setArray(new Float32Array(parsed.uvs)).setBuffer(buffer);
const normalAccessor = document.createAccessor("法线").setType("VEC3").setArray(new Float32Array(parsed.normalValues)).setBuffer(buffer);
const indexAccessor = document.createAccessor("索引").setType("SCALAR").setArray(new Uint32Array(parsed.indices)).setBuffer(buffer);
const texture = document.createTexture("male_elegantsuit01_diffuse").setImage(fs.readFileSync(inputTexture)).setMimeType("image/png");
const material = document.createMaterial("male_elegantsuit01").setBaseColorTexture(texture).setRoughnessFactor(0.82).setMetallicFactor(0.0);
const primitive = document.createPrimitive(Primitive.Mode.TRIANGLES)
  .setAttribute("POSITION", positionAccessor)
  .setAttribute("NORMAL", normalAccessor)
  .setAttribute("TEXCOORD_0", uvAccessor)
  .setIndices(indexAccessor)
  .setMaterial(material);
const mesh = document.createMesh("male_elegantsuit01_unskinned").addPrimitive(primitive);
const node = document.createNode("male_elegantsuit01_unskinned").setMesh(mesh);
document.createScene("场景").addChild(node);
await document.transform(weld(), normals());
await new NodeIO().write(outputGlb, document);
console.log(`未蒙皮 MakeHuman 服装 GLB 已生成：${outputGlb}`);

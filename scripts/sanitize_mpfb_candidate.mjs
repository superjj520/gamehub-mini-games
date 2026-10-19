import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

const [input, output] = process.argv.slice(2);
if (!input || !output) throw new Error('用法：node scripts/sanitize_mpfb_candidate.mjs 输入.glb 输出.glb');

function resolveGltfTransformFile(relativePath) {
  const candidates = [];
  if (process.env.GLTF_TRANSFORM_ROOT) candidates.push(path.join(process.env.GLTF_TRANSFORM_ROOT, relativePath));
  candidates.push(path.join(process.cwd(), 'node_modules', relativePath));
  candidates.push(path.join(process.cwd(), 'node_modules/@gltf-transform/cli/node_modules', relativePath));
  try {
    const globalRoot = execFileSync('npm', ['root', '-g'], {encoding: 'utf8'}).trim();
    candidates.push(path.join(globalRoot, '@gltf-transform/cli/node_modules', relativePath));
  } catch {
    // npm 不可用时继续检查显式环境变量和项目本地依赖。
  }
  const resolved = candidates.find((candidate) => fs.existsSync(candidate));
  if (!resolved) {
    throw new Error(`找不到 glTF Transform 依赖：${relativePath}；请安装项目依赖，或设置 GLTF_TRANSFORM_ROOT`);
  }
  return pathToFileURL(resolved).href;
}

const {NodeIO} = await import(resolveGltfTransformFile('@gltf-transform/core/dist/index.js'));
const {prune} = await import(resolveGltfTransformFile('@gltf-transform/functions/dist/index.js'));
const keepTextures = process.env.GLTF_KEEP_TEXTURES === '1';

const io = new NodeIO();
const document = await io.read(input);
for (const material of document.getRoot().listMaterials()) {
  if (!keepTextures) {
    material.setBaseColorTexture(null);
    material.setNormalTexture(null);
    material.setMetallicRoughnessTexture(null);
    material.setOcclusionTexture(null);
    material.setEmissiveTexture(null);
  }
  material.setAlphaMode('OPAQUE');
  if (!keepTextures) {
    material.setBaseColorFactor([0.72, 0.64, 0.56, 1]);
    material.setRoughnessFactor(0.72);
    material.setMetallicFactor(0.0);
  }
}
for (const accessor of document.getRoot().listAccessors()) {
  // MakeHuman 导出的部分蒙皮访问器使用稀疏存储；展开后才能通过 Godot 的严格 glTF 导入。
  accessor.setSparse(false);
}
for (const mesh of document.getRoot().listMeshes()) {
  for (const primitive of mesh.listPrimitives()) {
    // 清洗版不带 UV，保留切线会让 Godot 尝试重新生成切线并报错。
    primitive.setAttribute('TANGENT', null);
  }
}
await document.transform(prune({keepLeaves: false}));
await io.write(output, document);
console.log(`已生成${keepTextures ? '保留纹理' : '无纹理'}诊断候选：${output}`);

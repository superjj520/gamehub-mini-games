import { NodeIO } from '/Users/superjj/.npm-global/lib/node_modules/@gltf-transform/cli/node_modules/@gltf-transform/core/dist/index.js';
import { prune } from '/Users/superjj/.npm-global/lib/node_modules/@gltf-transform/cli/node_modules/@gltf-transform/functions/dist/index.js';

const [input, output, keepMeshRaw] = process.argv.slice(2);
const keepMesh = Number.parseInt(keepMeshRaw ?? '-1', 10);
const io = new NodeIO();
const document = await io.read(input);
for (const node of document.getRoot().listNodes()) {
  node.setSkin(null);
  const mesh = node.getMesh();
  if (mesh && document.getRoot().listMeshes().indexOf(mesh) !== keepMesh) node.setMesh(null);
}
for (const material of document.getRoot().listMaterials()) {
  material.setBaseColorTexture(null);
  material.setNormalTexture(null);
  material.setMetallicRoughnessTexture(null);
  material.setOcclusionTexture(null);
  material.setEmissiveTexture(null);
  material.setAlphaMode('OPAQUE');
  material.setBaseColorFactor([0.72, 0.64, 0.56, 1]);
}
await document.transform(prune({keepLeaves: false}));
await io.write(output, document);
console.log(`保留网格 ${keepMesh}：${output}`);

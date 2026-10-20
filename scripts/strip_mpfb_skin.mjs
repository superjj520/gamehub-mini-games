import { NodeIO } from '/Users/superjj/.npm-global/lib/node_modules/@gltf-transform/cli/node_modules/@gltf-transform/core/dist/index.js';
import { prune } from '/Users/superjj/.npm-global/lib/node_modules/@gltf-transform/cli/node_modules/@gltf-transform/functions/dist/index.js';

const [input, output] = process.argv.slice(2);
if (!input || !output) throw new Error('用法：node scripts/strip_mpfb_skin.mjs 输入.glb 输出.glb');

const io = new NodeIO();
const document = await io.read(input);
for (const node of document.getRoot().listNodes()) node.setSkin(null);
for (const mesh of document.getRoot().listMeshes()) {
  for (const primitive of mesh.listPrimitives()) {
    primitive.setAttribute('JOINTS_0', null);
    primitive.setAttribute('WEIGHTS_0', null);
  }
}
await document.transform(prune({keepLeaves: false}));
await io.write(output, document);
console.log(`已生成无骨骼诊断候选：${output}`);

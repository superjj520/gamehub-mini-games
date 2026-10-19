import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const root = process.cwd();
const manifestPath = path.join(root, "docs", "visual-concept-manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const expectedLogicStates = [
  ...Array.from({length: 10}, (_, index) => `office-${String(index + 1).padStart(2, "0")}`),
  ...Array.from({length: 11}, (_, index) => `city-${String(index + 1).padStart(2, "0")}`),
];

function fail(message) {
  throw new Error(`视觉稿清单校验失败：${message}`);
}

if (manifest.schema_version !== 1) fail("schema_version 不是 1");
if (!Array.isArray(manifest.concepts) || manifest.concepts.length < 5) {
  fail("视觉稿数量少于五项核心资产");
}

const ids = new Set();
const stateOwners = new Map();
for (const concept of manifest.concepts) {
  if (!concept.id || ids.has(concept.id)) fail(`视觉稿 id 重复或为空：${concept.id}`);
  ids.add(concept.id);
  if (!concept.path || !concept.asset_class) fail(`视觉稿缺少路径或资产类别：${concept.id}`);
  if (!Array.isArray(concept.logic_states) || concept.logic_states.length === 0) {
    fail(`${concept.id} 没有绑定逻辑状态`);
  }
  const localStates = new Set();
  for (const state of concept.logic_states) {
    if (!expectedLogicStates.includes(state)) fail(`${concept.id} 绑定了未知逻辑状态：${state}`);
    if (localStates.has(state)) fail(`${concept.id} 重复绑定逻辑状态：${state}`);
    localStates.add(state);
    const owners = stateOwners.get(state) ?? [];
    owners.push(concept.id);
    stateOwners.set(state, owners);
  }
  if (!Array.isArray(concept.required_mount_points) && !Array.isArray(concept.required_scene_layers)) {
    fail(`${concept.id} 没有绑定挂点或场景层`);
  }
  const conceptPath = path.resolve(root, concept.path);
  if (!fs.existsSync(conceptPath)) fail(`${concept.id} 的视觉稿不存在：${concept.path}`);
  const digest = crypto.createHash("sha256").update(fs.readFileSync(conceptPath)).digest("hex");
  if (digest !== concept.sha256) fail(`${concept.id} 的 SHA-256 与清单不一致`);
  if (!concept.runtime_target) fail(`${concept.id} 没有 runtime_target`);
  const runtimeTarget = path.resolve(root, concept.runtime_target);
  if (!fs.existsSync(runtimeTarget)) fail(`${concept.id} 的运行时目标不存在：${concept.runtime_target}`);
}

const missingStates = expectedLogicStates.filter((state) => !stateOwners.has(state));
if (missingStates.length > 0) fail(`21 段逻辑状态仍缺少视觉生产稿覆盖：${missingStates.join(", ")}`);

console.log(`视觉稿清单校验通过：${manifest.concepts.length} 项；逻辑状态覆盖 ${stateOwners.size}/${expectedLogicStates.length}；每项均已绑定运行时目标和文件指纹`);

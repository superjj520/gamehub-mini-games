import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const projectRoot = path.resolve(".");
const rightsManifestPath = path.resolve("gta-reference-runtime/content/rights-manifest.json");
const rightsManifest = JSON.parse(fs.readFileSync(rightsManifestPath, "utf8"));

function fail(message) {
  throw new Error(message);
}

function assert(condition, message) {
  if (!condition) fail(message);
}

function resolveProjectFile(relativePath, label) {
  assert(typeof relativePath === "string" && relativePath.length > 0, `${label}路径为空`);
  const normalized = relativePath.startsWith("res://")
    ? path.resolve("gta-reference-runtime", relativePath.slice("res://".length))
    : path.resolve(relativePath);
  assert(normalized === projectRoot || normalized.startsWith(`${projectRoot}${path.sep}`), `${label}越出工程目录：${relativePath}`);
  assert(fs.existsSync(normalized), `${label}不存在：${relativePath}`);
  return normalized;
}

function hashFile(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function resolveRuntimeAsset(relativePath, label) {
  const candidates = [
    path.resolve(relativePath),
    path.resolve("gta-reference-runtime", relativePath),
  ];
  const resolved = candidates.find((candidate) => fs.existsSync(candidate));
  assert(resolved, `${label}不存在：${relativePath}`);
  return resolved;
}

assert(Array.isArray(rightsManifest.assets), "权利清单缺少 assets 数组");
assert(Array.isArray(rightsManifest.third_party_components), "权利清单缺少 third_party_components 数组");

const assetIds = new Set();
let checkedFiles = 0;
let blockedCandidates = 0;
for (const asset of rightsManifest.assets) {
  assert(asset && typeof asset === "object", "权利清单存在非对象资产条目");
  assert(typeof asset.id === "string" && asset.id.length > 0, "权利清单存在空资产 id");
  assert(!assetIds.has(asset.id), `权利清单存在重复资产 id：${asset.id}`);
  assetIds.add(asset.id);
  assert(typeof asset.release_candidate_required === "boolean", `资产缺少 release_candidate_required：${asset.id}`);
  assert(typeof asset.release_allowed === "boolean", `资产缺少 release_allowed：${asset.id}`);
  assert(Array.isArray(asset.release_scope_ids), `资产缺少 release_scope_ids：${asset.id}`);
  assert(new Set(asset.release_scope_ids).size === asset.release_scope_ids.length, `资产 release_scope_ids 存在重复：${asset.id}`);
  if (asset.asset_slot_ids !== undefined) {
    assert(Array.isArray(asset.asset_slot_ids), `资产 asset_slot_ids 必须为数组：${asset.id}`);
    assert(new Set(asset.asset_slot_ids).size === asset.asset_slot_ids.length, `资产 asset_slot_ids 存在重复：${asset.id}`);
  }

  if (asset.release_candidate_required && asset.release_allowed === false) {
    blockedCandidates += 1;
    assert(asset.status === "internal_candidate_only", `候选资产必须保持 internal_candidate_only：${asset.id}`);
    assert(typeof asset.conditions === "string" && asset.conditions.length > 0, `候选资产缺少升级条件：${asset.id}`);
  }

  for (const runtimeFile of asset.derived_runtime_files ?? []) {
    const resolved = resolveRuntimeAsset(runtimeFile, `资产 ${asset.id} 的运行时文件`);
    checkedFiles += 1;
    const expectedHash = asset.sha256?.[path.basename(runtimeFile)];
    if (expectedHash) {
      assert(hashFile(resolved) === expectedHash, `资产 ${asset.id} 的运行时文件哈希不匹配：${runtimeFile}`);
    }
  }

  for (const sourceFile of asset.derived_source_files ?? []) {
    resolveProjectFile(sourceFile, `资产 ${asset.id} 的源文件`);
    checkedFiles += 1;
  }

  if (asset.license_copy) {
    resolveProjectFile(asset.license_copy, `资产 ${asset.id} 的许可证副本`);
    checkedFiles += 1;
  }
}

const componentIds = new Set();
let inUseComponents = 0;
for (const component of rightsManifest.third_party_components) {
  assert(component && typeof component === "object", "权利清单存在非对象组件条目");
  assert(typeof component.id === "string" && component.id.length > 0, "权利清单存在空组件 id");
  assert(!componentIds.has(component.id), `权利清单存在重复组件 id：${component.id}`);
  componentIds.add(component.id);
  assert(typeof component.source === "string" && component.source.length > 0, `组件缺少来源：${component.id}`);
  assert(typeof component.license === "string" && component.license.length > 0, `组件缺少许可证：${component.id}`);
  if (component.status === "in_use") {
    inUseComponents += 1;
    assert(component.release_allowed === true, `在用组件不得标为不可发布：${component.id}`);
    assert(typeof component.conditions === "string" && component.conditions.length > 0, `在用组件缺少发布条件：${component.id}`);
  }
}

console.log(`权利来源证据验证通过：${assetIds.size} 个资产、${blockedCandidates} 个内部候选、${checkedFiles} 个文件证据、${inUseComponents} 个在用第三方组件`);

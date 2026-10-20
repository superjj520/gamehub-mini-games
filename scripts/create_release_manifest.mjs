import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import {resolveScope} from "./release_scope.mjs";
import {rightsAssetsForScope} from "./release_rights_scope.mjs";

const workspaceRoot = path.resolve(".");
const runtimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const projectPath = path.join(runtimeRoot, "project.godot");
const rightsPath = path.join(runtimeRoot, "content", "rights-manifest.json");
const noticesPath = path.join(runtimeRoot, "THIRD_PARTY_NOTICES.md");
const productDecisionPath = path.join(workspaceRoot, "docs", "product-baseline-decision.json");
const outputPath = path.join(workspaceRoot, "docs", "release-manifest.json");
const ignoredDirectories = new Set([".godot", ".import"]);

function collectFiles(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true }).sort((left, right) => left.name.localeCompare(right.name));
  const files = [];
  for (const entry of entries) {
    if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...collectFiles(absolutePath));
    } else if (entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) {
      files.push(absolutePath);
    }
  }
  return files;
}

function fingerprintRuntime() {
  const hash = crypto.createHash("sha256");
  const files = collectFiles(runtimeRoot);
  for (const filePath of files) {
    const relativePath = path.relative(runtimeRoot, filePath).split(path.sep).join("/");
    hash.update(relativePath);
    hash.update("\0");
    hash.update(fs.readFileSync(filePath));
    hash.update("\0");
  }
  return { sha256: hash.digest("hex"), file_count: files.length };
}

function inventoryRuntime() {
  return collectFiles(runtimeRoot).map((filePath) => ({
    path: path.relative(runtimeRoot, filePath).split(path.sep).join("/"),
    bytes: fs.statSync(filePath).size,
    sha256: crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex"),
  }));
}

function requiredMatch(text, pattern, label) {
  const match = text.match(pattern);
  if (!match) throw new Error(`无法从项目配置读取${label}`);
  return match[1];
}

if (!fs.existsSync(projectPath) || !fs.existsSync(rightsPath) || !fs.existsSync(noticesPath)) {
  throw new Error("缺少 Godot 项目配置、权利清单或第三方声明索引");
}

const projectText = fs.readFileSync(projectPath, "utf8");
const rights = JSON.parse(fs.readFileSync(rightsPath, "utf8"));
const productDecision = JSON.parse(fs.readFileSync(productDecisionPath, "utf8"));
const engineOutput = execFileSync("godot", ["--version"], { encoding: "utf8" }).trim();
const fingerprint = fingerprintRuntime();
const assets = Array.isArray(rights.assets) ? rights.assets : [];
const components = Array.isArray(rights.third_party_components) ? rights.third_party_components : [];
const contentFiles = ["content-pack-manifest.json", "office_mission.json", "city_mission.json", "audio_cues.json", "audio-runtime-catalog.json", "launch-profile.json"];
const inventory = inventoryRuntime();
const requestedScope = resolveScope(productDecision.launch_scope);
const launchScopeId = productDecision.launch_scope?.[0] ?? null;
const visualScopeLabel = requestedScope ? `${requestedScope.segmentIds.length} 个首发范围视觉分段` : "首发范围视觉分段";
const scopedRightsAssets = rightsAssetsForScope(assets, launchScopeId);
const requiredBlockedAssets = scopedRightsAssets.filter((asset) => asset.release_allowed !== true);
const releaseBlockers = [];
if (productDecision.status !== "approved") releaseBlockers.push("产品基线尚未获得用户确认");
if (requiredBlockedAssets.length > 0) releaseBlockers.push("最终角色、场景、载具、动画和音频资产未完成权利登记");
releaseBlockers.push(`${visualScopeLabel}的验收状态仍为 unverified`);
if (!fs.existsSync(path.join(runtimeRoot, "export_presets.cfg"))) {
  releaseBlockers.push("Steam Windows 导出预设、目标设备性能、输入、隐私和商店材料尚未验证");
} else {
  releaseBlockers.push("Steam Windows 目标设备性能、输入、隐私和商店材料尚未验证");
}

const manifest = {
  schema_version: 1,
  status: "internal_no_go",
  reason: "最终资产、目标设备和视觉验收尚未完成",
  project: {
    name: requiredMatch(projectText, /config\/name="([^"]+)"/, "项目名称"),
    version: requiredMatch(projectText, /config\/version="([^"]+)"/, "项目版本"),
    engine: engineOutput,
    renderer: requiredMatch(projectText, /renderer\/rendering_method="([^"]+)"/, "渲染器"),
    main_scene: requiredMatch(projectText, /run\/main_scene="([^"]+)"/, "主场景"),
  },
  source: {
    root: "gta-reference-runtime",
    sha256: fingerprint.sha256,
    file_count: fingerprint.file_count,
    files: inventory,
  },
  content_packages: contentFiles.map((fileName) => {
    const filePath = path.join(runtimeRoot, "content", fileName);
    const payload = JSON.parse(fs.readFileSync(filePath, "utf8"));
    if (typeof payload.id !== "string" || payload.id.length === 0 || !Number.isInteger(payload.version) || payload.version < 1) {
      throw new Error(`内容包缺少可发布的 id/version：${fileName}`);
    }
    return {
      path: `content/${fileName}`,
      id: payload.id,
      version: payload.version,
    };
  }),
  rights: {
    release_allowed_assets: assets.filter((asset) => asset.release_allowed === true).length,
    required_blocked_assets: requiredBlockedAssets.map((asset) => asset.id),
    launch_scope_id: launchScopeId,
    out_of_scope_candidate_assets: assets.filter((asset) => asset.release_candidate_required === true && !scopedRightsAssets.includes(asset)).map((asset) => asset.id),
    blocked_assets: assets.filter((asset) => asset.release_allowed !== true).map((asset) => asset.id),
    excluded_internal_assets: assets.filter((asset) => asset.release_candidate_required === false).map((asset) => asset.id),
    in_use_components: components.filter((component) => component.status === "in_use").map((component) => ({
      id: component.id,
      version: component.version,
      license: component.license,
      release_allowed: component.release_allowed === true,
    })),
  },
  third_party_notices: {
    path: "THIRD_PARTY_NOTICES.md",
    status: "internal_index_requires_official_license_text_before_release",
  },
  excluded_from_runtime: [
    "reference-evidence/",
    "视频参考文件",
    "未授权商业资产",
  ],
  release_blockers: releaseBlockers,
};

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
console.log(`候选发布清单已生成：${path.relative(workspaceRoot, outputPath)}；状态 ${manifest.status}；源文件 ${fingerprint.file_count} 个`);

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const root = process.cwd();
const formalRoot = path.join(root, "gta-reference-runtime");
const candidateRoot = path.join(root, "build", "internal-full-candidate");
const originalCandidateRoot = path.join(root, "build", "internal-full-candidate-original");
const presetPath = path.join(formalRoot, "export_presets.cfg");
const rightsPath = path.join(formalRoot, "content", "rights-manifest.json");
const candidateRegistryPath = path.join(root, "docs", "asset-candidate-registry.json");
const launchProfilePath = path.join(formalRoot, "content", "launch-profile.json");
const releaseManifestPath = path.join(root, "docs", "release-manifest.json");
const reportPath = path.join(root, "reference-evidence", "candidate-runtime", "release-separation-report.json");

function readJson(filePath) {
  if (!fs.existsSync(filePath)) throw new Error(`发行边界核验缺少文件：${path.relative(root, filePath)}`);
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function collectFiles(directory) {
  const files = [];
  const walk = (current) => {
    for (const entry of fs.readdirSync(current, {withFileTypes: true}).sort((left, right) => left.name.localeCompare(right.name))) {
      if (entry.isDirectory() && [".godot", ".import"].includes(entry.name)) continue;
      const absolutePath = path.join(current, entry.name);
      if (entry.isDirectory()) walk(absolutePath);
      else if (entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) files.push(absolutePath);
    }
  };
  walk(directory);
  return files;
}

function parsePreset(presetText, index) {
  const block = presetText.match(new RegExp(`\\[preset\\.${index}\\]([\\s\\S]*?)(?=\\n\\[preset\\.${index}\\.options\\])`));
  if (!block) throw new Error(`缺少导出预设 preset.${index}`);
  const values = {};
  for (const line of block[1].split(/\r?\n/)) {
    const match = line.match(/^([a-zA-Z0-9_]+)=(?:"([^"]*)"|([^\s]+))$/);
    if (match) values[match[1]] = match[2] ?? match[3];
  }
  return values;
}

function matchesFilter(assetPath, filter) {
  return filter.endsWith("/*") ? assetPath.startsWith(filter.slice(0, -1)) : assetPath === filter;
}

const presetText = fs.readFileSync(presetPath, "utf8");
const internalPreset = parsePreset(presetText, 0);
const launchPreset = parsePreset(presetText, 1);
const rights = readJson(rightsPath);
const candidateRegistry = readJson(candidateRegistryPath);
const launchProfile = readJson(launchProfilePath);
const releaseManifest = readJson(releaseManifestPath);

const errors = [];
const formalFiles = collectFiles(formalRoot);
const formalRelativeFiles = formalFiles.map((filePath) => path.relative(formalRoot, filePath).split(path.sep).join("/"));
const forbiddenFormalFragments = [
  "reference-evidence/",
  "video-1/",
  "video-2/",
  "full-candidate-preview.marker",
  "candidate-package-manifest.json",
  "CANDIDATE_PACKAGE_README.md",
];
for (const fragment of forbiddenFormalFragments) {
  const leakingFiles = formalRelativeFiles.filter((filePath) => filePath.includes(fragment));
  if (leakingFiles.length > 0) errors.push(`正式运行时包含候选或参考证据文件：${leakingFiles.join(", ")}`);
}

if (internalPreset.name !== "新时代觉醒者 Windows 内部测试" || internalPreset.runnable !== "true") {
  errors.push("内部测试预设必须保持可运行且明确标记为内部测试");
}
if (internalPreset.export_path !== "../build/windows/新时代觉醒者.exe") {
  errors.push("内部测试预设输出路径发生变化");
}
if (launchPreset.name !== "新时代觉醒者 Windows 首发候选" || launchPreset.runnable !== "false") {
  errors.push("首发候选预设必须保持不可直接运行的待验收状态");
}
if (launchPreset.export_path === internalPreset.export_path) {
  errors.push("首发候选预设不能覆盖内部测试构建");
}

const candidateFilters = String(launchPreset.exclude_filter || "").split(",").map((item) => item.trim()).filter(Boolean);
const blockedRuntimePaths = new Set();
for (const asset of rights.assets ?? []) {
  if (asset.release_allowed === true) continue;
  for (const runtimePath of asset.derived_runtime_files ?? []) blockedRuntimePaths.add(runtimePath);
}
for (const candidate of candidateRegistry.candidates ?? []) {
  if (candidate.release_allowed !== false) continue;
  for (const assetPath of candidate.asset_paths ?? []) {
    blockedRuntimePaths.add(String(assetPath).replace(/^gta-reference-runtime\//, ""));
  }
}
const unexcluded = [...blockedRuntimePaths].filter((assetPath) => !candidateFilters.some((filter) => matchesFilter(assetPath, filter)));
if (unexcluded.length > 0) errors.push(`首发候选预设未排除未授权或未定稿资产：${unexcluded.join(", ")}`);

const launchProfileAssetCatalogs = [];
for (const entry of launchProfile.entries ?? []) {
  const catalogPath = String(entry.asset_catalog_path ?? "");
  if (!catalogPath.startsWith("res://")) {
    launchProfileAssetCatalogs.push({
      entry_id: String(entry.id ?? "unknown"),
      path: catalogPath,
      status: "invalid_path",
      blocked_scene_paths: [],
    });
    continue;
  }
  const relativeCatalogPath = catalogPath.slice("res://".length);
  const absoluteCatalogPath = path.join(formalRoot, relativeCatalogPath);
  if (!fs.existsSync(absoluteCatalogPath)) {
    errors.push(`正式启动入口引用的资产目录不存在：${catalogPath}`);
    launchProfileAssetCatalogs.push({
      entry_id: String(entry.id ?? "unknown"),
      path: catalogPath,
      status: "missing",
      blocked_scene_paths: [],
    });
    continue;
  }
  let catalog;
  try {
    catalog = readJson(absoluteCatalogPath);
  } catch (error) {
    errors.push(`正式启动入口引用的资产目录无法解析：${catalogPath}；${error.message}`);
    launchProfileAssetCatalogs.push({
      entry_id: String(entry.id ?? "unknown"),
      path: catalogPath,
      status: "invalid_json",
      blocked_scene_paths: [],
    });
    continue;
  }
  const blockedScenePaths = (catalog.slots ?? [])
    .map((slot) => String(slot?.scene_path ?? "").replace(/^res:\/\//, ""))
    .filter((scenePath) => scenePath && blockedRuntimePaths.has(scenePath));
  const catalogStatus = blockedScenePaths.length > 0 ? "internal_only_candidate_assets" : "release_compatible";
  launchProfileAssetCatalogs.push({
    entry_id: String(entry.id ?? "unknown"),
    path: catalogPath,
    status: catalogStatus,
    blocked_scene_paths: blockedScenePaths,
  });
  // 当前发布清单仍是 internal_no_go，原创候选目录只能用于内部试玩；
  // 一旦未来进入可发布状态，首发入口不得继续引用会被导出预设排除的场景。
  if (releaseManifest.status !== "internal_no_go" && blockedScenePaths.length > 0) {
    errors.push(`可发布启动入口仍引用首发预设会排除的候选场景：${entry.id ?? "unknown"} -> ${blockedScenePaths.join(", ")}`);
  }
}

if (launchProfile.status !== "approved" || launchProfile.internal_development_mode !== false) {
  errors.push("正式运行时启动入口必须是已确认基线且关闭内部开发模式");
}
if ((launchProfile.entries ?? []).some((entry) => String(entry.id).includes("candidate") || String(entry.scene_path).includes("art-source"))) {
  errors.push("正式运行时启动入口包含候选内容入口");
}

if (releaseManifest.status !== "internal_no_go") {
  errors.push(`发布清单状态必须保持 internal_no_go，当前为 ${releaseManifest.status}`);
}
if (releaseManifest.source?.root !== "gta-reference-runtime") {
  errors.push("发布清单源根目录不是正式运行时");
}

const candidateSummaries = [];
for (const candidatePath of [candidateRoot, originalCandidateRoot]) {
  if (!fs.existsSync(candidatePath)) continue;
  const candidateManifestPath = path.join(candidatePath, "candidate-package-manifest.json");
  const markerPath = path.join(candidatePath, "content", "full-candidate-preview.marker");
  if (!fs.existsSync(candidateManifestPath) || !fs.existsSync(markerPath)) {
    errors.push("完整候选包存在但缺少候选清单或内部启动标记");
  } else {
    const candidateManifest = readJson(candidateManifestPath);
    const marker = fs.readFileSync(markerPath, "utf8").trim();
    if (candidateManifest.status !== "internal_candidate_review_only" || candidateManifest.release_allowed !== false) {
      errors.push("完整候选包没有保持 internal_candidate_review_only/release_allowed=false");
    }
    if (marker !== "internal_candidate_review_only") errors.push("完整候选包启动标记内容错误");
    candidateSummaries.push({
      path: path.relative(root, candidatePath).split(path.sep).join("/"),
      character_variant: candidateManifest.character_variant ?? "makehuman",
      status: candidateManifest.status,
      release_allowed: candidateManifest.release_allowed,
      sha256: candidateManifest.package?.sha256 ?? null,
      file_count: candidateManifest.package?.file_count ?? null,
    });
  }
}
const candidateSummary = candidateSummaries[0] ?? null;

const sourceFingerprintLine = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: root, encoding: "utf8"}).trim();
const sourceFingerprint = sourceFingerprintLine.split(/\s+/)[0];
const report = {
  schema_version: 1,
  status: errors.length === 0 ? "passed_internal_boundary" : "blocked",
  generated_at: new Date().toISOString(),
  formal_runtime: {
    path: "gta-reference-runtime",
    source_fingerprint: sourceFingerprint,
    file_count: formalFiles.length,
    launch_profile: launchProfile.status,
  },
  export_presets: {
    internal_test: {name: internalPreset.name, runnable: internalPreset.runnable, export_path: internalPreset.export_path},
    first_launch_candidate: {name: launchPreset.name, runnable: launchPreset.runnable, export_path: launchPreset.export_path, exclude_filter_count: candidateFilters.length},
  },
  launch_profile_asset_catalogs: launchProfileAssetCatalogs,
  candidate_package: candidateSummary,
  candidate_packages: candidateSummaries,
  policy: "正式运行时、内部测试构建和完整候选包必须分离；候选包不得升级为 release_allowed=true。",
  errors,
};
fs.mkdirSync(path.dirname(reportPath), {recursive: true});
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");

if (errors.length > 0) {
  console.error(`发行边界隔离核验失败：${errors.length} 项`);
  for (const error of errors) console.error(`- ${error}`);
  process.exit(1);
}
console.log(`发行边界隔离核验通过：正式运行时 ${formalFiles.length} 个文件；候选排除规则 ${candidateFilters.length} 条；候选包保持 release_allowed=false`);

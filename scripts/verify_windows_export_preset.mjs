import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const presetPath = path.join(root, "gta-reference-runtime", "export_presets.cfg");
const projectPath = path.join(root, "gta-reference-runtime", "project.godot");
const rightsPath = path.join(root, "gta-reference-runtime", "content", "rights-manifest.json");
const candidateRegistryPath = path.join(root, "docs", "asset-candidate-registry.json");

if (!fs.existsSync(presetPath)) {
  throw new Error("缺少 Windows Desktop 导出预设");
}

const preset = fs.readFileSync(presetPath, "utf8");
const project = fs.readFileSync(projectPath, "utf8");
const rights = JSON.parse(fs.readFileSync(rightsPath, "utf8"));
const candidateRegistry = JSON.parse(fs.readFileSync(candidateRegistryPath, "utf8"));
const requiredPresetFields = [
  'platform="Windows Desktop"',
  'export_path="../build/windows/新时代觉醒者.exe"',
  'binary_format/architecture="x86_64"',
  'application/product_name="新时代觉醒者"',
  'application/product_version="0.1.0-dev"',
  'name="新时代觉醒者 Windows 首发候选"',
  'exclude_filter="tests/*,.godot/*,assets/audio/generated/*,assets/characters/quaternius-superhero-male/*,assets/characters/original-procedural-office-characters/*,assets/characters/original-procedural-city-crowd/*,assets/environment/generated/*,assets/environment/cc0/*,assets/environment/quaternius-downtown/*,assets/environment/original-procedural-city-environment/*,content/candidates/*,assets/props/original-procedural-interaction-props/*,assets/vehicles/three-wheel-delivery/*"',
  'export_path="../build/windows/新时代觉醒者-首发候选.exe"',
];
for (const field of requiredPresetFields) {
  if (!preset.includes(field)) throw new Error(`Windows 导出预设缺少字段：${field}`);
}
if (!project.includes('config/name="新时代觉醒者"')) {
  throw new Error("运行时工程名称没有锁定为产品名");
}

const candidatePresetMatch = preset.match(/\[preset\.1\]([\s\S]*?)(?=\n\[preset\.1\.options\])/);
if (!candidatePresetMatch) throw new Error("缺少 Windows 首发候选预设选项");
const candidateExcludeMatch = candidatePresetMatch[1].match(/^exclude_filter="([^"]*)"$/m);
if (!candidateExcludeMatch) throw new Error("Windows 首发候选预设缺少 exclude_filter");
const candidateExcludeFilters = candidateExcludeMatch[1].split(",").map((item) => item.trim()).filter(Boolean);
const candidateAssetPaths = new Set();
for (const asset of rights.assets ?? []) {
  if (asset.release_allowed === true) continue;
  for (const runtimePath of asset.derived_runtime_files ?? []) candidateAssetPaths.add(runtimePath);
}
for (const candidate of candidateRegistry.candidates ?? []) {
  if (candidate.release_allowed !== false) continue;
  for (const assetPath of candidate.asset_paths ?? []) {
    candidateAssetPaths.add(assetPath.replace(/^gta-reference-runtime\//, ""));
  }
}
function matchesFilter(assetPath, filter) {
  if (filter.endsWith("/*")) return assetPath.startsWith(filter.slice(0, -1));
  return assetPath === filter;
}
const unexcludedCandidatePaths = [...candidateAssetPaths].filter(
  (assetPath) => !candidateExcludeFilters.some((filter) => matchesFilter(assetPath, filter)),
);
if (unexcludedCandidatePaths.length > 0) {
  throw new Error(`Windows 首发候选预设仍可能打入未授权候选资产：${unexcludedCandidatePaths.join(", ")}`);
}
const requiredCandidateFilters = [
  "assets/audio/generated/*",
  "assets/characters/quaternius-superhero-male/*",
  "assets/environment/generated/*",
  "assets/environment/cc0/*",
  "assets/environment/quaternius-downtown/*",
  "assets/vehicles/three-wheel-delivery/*",
];
for (const filter of requiredCandidateFilters) {
  if (!candidateExcludeFilters.includes(filter)) {
    throw new Error(`Windows 首发候选预设缺少候选资产排除规则：${filter}`);
  }
}

const templateCandidates = [
  process.env.GODOT_WINDOWS_TEMPLATE,
  path.join(process.env.HOME ?? "", ".local", "share", "godot", "export_templates"),
  path.join(process.env.HOME ?? "", "Library", "Application Support", "Godot", "export_templates"),
].filter(Boolean);
const templateRoot = templateCandidates.find((candidate) => {
  if (!fs.existsSync(candidate)) return false;
  try {
    return fs.statSync(candidate).isFile() || fs.readdirSync(candidate).length > 0;
  } catch {
    return false;
  }
}) ?? null;
const versionedTemplateRoot = templateRoot ? path.join(templateRoot, "4.7.1.stable") : null;
const requiredTemplates = ["windows_debug_x86_64.exe", "windows_release_x86_64.exe"];
const templatesReady = Boolean(versionedTemplateRoot)
  && requiredTemplates.every((name) => {
    const filePath = path.join(versionedTemplateRoot, name);
    return fs.existsSync(filePath) && fs.statSync(filePath).size > 1024 * 1024;
  });
const templateStatus = templatesReady ? "detected" : "missing_or_incomplete";

console.log(`Windows 导出预设验证通过：产品名为新时代觉醒者；模板状态 ${templateStatus}`);
if (templatesReady) console.log(`检测到 4.7.1 Windows x86_64 Debug/Release 模板：${versionedTemplateRoot}；仍需完成目标设备回归`);
else console.log("未检测到 Windows 导出模板；当前只能证明预设存在，不能生成可验证 Windows 构建");

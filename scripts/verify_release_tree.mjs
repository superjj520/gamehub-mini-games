import fs from "node:fs";
import path from "node:path";

const projectRoot = path.resolve("gta-reference-runtime");
const projectFile = path.join(projectRoot, "project.godot");
const rightsFile = path.join(projectRoot, "content", "rights-manifest.json");
const noticesFile = path.join(projectRoot, "THIRD_PARTY_NOTICES.md");
const ignoredDirectories = new Set([".godot", ".import"]);
const requiredContentFiles = [
	path.join(projectRoot, "content", "content-pack-manifest.json"),
	path.join(projectRoot, "content", "office_mission.json"),
  path.join(projectRoot, "content", "city_mission.json"),
  path.join(projectRoot, "content", "audio_cues.json"),
  path.join(projectRoot, "content", "audio-runtime-catalog.json"),
  path.join(projectRoot, "content", "launch-profile.json"),
];

if (!fs.existsSync(projectFile) || !fs.existsSync(rightsFile) || !fs.existsSync(noticesFile)) {
  throw new Error("发布工程缺少项目配置、权利清单或第三方声明索引");
}
for (const requiredFile of requiredContentFiles) {
  if (!fs.existsSync(requiredFile)) {
    throw new Error(`发布工程缺少内容包：${path.relative(projectRoot, requiredFile)}`);
  }
}

const projectText = fs.readFileSync(projectFile, "utf8");
if (!projectText.includes('run/main_scene="res://scenes/launcher.tscn"')) {
  throw new Error("发布工程主场景不是启动器");
}
const requiredAutoloads = {
  "LaunchContext": "res://scripts/launch_context.gd",
  "SessionJournal": "res://scripts/session_journal.gd",
};
for (const [name, scriptPath] of Object.entries(requiredAutoloads)) {
  if (!projectText.includes(`${name}="*${scriptPath}"`)) {
    throw new Error(`发布工程缺少自动加载单例：${name}`);
  }
}
if (!projectText.match(/config\/version="[^"]+"/)) {
  throw new Error("发布工程缺少版本号");
}

const rights = JSON.parse(fs.readFileSync(rightsFile, "utf8"));
const notices = fs.readFileSync(noticesFile, "utf8");
if (!Array.isArray(rights.assets) || !Array.isArray(rights.third_party_components)) {
  throw new Error("权利清单结构不完整");
}
const inUseComponents = rights.third_party_components.filter((component) => component.status === "in_use");
for (const component of inUseComponents) {
  if (!notices.includes(String(component.id)) && !notices.includes(String(component.source))) {
    throw new Error(`第三方声明索引没有覆盖在用组件：${component.id}`);
  }
}

const forbiddenPathFragments = [
  "reference-evidence",
  "video-1-china-gta",
  "video-2-off-work",
  "commercial-game-assets",
];
const forbiddenExtensions = new Set([".mp4", ".mov", ".avi"]);
const files = [];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (ignoredDirectories.has(entry.name)) continue;
      walk(absolute);
      continue;
    }
    if (entry.name.endsWith(".import") || entry.name.endsWith(".uid")) continue;
    files.push(absolute);
  }
}

walk(projectRoot);
for (const file of files) {
  const relative = path.relative(projectRoot, file).replaceAll(path.sep, "/");
  const normalized = relative.toLowerCase();
  if (forbiddenPathFragments.some((fragment) => normalized.includes(fragment))) {
    throw new Error(`发布工程包含内部或被拒绝内容：${relative}`);
  }
  if (forbiddenExtensions.has(path.extname(normalized))) {
    throw new Error(`发布工程包含参考视频格式：${relative}`);
  }
}

const blockedAssets = rights.assets.filter((asset) => asset.release_candidate_required === true && asset.release_allowed !== true);
const excludedInternalAssets = rights.assets.filter((asset) => asset.release_candidate_required === false);
if (inUseComponents.some((component) => component.release_allowed !== true)) {
  throw new Error("权利清单中存在不可发布的在用第三方组件");
}

console.log(`发布工程边界检查通过：运行时文件 ${files.length} 个，候选包必需阻断资产 ${blockedAssets.length} 项，明确排除内部资产 ${excludedInternalAssets.length} 项，在用组件 ${inUseComponents.length} 项`);

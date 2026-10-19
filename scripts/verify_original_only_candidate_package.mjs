import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const packageRoot = path.resolve(process.env.FULL_CANDIDATE_PACKAGE_ROOT?.trim() || path.join(workspaceRoot, "build", "internal-full-candidate-original-only"));

function collectFiles(rootPath) {
  const files = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true}).sort((left, right) => left.name.localeCompare(right.name))) {
      if (entry.isDirectory() && entry.name === ".godot") continue;
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(absolutePath);
      else if (entry.isFile() && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) files.push(absolutePath);
    }
  };
  visit(rootPath);
  return files;
}

if (!fs.existsSync(packageRoot)) throw new Error(`原创边界候选包不存在：${packageRoot}`);
const manifest = JSON.parse(fs.readFileSync(path.join(packageRoot, "candidate-package-manifest.json"), "utf8"));
if (manifest.character_variant !== "original_only") throw new Error("候选包不是 original_only 变体");

const forbiddenPathFragments = [
  "quaternius",
  "makehuman",
  "polyhaven",
  "metal_office_desk",
  "worn_asphalt",
  "/cc0/",
];
const forbidden = collectFiles(packageRoot)
  .map((filePath) => path.relative(packageRoot, filePath).split(path.sep).join("/"))
  .filter((relativePath) => forbiddenPathFragments.some((fragment) => relativePath.toLowerCase().includes(fragment)));
if (forbidden.length > 0) throw new Error(`原创边界候选包仍包含外部资产路径：${forbidden.slice(0, 12).join(", ")}`);

const catalog = JSON.parse(fs.readFileSync(path.join(packageRoot, "tests/asset-runtime-catalog-full-candidates.json"), "utf8"));
const activeExternal = (catalog.slots ?? []).filter((slot) => /makehuman|quaternius|polyhaven|cc0/i.test(String(slot.scene_path ?? "")));
if (activeExternal.length > 0) throw new Error(`原创边界候选目录仍挂载外部路径：${activeExternal.map((slot) => `${slot.id}=${slot.scene_path}`).join(", ")}`);
const vehicleSlot = (catalog.slots ?? []).find((slot) => slot.id === "three-wheel-vehicle");
if (vehicleSlot?.scene_path !== "res://art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.tscn") {
  throw new Error("原创边界候选没有挂载工程内原创程序化三轮车最终候选");
}

const allowedRoots = [
  "assets/characters/original-procedural-office-characters/",
  "assets/characters/original-procedural-city-crowd/",
  "assets/environment/generated/",
  "art-source/characters/original-procedural-city-crowd/",
  "art-source/candidate-playtest/original-only/",
  "art-source/environment/original-office-desk/",
  "art-source/props/original-interaction-kit/",
  "art-source/vehicles/three-wheel-delivery/",
];
const packageFiles = collectFiles(packageRoot).map((filePath) => path.relative(packageRoot, filePath).split(path.sep).join("/"));
const suspiciousSourceFiles = packageFiles.filter((relativePath) => relativePath.startsWith("art-source/") && !allowedRoots.some((prefix) => relativePath.startsWith(prefix)));
if (suspiciousSourceFiles.length > 0) throw new Error(`原创边界候选包包含未纳入白名单的 art-source 文件：${suspiciousSourceFiles.slice(0, 12).join(", ")}`);

console.log(`原创边界候选包验证通过：${path.relative(workspaceRoot, packageRoot)}；外部资产路径 0 个；活动目录外部挂载 0 个；art-source 白名单通过`);

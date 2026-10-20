import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync} from "node:child_process";

const workspaceRoot = path.resolve(".");
const sourceManifestPath = path.join(workspaceRoot, "docs/release-manifest.json");
const outputDirectory = path.join(workspaceRoot, "build");

const packageFiles = [
  "docs/product-baseline-decision.json",
  "docs/p0-asset-production-spec.md",
  "docs/3d-asset-pipeline-conventions.md",
  "docs/asset-candidate-registry.json",
  "docs/asset-rights-register.md",
  "docs/final-asset-production-backlog.md",
  "docs/candidate-art-review-2026-10-10.md",
  "reference-evidence/candidate-runtime/candidate-art-review-2026-10-10.json",
  "docs/windows-device-qa-runbook.md",
  "gta-reference-runtime/content/asset-runtime-catalog.json",
  "gta-reference-runtime/content/rights-manifest.json",
  "gta-reference-runtime/assets/environment/generated/office_elevator_hall_v1_generated.png",
  "gta-reference-runtime/assets/environment/generated/office_elevator_hall_v1_generated.json",
  "gta-reference-runtime/assets/environment/generated/office_workstation_row_v2_worker_generated.png",
  "gta-reference-runtime/assets/environment/generated/office_workstation_row_v2_worker_generated.json",
  "art-source/environment/polyhaven-metal-office-desk/README.md",
  "art-source/environment/polyhaven-metal-office-desk/asset-record.json",
  "art-source/environment/polyhaven-metal-office-desk/asset-runtime-catalog-office-full-kit-override.json",
  "art-source/environment/polyhaven-metal-office-desk/office_desk_composition.gd",
  "art-source/environment/polyhaven-metal-office-desk/office_desk_composition.tscn",
  "art-source/environment/polyhaven-metal-office-desk/office_desk_candidate.gd",
  "art-source/environment/polyhaven-metal-office-desk/office_desk_candidate.tscn",
  "art-source/environment/polyhaven-metal-office-desk/capture_combined_office_candidate_visual.mjs",
  "art-source/environment/polyhaven-metal-office-desk/office-capture-profiles.json",
  "art-source/environment/polyhaven-metal-office-desk/office_carpet_ai_candidate_v1.json",
  "art-source/environment/polyhaven-metal-office-desk/office_carpet_ai_candidate_v1.png",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/asset-record.json",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/office-01-video-playable-backdrop-v1.png",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/office-02-asset-record.json",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/office-02-video-playable-backdrop-v1.png",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/office-10-asset-record.json",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/office-10-video-playable-backdrop-v1.png",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/office-06-asset-record.json",
  "art-source/environment/polyhaven-metal-office-desk/reference-video-candidate/office-06-video-playable-backdrop-v1.png",
  "art-source/environment/polyhaven-metal-office-desk/metal_office_desk_1k.glb",
  "art-source/environment/polyhaven-metal-office-desk/run_combined_office_candidate_runtime.mjs",
  "art-source/props/original-interaction-kit/asset-record.json",
  "art-source/props/original-interaction-kit/build_interaction_props_glb.mjs",
  "art-source/props/original-interaction-kit/interaction_props_atlas_v1.png",
  "art-source/props/original-interaction-kit/interaction_props_kit.glb",
  "art-source/characters/makehuman-office-player/README.md",
  "art-source/characters/makehuman-office-player/makehuman_player_visual_candidate.gd",
  "art-source/characters/makehuman-office-player/makehuman_player_visual_candidate.tscn",
  "art-source/characters/makehuman-office-worker/MPFB-LICENSE.ASSETS.md",
  "art-source/characters/makehuman-office-worker/MPFB-LICENSE.CODE.md",
  "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
  "art-source/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd",
  "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb",
  "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.gd",
  "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.tscn",
  "scripts/run_combined_office_candidate_playtest.sh",
  "reference-evidence/candidate-runtime/combined-office-candidates-runtime.json",
  "reference-evidence/candidate-runtime/combined-office-candidates-formal-runtime.json",
  "reference-evidence/candidate-runtime/combined-office-candidates-formal-runtime-close.json",
  "reference-evidence/p0-candidate-office-01.png",
  "reference-evidence/candidate-runtime/office-workstation-row-current-capture.json",
  "reference-evidence/p0-candidate-office-06.png",
];

function sha256Bytes(bytes) {
  return crypto.createHash("sha256").update(bytes).digest("hex");
}

function sha256File(filePath) {
  return sha256Bytes(fs.readFileSync(filePath));
}

function readCurrentSource() {
  if (!fs.existsSync(sourceManifestPath)) throw new Error("缺少 docs/release-manifest.json");
  const manifest = JSON.parse(fs.readFileSync(sourceManifestPath, "utf8"));
  const source = manifest.source;
  if (!source || !/^[0-9a-f]{64}$/.test(source.sha256) || !Number.isInteger(source.file_count)) {
    throw new Error("发布清单缺少有效正式运行时源指纹");
  }
  return source;
}

function assertSafeOutput(outputPath) {
  const normalized = path.resolve(outputPath);
  if (normalized === workspaceRoot || normalized === outputDirectory) {
    throw new Error("P0 审阅包输出路径过于宽泛");
  }
  if (path.extname(normalized).toLowerCase() !== ".zip") {
    throw new Error("P0 审阅包输出路径必须是 .zip 文件");
  }
}

function setStableTimestamps(directory) {
  const stableTime = new Date("2000-01-01T00:00:00.000Z");
  const entries = fs.readdirSync(directory, {withFileTypes: true}).sort((left, right) => left.name.localeCompare(right.name));
  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) setStableTimestamps(entryPath);
    fs.utimesSync(entryPath, stableTime, stableTime);
  }
  fs.utimesSync(directory, stableTime, stableTime);
}

function copyFiles(stagingRoot) {
  const entries = [];
  for (const relativePath of [...packageFiles].sort()) {
    const sourcePath = path.join(workspaceRoot, relativePath);
    if (!fs.existsSync(sourcePath) || !fs.statSync(sourcePath).isFile()) {
      throw new Error(`审阅包必需文件不存在：${relativePath}`);
    }
    const targetPath = path.join(stagingRoot, relativePath);
    fs.mkdirSync(path.dirname(targetPath), {recursive: true});
    fs.copyFileSync(sourcePath, targetPath);
    entries.push({path: relativePath, bytes: fs.statSync(sourcePath).size, sha256: sha256File(sourcePath)});
  }
  return entries;
}

function buildReadme(source, entries) {
  return `# 《新时代觉醒者》办公室 P0 候选资产审阅包\n\n状态：内部候选审阅，不是可上架版本。\n\n正式运行时源指纹：${source.sha256} / ${source.file_count} 个文件。\n\n本包绑定了办公室首发范围的候选角色、NPC、环境、载具、运行时覆盖说明、权利记录、视觉组合依赖、当前捕获脚本和历史候选证据。候选资产仍不得进入发布构建，视觉截图如果标注为历史或过期，不能用于当前版本视觉通过。\n\n可复现验证：在工作区运行 npm run verify:p0-office-review。\n候选运行时回归：在工作区运行 npm run test:combined-office-candidates。\n视觉捕获脚本只在真实图形窗口可用时运行；若捕获失败，失败元数据必须保留，不能用旧截图替代。\n\n本包不包含参考视频原文件和原始参考抽帧目录；仅包含用户授权的 office-01、office-02、office-06 与 office-10 可玩背景编辑候选及其权利登记，不改变正式 gta-reference-runtime/content/asset-runtime-catalog.json。\n\n## 包内文件\n\n共 ${entries.length} 个文件；每个文件的字节数和 SHA-256 记录在 manifest.json。\n`;
}

function parseArgs() {
  const args = process.argv.slice(2);
  const outputIndex = args.indexOf("--output");
  const outputPath = outputIndex >= 0 ? args[outputIndex + 1] : null;
  if (outputIndex >= 0 && (!outputPath || outputPath.startsWith("--"))) throw new Error("--output 必须跟随压缩包路径");
  return {outputPath: outputPath ? path.resolve(outputPath) : null};
}

const source = readCurrentSource();
const sourceShort = source.sha256.slice(0, 8);
const options = parseArgs();
const outputPath = options.outputPath ?? path.join(outputDirectory, `p0-office-candidate-review-${sourceShort}.zip`);
assertSafeOutput(outputPath);
fs.mkdirSync(path.dirname(outputPath), {recursive: true});

execFileSync(process.execPath, [path.join(workspaceRoot, "scripts/verify_asset_candidate_registry.mjs")], {stdio: "inherit"});
execFileSync(process.execPath, [path.join(workspaceRoot, "scripts/verify_asset_delivery_gate.mjs")], {stdio: "inherit"});

const stagingRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-p0-office-review-"));
try {
  const entries = copyFiles(stagingRoot);
  const manifest = {
    schema_version: 1,
    status: "internal_candidate_review_only",
    product_name: "新时代觉醒者",
    scope: "office_vertical_slice",
    source: {sha256: source.sha256, file_count: source.file_count},
    candidate_policy: "候选资产仅用于隔离预览和运行时回放，release_allowed=false；视觉截图必须在当前源指纹和目标设备下重新采集后才能人工签收",
    entries,
    remaining_gates: ["当前源版本真实图形截图", "P0 角色/NPC/环境/载具人工视觉签收", "最终资产权利签收", "Windows 10/11 目标设备 QA", "Steam 商店门禁"],
  };
  fs.writeFileSync(path.join(stagingRoot, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  fs.writeFileSync(path.join(stagingRoot, "README.md"), buildReadme(source, entries), "utf8");
  setStableTimestamps(stagingRoot);
  fs.rmSync(outputPath, {force: true});
  execFileSync("zip", ["-Xqr", outputPath, "."], {cwd: stagingRoot, stdio: "inherit"});
} finally {
  fs.rmSync(stagingRoot, {recursive: true, force: true});
}

const packageInfo = {path: path.relative(workspaceRoot, outputPath).split(path.sep).join("/"), bytes: fs.statSync(outputPath).size, sha256: sha256File(outputPath)};
const metadataPath = `${outputPath.slice(0, -4)}.json`;
fs.writeFileSync(metadataPath, `${JSON.stringify({schema_version: 1, ...packageInfo, status: "internal_candidate_review_only", source, scope: "office_vertical_slice"}, null, 2)}\n`, "utf8");
console.log(`办公室 P0 候选审阅包已生成：${packageInfo.path}；${packageInfo.bytes} bytes；SHA-256 ${packageInfo.sha256}`);
console.log(`审阅包清单已生成：${path.relative(workspaceRoot, metadataPath)}`);

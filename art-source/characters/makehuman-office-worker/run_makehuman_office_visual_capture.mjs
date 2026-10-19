import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const candidateId = process.env.MAKEHUMAN_CANDIDATE_ID || "office-npc-makehuman-sanitized-candidate";
const sourceAsset = path.resolve(process.env.MAKEHUMAN_SOURCE_ASSET || path.join(candidateRoot, "makehuman_office_worker_candidate_sanitized.glb"));
const retouchScript = path.join(candidateRoot, "makehuman_office_npc_retouch.gd");
const captureScript = path.join(candidateRoot, "makehuman_office_visual_capture.gd");
const godotBinary = process.env.GODOT_BIN || "godot";
const captureSubdir = process.env.MAKEHUMAN_CAPTURE_SUBDIR || "makehuman-office-npc-visual";
if (path.isAbsolute(captureSubdir) || captureSubdir.split(/[\\/]+/).includes("..")) throw new Error(`候选视觉采集目录越界：${captureSubdir}`);
const outputDir = path.join(workspaceRoot, "reference-evidence/candidate-runtime", captureSubdir);
const evidenceRelativeDir = path.relative(path.join(workspaceRoot, "reference-evidence"), outputDir).split(path.sep).join("/");
const manifestPath = path.join(outputDir, "manifest.json");
const candidateVariant = process.env.MAKEHUMAN_VARIANT || "default_retouch";
const preserveImportedMaterials = process.env.MAKEHUMAN_KEEP_IMPORTED_MATERIALS === "1";
const referenceOfficeMaterials = process.env.MAKEHUMAN_REFERENCE_OFFICE_MATERIALS === "1";
const closeCapture = process.env.MAKEHUMAN_CLOSE_CAPTURE === "1";
const useElegantSuitCandidate = process.env.MAKEHUMAN_USE_ELEGANT_SUIT === "1";
const useElegantSuitSkinned = process.env.MAKEHUMAN_USE_ELEGANT_SUIT_SKINNED === "1";
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-makehuman-office-visual-"));

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function md5(filePath) {
  return crypto.createHash("md5").update(fs.readFileSync(filePath)).digest("hex");
}

function writeJsonAtomic(filePath, payload) {
  const temporaryPath = `${filePath}.tmp-${process.pid}`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  fs.renameSync(temporaryPath, filePath);
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function filterGodotOutput(output, allowEditorSettingsNoise = false) {
  const lines = output.split(/\r?\n/);
  return lines.filter((line, index) => {
    const previous = lines[index - 1] || "";
    const next = lines[index + 1] || "";
    const certificateNoise = line.includes("at: get_system_ca_certificates") || ((previous.includes("get_system_ca_certificates") || next.includes("get_system_ca_certificates")) && line.includes('ERROR: Condition "ret != noErr" is true.'));
    const editorSettingsNoise = allowEditorSettingsNoise && (/ERROR: Cannot save file .*editor_settings-4\.7\.tres/.test(line) || line.includes("ERROR: Error saving editor settings to"));
    return !certificateNoise && !editorSettingsNoise;
  }).join("\n");
}

function assertGodotOutputHealthy(label, output, allowEditorSettingsNoise = false) {
  const filtered = filterGodotOutput(output, allowEditorSettingsNoise);
  if (/\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
    const errorLines = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-12);
    throw new Error(`${label}输出包含错误：${errorLines.join(" | ")}`);
  }
}

function assertAuxiliaryAssetBinding(entry) {
  if (!useElegantSuitCandidate || useElegantSuitSkinned) return null;
  const auxiliaryPath = path.join(candidateRoot, "male_elegantsuit01_unskinned.glb");
  if (!entry.auxiliary_runtime_sha256) throw new Error(`静态西装候选缺少 auxiliary_runtime_sha256：${entry.id}`);
  const auxiliaryHash = sha256(auxiliaryPath);
  if (auxiliaryHash !== entry.auxiliary_runtime_sha256) throw new Error(`静态西装辅助资产哈希与候选登记不一致：${auxiliaryHash}`);
  return auxiliaryHash;
}

function prewarmEditor(runtimeRoot) {
  const logPath = path.join(runtimeRoot, "makehuman-office-visual-editor-prewarm.log");
  fs.rmSync(logPath, {force: true});
  const result = spawnSync(godotBinary, [
    "--headless", "--path", runtimeRoot,
    "--audio-driver", "Dummy",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility",
    "--log-file", logPath,
    "--editor", "--quit",
  ], {
    cwd: workspaceRoot,
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 300000,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const output = `${result.stdout || ""}\n${result.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
  if (result.error || result.status !== 0) {
    const error = result.error || new Error(`Godot 编辑器预热退出码为 ${result.status}`);
    error.output = output;
    throw error;
  }
  assertGodotOutputHealthy("Godot 图形采集编辑器预热", output, true);
}

function runGodot(runtimeRoot, outputPath) {
  const logPath = path.join(runtimeRoot, "makehuman-office-visual-capture.log");
  fs.rmSync(logPath, {force: true});
  const result = spawnSync(godotBinary, [
    "--path", runtimeRoot,
    "--audio-driver", "Dummy",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility",
    "--log-file", logPath,
    "-s", "res://makehuman_office_visual_capture.gd",
  ], {
    cwd: workspaceRoot,
    env: {
      ...process.env,
      REFERENCE_ASSET_CATALOG_PATH: "res://tests/asset-runtime-catalog-makehuman-office-npc-override.json",
      MAKEHUMAN_CAPTURE_DIR: outputDir,
    },
    stdio: ["ignore", "pipe", "pipe"],
    // 蒙皮西装候选约 28MB，Godot 首次导入并建立骨骼材质缓存时可能超过三分钟。
    // 这里的超时只保护采集进程，不改变候选的视觉验收标准。
    timeout: 600000,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const output = `${result.stdout || ""}\n${result.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
  if (result.error || result.status !== 0) {
    const error = result.error || new Error(`Godot 图形采集进程退出码为 ${result.status}`);
    error.output = output;
    throw error;
  }
  assertGodotOutputHealthy("图形候选采集", output);
}

try {
  const registry = JSON.parse(fs.readFileSync(path.join(workspaceRoot, "docs/asset-candidate-registry.json"), "utf8"));
  const registryEntry = registry.candidates.find((candidate) => candidate.id === candidateId);
  if (!registryEntry) throw new Error(`候选登记中缺少 ${candidateId}`);
  const sourceHash = sha256(sourceAsset);
  if (sourceHash !== registryEntry.runtime_sha256) throw new Error(`候选视觉采集哈希与登记不一致：${sourceHash}`);
  const auxiliaryHash = assertAuxiliaryAssetBinding(registryEntry);
  fs.rmSync(outputDir, {recursive: true, force: true});
  fs.mkdirSync(outputDir, {recursive: true});
  fs.cpSync(formalRuntimeRoot, tempRoot, {recursive: true, filter: copyFilter});
  fs.mkdirSync(path.join(tempRoot, "assets/characters/makehuman-office-worker"), {recursive: true});
  const runtimeAssetPath = path.join(tempRoot, "assets/characters/makehuman-office-worker/candidate_sanitized.glb");
  fs.copyFileSync(sourceAsset, runtimeAssetPath);
  const importHash = md5(runtimeAssetPath);
  const importedScenePath = `res://.godot/imported/candidate_sanitized.glb-${importHash}.scn`;
  fs.writeFileSync(`${runtimeAssetPath}.import`, `[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\npath="${importedScenePath}"\n\n[deps]\n\nsource_file="res://assets/characters/makehuman-office-worker/candidate_sanitized.glb"\ndest_files=["${importedScenePath}"]\n\n[params]\n\nmeshes/ensure_tangents=false\nmeshes/generate_lods=false\nmeshes/create_shadow_meshes=true\nnodes/apply_root_scale=true\nskins/use_named_skins=true\nanimation/import=true\nanimation/fps=30\nanimation/trimming=false\nanimation/remove_immutable_tracks=true\ngltf/naming_version=2\ngltf/embedded_image_handling=1\ngltf/texture_map_mode=1\n`, "utf8");
  fs.copyFileSync(retouchScript, path.join(tempRoot, "makehuman_office_npc_retouch.gd"));
  fs.copyFileSync(captureScript, path.join(tempRoot, "makehuman_office_visual_capture.gd"));
  if (useElegantSuitCandidate) {
    fs.copyFileSync(path.join(candidateRoot, "male_elegantsuit01_unskinned.glb"), path.join(tempRoot, "assets/characters/makehuman-office-worker/male_elegantsuit01_unskinned.glb"));
  }
  const catalog = JSON.parse(fs.readFileSync(path.join(formalRuntimeRoot, "content/asset-runtime-catalog.json"), "utf8"));
  const officeNpcSlot = catalog.slots.find((slot) => slot.id === "office-npc-set");
  officeNpcSlot.scene_path = "res://assets/characters/makehuman-office-worker/candidate_sanitized.glb";
  officeNpcSlot.fallback_policy = "forbid";
  fs.writeFileSync(path.join(tempRoot, "tests/asset-runtime-catalog-makehuman-office-npc-override.json"), `${JSON.stringify(catalog, null, 2)}\n`, "utf8");
  prewarmEditor(tempRoot);
  runGodot(tempRoot, outputDir);

  const states = ["idle_default", "search_default", "alert_default"];
  const captures = states.map((state) => {
    const relativePath = `${evidenceRelativeDir}/makehuman-office-npc-${state}.png`;
    const absolutePath = path.join(outputDir, `makehuman-office-npc-${state}.png`);
    if (!fs.existsSync(absolutePath)) throw new Error(`缺少候选视觉截图：${relativePath}`);
    const imageHeader = fs.readFileSync(absolutePath).subarray(0, 24);
    if (imageHeader.readUInt32BE(16) !== 1280 || imageHeader.readUInt32BE(20) !== 720) throw new Error(`候选视觉截图尺寸不符合 1280x720：${relativePath}`);
    return {id: `makehuman-office-npc-${state}`, state, path: relativePath, sha256: sha256(absolutePath), width: 1280, height: 720, visual_status: "unverified"};
  });
  writeJsonAtomic(manifestPath, {schema_version: 1, status: "candidate_graphical_visual_capture_unverified", candidate_id: candidateId, candidate_variant: candidateVariant, candidate_sha256: sourceHash, auxiliary_asset_sha256: auxiliaryHash, retouch_script_sha256: sha256(retouchScript), capture_options: {preserve_imported_materials: preserveImportedMaterials, reference_office_materials: referenceOfficeMaterials, close_capture: closeCapture, use_elegant_suit_candidate: useElegantSuitCandidate, use_elegant_suit_skinned: useElegantSuitSkinned}, environment: "temporary copy of gta-reference-runtime", visual_status: "unverified", release_allowed: false, captures, captured_at: new Date().toISOString()});
  console.log(`MakeHuman 候选图形视觉证据已写入：${manifestPath}`);
} catch (error) {
  fs.rmSync(outputDir, {recursive: true, force: true});
  fs.mkdirSync(outputDir, {recursive: true});
  writeJsonAtomic(manifestPath, {schema_version: 1, status: "candidate_graphical_visual_capture_failed", candidate_id: candidateId, candidate_variant: candidateVariant, candidate_sha256: sha256(sourceAsset), retouch_script_sha256: sha256(retouchScript), capture_options: {preserve_imported_materials: preserveImportedMaterials, reference_office_materials: referenceOfficeMaterials, close_capture: closeCapture, use_elegant_suit_candidate: useElegantSuitCandidate, use_elegant_suit_skinned: useElegantSuitSkinned}, environment: "temporary copy of gta-reference-runtime", visual_status: "unverified", release_allowed: false, failure: String(error?.message || error), captured_at: new Date().toISOString()});
  throw error;
} finally {
  fs.rmSync(tempRoot, {recursive: true, force: true});
}

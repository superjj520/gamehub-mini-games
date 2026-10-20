import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {execFileSync, spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";
import {NodeIO} from "@gltf-transform/core";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const candidateId = process.env.MAKEHUMAN_CANDIDATE_ID || "office-npc-makehuman-sanitized-candidate";
const sourceAsset = path.resolve(process.env.MAKEHUMAN_SOURCE_ASSET || path.join(candidateRoot, "makehuman_office_worker_candidate_sanitized.glb"));
const retouchScript = path.join(candidateRoot, "makehuman_office_npc_retouch.gd");
const integrationScript = path.join(candidateRoot, "makehuman_office_runtime_integration_test.gd");
const runnerSource = path.join(candidateRoot, "run_isolated_office_npc_runtime.mjs");
const godotBinary = process.env.GODOT_BIN || "godot";
const evidencePath = path.join(workspaceRoot, "reference-evidence/candidate-runtime", process.env.MAKEHUMAN_EVIDENCE_FILE || "makehuman-office-npc-runtime-integration.json");
const evidenceTempPath = `${evidencePath}.tmp-${process.pid}`;
const candidateVariant = process.env.MAKEHUMAN_VARIANT || "default_retouch";
const preserveImportedMaterials = process.env.MAKEHUMAN_KEEP_IMPORTED_MATERIALS === "1";
const referenceOfficeMaterials = process.env.MAKEHUMAN_REFERENCE_OFFICE_MATERIALS === "1";
const useElegantSuitCandidate = process.env.MAKEHUMAN_USE_ELEGANT_SUIT === "1";
const useElegantSuitSkinned = process.env.MAKEHUMAN_USE_ELEGANT_SUIT_SKINNED === "1";

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

async function triangleCount(filePath) {
  const document = await new NodeIO().read(filePath);
  return document.getRoot().listMeshes().reduce((total, mesh) => total + mesh.listPrimitives().reduce((meshTotal, primitive) => {
    const indices = primitive.getIndices()?.getCount();
    const positions = primitive.getAttribute("POSITION")?.getCount() || 0;
    return meshTotal + (indices ?? positions) / 3;
  }, 0), 0);
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function runGodot(runtimeRoot, args, env = {}, capture = false, timeout = 120000) {
  const logPath = path.join(runtimeRoot, "makehuman-office-npc-integration.log");
  fs.rmSync(logPath, {force: true});
  const result = spawnSync(godotBinary, [
    "--headless",
    "--path",
    runtimeRoot,
    "--audio-driver",
    "Dummy",
    "--rendering-driver",
    "opengl3",
    "--rendering-method",
    "gl_compatibility",
    "--log-file",
    logPath,
    ...args,
  ], {
    cwd: workspaceRoot,
    env: {...process.env, ...env},
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    timeout,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const processOutput = `${result.stdout || ""}\n${result.stderr || ""}`;
  const logOutput = fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : "";
  const output = `${processOutput}\n${logOutput}`;
  if (result.error) {
    result.error.output = output;
    throw result.error;
  }
  if (result.status !== 0) {
    const error = new Error(`Godot 测试进程退出码为 ${result.status}`);
    error.output = output;
    throw error;
  }
  return capture ? output : "";
}

function assertGodotOutputHealthy(label, output) {
  const lines = output.split(/\r?\n/);
  const warmup = label.includes("Godot 资产导入");
  const filtered = lines.filter((line, index) => {
    const previous = lines[index - 1] || "";
    const next = lines[index + 1] || "";
    const certificateNoise = line.includes("at: get_system_ca_certificates") || ((previous.includes("get_system_ca_certificates") || next.includes("get_system_ca_certificates")) && line.includes('ERROR: Condition "ret != noErr" is true.'));
    const editorSettingsNoise = warmup && (/ERROR: Cannot save file .*editor_settings-4\.7\.tres/.test(line) || line.includes("ERROR: Error saving editor settings to"));
    return !certificateNoise && !editorSettingsNoise;
  }).join("\n");
  if (/\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
    const errorLines = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-12);
    throw new Error(`${label}输出包含错误、脚本错误或断言失败：${errorLines.join(" | ")}`);
  }
}

function candidateRegistryEntry() {
  const registry = JSON.parse(fs.readFileSync(path.join(workspaceRoot, "docs/asset-candidate-registry.json"), "utf8"));
  const entry = registry.candidates.find((candidate) => candidate.id === candidateId);
  if (!entry) throw new Error(`候选登记中缺少 ${candidateId}`);
  return entry;
}

function assertAuxiliaryAssetBinding(entry) {
  if (!useElegantSuitCandidate || useElegantSuitSkinned) return null;
  const auxiliaryPath = path.join(candidateRoot, "male_elegantsuit01_unskinned.glb");
  if (!entry.auxiliary_runtime_sha256) throw new Error(`静态西装候选缺少 auxiliary_runtime_sha256：${entry.id}`);
  const auxiliaryHash = sha256(auxiliaryPath);
  if (auxiliaryHash !== entry.auxiliary_runtime_sha256) throw new Error(`静态西装辅助资产哈希与候选登记不一致：${auxiliaryHash}`);
  return auxiliaryHash;
}

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-makehuman-office-npc-"));
try {
  fs.cpSync(formalRuntimeRoot, tempRoot, {recursive: true, filter: copyFilter});
  fs.mkdirSync(path.join(tempRoot, "assets/characters/makehuman-office-worker"), {recursive: true});
  const runtimeAssetPath = path.join(tempRoot, "assets/characters/makehuman-office-worker/candidate_sanitized.glb");
  fs.copyFileSync(sourceAsset, runtimeAssetPath);
  const runtimeAssetImportPath = `${runtimeAssetPath}.import`;
  const importHash = crypto.createHash("md5").update(fs.readFileSync(runtimeAssetPath)).digest("hex");
  const importedScenePath = `res://.godot/imported/candidate_sanitized.glb-${importHash}.scn`;
  fs.writeFileSync(runtimeAssetImportPath, `[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\npath="${importedScenePath}"\n\n[deps]\n\nsource_file="res://assets/characters/makehuman-office-worker/candidate_sanitized.glb"\ndest_files=["${importedScenePath}"]\n\n[params]\n\nmeshes/ensure_tangents=false\nmeshes/generate_lods=false\nmeshes/create_shadow_meshes=true\nnodes/apply_root_scale=true\nskins/use_named_skins=true\nanimation/import=true\nanimation/fps=30\nanimation/trimming=false\nanimation/remove_immutable_tracks=true\ngltf/naming_version=2\ngltf/embedded_image_handling=1\ngltf/texture_map_mode=1\n`, "utf8");
  fs.copyFileSync(retouchScript, path.join(tempRoot, "makehuman_office_npc_retouch.gd"));
  fs.copyFileSync(integrationScript, path.join(tempRoot, "tests/makehuman_office_runtime_integration_test.gd"));
  if (useElegantSuitCandidate) {
    fs.copyFileSync(path.join(candidateRoot, "male_elegantsuit01_unskinned.glb"), path.join(tempRoot, "assets/characters/makehuman-office-worker/male_elegantsuit01_unskinned.glb"));
  }

  const overrideCatalogPath = path.join(tempRoot, "tests/asset-runtime-catalog-makehuman-office-npc-override.json");
  const catalog = JSON.parse(fs.readFileSync(path.join(formalRuntimeRoot, "content/asset-runtime-catalog.json"), "utf8"));
  const officeNpcSlot = catalog.slots.find((slot) => slot.id === "office-npc-set");
  officeNpcSlot.scene_path = "res://assets/characters/makehuman-office-worker/candidate_sanitized.glb";
  officeNpcSlot.fallback_policy = "forbid";
  fs.writeFileSync(overrideCatalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");

  const importOutput = runGodot(tempRoot, ["--import"], {}, true, 300000);
  assertGodotOutputHealthy("Godot 资产导入预热", importOutput);
  const importReviewOutput = runGodot(tempRoot, ["--import"], {}, true, 300000);
  assertGodotOutputHealthy("Godot 资产导入复核", importReviewOutput);
  const env = {REFERENCE_ASSET_CATALOG_PATH: "res://tests/asset-runtime-catalog-makehuman-office-npc-override.json"};
  const candidateOutput = runGodot(tempRoot, ["-s", "res://tests/makehuman_office_runtime_integration_test.gd"], env, true);
  assertGodotOutputHealthy("MakeHuman 办公室候选接入测试", candidateOutput);
  if (!candidateOutput.includes("MakeHuman 候选已接入隔离办公室真实运行时")) {
    throw new Error("MakeHuman 办公室候选接入测试缺少成功哨兵");
  }
  const officeOutput = runGodot(tempRoot, ["-s", "res://tests/office_integration_test.gd"], env, true);
  assertGodotOutputHealthy("办公室完整回放", officeOutput);
  if (!officeOutput.includes("办公室潜行端到端回放测试通过")) {
    throw new Error("办公室完整回放缺少成功哨兵");
  }

  const entry = candidateRegistryEntry();
  const auxiliaryHash = assertAuxiliaryAssetBinding(entry);
  const candidateHash = sha256(sourceAsset);
  if (candidateHash !== entry.runtime_sha256) {
    throw new Error(`MakeHuman 返工候选实际哈希与候选登记不一致：${candidateHash}`);
  }
  const candidateTriangleCount = await triangleCount(sourceAsset);
  const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: workspaceRoot, encoding: "utf8"}).trim();
  const sourceMatch = sourceOutput.match(/^([0-9a-f]{64}) files=(\d+)$/);
  if (!sourceMatch) throw new Error(`当前正式运行时源码指纹格式无效：${sourceOutput}`);
  const evidence = {
    schema_version: 1,
    status: "candidate_isolated_office_runtime_verified",
    candidate_id: entry.id,
    candidate_variant: candidateVariant,
    candidate_sha256: candidateHash,
    candidate_triangle_count: candidateTriangleCount,
    retouch_script_sha256: sha256(retouchScript),
    integration_runner_sha256: sha256(runnerSource),
    integration_script_sha256: sha256(integrationScript),
    runtime_options: {preserve_imported_materials: preserveImportedMaterials, reference_office_materials: referenceOfficeMaterials, use_elegant_suit_candidate: useElegantSuitCandidate, use_elegant_suit_skinned: useElegantSuitSkinned},
    auxiliary_asset_sha256: auxiliaryHash,
    formal_runtime_source_fingerprint: sourceMatch[1],
    formal_runtime_source_file_count: Number(sourceMatch[2]),
    environment: "temporary copy of gta-reference-runtime",
    checks: [
      "Godot GLB import",
      "office NPC Visual mount with fallback forbidden",
      "Skeleton3D bone-count and meter-scale contract",
      "retouch script and four candidate pose states",
      "backpack visual mount",
      "full office stealth, perception and save replay",
    ],
    visual_status: "unverified",
    release_allowed: false,
    captured_at: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(evidencePath), {recursive: true});
  fs.writeFileSync(evidenceTempPath, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  fs.renameSync(evidenceTempPath, evidencePath);
  console.log(`MakeHuman 办公室候选隔离运行时证据已写入：${evidencePath}`);
} catch (error) {
  fs.rmSync(evidenceTempPath, {force: true});
  const failureEvidence = {
    schema_version: 1,
    status: "candidate_isolated_office_runtime_failed",
    candidate_id: candidateId,
    candidate_variant: candidateVariant,
    candidate_sha256: sha256(sourceAsset),
    retouch_script_sha256: sha256(retouchScript),
    integration_runner_sha256: sha256(runnerSource),
    integration_script_sha256: sha256(integrationScript),
    runtime_options: {preserve_imported_materials: preserveImportedMaterials, reference_office_materials: referenceOfficeMaterials, use_elegant_suit_candidate: useElegantSuitCandidate, use_elegant_suit_skinned: useElegantSuitSkinned},
    visual_status: "unverified",
    release_allowed: false,
    failure: String(error?.message || error),
    captured_at: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(evidencePath), {recursive: true});
  fs.writeFileSync(evidenceTempPath, `${JSON.stringify(failureEvidence, null, 2)}\n`, "utf8");
  fs.renameSync(evidenceTempPath, evidencePath);
  throw error;
} finally {
  fs.rmSync(evidenceTempPath, {force: true});
  fs.rmSync(tempRoot, {recursive: true, force: true});
}

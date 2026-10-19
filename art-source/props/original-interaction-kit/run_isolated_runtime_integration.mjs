import fs from "node:fs";
import crypto from "node:crypto";
import os from "node:os";
import path from "node:path";
import {execFileSync, spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const sourceAsset = path.join(candidateRoot, "interaction_props_kit.glb");
const integrationScript = path.join(candidateRoot, "interaction_props_runtime_integration_test.gd");
const godotBinary = process.env.GODOT_BIN || "godot";
const evidencePath = path.join(workspaceRoot, "reference-evidence/candidate-runtime/interaction-props-runtime-integration.json");
const assetRecordPath = path.join(candidateRoot, "asset-record.json");
const runnerSource = path.join(candidateRoot, "run_isolated_runtime_integration.mjs");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function runGodot(runtimeRoot, args, env = {}, capture = false) {
  const result = spawnSync(godotBinary, ["--headless", "--path", runtimeRoot, "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--rendering-method", "gl_compatibility", "--log-file", path.join(runtimeRoot, "interaction-props-runtime-integration.log"), ...args], {
    cwd: workspaceRoot,
    env: {...process.env, ...env},
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
    timeout: 120000,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  if (result.error) throw result.error;
  const output = `${result.stdout || ""}\n${result.stderr || ""}`;
  if (result.status !== 0) {
    const error = new Error(`Godot 测试进程退出码为 ${result.status}`);
    error.output = output;
    throw error;
  }
  return capture ? output : "";
}

function assertGodotOutputHealthy(label, output) {
  const filtered = output
    .split(/\r?\n/)
    .filter((line) => !line.includes('ERROR: Condition "ret != noErr" is true.') && !line.includes("at: get_system_ca_certificates") && !/ERROR: Cannot save file .*editor_settings-4\.7\.tres/.test(line) && !line.includes("ERROR: Error saving editor settings to"))
    .join("\n");
  if (/\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
    throw new Error(`${label}输出包含错误、脚本错误或断言失败`);
  }
}

fs.rmSync(evidencePath, {force: true});
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-interaction-props-runtime-"));
try {
  fs.cpSync(formalRuntimeRoot, tempRoot, {recursive: true, filter: copyFilter});
  const runtimeAssetDir = path.join(tempRoot, "assets/props");
  fs.mkdirSync(runtimeAssetDir, {recursive: true});
  fs.copyFileSync(sourceAsset, path.join(runtimeAssetDir, "interaction_props_kit.glb"));

  const overrideCatalogPath = path.join(tempRoot, "tests/asset-runtime-catalog-interaction-props-override.json");
  const catalog = JSON.parse(fs.readFileSync(path.join(formalRuntimeRoot, "content/asset-runtime-catalog.json"), "utf8"));
  const propsSlot = catalog.slots.find((slot) => slot.id === "interaction-props");
  propsSlot.scene_path = "res://assets/props/interaction_props_kit.glb";
  propsSlot.fallback_policy = "forbid";
  fs.writeFileSync(overrideCatalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");

  const editorOutput = runGodot(tempRoot, ["--editor", "--quit"], {}, true);
  assertGodotOutputHealthy("Godot 资产导入预热", editorOutput);
  const env = {REFERENCE_ASSET_CATALOG_PATH: "res://tests/asset-runtime-catalog-interaction-props-override.json"};
  const candidateOutput = runGodot(tempRoot, ["-s", integrationScript], env, true);
  assertGodotOutputHealthy("交互道具隔离接入测试", candidateOutput);
  if (!candidateOutput.includes("交互道具候选已接入隔离城市真实运行时")) {
    throw new Error("交互道具隔离接入测试缺少成功哨兵");
  }
  const cityOutput = runGodot(tempRoot, ["-s", "res://tests/city_integration_test.gd"], env, true);
  assertGodotOutputHealthy("城市完整任务回放", cityOutput);
  if (!cityOutput.includes("城市任务端到端回放测试通过")) {
    throw new Error("城市完整任务回放缺少成功哨兵");
  }

  const sourceOutput = execFileSync(process.execPath, ["scripts/source_fingerprint.mjs"], {cwd: workspaceRoot, encoding: "utf8"}).trim();
  const sourceMatch = sourceOutput.match(/^([0-9a-f]{64}) files=(\d+)$/);
  if (!sourceMatch) throw new Error(`当前正式运行时源码指纹格式无效：${sourceOutput}`);
  const assetRecord = JSON.parse(fs.readFileSync(assetRecordPath, "utf8"));
  const candidateHash = sha256(sourceAsset);
  if (candidateHash !== assetRecord.runtime_sha256) {
    throw new Error(`交互道具候选实际哈希与 asset-record 不一致：${candidateHash}`);
  }
  const evidence = {
    schema_version: 1,
    status: "candidate_isolated_runtime_verified",
    candidate_id: "interaction-props-original-kit-candidate",
    candidate_sha256: candidateHash,
    integration_runner_sha256: sha256(runnerSource),
    integration_script_sha256: sha256(integrationScript),
    asset_record_sha256: sha256(assetRecordPath),
    formal_runtime_source_fingerprint: sourceMatch[1],
    formal_runtime_source_file_count: Number(sourceMatch[2]),
    environment: "temporary copy of gta-reference-runtime",
    checks: [
      "Godot GLB import",
      "city Visual mount with fallback forbidden",
      "interaction prompt and egg inventory transition",
      "camera/player/mission preservation",
      "full city mission integration replay",
    ],
    visual_status: "unverified",
    release_allowed: false,
    captured_at: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(evidencePath), {recursive: true});
  fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  console.log(`交互道具候选隔离运行时证据已写入：${evidencePath}`);
} finally {
  fs.rmSync(tempRoot, {recursive: true, force: true});
}

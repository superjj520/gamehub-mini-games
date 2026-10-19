import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";

const workspaceRoot = process.cwd();
const runtimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const outputPath = path.join(workspaceRoot, "reference-evidence/expanded-runtime-matrix/behavior-evidence.json");
const outputTempPath = `${outputPath}.tmp-${process.pid}`;
const godotBinary = process.env.GODOT_BIN || "godot";
const settingsDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-expanded-behavior-settings-"));
const settingsPath = path.join(settingsDirectory, "settings.json");
const testCases = [
  {
    id: "global-launcher-and-focus",
    test: "tests/launcher_integration_test.gd",
    capabilities: ["launcher", "focus_navigation", "input_feedback"],
    expanded_entries: ["launcher-cold-boot", "launcher-focus-navigation"],
  },
  {
    id: "global-session-recovery",
    test: "tests/launcher_checkpoint_integration_test.gd",
    capabilities: ["session_recovery", "checkpoint_load", "safe_resume"],
    expanded_entries: ["global-crash-recovery-prompt", "office-checkpoint-recovery"],
  },
  {
    id: "office-task-and-search",
    test: "tests/office_integration_test.gd",
    capabilities: ["mission_success", "failure_state", "npc_search", "patrol_resume", "reward_feedback"],
    expanded_entries: ["office-success-feedback", "office-search-loop", "office-failure-overlay"],
  },
  {
    id: "office-pause-and-audio",
    test: "tests/pause_integration_test.gd",
    capabilities: ["pause_overlay", "settings", "audio_toggle", "fallback_feedback"],
    expanded_entries: ["office-pause-overlay", "global-audio-disabled-fallback"],
  },
  {
    id: "office-hud-resolution",
    test: "tests/hud_layout_integration_test.gd",
    capabilities: ["responsive_hud", "camera_safe_area", "input_feedback"],
    expanded_entries: ["office-resolution-variants"],
  },
  {
    id: "city-store-crowd-and-traffic",
    test: "tests/city_integration_test.gd",
    capabilities: ["store_transition", "crowd_variation", "traffic_routes", "collision_feedback", "vehicle_presentation"],
    expanded_entries: ["city-store-transition", "city-crowd-variants", "city-traffic-near-miss", "city-police-pursuit", "city-police-escape", "city-vehicle-damage-feedback"],
  },
  {
    id: "city-extension-weather-and-damage",
    test: "tests/city_extension_integration_test.gd",
    capabilities: ["new_district", "landmark_navigation", "lighting_profile", "weather_profile", "material_response", "vehicle_presentation", "collision_feedback"],
    expanded_entries: ["city-neighborhood-extension", "city-weather-lighting-extension", "city-vehicle-damage-feedback"],
  },
  {
    id: "city-delivery-and-conflict",
    test: "tests/city_conflict_integration_test.gd",
    capabilities: ["delivery_state", "inventory_consume", "reward_feedback", "collision_feedback"],
    expanded_entries: ["city-delivery-completion", "city-vehicle-damage-feedback"],
  },
  {
    id: "global-content-pack-and-asset-safety",
    test: "tests/content_pack_manifest_integration_test.gd",
    capabilities: ["content_pack_trace", "asset_forbid_fallback", "error_feedback", "safe_exit"],
    expanded_entries: ["global-missing-asset-blocked", "city-neighborhood-extension"],
  },
  {
    id: "global-determinism-and-session-journal",
    test: "tests/determinism_integration_test.gd",
    capabilities: ["deterministic_replay", "session_trace", "safe_resume"],
    expanded_entries: ["global-crash-recovery-prompt", "office-checkpoint-recovery"],
  },
];

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function runTest(testCase) {
  const logPath = path.join(settingsDirectory, `${testCase.id}.log`);
  const output = spawnSync(godotBinary, [
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
    "-s",
    `res://${testCase.test}`,
  ], {
    cwd: workspaceRoot,
    env: {...process.env, REFERENCE_SETTINGS_PATH: settingsPath},
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 120000,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const combined = `${output.stdout || ""}\n${output.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
  const filtered = combined.split(/\r?\n/).filter((line) => {
    if (line.includes("get_system_ca_certificates") || line.includes('ERROR: Condition "ret != noErr" is true.')) return false;
    return true;
  }).join("\n");
  const errorLines = filtered.split(/\r?\n/).filter((line) => /SCRIPT ERROR|Parse Error|Failed to load script|Invalid type|Invalid access|Assertion failed|Cannot infer the type|ObjectDB instances were leaked|Leaked instance:|Orphan StringName/i.test(line)).slice(-12);
  const passed = !output.error && output.status === 0 && errorLines.length === 0;
  return {
    id: testCase.id,
    test: testCase.test,
    test_sha256: sha256(path.join(runtimeRoot, testCase.test)),
    capabilities: testCase.capabilities,
    expanded_entries: testCase.expanded_entries,
    status: passed ? "passed" : "failed",
    exit_code: output.status,
    signal: output.signal || null,
    error: output.error ? output.error.message : null,
    diagnostics: errorLines,
  };
}

try {
  const results = [];
  for (const testCase of testCases) {
    const result = runTest(testCase);
    results.push(result);
    console.log(`扩展行为测试 ${result.status}：${result.id}`);
    if (result.status !== "passed") {
      for (const diagnostic of result.diagnostics) console.error(`- ${diagnostic}`);
      if (result.error) console.error(`- ${result.error}`);
    }
  }
  const sourceFingerprint = String(spawnSync(process.execPath, [path.join(workspaceRoot, "scripts/source_fingerprint.mjs")], {cwd: workspaceRoot, encoding: "utf8"}).stdout || "").trim().split(/\s+/)[0];
  const passed = results.filter((result) => result.status === "passed").length;
  const report = {
    schema_version: 1,
    status: passed === results.length ? "expanded_behavior_verified" : "expanded_behavior_incomplete",
    visual_status: "unverified",
    release_allowed: false,
    source_fingerprint: sourceFingerprint,
    source_file_count: Number(String(spawnSync(process.execPath, [path.join(workspaceRoot, "scripts/source_fingerprint.mjs")], {cwd: workspaceRoot, encoding: "utf8"}).stdout || "").trim().match(/files=(\d+)/)?.[1] || 0),
    generated_at: new Date().toISOString(),
    counts: {total: results.length, passed, failed: results.length - passed},
    tests: results,
    policy: "该报告只证明无头行为和能力回放；不证明截图、人工视觉、最终资产、目标设备或发布通过。",
  };
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.writeFileSync(outputTempPath, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  fs.renameSync(outputTempPath, outputPath);
  if (passed !== results.length) process.exitCode = 1;
} finally {
  fs.rmSync(outputTempPath, {force: true});
  fs.rmSync(settingsDirectory, {recursive: true, force: true});
}

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const sourcePlayer = path.join(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb");
const sourceVehicle = path.join(workspaceRoot, "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb");
const playerScript = path.join(candidateRoot, "makehuman_player_visual_candidate.gd");
const probeScript = path.join(candidateRoot, "makehuman_vehicle_seated_probe.gd");
const outputRoot = path.join(workspaceRoot, "reference-evidence/candidate-runtime/makehuman-vehicle-seated-probe");
const outputImage = path.join(outputRoot, "makehuman-vehicle-seated-probe.png");
const outputManifest = path.join(outputRoot, "manifest.json");
const godotBinary = process.env.GODOT_BIN || "godot";
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-makehuman-vehicle-seated-probe-"));
const seatPositionErrorTarget = 0.001;
const handHandlebarErrorTarget = 0.18;

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function runGodot(args, env, label, timeout = 300000) {
  const logPath = path.join(tempRoot, "makehuman-vehicle-seated-probe.log");
  const result = spawnSync(godotBinary, ["--path", tempRoot, "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--rendering-method", "gl_compatibility", "--log-file", logPath, ...args], {
    cwd: workspaceRoot,
    env: {...process.env, ...env},
    stdio: ["ignore", "pipe", "pipe"],
    timeout,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const output = `${result.stdout || ""}\n${result.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
  const filtered = output.split(/\r?\n/).filter((line) => {
    if (line.includes("get_system_ca_certificates") || line.includes('ERROR: Condition "ret != noErr" is true.')) return false;
    if (line.includes("Cannot save file") || line.includes("Error saving editor settings to")) return false;
    return true;
  }).join("\n");
  const errorLines = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-12);
  if (result.error || result.status !== 0 || errorLines.length > 0) {
    throw new Error(`${label}失败：${result.error?.message || errorLines.join(" | ") || `退出码 ${result.status}`}`);
  }
}

function validateContactContract(payload) {
  const cases = Array.isArray(payload.cases) ? payload.cases : [];
  if (cases.length === 0) throw new Error("载具驾驶探针没有返回任何测量分段");
  const failures = [];
  let maxSeatError = 0;
  let maxHandError = 0;
  for (const item of cases) {
    const metrics = item?.contact_metrics || {};
    const seatError = Number(metrics.seat_position_error);
    const handError = Number(metrics.hand_handlebar_error);
    maxSeatError = Math.max(maxSeatError, Number.isFinite(seatError) ? seatError : Number.POSITIVE_INFINITY);
    maxHandError = Math.max(maxHandError, Number.isFinite(handError) ? handError : Number.POSITIVE_INFINITY);
    const bones = Array.isArray(item.hand_bones_found) ? item.hand_bones_found : [];
    if (!bones.includes("hand_l") || !bones.includes("hand_r")) failures.push(`${item.id}: 缺少双手骨骼`);
    if (!Number.isFinite(seatError) || seatError > seatPositionErrorTarget) failures.push(`${item.id}: 座椅误差 ${seatError}`);
    if (!Number.isFinite(handError) || handError > handHandlebarErrorTarget) failures.push(`${item.id}: 车把误差 ${handError}`);
  }
  if (failures.length > 0) throw new Error(`载具驾驶接触契约失败：${failures.join("；")}`);
  return {
    status: "passed",
    cases: cases.length,
    max_seat_position_error: maxSeatError,
    max_hand_handlebar_error: maxHandError,
    thresholds: {
      seat_position_error: seatPositionErrorTarget,
      hand_handlebar_error: handHandlebarErrorTarget,
    },
  };
}

try {
  fs.rmSync(outputRoot, {recursive: true, force: true});
  fs.mkdirSync(outputRoot, {recursive: true});
  fs.cpSync(formalRuntimeRoot, tempRoot, {recursive: true, filter: copyFilter});
  fs.copyFileSync(sourcePlayer, path.join(tempRoot, "player_candidate_body.glb"));
  fs.copyFileSync(sourceVehicle, path.join(tempRoot, "three_wheel_delivery_candidate.glb"));
  fs.copyFileSync(playerScript, path.join(tempRoot, "makehuman_player_visual_candidate.gd"));
  fs.copyFileSync(probeScript, path.join(tempRoot, "makehuman_vehicle_seated_probe.gd"));
  // 资源导入不需要图形编辑器；在 macOS 图形服务不稳定时，强制无头导入，
  // 把真实图形窗口留给下面的画面采集阶段，避免把编辑器初始化误判为视觉失败。
  runGodot(["--headless", "--editor", "--import", "--quit"], {}, "载具驾驶探针资源导入");
  const readiness = JSON.parse(fs.readFileSync(path.join(workspaceRoot, "docs/readiness-report.json"), "utf8"));
  const identity = readiness.build_identity || {};
  const captureArgs = process.env.MAKEHUMAN_VEHICLE_PROBE_OFFSCREEN === "1"
    ? ["--headless", "-s", "res://makehuman_vehicle_seated_probe.gd"]
    : ["-s", "res://makehuman_vehicle_seated_probe.gd"];
  runGodot(captureArgs, {
    MAKEHUMAN_VEHICLE_PROBE_OUTPUT: outputImage,
    MAKEHUMAN_VEHICLE_PROBE_MANIFEST: outputManifest,
  }, "载具驾驶探针图形采集", 600000);
  const payload = JSON.parse(fs.readFileSync(outputManifest, "utf8"));
  payload.contact_validation = validateContactContract(payload);
  if (payload.status === "candidate_makehuman_vehicle_seated_probe_measurement_only") {
    payload.status = "candidate_makehuman_vehicle_seated_probe_validated";
  }
  payload.source = {
    player_asset_sha256: sha256(sourcePlayer),
    vehicle_asset_sha256: sha256(sourceVehicle),
    player_script_sha256: sha256(playerScript),
    probe_script_sha256: sha256(probeScript),
    runtime_source_fingerprint: identity.source_sha256,
    runtime_file_count: identity.source_file_count,
  };
  fs.writeFileSync(outputManifest, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  console.log(`MakeHuman 载具驾驶探针证据已写入：${outputRoot}`);
} finally {
  fs.rmSync(tempRoot, {recursive: true, force: true});
}

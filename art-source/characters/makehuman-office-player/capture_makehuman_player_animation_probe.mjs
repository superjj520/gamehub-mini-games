import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const sourceAsset = path.join(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb");
const playerScript = path.join(candidateRoot, "makehuman_player_visual_candidate.gd");
const probeScript = path.join(candidateRoot, "makehuman_player_animation_probe.gd");
const outputRoot = path.join(workspaceRoot, "reference-evidence/candidate-runtime/makehuman-player-animation-probe");
const outputImage = path.join(outputRoot, "makehuman-player-animation-probe.png");
const outputManifest = path.join(outputRoot, "manifest.json");
const godotBinary = process.env.GODOT_BIN || "godot";
const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-makehuman-player-animation-probe-"));

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function runGodot(args, env, label, timeout = 300000) {
  const logPath = path.join(tempRoot, "makehuman-player-animation-probe.log");
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

try {
  fs.rmSync(outputRoot, {recursive: true, force: true});
  fs.mkdirSync(outputRoot, {recursive: true});
  fs.cpSync(formalRuntimeRoot, tempRoot, {recursive: true, filter: copyFilter});
  fs.copyFileSync(sourceAsset, path.join(tempRoot, "player_candidate_body.glb"));
  fs.copyFileSync(playerScript, path.join(tempRoot, "makehuman_player_visual_candidate.gd"));
  fs.copyFileSync(probeScript, path.join(tempRoot, "makehuman_player_animation_probe.gd"));
  runGodot(["--editor", "--import", "--quit"], {}, "玩家动作探针资源导入");
  const readiness = JSON.parse(fs.readFileSync(path.join(workspaceRoot, "docs/readiness-report.json"), "utf8"));
  const identity = readiness.build_identity || {};
  runGodot(["-s", "res://makehuman_player_animation_probe.gd"], {
    PLAYER_ANIMATION_PROBE_OUTPUT: outputImage,
    PLAYER_ANIMATION_PROBE_MANIFEST: outputManifest,
  }, "玩家动作探针图形采集", 600000);
  const payload = JSON.parse(fs.readFileSync(outputManifest, "utf8"));
  payload.source = {
    asset_sha256: sha256(sourceAsset),
    player_script_sha256: sha256(playerScript),
    probe_script_sha256: sha256(probeScript),
    runtime_source_fingerprint: identity.source_sha256,
    runtime_file_count: identity.source_file_count,
  };
  fs.writeFileSync(outputManifest, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  console.log(`MakeHuman 玩家动作探针证据已写入：${outputRoot}`);
} finally {
  fs.rmSync(tempRoot, {recursive: true, force: true});
}

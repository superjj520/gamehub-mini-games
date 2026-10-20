import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const godotBinary = process.env.GODOT_BIN || "godot";
const preflightOnly = process.env.CITY_CANDIDATE_PREFLIGHT_ONLY === "1";
const visibleTimeoutMs = Number.parseInt(process.env.CITY_CANDIDATE_VISIBLE_TIMEOUT_MS || "120000", 10);
if (!Number.isInteger(visibleTimeoutMs) || visibleTimeoutMs < 10000 || visibleTimeoutMs > 600000) {
  throw new Error("CITY_CANDIDATE_VISIBLE_TIMEOUT_MS 必须是 10000 至 600000 之间的整数");
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function copyRuntimeClassCache(runtimeRoot) {
  const sourceCache = path.join(formalRuntimeRoot, ".godot/global_script_class_cache.cfg");
  const targetCache = path.join(runtimeRoot, ".godot/global_script_class_cache.cfg");
  fs.mkdirSync(path.dirname(targetCache), {recursive: true});
  if (fs.existsSync(sourceCache)) fs.copyFileSync(sourceCache, targetCache);
  const sourceImported = path.join(formalRuntimeRoot, ".godot/imported");
  const targetImported = path.join(runtimeRoot, ".godot/imported");
  if (fs.existsSync(sourceImported)) fs.cpSync(sourceImported, targetImported, {recursive: true});
}

function copyCandidateBundle(runtimeRoot) {
  const targetRoot = path.join(runtimeRoot, "art-source/city-full-kit-candidate");
  fs.cpSync(candidateRoot, targetRoot, {recursive: true});
  for (const fileName of [
    "asset-runtime-catalog-city-full-kit-override.json",
    "city_environment_storefront_candidate.tscn",
    "city_crowd_quaternius_candidate_runtime_overlay.tscn",
    "city_crowd_makehuman_runtime_overlay.tscn",
    "city_crowd_makehuman_candidate.gd",
    "capture_city_storefront_candidate.gd",
    "capture_city_storefront_movie.gd",
    "city_full_kit_runtime_integration_test.gd",
  ]) {
    const filePath = path.join(targetRoot, fileName);
    const rewritten = fs.readFileSync(filePath, "utf8").replaceAll("res://../art-source", "res://art-source");
    fs.writeFileSync(filePath, rewritten, "utf8");
  }

  const crowdSourceRoot = path.join(workspaceRoot, "art-source/characters/quaternius-superhero-male/city-crowd-candidate");
  const crowdTargetRoot = path.join(runtimeRoot, "art-source/characters/quaternius-superhero-male/city-crowd-candidate");
  fs.cpSync(crowdSourceRoot, crowdTargetRoot, {recursive: true});
  const originalCrowdSourceRoot = path.join(workspaceRoot, "art-source/characters/original-procedural-city-crowd");
  const originalCrowdTargetRoot = path.join(runtimeRoot, "art-source/characters/original-procedural-city-crowd");
  fs.cpSync(originalCrowdSourceRoot, originalCrowdTargetRoot, {recursive: true});
  const playerSourceRoot = path.join(workspaceRoot, "art-source/characters/quaternius-superhero-male");
  const playerTargetRoot = path.join(runtimeRoot, "art-source/characters/quaternius-superhero-male");
  fs.mkdirSync(playerTargetRoot, {recursive: true});
  for (const fileName of ["player_character_visual_candidate.gd", "player_character_visual_candidate.tscn"]) {
    fs.copyFileSync(path.join(playerSourceRoot, fileName), path.join(playerTargetRoot, fileName));
  }
  const interactionSourceRoot = path.join(workspaceRoot, "art-source/props/original-interaction-kit");
  const interactionTargetRoot = path.join(runtimeRoot, "art-source/props/original-interaction-kit");
  fs.mkdirSync(interactionTargetRoot, {recursive: true});
  fs.copyFileSync(path.join(interactionSourceRoot, "interaction_props_kit.glb"), path.join(interactionTargetRoot, "interaction_props_kit.glb"));
  const makeHumanSourceRoot = path.join(workspaceRoot, "art-source/characters/makehuman-office-worker");
  const makeHumanTargetRoot = path.join(runtimeRoot, "art-source/characters/makehuman-office-worker");
  fs.mkdirSync(makeHumanTargetRoot, {recursive: true});
  for (const fileName of [
    "makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
    "makehuman_office_npc_retouch.gd",
  ]) {
    fs.copyFileSync(path.join(makeHumanSourceRoot, fileName), path.join(makeHumanTargetRoot, fileName));
  }

  const vehicleSourceRoot = path.join(workspaceRoot, "art-source/vehicles/three-wheel-delivery");
  const vehicleTargetRoot = path.join(runtimeRoot, "art-source/vehicles/three-wheel-delivery");
  fs.cpSync(vehicleSourceRoot, vehicleTargetRoot, {recursive: true});
  const vehicleScenePath = path.join(vehicleTargetRoot, "three_wheel_delivery_atlas_candidate.tscn");
  fs.writeFileSync(vehicleScenePath, fs.readFileSync(vehicleScenePath, "utf8").replaceAll("res://../art-source", "res://art-source"), "utf8");
  const overlayPath = path.join(targetRoot, "city_crowd_quaternius_candidate_runtime_overlay.tscn");
  fs.writeFileSync(overlayPath, fs.readFileSync(overlayPath, "utf8").replaceAll("res://../art-source", "res://art-source"), "utf8");
  const makeHumanOverlayPath = path.join(targetRoot, "city_crowd_makehuman_runtime_overlay.tscn");
  fs.writeFileSync(makeHumanOverlayPath, fs.readFileSync(makeHumanOverlayPath, "utf8").replaceAll("res://../art-source", "res://art-source"), "utf8");
  const playerScriptPath = path.join(runtimeRoot, "assets/characters/quaternius-superhero-male/player_character_quaternius_candidate.gd");
  if (fs.existsSync(playerScriptPath)) {
    const playerScript = fs.readFileSync(playerScriptPath, "utf8");
    const patchedPlayerScript = playerScript
      .replace(
        "func _apply_pose() -> void:\n\tif _skeleton == null:\n\t\treturn",
        "func _apply_pose() -> void:\n\t_set_city_candidate_backpack_visibility(_state != \"vehicle_default\")\n\tif _skeleton == null:\n\t\treturn",
      )
      .replace(
        "func _style_imported_meshes() -> void:",
        "func _set_city_candidate_backpack_visibility(visible_state: bool) -> void:\n\tfor backpack in find_children(\"候选主角背包\", \"Node3D\", true, false):\n\t\t(backpack as Node3D).visible = visible_state\n\nfunc _style_imported_meshes() -> void:",
      );
    fs.writeFileSync(playerScriptPath, patchedPlayerScript, "utf8");
  }
}

function writePlaytestScene(runtimeRoot) {
  const scriptPath = path.join(runtimeRoot, "tests/play_city_candidate.gd");
  fs.writeFileSync(scriptPath, `extends Node3D

const CityScene := preload("res://scenes/city.tscn")

func _ready() -> void:
\tvar city := CityScene.instantiate()
\tcity.set_meta("asset_catalog_path", "res://art-source/city-full-kit-candidate/asset-runtime-catalog-city-full-kit-override.json")
\tcity.set_meta("settings_path", OS.get_temp_dir().path_join("city-candidate-playtest-settings.json"))
\tadd_child(city)
`, "utf8");
  fs.writeFileSync(path.join(runtimeRoot, "tests/play_city_candidate.tscn"), `[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/play_city_candidate.gd" id="1_play"]

[node name="CityCandidatePlaytest" type="Node3D"]
script = ExtResource("1_play")
`, "utf8");
}

function runGodot(runtimeRoot, args, label) {
  const logPath = path.join(runtimeRoot, "city-candidate-playtest-preflight.log");
  const result = spawnSync(godotBinary, [
    "--headless",
    "--path", runtimeRoot,
    "--quit-after", "120",
    "--audio-driver", "Dummy",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility",
    "--log-file", logPath,
    ...args,
  ], {
    cwd: workspaceRoot,
    env: {...process.env, P0_EMBEDDED: "1"},
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 600000,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const output = `${result.stdout || ""}\n${result.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
  const filtered = output.split(/\r?\n/).filter((line) => {
    if (line.includes("get_system_ca_certificates") || line.includes('ERROR: Condition "ret != noErr" is true.')) return false;
    if (args.includes("--editor") && (line.includes("Cannot save file") || line.includes("Error saving editor settings to"))) return false;
    return true;
  }).join("\n");
  if (result.error) throw new Error(`${label}失败：${result.error.message}\n${filtered}`);
  if (result.status !== 0 || /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
    const errors = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-16);
    throw new Error(`${label}失败：${errors.join(" | ")}`);
  }
}

function launchPlaytest(runtimeRoot) {
  const logPath = path.join(runtimeRoot, "city-candidate-playtest.log");
  const result = spawnSync(godotBinary, [
    "--display-driver", "macos",
    "--single-window",
    "--windowed",
    "--resolution", "1280x720",
    "--path", runtimeRoot,
    "--audio-driver", "Dummy",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility",
    "--log-file", logPath,
    "--scene", "res://tests/play_city_candidate.tscn",
  ], {
    cwd: workspaceRoot,
    env: {...process.env, P0_EMBEDDED: "1"},
    stdio: "inherit",
    timeout: visibleTimeoutMs,
    killSignal: "SIGTERM",
  });
  if (result.error) {
    if (result.error.code === "ETIMEDOUT") {
      throw new Error(`城市候选可见试玩在 ${visibleTimeoutMs} 毫秒内没有退出；请检查真实图形窗口或改用 CITY_CANDIDATE_PREFLIGHT_ONLY=1`);
    }
    throw new Error(`城市候选试玩启动失败：${result.error.message}`);
  }
  if (result.status !== 0) throw new Error(`城市候选试玩退出码异常：${result.status}`);
}

const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-city-candidate-playtest-"));
try {
  fs.cpSync(formalRuntimeRoot, temporaryRoot, {recursive: true, filter: copyFilter});
  copyRuntimeClassCache(temporaryRoot);
  copyCandidateBundle(temporaryRoot);
  writePlaytestScene(temporaryRoot);
  runGodot(temporaryRoot, ["--editor", "--import", "--quit"], "城市候选试玩资源导入预热");
  runGodot(temporaryRoot, ["-s", "res://art-source/city-full-kit-candidate/city_full_kit_runtime_integration_test.gd"], "城市候选试玩集成预检");
  if (preflightOnly) {
    console.log("城市候选试玩预检通过：临时运行时、候选资产目录和城市完整集成契约均可启动");
  } else {
    console.log("城市候选试玩即将启动；关闭 Godot 窗口后自动清理临时运行时副本");
    launchPlaytest(temporaryRoot);
  }
} finally {
  fs.rmSync(temporaryRoot, {recursive: true, force: true});
}

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const evidenceRoot = path.join(workspaceRoot, "reference-evidence/candidate-runtime");
const captureCollectorSource = path.join(candidateRoot, "capture_city_storefront_candidate_visual.mjs");
const captureScriptSource = path.join(candidateRoot, "capture_city_storefront_candidate.gd");
const candidateScene = path.join(candidateRoot, "city_environment_storefront_candidate.tscn");
const candidateScript = path.join(candidateRoot, "city_environment_storefront_candidate.gd");
const cityCrowdScript = path.join(candidateRoot, "city_crowd_makehuman_candidate.gd");
const cityCrowdOverlay = path.join(candidateRoot, "city_crowd_makehuman_runtime_overlay.tscn");
const playerVisualScript = path.join(workspaceRoot, "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.gd");
const playerVisualScene = path.join(workspaceRoot, "art-source/characters/quaternius-superhero-male/player_character_visual_candidate.tscn");
const makeHumanNpcRetouchScript = path.join(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd");
const makeHumanPlayerRoot = path.join(workspaceRoot, "art-source/characters/makehuman-office-player");
const eggsSignTexture = path.join(candidateRoot, "textures/storefront-sign-eggs-v1.png");
const endpointSignTexture = path.join(candidateRoot, "textures/storefront-sign-endpoint-v1.png");
const storefrontCrowdTexture = path.join(formalRuntimeRoot, "assets/environment/generated/city_storefront_crowd_v2_generated.png");
const duskCornerTexture = path.join(formalRuntimeRoot, "assets/environment/generated/city_dusk_corner_storefront_v1_generated.png");
const driveLaneTexture = path.join(formalRuntimeRoot, "assets/environment/generated/city_drive_lane_dusk_v1_generated.png");
const city02VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-02-video-playable-backdrop-v1.png");
const city03VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-03-video-playable-backdrop-v1.png");
const city04VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-04-video-playable-backdrop-v1.png");
const city05VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-05-video-playable-backdrop-v1.png");
const city06VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-06-video-playable-backdrop-v1.png");
const city07VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-07-video-playable-backdrop-v1.png");
const city08VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-08-video-playable-backdrop-v1.png");
const city09VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-09-video-playable-backdrop-v1.png");
const city10VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-10-video-playable-backdrop-v1.png");
const city11VideoPlayableTexture = path.join(candidateRoot, "reference-video-candidate/city-11-video-playable-backdrop-v1.png");
const vehicleScene = path.join(workspaceRoot, "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.tscn");
const vehicleScript = path.join(workspaceRoot, "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.gd");
const interactionPropsRoot = path.join(workspaceRoot, "art-source/props/original-interaction-kit");
const interactionPropsAsset = path.join(interactionPropsRoot, "interaction_props_kit.glb");
const catalog = path.join(candidateRoot, "asset-runtime-catalog-city-full-kit-quaternius-override.json");
const makeHumanPlayerCatalog = path.join(candidateRoot, "asset-runtime-catalog-city-full-kit-makehuman-player-override.json");
const useMakeHumanPlayer = process.env.CITY_CANDIDATE_PLAYER?.trim() === "makehuman";
const activeCatalog = useMakeHumanPlayer ? makeHumanPlayerCatalog : catalog;
const supportedCaptureIds = ["city-01", "city-02", "city-03", "city-04", "city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11"];
const requestedCaptureId = process.env.CITY_CANDIDATE_CAPTURE_FILTER?.trim() || "";
if (requestedCaptureId && !supportedCaptureIds.includes(requestedCaptureId)) {
  throw new Error(`CITY_CANDIDATE_CAPTURE_FILTER 不支持：${requestedCaptureId}`);
}
const captureIds = requestedCaptureId ? [requestedCaptureId] : supportedCaptureIds;
const godotBinary = process.env.GODOT_BIN || "godot";
const captureDisplayDriver = process.env.CAPTURE_DISPLAY_DRIVER?.trim() || "";
const captureRenderingDriver = process.env.CAPTURE_RENDERING_DRIVER?.trim() || "opengl3";
const captureRenderingMethod = process.env.CAPTURE_RENDERING_METHOD?.trim() || "gl_compatibility";
const captureHeadless = process.env.CITY_CANDIDATE_CAPTURE_HEADLESS === "1";
const configurationValidationOnly = process.env.CITY_CANDIDATE_CAPTURE_VALIDATE_ONLY === "1";
const movieVisible = process.env.CITY_CANDIDATE_MOVIE_VISIBLE === "1";
const offscreenMovieCapture = process.env.CITY_CANDIDATE_OFFSCREEN_CAPTURE === "1";
const captureTimeoutMs = Number.parseInt(process.env.CITY_CANDIDATE_CAPTURE_TIMEOUT_MS || "90000", 10);
const movieQuitAfter = Number.parseFloat(process.env.CITY_CANDIDATE_MOVIE_QUIT_AFTER || "12");
if (!Number.isInteger(captureTimeoutMs) || captureTimeoutMs < 5000 || captureTimeoutMs > 600000) {
  throw new Error("CITY_CANDIDATE_CAPTURE_TIMEOUT_MS 必须是 5000 至 600000 之间的整数");
}
if (!Number.isFinite(movieQuitAfter) || movieQuitAfter <= 0 || movieQuitAfter > 120) {
  throw new Error("CITY_CANDIDATE_MOVIE_QUIT_AFTER 必须是 0 至 120 之间的数字");
}

function readFormalRuntimeIdentity() {
  const reportPath = path.join(workspaceRoot, "docs/readiness-report.json");
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  const identity = report.build_identity || {};
  const sourceSha256 = String(identity.source_sha256 || "").trim();
  const sourceFileCount = Number(identity.source_file_count || 0);
  if (!/^[a-f0-9]{64}$/.test(sourceSha256) || !Number.isInteger(sourceFileCount) || sourceFileCount <= 0) {
    throw new Error("正式运行时准备报告缺少有效源指纹或文件数");
  }
  return {sourceSha256, sourceFileCount};
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function safeSha256(filePath) {
  try {
    return sha256(filePath);
  } catch {
    return null;
  }
}

function pngDimensions(filePath) {
  const buffer = fs.readFileSync(filePath);
  if (buffer.length < 24 || buffer.readUInt32BE(0) !== 0x89504e47) throw new Error(`不是有效 PNG：${filePath}`);
  return {width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20)};
}

function resolveMovieFrame(temporaryRoot, requestedPath) {
  if (fs.existsSync(requestedPath)) return requestedPath;
  const requestedName = path.basename(requestedPath, ".png");
  const candidates = fs.readdirSync(temporaryRoot)
    .filter((name) => name.startsWith(`${requestedName}-`) && name.endsWith(".png"))
    .sort()
    .map((name) => path.join(temporaryRoot, name));
  return candidates.at(-1) || null;
}

function writeJsonAtomic(filePath, payload) {
  const temporaryPath = `${filePath}.tmp-${process.pid}`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  fs.renameSync(temporaryPath, filePath);
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/");
}

function copyFilterFrom(root) {
  return (sourcePath) => {
    const relative = path.relative(root, sourcePath).split(path.sep).join("/");
    return relative !== ".godot" && !relative.startsWith(".godot/");
  };
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

function runGodot(runtimeRoot, args, env, label, visible = false, timeout = 300000) {
  const logPath = path.join(runtimeRoot, "city-storefront-candidate.log");
  fs.rmSync(logPath, {force: true});
  const visibleGraphicsArgs = [
    ...(captureDisplayDriver ? ["--display-driver", captureDisplayDriver] : []),
    "--rendering-driver", captureRenderingDriver,
    "--rendering-method", captureRenderingMethod,
  ];
  const commandArgs = visible
    ? ["--path", runtimeRoot, "--audio-driver", "Dummy", ...visibleGraphicsArgs, "--log-file", logPath, ...args]
    : ["--headless", "--path", runtimeRoot, "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--rendering-method", "gl_compatibility", "--log-file", logPath, ...args];
  const runInBackground = visible && (env.CITY_CANDIDATE_CAPTURE_BACKGROUND === "1" || process.env.CITY_CANDIDATE_CAPTURE_BACKGROUND === "1");
  const command = runInBackground ? "open" : godotBinary;
  const effectiveArgs = runInBackground
    ? ["-g", "-W", "-a", process.env.GODOT_APP_PATH || "/Applications/Godot.app", "--args", ...commandArgs]
    : commandArgs;
  const result = spawnSync(command, effectiveArgs, {
    cwd: workspaceRoot,
    env: {...process.env, ...env},
    stdio: ["ignore", "pipe", "pipe"],
    timeout,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const output = `${result.stdout || ""}\n${result.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
  const warmup = args.includes("--editor") || args.includes("--import");
  const filtered = output.split(/\r?\n/).filter((line) => {
    if (line.includes("get_system_ca_certificates") || line.includes('ERROR: Condition "ret != noErr" is true.')) return false;
    if (warmup && (line.includes("Cannot save file") || line.includes("Error saving editor settings to"))) return false;
    return true;
  }).join("\n");
  if (result.error) throw new Error(`${label}失败：${result.error.message}\n${filtered}`);
  const errors = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-16);
  const movieViewportNoiseOnly = label.includes("MovieWriter") && errors.length > 0 && errors.every((line) => line.includes('Parameter "t" is null'));
  if ((result.status !== 0 || errors.length > 0) && !movieViewportNoiseOnly) {
    throw new Error(`${label}失败：${errors.join(" | ")}`);
  }
  return output;
}

function copyCandidateBundle(runtimeRoot) {
  const targetRoot = path.join(runtimeRoot, "art-source/city-full-kit-candidate");
  fs.cpSync(candidateRoot, targetRoot, {recursive: true});
  for (const fileName of [
    "asset-runtime-catalog-city-full-kit-override.json",
    "asset-runtime-catalog-city-full-kit-quaternius-override.json",
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
  const makeHumanPlayerTargetRoot = path.join(runtimeRoot, "art-source/characters/makehuman-office-player");
  fs.cpSync(makeHumanPlayerRoot, makeHumanPlayerTargetRoot, {recursive: true});
  const makeHumanSourceRoot = path.join(workspaceRoot, "art-source/characters/makehuman-office-worker");
  const makeHumanTargetRoot = path.join(runtimeRoot, "art-source/characters/makehuman-office-worker");
  fs.mkdirSync(makeHumanTargetRoot, {recursive: true});
  for (const fileName of [
    "makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
    "makehuman_office_worker_elegant_suit_skinned_probe_512_simplified.glb",
    "makehuman_office_npc_retouch.gd",
  ]) {
    fs.copyFileSync(path.join(makeHumanSourceRoot, fileName), path.join(makeHumanTargetRoot, fileName));
  }
  const vehicleSourceRoot = path.join(workspaceRoot, "art-source/vehicles/three-wheel-delivery");
  const vehicleTargetRoot = path.join(runtimeRoot, "art-source/vehicles/three-wheel-delivery");
  fs.cpSync(vehicleSourceRoot, vehicleTargetRoot, {recursive: true});
  const vehicleScenePath = path.join(vehicleTargetRoot, "three_wheel_delivery_atlas_candidate.tscn");
  fs.writeFileSync(vehicleScenePath, fs.readFileSync(vehicleScenePath, "utf8").replaceAll("res://../art-source", "res://art-source"), "utf8");
  const interactionPropsTargetRoot = path.join(runtimeRoot, "art-source/props/original-interaction-kit");
  fs.mkdirSync(interactionPropsTargetRoot, {recursive: true});
  for (const fileName of ["interaction_props_kit.glb", "interaction_props_atlas_v1.png", "asset-record.json"]) {
    fs.copyFileSync(path.join(interactionPropsRoot, fileName), path.join(interactionPropsTargetRoot, fileName));
  }
  // 交互道具 GLB 的 Godot 导入场景会引用这个导出纹理名；隔离候选包必须显式带上它，不能依赖源目录的 .godot 缓存。
  fs.copyFileSync(path.join(interactionPropsRoot, "interaction_props_atlas_v1.png"), path.join(runtimeRoot, "interaction_props_kit_0.png"));
  const overlayPath = path.join(targetRoot, "city_crowd_quaternius_candidate_runtime_overlay.tscn");
  fs.writeFileSync(overlayPath, fs.readFileSync(overlayPath, "utf8").replaceAll("res://../art-source", "res://art-source"), "utf8");
  const makeHumanOverlayPath = path.join(targetRoot, "city_crowd_makehuman_runtime_overlay.tscn");
  fs.writeFileSync(makeHumanOverlayPath, fs.readFileSync(makeHumanOverlayPath, "utf8").replaceAll("res://../art-source", "res://art-source"), "utf8");
  fs.copyFileSync(path.join(targetRoot, "capture_city_storefront_candidate.gd"), path.join(runtimeRoot, "tests/capture_city_storefront_candidate.gd"));
  fs.copyFileSync(path.join(targetRoot, "capture_city_storefront_movie.gd"), path.join(runtimeRoot, "tests/capture_city_storefront_movie.gd"));
}

function parseCaptureDimensions(output) {
  const dimensions = new Map();
  for (const match of output.matchAll(/CITY_STOREFRONT_CAPTURE_META id=(city-\d+) width=(\d+) height=(\d+)/g)) {
    dimensions.set(match[1], {width: Number(match[2]), height: Number(match[3])});
  }
  for (const captureId of captureIds) {
    if (!dimensions.has(captureId)) throw new Error(`缺少 ${captureId} 的实际尺寸哨兵`);
  }
  return dimensions;
}

function parseConfigurationValidation(outputPath) {
  const validationPath = path.join(outputPath, "city-storefront-candidate-validation.json");
  if (!fs.existsSync(validationPath)) throw new Error(`缺少候选城市配置验证报告：${validationPath}`);
  const payload = JSON.parse(fs.readFileSync(validationPath, "utf8"));
  if (payload.status !== "candidate_configuration_validation_only") throw new Error("候选城市配置验证报告状态不正确");
  if (payload.visual_status !== "unverified" || payload.release_allowed !== false) throw new Error("候选城市配置验证报告错误地允许视觉发布");
  if (!Array.isArray(payload.captures) || payload.captures.length !== captureIds.length) throw new Error("候选城市配置验证报告缺少完整采集段");
  const capturesById = new Map(payload.captures.map((capture) => [capture.capture_id, capture]));
  const city08 = capturesById.get("city-08");
  if (captureIds.includes("city-08") && (!city08
    || Number(city08.traffic?.visible || 0) < 2
    || Number(city08.traffic?.candidate_visual_nodes || 0) < 2
    || Number(city08.traffic?.visible_meshes || 0) < 16
    || Number(city08.drive_foreground?.visible_meshes || 0) < 80)) {
    throw new Error(`候选城市配置验证报告的 city-08 没有形成可见前方交通层：${JSON.stringify(city08?.traffic || {})}`);
  }
  const city01 = capturesById.get("city-01");
  if (captureIds.includes("city-01") && (!city01
    || Number(city01.storefront_foreground?.visible_persons || 0) < 14
    || Number(city01.storefront_foreground?.visible_meshes || 0) < 90)) {
    throw new Error(`候选城市配置验证报告的 city-01 没有形成可见前景人群层：${JSON.stringify(city01?.storefront_foreground || {})}`);
  }
  if (captureIds.includes("city-08") && (!city08
    || city08.video_backdrop_enabled !== true
    || !String(city08.capture_background?.texture || "").endsWith("city-08-video-playable-backdrop-v1.png")
    || city08.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city08.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff")) {
    throw new Error(`候选城市配置验证报告的 city-08 没有绑定用户授权视频帧驾驶背景：${JSON.stringify({
      video_backdrop_enabled: city08?.video_backdrop_enabled,
      capture_background: city08?.capture_background,
    })}`);
  }
  const city02 = capturesById.get("city-02");
  if (captureIds.includes("city-02") && (!city02
    || Number(city02.storefront_foreground?.visible_persons || 0) < 14
    || Number(city02.storefront_foreground?.visible_meshes || 0) < 90
    || city02.video_backdrop_enabled !== true
    || !String(city02.capture_background?.texture || "").endsWith("city-02-video-playable-backdrop-v1.png")
    || city02.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city02.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff")) {
    throw new Error(`候选城市配置验证报告的 city-02 没有绑定用户授权视频帧人群背景：${JSON.stringify({
      storefront_foreground: city02?.storefront_foreground,
      video_backdrop_enabled: city02?.video_backdrop_enabled,
      capture_background: city02?.capture_background,
    })}`);
  }
  const city03 = capturesById.get("city-03");
  if (captureIds.includes("city-03") && (!city03
    || city03.video_backdrop_enabled !== true
    || !String(city03.capture_background?.texture || "").endsWith("city-03-video-playable-backdrop-v1.png")
    || city03.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city03.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
    || city03.store_interior?.inside_store_aisle !== true
    || Number(city03.store_interior?.visible_nodes || 0) < 7
    || Number(city03.store_interior?.product_count || 0) < 20
    || city03.player?.visible !== true
    || city03.vehicle?.visible !== false)) {
    throw new Error(`候选城市配置验证报告的 city-03 没有绑定超市通道视频背景或正式店内状态：${JSON.stringify({
      video_backdrop_enabled: city03?.video_backdrop_enabled,
      capture_background: city03?.capture_background,
      store_interior: city03?.store_interior,
      player: city03?.player,
      vehicle: city03?.vehicle,
    })}`);
  }
  const city04 = capturesById.get("city-04");
  if (captureIds.includes("city-04") && (!city04
    || city04.video_backdrop_enabled !== true
    || !String(city04.capture_background?.texture || "").endsWith("city-04-video-playable-backdrop-v1.png")
    || city04.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city04.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
    || city04.store_interior?.inside_store_aisle !== true
    || city04.player?.visible !== true
    || city04.vehicle?.visible !== false
    || city04.conflict?.visible !== true
    || Number(city04.conflict?.visible_meshes || 0) < 10)) {
    throw new Error(`候选城市配置验证报告的 city-04 没有绑定超市冲突视频背景或正式冲突状态：${JSON.stringify({
      video_backdrop_enabled: city04?.video_backdrop_enabled,
      capture_background: city04?.capture_background,
      store_interior: city04?.store_interior,
      conflict: city04?.conflict,
      player: city04?.player,
      vehicle: city04?.vehicle,
    })}`);
  }
  const city05 = capturesById.get("city-05");
  if (captureIds.includes("city-05") && (!city05
    || city05.video_backdrop_enabled !== true
    || !String(city05.capture_background?.texture || "").endsWith("city-05-video-playable-backdrop-v1.png")
    || city05.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city05.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
    || city05.mission?.stage !== "leave_store"
    || city05.cargo?.egg_tray !== true
    || city05.cargo?.visual_visible !== true
    || city05.player?.visible !== true
    || city05.vehicle?.visible !== false)) {
    throw new Error(`候选城市配置验证报告的 city-05 没有绑定黄昏离店视频背景或正式携带物状态：${JSON.stringify({
      video_backdrop_enabled: city05?.video_backdrop_enabled,
      capture_background: city05?.capture_background,
      mission: city05?.mission,
      cargo: city05?.cargo,
      player: city05?.player,
      vehicle: city05?.vehicle,
    })}`);
  }
  const city06 = capturesById.get("city-06");
  if (captureIds.includes("city-06") && (!city06
    || city06.video_backdrop_enabled !== true
    || !String(city06.capture_background?.texture || "").endsWith("city-06-video-playable-backdrop-v1.png")
    || city06.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city06.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
    || city06.mission?.stage !== "register"
    || city06.registration?.scan_board_visible !== true
    || city06.registration?.clerk_visible !== true
    || city06.player?.visible !== true
    || city06.vehicle?.visible !== true
    || city06.vehicle?.driver_is_player !== true)) {
    throw new Error(`候选城市配置验证报告的 city-06 没有绑定黄昏扫码登记视频背景或正式载具登记状态：${JSON.stringify({
      video_backdrop_enabled: city06?.video_backdrop_enabled,
      capture_background: city06?.capture_background,
      mission: city06?.mission,
      registration: city06?.registration,
      player: city06?.player,
      vehicle: city06?.vehicle,
    })}`);
  }
  const city07 = capturesById.get("city-07");
  if (captureIds.includes("city-07") && (!city07
    || city07.video_backdrop_enabled !== true
    || !String(city07.capture_background?.texture || "").endsWith("city-07-video-playable-backdrop-v1.png")
    || city07.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city07.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
    || city07.mission?.stage !== "new_shop"
    || city07.registered !== true
    || city07.registration?.scan_board_visible !== true
    || city07.registration?.clerk_visible !== true
    || city07.player?.visible !== true
    || city07.vehicle?.visible !== true
    || city07.vehicle?.driver_is_player !== true)) {
    throw new Error(`候选城市配置验证报告的 city-07 没有绑定黄昏登记成功视频背景或正式登记状态：${JSON.stringify({
      video_backdrop_enabled: city07?.video_backdrop_enabled,
      capture_background: city07?.capture_background,
      mission: city07?.mission,
      registered: city07?.registered,
      registration: city07?.registration,
      player: city07?.player,
      vehicle: city07?.vehicle,
    })}`);
  }
  const city09 = capturesById.get("city-09");
  if (captureIds.includes("city-09") && (!city09
    || city09.video_backdrop_enabled !== true
    || !String(city09.capture_background?.texture || "").endsWith("city-09-video-playable-backdrop-v1.png")
    || city09.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city09.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
    || city09.mission?.stage !== "new_shop"
    || city09.registered !== true
    || city09.player?.visible !== true
    || city09.vehicle?.visible !== true
    || city09.vehicle?.driver_is_player !== true)) {
    throw new Error(`候选城市配置验证报告的 city-09 没有绑定黄昏行驶视频背景或正式登记驾驶状态：${JSON.stringify({
      video_backdrop_enabled: city09?.video_backdrop_enabled,
      capture_background: city09?.capture_background,
      mission: city09?.mission,
      registered: city09?.registered,
      player: city09?.player,
      vehicle: city09?.vehicle,
    })}`);
  }
  const city10 = capturesById.get("city-10");
  if (captureIds.includes("city-10") && (!city10
    || city10.video_backdrop_enabled !== true
    || !String(city10.capture_background?.texture || "").endsWith("city-10-video-playable-backdrop-v1.png")
    || city10.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city10.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
    || city10.mission?.stage !== "new_shop"
    || city10.registered !== true
    || city10.player?.visible !== true
    || city10.vehicle?.visible !== true
    || city10.vehicle?.driver_is_player !== true)) {
    throw new Error(`候选城市配置验证报告的 city-10 没有绑定黄昏车尾跟拍视频背景或正式登记驾驶状态：${JSON.stringify({
      video_backdrop_enabled: city10?.video_backdrop_enabled,
      capture_background: city10?.capture_background,
      mission: city10?.mission,
      registered: city10?.registered,
      player: city10?.player,
      vehicle: city10?.vehicle,
    })}`);
  }
  if (captureIds.includes("city-01") && (!city01
    || city01.video_backdrop_enabled !== true
    || !String(city01.capture_background?.texture || "").endsWith("city-01-video-playable-backdrop-v2.png")
    || city01.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city01.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff")) {
    throw new Error(`候选城市配置验证报告的 city-01 没有绑定用户授权视频帧候选背景：${JSON.stringify({
      video_backdrop_enabled: city01?.video_backdrop_enabled,
      capture_background: city01?.capture_background,
    })}`);
  }
  const city11 = capturesById.get("city-11");
  if (captureIds.includes("city-11") && (!city11
    || city11.video_backdrop_enabled !== true
    || !String(city11.capture_background?.texture || "").endsWith("city-11-video-playable-backdrop-v1.png")
    || city11.capture_background?.asset_source !== "user_authorized_ai_video_frame_edit"
    || city11.capture_background?.rights_status !== "user_authorized_candidate_rights_pending_final_signoff")) {
    throw new Error(`候选城市配置验证报告的 city-11 没有绑定用户授权视频帧终点背景：${JSON.stringify({
      video_backdrop_enabled: city11?.video_backdrop_enabled,
      capture_background: city11?.capture_background,
    })}`);
  }
  if (captureIds.includes("city-11")) {
    const cameraPosition = city11?.camera?.global_position;
    const cameraFov = Number(city11?.camera?.fov || 0);
    const endpointMeshCount = Number(city11?.capture_render_layers?.visible_candidate_endpoint_meshes ?? 0);
    const nonDynamicMeshCount = Number(city11?.capture_render_layers?.visible_non_dynamic_meshes ?? -1);
    const validCameraPosition = Array.isArray(cameraPosition) && cameraPosition.length === 3
      && Math.abs(Number(cameraPosition[0]) - 8.6) < 0.05
      && Number(cameraPosition[2]) < 5.3;
    if (!city11 || city11.player?.visible !== true || city11.vehicle?.visible !== true || city11.vehicle?.driver_is_player !== true) {
      throw new Error("候选城市配置验证报告的 city-11 没有保留玩家驾驶终点构图");
    }
    if (!validCameraPosition || Math.abs(cameraFov - 52.0) > 0.1) {
      throw new Error(`候选城市配置验证报告的 city-11 相机未锁定车辆后方：position=${JSON.stringify(cameraPosition)} fov=${cameraFov}`);
    }
    if (endpointMeshCount < 13 || nonDynamicMeshCount !== 0) {
      throw new Error(`候选城市配置验证报告的 city-11 终点门面或灰盒隔离不满足：endpoint=${endpointMeshCount} non_dynamic=${nonDynamicMeshCount}`);
    }
  }
  return {validationPath, payload};
}

function metadataBase(captureId, status) {
  const imageName = `city-storefront-candidate-${captureId}.png`;
  const runtimeIdentity = readFormalRuntimeIdentity();
  return {
    schema_version: 1,
    status,
    capture_id: captureId,
    candidate_ids: [useMakeHumanPlayer ? "city-player-character-makehuman-candidate" : "city-player-character-quaternius-cc0-candidate", "city-crowd-quaternius-cc0-candidate", "city-vehicle-three-wheel-delivery-atlas-candidate", "city-environment-quaternius-downtown-cc0-candidate", "city-storefront-crowd-v2-generated-candidate", "city-dusk-corner-storefront-v1-generated-candidate", "city-drive-lane-dusk-v1-generated-candidate", "city-02-video-authored-backdrop-candidate-v1", "city-03-video-authored-backdrop-candidate-v1", "city-04-video-authored-backdrop-candidate-v1", "city-05-video-authored-backdrop-candidate-v1", "city-06-video-authored-backdrop-candidate-v1", "city-07-video-authored-backdrop-candidate-v1", "city-08-video-authored-backdrop-candidate-v1", "city-09-video-authored-backdrop-candidate-v1", "city-10-video-authored-backdrop-candidate-v1", "city-11-video-authored-backdrop-candidate-v1"],
    source_sha256: {
      runtime_source_fingerprint: runtimeIdentity.sourceSha256,
      runtime_file_count: runtimeIdentity.sourceFileCount,
      candidate_catalog: safeSha256(activeCatalog),
      storefront_scene: safeSha256(candidateScene),
      storefront_script: safeSha256(candidateScript),
      city_crowd_script: safeSha256(cityCrowdScript),
      city_crowd_overlay: safeSha256(cityCrowdOverlay),
      player_visual_script: safeSha256(playerVisualScript),
      player_visual_scene: safeSha256(playerVisualScene),
      makehuman_npc_retouch_script: safeSha256(makeHumanNpcRetouchScript),
      storefront_sign_eggs_texture: safeSha256(eggsSignTexture),
      storefront_sign_endpoint_texture: safeSha256(endpointSignTexture),
      storefront_crowd_texture: safeSha256(storefrontCrowdTexture),
      dusk_corner_storefront_texture: safeSha256(duskCornerTexture),
      drive_lane_texture: safeSha256(driveLaneTexture),
      city02_video_playable_texture: safeSha256(city02VideoPlayableTexture),
      city03_video_playable_texture: safeSha256(city03VideoPlayableTexture),
      city04_video_playable_texture: safeSha256(city04VideoPlayableTexture),
      city05_video_playable_texture: safeSha256(city05VideoPlayableTexture),
      city06_video_playable_texture: safeSha256(city06VideoPlayableTexture),
      city07_video_playable_texture: safeSha256(city07VideoPlayableTexture),
      city08_video_playable_texture: safeSha256(city08VideoPlayableTexture),
      city09_video_playable_texture: safeSha256(city09VideoPlayableTexture),
      city10_video_playable_texture: safeSha256(city10VideoPlayableTexture),
      city11_video_playable_texture: safeSha256(city11VideoPlayableTexture),
      vehicle_scene: safeSha256(vehicleScene),
      vehicle_script: safeSha256(vehicleScript),
      interaction_props_asset: safeSha256(interactionPropsAsset),
      capture_script: safeSha256(captureScriptSource),
      capture_collector_script: safeSha256(captureCollectorSource),
    },
    capture_options: {
      scene: "city",
      reference_segment: captureId,
      player_camera_profile: "candidate_preview_camera",
      dynamic_actors: captureId === "city-01" || captureId === "city-02" ? "storefront_crowd_visible" : captureId === "city-03" ? "store_interior_player_visible" : captureId === "city-04" ? "store_conflict_player_visible" : captureId === "city-05" ? "leave_store_cargo_runner_visible" : captureId === "city-06" ? "registration_vehicle_clerk_visible" : captureId === "city-07" ? "registration_success_vehicle_clerk_visible" : captureId === "city-08" ? "road_pedestrians_and_traffic_visible" : captureId === "city-09" ? "registered_driver_motion_blur_visible" : captureId === "city-10" ? "registered_driver_rear_follow_visible" : "crowd_hidden_vehicle_visible",
      player_visibility: "visible",
      vehicle_visibility: captureId === "city-08" || captureId === "city-09" || captureId === "city-10" ? "visible_driving" : captureId === "city-07" || captureId === "city-06" ? "visible_registration" : captureId === "city-11" ? "visible_at_endpoint" : "hidden",
      storefront_variant: "storefront_v3_with_crowd_dusk_corner_and_drive_lane_background_cards",
      collision_and_mission_logic: "formal_runtime_unchanged",
      runtime_isolation: "temporary_copy_of_formal_runtime",
      timeout_ms: captureTimeoutMs,
    },
    reference_comparison: {
      reference_frame: `reference-evidence/video-1/${captureId}.jpg`,
      findings: [
        "原创店铺立面、卷帘门、招牌、橱窗/货架和扫码牌通过外置候选目录进入真实城市运行时",
        "首店密集人群写实背景卡已进入城市候选环境；它只作为远景构图层，不替代可交互行人",
        "城市建筑和 HUD 保留；人群、交通、登记牌与冲突对象按分段清理，city-05 保留离店携带物奔跑状态，city-06 保留三轮车与扫码登记前景，city-07 保留注册成功反馈与登记前景，city-09 保留登记完成后的玩家驾驶和侧后方运动模糊构图，city-10 保留登记完成后的车尾跟拍与导航目标语义，city-11 保留玩家与三轮车以复现终点车尾构图",
        "角色、车体、建筑材质、光照、动作和镜头仍需人工逐帧返工，不能视为视觉通过",
      ],
    },
    visual_status: "unverified",
    release_allowed: false,
    captured_at: new Date().toISOString(),
    image_name: imageName,
  };
}

function classifyCaptureFailure(error) {
  const message = String(error?.message || error);
  if (message.includes("Connection invalid") || message.includes("scheduleApplicationNotification")) return "macos_graphics_service_failure";
  if (message.includes("ETIMEDOUT")) return "process_timeout";
  if (message.includes("signal 11") || message.includes('Parameter "t" is null')) return "godot_render_backend_failure";
  if (message.includes("无头或无根纹理") || message.includes("headless")) return "headless_render_backend_unavailable";
  return "capture_error";
}

const evidenceBackupRoot = path.join(os.tmpdir(), `新时代觉醒者-city-capture-backup-${process.pid}`);
const evidenceBackups = new Map();

function prepareEvidenceForCapture() {
  fs.mkdirSync(evidenceBackupRoot, {recursive: true});
  for (const captureId of captureIds) {
    const imagePath = path.join(evidenceRoot, `city-storefront-candidate-${captureId}.png`);
    if (fs.existsSync(imagePath)) {
      const backupPath = path.join(evidenceBackupRoot, path.basename(imagePath));
      fs.copyFileSync(imagePath, backupPath);
      evidenceBackups.set(imagePath, backupPath);
    }
  }
}

function restoreEvidenceBackups() {
  for (const captureId of captureIds) {
    const imagePath = path.join(evidenceRoot, `city-storefront-candidate-${captureId}.png`);
    const backupPath = evidenceBackups.get(imagePath);
    if (!fs.existsSync(imagePath) && backupPath && fs.existsSync(backupPath)) {
      fs.copyFileSync(backupPath, imagePath);
    }
  }
}

function discardEvidenceBackups() {
  fs.rmSync(evidenceBackupRoot, {recursive: true, force: true});
  evidenceBackups.clear();
}

let activeCaptureId = null;

function writeFailureEvidence(error) {
  const message = String(error?.stack || error).slice(0, 5000);
  for (const captureId of captureIds) {
    const metadataPath = path.join(evidenceRoot, `city-storefront-candidate-${captureId}.json`);
    const metadata = metadataBase(captureId, "candidate_isolated_formal_runtime_graphical_capture_failed");
    metadata.error = `${activeCaptureId ? `当前失败段：${activeCaptureId}\n` : "捕获流程尚未进入单段图形采集\n"}${message}`;
    metadata.failure_kind = classifyCaptureFailure(error);
    metadata.image = null;
    writeJsonAtomic(metadataPath, metadata);
  }
  restoreEvidenceBackups();
}

// Godot 在 macOS 图形保存阶段对含中文的临时路径可能出现乱码；
// 临时目录使用 ASCII，正式证据目录仍保留项目中文命名。
const requestedRuntimeRoot = process.env.CITY_CANDIDATE_CAPTURE_RUNTIME_ROOT?.trim() || "";
const reusableRuntimeRoot = requestedRuntimeRoot ? path.resolve(requestedRuntimeRoot) : formalRuntimeRoot;
// 即使调用方提供了已导入的候选运行时，也必须复制到临时目录。
// 采集器会覆盖测试脚本和候选环境脚本；直接写入 build/ 会污染包指纹。
const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "codex-city-candidate-"));
const ownsTemporaryRoot = true;
let interrupted = false;
const handleInterrupt = (signal) => {
  if (interrupted) return;
  interrupted = true;
  writeFailureEvidence(new Error(`城市候选采集被 ${signal} 中断`));
  process.exitCode = signal === "SIGINT" ? 130 : 143;
};
process.once("SIGINT", () => handleInterrupt("SIGINT"));
process.once("SIGTERM", () => handleInterrupt("SIGTERM"));
try {
  fs.mkdirSync(evidenceRoot, {recursive: true});
  prepareEvidenceForCapture();
  fs.cpSync(reusableRuntimeRoot, temporaryRoot, {recursive: true, filter: copyFilterFrom(reusableRuntimeRoot)});
  copyRuntimeClassCache(temporaryRoot);
  copyCandidateBundle(temporaryRoot);
  if (process.env.CITY_CANDIDATE_INTEGRATION_ONLY === "1") {
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入", false, 600000);
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入复核", false, 600000);
    const activeCatalogRuntimePath = `res://art-source/city-full-kit-candidate/${path.basename(activeCatalog)}`;
    const integrationOutput = runGodot(temporaryRoot, ["-s", "res://art-source/city-full-kit-candidate/city_full_kit_runtime_integration_test.gd"], {P0_EMBEDDED: "1", CITY_CANDIDATE_CATALOG: activeCatalogRuntimePath}, "城市完整候选包隔离集成测试", false, 600000);
    if (!integrationOutput.includes("城市完整候选包接入真实运行时通过")) throw new Error("城市完整候选包缺少集成测试成功哨兵");
    discardEvidenceBackups();
    console.log("城市完整候选包隔离集成测试通过");
    process.exitCode = 0;
  } else if (configurationValidationOnly) {
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入", false, 600000);
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入复核", false, 600000);
    const activeCatalogRuntimePath = `res://art-source/city-full-kit-candidate/${path.basename(activeCatalog)}`;
    const output = runGodot(temporaryRoot, ["-s", "res://tests/capture_city_storefront_candidate.gd"], {
      P0_EMBEDDED: "1",
      CITY_CANDIDATE_CAPTURE_DIR: temporaryRoot,
      CITY_CANDIDATE_CAPTURE_VALIDATE_ONLY: "1",
      CITY_CANDIDATE_CATALOG: activeCatalogRuntimePath,
    }, "候选城市无图形配置验证", false, captureTimeoutMs);
    const {validationPath, payload} = parseConfigurationValidation(temporaryRoot);
    const evidencePath = path.join(evidenceRoot, "city-storefront-candidate-validation.json");
    writeJsonAtomic(evidencePath, {
      ...payload,
      source_sha256: metadataBase("city-configuration", "candidate_configuration_validation_only").source_sha256,
      validation_output: output.match(/CITY_STOREFRONT_CONFIGURATION_VALIDATION[^\n]*/)?.[0] || null,
      captured_at: new Date().toISOString(),
    });
    fs.rmSync(validationPath, {force: true});
    discardEvidenceBackups();
    console.log(`城市店铺候选无图形配置验证已写入：${evidencePath}`);
  } else if (process.env.CITY_CANDIDATE_MOVIE_CAPTURE === "1") {
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入", false, 600000);
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入复核", false, 600000);
    const moviePreflight = runGodot(temporaryRoot, ["-s", "res://art-source/city-full-kit-candidate/city_full_kit_runtime_integration_test.gd"], {P0_EMBEDDED: "1"}, "MovieWriter 候选城市全量预热回放", false, 600000);
    if (!moviePreflight.includes("城市完整候选包接入真实运行时通过")) throw new Error("MovieWriter 预热回放缺少城市完整候选包成功哨兵");
    for (const captureId of captureIds) {
      activeCaptureId = captureId;
      const requestedMoviePath = path.join(temporaryRoot, `city-storefront-movie-${captureId}.png`);
      const movieArgs = offscreenMovieCapture
        ? ["-s", "res://tests/capture_city_storefront_movie.gd"]
        : ["--write-movie", requestedMoviePath, "--quit-after", String(movieQuitAfter), "-s", "res://tests/capture_city_storefront_movie.gd"];
      const movieEnv = {
        P0_EMBEDDED: "1",
        CITY_MOVIE_CAPTURE_ID: captureId,
        ...(offscreenMovieCapture ? {CITY_MOVIE_OFFSCREEN: "1", CITY_MOVIE_CAPTURE_OUTPUT: requestedMoviePath} : {}),
      };
      const movieOutput = runGodot(temporaryRoot, movieArgs, movieEnv, `候选城市 ${captureId} ${offscreenMovieCapture ? "离屏 SubViewport" : "MovieWriter"} 图形采集`, offscreenMovieCapture ? false : movieVisible, captureTimeoutMs);
      const sourceImage = resolveMovieFrame(temporaryRoot, requestedMoviePath);
      if (sourceImage == null) throw new Error(`缺少 ${captureId} 的${offscreenMovieCapture ? "离屏 SubViewport" : " MovieWriter"} PNG；输出：${movieOutput.slice(-1000)}`);
      const imageName = `city-storefront-candidate-${captureId}.png`;
      const outputImage = path.join(evidenceRoot, imageName);
      const temporaryImage = `${outputImage}.tmp-${process.pid}`;
      fs.copyFileSync(sourceImage, temporaryImage);
      fs.renameSync(temporaryImage, outputImage);
      const metadata = metadataBase(captureId, "candidate_isolated_formal_runtime_graphical_capture_unverified");
      metadata.image = {path: `reference-evidence/candidate-runtime/${imageName}`, sha256: sha256(outputImage), ...pngDimensions(outputImage), backend: offscreenMovieCapture ? "Godot 4.7.1 headless OpenGL compatibility SubViewport PNG" : "Godot 4.7.1 MovieWriter PNG"};
      delete metadata.image_name;
      writeJsonAtomic(path.join(evidenceRoot, `city-storefront-candidate-${captureId}.json`), metadata);
      activeCaptureId = null;
    }
    console.log(`城市店铺候选 MovieWriter 图形证据已写入：${evidenceRoot}`);
    discardEvidenceBackups();
  } else {
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入", false, 600000);
    runGodot(temporaryRoot, ["--import"], {P0_EMBEDDED: "1"}, "候选城市正式运行时资源导入复核", false, 600000);
      const activeCatalogRuntimePath = `res://art-source/city-full-kit-candidate/${path.basename(activeCatalog)}`;
      const output = runGodot(temporaryRoot, ["-s", "res://tests/capture_city_storefront_candidate.gd"], {P0_EMBEDDED: "1", CITY_CANDIDATE_CAPTURE_DIR: temporaryRoot, CITY_CANDIDATE_CATALOG: activeCatalogRuntimePath}, captureHeadless ? "候选城市正式运行时无窗口图形采集" : "候选城市正式运行时可见窗口图形采集", !captureHeadless, captureTimeoutMs);
    const dimensions = parseCaptureDimensions(output);
    for (const captureId of captureIds) {
      const imageName = `city-storefront-candidate-${captureId}.png`;
      const sourceImage = path.join(temporaryRoot, imageName);
      if (!fs.existsSync(sourceImage)) throw new Error(`缺少 ${captureId} 截图文件`);
      const outputImage = path.join(evidenceRoot, imageName);
      const temporaryImage = `${outputImage}.tmp-${process.pid}`;
      fs.copyFileSync(sourceImage, temporaryImage);
      fs.renameSync(temporaryImage, outputImage);
      const metadata = metadataBase(captureId, "candidate_isolated_formal_runtime_graphical_capture_unverified");
      metadata.image = {path: `reference-evidence/candidate-runtime/${imageName}`, sha256: sha256(outputImage), ...dimensions.get(captureId), backend: "Godot 4.7.1 OpenGL compatibility viewport capture"};
      delete metadata.image_name;
      writeJsonAtomic(path.join(evidenceRoot, `city-storefront-candidate-${captureId}.json`), metadata);
    }
    console.log(`城市店铺候选图形证据已写入隔离运行时副本：${evidenceRoot}`);
    discardEvidenceBackups();
  }
} catch (error) {
  writeFailureEvidence(error);
  console.error(String(error?.stack || error));
  process.exitCode = 1;
} finally {
  if (fs.existsSync(evidenceBackupRoot)) fs.rmSync(evidenceBackupRoot, {recursive: true, force: true});
  if (ownsTemporaryRoot) fs.rmSync(temporaryRoot, {recursive: true, force: true});
}

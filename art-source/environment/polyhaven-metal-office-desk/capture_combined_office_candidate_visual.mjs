import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../../..");
const captureProfilesPath = path.join(candidateRoot, "office-capture-profiles.json");
const captureProfiles = JSON.parse(fs.readFileSync(captureProfilesPath, "utf8"));
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const defaultCharacterSource = path.resolve(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb");
const npcSource = path.resolve(workspaceRoot, process.env.COMBINED_NPC_GLB_SOURCE?.trim() || "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb");
const npcRetouchSource = path.resolve(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd");
const playerVisualSource = path.resolve(workspaceRoot, "art-source/characters/makehuman-office-player/makehuman_player_visual_candidate.gd");
const playerGlbSource = path.resolve(workspaceRoot, process.env.COMBINED_PLAYER_GLB_SOURCE?.trim() || defaultCharacterSource);
const vehicleSource = path.resolve(workspaceRoot, "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb");
const deskSource = path.resolve(candidateRoot, "metal_office_desk_1k.glb");
const officeCompositionSource = path.resolve(candidateRoot, "office_desk_composition.gd");
const interactionPropsSource = path.resolve(workspaceRoot, "art-source/props/original-interaction-kit/interaction_props_kit.glb");
const playerSource = playerGlbSource;
const captureRunnerSource = path.join(candidateRoot, "capture_combined_office_candidate_visual.mjs");
const captureUserDataDir = path.join(os.tmpdir(), `新时代觉醒者-office-capture-${process.pid}`);
const captureRuntimeRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-office-candidate-runtime-"));
const captureDisplayDriver = process.env.CAPTURE_DISPLAY_DRIVER?.trim() || "";
const captureRenderingDriver = process.env.CAPTURE_RENDERING_DRIVER?.trim() || "opengl3";
const captureRenderingMethod = process.env.CAPTURE_RENDERING_METHOD?.trim() || "gl_compatibility";
const useDefaultVisibleUserData = process.env.COMBINED_CAPTURE_USE_DEFAULT_USER_DATA === "1";
const requestedCaptureProfile = process.env.COMBINED_CAPTURE_PROFILE?.trim();
const captureProfile = ["close", "stealth", "lobby"].includes(requestedCaptureProfile) ? requestedCaptureProfile : "wide";
const captureHeadless = process.env.COMBINED_CAPTURE_HEADLESS === "1";
const captureConfig = captureProfiles[captureProfile];
if (captureConfig == null) throw new Error(`缺少办公室采集镜头合同：${captureProfile}`);
const supportedVideoBackdropIds = ["office-01", "office-02", "office-03", "office-04", "office-05", "office-06", "office-07", "office-08", "office-09", "office-10"];
const requestedVideoBackdropId = process.env.COMBINED_CAPTURE_VIDEO_SEGMENT?.trim() || "";
if (requestedVideoBackdropId && !supportedVideoBackdropIds.includes(requestedVideoBackdropId)) {
  throw new Error(`COMBINED_CAPTURE_VIDEO_SEGMENT 不支持：${requestedVideoBackdropId}`);
}
const videoBackdropId = requestedVideoBackdropId || (captureProfile === "close" ? "office-01" : captureProfile === "stealth" ? "office-02" : captureProfile === "lobby" ? "office-06" : "");
const videoBackdropSource = path.join(candidateRoot, `reference-video-candidate/${videoBackdropId || "office-01"}-video-playable-backdrop-v1.png`);
const referenceVideoSegment = videoBackdropId || "office-01";
const segmentSuffix = requestedVideoBackdropId ? `-${requestedVideoBackdropId}` : captureConfig.filenameSuffix;
const outputStem = `combined-office-candidates-formal-runtime${segmentSuffix}`;
const outputPath = path.join(workspaceRoot, `reference-evidence/candidate-runtime/${outputStem}.png`);
const metadataPath = path.join(workspaceRoot, `reference-evidence/candidate-runtime/${outputStem}.json`);
// 无头探针只用于研发诊断，不能覆盖正式可见窗口/Windows 设备的视觉证据。
// 否则一次无头试跑就会把正式采集失败原因改写成另一种状态，甚至误删已有正式 PNG。
const captureMetadataPath = captureHeadless
  ? path.join(workspaceRoot, `reference-evidence/candidate-runtime/${outputStem}-headless-diagnostic.json`)
  : metadataPath;
const configurationValidationOnly = process.env.COMBINED_CAPTURE_VALIDATE_ONLY === "1";
const configurationValidationPath = path.join(workspaceRoot, `reference-evidence/candidate-runtime/combined-office-candidates-configuration-${requestedVideoBackdropId || captureProfile}.json`);
const metadataTempPath = `${captureMetadataPath}.tmp-${process.pid}`;
const outputBackupPath = `${outputPath}.previous-${process.pid}`;
const godotBinary = process.env.GODOT_BIN || "godot";
const disableEnvironmentCandidate = process.env.COMBINED_DISABLE_ENVIRONMENT_CANDIDATE === "1";
const disableAllCandidates = process.env.COMBINED_DISABLE_ALL_CANDIDATES === "1";
const disableNpcCandidate = process.env.COMBINED_DISABLE_NPC_CANDIDATE === "1";
const disableVehicleCandidate = process.env.COMBINED_DISABLE_VEHICLE_CANDIDATE === "1";
const captureTimeoutMs = Number.parseInt(process.env.COMBINED_CAPTURE_TIMEOUT_MS || "90000", 10);

if (!Number.isFinite(captureTimeoutMs) || captureTimeoutMs < 5000 || captureTimeoutMs > 600000) {
  throw new Error(`COMBINED_CAPTURE_TIMEOUT_MS 必须是 5000 到 600000 之间的毫秒数，当前为：${process.env.COMBINED_CAPTURE_TIMEOUT_MS || "未设置"}`);
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

function writeJsonAtomic(filePath, payload) {
  const temporaryPath = `${filePath}.tmp-${process.pid}`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  fs.renameSync(temporaryPath, filePath);
}

function runGodot(runtimeRoot, args, env, label, visible = false, timeout = 300000) {
  const logPath = path.join(runtimeRoot, "combined-office-candidates-visual.log");
  fs.rmSync(logPath, {force: true});
  const visibleGraphicsArgs = [
    ...(captureDisplayDriver ? ["--display-driver", captureDisplayDriver] : []),
    "--rendering-driver", captureRenderingDriver,
    "--rendering-method", captureRenderingMethod,
  ];
  const commandArgs = visible ? ["--path", runtimeRoot, "--audio-driver", "Dummy", ...visibleGraphicsArgs, "--log-file", logPath, ...args] : ["--headless", "--path", runtimeRoot, "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--rendering-method", "gl_compatibility", "--log-file", logPath, ...args];
  const result = spawnSync(godotBinary, commandArgs, {
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
    if ((args.includes("--editor") || args.includes("--import")) && (line.includes("Cannot save file") || line.includes("Error saving editor settings to"))) return false;
    return true;
  }).join("\n");
  if (result.error) throw new Error(`${label}失败：${result.error.message}\n${filtered}`);
  if (result.status !== 0 || /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
    const errors = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-16);
    throw new Error(`${label}失败：${errors.join(" | ")}`);
  }
  return output;
}

function runGodotWithImportRetry(runtimeRoot, args, env, label, timeout = 300000) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return runGodot(runtimeRoot, args, env, label, false, timeout);
    } catch (error) {
      lastError = error;
      if (attempt === 3) throw error;
      fs.rmSync(path.join(runtimeRoot, ".godot"), {recursive: true, force: true});
      fs.rmSync(captureUserDataDir, {recursive: true, force: true});
      fs.mkdirSync(captureUserDataDir, {recursive: true});
      console.warn(`${label}第 ${attempt} 次导入出现瞬时失败，已清理临时导入缓存并重试`);
    }
  }
  throw lastError;
}

function copyOfficeComposition(tempRoot) {
  for (const fileName of ["office_desk_composition.gd", "office_desk_composition.tscn", "office_desk_candidate.gd", "office_desk_candidate.tscn", "office_carpet_ai_candidate_v1.png", "office_carpet_ai_candidate_v1.json"]) {
    fs.copyFileSync(path.join(candidateRoot, fileName), path.join(tempRoot, fileName));
  }
  for (const fileName of [
    "metal_office_desk_1k_metal_office_desk_diff.jpg",
    "metal_office_desk_1k_metal_office_desk_metal-metal_office_desk_rough.jpg",
    "metal_office_desk_1k_metal_office_desk_nor_gl.jpg",
  ]) {
    fs.copyFileSync(path.join(candidateRoot, fileName), path.join(tempRoot, fileName));
  }
  const videoCandidateDirectory = path.join(tempRoot, "reference-video-candidate");
  fs.mkdirSync(videoCandidateDirectory, {recursive: true});
  for (const backdropId of supportedVideoBackdropIds) {
    const fileName = `${backdropId}-video-playable-backdrop-v1.png`;
    fs.copyFileSync(path.join(candidateRoot, "reference-video-candidate", fileName), path.join(videoCandidateDirectory, fileName));
  }
  fs.copyFileSync(deskSource, path.join(tempRoot, "metal_office_desk_1k.glb"));
  fs.copyFileSync(interactionPropsSource, path.join(tempRoot, "interaction_props_kit.glb"));
}

function copyCandidateAssets(tempRoot) {
  const playerDirectory = path.join(tempRoot, "assets/characters/makehuman-office-player");
  fs.mkdirSync(playerDirectory, {recursive: true});
  fs.copyFileSync(playerVisualSource, path.join(playerDirectory, "makehuman_player_visual_candidate.gd"));
  fs.copyFileSync(playerGlbSource, path.join(playerDirectory, "makehuman_player_elegant_suit_atlas_candidate.glb"));
  const playerScenePath = path.join(playerDirectory, "makehuman_player_visual_candidate.tscn");
  fs.writeFileSync(playerScenePath, `[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://assets/characters/makehuman-office-player/makehuman_player_elegant_suit_atlas_candidate.glb" id="1_character"]
[ext_resource type="Script" path="res://assets/characters/makehuman-office-player/makehuman_player_visual_candidate.gd" id="2_script"]

[node name="PlayerCharacterVisualCandidate" type="Node3D"]
script = ExtResource("2_script")

[node name="候选主角身体" parent="." instance=ExtResource("1_character")]
rotation_degrees = Vector3(0, 180, 0)
`, "utf8");
  if (!fs.existsSync(playerScenePath) || fs.statSync(playerScenePath).size < 160) {
    throw new Error(`玩家候选 PackedScene 暂存失败：${playerScenePath}`);
  }
  if (!disableNpcCandidate) {
    const npcDirectory = path.join(tempRoot, "assets/characters/makehuman-office-worker");
    fs.mkdirSync(npcDirectory, {recursive: true});
    fs.copyFileSync(npcSource, path.join(npcDirectory, "office_npc_atlas_candidate.glb"));
    const retouchSource = fs.readFileSync(npcRetouchSource, "utf8")
      .replace('get_meta("preserve_imported_materials", false)', 'get_meta("preserve_imported_materials", true)')
      .replace('get_meta("reference_office_materials", false)', 'get_meta("reference_office_materials", true)')
      .replace('get_meta("use_elegant_suit_skinned", false)', 'get_meta("use_elegant_suit_skinned", true)');
    fs.writeFileSync(path.join(npcDirectory, "makehuman_office_npc_retouch.gd"), retouchSource, "utf8");
    fs.writeFileSync(path.join(npcDirectory, "office_npc_atlas_retouch_candidate.tscn"), `[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://assets/characters/makehuman-office-worker/office_npc_atlas_candidate.glb" id="1_atlas"]
[ext_resource type="Script" path="res://assets/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd" id="2_retouch"]

[node name="OfficeNpcAtlasRetouchCandidate" type="Node3D"]
script = ExtResource("2_retouch")

[node name="Character" parent="." instance=ExtResource("1_atlas")]
`, "utf8");
  }

  if (!disableVehicleCandidate) {
    const vehicleDirectory = path.join(tempRoot, "assets/vehicles/three-wheel-delivery");
    fs.mkdirSync(vehicleDirectory, {recursive: true});
    fs.copyFileSync(vehicleSource, path.join(vehicleDirectory, "three_wheel_delivery_atlas_candidate.glb"));
    const vehicleTextureRoot = path.resolve(workspaceRoot, "art-preview/candidate-asset-preview/assets");
    for (const textureName of [
      "three_wheel_delivery_atlas_candidate_three_wheel_opaque_base_color_atlas.png",
      "three_wheel_delivery_atlas_candidate_three_wheel_opaque_metallic_roughness_atlas.png",
    ]) {
      fs.copyFileSync(path.join(vehicleTextureRoot, textureName), path.join(vehicleDirectory, textureName));
    }
    const vehicleTemplate = fs.readFileSync(path.join(formalRuntimeRoot, "assets/vehicles/three-wheel-delivery/three_wheel_delivery_candidate.tscn"), "utf8");
    fs.writeFileSync(path.join(vehicleDirectory, "three_wheel_delivery_atlas_candidate.tscn"), vehicleTemplate.replace("three_wheel_delivery.glb", "three_wheel_delivery_atlas_candidate.glb"), "utf8");
  }
  if (!disableEnvironmentCandidate) copyOfficeComposition(tempRoot);
}

function writeCatalog(tempRoot) {
  const catalogPath = path.join(tempRoot, "tests/asset-runtime-catalog-combined-office-candidates.json");
  const catalog = JSON.parse(fs.readFileSync(path.join(formalRuntimeRoot, "content/asset-runtime-catalog.json"), "utf8"));
  const slots = new Map(catalog.slots.map((slot) => [slot.id, slot]));
  if (!disableAllCandidates) {
    slots.get("player-character").scene_path = "res://assets/characters/makehuman-office-player/makehuman_player_visual_candidate.tscn";
    slots.get("player-character").fallback_policy = "forbid";
    if (!disableNpcCandidate) {
      slots.get("office-npc-set").scene_path = "res://assets/characters/makehuman-office-worker/office_npc_atlas_retouch_candidate.tscn";
      slots.get("office-npc-set").fallback_policy = "forbid";
    }
    if (!disableVehicleCandidate) {
      slots.get("three-wheel-vehicle").scene_path = "res://assets/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.tscn";
      slots.get("three-wheel-vehicle").fallback_policy = "forbid";
    }
    if (!disableEnvironmentCandidate) {
      slots.get("office-environment-kit").scene_path = "res://office_desk_composition.tscn";
      slots.get("office-environment-kit").fallback_policy = "forbid";
    }
  }
  fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");
  return "res://tests/asset-runtime-catalog-combined-office-candidates.json";
}

function writeCaptureScene(tempRoot) {
  fs.writeFileSync(path.join(tempRoot, "tests/capture_combined_office_candidates.gd"), `extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const InputFrameClass = preload("res://scripts/input_frame.gd")
const RuntimeCaptureClass = preload("res://scripts/runtime_capture.gd")

func _init() -> void:
\tcall_deferred("_run")

func _run() -> void:
\tvar validation_only := OS.get_environment("COMBINED_CAPTURE_VALIDATE_ONLY").strip_edges() == "1"
\tif not validation_only and (DisplayServer.get_name() == "headless" or get_root().get_texture() == null):
\t\tprint("候选组合正式运行时跳过：当前是无头渲染服务")
\t\tquit(0)
\t\treturn
\tprint("COMBINED_STAGE_START")
\tvar office = OfficeScene.instantiate()
\tprint("COMBINED_STAGE_INSTANTIATED")
\toffice.set_meta("asset_catalog_path", OS.get_environment("COMBINED_ASSET_CATALOG_PATH"))
\toffice.set_meta("settings_path", OS.get_temp_dir().path_join("combined-office-candidates-visual-settings.json"))
\toffice.set_meta("candidate_video_backdrop", ${videoBackdropId ? "true" : "false"})
\toffice.set_meta("candidate_video_backdrop_id", "${videoBackdropId}")
\tget_root().add_child(office)
\tprint("COMBINED_STAGE_ADDED")
\tawait process_frame
\tawait process_frame
\tassert(office.initialized, "候选组合正式运行时办公室初始化失败")
\tprint("COMBINED_STAGE_READY")
\toffice.player.position = ${captureConfig.playerPosition}
\toffice.npc.position = ${captureConfig.npcPosition}
\toffice.npc.rotation.y = PI
\tvar crouch := InputFrameClass.new()
\tcrouch.crouch = true
\toffice.process_input_frame(crouch, 0.2)
\toffice.camera_rig.set_follow_profile(${captureConfig.followDistance}, ${captureConfig.followHeight})
\toffice.camera_rig.set_shoulder_offset(${captureConfig.shoulderOffset})
\toffice.camera_rig.set_orbit(${captureConfig.orbitYaw}, ${captureConfig.orbitPitch})
\toffice.prepare_reference_capture(false)
\tif "${videoBackdropId}" != "":
\t\toffice.set_meta("reference_capture_scenario", "${videoBackdropId}")
\t\toffice.set_meta("candidate_video_backdrop_id", "${videoBackdropId}")
\t\toffice._apply_candidate_video_backdrop()
\tprint("COMBINED_STAGE_PREPARED")
\tawait process_frame
\tawait process_frame
\tif validation_only:
\t\tvar visual := office.get_node_or_null("Visual") as Node3D
\t\tvar workstation_card := visual.get_node_or_null("原创办公室连续工位写实背景卡") as MeshInstance3D if visual != null else null
\t\tvar elevator_card := visual.get_node_or_null("原创办公室电梯厅写实背景卡") as MeshInstance3D if visual != null else null
\t\tvar workstation_material := workstation_card.material_override as StandardMaterial3D if workstation_card != null else null
\t\tvar elevator_material := elevator_card.material_override as StandardMaterial3D if elevator_card != null else null
\t\tvar desk_count := visual.find_children("*", "StaticBody3D", true, false).size() if visual != null else 0
\t\tvar visual_collision_count := visual.find_children("近似碰撞体", "CollisionShape3D", true, false).size() if visual != null else 0
\t\tvar validation_payload := {
\t\t\t"schema_version": 1,
\t\t\t"status": "candidate_configuration_validation_only",
\t\t\t"visual_status": "unverified",
\t\t\t"release_allowed": false,
\t\t\t"graphics_capture_performed": false,
\t\t\t"reason": "当前运行没有可用图形根纹理；本报告只证明办公室候选场景配置，不替代逐帧视觉验收。",
\t\t\t"capture_profile": "${captureProfile}",
\t\t\t"reference_video_segment": "${referenceVideoSegment}",
\t\t\t"camera": {
\t\t\t\t"distance": float(office.camera_rig.distance),
\t\t\t\t"height": float(office.camera_rig.height),
\t\t\t\t"shoulder_x": float(office.camera_rig.shoulder_offset.x),
\t\t\t\t"current": bool(office.camera_rig.camera.current),
\t\t\t\t"orbit_yaw": ${captureConfig.orbitYaw},
\t\t\t\t"orbit_pitch": ${captureConfig.orbitPitch},
\t\t\t},
\t\t\t"actors": {
\t\t\t\t"player_present": office.player != null,
\t\t\t\t"player_visible": bool(office.player.visible) if office.player != null else false,
\t\t\t\t"npc_present": office.npc != null,
\t\t\t\t"npc_visible": bool(office.npc.visible) if office.npc != null else false,
\t\t\t\t"player_position": [office.player.global_position.x, office.player.global_position.y, office.player.global_position.z] if office.player != null else [],
\t\t\t\t"npc_position": [office.npc.global_position.x, office.npc.global_position.y, office.npc.global_position.z] if office.npc != null else [],
\t\t\t},
\t\t\t"environment": {
\t\t\t\t"visual_present": visual != null,
\t\t\t\t"visual_script": str(visual.get_script().resource_path) if visual != null and visual.get_script() != null else "",
\t\t\t\t"desk_count": desk_count,
\t\t\t\t"visual_collision_count": visual_collision_count,
\t\t\t\t"workstation_card_present": workstation_card != null,
\t\t\t\t"workstation_card_visible": bool(workstation_card.visible) if workstation_card != null else false,
\t\t\t\t"workstation_texture": str(workstation_material.albedo_texture.resource_path) if workstation_material != null and workstation_material.albedo_texture != null else "",
\t\t\t\t"elevator_card_present": elevator_card != null,
\t\t\t\t"elevator_card_visible": bool(elevator_card.visible) if elevator_card != null else false,
\t\t\t\t"elevator_texture": str(elevator_material.albedo_texture.resource_path) if elevator_material != null and elevator_material.albedo_texture != null else "",
\t\t\t\t"graybox_fallback_present": office.get_node_or_null("办公室环境灰盒回退") != null,
\t\t\t\t"video_backdrop_enabled": bool(office.get_meta("candidate_video_backdrop", false)),
\t\t\t\t"video_backdrop_texture": str(office.find_child("用户授权办公室视频帧候选背景卡", true, false).get_meta("video_backdrop_texture_path", "")) if office.find_child("用户授权办公室视频帧候选背景卡", true, false) != null else "",
\t\t\t\t"video_backdrop_asset_source": str(office.find_child("用户授权办公室视频帧候选背景卡", true, false).get_meta("asset_source", "")) if office.find_child("用户授权办公室视频帧候选背景卡", true, false) != null else "",
\t\t\t\t"video_backdrop_rights_status": str(office.find_child("用户授权办公室视频帧候选背景卡", true, false).get_meta("rights_status", "")) if office.find_child("用户授权办公室视频帧候选背景卡", true, false) != null else "",
\t\t\t},
\t\t}
\t\tvar validation_path := OS.get_environment("COMBINED_CAPTURE_CONFIGURATION_PATH").strip_edges()
\t\tif validation_path.is_empty():
\t\t\tvalidation_path = ProjectSettings.globalize_path("res://../reference-evidence/candidate-runtime/combined-office-candidates-configuration-${captureProfile}.json")
\t\tDirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../reference-evidence/candidate-runtime"))
\t\tvar validation_file := FileAccess.open(validation_path, FileAccess.WRITE)
\t\tif validation_file == null:
\t\t\tpush_error("办公室候选配置验证报告写入失败：" + validation_path)
\t\t\tquit(1)
\t\t\treturn
\t\tvalidation_file.store_string(JSON.stringify(validation_payload, "\\t") + "\\n")
\t\tvalidation_file.close()
\t\tprint("COMBINED_CONFIGURATION_VALIDATION profile=${captureProfile} path=%s" % validation_path)
\t\toffice.free()
\t\tawait process_frame
\t\tquit(0)
\t\treturn
\tvar capture_path := RuntimeCaptureClass.capture(get_root(), "${outputStem}")
\tprint("COMBINED_STAGE_CAPTURED path=%s" % capture_path)
\tassert(not capture_path.is_empty(), "正式运行时候选图形采集失败")
\tvar source_path := ProjectSettings.globalize_path(capture_path)
\tvar output_path := ProjectSettings.globalize_path("res://../reference-evidence/candidate-runtime/${outputStem}.png")
\tassert(DirAccess.copy_absolute(source_path, output_path) == OK, "正式运行时候选截图复制失败")
\tvar image := Image.load_from_file(output_path)
\tassert(image != null and not image.is_empty(), "正式运行时候选截图为空")
\tassert(_has_graphical_signal(image), "正式运行时候选截图黑屏、全透明或像素方差过低")
\tprint("COMBINED_CAPTURE_META width=%d height=%d" % [image.get_width(), image.get_height()])
\tprint("候选组合正式运行时图形证据已生成：", output_path)
\toffice.free()
\tawait process_frame
\tquit(0)

func _has_graphical_signal(image: Image) -> bool:
\tvar count := 0
\tvar brightness_sum := 0.0
\tvar brightness_square_sum := 0.0
\tvar max_brightness := 0.0
\tfor y in range(0, image.get_height(), 8):
\t\tfor x in range(0, image.get_width(), 8):
\t\t\tvar pixel: Color = image.get_pixel(x, y)
\t\t\tvar brightness: float = (pixel.r + pixel.g + pixel.b) / 3.0
\t\t\tbrightness_sum += brightness
\t\t\tbrightness_square_sum += brightness * brightness
\t\t\tmax_brightness = maxf(max_brightness, brightness)
\t\t\tcount += 1
\tif count == 0:
\t\treturn false
\tvar average := brightness_sum / count
\tvar variance := maxf(0.0, brightness_square_sum / count - average * average)
\treturn max_brightness > 0.03 and variance > 0.00035
`, "utf8");
  fs.writeFileSync(path.join(tempRoot, "tests/capture_combined_office_candidates.tscn"), `[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/capture_combined_office_candidates.gd" id="1_capture"]

[node name="CombinedOfficeCapture" type="Node3D"]
script = ExtResource("1_capture")
`, "utf8");
}

const runtimeRoot = captureRuntimeRoot;

function copyFormalRuntimeToIsolation() {
  fs.cpSync(formalRuntimeRoot, runtimeRoot, {
    recursive: true,
    filter(source) {
      const relativePath = path.relative(formalRuntimeRoot, source);
      const parts = relativePath.split(path.sep);
      if (parts.includes(".godot") || parts.includes(".import")) return false;
      if (source.endsWith(".uid")) return false;
      return true;
    },
  });
  // 配置验证不启动编辑器导入预热，但仍需要正式运行时生成的脚本类缓存，
  // 否则隔离工程首次加载时会把自定义类误判为不存在。
  const formalGodotCache = path.join(formalRuntimeRoot, ".godot");
  const isolatedGodotCache = path.join(runtimeRoot, ".godot");
  fs.mkdirSync(isolatedGodotCache, {recursive: true});
  for (const fileName of ["global_script_class_cache.cfg", "uid_cache.bin"]) {
    const sourcePath = path.join(formalGodotCache, fileName);
    if (fs.existsSync(sourcePath)) fs.copyFileSync(sourcePath, path.join(isolatedGodotCache, fileName));
  }
}

function handleTermination(signal) {
  fs.rmSync(metadataTempPath, {force: true});
  fs.rmSync(outputBackupPath, {force: true});
  fs.rmSync(captureRuntimeRoot, {recursive: true, force: true});
  process.exit(signal === "SIGINT" ? 130 : 143);
}

process.once("SIGINT", () => handleTermination("SIGINT"));
process.once("SIGTERM", () => handleTermination("SIGTERM"));

function classifyCaptureFailure(error) {
  const message = String(error?.message || error);
  if (message.includes("无头或无根纹理运行") || message.includes("无头运行") || message.includes("无根纹理")) return "headless_graphics_unavailable";
  if (message.includes("Connection invalid") || message.includes("scheduleApplicationNotification")) return "macos_graphics_service_failure";
  if (message.includes("ETIMEDOUT")) return "process_timeout";
  if (message.includes("暂存区非空")) return "staging_area_not_clean";
  return "capture_error";
}

try {
  if (!captureHeadless) {
    fs.rmSync(outputBackupPath, {force: true});
    if (fs.existsSync(outputPath)) fs.renameSync(outputPath, outputBackupPath);
  }
  copyFormalRuntimeToIsolation();
  if (!disableAllCandidates) copyCandidateAssets(runtimeRoot);
  const catalogPath = writeCatalog(runtimeRoot);
  writeCaptureScene(runtimeRoot);
  // 隔离工程必须先完成导入，才能加载 GLB、纹理和正式脚本类；配置验证与可见采集共用这一步。
  runGodotWithImportRetry(runtimeRoot, ["--import", "--quit"], {P0_EMBEDDED: "1"}, "候选组合正式运行时导入预热");
  if (configurationValidationOnly) {
    const validationOutput = runGodot(runtimeRoot, ["--script", "res://tests/capture_combined_office_candidates.gd", "--quit-after", "120"], {
      COMBINED_ASSET_CATALOG_PATH: catalogPath,
      COMBINED_CAPTURE_VALIDATE_ONLY: "1",
      COMBINED_CAPTURE_CONFIGURATION_PATH: configurationValidationPath,
      P0_EMBEDDED: "1",
    }, `办公室候选 ${captureProfile} 无图形配置验证`, false, captureTimeoutMs);
    if (!validationOutput.includes(`COMBINED_CONFIGURATION_VALIDATION profile=${captureProfile}`)) throw new Error(`缺少办公室 ${captureProfile} 配置验证成功哨兵`);
    if (!fs.existsSync(configurationValidationPath)) throw new Error(`缺少办公室 ${captureProfile} 配置验证报告`);
    const validation = JSON.parse(fs.readFileSync(configurationValidationPath, "utf8"));
    const camera = validation.camera || {};
    const actors = validation.actors || {};
    const environment = validation.environment || {};
    const expectedDistance = Number(captureConfig.followDistance);
    const expectedHeight = Number(captureConfig.followHeight);
    if (validation.status !== "candidate_configuration_validation_only" || validation.visual_status !== "unverified" || validation.release_allowed !== false) throw new Error(`办公室 ${captureProfile} 配置报告状态错误`);
    if (camera.current !== true || Math.abs(Number(camera.distance) - expectedDistance) > 0.001 || Math.abs(Number(camera.height) - expectedHeight) > 0.001) throw new Error(`办公室 ${captureProfile} 相机契约未锁定：${JSON.stringify(camera)}`);
    if (actors.player_present !== true || actors.player_visible !== true || actors.npc_present !== true || actors.npc_visible !== true) throw new Error(`办公室 ${captureProfile} 玩家/NPC 可见性契约失败：${JSON.stringify(actors)}`);
    if (environment.visual_present !== true || Number(environment.desk_count) !== 10 || Number(environment.visual_collision_count) !== 10 || environment.graybox_fallback_present !== false) throw new Error(`办公室 ${captureProfile} 环境候选契约失败：${JSON.stringify(environment)}`);
			if (videoBackdropId && (environment.video_backdrop_enabled !== true
			  || !String(environment.video_backdrop_texture || "").endsWith(`${videoBackdropId}-video-playable-backdrop-v1.png`)
      || environment.video_backdrop_asset_source !== "user_authorized_ai_video_frame_edit"
      || environment.video_backdrop_rights_status !== "user_authorized_candidate_rights_pending_final_signoff")) {
			  throw new Error(`办公室 ${captureProfile} 配置报告没有绑定用户授权视频帧候选背景：${JSON.stringify(environment)}`);
    }
			writeJsonAtomic(configurationValidationPath, {...validation, source_sha256: {player_character_glb: safeSha256(playerSource), player_visual_candidate_gd: safeSha256(playerVisualSource), office_npc_atlas_glb: safeSha256(npcSource), npc_retouch_candidate_gd: safeSha256(npcRetouchSource), office_desk_glb: safeSha256(deskSource), office_composition_gd: safeSha256(officeCompositionSource), office_video_playable_backdrop: safeSha256(videoBackdropSource), capture_runner_mjs: safeSha256(captureRunnerSource)}, captured_at: new Date().toISOString()});
    console.log(`办公室候选 ${captureProfile} 无图形配置验证已写入：${configurationValidationPath}`);
  } else {
    fs.mkdirSync(path.dirname(outputPath), {recursive: true});
    const visibleOutput = runGodot(runtimeRoot, ["--script", "res://tests/capture_combined_office_candidates.gd", "--quit-after", "120"], {
      COMBINED_ASSET_CATALOG_PATH: catalogPath,
      P0_EMBEDDED: "1",
      COMBINED_CAPTURE_OUTPUT: outputPath,
    }, captureHeadless ? "候选组合正式运行时无头视口图形截图" : "候选组合正式运行时可见窗口图形截图", !captureHeadless, captureTimeoutMs);
    const dimensions = /COMBINED_CAPTURE_META width=(\d+) height=(\d+)/.exec(visibleOutput);
    if (!dimensions || !fs.existsSync(outputPath)) {
      throw new Error(captureHeadless ? "无头或无根纹理运行不会生成正式图形证据" : "可见窗口没有生成带尺寸哨兵的截图");
    }
    const imageHash = sha256(outputPath);
    const metadata = {
      schema_version: 1,
      status: "candidate_isolated_formal_runtime_graphical_capture_unverified",
      capture_profile: captureProfile,
      image: {path: `reference-evidence/candidate-runtime/${outputStem}.png`, sha256: imageHash, width: Number(dimensions[1]), height: Number(dimensions[2]), backend: captureHeadless ? "Godot 4.7.1 OpenGL compatibility headless viewport capture" : "Godot 4.7.1 OpenGL compatibility visible viewport capture"},
      candidate_ids: ["player-character-makehuman-elegant-suit-atlas-candidate", "office-npc-makehuman-elegant-suit-skinned-512-atlas-candidate", "office-polyhaven-five-desk-full-kit-candidate", "office-workstation-row-v1-generated-candidate", "office-elevator-lobby-v1-generated-candidate", "office-01-video-authored-backdrop-candidate-v1", "office-02-video-authored-backdrop-candidate-v1", "office-06-video-authored-backdrop-candidate-v1", "office-10-video-authored-backdrop-candidate-v1", "city-vehicle-three-wheel-delivery-atlas-candidate"],
      source_sha256: {player_character_glb: sha256(playerSource), player_visual_candidate_gd: sha256(playerVisualSource), office_npc_atlas_glb: sha256(npcSource), npc_retouch_candidate_gd: sha256(npcRetouchSource), office_desk_glb: sha256(deskSource), office_carpet_texture: sha256(path.join(candidateRoot, "office_carpet_ai_candidate_v1.png")), office_workstation_texture: safeSha256(path.join(formalRuntimeRoot, "assets/environment/generated/office_workstation_row_v2_worker_generated.png")), office_elevator_lobby_texture: safeSha256(path.join(formalRuntimeRoot, "assets/environment/generated/office_elevator_lobby_v1_generated.png")), office_video_playable_backdrop: sha256(videoBackdropSource), office_composition_gd: sha256(officeCompositionSource), interaction_props_glb: sha256(interactionPropsSource), three_wheel_atlas_glb: sha256(vehicleSource), capture_runner_mjs: sha256(captureRunnerSource)},
      capture_options: {profile: captureProfile, backend: captureHeadless ? "headless" : "visible_window", timeout_ms: captureTimeoutMs, player_state: "crouch_default", player_position: captureConfig.playerPositionArray, npc_position: captureConfig.npcPositionArray, follow_distance: Number(captureConfig.followDistance), follow_height: Number(captureConfig.followHeight), shoulder_offset: captureConfig.shoulderOffsetArray, orbit_degrees: [Number(captureConfig.orbitYaw), Number(captureConfig.orbitPitch)], lighting: {policy: "单一动态阴影主光；环境光、冷色补光和顶灯为非阴影控制", ambient_energy: 0.22, key_energy: 0.24, fill_energy: 0.08, ceiling_light_energy: 0.02, emissive_energy: 0.035, adjustment: {brightness: 0.90, contrast: 1.05, saturation: 0.94}}},
      reference_comparison: {reference_frame: `reference-evidence/video-2/${referenceVideoSegment}.jpg`, target: captureConfig.targetLabel, findings: ["截图来自临时复制的正式办公室运行时，不是独立预览工程", "已验证第三人称玩家、NPC、办公室工位、玻璃隔断和 HUD 的正式可见窗口出图", "仍需人工逐项对齐人物面部、背包比例、材质、姿态、遮挡关系和曝光"]},
      visual_status: "unverified",
      release_allowed: false,
      captured_at: new Date().toISOString(),
    };
    fs.writeFileSync(metadataTempPath, `${JSON.stringify(metadata, null, 2)}\n`, "utf8");
    fs.renameSync(metadataTempPath, captureMetadataPath);
    fs.rmSync(outputBackupPath, {force: true});
    console.log(`候选组合正式运行时图形证据已写入：${outputPath}`);
  }
} catch (error) {
  fs.rmSync(metadataTempPath, {force: true});
  if (!captureHeadless) {
    fs.rmSync(outputPath, {force: true});
    if (fs.existsSync(outputBackupPath)) fs.renameSync(outputBackupPath, outputPath);
  }
  writeJsonAtomic(captureMetadataPath, {
    schema_version: 1,
    status: "candidate_isolated_formal_runtime_graphical_capture_failed",
    capture_profile: captureProfile,
    image: {path: captureHeadless ? null : `reference-evidence/candidate-runtime/${outputStem}.png`, visual_status: "unverified", release_allowed: false},
    candidate_ids: ["player-character-makehuman-elegant-suit-atlas-candidate", "office-npc-makehuman-elegant-suit-skinned-512-atlas-candidate", "office-polyhaven-five-desk-full-kit-candidate", "office-workstation-row-v1-generated-candidate", "office-elevator-lobby-v1-generated-candidate", "office-01-video-authored-backdrop-candidate-v1", "office-02-video-authored-backdrop-candidate-v1", "office-06-video-authored-backdrop-candidate-v1", "office-10-video-authored-backdrop-candidate-v1", "city-vehicle-three-wheel-delivery-atlas-candidate"],
    source_sha256: {player_character_glb: safeSha256(playerSource), player_visual_candidate_gd: safeSha256(playerVisualSource), office_npc_atlas_glb: safeSha256(npcSource), npc_retouch_candidate_gd: safeSha256(npcRetouchSource), office_desk_glb: safeSha256(deskSource), office_carpet_texture: safeSha256(path.join(candidateRoot, "office_carpet_ai_candidate_v1.png")), office_workstation_texture: safeSha256(path.join(formalRuntimeRoot, "assets/environment/generated/office_workstation_row_v2_worker_generated.png")), office_elevator_lobby_texture: safeSha256(path.join(formalRuntimeRoot, "assets/environment/generated/office_elevator_lobby_v1_generated.png")), office_video_playable_backdrop: safeSha256(videoBackdropSource), office_composition_gd: safeSha256(officeCompositionSource), interaction_props_glb: safeSha256(interactionPropsSource), three_wheel_atlas_glb: safeSha256(vehicleSource), capture_runner_mjs: safeSha256(captureRunnerSource)},
    capture_options: {profile: captureProfile, backend: captureHeadless ? "headless" : "visible_window", timeout_ms: captureTimeoutMs},
    visual_status: "unverified",
    release_allowed: false,
    diagnostic_only: captureHeadless,
    failure_kind: classifyCaptureFailure(error),
    failure: String(error?.message || error),
    captured_at: new Date().toISOString(),
  });
  throw error;
} finally {
  fs.rmSync(metadataTempPath, {force: true});
  fs.rmSync(outputBackupPath, {force: true});
  fs.rmSync(captureUserDataDir, {recursive: true, force: true});
  fs.rmSync(captureRuntimeRoot, {recursive: true, force: true});
}

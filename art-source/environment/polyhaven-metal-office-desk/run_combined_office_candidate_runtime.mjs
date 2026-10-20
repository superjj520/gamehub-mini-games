import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const npcSource = path.resolve(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb");
const npcRetouchSource = path.resolve(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd");
const playerVisualSource = path.resolve(workspaceRoot, "art-source/characters/makehuman-office-player/makehuman_player_visual_candidate.gd");
const playerGlbSource = path.resolve(workspaceRoot, "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb");
const vehicleSource = path.resolve(workspaceRoot, "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb");
const interactionPropsSource = path.resolve(workspaceRoot, "art-source/props/original-interaction-kit/interaction_props_kit.glb");
const deskSource = path.resolve(candidateRoot, "metal_office_desk_1k.glb");
const playerSource = playerGlbSource;
const runtimeRunnerSource = path.join(candidateRoot, "run_combined_office_candidate_runtime.mjs");
const evidencePath = path.join(workspaceRoot, "reference-evidence/candidate-runtime/combined-office-candidates-runtime.json");
const evidenceTempPath = `${evidencePath}.tmp-${process.pid}`;
const godotBinary = process.env.GODOT_BIN || "godot";
const playtestMode = process.env.COMBINED_OFFICE_CANDIDATE_PLAYTEST === "1";

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

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function runGodot(runtimeRoot, args, env, label, timeout = 300000) {
  const logPath = path.join(runtimeRoot, "combined-office-candidates.log");
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
  if (result.status !== 0 || result.signal || /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
    const errors = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-16);
    const diagnostic = errors.length > 0 ? errors.join(" | ") : filtered.trim().split(/\r?\n/).slice(-24).join(" | ");
    throw new Error(`${label}失败：退出码=${result.status ?? "null"}；信号=${result.signal ?? "无"}；${diagnostic || "没有可读取的 Godot 输出"}`);
  }
  return output;
}

function launchCandidatePlaytest(runtimeRoot) {
  const logPath = path.join(runtimeRoot, "combined-office-candidate-playtest.log");
  const result = spawnSync(godotBinary, [
    "--path",
    runtimeRoot,
    "--scene",
    "res://scenes/benchmark.tscn",
    "--log-file",
    logPath,
  ], {
    cwd: workspaceRoot,
    env: {
      ...process.env,
      REFERENCE_ASSET_PREVIEW: "1",
      REFERENCE_ASSET_CATALOG_PATH: "res://tests/asset-runtime-catalog-combined-office-candidates.json",
    },
    stdio: "inherit",
  });
  if (result.error) throw new Error(`办公室组合候选试玩启动失败：${result.error.message}`);
  if (result.status !== 0) throw new Error(`办公室组合候选试玩退出码异常：${result.status}`);
}

function copyOfficeComposition(tempRoot) {
  for (const fileName of [
    "office_desk_composition.gd",
    "office_desk_composition.tscn",
    "office_desk_candidate.gd",
    "office_desk_candidate.tscn",
    "office_carpet_ai_candidate_v1.png",
    "office_carpet_ai_candidate_v1.json",
  ]) {
    fs.copyFileSync(path.join(candidateRoot, fileName), path.join(tempRoot, fileName));
  }
  const videoCandidateDirectory = path.join(tempRoot, "reference-video-candidate");
  fs.mkdirSync(videoCandidateDirectory, {recursive: true});
  // 组合候选回放也必须携带完整的办公室分段背景，确保任意 office-01..10
  // 切换都在真实隔离运行目录中复现，而不是只验证四个代表镜头。
  for (const segment of [
    "office-01", "office-02", "office-03", "office-04", "office-05",
    "office-06", "office-07", "office-08", "office-09", "office-10",
  ]) {
    const filename = `${segment}-video-playable-backdrop-v1.png`;
    fs.copyFileSync(
      path.join(candidateRoot, `reference-video-candidate/${filename}`),
      path.join(videoCandidateDirectory, filename),
    );
  }
  fs.copyFileSync(deskSource, path.join(tempRoot, "metal_office_desk_1k.glb"));
  fs.copyFileSync(interactionPropsSource, path.join(tempRoot, "interaction_props_kit.glb"));
}

function buildNpcWrapper(tempRoot) {
  const directory = path.join(tempRoot, "assets/characters/makehuman-office-worker");
  fs.mkdirSync(directory, {recursive: true});
  fs.copyFileSync(npcSource, path.join(directory, "office_npc_atlas_candidate.glb"));
  const retouchSource = fs.readFileSync(npcRetouchSource, "utf8")
    .replace('get_meta("preserve_imported_materials", false)', 'get_meta("preserve_imported_materials", true)')
    .replace('get_meta("reference_office_materials", false)', 'get_meta("reference_office_materials", true)')
    .replace('get_meta("use_elegant_suit_skinned", false)', 'get_meta("use_elegant_suit_skinned", true)');
  fs.writeFileSync(path.join(directory, "makehuman_office_npc_retouch.gd"), retouchSource, "utf8");
  fs.writeFileSync(path.join(directory, "office_npc_atlas_retouch_candidate.tscn"), `[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://assets/characters/makehuman-office-worker/office_npc_atlas_candidate.glb" id="1_atlas"]
[ext_resource type="Script" path="res://assets/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd" id="2_retouch"]

[node name="OfficeNpcAtlasRetouchCandidate" type="Node3D"]
script = ExtResource("2_retouch")

[node name="Character" parent="." instance=ExtResource("1_atlas")]
`, "utf8");
}

function buildPlayerWrapper(tempRoot) {
  const directory = path.join(tempRoot, "assets/characters/makehuman-office-player");
  fs.mkdirSync(directory, {recursive: true});
  fs.copyFileSync(playerVisualSource, path.join(directory, "makehuman_player_visual_candidate.gd"));
  fs.copyFileSync(playerGlbSource, path.join(directory, "makehuman_player_elegant_suit_atlas_candidate.glb"));
  fs.writeFileSync(path.join(directory, "makehuman_player_visual_candidate.tscn"), `[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://assets/characters/makehuman-office-player/makehuman_player_elegant_suit_atlas_candidate.glb" id="1_character"]
[ext_resource type="Script" path="res://assets/characters/makehuman-office-player/makehuman_player_visual_candidate.gd" id="2_script"]

[node name="PlayerCharacterVisualCandidate" type="Node3D"]
script = ExtResource("2_script")

[node name="候选主角身体" parent="." instance=ExtResource("1_character")]
rotation_degrees = Vector3(0, 180, 0)
`, "utf8");
}

function buildCityPlayerWrapper(tempRoot) {
  const sourceDirectory = path.join(workspaceRoot, "art-source/characters/quaternius-superhero-male");
  const targetDirectory = path.join(tempRoot, "art-source/characters/quaternius-superhero-male");
  fs.mkdirSync(targetDirectory, {recursive: true});
  for (const fileName of ["player_character_visual_candidate.gd", "player_character_visual_candidate.tscn"]) {
    fs.copyFileSync(path.join(sourceDirectory, fileName), path.join(targetDirectory, fileName));
  }
}

function buildVehicleWrapper(tempRoot) {
  const directory = path.join(tempRoot, "assets/vehicles/three-wheel-delivery");
  fs.mkdirSync(directory, {recursive: true});
  fs.copyFileSync(vehicleSource, path.join(directory, "three_wheel_delivery_atlas_candidate.glb"));
  const template = fs.readFileSync(path.join(formalRuntimeRoot, "assets/vehicles/three-wheel-delivery/three_wheel_delivery_candidate.tscn"), "utf8");
  fs.writeFileSync(path.join(directory, "three_wheel_delivery_atlas_candidate.tscn"), template.replace("three_wheel_delivery.glb", "three_wheel_delivery_atlas_candidate.glb"), "utf8");
}

function writeContractTest(tempRoot) {
  fs.writeFileSync(path.join(tempRoot, "tests/combined_office_candidates_contract_test.gd"), `extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")

func _init() -> void:
\tcall_deferred("_run")

func _run() -> void:
\tvar office = OfficeScene.instantiate()
\toffice.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-combined-office-candidates.json")
\troot.add_child(office)
\tawait process_frame
\tawait process_frame
\tassert(office.initialized, "候选组合办公室没有完成初始化")
\tvar player_visual = office.player.get_node_or_null("Visual")
\tassert(player_visual != null, "候选组合玩家没有挂载 Visual")
\tassert(player_visual.get_node_or_null("AnimationPlayer") != null, "候选组合玩家缺少 AnimationPlayer")
\tvar player_backpack_marker = player_visual.get_node_or_null("候选主角背包")
\tassert(player_backpack_marker != null, "候选组合玩家缺少背包契约节点")
\tassert(str(player_backpack_marker.get_meta("attachment_bone", "")) == "spine_02", "候选组合玩家背包没有绑定 spine_02")
\tvar player_backpack = player_visual.find_child("MakeHuman 玩家背包骨骼挂点", true, false)
\tassert(player_backpack != null and player_backpack is BoneAttachment3D, "候选组合玩家缺少 MakeHuman 背包骨骼挂点")
\tassert(player_backpack.find_child("MakeHuman 玩家背包前袋", true, false) != null, "候选组合玩家缺少背包前袋细节")
\tassert(player_backpack.find_child("MakeHuman 玩家背包反光条", true, false) != null, "候选组合玩家缺少背包反光条细节")
\tassert(player_backpack.find_child("MakeHuman 玩家背包翻盖", true, false) != null, "候选组合玩家缺少背包翻盖")
\tassert(office.player.get_node_or_null("原创灰盒角色外观") == null, "候选组合玩家仍保留灰盒回退")
\tvar environment_visual = office.get_node_or_null("Visual")
\tassert(environment_visual != null, "办公室候选环境没有挂载 Visual")
\tassert(environment_visual.find_child("PolyHaven工位候选", true, false) != null, "办公室候选环境缺少真实办公桌")
\tvar floor_mesh = environment_visual.find_child("地面", true, false) as MeshInstance3D
\tassert(floor_mesh != null, "办公室候选环境缺少地面网格")
\tvar floor_material = floor_mesh.material_override as StandardMaterial3D
\tassert(floor_material != null, "办公室候选地面缺少材质覆盖")
\tvar floor_texture = floor_material.albedo_texture as Texture2D
\tassert(floor_texture != null and floor_texture.resource_path.ends_with("office_carpet_ai_candidate_v1.png"), "办公室候选地面没有绑定原创地毯纹理")
\tassert(environment_visual.find_child("电梯门", true, false) != null, "办公室候选环境缺少电梯门层")
\tassert(environment_visual.find_child("电梯呼叫面板", true, false) != null, "办公室候选环境缺少电梯呼叫面板")
\tassert(environment_visual.find_child("标识-办公区", true, false) != null, "办公室候选环境缺少办公区导视")
\tvar workstation_card = environment_visual.find_child("原创办公室连续工位写实背景卡", true, false)
\tassert(workstation_card != null and workstation_card is MeshInstance3D and workstation_card.material_override != null, "办公室候选环境缺少连续工位写实背景卡")
\tassert(environment_visual.find_child("电梯厅暖色实用光", true, false) != null, "办公室候选环境缺少电梯厅暖色实用光")
\tassert(environment_visual.find_child("原创交互道具候选套件", true, false) != null, "办公室候选环境缺少原创交互道具套件")
\tvar interaction_props = environment_visual.find_child("原创交互道具候选套件", true, false)
\tassert(interaction_props.find_children("*", "CollisionObject3D", true, false).is_empty(), "办公室交互道具候选不得创建碰撞体")
\tassert(interaction_props.find_children("*", "InteractionTarget", true, false).is_empty(), "办公室交互道具候选不得接管交互目标")
\tassert(office.get_node_or_null("办公室环境灰盒回退") == null, "办公室候选环境仍保留灰盒回退")
\tvar npc_visual = office.npc.get_node_or_null("Visual")
\tassert(npc_visual != null, "办公室候选 NPC 没有挂载 Visual")
\tassert(npc_visual.get_node_or_null("Character") != null, "办公室候选 NPC 缺少实际 GLB 角色")
\tassert(npc_visual.find_child("视觉返工背包", true, false) == null, "办公室候选 NPC 不得继承主角背包")
\tassert(npc_visual.find_child("参考服装工牌", true, false) != null, "办公室候选 NPC 缺少工牌身份层")
\tassert(npc_visual.find_child("视觉返工对讲机", true, false) != null, "办公室候选 NPC 缺少对讲机身份层")
\tassert(office.npc.get_node_or_null("原创灰盒NPC外观") == null, "办公室候选 NPC 仍保留灰盒回退")
\tvar vehicle_visual = office.vehicle.get_node_or_null("Visual")
\tassert(vehicle_visual != null, "办公室候选载具没有挂载 Visual")
\tassert(vehicle_visual.find_child("候选三轮车车体", true, false) != null, "办公室候选载具缺少实际 GLB 车体")
\tassert(office.vehicle.get_node_or_null("原创灰盒三轮车外观") == null, "办公室候选载具仍保留灰盒回退")
\tprint("办公室候选组合挂载契约测试通过")
\tquit(0)
`, "utf8");
}

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-combined-office-candidates-"));
try {
  fs.cpSync(formalRuntimeRoot, tempRoot, {recursive: true, filter: copyFilter});
  buildPlayerWrapper(tempRoot);
  buildCityPlayerWrapper(tempRoot);
  buildNpcWrapper(tempRoot);
  buildVehicleWrapper(tempRoot);
  copyOfficeComposition(tempRoot);

  const catalogPath = path.join(tempRoot, "tests/asset-runtime-catalog-combined-office-candidates.json");
  const catalog = JSON.parse(fs.readFileSync(path.join(formalRuntimeRoot, "content/asset-runtime-catalog.json"), "utf8"));
  const playerSlot = catalog.slots.find((slot) => slot.id === "player-character");
  playerSlot.scene_path = "res://assets/characters/makehuman-office-player/makehuman_player_visual_candidate.tscn";
  playerSlot.fallback_policy = "forbid";
  catalog.slots.push({
    id: "city-player-character",
    category: "characters",
    root_name: "Visual",
    scene_path: "res://art-source/characters/quaternius-superhero-male/player_character_visual_candidate.tscn",
    fallback_policy: "forbid",
  });
  const npcSlot = catalog.slots.find((slot) => slot.id === "office-npc-set");
  npcSlot.scene_path = "res://assets/characters/makehuman-office-worker/office_npc_atlas_retouch_candidate.tscn";
  npcSlot.fallback_policy = "forbid";
  const vehicleSlot = catalog.slots.find((slot) => slot.id === "three-wheel-vehicle");
  vehicleSlot.scene_path = "res://assets/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.tscn";
  vehicleSlot.fallback_policy = "forbid";
  const environmentSlot = catalog.slots.find((slot) => slot.id === "office-environment-kit");
  environmentSlot.scene_path = "res://office_desk_composition.tscn";
  environmentSlot.fallback_policy = "forbid";
  fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");
  writeContractTest(tempRoot);

  // 只做资源导入并等待 Godot 完成，不启动完整编辑器布局；在无图形桌面环境中，
  // --editor --quit 会触发编辑器线程通知崩溃，而 --import --recovery-mode
  // 仍然会导入 PNG/GLB 并保留后续真实运行时契约测试。
  runGodot(tempRoot, ["--import", "--recovery-mode"], {P0_EMBEDDED: "1"}, "候选组合办公室资产导入预热");
  const env = {
    REFERENCE_ASSET_CATALOG_PATH: "res://tests/asset-runtime-catalog-combined-office-candidates.json",
    P0_EMBEDDED: "1",
  };
  const contractOutput = runGodot(tempRoot, ["-s", "res://tests/combined_office_candidates_contract_test.gd"], env, "候选组合办公室挂载契约");
  if (!contractOutput.includes("办公室候选组合挂载契约测试通过")) throw new Error("候选组合办公室缺少挂载成功哨兵");
  const officeTestPath = path.join(tempRoot, "tests/office_combined_candidates_test.gd");
  const officeTestSource = fs.readFileSync(path.join(formalRuntimeRoot, "tests/office_integration_test.gd"), "utf8")
    .replace('var presentation = office.player.find_child("原创灰盒角色外观", true, false)', 'var presentation = office.player.get_node_or_null("Visual") if office.player.get_node_or_null("Visual") != null else office.player.find_child("原创灰盒角色外观", true, false)');
  fs.writeFileSync(officeTestPath, officeTestSource, "utf8");
  const officeOutput = runGodot(tempRoot, ["-s", "res://tests/office_combined_candidates_test.gd"], env, "候选组合办公室完整回放");
  if (!officeOutput.includes("办公室潜行端到端回放测试通过")) throw new Error("候选组合办公室缺少完整回放成功哨兵");
  const cityTestPath = path.join(tempRoot, "tests/city_combined_office_candidates_test.gd");
  const cityTestSource = fs.readFileSync(path.join(formalRuntimeRoot, "tests/city_integration_test.gd"), "utf8")
    .replace('assert(city.find_child("三轮车座椅", true, false) != null, "城市三轮车缺少座椅视觉")', 'assert(city.find_child("三轮车座椅", true, false) != null or city.find_child("候选三轮车座椅", true, false) != null, "城市三轮车缺少座椅视觉")')
    .replace('assert(city.find_child("三轮车车把", true, false) != null, "城市三轮车缺少车把视觉")', 'assert(city.find_child("三轮车车把", true, false) != null or city.find_child("候选三轮车车把", true, false) != null, "城市三轮车缺少车把视觉")')
    .replace('assert(city.find_child("三轮车货架", true, false) != null, "城市三轮车缺少货架视觉")', 'assert(city.find_child("三轮车货架", true, false) != null or city.vehicle.get_node_or_null("Visual") != null and (city.vehicle.get_node("Visual").find_child("候选三轮车货斗底板", true, false) != null or city.vehicle.get_node("Visual").find_child("候选三轮车货斗左栏", true, false) != null), "城市三轮车缺少货架视觉")');
  fs.writeFileSync(cityTestPath, cityTestSource, "utf8");
  const cityOutput = runGodot(tempRoot, ["-s", "res://tests/city_combined_office_candidates_test.gd"], env, "候选组合办公室城市回放");
  if (!cityOutput.includes("城市任务端到端回放测试通过")) throw new Error("候选组合办公室缺少城市回放成功哨兵");

  const evidence = {
    schema_version: 1,
    status: "candidate_isolated_formal_office_city_runtime_verified",
    candidate_ids: [
      "office-polyhaven-five-desk-full-kit-candidate",
      "office-npc-makehuman-elegant-suit-skinned-512-atlas-candidate",
      "city-vehicle-three-wheel-delivery-atlas-candidate",
      "player-character-makehuman-elegant-suit-atlas-candidate",
    ],
    source_sha256: {
      office_desk_glb: sha256(deskSource),
      office_carpet_texture: sha256(path.join(candidateRoot, "office_carpet_ai_candidate_v1.png")),
      interaction_props_glb: sha256(interactionPropsSource),
      office_composition_gd: sha256(path.join(candidateRoot, "office_desk_composition.gd")),
      office_composition_tscn: sha256(path.join(candidateRoot, "office_desk_composition.tscn")),
      office_npc_atlas_glb: sha256(npcSource),
      npc_retouch_candidate_gd: sha256(npcRetouchSource),
      three_wheel_atlas_glb: sha256(vehicleSource),
      player_character_glb: sha256(playerSource),
      player_visual_candidate_gd: sha256(playerVisualSource),
      runtime_runner_mjs: sha256(runtimeRunnerSource),
    },
    runtime_options: {
      asset_catalog: "combined-office-candidates-override",
      office_environment_fallback_policy: "forbid",
      office_npc_fallback_policy: "forbid",
      vehicle_fallback_policy: "forbid",
      player_character: "makehuman_elegant_suit_atlas_candidate",
    },
    environment: "temporary copy of gta-reference-runtime",
    checks: [
      "Godot import of office desk composition, player candidate, NPC atlas and vehicle atlas",
      "player visual candidate wrapper with reduced backpack and original detail layers",
      "office environment, player, NPC and vehicle Visual mounts with fallback forbidden",
      "NPC retouch backpack bone attachment",
      "full office stealth, perception, driving and save replay",
      "full city task, driving, wheel and save replay",
    ],
    visual_status: "unverified",
    release_allowed: false,
    captured_at: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(evidencePath), {recursive: true});
  fs.writeFileSync(evidenceTempPath, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  fs.renameSync(evidenceTempPath, evidencePath);
  console.log(`办公室候选组合隔离运行时证据已写入：${evidencePath}`);
  if (playtestMode) {
    console.log("即将启动办公室组合候选试玩；关闭 Godot 窗口后自动清理临时运行时副本。");
    launchCandidatePlaytest(tempRoot);
  }
} catch (error) {
  fs.rmSync(evidenceTempPath, {force: true});
  const failureEvidence = {
    schema_version: 1,
    status: "candidate_isolated_formal_office_city_runtime_failed",
    candidate_ids: [
      "office-polyhaven-five-desk-full-kit-candidate",
      "office-npc-makehuman-elegant-suit-skinned-512-atlas-candidate",
      "city-vehicle-three-wheel-delivery-atlas-candidate",
      "player-character-makehuman-elegant-suit-atlas-candidate",
    ],
    source_sha256: {
      office_desk_glb: safeSha256(deskSource),
      office_carpet_texture: safeSha256(path.join(candidateRoot, "office_carpet_ai_candidate_v1.png")),
      office_composition_gd: safeSha256(path.join(candidateRoot, "office_desk_composition.gd")),
      office_composition_tscn: safeSha256(path.join(candidateRoot, "office_desk_composition.tscn")),
      office_npc_atlas_glb: safeSha256(npcSource),
      npc_retouch_candidate_gd: safeSha256(npcRetouchSource),
      three_wheel_atlas_glb: safeSha256(vehicleSource),
      player_character_glb: safeSha256(playerSource),
      player_visual_candidate_gd: safeSha256(playerVisualSource),
    },
    runtime_options: {
      asset_catalog: "combined-office-candidates-override",
      office_environment_fallback_policy: "forbid",
      office_npc_fallback_policy: "forbid",
      vehicle_fallback_policy: "forbid",
      player_character: "makehuman_elegant_suit_atlas_candidate",
    },
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

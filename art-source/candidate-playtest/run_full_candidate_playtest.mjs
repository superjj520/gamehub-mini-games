import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const candidateRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(candidateRoot, "../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const godotBinary = process.env.GODOT_BIN || "godot";
const preflightOnly = process.env.FULL_CANDIDATE_PREFLIGHT_ONLY === "1";
const persistentOutput = process.env.FULL_CANDIDATE_OUTPUT?.trim() ? path.resolve(process.env.FULL_CANDIDATE_OUTPUT.trim()) : null;
const characterVariant = process.env.FULL_CANDIDATE_CHARACTERS?.trim() || "makehuman";
const originalOnly = characterVariant === "original_only";
const evidencePath = path.resolve(process.env.FULL_CANDIDATE_EVIDENCE_PATH?.trim() || path.join(workspaceRoot, "reference-evidence/candidate-runtime/full-candidate-playtest.json"));

function readCurrentSourceIdentity() {
  const result = spawnSync(process.execPath, [path.join(workspaceRoot, "scripts/source_fingerprint.mjs")], {
    cwd: workspaceRoot,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    throw new Error(`无法计算当前运行时源指纹：${String(result.stderr || result.stdout || "未知错误").trim()}`);
  }
  const match = String(result.stdout || "").trim().match(/^([0-9a-f]{64}) files=(\d+)$/);
  if (!match) throw new Error(`当前运行时源指纹输出格式无效：${String(result.stdout || "").trim()}`);
  return {sha256: match[1], file_count: Number(match[2])};
}

const currentSource = readCurrentSourceIdentity();

if (!["makehuman", "original", "original_only"].includes(characterVariant)) {
	throw new Error(`不支持的完整候选角色方案：${characterVariant}；可选值为 makehuman、original 或 original_only`);
}

function assertSafePersistentOutput(outputRoot) {
  const buildRoot = path.join(workspaceRoot, "build");
  if (!outputRoot.startsWith(`${buildRoot}${path.sep}`) || outputRoot === formalRuntimeRoot || outputRoot === workspaceRoot) {
    throw new Error("完整候选运行包必须输出到 build 子目录，且不能覆盖正式运行时或工作区");
  }
}

function collectPackageFiles(rootPath) {
  const ignoredDirectories = new Set([".godot"]);
  const ignoredMetadataFiles = new Set(["candidate-package-manifest.json", "CANDIDATE_PACKAGE_README.md"]);
  const files = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true}).sort((left, right) => left.name.localeCompare(right.name))) {
      if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        visit(absolutePath);
      } else if (entry.isFile() && !ignoredMetadataFiles.has(entry.name) && !entry.name.endsWith(".import") && !entry.name.endsWith(".uid")) {
        files.push(absolutePath);
      }
    }
  };
  visit(rootPath);
  return files;
}

function fingerprintPackage(rootPath) {
  const hash = crypto.createHash("sha256");
  const files = collectPackageFiles(rootPath);
  for (const filePath of files) {
    hash.update(path.relative(rootPath, filePath).split(path.sep).join("/"));
    hash.update("\0");
    hash.update(fs.readFileSync(filePath));
    hash.update("\0");
  }
  return {sha256: hash.digest("hex"), file_count: files.length};
}

function writePersistentPackageContract(rootPath, source) {
  const packageFingerprint = fingerprintPackage(rootPath);
  const manifest = {
    schema_version: 1,
    status: "internal_candidate_review_only",
    product_name: "新时代觉醒者",
    scope: "office_and_city_candidate_preview",
    character_variant: characterVariant,
    release_allowed: false,
    preflight_status: "candidate_isolated_full_playtest_verified",
    visual_status: "unverified",
    graphical_capture_status: "city_p0_graphics_capture_available_manual_acceptance_pending",
    source: {sha256: source.sha256, file_count: source.file_count},
    package: {root: path.relative(workspaceRoot, rootPath).split(path.sep).join("/"), ...packageFingerprint},
    entries: ["office-candidate", "city-candidate", "city-market-candidate"],
    launch_script: "./scripts/play_candidate.sh",
    candidate_policy: "候选资产仅用于内部试玩、行为回放和视觉审阅；不得直接进入发布构建或商店素材",
    launch_command: "./scripts/play_candidate.sh",
    launch_behavior: "启动后直接显示办公室与城市候选入口；不会进入正式灰盒入口",
    excluded: ["reference-evidence/", "原始视频参考文件", "未授权商业资产"],
    remaining_gates: ["候选视觉人工签收", "最终资产权利签收", "Windows 10/11 目标设备 QA", "Steam 商店门禁"],
  };
  /*
  fs.writeFileSync(path.join(rootPath, "candidate-package-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  fs.writeFileSync(path.join(rootPath, "CANDIDATE_PACKAGE_README.md"), `# 《新时代觉醒者》完整候选运行包\n\n状态：内部候选试玩，不是可上架版本。\n\n正式运行时源指纹：${source.sha256} / ${source.file_count} 个文件。\n完整候选包指纹：${packageFingerprint.sha256} / ${packageFingerprint.file_count} 个文件。\n\n本包包含办公室与城市候选入口、候选资产和完整行为回放契约。参考视频、参考抽帧和未授权商业资产不进入本包。\n\n完整候选源码树运行：在本目录执行 \\`godot --path .\\`。\n\nWindows 真机试玩：\n\n1. 完整候选源码树中直接运行 \\`build/windows/新时代觉醒者-完整候选.exe\\`。\n2. 在完整候选源码树根目录执行 \\`powershell -ExecutionPolicy Bypass -File .\\scripts\\windows_device_qa.ps1 -BuildKind 完整候选 -BuildPath .\\build\\windows\\新时代觉醒者-完整候选.exe\\`，采集办公室、城市、输入和异常重启证据。\n3. 将证据目录带回项目后执行 \\`npm run verify:candidate:windows-device-qa\\`；人工完成画面、输入、存档恢复、性能和异常退出等验收后再执行严格核验。\n4. 详细设备、截图、手柄和签收要求见配套 QA 包根目录的 WINDOWS_DEVICE_QA_RUNBOOK.md。\n\nWindows QA 压缩包说明：压缩包只包含 Windows 可执行文件、构建清单和 QA 脚本，不包含 Godot 编辑器或完整源码树；解压后应直接运行 \\`build/windows/新时代觉醒者-完整候选.exe\\`，再按 \\`WINDOWS_DEVICE_QA_RUNBOOK.md\\` 执行脚本。\n\n该完整候选 QA 只用于内部试玩，不会把候选状态升级为可上架状态。\n\n当前必须保留的门禁：候选视觉人工签收、最终资产权利、Windows 10/11 目标设备 QA、Steam 商店材料。\n`, "utf8");
  */
  fs.writeFileSync(path.join(rootPath, "candidate-package-manifest.json"), JSON.stringify(manifest, null, 2) + "\n", "utf8");
  const variantLabel = characterVariant === "original_only" ? "原创边界候选" : characterVariant === "original" ? "原创角色候选" : "完整候选";
  const executableName = characterVariant === "original_only" ? "新时代觉醒者-原创边界候选.exe" : characterVariant === "original" ? "新时代觉醒者-原创角色候选.exe" : "新时代觉醒者-完整候选.exe";
  const buildKind = characterVariant === "makehuman"
    ? "完整候选"
    : characterVariant === "original_only"
      ? "原创边界候选"
      : "首发候选";
  const qaEvidenceRoot = characterVariant === "original_only"
    ? "reference-evidence/candidate-windows-device-qa-original-only"
    : "reference-evidence/candidate-windows-device-qa";
  const qaBuildManifest = characterVariant === "original_only"
    ? "reference-evidence/candidate-runtime/full-candidate-windows-original-only-build.json"
    : characterVariant === "original"
      ? "reference-evidence/candidate-runtime/full-candidate-windows-original-build.json"
      : "reference-evidence/candidate-runtime/full-candidate-windows-build.json";
  const qaAssetCatalog = originalOnly
    ? "res://content/asset-runtime-catalog-original-only.json"
    : "res://tests/asset-runtime-catalog-full-candidates.json";
  const readmeContent = [
    "# 《新时代觉醒者》" + variantLabel + "运行包",
    "",
    "状态：内部候选试玩，不是可上架版本。",
    "",
    "正式运行时源指纹：" + source.sha256 + " / " + source.file_count + " 个文件。",
    "完整候选包指纹：" + packageFingerprint.sha256 + " / " + packageFingerprint.file_count + " 个文件。",
    "",
    "本包包含办公室与城市候选入口、候选资产和完整行为回放契约。原始参考视频、未处理参考抽帧和未授权商业资产不进入本包；本包只包含已经登记为内部候选的可玩背景编辑帧。",
    "",
    "完整候选源码树运行：只有在包含 project.godot 的完整候选源码树中，才可执行 godot --path .；Windows QA 压缩包不包含完整源码树，不能在 QA 压缩包根目录执行该命令。",
    "最短启动方式：在本包根目录执行 ./scripts/play_candidate.sh；也可以直接执行 godot --path .。启动后按 1 进入办公室候选，按 2 进入城市候选。",
    "",
    "Windows 真机试玩：",
    "",
    "1. 候选源码树中直接运行 build/windows/" + executableName + "。",
    "2. 在候选源码树根目录执行 powershell -ExecutionPolicy Bypass -File .\\scripts\\windows_complete_qa.ps1 -BuildKind " + buildKind + " -BuildPath .\\build\\windows\\" + executableName + " -EvidenceRoot .\\" + qaEvidenceRoot + " -BuildManifestPath .\\" + qaBuildManifest + " -AssetCatalogPath " + qaAssetCatalog + "，采集设备、参考矩阵和扩展视觉证据。",
    "3. 将证据目录带回项目后执行 node scripts/verify_windows_complete_qa.mjs --build-manifest " + qaBuildManifest + " --evidence-root " + qaEvidenceRoot + "；人工完成画面、输入、存档恢复、性能和异常退出等验收后再执行严格核验。",
    "4. 单项严格核验可执行 node scripts/verify_windows_device_qa.mjs --candidate --strict --build-manifest " + qaBuildManifest + " --root " + qaEvidenceRoot + "。",
    "5. 详细设备、截图、手柄和签收要求见配套 QA 包根目录的 WINDOWS_DEVICE_QA_RUNBOOK.md。",
    "",
    "Windows QA 压缩包说明：压缩包只包含 Windows 可执行文件、构建清单和 QA 脚本，不包含 Godot 编辑器或完整源码树；解压后应直接运行 build/windows/" + executableName + "，再按 WINDOWS_DEVICE_QA_RUNBOOK.md 执行脚本。",
    "",
    "该" + variantLabel + " QA 只用于内部试玩，不会把候选状态升级为可上架状态。",
    "",
    "当前必须保留的门禁：候选视觉人工签收、最终资产权利、Windows 10/11 目标设备 QA、Steam 商店材料。",
    "",
    "启动行为：本包启动后直接显示办公室与城市候选入口；Windows 候选程序双击后也会直接进入候选入口。",
  ].join("\n") + "\n";
  fs.writeFileSync(path.join(rootPath, "CANDIDATE_PACKAGE_README.md"), readmeContent, "utf8");
  return manifest;
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  if (originalOnly && [
    "assets/characters/quaternius-superhero-male/",
    "assets/environment/quaternius-downtown/",
    "assets/environment/cc0/",
    "art-source/characters/makehuman-office-player/",
    "art-source/characters/makehuman-office-worker/",
  ].some((prefix) => relative.startsWith(prefix))) return false;
  if (originalOnly && [
    "content/asset-runtime-catalog-makehuman-office-candidate.json",
    "tests/inspect_quaternius_candidate.gd",
    "tests/inspect_quaternius_candidate.gd.uid",
    "tests/city_environment_quaternius_candidate.gd",
    "tests/city_environment_quaternius_candidate.gd.uid",
    "tests/city_environment_quaternius_candidate.tscn",
    "tests/makehuman_animation_contract.gd",
    "tests/makehuman_animation_contract.gd.uid",
  ].includes(relative)) return false;
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function rewriteCandidateReferences(rootPath) {
  const entries = fs.readdirSync(rootPath, {withFileTypes: true});
  for (const entry of entries) {
    const entryPath = path.join(rootPath, entry.name);
    if (entry.isDirectory()) {
      rewriteCandidateReferences(entryPath);
      continue;
    }
    if (!/[.](gd|tscn|json)$/.test(entry.name)) continue;
    const text = fs.readFileSync(entryPath, "utf8");
    fs.writeFileSync(entryPath, text.replaceAll("res://../art-source", "res://art-source"), "utf8");
  }
}

function copyRuntimeClassCache(runtimeRoot) {
  const sourceCache = path.join(formalRuntimeRoot, ".godot/global_script_class_cache.cfg");
  const targetCache = path.join(runtimeRoot, ".godot/global_script_class_cache.cfg");
  if (fs.existsSync(sourceCache)) {
    fs.mkdirSync(path.dirname(targetCache), {recursive: true});
    fs.copyFileSync(sourceCache, targetCache);
  }
  const sourceImported = path.join(formalRuntimeRoot, ".godot/imported");
  const targetImported = path.join(runtimeRoot, ".godot/imported");
  if (fs.existsSync(sourceImported)) fs.cpSync(sourceImported, targetImported, {recursive: true});
}

function copyFiles(sourceRoot, targetRoot, fileNames) {
  fs.mkdirSync(targetRoot, {recursive: true});
  for (const fileName of fileNames) {
    fs.copyFileSync(path.join(sourceRoot, fileName), path.join(targetRoot, fileName));
  }
}

function copyOriginalOfficeCharacters(runtimeRoot) {
  // 原创角色候选必须消费正式运行时的唯一源目录；original_only 只表示
  // 资产目录边界，不允许再复制一份会与正式运行时漂移的旧角色快照。
  const sourceRoot = path.join(formalRuntimeRoot, "assets/characters/original-procedural-office-characters");
  const targetRoot = path.join(runtimeRoot, "assets/characters/original-procedural-office-characters");
  fs.cpSync(sourceRoot, targetRoot, {recursive: true});
}

function patchOriginalOnlyFormalRuntime(runtimeRoot) {
  const originalOnlyEnvironmentSource = path.join(workspaceRoot, "art-source/candidate-playtest/original-only/original_only_city_environment_candidate.gd");
  const formalEnvironmentTarget = path.join(runtimeRoot, "assets/environment/original-procedural-city-environment/original_city_environment_candidate.gd");
  fs.copyFileSync(originalOnlyEnvironmentSource, formalEnvironmentTarget);
  const cityDemoPath = path.join(runtimeRoot, "scripts/city_demo.gd");
  const cityDemo = fs.readFileSync(cityDemoPath, "utf8").replace(
    "\tif not _catalog_slot_has_scene(\"city-environment-kit\"):\n\t\t_add_cc0_worn_asphalt_visuals()",
    "\t# 原创边界候选不加载第三方 CC0 沥青纹理；道路由原创程序化环境层提供。",
  );
  fs.writeFileSync(cityDemoPath, cityDemo, "utf8");
}

function copyCandidateAssets(runtimeRoot) {
  if (originalOnly) patchOriginalOnlyFormalRuntime(runtimeRoot);
  if (!originalOnly) {
    const cityTarget = path.join(runtimeRoot, "art-source/city-full-kit-candidate");
    fs.cpSync(path.join(workspaceRoot, "art-source/city-full-kit-candidate"), cityTarget, {recursive: true});
    rewriteCandidateReferences(cityTarget);
  }

  if (characterVariant === "original_only") {
    const originalOnlySource = path.join(workspaceRoot, "art-source/candidate-playtest/original-only");
    const originalOnlyTarget = path.join(runtimeRoot, "art-source/candidate-playtest/original-only");
    fs.cpSync(originalOnlySource, originalOnlyTarget, {recursive: true});
  }

  const originalCrowdSource = path.join(workspaceRoot, "art-source/characters/original-procedural-city-crowd");
  const originalCrowdTarget = path.join(runtimeRoot, "art-source/characters/original-procedural-city-crowd");
  fs.cpSync(originalCrowdSource, originalCrowdTarget, {recursive: true});

  let makeHumanSource = null;
  if (!originalOnly) {
    const cityPlayerSource = path.join(workspaceRoot, "art-source/characters/quaternius-superhero-male");
    const cityPlayerTarget = path.join(runtimeRoot, "art-source/characters/quaternius-superhero-male");
    fs.mkdirSync(cityPlayerTarget, {recursive: true});
    copyFiles(cityPlayerSource, cityPlayerTarget, [
      "player_character_visual_candidate.gd",
      "player_character_visual_candidate.tscn",
    ]);

    // 正式运行时保留了一个旧的城市人群候选场景作为资源扫描入口；
    // 完整候选包即使不选择它，也必须携带其脚本，避免导出阶段出现隐藏资源错误。
    const quaterniusCrowdSource = path.join(workspaceRoot, "art-source/characters/quaternius-superhero-male/city-crowd-candidate");
    const quaterniusCrowdTarget = path.join(runtimeRoot, "art-source/characters/quaternius-superhero-male/city-crowd-candidate");
    fs.mkdirSync(quaterniusCrowdTarget, {recursive: true});
    copyFiles(quaterniusCrowdSource, quaterniusCrowdTarget, [
      "city_crowd_quaternius_candidate.gd",
      "city_crowd_quaternius_candidate.tscn",
    ]);
    fs.copyFileSync(
      path.join(quaterniusCrowdSource, "city_crowd_quaternius_candidate.gd"),
      path.join(runtimeRoot, "assets/characters/quaternius-superhero-male/city_crowd_quaternius_candidate.gd"),
    );

    makeHumanSource = path.join(workspaceRoot, "art-source/characters/makehuman-office-worker");
    const makeHumanTarget = path.join(runtimeRoot, "art-source/characters/makehuman-office-worker");
    copyFiles(makeHumanSource, makeHumanTarget, [
      "makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
      "makehuman_office_npc_retouch.gd",
    ]);
  }

  const vehicleSource = path.join(workspaceRoot, "art-source/vehicles/three-wheel-delivery");
  const vehicleTarget = path.join(runtimeRoot, "art-source/vehicles/three-wheel-delivery");
  fs.cpSync(vehicleSource, vehicleTarget, {recursive: true});
  rewriteCandidateReferences(vehicleTarget);

  const officeSource = path.join(workspaceRoot, "art-source/environment/polyhaven-metal-office-desk");
  copyFiles(officeSource, runtimeRoot, [
    "office_desk_composition.gd",
    "office_desk_composition.tscn",
    "office_carpet_ai_candidate_v1.png",
    "office_carpet_ai_candidate_v1.json",
  ]);
  const officeVideoCandidateDirectory = path.join(runtimeRoot, "reference-video-candidate");
  fs.mkdirSync(officeVideoCandidateDirectory, {recursive: true});
  // 完整候选包必须携带办公室 10 段独立背景；只拷贝首发镜头会导致
  // office-03/04/05/07/08/09 在隔离包内退回到旧构图，形成“场景已接入、包内不可复现”的假完成。
  for (const segment of [
    "office-01", "office-02", "office-03", "office-04", "office-05",
    "office-06", "office-07", "office-08", "office-09", "office-10",
  ]) {
    const filename = `${segment}-video-playable-backdrop-v1.png`;
    fs.copyFileSync(
      path.join(officeSource, `reference-video-candidate/${filename}`),
      path.join(officeVideoCandidateDirectory, filename),
    );
  }
  if (["original", "original_only"].includes(characterVariant)) {
    const originalDeskSource = path.join(workspaceRoot, "art-source/environment/original-office-desk");
    const originalDeskTarget = path.join(runtimeRoot, "art-source/environment/original-office-desk");
    fs.cpSync(originalDeskSource, originalDeskTarget, {recursive: true});
    const compositionPath = path.join(runtimeRoot, "office_desk_composition.gd");
    const composition = fs.readFileSync(compositionPath, "utf8")
      .replace('const DESK_SCENE := preload("res://office_desk_candidate.tscn")', 'const DESK_SCENE := preload("res://art-source/environment/original-office-desk/original_office_desk_candidate.tscn")');
    fs.writeFileSync(compositionPath, composition, "utf8");
    if (characterVariant === "original_only") {
      copyFiles(officeSource, path.join(runtimeRoot, "assets/environment/generated"), [
        "office_elevator_lobby_v2_generated.png",
        "office_elevator_lobby_v2_generated.json",
      ]);
      const originalOnlyComposition = fs.readFileSync(compositionPath, "utf8")
        .replace("res://assets/environment/generated/office_elevator_lobby_v1_generated.png", "res://assets/environment/generated/office_elevator_lobby_v2_generated.png");
      fs.writeFileSync(compositionPath, originalOnlyComposition, "utf8");
    }
  } else {
    copyFiles(officeSource, runtimeRoot, ["office_desk_candidate.gd", "office_desk_candidate.tscn", "metal_office_desk_1k.glb"]);
  }
  fs.copyFileSync(
    path.join(workspaceRoot, "art-source/props/original-interaction-kit/interaction_props_kit.glb"),
    path.join(runtimeRoot, "interaction_props_kit.glb"),
  );

  if (!originalOnly) {
    const playerTarget = path.join(runtimeRoot, "assets/characters/makehuman-office-player");
    fs.mkdirSync(playerTarget, {recursive: true});
    fs.copyFileSync(
      path.join(workspaceRoot, "art-source/characters/makehuman-office-player/makehuman_player_visual_candidate.gd"),
      path.join(playerTarget, "makehuman_player_visual_candidate.gd"),
    );
    fs.copyFileSync(
      path.join(makeHumanSource, "makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb"),
      path.join(playerTarget, "makehuman_player_elegant_suit_atlas_candidate.glb"),
    );
    fs.writeFileSync(path.join(playerTarget, "makehuman_player_visual_candidate.tscn"), `[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://assets/characters/makehuman-office-player/makehuman_player_elegant_suit_atlas_candidate.glb" id="1_character"]
[ext_resource type="Script" path="res://assets/characters/makehuman-office-player/makehuman_player_visual_candidate.gd" id="2_script"]

[node name="PlayerCharacterVisualCandidate" type="Node3D"]
script = ExtResource("2_script")

[node name="候选主角身体" parent="." instance=ExtResource("1_character")]
rotation_degrees = Vector3(0, 180, 0)
scale = Vector3(1.35, 1.35, 1.35)
`, "utf8");

    const npcTarget = path.join(runtimeRoot, "assets/characters/makehuman-office-worker");
    fs.mkdirSync(npcTarget, {recursive: true});
    fs.copyFileSync(
      path.join(makeHumanSource, "makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb"),
      path.join(npcTarget, "office_npc_atlas_candidate.glb"),
    );
    const npcRetouch = fs.readFileSync(path.join(makeHumanSource, "makehuman_office_npc_retouch.gd"), "utf8")
      .replace('get_meta("preserve_imported_materials", false)', 'get_meta("preserve_imported_materials", true)')
      .replace('get_meta("reference_office_materials", false)', 'get_meta("reference_office_materials", true)')
      .replace('get_meta("use_elegant_suit_skinned", false)', 'get_meta("use_elegant_suit_skinned", true)');
    fs.writeFileSync(path.join(npcTarget, "makehuman_office_npc_retouch.gd"), npcRetouch, "utf8");
    fs.writeFileSync(path.join(npcTarget, "office_npc_atlas_retouch_candidate.tscn"), `[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://assets/characters/makehuman-office-worker/office_npc_atlas_candidate.glb" id="1_atlas"]
[ext_resource type="Script" path="res://assets/characters/makehuman-office-worker/makehuman_office_npc_retouch.gd" id="2_retouch"]

[node name="OfficeNpcAtlasRetouchCandidate" type="Node3D"]
script = ExtResource("2_retouch")

[node name="Character" parent="." instance=ExtResource("1_atlas")]
`, "utf8");
  }

  if (["original", "original_only"].includes(characterVariant)) copyOriginalOfficeCharacters(runtimeRoot);
}

function writeMergedCatalog(runtimeRoot) {
  const catalogPath = path.join(runtimeRoot, "tests/asset-runtime-catalog-full-candidates.json");
  const catalog = JSON.parse(fs.readFileSync(path.join(formalRuntimeRoot, "content/asset-runtime-catalog.json"), "utf8"));
  catalog.policy = originalOnly
    ? "original_assets_only_candidate_runtime_no_graybox_for_visual_slots"
    : "optional_release_asset_with_graybox_fallback";
  const paths = {
    "player-character": ["original", "original_only"].includes(characterVariant)
      ? "res://assets/characters/original-procedural-office-characters/original_player_candidate.tscn"
      : "res://assets/characters/makehuman-office-player/makehuman_player_visual_candidate.tscn",
    "city-player-character": ["original", "original_only"].includes(characterVariant)
      ? "res://assets/characters/original-procedural-office-characters/original_player_candidate.tscn"
      : "res://assets/characters/makehuman-office-player/makehuman_player_visual_candidate.tscn",
    "office-npc-set": ["original", "original_only"].includes(characterVariant)
      ? "res://assets/characters/original-procedural-office-characters/original_office_npc_candidate.tscn"
      : "res://assets/characters/makehuman-office-worker/office_npc_atlas_retouch_candidate.tscn",
    "city-crowd-set": characterVariant === "original_only"
      ? "res://art-source/characters/original-procedural-city-crowd/original_procedural_city_crowd_candidate.tscn"
      : "res://art-source/city-full-kit-candidate/city_crowd_makehuman_runtime_overlay.tscn",
    "three-wheel-vehicle": characterVariant === "original_only"
      // 原创边界候选也使用工程内原创程序化最终候选，避免回退到低细节三轮车。
      ? "res://art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.tscn"
      : "res://art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.tscn",
    "office-environment-kit": "res://office_desk_composition.tscn",
    "city-environment-kit": characterVariant === "original_only"
      ? "res://art-source/candidate-playtest/original-only/original_only_city_environment_candidate.tscn"
      : "res://art-source/city-full-kit-candidate/city_environment_storefront_candidate.tscn",
    "interaction-props": characterVariant === "original_only"
      ? "res://assets/props/original-procedural-interaction-props/original_interaction_props_candidate.tscn"
      : "res://interaction_props_kit.glb",
  };
  for (const slot of catalog.slots) {
    if (Object.hasOwn(paths, slot.id)) {
      slot.scene_path = paths[slot.id];
      slot.fallback_policy = "forbid";
    }
  }
  if (!catalog.slots.some((slot) => slot.id === "city-player-character")) {
    catalog.slots.push({
      id: "city-player-character",
      category: "characters",
      root_name: "Visual",
      scene_path: paths["city-player-character"],
      fallback_policy: "forbid",
    });
  }
  fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");
  return "res://tests/asset-runtime-catalog-full-candidates.json";
}

function writeCandidateAudioCatalog(runtimeRoot) {
  const catalogPath = path.join(runtimeRoot, "content/audio-runtime-catalog.json");
  const catalog = JSON.parse(fs.readFileSync(catalogPath, "utf8"));
  catalog.policy = "full_candidate_audio_assets_required_no_silent_fallback";
  for (const event of catalog.events ?? []) event.fallback_policy = "forbid";
  fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");
  return "res://content/audio-runtime-catalog.json";
}

function patchCandidateCaptureScripts(runtimeRoot) {
  const officeCapturePath = path.join(runtimeRoot, "tests/capture_p0_candidate_visual.gd");
  if (fs.existsSync(officeCapturePath)) {
    const original = fs.readFileSync(officeCapturePath, "utf8");
    // 这里只替换目录值，不依赖原脚本的缩进数量，避免候选截图悄悄回落到正式灰盒目录。
    const patched = original.replace(
      'catalog_path = "res://tests/asset-runtime-catalog-override.json"',
      'catalog_path = "res://tests/asset-runtime-catalog-full-candidates.json"',
    ).replace(
      '\telse:\n\t\tvar crouch := InputFrameClass.new()',
     '\telse:\n\t\t# 候选组合房间以原点为构图中心；这里只调整截图站位，不改变正式任务起点。\n\t\toffice.player.position = Vector3(0.0, 1.0, 1.7)\n\t\toffice.camera_rig.set_follow_profile(3.05, 1.78)\n\t\tvar candidate_yaw := OS.get_environment("P0_CANDIDATE_YAW").strip_edges()\n\t\toffice.camera_rig.set_orbit(float(candidate_yaw) if not candidate_yaw.is_empty() else 54.0, -10.0)\n\t\tvar crouch := InputFrameClass.new()',
      '\telse:\n\t\t# 候选组合房间以原点为构图中心；这里只调整截图站位，不改变正式任务起点。\n\t\toffice.player.position = Vector3(0.0, 1.0, 1.7)\n\t\toffice.camera_rig.set_follow_profile(2.85, 1.72)\n\t\tvar candidate_yaw := OS.get_environment("P0_CANDIDATE_YAW").strip_edges()\n\t\toffice.camera_rig.set_orbit(float(candidate_yaw) if not candidate_yaw.is_empty() else 72.0, -10.0)\n\t\tvar crouch := InputFrameClass.new()',
    ).replace(
      '\telse:\n\t\t# 候选组合房间以原点为构图中心；这里只调整截图站位，不改变正式任务起点。',
     '\telif scenario == "office-supervisor":\n\t\t# 候选主管工位的独立构图，只用于验收新增视觉，不改变正式任务回放。\n\t\toffice.player.position = Vector3(3.0, 1.0, 0.45)\n\t\toffice.camera_rig.set_orbit(0.0, -10.0)\n\telse:\n\t\t# 候选组合房间以原点为构图中心；这里只调整截图站位，不改变正式任务起点。',
      '\telif scenario == "office-supervisor":\n\t\t# 候选主管工位的独立构图，只用于验收新增视觉，不改变正式任务回放。\n\t\toffice.player.position = Vector3(3.0, 1.0, 0.45)\n\t\toffice.camera_rig.set_follow_profile(2.65, 1.68)\n\t\toffice.camera_rig.set_orbit(0.0, -10.0)\n\telse:\n\t\t# 候选组合房间以原点为构图中心；这里只调整截图站位，不改变正式任务起点。',
    ).replace(
      'var capture_id := "p0-candidate-office-06" if scenario == "office-06" else "p0-candidate-office-01"',
      'var capture_id := "p0-candidate-office-06" if scenario == "office-06" else ("p0-candidate-office-supervisor" if scenario == "office-supervisor" else "p0-candidate-office-01")',
    );
    fs.writeFileSync(officeCapturePath, patched, "utf8");
  }
  const cityCapturePath = path.join(runtimeRoot, "tests/capture_p0_city_candidate_visual.gd");
  if (fs.existsSync(cityCapturePath)) {
    const original = fs.readFileSync(cityCapturePath, "utf8");
    const patched = original.replace(
      'city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-override.json")',
      'city.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")',
    )
      .replace('city.vehicle.position = Vector3(5.0, 0.7, 3.0)', 'city.vehicle.position = Vector3(0.0, 0.7, 4.4)')
      .replace('city.camera_rig.set_orbit(-20.0, -18.0)', 'city.camera_rig.set_follow_profile(5.4, 2.35)\n\tcity.camera_rig.set_orbit(0.0, -8.0)');
    fs.writeFileSync(cityCapturePath, patched, "utf8");
  }
  const extendedCityCaptureSource = path.join(candidateRoot, "../city-full-kit-candidate/capture_city_storefront_candidate.gd");
  const extendedCityCaptureTarget = path.join(runtimeRoot, "tests/capture_city_storefront_candidate.gd");
  if (fs.existsSync(extendedCityCaptureSource)) {
    const extendedCityCapture = fs.readFileSync(extendedCityCaptureSource, "utf8")
      .replace('res://../art-source/city-full-kit-candidate/asset-runtime-catalog-city-full-kit-override.json', "res://tests/asset-runtime-catalog-full-candidates.json");
    fs.writeFileSync(extendedCityCaptureTarget, extendedCityCapture, "utf8");
  }
}

function writeLaunchProfile(runtimeRoot, catalogPath) {
  const profilePath = path.join(runtimeRoot, "content/launch-profile.json");
  const profile = {
    schema_version: 1,
    id: "launch-profile-full-candidate-v1",
    version: 1,
    status: "internal_candidate_review_only",
    launch_scope: "office_and_city_candidate_preview",
    internal_development_mode: true,
    character_variant: characterVariant,
    character_variant_label: ["original", "original_only"].includes(characterVariant) ? "原创程序化角色方案" : "MakeHuman角色方案",
    policy: "只用于办公室与城市候选资产的统一内部试玩，不进入默认发布入口",
    entries: [
      {id: "office-candidate", shortcut: "1", title: "1  准点下班 · 办公室候选预览", description: `${["original", "original_only"].includes(characterVariant) ? "原创程序化人物" : "MakeHuman人物"}、办公桌、交互道具和三轮车候选`, scene_path: "res://scenes/benchmark.tscn", asset_catalog_path: catalogPath, content_pack_id: "office-leave-on-time-v1"},
      {id: "city-candidate", shortcut: "2", title: "2  免费鸡蛋 · 城市候选预览", description: "连续街区、城市人群、道路 PBR、店铺和三轮车候选", scene_path: "res://scenes/city.tscn", asset_catalog_path: catalogPath, content_pack_id: "city-free-eggs-v1"},
      {id: "city-market-candidate", shortcut: "4", title: "4  街角夜市 · 城市配送候选预览", description: "接单、装载、配送和领奖四阶段内容候选", scene_path: "res://scenes/city.tscn", asset_catalog_path: catalogPath, content_pack_id: "city-market-delivery-v1"},
    ],
  };
  fs.writeFileSync(profilePath, `${JSON.stringify(profile, null, 2)}\n`, "utf8");
}

function writeCandidateLaunchMarker(runtimeRoot) {
  const markerPath = path.join(runtimeRoot, "content/full-candidate-preview.marker");
  fs.writeFileSync(markerPath, "internal_candidate_review_only\n", "utf8");
}

function writeOfficeTest(runtimeRoot) {
  let source = fs.readFileSync(path.join(formalRuntimeRoot, "tests/office_integration_test.gd"), "utf8")
    .replace('get_root().add_child(office)\n\tawait process_frame', 'get_root().add_child(office)\n\tawait process_frame\n\tawait process_frame')
    .replace('var office = OfficeScene.instantiate()\n\tget_root().add_child(office)', 'var office = OfficeScene.instantiate()\n\toffice.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-full-candidates.json")\n\tget_root().add_child(office)')
    .replace('var presentation = office.player.find_child("原创灰盒角色外观", true, false)', 'var presentation = office.player.get_node_or_null("Visual") if office.player.get_node_or_null("Visual") != null else office.player.find_child("原创灰盒角色外观", true, false)')
		.replace('assert(office.find_child("办公桌", true, false) != null, "办公室缺少办公桌视觉")', 'assert(office.find_child("办公桌", true, false) != null, "办公室缺少办公桌视觉")\n\tassert(office.get_node_or_null("Visual/候选主管工位视觉") != null, "办公室候选缺少主管工位视觉")\n\tassert(office.get_node_or_null("Visual/候选主管工位视觉/主管显示器屏幕") != null, "办公室候选主管工位缺少显示器视觉")\n\tvar candidate_catalog_path := str(office.get_meta("asset_catalog_path", ""))\n\tif candidate_catalog_path.ends_with("asset-runtime-catalog-full-candidates.json"):\n\t\tassert(bool(office.get_meta("candidate_video_backdrop", false)), "完整候选办公室没有启用用户授权视频背景元数据")\n\t\tassert(str(office.get_meta("candidate_video_backdrop_id", "")) == "office-01", "完整候选办公室视频背景没有锁定 office-01")\n\t\tassert(bool(office.get_meta("candidate_gameplay_video_backdrop", false)), "完整候选办公室没有启用真实三维逻辑前景模式")\n\t\tvar office_video_backdrop := office.find_child("用户授权办公室视频帧候选背景卡", true, false) as MeshInstance3D\n\t\tassert(office_video_backdrop != null and office_video_backdrop.visible, "完整候选办公室没有加载可见视频背景卡")\n\t\tvar office_video_material := office_video_backdrop.material_override as StandardMaterial3D\n\t\tassert(office_video_material != null and office_video_material.albedo_texture != null, "完整候选办公室视频背景卡缺少材质纹理")\n\t\tassert(str(office_video_material.albedo_texture.resource_path).ends_with("office-01-video-playable-backdrop-v1.png"), "完整候选办公室没有绑定 office-01 授权视频帧")\n\t\tassert(str(office_video_backdrop.get_meta("asset_source", "")) == "user_authorized_ai_video_frame_edit", "完整候选办公室视频背景卡缺少资产来源标记")\n\t\tassert(str(office_video_backdrop.get_meta("rights_status", "")).contains("user_authorized_candidate_rights_pending_final_signoff"), "完整候选办公室视频背景卡缺少权利状态标记")\n\t\tassert(not office_video_material.no_depth_test, "完整候选办公室视频背景卡不得压住真实三维玩法前景")\n\tvar hidden_graybox_mesh_count := 0\n\tvar graybox_environment_root_names := ["灰盒地面", "灰盒隔断"]\n\tfor static_root in office.get_children():\n\t\tif not static_root is StaticBody3D or not graybox_environment_root_names.has(str(static_root.name)):\n\t\t\tcontinue\n\t\tfor mesh_node in static_root.find_children("*", "MeshInstance3D", true, false):\n\t\t\thidden_graybox_mesh_count += 1\n\t\t\tassert(not (mesh_node as MeshInstance3D).visible, "办公室候选接入后静态灰盒网格仍可见：" + str(mesh_node.get_path()))\n\tassert(hidden_graybox_mesh_count > 0, "办公室候选集成测试没有发现可验证的静态灰盒渲染层")');
  // 完整候选使用无深度测试的远景卡，再由真实三维前景覆盖；同步更新临时验收脚本的契约。
  source = source.replace('office_video_material.albedo_texture.resource_path', 'office_video_backdrop.get_meta("video_backdrop_texture_path", "")');
  source = source.replace('assert(not office_video_material.no_depth_test, "完整候选办公室视频背景卡不得压住真实三维玩法前景")', 'assert(office_video_material.no_depth_test, "完整候选办公室视频背景卡必须作为远景绘制，不能被环境墙遮住")');
  source = source.replace('print("办公室潜行端到端回放测试通过")', 'var candidate_catalog_path_after_replay := str(office.get_meta("asset_catalog_path", ""))\n\tif candidate_catalog_path_after_replay.ends_with("asset-runtime-catalog-full-candidates.json"):\n\t\toffice.set_meta("reference_capture_scenario", "office-01")\n\t\toffice.prepare_reference_capture(false)\n\t\tvar office_video_backdrop_after_replay := office.find_child("用户授权办公室视频帧候选背景卡", true, false) as MeshInstance3D\n\t\tassert(office_video_backdrop_after_replay != null and office_video_backdrop_after_replay.visible, "办公室正式采集冻结后视频背景卡被错误隐藏")\n\tprint("办公室潜行端到端回放测试通过")');
  if (characterVariant === "makehuman") {
    source = source.replace(
      'assert(hidden_graybox_mesh_count > 0, "办公室候选集成测试没有发现可验证的静态灰盒渲染层")',
      'assert(hidden_graybox_mesh_count > 0, "办公室候选集成测试没有发现可验证的静态灰盒渲染层")\n\tvar candidate_desks: Array[Node] = []\n\tfor candidate_node in office.get_node("Visual").find_children("*", "StaticBody3D", true, false):\n\t\tvar candidate_script: Script = candidate_node.get_script()\n\t\tif candidate_script != null and str(candidate_script.resource_path).ends_with("office_desk_candidate.gd"):\n\t\t\tcandidate_desks.append(candidate_node)\n\tassert(candidate_desks.size() == 10, "办公室候选真实工位数量不是 10：%d" % candidate_desks.size())\n\tfor candidate_desk in candidate_desks:\n\t\tvar real_desk_geometry := candidate_desk.get_node_or_null("Geometry")\n\t\tassert(real_desk_geometry != null and real_desk_geometry.visible, "办公室候选隐藏了真实 Poly Haven 桌体：" + str(candidate_desk.get_path()))',
    );
  }
  if (["original", "original_only"].includes(characterVariant)) {
    source = source.replace("\tawait process_frame\n\toffice.save_store.save_path", "\tawait process_frame\n\t_verify_original_office_desk_contract(office)\n\toffice.save_store.save_path");
    source += `\n\nfunc _verify_original_office_desk_contract(office_root: Node) -> void:\n\tvar visual: Node = office_root.get_node_or_null("Visual")\n\tassert(visual != null, "原创候选办公室缺少 Visual 根节点")\n\tvar desks := visual.find_children("*", "StaticBody3D", true, false)\n\tassert(desks.size() == 10, "原创候选办公室工位数量不是 10：%d" % desks.size())\n\tfor desk in desks:\n\t\tvar desk_script: Script = desk.get_script()\n\t\tassert(desk_script != null and str(desk_script.resource_path).ends_with("original_office_desk_candidate.gd"), "原创角色候选包检测到非原创办公桌脚本：" + str(desk.get_path()))\n\t\tassert(desk.get_node_or_null("近似碰撞体") is CollisionShape3D, "原创办公桌缺少近似碰撞体：" + str(desk.get_path()))\n\t\tassert(desk.get_node_or_null("交互挂点") is Marker3D, "原创办公桌缺少交互挂点：" + str(desk.get_path()))\n\t\tassert(desk.get_node_or_null("显示器挂点") is Marker3D, "原创办公桌缺少显示器挂点：" + str(desk.get_path()))\n\t\tassert(desk.find_children("原创显示器屏幕", "MeshInstance3D", true, false).size() == 1, "原创办公桌缺少显示器屏幕：" + str(desk.get_path()))\n\tvar npc_visual: Node = office_root.npc.get_node_or_null("Visual")\n\tassert(npc_visual != null, "原创候选办公室缺少 NPC Visual 根节点")\n\tvar npc_script: Script = npc_visual.get_script()\n\tassert(npc_script != null and str(npc_script.resource_path).ends_with("original_office_npc_candidate.gd"), "原创候选办公室 NPC 没有使用原创程序化脚本")\n\tfor mount_name in ["视线起点", "搜索目标点", "警觉标记点", "脚底碰撞参考点"]:\n\t\tassert(npc_visual.get_node_or_null(mount_name) is Marker3D, "原创候选办公室 NPC 缺少挂点：" + mount_name)\n\tvar npc_player: AnimationPlayer = npc_visual.get_node_or_null("AnimationPlayer") as AnimationPlayer\n\tassert(npc_player != null, "原创候选办公室 NPC 缺少 AnimationPlayer")\n\tfor animation_name in ["idle_default", "walk_default", "search_default", "alert_default"]:\n\t\tassert(npc_player.has_animation(animation_name), "原创候选办公室 NPC 缺少动画状态：" + animation_name)\n\t\tassert(npc_player.get_animation(animation_name).get_track_count() > 0, "原创候选办公室 NPC 动画没有真实轨道：" + animation_name)\n`;
    source = source.replace(
      '\t\tassert(npc_player.get_animation(animation_name).get_track_count() > 0, "原创候选办公室 NPC 动画没有真实轨道：" + animation_name)\n',
      '\t\tassert(npc_player.get_animation(animation_name).get_track_count() > 0, "原创候选办公室 NPC 动画没有真实轨道：" + animation_name)\n\tassert(npc_visual.find_child("候选NPC搜索状态灯", true, false) != null, "原创候选办公室 NPC 缺少搜索状态视觉层")\n\tassert(npc_visual.find_child("候选NPC警觉状态灯", true, false) != null, "原创候选办公室 NPC 缺少警觉状态视觉层")\n',
    );
    source = source.replace(
      'assert(npc_visual.find_child("候选NPC搜索状态灯", true, false) != null, "原创候选办公室 NPC 缺少搜索状态视觉层")',
      'assert(npc_visual.find_child("候选NPC搜索状态灯", true, false) != null, "原创候选办公室 NPC 缺少搜索状态视觉层")\n\tassert(npc_visual.get_node_or_null("候选NPC表现根") != null, "原创候选办公室 NPC 缺少统一表现根节点")\n\tassert(str(npc_player.get_animation("search_default").track_get_path(0)).begins_with("候选NPC表现根/"), "原创候选办公室 NPC 搜索动画没有驱动统一表现根节点")',
    );
  }
  if (characterVariant === "original_only") {
    source = source.replace(
      'assert(visual != null, "原创候选办公室缺少 Visual 根节点")',
      'assert(visual != null, "原创候选办公室缺少 Visual 根节点")\n\tvar elevator_card: MeshInstance3D = office_root.find_child("原创办公室电梯厅写实背景卡", true, false) as MeshInstance3D\n\tassert(elevator_card != null and elevator_card.visible, "原创边界办公室缺少可见电梯厅背景卡")\n\tvar elevator_material: StandardMaterial3D = elevator_card.material_override as StandardMaterial3D\n\tassert(elevator_material != null and elevator_material.albedo_texture != null, "原创边界办公室电梯厅背景卡缺少材质")\n\tassert(str(elevator_material.albedo_texture.resource_path).ends_with("office_elevator_lobby_v2_generated.png"), "原创边界办公室没有绑定 v2 电梯厅纹理")',
    );
  }
  if (characterVariant === "makehuman") {
    source = source.replace(
      'assert(presentation != null, "办公室缺少角色表现节点")',
      `assert(presentation != null, "办公室缺少角色表现节点")
	if str(presentation.get_script().resource_path).ends_with("makehuman_player_visual_candidate.gd"):
		var candidate_environment := office.get_node_or_null("Visual")
		assert(candidate_environment != null, "MakeHuman 候选办公室缺少环境 Visual 根节点")
		var center_workstation_found := false
		for candidate_workstation in candidate_environment.find_children("*", "Node3D", true, false):
			if str(candidate_workstation.get_meta("candidate_workstation_role", "")) == "office_10_center":
				center_workstation_found = true
				break
		assert(center_workstation_found, "MakeHuman 候选办公室缺少与正式 office-10 坐标对齐的中心工位")
		var makehuman_animation := presentation.get_node_or_null("AnimationPlayer") as AnimationPlayer
		assert(makehuman_animation != null and makehuman_animation.has_animation("typing_default"), "MakeHuman 主角候选缺少 typing_default 动画状态")
		var makehuman_body := presentation.get_node_or_null("候选主角身体") as Node3D
		var makehuman_skeleton_nodes := makehuman_body.find_children("*", "Skeleton3D", true, false) if makehuman_body != null else []
		assert(makehuman_skeleton_nodes.size() > 0, "MakeHuman 主角候选缺少 Skeleton3D")
		var makehuman_skeleton := makehuman_skeleton_nodes[0] as Skeleton3D
		for makehuman_bone_name in ["hand_l", "hand_r", "index_01_l", "index_02_l", "index_03_l", "index_01_r", "index_02_r", "index_03_r"]:
			assert(makehuman_skeleton.find_bone(makehuman_bone_name) >= 0, "MakeHuman 打字接触骨骼缺失：" + makehuman_bone_name)
		# 接触契约必须走正式的“靠近工位 -> 交互 -> 进入打字”路径；不能
		# 直接把玩家摆到一个脱离正式状态机的镜头坐标，否则会把站位差
		# 误报成骨骼接触失败，也无法证明玩家实际游玩时会落到同一工位。
		var center_workstation: Node3D = office.workstation_targets[1] as Node3D
		office.player.global_position = center_workstation.global_position
		var typing_input := InputFrameClass.new()
		typing_input.interact = true
		office.process_input_frame(typing_input, 0.016)
		assert(office.typing_mode, "MakeHuman 候选办公室没有通过正式工位交互进入打字状态")
		await process_frame
		presentation.drive_candidate_state("typing_default")
		presentation.call("_process", 0.18)
		assert(makehuman_animation.current_animation == "typing_default", "MakeHuman 主角候选没有进入 typing_default")
		var typing_body := presentation.get_node_or_null("候选主角身体") as Node3D
		assert(typing_body != null and is_equal_approx(typing_body.position.y, -0.70), "MakeHuman typing_default 表现层仍未回收过度下沉：%s" % (typing_body.position.y if typing_body != null else "缺失"))
		var left_hand_index := makehuman_skeleton.find_bone("hand_l")
		var right_hand_index := makehuman_skeleton.find_bone("hand_r")
		var left_hand_pose := makehuman_skeleton.get_bone_pose_rotation(left_hand_index)
		var right_hand_pose := makehuman_skeleton.get_bone_pose_rotation(right_hand_index)
		assert(absf(left_hand_pose.x) + absf(left_hand_pose.z) > 0.01, "MakeHuman 左腕没有应用打字下压姿态")
		assert(absf(right_hand_pose.x) + absf(right_hand_pose.z) > 0.01, "MakeHuman 右腕没有应用打字下压姿态")`
				+ `
		for makehuman_contact_name in ["候选打字骨盆接触点", "候选打字左手接触点", "候选打字右手接触点"]:
			assert(presentation.find_child(makehuman_contact_name, true, false) != null, "MakeHuman 打字接触探针缺失：" + makehuman_contact_name)
		var left_contact := presentation.find_child("候选打字左手接触点", true, false) as Node3D
		var right_contact := presentation.find_child("候选打字右手接触点", true, false) as Node3D
		var pelvis_contact := presentation.find_child("候选打字骨盆接触点", true, false) as Node3D
		assert(left_contact.visible == false and right_contact.visible == false and pelvis_contact.visible == false, "MakeHuman 打字接触探针不得污染候选画面")
		assert(left_contact.get_meta("candidate_contact_probe", false) and right_contact.get_meta("candidate_contact_probe", false) and pelvis_contact.get_meta("candidate_contact_probe", false), "MakeHuman 打字接触探针缺少候选标记")
		assert(left_contact.get_meta("contact_kind", "") == "keyboard_hand_proxy" and right_contact.get_meta("contact_kind", "") == "keyboard_hand_proxy", "MakeHuman 手腕接触探针类型错误")
		assert(pelvis_contact.get_meta("contact_kind", "") == "seat_surface_proxy", "MakeHuman 骨盆接触探针没有使用座面代理")
		var keyboard_nodes := office.find_children("键盘", "MeshInstance3D", true, false)
		assert(keyboard_nodes.size() > 0, "MakeHuman 打字接触回放没有找到候选键盘")
		var nearest_keyboard := keyboard_nodes[0] as Node3D
		var nearest_left_keyboard := nearest_keyboard
		var nearest_right_keyboard := nearest_keyboard
		var left_keyboard_distance := left_contact.global_position.distance_to(nearest_keyboard.global_position)
		var right_keyboard_distance := right_contact.global_position.distance_to(nearest_keyboard.global_position)
		for keyboard_node in keyboard_nodes:
			var candidate_keyboard := keyboard_node as Node3D
			var candidate_left_distance := left_contact.global_position.distance_to(candidate_keyboard.global_position)
			var candidate_right_distance := right_contact.global_position.distance_to(candidate_keyboard.global_position)
			if candidate_left_distance < left_keyboard_distance:
				left_keyboard_distance = candidate_left_distance
				nearest_left_keyboard = candidate_keyboard
			if candidate_right_distance < right_keyboard_distance:
				right_keyboard_distance = candidate_right_distance
				nearest_right_keyboard = candidate_keyboard
		assert(left_keyboard_distance < 1.35, "MakeHuman 左手腕距离最近键盘过远：%f 手=%s 键盘=%s" % [left_keyboard_distance, left_contact.global_position, nearest_left_keyboard.global_position])
		assert(right_keyboard_distance < 1.35, "MakeHuman 右手腕距离最近键盘过远：%f 手=%s 键盘=%s" % [right_keyboard_distance, right_contact.global_position, nearest_right_keyboard.global_position])
		var chair_nodes := office.find_children("椅子座面", "MeshInstance3D", true, false)
		assert(chair_nodes.size() > 0, "MakeHuman 坐姿接触回放没有找到候选椅面")
		var nearest_chair := chair_nodes[0] as Node3D
		var pelvis_chair_distance := pelvis_contact.global_position.distance_to(nearest_chair.global_position)
		for chair_node in chair_nodes:
			var candidate_chair := chair_node as Node3D
			pelvis_chair_distance = minf(pelvis_chair_distance, pelvis_contact.global_position.distance_to(candidate_chair.global_position))
		assert(pelvis_chair_distance < 1.35, "MakeHuman 骨盆接触代理距离最近椅面过远：%f 骨盆=%s 椅面=%s" % [pelvis_chair_distance, pelvis_contact.global_position, nearest_chair.global_position])
		print("MakeHuman 打字接触距离：左手=%f 右手=%f 骨盆=%f" % [left_keyboard_distance, right_keyboard_distance, pelvis_chair_distance])
	var makehuman_typing_exit := InputFrameClass.new()
	office.process_input_frame(InputFrameClass.new(), 0.016)
	makehuman_typing_exit.interact = true
	office.process_input_frame(makehuman_typing_exit, 0.016)
	assert(not office.typing_mode, "MakeHuman 专项坐姿回放退出失败，无法继续通用交互回归")
	office.process_input_frame(InputFrameClass.new(), 0.016)
	# MakeHuman 专项回放包含驾驶、存档和接触验证；通用办公室回归需要独立
	# 回到 17:59 起点，避免专项回放累计的模拟分钟污染准点下班断言。
	office.mission.restart()
	office.time_accumulator = 0.0
	office.perception.reset()`
    );
  }
  fs.writeFileSync(path.join(runtimeRoot, "tests/full_candidate_office_integration_test.gd"), source, "utf8");
}

function writeCityTest(runtimeRoot, catalogPath) {
  if (characterVariant === "original_only") {
    const source = `extends SceneTree

const CityScene := preload("res://scenes/city.tscn")
const AssetRuntimeCatalogClass := preload("res://scripts/asset_runtime_catalog.gd")
const MissionChainClass := preload("res://scripts/mission_chain.gd")

func _init() -> void:
\tcall_deferred("_run")

func _run() -> void:
\tvar catalog_path := "${catalogPath}"
\tvar catalog := AssetRuntimeCatalogClass.load_json(catalog_path)
\tassert(AssetRuntimeCatalogClass.validate(catalog).is_empty(), "原创边界城市目录契约校验失败")
\tfor slot in catalog.get("slots", []):
\t\tvar active_path := str(slot.get("scene_path", ""))
\t\tif active_path.is_empty():
\t\t\tcontinue
\t\tassert(not active_path.to_lower().contains("makehuman"), "原创边界城市仍挂载 MakeHuman 路径：" + active_path)
\t\tassert(not active_path.to_lower().contains("quaternius"), "原创边界城市仍挂载 Quaternius 路径：" + active_path)
\tvar city = CityScene.instantiate()
\tcity.set_meta("asset_catalog_path", catalog_path)
\tcity.set_meta("settings_path", OS.get_temp_dir().path_join("original-only-city-%d.json" % Time.get_ticks_usec()))
\tget_root().add_child(city)
\tawait process_frame
\tawait process_frame
\tassert(city.initialized, "原创边界城市没有完成初始化")
\tassert(city.mission.status == MissionChainClass.Status.ACTIVE, "原创边界城市任务没有保持 ACTIVE")
\tvar player_visual: Node = city.player.get_node_or_null("Visual")
\tassert(player_visual != null, "原创边界城市没有挂载主角 Visual")
\tassert(str(player_visual.get_script().resource_path).ends_with("original_player_candidate.gd"), "原创边界城市主角不是程序化原创脚本")
\tfor player_detail_name in ["候选主角连帽外壳", "候选主角肩部夹克-左", "候选主角背包侧袋-左", "候选主角工装裤袋-左", "候选主角鞋面侧条-左"]:
\t\tassert(player_visual.find_child(player_detail_name, true, false) != null, "原创边界城市主角缺少细节节点：" + player_detail_name)
\tassert(city.player.get_node_or_null("原创灰盒角色外观") == null, "原创边界城市仍存在主角灰盒回退")
\tvar environment: Node = city.get_node_or_null("Visual")
\tassert(environment != null, "原创边界城市没有挂载环境 Visual")
\tassert(str(environment.get_script().resource_path).ends_with("original_only_city_environment_candidate.gd"), "原创边界城市环境不是原创边界脚本")
\tfor node_name in ["候选原创小型城市楼", "候选原创中型城市楼", "候选原创大型城市楼", "原创城市驾驶街道背景卡", "原创城市终点傍晚街道背景卡", "原创店铺遮雨棚", "原创城市标识-新鲜集市", "原创后场安全警示条", "原创城市标识-装卸区", "原创街区信号灯灯头-左", "原创街区信号灯红灯-左", "原创街区人行提示牌-右"]:
\t\tassert(environment.find_child(node_name, true, false) != null, "原创边界城市缺少视觉节点：" + node_name)
\tvar signal_red := environment.find_child("原创街区信号灯红灯-左", true, false) as Node3D
\tvar signal_amber := environment.find_child("原创街区信号灯黄灯-左", true, false) as Node3D
\tvar signal_green := environment.find_child("原创街区信号灯绿灯-左", true, false) as Node3D
\tassert(signal_red != null and signal_amber != null and signal_green != null, "原创边界城市信号灯缺少三色节点")
\tenvironment.call("drive_visual_signal_phase", 6.4)
\tassert(not signal_red.visible and signal_amber.visible and not signal_green.visible, "原创边界城市信号灯黄灯阶段没有正确切换")
\tenvironment.call("drive_visual_signal_phase", 8.0)
\tassert(signal_red.visible and not signal_amber.visible and not signal_green.visible, "原创边界城市信号灯红灯阶段没有正确切换")
\tassert(environment.find_children("*", "CollisionObject3D", true, false).is_empty(), "原创边界城市环境不得创建碰撞对象")
\tvar vehicle_visual: Node = city.vehicle.get_node_or_null("Visual")
\tassert(vehicle_visual != null, "原创边界城市没有挂载载具 Visual")
\tvar vehicle_script_path := str(vehicle_visual.get_script().resource_path)
\tassert(vehicle_script_path.ends_with("original_city_vehicle_candidate.gd") or vehicle_script_path.ends_with("three_wheel_delivery_atlas_candidate.gd"), "原创边界城市载具不是原创程序化包装")
\tassert(bool(vehicle_visual.get_meta("original_procedural_asset", false)), "原创边界城市载具缺少原创程序化资产标记")
\tassert(vehicle_visual.find_child("ThreeWheelDelivery", true, false) != null, "原创边界城市缺少三轮车网格")
\tvar contact_shadows: Array[Node] = vehicle_visual.find_children("候选三轮车软接触阴影-*", "MeshInstance3D", true, false)
\tassert(contact_shadows.size() == 3, "原创边界城市三轮车缺少三处轮胎软接触阴影")
\tfor contact_shadow in contact_shadows:
\t\tassert(bool(contact_shadow.get_meta("ground_contact_visual", false)), "原创边界城市三轮车接触阴影缺少视觉标记")
\t\tassert(bool(contact_shadow.get_meta("visual_only", false)), "原创边界城市三轮车接触阴影不得携带逻辑")
\tfor vehicle_detail_name in ["候选三轮车损伤刮痕-左", "候选三轮车损伤刮痕-右", "候选三轮车损伤警示灯"]:
\t\tassert(vehicle_visual.find_child(vehicle_detail_name, true, false) != null, "原创边界城市三轮车缺少分级损伤视觉节点：" + vehicle_detail_name)
\tfor pedestrian in city.pedestrians:
\t\tvar crowd_visual: Node = pedestrian.get_node_or_null("Visual")
\t\tassert(crowd_visual != null, "原创边界城市行人缺少 Visual")
\t\tassert(str(crowd_visual.get_script().resource_path).ends_with("original_procedural_city_crowd_candidate.gd"), "原创边界城市行人不是程序化原创脚本")
\t\tassert(crowd_visual.get_node_or_null("AnimationPlayer") != null, "原创边界城市行人缺少 AnimationPlayer")
\t\tassert(crowd_visual.get_node("AnimationPlayer").current_animation == "walk_default", "原创边界城市行人没有进入行走状态")
\t\tassert(crowd_visual.find_child("候选人群视觉配件", true, false) != null, "原创边界城市行人缺少视觉配件层")
\t\tassert(crowd_visual.find_child("人群上衣领口", true, false) != null, "原创边界城市行人缺少服装轮廓细节")
\t\tfor crowd_detail_name in ["人群外套下摆", "人群裤腰边线", "人群左鞋面高光", "人群左鞋带", "人群左肩缝线", "人群左眼", "人群眉线-左"]:
\t\t\tassert(crowd_visual.find_child(crowd_detail_name, true, false) != null, "原创边界城市行人缺少身体轮廓细节：" + crowd_detail_name)
\t\tfor crowd_mesh in crowd_visual.find_children("*", "MeshInstance3D", true, false):
\t\t\tassert(bool(crowd_mesh.get_meta("visual_only", false)), "原创边界城市行人网格缺少 visual_only 标记：" + str(crowd_mesh.name))
\t\t\tassert(bool(crowd_mesh.get_meta("candidate_visual_only", false)), "原创边界城市行人网格缺少 candidate_visual_only 标记：" + str(crowd_mesh.name))
\tassert(str(city.conflict_agent.get_node("Visual").get_script().resource_path).ends_with("original_procedural_city_crowd_candidate.gd"), "原创边界城市冲突对象不是程序化原创脚本")
\tvar interaction_visual: Node = city.get_node_or_null("交互道具层/Visual")
\tassert(interaction_visual != null, "原创边界城市缺少交互道具层")
\tassert(str(interaction_visual.get_script().resource_path).ends_with("original_interaction_props_candidate.gd"), "原创边界城市交互道具不是程序化原创脚本")
\tfor interaction_detail_name in ["候选鸡蛋货架", "候选扫码台", "候选配送标记", "候选购物篮"]:
\t\tassert(interaction_visual.find_child(interaction_detail_name, true, false) != null, "原创边界城市交互道具缺少视觉节点：" + interaction_detail_name)
\tvar start_position: Vector3 = city.pedestrians[0].global_position
\tcity.pedestrians[0]._physics_process(1.0)
\tassert(city.pedestrians[0].global_position.distance_to(start_position) > 0.1, "原创边界城市行人路线逻辑没有继续运行")
\tprint("原创边界城市候选通过：主角、人群、环境、载具和交互层均未挂载 MakeHuman/Quaternius 活跃路径")
\tquit(0)
`;
    fs.writeFileSync(path.join(runtimeRoot, "tests/full_candidate_city_integration_test.gd"), source, "utf8");
    return;
  }
  let source = fs.readFileSync(path.join(candidateRoot, "../city-full-kit-candidate/city_full_kit_runtime_integration_test.gd"), "utf8")
    .replace(/\tvar candidate_root :=[\s\S]*?\n\tvar catalog :=/, `\tvar catalog_path := ProjectSettings.globalize_path("${catalogPath}")\n\tvar catalog :=`);
  if (characterVariant === "original") {
    source = source
      .replace('assert(str(city.player.get_node("Visual").get_script().resource_path).contains("player_character_visual_candidate.gd"), "城市玩家没有挂载独立城市视觉候选脚本")\n\t\tvar city_jacket := city.player.get_node("Visual").find_child("原创夹克肩部", true, false) as MeshInstance3D\n\t\tassert(city_jacket != null, "城市玩家候选缺少夹克肩部视觉节点")\n\t\tvar city_jacket_material := city_jacket.material_override as StandardMaterial3D\n\t\tassert(city_jacket_material != null, "城市玩家候选夹克没有材质覆盖")\n\t\tassert(city_jacket_material.albedo_color.r > city_jacket_material.albedo_color.g * 1.6 and city_jacket_material.albedo_color.r > city_jacket_material.albedo_color.b * 1.6, "城市玩家候选夹克没有形成参考帧砖红识别色")', 'assert(str(city.player.get_node("Visual").get_script().resource_path).ends_with("original_player_candidate.gd"), "城市玩家没有挂载原创程序化视觉候选脚本")\n\t\tassert(city.player.get_node("Visual").find_child("候选主角背包", true, false) != null, "原创城市玩家缺少背包视觉节点")');
  }
  fs.writeFileSync(path.join(runtimeRoot, "tests/full_candidate_city_integration_test.gd"), source, "utf8");
}

function writeAudioTest(runtimeRoot) {
  fs.writeFileSync(path.join(runtimeRoot, "tests/audio_candidate_runtime_test.gd"), `extends SceneTree

func _init() -> void:
\tcall_deferred("_run")

func _run() -> void:
\tvar file := FileAccess.open("res://content/audio-runtime-catalog.json", FileAccess.READ)
\tassert(file != null, "完整候选包缺少音频运行时目录")
\tvar payload = JSON.parse_string(file.get_as_text())
\tassert(payload is Dictionary, "完整候选包音频运行时目录格式无效")
\tvar events = payload.get("events", [])
\tvar cue_file := FileAccess.open("res://content/audio_cues.json", FileAccess.READ)
\tassert(cue_file != null, "完整候选包缺少音频提示音目录")
\tvar cue_payload = JSON.parse_string(cue_file.get_as_text())
\tvar cues = cue_payload.get("cues", []) if cue_payload is Dictionary else []
\tassert(events is Array and cues is Array and events.size() == cues.size() and events.size() > 0, "完整候选包音频事件数量必须与提示音目录一致")
\tfor event in events:
\t\tassert(str(event.get("fallback_policy", "")) == "forbid", "完整候选包音频事件不得静默回退：" + str(event.get("id", "")))
\t\tvar stream_path := str(event.get("stream_path", ""))
\t\tassert(ResourceLoader.exists(stream_path), "完整候选包音频资源不存在：" + stream_path)
\t\tassert(load(stream_path) is AudioStream, "完整候选包音频资源不是 AudioStream：" + stream_path)
\tprint("完整候选包 %d 个音频资源已加载，音频目录禁止静默回退" % events.size())
\tquit(0)
`, "utf8");
}

function writeMovieCaptureTests(runtimeRoot) {
  copyFiles(candidateRoot, path.join(runtimeRoot, "tests"), [
    "capture_movie_candidate_office.gd",
    "capture_movie_candidate_office_detail.gd",
    "capture_movie_candidate_office_npc.gd",
    "capture_movie_candidate_city.gd",
    "capture_movie_candidate_city_crowd.gd",
    "capture_movie_candidate_vehicle_detail.gd",
  ]);
  if (!originalOnly) {
    copyFiles(
      path.join(workspaceRoot, "art-source/characters/makehuman-office-player"),
      path.join(runtimeRoot, "tests"),
      ["capture_makehuman_office_typing.gd"],
    );
  }
}

function pruneOriginalOnlyCandidateNoise(runtimeRoot) {
  if (!originalOnly) return;
  for (const relativePath of [
    "tests/city_environment_quaternius_candidate.gd",
    "tests/city_environment_quaternius_candidate.tscn",
    "tests/inspect_quaternius_candidate.gd",
    "tests/makehuman_animation_contract.gd",
  ]) {
    fs.rmSync(path.join(runtimeRoot, relativePath), {force: true});
    fs.rmSync(path.join(runtimeRoot, `${relativePath}.uid`), {force: true});
  }
  // 预检阶段会生成正式运行时的导入缓存。首次启动时，候选场景会在导入完成前
  // preload 纹理和模型；如果把整个 .godot 删除，原创边界包在新机器上会直接
  // 进入“资源不存在”分支。这里仅保留包内实际存在的二进制资源对应缓存，
  // 不携带正式运行时中与第三方资源有关的缓存。
  const importedRoot = path.join(runtimeRoot, ".godot/imported");
  const sourceBasenames = new Set();
  const collectAssetBasenames = (directory) => {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      if (entry.name === ".godot") continue;
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        collectAssetBasenames(absolutePath);
        continue;
      }
      if (!/[.](png|jpe?g|webp|glb|gltf|wav|ogg|mp3|flac)$/i.test(entry.name)) continue;
      sourceBasenames.add(entry.name);
    }
  };
  collectAssetBasenames(runtimeRoot);
  if (fs.existsSync(importedRoot)) {
    for (const entry of fs.readdirSync(importedRoot)) {
      if (!Array.from(sourceBasenames).some((basename) => entry.startsWith(`${basename}-`))) {
        fs.rmSync(path.join(importedRoot, entry), {recursive: true, force: true});
      }
    }
  }
  const godotRoot = path.join(runtimeRoot, ".godot");
  if (fs.existsSync(godotRoot)) {
    for (const entry of fs.readdirSync(godotRoot)) {
      if (entry !== "imported" && entry !== "global_script_class_cache.cfg") {
        fs.rmSync(path.join(godotRoot, entry), {recursive: true, force: true});
      }
    }
  }
}

function runGodot(runtimeRoot, args, label, extraEnv = {}) {
  const logPath = path.join(runtimeRoot, "full-candidate-preflight.log");
  const importWarmupRetryLimit = label.includes("资源导入预热") ? 2 : 1;
  for (let attempt = 1; attempt <= importWarmupRetryLimit; attempt += 1) {
    try {
      const result = spawnSync(godotBinary, [
        "--headless", "--single-threaded-scene", "--path", runtimeRoot,
        "--quit-after", "120",
        "--audio-driver", "Dummy",
        "--rendering-driver", "opengl3",
        "--rendering-method", "gl_compatibility",
        "--log-file", logPath,
        ...args,
      ], {cwd: workspaceRoot, env: {...process.env, ...extraEnv, P0_EMBEDDED: "1", REFERENCE_ASSET_PREVIEW: "1"}, stdio: ["ignore", "pipe", "pipe"], timeout: 600000, killSignal: "SIGTERM", encoding: "utf8"});
      const output = `${result.stdout || ""}\n${result.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
      const filtered = output.split(/\r?\n/).filter((line) => {
        if (line.includes("get_system_ca_certificates") || line.includes('ERROR: Condition "ret != noErr" is true.')) return false;
        if (args.includes("--editor") && (line.includes("Cannot save file") || line.includes("Error saving editor settings to"))) return false;
        return true;
      }).join("\n");
      if (result.error) throw new Error(`${label}失败：${result.error.message}`);
      if (result.status !== 0 || /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
        if (["SIGSEGV", "SIGABRT"].includes(result.signal) && attempt < importWarmupRetryLimit) {
          console.warn(`${label}第一次导入进程收到 ${result.signal}，清理隔离用户目录后重试一次`);
          continue;
        }
        const errors = filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-18);
        const detail = errors.length > 0 ? errors.join(" | ") : filtered.trim().slice(-1200);
        throw new Error(`${label}失败：退出码 ${result.status ?? "null"}，信号 ${result.signal ?? "none"}；${detail}`);
      }
      return;
    } finally {}
  }
}

function launch(runtimeRoot) {
  const result = spawnSync(godotBinary, [
    "--display-driver", "macos",
    "--rendering-driver", "opengl3",
    "--rendering-method", "gl_compatibility",
    "--single-window",
    "--windowed",
    "--resolution", "1280x720",
    "--path", runtimeRoot,
    "--scene", "res://scenes/launcher.tscn",
    "--log-file", "/tmp/xinjieyuanjuexing-full-candidate-playtest.log",
  ], {
      cwd: workspaceRoot,
      env: {...process.env, REFERENCE_ASSET_PREVIEW: "1", P0_EMBEDDED: "1"},
      stdio: "inherit",
    });
  if (result.error) throw new Error(`统一候选试玩启动失败：${result.error.message}`);
  if (result.status !== 0) throw new Error(`统一候选试玩退出码异常：${result.status}`);
}

if (persistentOutput != null) {
  assertSafePersistentOutput(persistentOutput);
  fs.rmSync(persistentOutput, {recursive: true, force: true});
  fs.mkdirSync(persistentOutput, {recursive: true});
}
const temporaryRoot = persistentOutput ?? fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-full-candidate-"));
try {
  fs.cpSync(formalRuntimeRoot, temporaryRoot, {recursive: true, filter: copyFilter});
  copyRuntimeClassCache(temporaryRoot);
  copyCandidateAssets(temporaryRoot);
  const catalogPath = writeMergedCatalog(temporaryRoot);
  const audioCatalogPath = writeCandidateAudioCatalog(temporaryRoot);
  const audioCueCatalog = JSON.parse(fs.readFileSync(path.join(temporaryRoot, "content/audio_cues.json"), "utf8"));
  const audioEventCount = Array.isArray(audioCueCatalog.cues) ? audioCueCatalog.cues.length : 0;
  patchCandidateCaptureScripts(temporaryRoot);
  writeLaunchProfile(temporaryRoot, catalogPath);
  writeCandidateLaunchMarker(temporaryRoot);
  writeOfficeTest(temporaryRoot);
  writeCityTest(temporaryRoot, catalogPath);
  writeAudioTest(temporaryRoot);
  writeMovieCaptureTests(temporaryRoot);
  runGodot(temporaryRoot, ["--editor", "--import", "--quit"], "统一候选试玩资源导入预热");
  const environment = {REFERENCE_ASSET_CATALOG_PATH: catalogPath, P0_EMBEDDED: "1"};
  runGodot(temporaryRoot, ["-s", "res://tests/full_candidate_office_integration_test.gd"], "统一候选办公室回放", environment);
  runGodot(temporaryRoot, ["-s", "res://tests/full_candidate_city_integration_test.gd"], "统一候选城市回放", environment);
  runGodot(temporaryRoot, ["-s", "res://tests/audio_candidate_runtime_test.gd"], "统一候选音频资源回放", environment);
  pruneOriginalOnlyCandidateNoise(temporaryRoot);
  const evidence = {
    schema_version: 1,
    status: "candidate_isolated_full_playtest_verified",
    source: {root: "temporary copy of gta-reference-runtime", sha256: currentSource.sha256, file_count: currentSource.file_count, catalog_path: catalogPath, asset_fallback_policy: "forbid"},
    character_variant: characterVariant,
    active_candidate_ids: [
      ["original", "original_only"].includes(characterVariant) ? "player-character-p0-procedural-candidate" : "player-character-makehuman-elegant-suit-atlas-candidate",
      ["original", "original_only"].includes(characterVariant) ? "office-npc-p0-procedural-candidate" : "office-npc-makehuman-elegant-suit-skinned-512-atlas-candidate",
      characterVariant === "original_only" ? "city-crowd-original-procedural-v1-candidate" : "city-crowd-makehuman-elegant-suit-atlas-candidate",
      "city-vehicle-three-wheel-delivery-final-procedural-candidate",
      characterVariant === "original_only" ? "city-environment-original-only-procedural-v1-candidate" : "city-environment-original-procedural-v3-candidate",
      ["original", "original_only"].includes(characterVariant) ? "office-environment-original-procedural-v1-candidate" : "office-desk-polyhaven-metal-cc0-candidate",
      "interaction-props-original-kit-candidate",
    ],
    active_candidate_slots: Object.fromEntries(
      JSON.parse(fs.readFileSync(path.join(temporaryRoot, "tests/asset-runtime-catalog-full-candidates.json"), "utf8"))
        .slots
        .filter((slot) => slot.scene_path)
        .map((slot) => [slot.id, slot.scene_path]),
    ),
    entries: ["office-candidate", "city-candidate", "city-market-candidate"],
    audio_catalog_path: audioCatalogPath,
    checks: ["统一启动器入口", "办公室候选资产挂载与完整行为回放", ...(characterVariant === "makehuman" ? ["MakeHuman 打字状态的腕部与指节骨骼契约"] : []), "城市候选资产挂载与完整行为回放", "原创交互道具禁止灰盒回退", `${audioEventCount} 个音频资源禁止静默回退`, "任务、镜头、NPC、载具、存档和交互链路"],
    visual_status: "unverified",
    release_allowed: false,
    generated_at: new Date().toISOString(),
  };
  fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  if (persistentOutput != null) {
    const packageManifest = writePersistentPackageContract(temporaryRoot, currentSource);
    console.log(`完整候选运行包已保留：${packageManifest.package.root}；${packageManifest.package.file_count} 个文件；包指纹 ${packageManifest.package.sha256}`);
  }
  if (preflightOnly) {
    console.log("统一候选试玩预检通过：办公室与城市入口、候选资产挂载和完整行为回放均通过；视觉仍为 unverified");
  } else {
    console.log("统一候选试玩即将启动；关闭 Godot 窗口后自动清理临时运行时副本");
    launch(temporaryRoot);
  }
} catch (error) {
  const failure = {schema_version: 1, status: "candidate_isolated_full_playtest_failed", visual_status: "unverified", release_allowed: false, failure: String(error?.message || error), generated_at: new Date().toISOString()};
  fs.writeFileSync(evidencePath, `${JSON.stringify(failure, null, 2)}\n`, "utf8");
  throw error;
} finally {
  if (persistentOutput == null) fs.rmSync(temporaryRoot, {recursive: true, force: true});
}

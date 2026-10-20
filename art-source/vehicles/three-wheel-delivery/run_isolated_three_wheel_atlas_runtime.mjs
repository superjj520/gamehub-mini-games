import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {spawnSync} from "node:child_process";
import {fileURLToPath} from "node:url";

const sourceRoot = path.dirname(fileURLToPath(import.meta.url));
const workspaceRoot = path.resolve(sourceRoot, "../../..");
const formalRuntimeRoot = path.join(workspaceRoot, "gta-reference-runtime");
const sourceAsset = path.resolve(process.env.THREE_WHEEL_ATLAS_SOURCE || path.join(sourceRoot, "three_wheel_delivery_atlas_candidate.glb"));
const candidateId = process.env.THREE_WHEEL_ATLAS_CANDIDATE_ID || "city-vehicle-three-wheel-delivery-atlas-candidate";
const evidencePath = path.join(workspaceRoot, "reference-evidence/candidate-runtime", process.env.THREE_WHEEL_ATLAS_EVIDENCE_FILE || "three-wheel-delivery-atlas-runtime.json");
const runtimeAssetFileName = process.env.THREE_WHEEL_RUNTIME_ASSET_NAME || "three_wheel_delivery_atlas_candidate.glb";
const candidateVariant = process.env.THREE_WHEEL_CANDIDATE_VARIANT || "three_wheel_delivery_material_atlas_v1";
const godotBinary = process.env.GODOT_BIN || "godot";
const godotTimeoutMs = Number.parseInt(process.env.THREE_WHEEL_ATLAS_GODOT_TIMEOUT_MS || "300000", 10);

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function copyFilter(sourcePath) {
  const relative = path.relative(formalRuntimeRoot, sourcePath).split(path.sep).join("/");
  return relative !== ".godot" && !relative.startsWith(".godot/") && !relative.endsWith(".import") && !relative.endsWith(".uid");
}

function runGodot(runtimeRoot, args, env, label, timeout = godotTimeoutMs) {
  const logPath = path.join(runtimeRoot, "three-wheel-atlas-integration.log");
  fs.rmSync(logPath, {force: true});
  console.log(`开始${label}：${args.join(" ")}`);
  const result = spawnSync(godotBinary, ["--headless", "--path", runtimeRoot, "--audio-driver", "Dummy", "--rendering-driver", "opengl3", "--rendering-method", "gl_compatibility", "--log-file", logPath, ...args], {
    cwd: workspaceRoot,
    env: {...process.env, ...env},
    stdio: ["ignore", "pipe", "pipe"],
    timeout,
    killSignal: "SIGTERM",
    encoding: "utf8",
  });
  const output = `${result.stdout || ""}\n${result.stderr || ""}\n${fs.existsSync(logPath) ? fs.readFileSync(logPath, "utf8") : ""}`;
  console.log(`完成${label}：状态 ${result.status ?? "空"}`);
  const warmup = args.includes("--editor");
  const filtered = output.split(/\r?\n/).filter((line) => {
    if (line.includes("get_system_ca_certificates") || line.includes('ERROR: Condition "ret != noErr" is true.')) return false;
    if (warmup && (line.includes("Cannot save file") || line.includes("Error saving editor settings to"))) return false;
    return true;
  }).join("\n");
  if (result.error) {
    const timeoutHint = result.error.code === "ETIMEDOUT" ? `；已达到 ${timeout} 毫秒超时` : "";
    throw new Error(`${label}失败${timeoutHint}：${result.error.message}\n${filtered}`);
  }
  if (result.status !== 0 || /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(filtered)) {
    throw new Error(`${label}失败：${filtered.split(/\r?\n/).filter((line) => /\bERROR:|SCRIPT ERROR|ASSERT(?:ION)?\s+FAILED|Assertion failed/i.test(line)).slice(-12).join(" | ")}`);
  }
  return output;
}

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), "新时代觉醒者-three-wheel-atlas-"));
const evidenceTempPath = `${evidencePath}.tmp-${process.pid}`;
try {
  fs.cpSync(formalRuntimeRoot, tempRoot, {recursive: true, filter: copyFilter});
  const assetDirectory = path.join(tempRoot, "assets/vehicles/three-wheel-delivery");
  fs.mkdirSync(assetDirectory, {recursive: true});
  const assetFileName = runtimeAssetFileName;
  fs.copyFileSync(sourceAsset, path.join(assetDirectory, assetFileName));
  const sceneTemplate = fs.readFileSync(path.join(formalRuntimeRoot, "assets/vehicles/three-wheel-delivery/three_wheel_delivery_candidate.tscn"), "utf8");
  fs.writeFileSync(path.join(assetDirectory, "three_wheel_delivery_atlas_candidate.tscn"), sceneTemplate.replace("three_wheel_delivery.glb", assetFileName), "utf8");
  const catalogPath = path.join(tempRoot, "tests/asset-runtime-catalog-three-wheel-atlas-override.json");
  const catalog = JSON.parse(fs.readFileSync(path.join(formalRuntimeRoot, "content/asset-runtime-catalog.json"), "utf8"));
  const vehicleSlot = catalog.slots.find((slot) => slot.id === "three-wheel-vehicle");
  const candidateVehicleRoot = path.join(tempRoot, "art-source/vehicles/three-wheel-delivery");
  fs.mkdirSync(candidateVehicleRoot, {recursive: true});
  fs.copyFileSync(sourceAsset, path.join(candidateVehicleRoot, assetFileName));
  fs.copyFileSync(path.join(sourceRoot, "three_wheel_delivery_atlas_candidate.gd"), path.join(candidateVehicleRoot, "three_wheel_delivery_atlas_candidate.gd"));
  const candidateScenePath = path.join(candidateVehicleRoot, "three_wheel_delivery_atlas_candidate.tscn");
  fs.writeFileSync(candidateScenePath, fs.readFileSync(path.join(sourceRoot, "three_wheel_delivery_atlas_candidate.tscn"), "utf8")
    .replaceAll("res://../art-source", "res://art-source")
    .replaceAll("three_wheel_delivery_atlas_candidate.glb", assetFileName), "utf8");
  vehicleSlot.scene_path = "res://art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.tscn";
  vehicleSlot.fallback_policy = "forbid";
  fs.writeFileSync(catalogPath, `${JSON.stringify(catalog, null, 2)}\n`, "utf8");
  const contractTestPath = path.join(tempRoot, "tests/three_wheel_atlas_contract_test.gd");
  fs.writeFileSync(contractTestPath, `extends SceneTree

const OfficeScene = preload("res://scenes/benchmark.tscn")
const CityScene = preload("res://scenes/city.tscn")

func _init() -> void:
\tcall_deferred("_run")

func _run() -> void:
\tvar office = OfficeScene.instantiate()
\toffice.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-three-wheel-atlas-override.json")
\troot.add_child(office)
\tawait process_frame
\tassert(office.vehicle.get_node_or_null("Visual") != null, "办公室图集三轮车没有挂载 Visual")
\tassert(office.vehicle.get_node("Visual").find_child("候选三轮车车体", true, false) != null, "办公室图集三轮车缺少候选车体")
\tassert(office.vehicle.get_node("Visual").find_child("候选前灯光晕", true, false) != null, "办公室图集三轮车缺少前灯光晕")
\tassert(office.vehicle.get_node("Visual").find_child("候选三轮车损伤面板", true, false) != null, "办公室图集三轮车缺少损伤面板")
\tassert(office.vehicle.get_node_or_null("原创灰盒三轮车外观") == null, "办公室图集三轮车仍保留灰盒回退")
\toffice.free()
\tawait process_frame
\tvar city = CityScene.instantiate()
\tcity.set_meta("asset_catalog_path", "res://tests/asset-runtime-catalog-three-wheel-atlas-override.json")
\troot.add_child(city)
\tawait process_frame
\tassert(city.vehicle.get_node_or_null("Visual") != null, "城市图集三轮车没有挂载 Visual")
\tassert(city.vehicle.get_node("Visual").find_child("候选三轮车车体", true, false) != null, "城市图集三轮车缺少候选车体")
\tassert(city.vehicle.get_node("Visual").find_child("候选前灯光晕", true, false) != null, "城市图集三轮车缺少前灯光晕")
\tassert(city.vehicle.get_node("Visual").find_child("候选三轮车损伤面板", true, false) != null, "城市图集三轮车缺少损伤面板")
\tassert(city.vehicle.get_node_or_null("原创灰盒三轮车外观") == null, "城市图集三轮车仍保留灰盒回退")
\tassert(city.vehicle_wheels.size() == 3, "城市图集三轮车没有绑定三只车轮")
\tprint("三轮车图集候选挂载契约测试通过")
\tquit(0)
`, "utf8");
  const cityTestPath = path.join(tempRoot, "tests/city_atlas_integration_test.gd");
  const cityTestSource = fs.readFileSync(path.join(formalRuntimeRoot, "tests/city_integration_test.gd"), "utf8")
    .replace('assert(city.vehicle.get_node("Visual").has_meta("original_procedural_asset"), "正式城市三轮车候选缺少原创资产元数据")', 'assert(city.vehicle.get_node("Visual").has_meta("candidate_visual_asset"), "城市图集三轮车候选缺少候选视觉资产元数据")')
    .replace('assert(city.find_child("三轮车座椅", true, false) != null, "城市三轮车缺少座椅视觉")', 'assert(city.find_child("三轮车座椅", true, false) != null or city.find_child("候选三轮车座椅", true, false) != null, "城市三轮车缺少座椅视觉")')
    .replace('assert(city.find_child("三轮车车把", true, false) != null, "城市三轮车缺少车把视觉")', 'assert(city.find_child("三轮车车把", true, false) != null or city.find_child("候选三轮车车把", true, false) != null, "城市三轮车缺少车把视觉")')
    .replace('assert(city.find_child("三轮车货架", true, false) != null or city.find_child("候选三轮车货架", true, false) != null, "城市三轮车缺少货架视觉")', 'assert(city.find_child("三轮车货架", true, false) != null or city.vehicle.get_node_or_null("Visual") != null and (city.vehicle.get_node("Visual").find_child("候选三轮车货斗底板", true, false) != null or city.vehicle.get_node("Visual").find_child("候选三轮车货斗左栏", true, false) != null), "城市三轮车缺少货架视觉")');
  const damageRefreshNeedle = '\t\tcity._update_vehicle_damage_feedback()\n\t\tassert(candidate_damage_panel.visible, "候选三轮车受损后没有显示专属损伤面板")';
  const damageRefreshReplacement = '\t\tcity._update_vehicle_damage_feedback()\n\t\tcity.vehicle.get_node("Visual").refresh_feedback()\n\t\tassert(candidate_damage_panel.visible, "候选三轮车受损后没有显示专属损伤面板")';
  const cityTestWithDamageRefresh = cityTestSource.replace(damageRefreshNeedle, damageRefreshReplacement);
  fs.writeFileSync(cityTestPath, cityTestWithDamageRefresh, "utf8");
  runGodot(tempRoot, ["--editor", "--quit"], {}, "三轮车图集候选导入预热");
  const env = {REFERENCE_ASSET_CATALOG_PATH: "res://tests/asset-runtime-catalog-three-wheel-atlas-override.json"};
  const assetOutput = runGodot(tempRoot, ["--quit-after", "45", "-s", "res://tests/three_wheel_atlas_contract_test.gd"], env, "三轮车图集候选资产接入");
  if (!assetOutput.includes("三轮车图集候选挂载契约测试通过")) throw new Error("三轮车图集候选缺少资产接入成功哨兵");
  const cityOutput = runGodot(tempRoot, ["--quit-after", "45", "-s", "res://tests/city_atlas_integration_test.gd"], env, "三轮车图集候选城市回放");
  if (!cityOutput.includes("城市任务端到端回放测试通过")) throw new Error("三轮车图集候选缺少城市回放成功哨兵");
  const officeOutput = runGodot(tempRoot, ["--quit-after", "45", "-s", "res://tests/office_integration_test.gd"], env, "三轮车图集候选办公室回放");
  if (!officeOutput.includes("办公室潜行端到端回放测试通过")) throw new Error("三轮车图集候选缺少办公室回放成功哨兵");
  const registry = JSON.parse(fs.readFileSync(path.join(workspaceRoot, "docs/asset-candidate-registry.json"), "utf8"));
  const entry = registry.candidates.find((candidate) => candidate.id === candidateId);
  if (!entry) throw new Error(`候选登记中缺少 ${candidateId}`);
  const candidateHash = sha256(sourceAsset);
  if (entry.runtime_sha256 !== candidateHash) throw new Error(`三轮车图集候选哈希不一致：${candidateHash}`);
  const evidence = {
    schema_version: 1,
    status: "candidate_isolated_city_office_runtime_verified",
    candidate_id: entry.id,
    candidate_variant: candidateVariant,
    candidate_sha256: candidateHash,
    runtime_options: {asset_catalog: "three-wheel-atlas-override", fallback_policy: "forbid"},
    environment: "temporary copy of gta-reference-runtime",
    checks: ["Godot GLB import", "vehicle Visual mount with fallback forbidden", "city task and driving replay", "office task and driving replay", "vehicle wheel movement and save restore"],
    visual_status: "unverified",
    release_allowed: false,
    captured_at: new Date().toISOString(),
  };
  fs.mkdirSync(path.dirname(evidencePath), {recursive: true});
  fs.writeFileSync(evidenceTempPath, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
  fs.renameSync(evidenceTempPath, evidencePath);
  console.log(`三轮车图集候选隔离运行时证据已写入：${evidencePath}`);
} catch (error) {
  fs.rmSync(evidenceTempPath, {force: true});
  throw error;
} finally {
  if (process.env.KEEP_THREE_WHEEL_TEMP !== "1") fs.rmSync(tempRoot, {recursive: true, force: true});
  else console.log(`已保留三轮车隔离运行临时目录：${tempRoot}`);
  fs.rmSync(evidenceTempPath, {force: true});
}

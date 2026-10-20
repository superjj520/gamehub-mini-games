import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {NodeIO} from "@gltf-transform/core";
import {getBounds} from "@gltf-transform/functions";

const workspaceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const registryPath = path.join(workspaceRoot, "docs/asset-candidate-registry.json");
const contractPath = path.join(workspaceRoot, "docs/3d-asset-pipeline-contract.json");
const defaultOutputPath = path.join(workspaceRoot, "reference-evidence/candidate-runtime/asset-convention-verification.json");

const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));

function parseArgs(argv) {
  const args = {strict: false, output: defaultOutputPath};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--strict") args.strict = true;
    else if (value === "--output") args.output = path.resolve(argv[++index]);
    else if (value === "--help") {
      console.log("用法：node scripts/verify_asset_conventions.mjs [--strict] [--output 文件]");
      process.exit(0);
    } else {
      throw new Error(`未知参数：${value}`);
    }
  }
  return args;
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function closeTo(value, expected, tolerance) {
  return Math.abs(Number(value) - Number(expected)) <= tolerance;
}

function isIdentityTransform(node, tolerance) {
  const translation = node.getTranslation();
  const rotation = node.getRotation();
  const scale = node.getScale();
  return translation.every((value) => closeTo(value, 0, tolerance))
    && closeTo(rotation[0], 0, tolerance)
    && closeTo(rotation[1], 0, tolerance)
    && closeTo(rotation[2], 0, tolerance)
    && closeTo(rotation[3], 1, tolerance)
    && scale.every((value) => closeTo(value, 1, tolerance));
}

function profileForSlot(slotId) {
  if (["player-character", "office-npc-set", "city-crowd-set"].includes(slotId)) return "character";
  if (slotId === "three-wheel-vehicle") return "vehicle";
  if (slotId === "office-environment-kit" || slotId === "city-environment-kit") return "environment";
  if (slotId === "interaction-props") return "prop";
  return null;
}

function numericBounds(bounds) {
  const min = bounds.min.map(Number);
  const max = bounds.max.map(Number);
  return {
    min,
    max,
    size: max.map((value, index) => value - min[index]),
  };
}

async function inspectCandidate(candidate, profileName) {
  const relativePath = String(candidate.asset_path);
  const assetPath = path.resolve(workspaceRoot, relativePath);
  const profile = contract.profiles[profileName];
  const result = {
    id: candidate.id,
    slot_id: candidate.slot_id,
    profile: profileName,
    path: relativePath,
    checks: {},
    status: "convention_fail",
  };
  if (!fs.existsSync(assetPath)) {
    result.error = `资产不存在：${relativePath}`;
    return result;
  }
  try {
    const document = await new NodeIO().read(assetPath);
    const scenes = document.getRoot().listScenes();
    const scene = scenes[0];
    const rootNodes = scene ? scene.listChildren() : [];
    const meshes = document.getRoot().listMeshes();
    const bounds = scene ? numericBounds(getBounds(scene)) : null;
    const tolerance = Number(contract.identity_transform_tolerance);
    const hasFiniteBounds = Boolean(bounds)
      && [...bounds.min, ...bounds.max, ...bounds.size].every(Number.isFinite)
      && bounds.size.every((value) => value > 0);
    const noRootTransform = rootNodes.length > 0 && rootNodes.every((node) => isIdentityTransform(node, tolerance));
    const dimensions = bounds?.size ?? [0, 0, 0];
    const [width, height, depth] = dimensions;
    const checks = {
      file_exists: true,
      supported_format: [".glb", ".gltf"].includes(path.extname(assetPath).toLowerCase()),
      one_scene: scenes.length === 1,
      mesh_present: meshes.length > 0,
      finite_positive_bounds: hasFiniteBounds,
      root_transform_identity: noRootTransform,
    };
    if (profileName === "character") {
      checks.height_in_character_range = height >= profile.min_height_m && height <= profile.max_height_m;
      checks.foot_origin = bounds.min[1] >= profile.min_y_m && bounds.min[1] <= 0.05;
      checks.character_top_in_range = bounds.max[1] <= profile.max_y_m;
    } else if (profileName === "vehicle") {
      checks.width_in_vehicle_range = width >= profile.min_width_m && width <= profile.max_width_m;
      checks.height_in_vehicle_range = height >= profile.min_height_m && height <= profile.max_height_m;
      checks.depth_in_vehicle_range = depth >= profile.min_depth_m && depth <= profile.max_depth_m;
      checks.body_center_origin = bounds.min[1] < 0 && bounds.max[1] > 0;
    } else if (profileName === "environment") {
      checks.base_origin = bounds.min[1] >= profile.min_y_m;
    } else if (profileName === "prop") {
      checks.base_origin = bounds.min[1] >= profile.min_y_m;
      checks.prop_height_in_range = height <= profile.max_height_m;
    }
    result.metrics = {
      scenes: scenes.length,
      root_nodes: rootNodes.map((node) => node.getName()),
      meshes: meshes.length,
      bounds,
      sha256: sha256(assetPath),
    };
    result.checks = checks;
    result.status = Object.values(checks).every(Boolean) ? "convention_pass" : "convention_fail";
    if (result.status !== "convention_pass") {
      result.failed_checks = Object.entries(checks).filter(([, value]) => !value).map(([name]) => name);
    }
  } catch (error) {
    result.error = String(error?.message || error);
  }
  return result;
}

const args = parseArgs(process.argv.slice(2));
if (contract.schema_version !== 1 || contract.units_per_meter !== 1 || contract.up_axis !== "+Y" || contract.forward_axis !== "-Z") {
  throw new Error("3D 资产契约的基础坐标约定无效");
}
const uniqueCandidates = new Map();
for (const candidate of registry.candidates ?? []) {
  const profileName = profileForSlot(candidate.slot_id);
  if (!profileName || !candidate.asset_path) continue;
  const key = `${candidate.slot_id}|${candidate.asset_path}`;
  if (!uniqueCandidates.has(key)) uniqueCandidates.set(key, {candidate, profileName});
}

const results = [];
for (const {candidate, profileName} of uniqueCandidates.values()) {
  const result = await inspectCandidate(candidate, profileName);
  results.push(result);
  if (result.status === "convention_pass") {
    const metrics = result.metrics;
    console.log(`资产导入契约通过：${candidate.id}；包围盒 ${metrics.bounds.size.map((value) => value.toFixed(3)).join("×")} 米`);
  } else {
    console.error(`资产导入契约不通过：${candidate.id}；${(result.failed_checks ?? [result.error ?? "未知错误"]).join("、")}`);
  }
}

const failed = results.filter((result) => result.status !== "convention_pass");
const evidence = {
  schema_version: 1,
  status: failed.length === 0 ? "technical_convention_passed" : "technical_convention_failed",
  strict: args.strict,
  contract_path: "docs/3d-asset-pipeline-contract.json",
  policy: contract.policy,
  results,
  verified_at: new Date().toISOString(),
};
fs.mkdirSync(path.dirname(args.output), {recursive: true});
fs.writeFileSync(args.output, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
console.log(`资产导入契约证据已写入：${path.relative(workspaceRoot, args.output)}`);
if (args.strict && failed.length > 0) process.exit(1);

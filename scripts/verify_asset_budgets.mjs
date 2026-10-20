import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {NodeIO} from "@gltf-transform/core";

const workspaceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const registryPath = path.join(workspaceRoot, "docs/asset-candidate-registry.json");
const defaultEvidencePath = path.join(workspaceRoot, "reference-evidence/candidate-runtime/asset-budget-verification.json");

const PROFILES = {
  player: {maxTriangles: 35000, maxMaterials: 4, maxTextureSize: 2048, maxBones: 128},
  npc: {maxTriangles: 18000, maxMaterials: 3, maxTextureSize: 1024, maxBones: 96},
  office_environment: {maxTriangles: 12000, maxMaterials: 3, maxTextureSize: 1024, maxBones: 0},
  city_environment: {maxTriangles: 12000, maxMaterials: 5, maxTextureSize: 2048, maxBones: 0},
  vehicle: {maxTriangles: 25000, maxMaterials: 5, maxTextureSize: 2048, maxBones: 32},
  prop: {maxTriangles: 4000, maxMaterials: 3, maxTextureSize: 512, maxBones: 0},
};

const DEFAULT_TARGETS = [
  {
    id: "player-character-makehuman-elegant-suit-atlas-candidate",
    path: "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
    profile: "player",
  },
  {
    id: "office-npc-makehuman-elegant-suit-skinned-512-atlas-candidate",
    path: "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
    profile: "npc",
  },
  {
    id: "city-crowd-makehuman-elegant-suit-atlas-candidate",
    path: "art-source/characters/makehuman-office-worker/makehuman_office_worker_elegant_suit_skinned_probe_512_atlas_candidate.glb",
    profile: "npc",
  },
  {
    id: "city-vehicle-three-wheel-delivery-atlas-candidate",
    path: "art-source/vehicles/three-wheel-delivery/three_wheel_delivery_atlas_candidate.glb",
    profile: "vehicle",
  },
  {
    id: "city-vehicle-three-wheel-delivery-final-procedural-candidate",
    path: "art-source/vehicles/three-wheel-delivery/final-candidate/three_wheel_delivery_final_candidate.glb",
    profile: "vehicle",
  },
  {
    id: "office-desk-polyhaven-metal-cc0-candidate",
    path: "art-source/environment/polyhaven-metal-office-desk/metal_office_desk_1k.gltf",
    profile: "office_environment",
  },
  {
    id: "interaction-props-original-kit-candidate",
    path: "art-source/props/original-interaction-kit/interaction_props_kit.glb",
    profile: "prop",
  },
];

function parseArgs(argv) {
  const args = {targets: [], output: defaultEvidencePath, strict: false, custom_targets: false};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--strict") {
      args.strict = true;
    } else if (value === "--output") {
      args.output = argv[++index];
    } else if (value === "--asset") {
      const [assetId, assetPath, profile] = String(argv[++index] || "").split("|");
      args.targets.push({id: assetId, path: assetPath, profile});
      args.custom_targets = true;
    } else if (value === "--help") {
      console.log("用法：node scripts/verify_asset_budgets.mjs [--strict] [--output 文件] [--asset id|路径|profile]");
      process.exit(0);
    } else {
      throw new Error(`未知参数：${value}`);
    }
  }
  if (args.targets.length === 0) args.targets = DEFAULT_TARGETS;
  return args;
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function resolveWorkspacePath(relativeOrAbsolute) {
  return path.isAbsolute(relativeOrAbsolute) ? relativeOrAbsolute : path.join(workspaceRoot, relativeOrAbsolute);
}

function trianglesForPrimitive(primitive) {
  const mode = primitive.getMode();
  const count = primitive.getIndices()?.getCount() ?? primitive.getAttribute("POSITION")?.getCount() ?? 0;
  if (mode === 4) return count / 3;
  if (mode === 5) return Math.max(0, count - 2);
  if (mode === 6) return Math.max(0, count - 2);
  return 0;
}

function textureSize(texture) {
  const size = texture.getSize();
  return size ? {width: size[0], height: size[1], maxDimension: Math.max(size[0], size[1])} : null;
}

function uniqueMaterials(document) {
  const materials = new Set();
  for (const mesh of document.getRoot().listMeshes()) {
    for (const primitive of mesh.listPrimitives()) {
      const material = primitive.getMaterial();
      if (material) materials.add(material);
    }
  }
  return [...materials];
}

async function inspectTarget(target, registry, strict) {
  const profile = PROFILES[target.profile];
  if (!profile) throw new Error(`未知资产预算档位：${target.profile}`);
  const assetPath = resolveWorkspacePath(target.path);
  if (!fs.existsSync(assetPath)) throw new Error(`资产文件不存在：${target.path}`);
  const document = await new NodeIO().read(assetPath);
  const root = document.getRoot();
  const meshDetails = root.listMeshes().map((mesh) => ({
    name: mesh.getName(),
    triangles: mesh.listPrimitives().reduce((sum, primitive) => sum + trianglesForPrimitive(primitive), 0),
    primitives: mesh.listPrimitives().length,
  }));
  const triangles = meshDetails.reduce((sum, mesh) => sum + mesh.triangles, 0);
  const materials = uniqueMaterials(document);
  const textures = root.listTextures().map((texture) => ({
    name: texture.getName(),
    uri: texture.getURI(),
    mimeType: texture.getMimeType(),
    size: textureSize(texture),
  }));
  const oversizedTextures = textures.filter((texture) => !texture.size || texture.size.maxDimension > profile.maxTextureSize);
  const bones = root.listSkins().reduce((sum, skin) => sum + skin.listJoints().length, 0);
  const registryEntry = registry.candidates.find((candidate) => candidate.id === target.id);
  const actualHash = sha256(assetPath);
  const checks = {
    file_exists: true,
    registry_entry_present: !strict || Boolean(registryEntry),
    registry_hash_present: !strict || Boolean(registryEntry?.runtime_sha256),
    registry_path_matches: !registryEntry || registryEntry.asset_path === target.path,
    registry_hash_matches: strict
      ? Boolean(registryEntry?.runtime_sha256) && registryEntry.runtime_sha256 === actualHash
      : !registryEntry || !registryEntry.runtime_sha256 || registryEntry.runtime_sha256 === actualHash,
    triangles_within_budget: triangles <= profile.maxTriangles,
    materials_within_budget: materials.length <= profile.maxMaterials,
    textures_within_budget: oversizedTextures.length === 0,
    bones_within_budget: bones <= profile.maxBones,
  };
  return {
    id: target.id,
    path: target.path,
    profile: target.profile,
    profile_limits: profile,
    sha256: actualHash,
    metrics: {
      triangles,
      materials: materials.length,
      bones,
      textures: textures.length,
      max_texture_dimension: textures.reduce((max, texture) => Math.max(max, texture.size?.maxDimension || 0), 0),
      meshes: meshDetails,
      texture_details: textures,
    },
    checks,
    status: Object.values(checks).every(Boolean) ? "technical_budget_pass" : "technical_budget_fail",
    visual_status: "unverified",
    release_allowed: false,
  };
}

const args = parseArgs(process.argv.slice(2));
const resolvedOutputPath = resolveWorkspacePath(args.output);
if (args.custom_targets && path.resolve(resolvedOutputPath) === path.resolve(defaultEvidencePath)) {
  throw new Error("使用 --asset 选择子集时必须同时提供 --output，避免覆盖默认全量预算证据");
}
const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const results = [];
let failed = false;

for (const target of args.targets) {
  try {
    const result = await inspectTarget(target, registry, args.strict);
    results.push(result);
    const failedChecks = Object.entries(result.checks).filter(([, passed]) => !passed).map(([name]) => name);
    if (failedChecks.length > 0) {
      failed = true;
      console.error(`资产预算不通过：${result.id}；${failedChecks.join("、")}`);
    } else {
      console.log(`资产预算通过：${result.id}；${result.metrics.triangles} 三角面 / ${result.metrics.materials} 材质 / ${result.metrics.bones} 骨骼`);
    }
  } catch (error) {
    failed = true;
    results.push({id: target.id, path: target.path, profile: target.profile, status: "inspection_failed", error: String(error?.message || error), visual_status: "unverified", release_allowed: false});
    console.error(`资产预算检查失败：${target.id}；${error?.message || error}`);
  }
}

const evidence = {
  schema_version: 1,
  status: failed ? "technical_budget_failed" : "technical_budget_passed",
  strict: args.strict,
  policy: "技术预算通过不代表视觉、权利、目标设备或发布验收通过",
  profiles: PROFILES,
  results,
  verified_at: new Date().toISOString(),
};
const outputPath = resolvedOutputPath;
fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
console.log(`资产预算证据已写入：${path.relative(workspaceRoot, outputPath)}`);

if (failed) process.exit(1);

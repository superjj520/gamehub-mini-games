import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const workspaceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const conventionPath = path.join(workspaceRoot, "docs/material-shading-conventions.json");
const defaultOutputPath = path.join(workspaceRoot, "reference-evidence/candidate-runtime/material-shading-verification.json");
const conventions = JSON.parse(fs.readFileSync(conventionPath, "utf8"));
const transparentSurfacePathSuffixes = conventions.runtime_scope.transparent_surface_paths ?? [
  "original_office_desk_runtime_candidate.gd",
];

function parseArgs(argv) {
  const args = {strict: false, output: defaultOutputPath};
  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--strict") args.strict = true;
    else if (value === "--output") args.output = path.resolve(argv[++index]);
    else if (value === "--help") {
      console.log("用法：node scripts/verify_material_shading_conventions.mjs [--strict] [--output 文件]");
      process.exit(0);
    } else throw new Error(`未知参数：${value}`);
  }
  return args;
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function sourceFingerprint() {
  const files = [];
  for (const relativeRoot of conventions.runtime_scope.roots) {
    const absoluteRoot = path.join(workspaceRoot, relativeRoot);
    if (!fs.existsSync(absoluteRoot)) continue;
    const pending = [absoluteRoot];
    while (pending.length > 0) {
      const current = pending.pop();
      for (const entry of fs.readdirSync(current, {withFileTypes: true})) {
        const entryPath = path.join(current, entry.name);
        if (entry.isDirectory()) pending.push(entryPath);
        else if (/\.(gd|tscn|tres|json|png|jpg|jpeg)$/i.test(entry.name)) files.push(entryPath);
      }
    }
  }
  const uniqueFiles = [...new Set(files)].sort();
  const hash = crypto.createHash("sha256");
  for (const filePath of uniqueFiles) {
    hash.update(path.relative(workspaceRoot, filePath));
    hash.update("\0");
    hash.update(fs.readFileSync(filePath));
    hash.update("\0");
  }
  return {file_count: uniqueFiles.length, sha256: hash.digest("hex")};
}

function collectSourceFiles() {
  const files = [];
  for (const relativeRoot of conventions.runtime_scope.roots) {
    const absoluteRoot = path.join(workspaceRoot, relativeRoot);
    if (!fs.existsSync(absoluteRoot)) continue;
    const pending = [absoluteRoot];
    while (pending.length > 0) {
      const current = pending.pop();
      for (const entry of fs.readdirSync(current, {withFileTypes: true})) {
        const entryPath = path.join(current, entry.name);
        if (entry.isDirectory()) pending.push(entryPath);
        else if (/\.(gd|tscn|tres)$/i.test(entry.name)) files.push(entryPath);
      }
    }
  }
  return [...new Set(files)].sort();
}

function numericLiterals(text, expression) {
  return [...text.matchAll(expression)].map((match) => Number(match[1]));
}

const args = parseArgs(process.argv.slice(2));
const sourceFiles = collectSourceFiles();
const checks = {
  convention_file_valid: conventions.schema_version === 1,
  standard_material_only: true,
  no_custom_shader_in_scope: true,
  roughness_literals_in_range: true,
  metallic_literals_in_range: true,
  alpha_transparency_is_scoped: true,
  generated_facade_textures_are_declared: true,
};
const findings = [];
let standardMaterialCount = 0;
let shaderMaterialCount = 0;
let textureReferenceCount = 0;
let alphaTransparencyCount = 0;
let emissionCount = 0;

for (const filePath of sourceFiles) {
  const relativePath = path.relative(workspaceRoot, filePath);
  const text = fs.readFileSync(filePath, "utf8");
  const standardMatches = text.match(/\bStandardMaterial3D\b/g) ?? [];
  const shaderMatches = text.match(/\bShaderMaterial\b/g) ?? [];
  standardMaterialCount += standardMatches.length;
  shaderMaterialCount += shaderMatches.length;
  textureReferenceCount += (text.match(/\b(?:albedo_texture|normal_texture|orm_texture)\b/g) ?? []).length;
  alphaTransparencyCount += (text.match(/TRANSPARENCY_ALPHA/g) ?? []).length;
  emissionCount += (text.match(/emission_enabled|emission_energy_multiplier/g) ?? []).length;
  if (shaderMatches.length > 0) {
    checks.standard_material_only = false;
    checks.no_custom_shader_in_scope = false;
    findings.push({file: relativePath, issue: "发现 ShaderMaterial；候选运行时暂不允许自定义着色器"});
  }
  const roughnessValues = numericLiterals(text, /(?:roughness\s*=|_material\([^\n]*,\s*)(0?\.\d+|1(?:\.0+)?)/g);
  for (const value of roughnessValues) {
    if (value < 0 || value > 1) {
      checks.roughness_literals_in_range = false;
      findings.push({file: relativePath, issue: `roughness 超出 0 到 1：${value}`});
    }
  }
  const metallicValues = numericLiterals(text, /metallic\s*=\s*(0?\.\d+|1(?:\.0+)?)/g);
  for (const value of metallicValues) {
    if (value < 0 || value > 1) {
      checks.metallic_literals_in_range = false;
      findings.push({file: relativePath, issue: `metallic 超出 0 到 1：${value}`});
    }
  }
  const transparentSurfaceAllowed = transparentSurfacePathSuffixes.some((suffix) => relativePath.endsWith(suffix));
  if (text.includes("TRANSPARENCY_ALPHA") && !transparentSurfaceAllowed) {
    checks.alpha_transparency_is_scoped = false;
    findings.push({file: relativePath, issue: "透明材质超出办公室玻璃隔断的候选范围"});
  }
}

const generatedTextureRoot = path.join(workspaceRoot, "gta-reference-runtime/assets/environment/generated");
const rightsManifestPath = path.join(workspaceRoot, "gta-reference-runtime/content/rights-manifest.json");
const rightsManifestText = fs.existsSync(rightsManifestPath) ? fs.readFileSync(rightsManifestPath, "utf8") : "";
const generatedTextures = fs.existsSync(generatedTextureRoot)
  ? fs.readdirSync(generatedTextureRoot).filter((name) => /\.(png|jpg|jpeg)$/i.test(name)).sort()
  : [];
for (const name of generatedTextures) {
  const relative = `gta-reference-runtime/assets/environment/generated/${name}`;
  const referenced = sourceFiles.some((filePath) => fs.readFileSync(filePath, "utf8").includes(name));
  const sidecarPath = path.join(generatedTextureRoot, `${name.replace(/\.(png|jpg|jpeg)$/i, "")}.json`);
  const rightsTracked = rightsManifestText.includes(`assets/environment/generated/${name}`);
  if (!referenced && !fs.existsSync(sidecarPath) && !rightsTracked) {
    checks.generated_facade_textures_are_declared = false;
    findings.push({file: relative, issue: "生成贴图存在，但没有在候选运行时代码中声明引用"});
  }
}

const fingerprint = sourceFingerprint();
const failed = Object.entries(checks).filter(([, value]) => !value).map(([name]) => name);
const evidence = {
  schema_version: 1,
  status: failed.length === 0 ? "technical_convention_passed" : "technical_convention_failed",
  strict: args.strict,
  convention_path: "docs/material-shading-conventions.json",
  source_fingerprint: fingerprint,
  scope: conventions.runtime_scope.roots,
  metrics: {
    source_files: sourceFiles.length,
    standard_material_mentions: standardMaterialCount,
    shader_material_mentions: shaderMaterialCount,
    texture_reference_mentions: textureReferenceCount,
    alpha_transparency_mentions: alphaTransparencyCount,
    emission_mentions: emissionCount,
    generated_texture_files: generatedTextures.length,
  },
  checks,
  findings,
  verified_at: new Date().toISOString(),
};
fs.mkdirSync(path.dirname(args.output), {recursive: true});
fs.writeFileSync(args.output, `${JSON.stringify(evidence, null, 2)}\n`, "utf8");
console.log(`材质与着色规范检查：${evidence.status}；文件 ${sourceFiles.length}；StandardMaterial3D ${standardMaterialCount}；自定义着色器 ${shaderMaterialCount}`);
console.log(`材质规范证据已写入：${path.relative(workspaceRoot, args.output)}`);
if (args.strict && failed.length > 0) process.exit(1);

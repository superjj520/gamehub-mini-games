import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const outputPath = path.join(workspaceRoot, "docs", "store-submission-evidence-index.json");

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(workspaceRoot, relativePath), "utf8"));
}

function sha256(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(workspaceRoot, relativePath))).digest("hex");
}

function fileEvidence(relativePath, metadata = {}) {
  const absolutePath = path.join(workspaceRoot, relativePath);
  if (!fs.existsSync(absolutePath)) {
    return {path: relativePath, exists: false, ...metadata};
  }
  return {
    path: relativePath,
    exists: true,
    bytes: fs.statSync(absolutePath).size,
    sha256: sha256(relativePath),
    ...metadata,
  };
}

function packageEvidence(metadataPath, status) {
  const metadata = readJson(metadataPath);
  const packagePath = metadata.path ?? metadata.package_path;
  const packageExists = typeof packagePath === "string" && fs.existsSync(path.join(workspaceRoot, packagePath));
  return {
    path: packagePath,
    metadata_path: metadataPath,
    exists: packageExists,
    status: metadata.status ?? status,
    bytes: metadata.bytes ?? null,
    sha256: metadata.sha256 ?? null,
    source_sha256: metadata.source?.sha256 ?? metadata.source_fingerprint ?? null,
    source_file_count: metadata.source?.file_count ?? metadata.source_file_count ?? null,
    entry_count: metadata.entry_count ?? null,
  };
}

function findCurrentReviewMetadata(prefix, source) {
  const buildDirectory = path.join(workspaceRoot, "build");
  const candidates = fs.readdirSync(buildDirectory)
    .filter((name) => name.startsWith(prefix) && name.endsWith(".json"))
    .sort();
  for (const name of candidates) {
    const metadataPath = path.join(buildDirectory, name);
    const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
    if (metadata.source?.sha256 === source.sha256 && metadata.source?.file_count === source.file_count) {
      return path.relative(workspaceRoot, metadataPath).split(path.sep).join("/");
    }
  }
  throw new Error(`没有找到绑定当前源指纹的审阅包清单：${prefix}*`);
}

const readiness = readJson("docs/readiness-report.json");
const releaseManifest = readJson("docs/release-manifest.json");
const ownerInputs = readJson("docs/release-owner-inputs.json");
const acceptance = readJson("reference-evidence/acceptance-status.json");
const expandedBehavior = readJson("reference-evidence/expanded-runtime-matrix/behavior-evidence.json");
const expandedVisual = readJson("reference-evidence/expanded-runtime-matrix/manifest.json");
const windowsManifest = readJson("docs/windows-build-manifest.json");
const productDecision = readJson("docs/product-baseline-decision.json");
const fullCandidatePlaytest = readJson("reference-evidence/candidate-runtime/full-candidate-playtest.json");
const originalOnlyCandidatePlaytest = readJson("reference-evidence/candidate-runtime/full-candidate-playtest-original-only.json");
const windowsQaBundle = readJson("reference-evidence/candidate-runtime/full-candidate-windows-qa-bundle.json");
const originalOnlyWindowsQaBundle = readJson("reference-evidence/candidate-runtime/full-candidate-windows-original-only-qa-bundle.json");
const source = releaseManifest.source;
const officeReviewMetadataPath = findCurrentReviewMetadata("p0-office-candidate-review-", source);
const cityReviewMetadataPath = findCurrentReviewMetadata("city-candidate-review-", source);
const runtimeMatrix = readJson("reference-evidence/runtime-matrix/manifest.json");
const runtimeMatrixBindingMatches = runtimeMatrix.source_fingerprint === source.sha256 && runtimeMatrix.source_file_count === source.file_count;
const storeMaterials = {
  mode: "strict",
  status: "blocked_pending_owner_inputs",
  command: "npm run verify:store-materials:strict",
  unresolved_count: ownerInputs.inputs.filter((input) => input.status !== "confirmed").length,
  owner_input_ids: ownerInputs.inputs.filter((input) => input.status !== "confirmed").map((input) => input.id),
};

function bundleEvidence(bundleMetadataPath) {
  const metadata = readJson(bundleMetadataPath);
  const bundlePath = metadata.bundle?.path;
  const bundleExists = typeof bundlePath === "string" && fs.existsSync(path.join(workspaceRoot, bundlePath));
  return {
    path: bundlePath,
    metadata_path: bundleMetadataPath,
    exists: bundleExists,
    status: metadata.status ?? "internal_no_go",
    bytes: metadata.bundle?.bytes ?? null,
    sha256: metadata.bundle?.sha256 ?? null,
    source_sha256: metadata.package?.source_sha256 ?? metadata.evidence_contract?.source?.sha256 ?? null,
    source_file_count: metadata.package?.source_file_count ?? metadata.evidence_contract?.source?.file_count ?? null,
    entry_count: metadata.package?.file_count ?? null,
  };
}

const index = {
  schema_version: 1,
  status: "internal_no_go",
  decision: "仅允许内部开发验证，不得提交 Steam 商店",
  generated_at: new Date().toISOString(),
  build_identity: {
    project_name: releaseManifest.project.name,
    project_version: releaseManifest.project.version,
    engine: releaseManifest.project.engine,
    runtime_root: source.root,
    source_sha256: source.sha256,
    source_file_count: source.file_count,
  },
  metadata_profile: {
    product_name: productDecision.product_name,
    version: releaseManifest.project.version,
    launch_platforms: productDecision.launch_platforms,
    launch_devices: productDecision.launch_devices,
    launch_regions_and_languages: productDecision.launch_regions_and_languages,
    commercialization: productDecision.commercialization,
    copyright_boundary: productDecision.copyright_boundary,
    localization_status: "简体中文基线已确认，其他语言未承诺",
    support_status: "客服邮箱和公开反馈入口待确认",
    privacy_status: "无网络数据收集基线已验证，正式隐私政策地址待确认",
    age_rating_status: "内部问卷草案，正式提交结果待确认",
    entitlement_status: "首发免费测试版，不接真实支付；Steam 应用编号待确认",
    release_date_status: "公开测试日期待确认",
  },
  evidence_policy: {
    reference_videos: "仅内部对照，不进入任何候选包或商店材料",
    candidate_assets: "只能作为候选评审证据，不等同于最终资产或发布授权",
    visual_evidence: "截图和扩展矩阵必须绑定同一源指纹，并经过人工验收后才可改为 passed",
    owner_fields: "客服、隐私、Steam 应用编号、年龄分级、日期和运营主体不得由工程猜测",
  },
  packages: [
    bundleEvidence("reference-evidence/candidate-runtime/full-candidate-windows-qa-bundle.json"),
    bundleEvidence("reference-evidence/candidate-runtime/full-candidate-windows-original-qa-bundle.json"),
    bundleEvidence("reference-evidence/candidate-runtime/full-candidate-windows-original-only-qa-bundle.json"),
    packageEvidence(officeReviewMetadataPath, "internal_candidate_review_only"),
    packageEvidence(cityReviewMetadataPath, "internal_candidate_review_only"),
  ],
  candidate_playtest: {
    path: "reference-evidence/candidate-runtime/full-candidate-playtest.json",
    status: fullCandidatePlaytest.status,
    source_sha256: fullCandidatePlaytest.source?.sha256 ?? null,
    source_file_count: fullCandidatePlaytest.source?.file_count ?? null,
    entries: fullCandidatePlaytest.entries ?? [],
    visual_status: fullCandidatePlaytest.visual_status,
    release_allowed: fullCandidatePlaytest.release_allowed,
  },
  release_candidate: {
    variant: "original_only",
    package_root: originalOnlyWindowsQaBundle.package?.root ?? "build/internal-full-candidate-original-only",
    playtest_path: "reference-evidence/candidate-runtime/full-candidate-playtest-original-only.json",
    qa_bundle_path: "reference-evidence/candidate-runtime/full-candidate-windows-original-only-qa-bundle.json",
    status: originalOnlyCandidatePlaytest.status,
    source_sha256: originalOnlyCandidatePlaytest.source?.sha256 ?? null,
    source_file_count: originalOnlyCandidatePlaytest.source?.file_count ?? null,
    visual_status: originalOnlyCandidatePlaytest.visual_status,
    release_allowed: originalOnlyCandidatePlaytest.release_allowed,
    policy: "产品基线为 original_assets_only；只有原创边界候选可以进入后续发布验收，其他候选仅用于内部对比。",
  },
  gate_matrix: [
    {
      id: "product_baseline",
      status: readiness.gates.find((gate) => gate.id === "product_baseline")?.status ?? "unknown",
      evidence: ["docs/product-baseline-decision.json"],
    },
    {
      id: "behavior_matrix",
      status: readiness.gates.find((gate) => gate.id === "behavior_matrix")?.status ?? "unknown",
      counts: readiness.gates.find((gate) => gate.id === "behavior_matrix")?.counts ?? null,
      evidence: ["reference-evidence/acceptance-status.json", "reference-evidence/expanded-runtime-matrix/behavior-evidence.json"],
      expanded_behavior: {
        status: expandedBehavior.status,
        visual_status: expandedBehavior.visual_status,
        release_allowed: expandedBehavior.release_allowed,
        source_sha256: expandedBehavior.source_fingerprint,
        source_file_count: expandedBehavior.source_file_count,
      },
    },
    {
      id: "visual_matrix",
      status: readiness.gates.find((gate) => gate.id === "visual_matrix")?.status ?? "unknown",
      counts: readiness.gates.find((gate) => gate.id === "visual_matrix")?.counts ?? null,
      evidence: ["reference-evidence/runtime-matrix/manifest.json", "reference-evidence/runtime-captures/manifest.json"],
      binding: {
        current_source_sha256: source.sha256,
        current_source_file_count: source.file_count,
        recorded_source_sha256: runtimeMatrix.source_fingerprint,
        recorded_source_file_count: runtimeMatrix.source_file_count,
        status: runtimeMatrixBindingMatches ? "unverified_current_binding" : "unverified_and_binding_mismatch",
      },
    },
    {
      id: "expanded_visual_matrix",
      status: expandedVisual.visual_status === "passed" && expandedVisual.source_fingerprint === source.sha256 && expandedVisual.source_file_count === source.file_count ? "passed" : "blocked_unverified",
      counts: {total: expandedVisual.captures.length, passed: expandedVisual.captures.filter((capture) => capture.visual_status === "passed").length, unverified: expandedVisual.captures.filter((capture) => capture.visual_status !== "passed").length},
      evidence: ["reference-evidence/expanded-runtime-matrix/manifest.json", "reference-evidence/expanded-runtime-matrix/behavior-evidence.json"],
      binding: {current_source_sha256: source.sha256, current_source_file_count: source.file_count, recorded_source_sha256: expandedVisual.source_fingerprint, recorded_source_file_count: expandedVisual.source_file_count},
    },
    {
      id: "final_assets",
      status: readiness.gates.find((gate) => gate.id === "final_assets")?.status ?? "unknown",
      counts: readiness.gates.find((gate) => gate.id === "final_assets")?.counts ?? null,
      evidence: ["docs/asset-production-manifest.json", "docs/asset-candidate-registry.json", "docs/asset-rights-register.md"],
    },
    {
      id: "rights_boundary",
      status: readiness.gates.find((gate) => gate.id === "rights_boundary")?.status ?? "unknown",
      evidence: ["gta-reference-runtime/content/rights-manifest.json", "gta-reference-runtime/THIRD_PARTY_NOTICES.md"],
    },
    {
      id: "target_platform",
      status: readiness.gates.find((gate) => gate.id === "target_platform")?.status ?? "unknown",
      evidence: ["docs/windows-build-manifest.json", "docs/steam-windows-export-plan.md", "docs/windows-device-qa-runbook.md"],
      current_builds: windowsManifest.presets.map((preset) => ({name: preset.name, path: preset.path, status: preset.target_device_status, includes_tests: preset.includes_tests, sha256: preset.sha256, bytes: preset.bytes})),
    },
    {
      id: "store_compliance",
      status: "blocked_draft_only",
      evidence: ["docs/store-submission-checklist.md", "docs/store-metadata-draft.md", "docs/privacy-policy-draft-zh-CN.md", "docs/support-and-rollback-plan.md", "docs/age-rating-questionnaire-zh-CN.md"],
      strict_materials: storeMaterials,
    },
    {
      id: "rollback",
      status: readiness.gates.find((gate) => gate.id === "rollback")?.status ?? "unknown",
      evidence: ["reference-evidence/release-rollback-rehearsal.json", "docs/support-and-rollback-plan.md"],
    },
  ],
  owner_inputs: ownerInputs.inputs.map((input) => ({id: input.id, label: input.label, status: input.status, required_before: input.required_before, value_present: input.value !== null && input.value !== ""})),
  next_actions: [
    {id: "visual_capture_and_signoff", owner: "视觉负责人", status: "pending_manual_visual_signoff", evidence: "reference-evidence/runtime-matrix/manifest.json"},
    {id: "final_asset_rights_signoff", owner: "美术/音频/权利负责人", status: "pending", evidence: "docs/asset-production-manifest.json"},
    {id: "windows_device_qa", owner: "发布工程负责人", status: "pending", evidence: "docs/windows-device-qa-runbook.md"},
    {id: "store_owner_inputs", owner: "产品/发行/法务负责人", status: "pending_user_confirmation", evidence: "docs/release-owner-inputs.json"},
  ],
  forbidden_content: ["reference-evidence/video-1/", "reference-evidence/video-2/", "参考视频", "未授权商业资产"],
};

fs.writeFileSync(outputPath, `${JSON.stringify(index, null, 2)}\n`, "utf8");
console.log(`商店提交证据索引已生成：${path.relative(workspaceRoot, outputPath)}；状态 ${index.status}；门禁 ${index.gate_matrix.length} 项；待负责人字段 ${storeMaterials.unresolved_count} 个`);

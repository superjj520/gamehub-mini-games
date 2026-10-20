import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const runFlagIndex = process.argv.indexOf("--run");
const buildManifestFlagIndex = process.argv.indexOf("--build-manifest");
const evidenceRootFlagIndex = process.argv.indexOf("--evidence-root");
const requestedRun = runFlagIndex >= 0 ? process.argv[runFlagIndex + 1] : null;
const buildManifestPath = path.resolve(root, buildManifestFlagIndex >= 0
  ? (process.argv[buildManifestFlagIndex + 1] ?? "")
  : "reference-evidence/candidate-runtime/full-candidate-windows-build.json");
const configuredEvidenceRoot = evidenceRootFlagIndex >= 0
  ? (process.argv[evidenceRootFlagIndex + 1] ?? "")
  : "reference-evidence/candidate-windows-device-qa";
const evidenceRoot = path.resolve(root, configuredEvidenceRoot);

const expectedSegments = [
  "city-01", "city-02", "city-03", "city-04", "city-05", "city-06", "city-07", "city-08", "city-09", "city-10", "city-11",
  "office-01", "office-02", "office-03", "office-04", "office-05", "office-06", "office-07", "office-08", "office-09", "office-10",
];
const expectedExpandedIds = [
  "launcher-cold-boot", "launcher-focus-navigation", "global-crash-recovery-prompt",
  "office-success-feedback", "office-search-loop", "office-failure-overlay", "office-checkpoint-recovery",
  "office-pause-overlay", "global-audio-disabled-fallback", "office-resolution-variants",
  "global-missing-asset-blocked", "city-store-transition", "city-crowd-variants", "city-traffic-near-miss",
  "city-neighborhood-extension", "city-weather-lighting-extension", "city-vehicle-damage-feedback", "city-delivery-completion",
];

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function hash(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function pngDimensions(filePath) {
  const bytes = fs.readFileSync(filePath);
  assert(bytes.subarray(0, 8).toString("hex") === "89504e470d0a1a0a", `不是有效 PNG：${filePath}`);
  assert(bytes.toString("ascii", 12, 16) === "IHDR", `PNG 缺少 IHDR：${filePath}`);
  return {width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), bytes: bytes.length};
}

function chooseRun() {
  if (requestedRun) return path.resolve(root, requestedRun);
  const candidates = fs.existsSync(evidenceRoot)
    ? fs.readdirSync(evidenceRoot, {withFileTypes: true})
      .filter((entry) => entry.isDirectory() && entry.name.startsWith("complete-run-"))
      .map((entry) => path.join(evidenceRoot, entry.name))
      .sort()
      .reverse()
    : [];
  const candidate = candidates.find((directory) => fs.existsSync(path.join(directory, "windows-complete-qa.json")));
  if (!candidate) throw new Error(`未找到完整 Windows QA 编排记录：${evidenceRoot}`);
  return candidate;
}

function assertInside(parent, candidate, label) {
  const relative = path.relative(path.resolve(parent), path.resolve(candidate));
  assert(relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative)), `${label} 路径越界：${candidate}`);
}

function resolveReference(value, runDirectory) {
  if (typeof value !== "string" || value.trim().length === 0) return null;
  const normalized = value.replaceAll("\\", "/");
  const candidates = [
    path.resolve(runDirectory, normalized),
    path.resolve(runDirectory, path.basename(normalized)),
    path.resolve(root, normalized),
    path.resolve(root, path.basename(normalized)),
  ];
  return candidates.find((candidate) => fs.existsSync(candidate) && (() => {
    try {
      assertInside(runDirectory, candidate, "证据文件");
      return true;
    } catch {
      return false;
    }
  })()) ?? null;
}

function verifyBuildIdentity(record, buildManifest, label) {
  assert(record?.build?.path === buildManifest.build.path, `${label} 构建路径与当前清单不一致`);
  assert(record?.build?.bytes === buildManifest.build.bytes, `${label} 构建字节数与当前清单不一致`);
  assert(record?.build?.sha256 === buildManifest.build.sha256, `${label} 构建 SHA-256 与当前清单不一致`);
  assert(record?.evidence_contract?.source?.sha256 === buildManifest.package.source_sha256, `${label} 正式源指纹不一致`);
  assert(record?.evidence_contract?.source?.file_count === buildManifest.package.source_file_count, `${label} 正式源文件数不一致`);
  assert(record?.evidence_contract?.candidate_package?.sha256 === buildManifest.package.sha256, `${label} 候选包指纹不一致`);
  assert(record?.evidence_contract?.candidate_package?.file_count === buildManifest.package.file_count, `${label} 候选包文件数不一致`);
}

function expectedAssetCatalog(buildManifest) {
  return buildManifest.candidate_variant === "original_only"
    ? "res://content/asset-runtime-catalog-original-only.json"
    : "res://tests/asset-runtime-catalog-full-candidates.json";
}

function verifyScreenshot(value, expectedHash, expectedWidth, expectedHeight, runDirectory, label) {
  const filePath = resolveReference(value, runDirectory);
  assert(filePath, `${label} 文件不存在`);
  const dimensions = pngDimensions(filePath);
  assert(dimensions.width === expectedWidth && dimensions.height === expectedHeight, `${label} 尺寸不一致：${dimensions.width}x${dimensions.height}`);
  assert(expectedHash === hash(filePath), `${label} SHA-256 不一致`);
}

function verifyDeviceStage(stageDirectory, buildManifest) {
  const recordPath = path.join(stageDirectory, "windows-device-qa.json");
  assert(fs.existsSync(recordPath), `设备 QA 阶段缺少 windows-device-qa.json：${stageDirectory}`);
  const record = readJson(recordPath);
  assert(["unverified_manual_signoff_required", "failed_qa_unverified", "failed_cleanup_unverified"].includes(record.status), `设备 QA 阶段状态异常：${record.status}`);
  verifyBuildIdentity(record, buildManifest, "设备 QA");
  assert(record.manual_signoff?.visual === "pending", "设备 QA 不得自动写入视觉签收");
  if (record.status !== "unverified_manual_signoff_required") {
    assert(typeof record.error === "string" && record.error.length > 0, "设备 QA 失败状态缺少错误原因");
    return false;
  }
  const scenarios = new Map((record.scenarios ?? []).map((scenario) => [scenario.scenario, scenario]));
  for (const scenarioName of ["office", "city"]) {
    const scenario = scenarios.get(scenarioName);
    assert(scenario, `设备 QA 缺少场景记录：${scenarioName}`);
    verifyScreenshot(scenario.launcher_screenshot, scenario.launcher_screenshot_sha256, scenario.launcher_screenshot_width, scenario.launcher_screenshot_height, stageDirectory, `${scenarioName} 启动器截图`);
    assert(scenario.process_alive_after_actions === true, `${scenarioName} 动作后进程没有保持存活`);
    for (const action of scenario.actions ?? []) {
      if (action.status === "window_not_focused") throw new Error(`${scenarioName} 动作未成功发送：${action.action}`);
      assert(action.status === "sent", `${scenarioName} 动作状态异常：${action.action}`);
      verifyScreenshot(action.screenshot, action.screenshot_sha256, action.screenshot_width, action.screenshot_height, stageDirectory, `${scenarioName} 动作 ${action.action} 截图`);
    }
  }
  assert(record.crash_recovery?.process_alive === true, "设备 QA 缺少异常恢复存活记录");
  verifyScreenshot(record.crash_recovery.screenshot, record.crash_recovery.screenshot_sha256, record.crash_recovery.screenshot_width, record.crash_recovery.screenshot_height, stageDirectory, "异常恢复截图");
  assert(Array.isArray(record.cleanup_failures) && record.cleanup_failures.length === 0, "设备 QA 存在进程清理失败");
  return true;
}

function verifyMatrixStage(stageDirectory, buildManifest) {
  const recordPath = path.join(stageDirectory, "windows-reference-matrix.json");
  assert(fs.existsSync(recordPath), `参考矩阵阶段缺少 windows-reference-matrix.json：${stageDirectory}`);
  const record = readJson(recordPath);
  verifyBuildIdentity(record, buildManifest, "参考矩阵");
  assert(record.asset_catalog_path === expectedAssetCatalog(buildManifest), "参考矩阵资产目录与 Windows 构建变体不一致");
  assert(record.manual_visual_signoff === "pending", "参考矩阵不得自动写入视觉签收");
  if (record.status !== "unverified_pending_visual_signoff") {
    assert(record.status === "failed_capture_unverified", `参考矩阵阶段状态异常：${record.status}`);
    assert(Array.isArray(record.failures) && record.failures.length > 0, "参考矩阵失败状态缺少失败清单");
    return false;
  }
  assert(Array.isArray(record.captures) && record.captures.length === expectedSegments.length, "参考矩阵没有完整 21 段记录");
  const captures = new Map(record.captures.map((capture) => [capture.id, capture]));
  for (const id of expectedSegments) {
    const capture = captures.get(id);
    assert(capture, `参考矩阵缺少分段：${id}`);
    assert(capture.visual_status === "unverified", `参考矩阵不得自动通过视觉：${id}`);
    verifyScreenshot(capture.path, capture.sha256, 1280, 720, stageDirectory, `参考矩阵 ${id}`);
  }
  return true;
}

function verifyExpandedStage(stageDirectory, buildManifest) {
  const recordPath = path.join(stageDirectory, "windows-expanded-visual-run.json");
  assert(fs.existsSync(recordPath), `扩展视觉阶段缺少 windows-expanded-visual-run.json：${stageDirectory}`);
  const record = readJson(recordPath);
  verifyBuildIdentity(record, buildManifest, "扩展视觉");
  assert(record.asset_catalog_path === expectedAssetCatalog(buildManifest), "扩展视觉资产目录与 Windows 构建变体不一致");
  assert(record.manual_visual_signoff === "pending", "扩展视觉不得自动写入视觉签收");
  if (record.status !== "unverified_pending_visual_signoff") {
    assert(record.status === "failed_capture_unverified", `扩展视觉阶段状态异常：${record.status}`);
    assert(typeof record.failure === "string" && record.failure.length > 0, "扩展视觉失败状态缺少失败原因");
    return false;
  }
  assert(record.expected_capture_count === expectedExpandedIds.length, "扩展视觉预期数量不是 18");
  assert(Array.isArray(record.captures) && record.captures.length === expectedExpandedIds.length, "扩展视觉没有完整 18 项记录");
  const captures = new Map(record.captures.map((capture) => [capture.id, capture]));
  for (const id of expectedExpandedIds) {
    const capture = captures.get(id);
    assert(capture, `扩展视觉缺少项目：${id}`);
    assert(capture.visual_status === "unverified", `扩展视觉不得自动通过：${id}`);
    verifyScreenshot(capture.path, capture.sha256, 1280, 720, stageDirectory, `扩展视觉 ${id}`);
  }
  return true;
}

try {
  const runDirectory = chooseRun();
  assertInside(evidenceRoot, runDirectory, "完整 QA 运行目录");
  const recordPath = path.join(runDirectory, "windows-complete-qa.json");
  assert(fs.existsSync(recordPath), `缺少完整 Windows QA 编排记录：${recordPath}`);
  const record = readJson(recordPath);
  const buildManifest = readJson(buildManifestPath);
  assert(record.schema_version === 1, "完整 Windows QA 编排记录 schema_version 必须为 1");
  assert(record.visual_status === "unverified" && record.target_device_status === "unverified", "完整 Windows QA 不得自动通过视觉或目标设备");
  assert(record.manual_signoff?.visual === "pending", "完整 Windows QA 不得写入视觉签收");
  verifyBuildIdentity(record, buildManifest, "完整 Windows QA");
  assert(record.asset_catalog_path === expectedAssetCatalog(buildManifest), "完整 Windows QA 资产目录与 Windows 构建变体不一致");
  const expectedStages = new Map([
    ["runtime_device_qa", "run-"],
    ["reference_matrix", "matrix-run-"],
    ["expanded_visual_matrix", "expanded-run-"],
  ]);
  assert(Array.isArray(record.stages) && record.stages.length === expectedStages.size, "完整 Windows QA 必须包含 3 个阶段");
  const results = [];
  for (const stage of record.stages) {
    assert(expectedStages.has(stage.name), `未知完整 Windows QA 阶段：${stage.name}`);
    assert(stage.script === `scripts/${stage.name === "runtime_device_qa" ? "windows_device_qa.ps1" : stage.name === "reference_matrix" ? "windows_reference_matrix_capture.ps1" : "windows_expanded_visual_capture.ps1"}`, `阶段脚本绑定异常：${stage.name}`);
    assert(typeof stage.run_directory === "string" && stage.run_directory.length > 0, `阶段缺少运行目录：${stage.name}`);
    const stageDirectory = path.resolve(root, stage.run_directory);
    assertInside(evidenceRoot, stageDirectory, `阶段 ${stage.name}`);
    assert(path.basename(stageDirectory).startsWith(expectedStages.get(stage.name)), `阶段运行目录前缀异常：${stage.name}`);
    const passed = stage.name === "runtime_device_qa"
      ? verifyDeviceStage(stageDirectory, buildManifest)
      : stage.name === "reference_matrix"
        ? verifyMatrixStage(stageDirectory, buildManifest)
        : verifyExpandedStage(stageDirectory, buildManifest);
    results.push({name: stage.name, passed});
    assert((stage.status === "passed_unverified") === passed, `阶段 ${stage.name} 编排状态与实际证据不一致`);
  }
  const allPassed = results.every((result) => result.passed);
  assert((record.status === "stages_completed_unverified") === allPassed, "完整 QA 顶层状态与阶段结果不一致");
  if (!allPassed) throw new Error(`完整 Windows QA 证据存在失败阶段：${results.filter((result) => !result.passed).map((result) => result.name).join("、")}`);
  console.log("完整 Windows QA 证据验证通过：3 个阶段；21 段参考矩阵、18 项扩展视觉和设备截图均已逐项校验；视觉仍为 unverified");
} catch (error) {
  console.error(`完整 Windows QA 证据核验失败：${error.message}`);
  process.exitCode = 1;
}

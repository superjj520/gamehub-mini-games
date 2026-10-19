import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const workspaceRoot = process.cwd();
const args = new Set(process.argv.slice(2));
const strict = args.has("--strict");
const fullCandidate = args.has("--candidate");
const rootArgIndex = process.argv.indexOf("--root");
const runArgIndex = process.argv.indexOf("--run");
const buildManifestArgIndex = process.argv.indexOf("--build-manifest");
const buildManifestRelativePath = buildManifestArgIndex >= 0
  ? (process.argv[buildManifestArgIndex + 1] ?? "")
  : (fullCandidate
    ? "reference-evidence/candidate-runtime/full-candidate-windows-build.json"
    : "docs/windows-build-manifest.json");
const evidenceBase = rootArgIndex >= 0
  ? path.resolve(process.argv[rootArgIndex + 1] ?? "")
  : path.resolve(workspaceRoot, fullCandidate ? "reference-evidence/candidate-windows-device-qa" : "reference-evidence/windows-device-qa");
const requestedRun = runArgIndex >= 0 ? process.argv[runArgIndex + 1] : null;

function fail(message) {
  console.error(`Windows 设备 QA 证据核验失败：${message}`);
}

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`${filePath}：${error.message}`);
  }
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function readPngDimensions(filePath) {
  const bytes = fs.readFileSync(filePath);
  if (bytes.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a" || bytes.toString("ascii", 12, 16) !== "IHDR") {
    throw new Error(`不是有效 PNG：${filePath}`);
  }
  return {width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20)};
}

function normalizeName(filePath) {
  return path.basename(String(filePath).replaceAll("\\", "/")).toLowerCase();
}

function resolveEvidenceFile(value, runDirectory) {
  if (typeof value !== "string" || value.length === 0) return null;
  const candidates = [
    path.resolve(workspaceRoot, value),
    path.resolve(runDirectory, path.basename(value)),
    path.resolve(runDirectory, value),
  ];
  const runRoot = path.resolve(runDirectory);
  return candidates.find((candidate) => {
    if (!fs.existsSync(candidate)) return false;
    const relative = path.relative(runRoot, candidate);
    return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
  }) ?? null;
}

function assertFileEvidence(value, expectedHash, label, runDirectory, errors) {
  const filePath = resolveEvidenceFile(value, runDirectory);
  if (!filePath) {
    errors.push(`${label} 文件不存在：${value ?? "未提供"}`);
    return;
  }
  if (typeof expectedHash !== "string" || expectedHash.length !== 64) {
    errors.push(`${label} 缺少有效 SHA-256`);
    return;
  }
  const actualHash = sha256(filePath);
  if (actualHash !== expectedHash.toLowerCase()) {
    errors.push(`${label} SHA-256 不匹配：记录 ${expectedHash}，实际 ${actualHash}`);
  }
}

function assertScreenshotEvidence(value, expectedHash, expectedWidth, expectedHeight, label, runDirectory, errors) {
  assertFileEvidence(value, expectedHash, label, runDirectory, errors);
  const filePath = resolveEvidenceFile(value, runDirectory);
  if (!filePath) return;
  try {
    const dimensions = readPngDimensions(filePath);
    if (!Number.isInteger(expectedWidth) || !Number.isInteger(expectedHeight)) {
      errors.push(`${label} 缺少客户区尺寸记录`);
      return;
    }
    if (dimensions.width !== expectedWidth || dimensions.height !== expectedHeight) {
      errors.push(`${label} 尺寸记录与 PNG 不一致：记录 ${expectedWidth}x${expectedHeight}，实际 ${dimensions.width}x${dimensions.height}`);
    }
    if (dimensions.width / dimensions.height < 1.6 || dimensions.width / dimensions.height > 1.85) {
      errors.push(`${label} 不是可用于参考视频对照的宽屏客户区：${dimensions.width}x${dimensions.height}`);
    }
  } catch (error) {
    errors.push(`${label} PNG 尺寸读取失败：${error.message}`);
  }
}

function listRunDirectories() {
  if (!fs.existsSync(evidenceBase)) return [];
  return fs.readdirSync(evidenceBase, {withFileTypes: true})
    .filter((entry) => entry.isDirectory() && entry.name.startsWith("run-"))
    .map((entry) => path.join(evidenceBase, entry.name))
    .sort()
    .reverse();
}

function chooseRunDirectory() {
  if (requestedRun) {
    const candidate = path.resolve(workspaceRoot, requestedRun);
    if (!fs.existsSync(path.join(candidate, "windows-device-qa.json"))) {
      throw new Error(`指定目录没有 windows-device-qa.json：${candidate}`);
    }
    return candidate;
  }
  const candidate = listRunDirectories().find((directory) => fs.existsSync(path.join(directory, "windows-device-qa.json")));
  if (!candidate) throw new Error(`未找到 Windows 设备 QA 运行目录：${evidenceBase}`);
  return candidate;
}

function validateRecord(record, runDirectory, buildManifest) {
  const errors = [];
  const warnings = [];
  if (record.schema_version !== 1) errors.push(`schema_version 必须为 1，实际为 ${record.schema_version}`);

  const allowedStatuses = new Set([
    "unverified_manual_signoff_required",
    "failed_qa_unverified",
    "failed_cleanup_unverified",
    "passed_manual_signoff",
  ]);
  if (!allowedStatuses.has(record.status)) errors.push(`未知状态：${record.status}`);
  if (record.status === "failed_qa_unverified" || record.status === "failed_cleanup_unverified") {
    errors.push(`记录自身已报告失败状态：${record.status}`);
  }

  const build = record.build ?? {};
  const matchingPreset = fullCandidate
    ? (
      normalizeName(buildManifest.build?.path) === normalizeName(build.path)
      && buildManifest.build.sha256 === String(build.sha256 ?? "").toLowerCase()
      && buildManifest.build.bytes === build.bytes
        ? {name: "新时代觉醒者完整候选 Windows 构建", path: buildManifest.build.path}
        : null
    )
    : buildManifest.presets.find((preset) =>
        normalizeName(preset.path) === normalizeName(build.path)
        && preset.sha256 === String(build.sha256 ?? "").toLowerCase()
        && preset.bytes === build.bytes
        && preset.includes_tests === false
        && /首发候选/.test(preset.name),
      );
  if (!matchingPreset) {
    errors.push(fullCandidate
      ? `完整候选 QA 构建必须同时匹配 ${buildManifestRelativePath} 的文件名、字节数和 SHA-256`
      : "QA 构建必须绑定 docs/windows-build-manifest.json 中 includes_tests=false 的 Windows 首发候选构建，且文件名、字节数和 SHA-256 必须同时匹配");
  }

  if (fullCandidate) {
    const evidenceContract = record.evidence_contract ?? {};
    const expectedSource = buildManifest.package ?? {};
    if (evidenceContract.build_manifest !== buildManifestRelativePath.replaceAll("\\", "/")) {
      errors.push("QA 记录缺少完整候选 Windows 构建清单绑定");
    }
    if (evidenceContract.source?.sha256 !== expectedSource.source_sha256 || evidenceContract.source?.file_count !== expectedSource.source_file_count) {
      errors.push("QA 记录的正式运行时源指纹与 Windows 构建清单不一致");
    }
    if (evidenceContract.candidate_package?.sha256 !== expectedSource.sha256 || evidenceContract.candidate_package?.file_count !== expectedSource.file_count) {
      errors.push("QA 记录的候选包指纹与 Windows 构建清单不一致");
    }
  }

  const screen = record.system?.screen ?? {};
  if (!Number.isInteger(screen.width) || !Number.isInteger(screen.height)) {
    errors.push("缺少有效主屏宽高");
  } else if (screen.target_1080p !== (screen.width === 1920 && screen.height === 1080)) {
    errors.push("target_1080p 与记录的主屏宽高不一致");
  }

  const expectedScenarios = ["office", "city"];
  const scenarios = new Map((record.scenarios ?? []).map((scenario) => [scenario.scenario, scenario]));
  for (const scenarioName of expectedScenarios) {
    const scenario = scenarios.get(scenarioName);
    if (!scenario) {
      errors.push(`缺少场景证据：${scenarioName}`);
      continue;
    }
    assertScreenshotEvidence(
      scenario.launcher_screenshot,
      scenario.launcher_screenshot_sha256,
      scenario.launcher_screenshot_width,
      scenario.launcher_screenshot_height,
      `${scenarioName} 启动器截图`,
      runDirectory,
      errors,
    );
    if (scenario.process_alive_after_actions !== true) {
      errors.push(`${scenarioName} 动作结束后进程没有被记录为存活`);
    }
    const expectedActions = scenarioName === "office"
      ? ["1", "w", "c", "e", "r", "l", "{ESC}"]
      : ["2", "w", "c", "e", "r", "l", "{ESC}"];
    const actions = scenario.actions ?? [];
    if (actions.length !== expectedActions.length) {
      errors.push(`${scenarioName} 动作数量应为 ${expectedActions.length}，实际为 ${actions.length}`);
    }
    for (let index = 0; index < expectedActions.length; index += 1) {
      const action = actions[index];
      if (!action || action.action !== expectedActions[index]) {
        errors.push(`${scenarioName} 第 ${index + 1} 个动作顺序不正确`);
        continue;
      }
      if (action.status === "window_not_focused") {
        warnings.push(`${scenarioName} 动作 ${action.action} 没有发送，窗口未确认位于前台`);
        continue;
      }
      if (action.status !== "sent") {
        errors.push(`${scenarioName} 动作 ${action.action} 状态未知：${action.status}`);
        continue;
      }
      assertScreenshotEvidence(action.screenshot, action.screenshot_sha256, action.screenshot_width, action.screenshot_height, `${scenarioName} 动作 ${action.action} 截图`, runDirectory, errors);
    }
  }

  const recovery = record.crash_recovery;
  if (!recovery) {
    errors.push("缺少崩溃探针重新启动证据");
  } else {
    if (recovery.process_alive !== true) errors.push("崩溃探针重新启动后进程没有被记录为存活");
    assertScreenshotEvidence(recovery.screenshot, recovery.screenshot_sha256, recovery.screenshot_width, recovery.screenshot_height, "崩溃探针恢复截图", runDirectory, errors);
  }

  const cleanupFailures = record.cleanup_failures ?? [];
  if (!Array.isArray(cleanupFailures) || cleanupFailures.length > 0) {
    errors.push("QA 记录包含进程清理失败");
  }

  const requiredSignoffs = ["visual", "keyboard", "gamepad", "save_load", "performance"];
  const signoff = record.manual_signoff ?? {};
  for (const key of requiredSignoffs) {
    if (!["pending", "passed", "failed"].includes(signoff[key])) {
      errors.push(`manual_signoff.${key} 不是允许的状态`);
    }
  }
  if (strict) {
    if (record.status !== "passed_manual_signoff") errors.push("严格模式要求 status=passed_manual_signoff");
    for (const key of requiredSignoffs) {
      if (signoff[key] !== "passed") errors.push(`严格模式要求 manual_signoff.${key}=passed`);
    }
    if (screen.target_1080p !== true) errors.push("严格模式要求目标设备为 1920x1080");
    const inputDevices = record.system?.input_devices;
    if (!Array.isArray(inputDevices) || inputDevices.length === 0) {
      errors.push("严格模式要求系统识别至少一个手柄或控制器");
    }
    for (const scenarioName of expectedScenarios) {
      for (const action of scenarios.get(scenarioName)?.actions ?? []) {
        if (action.status !== "sent") errors.push(`严格模式要求 ${scenarioName} 的每个动作均成功发送`);
      }
    }
  } else if (record.status === "unverified_manual_signoff_required") {
    warnings.push("结构化证据有效，但仍需要人工视觉、输入、存档和性能签收；本次不代表发布通过");
  }

  return {errors, warnings, matchingPreset};
}

try {
  const runDirectory = chooseRunDirectory();
  const recordPath = path.join(runDirectory, "windows-device-qa.json");
  const record = readJson(recordPath);
  const buildManifest = readJson(path.resolve(workspaceRoot, fullCandidate
    ? buildManifestRelativePath
    : "docs/windows-build-manifest.json"));
  const result = validateRecord(record, runDirectory, buildManifest);
  if (result.errors.length > 0) {
    for (const error of result.errors) fail(error);
    process.exitCode = 1;
  } else {
    console.log(`${fullCandidate ? "完整候选" : "首发候选"} Windows 设备 QA 证据结构核验通过：${runDirectory}`);
    console.log(`绑定构建：${result.matchingPreset.name}`);
    for (const warning of result.warnings) console.log(`- ${warning}`);
    if (strict) console.log("严格模式通过：允许进入发布前置门禁的下一步，但不替代商店、权利和视觉矩阵门禁");
  }
} catch (error) {
  fail(error.message);
  process.exitCode = 1;
}

import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const scriptPath = path.join(root, "scripts/windows_complete_qa.ps1");
const source = fs.readFileSync(scriptPath, "utf8");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const requiredParameters = [
  "[string]$BuildPath = \"\"",
  "[string]$EvidenceRoot = \"\"",
  "[string]$BuildManifestPath = \"\"",
  "[string]$AssetCatalogPath = \"\"",
  "[ValidateSet(\"完整候选\", \"原创边界候选\")]",
  "[string]$BuildKind = \"完整候选\"",
];
for (const parameter of requiredParameters) {
  assert(source.includes(parameter), `Windows 完整 QA 编排器缺少参数：${parameter}`);
}

const stageContracts = [
  {
    name: "runtime_device_qa",
    script: "windows_device_qa.ps1",
    prefix: "run-",
    requiredArguments: ["\"-BuildPath\", $BuildPath", "\"-EvidenceRoot\", $EvidenceRoot", "\"-BuildManifestPath\", $buildManifestPath", "\"-BuildKind\", $BuildKind"],
  },
  {
    name: "reference_matrix",
    script: "windows_reference_matrix_capture.ps1",
    prefix: "matrix-run-",
    requiredArguments: ["\"-BuildPath\", $BuildPath", "\"-EvidenceRoot\", $EvidenceRoot", "\"-BuildManifestPath\", $buildManifestPath", "\"-AssetCatalogPath\", $AssetCatalogPath"],
  },
  {
    name: "expanded_visual_matrix",
    script: "windows_expanded_visual_capture.ps1",
    prefix: "expanded-run-",
    requiredArguments: ["\"-BuildPath\", $BuildPath", "\"-EvidenceRoot\", $EvidenceRoot", "\"-BuildManifestPath\", $buildManifestPath", "\"-AssetCatalogPath\", $AssetCatalogPath"],
  },
];

for (const stage of stageContracts) {
  assert(source.includes(`Invoke-QaStage \"${stage.name}\" \"${stage.script}\"`), `Windows 完整 QA 缺少阶段：${stage.name}`);
  assert(source.includes(`) \"${stage.prefix}\"`), `Windows 完整 QA 阶段缺少运行目录前缀：${stage.name}`);
  for (const argument of stage.requiredArguments) {
    assert(source.includes(argument), `Windows 完整 QA 阶段 ${stage.name} 缺少参数传递：${argument}`);
  }
}

assert(source.includes("$stages.Count"), "Windows 完整 QA 没有按阶段数量汇总结果");
assert(source.includes("failed_unverified"), "Windows 完整 QA 没有保留失败阶段状态");
assert(source.includes("asset_catalog_path = $AssetCatalogPath"), "Windows 完整 QA 顶层记录没有保存资源目录绑定");
assert(source.includes("windows-complete-qa.json"), "Windows 完整 QA 没有写入顶层编排记录");
assert(source.includes("视觉状态保持 unverified"), "Windows 完整 QA 没有明确禁止自动视觉通过");

console.log("Windows 完整 QA 编排器契约通过：同一构建清单、证据目录和资源目录已绑定到 3 个阶段；视觉仍保持 unverified");

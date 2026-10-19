import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const runtimeRoot = path.join(root, "gta-reference-runtime");
const reportPath = path.join(root, "docs", "scene-completeness-report.json");

const cityStates = Array.from({ length: 11 }, (_, index) => `city-${String(index + 1).padStart(2, "0")}`);
const officeStates = Array.from({ length: 10 }, (_, index) => `office-${String(index + 1).padStart(2, "0")}`);
const coreStates = [...cityStates, ...officeStates];

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function sourceFingerprint() {
  const ignoredDirectories = new Set([".godot", ".import"]);
  const ignoredExtensions = new Set([".gdc", ".remap", ".import", ".uid"]);
  const files = [];

  function collect(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (entry.isDirectory() && ignoredDirectories.has(entry.name)) continue;
      const absolutePath = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        collect(absolutePath);
      } else if (entry.isFile() && ![...ignoredExtensions].some((extension) => entry.name.endsWith(extension))) {
        files.push(absolutePath);
      }
    }
  }

  collect(runtimeRoot);
  const hash = crypto.createHash("sha256");
  for (const absolutePath of files) {
    const relativePath = path.relative(runtimeRoot, absolutePath).split(path.sep).join("/");
    hash.update(relativePath);
    hash.update("\0");
    hash.update(fs.readFileSync(absolutePath));
    hash.update("\0");
  }
  return { sha256: hash.digest("hex"), file_count: files.length };
}

function stateCoverage(states, visualSource, runtimeSource, referenceCaptures) {
  const visualBuilderPresent = states.filter((state) => visualSource.includes(`"${state}"`));
  const runtimeSelectorPresent = states.filter((state) => runtimeSource.includes(`"${state}"`));
  const referenceRecordPresent = states.filter((state) => referenceCaptures.has(state));
  const visualContracts = new Map();
  const contractPattern = /set_meta\("visual_state_contract",\s*\{\s*"state":\s*"([^"]+)"([\s\S]*?)\}\)/g;
  for (const match of visualSource.matchAll(contractPattern)) {
    const state = match[1];
    const layerMatch = match[2].match(/"required_layers":\s*\[([^\]]*)\]/);
    const layers = layerMatch
      ? [...layerMatch[1].matchAll(/"([^"]+)"/g)].map((layer) => layer[1])
      : [];
    visualContracts.set(state, layers);
  }
  // 某些状态由同一构建器按运行时参数切换（例如 city-06/07、city-08/09，
  // 以及办公室的工位/对话构建器）。静态解析必须把这些调用点展开，否则
  // 会把“有独立合同的共享构建器”误判成缺失场景。
  const sharedContractGroups = [
    {
      states: ["city-06", "city-07"],
      present: /"state":\s*"city-07"\s*if\s+scanned\s+else\s+"city-06"/.test(visualSource),
      layers: ["registration_desk", "qr_panel", "feedback_light"],
    },
    {
      states: ["city-08", "city-09"],
      present: /"state":\s*"city-09"\s*if\s+traffic\s+else\s+"city-08"/.test(visualSource),
      layers: ["road", "lane_marking", "curb", "street_lights"],
    },
    {
      states: ["office-01", "office-10"],
      present: /func _build_workstation_state[\s\S]*?"state":\s*state_id[\s\S]*?"required_layers":\s*\[[^\]]+\]/.test(visualSource),
      layers: ["workstation", "monitor", "chair", "warm_light", "background_depth", "contact_detail", "office_detail"],
    },
    {
      states: ["office-08", "office-09"],
      present: /func _build_dialogue_state[\s\S]*?"state":\s*state_id[\s\S]*?"required_layers":\s*\[[^\]]+\]/.test(visualSource),
      layers: ["corridor", "window_band", "alert_edge", "dialogue_light", "window_frame", "floor_detail", "conversation_staging"],
    },
    {
      states: ["office-05", "office-06"],
      present: /"state":\s*"office-06"\s*if\s+active_call\s+else\s+"office-05"/.test(visualSource),
      layers: ["elevator_doors", "floor_indicator", "call_panel", "warm_light"],
    },
  ];
  for (const group of sharedContractGroups) {
    if (!group.present) continue;
    for (const state of group.states) visualContracts.set(state, group.layers);
  }
  const visualContractPresent = states.filter((state) => visualContracts.has(state));
  const missingVisualContracts = states.filter((state) => !visualContracts.has(state));
  const emptyVisualContractLayers = states.filter((state) => visualContracts.has(state) && visualContracts.get(state).length === 0);
  return {
    expected: states.length,
    visual_builder_present: visualBuilderPresent.length,
    runtime_selector_present: runtimeSelectorPresent.length,
    reference_record_present: referenceRecordPresent.length,
    visual_contract_present: visualContractPresent.length,
    missing_visual_contracts: missingVisualContracts,
    empty_visual_contract_layers: emptyVisualContractLayers,
    missing_visual_builders: states.filter((state) => !visualBuilderPresent.includes(state)),
    missing_runtime_selectors: states.filter((state) => !runtimeSelectorPresent.includes(state)),
    missing_reference_records: states.filter((state) => !referenceRecordPresent.includes(state)),
    visual_builder_states: visualBuilderPresent,
    runtime_selector_states: runtimeSelectorPresent,
    reference_record_states: referenceRecordPresent,
    visual_contract_layers: Object.fromEntries(
      states
        .filter((state) => visualContracts.has(state))
        .map((state) => [state, visualContracts.get(state)]),
    ),
  };
}

function buildSceneMatrix(scope, states, coverage, currentEvidenceBound, behaviorEvidenceBound) {
  return states.map((state) => {
    const sceneAssemblyPassed = (
      coverage.visual_builder_states?.includes(state)
      && coverage.runtime_selector_states?.includes(state)
      && coverage.visual_contract_present >= coverage.expected
      && !coverage.empty_visual_contract_layers?.includes(state)
    );
    return {
      id: state,
      scope,
      scene_assembly: sceneAssemblyPassed ? "passed" : "incomplete",
      behavior_evidence: behaviorEvidenceBound ? "passed_graybox" : "unverified",
      visual_builder: coverage.visual_builder_states?.includes(state) ? "present" : "missing",
      runtime_selector: coverage.runtime_selector_states?.includes(state) ? "present" : "missing",
      visual_contract_layers: coverage.visual_contract_layers?.[state] ?? [],
      reference_record: coverage.reference_record_states?.includes(state) ? "registered" : "missing",
      current_source_binding: currentEvidenceBound ? "current" : "stale_or_missing",
      current_source_visual_capture: "unverified",
      visual_acceptance: "unverified",
      final_asset_signoff: "blocked_global_asset_gate",
      next_action: scope === "office"
        ? "当前源真实窗口采集→逐帧对照→人工视觉签收"
        : "办公室首发范围完成后，当前源真实窗口采集→逐帧对照→人工视觉签收",
    };
  });
}

const cityVisualSource = read("gta-reference-runtime/scripts/city_scene_visuals.gd");
const officeVisualSource = read("gta-reference-runtime/scripts/office_scene_visuals.gd");
const cityRuntimeSource = read("gta-reference-runtime/scripts/city_demo.gd");
const officeRuntimeSource = read("gta-reference-runtime/scripts/benchmark_scene.gd");
const runtimeManifest = JSON.parse(read("reference-evidence/runtime-matrix/manifest.json"));
const behaviorManifest = JSON.parse(read("reference-evidence/current-runtime-behavior/manifest.json"));
const expandedMatrix = JSON.parse(read("docs/expanded-visual-acceptance-matrix.json"));
const runtimeProbePath = path.join(root, "reference-evidence/candidate-runtime/scene-visual-runtime-completeness.json");
const runtimeVisualProbe = fs.existsSync(runtimeProbePath)
  ? JSON.parse(fs.readFileSync(runtimeProbePath, "utf8"))
  : {status: "missing", state_count: 0, expected_state_count: coreStates.length};
const current = sourceFingerprint();
const referenceCaptures = new Set((runtimeManifest.captures ?? []).map((capture) => capture.id));
const manifestFingerprints = [...new Set((runtimeManifest.captures ?? []).map((capture) => capture.source_fingerprint).filter(Boolean))];

const city = stateCoverage(cityStates, cityVisualSource, cityRuntimeSource, referenceCaptures);
const office = stateCoverage(officeStates, officeVisualSource, officeRuntimeSource, referenceCaptures);
const behaviorEvidenceBound = (
  behaviorManifest.status === "current_behavior_matrix_verified"
  && behaviorManifest.source_fingerprint === current.sha256
);
const coreSceneAssemblyPassed = [city, office].every((scope) => (
  scope.visual_builder_present === scope.expected
  && scope.runtime_selector_present === scope.expected
  && scope.visual_contract_present === scope.expected
  && scope.empty_visual_contract_layers.length === 0
));
const currentEvidenceBound = manifestFingerprints.length === 1 && manifestFingerprints[0] === current.sha256;
const sceneMatrix = [
  ...buildSceneMatrix("office", officeStates, office, currentEvidenceBound, behaviorEvidenceBound),
  ...buildSceneMatrix("city", cityStates, city, currentEvidenceBound, behaviorEvidenceBound),
];

const report = {
  schema_version: 1,
  generated_at: new Date().toISOString(),
  source: current,
  status: coreSceneAssemblyPassed ? "scene_assembly_graybox" : "scene_assembly_incomplete",
  completion_proven: false,
  core_reference_scope: {
    expected_states: coreStates.length,
    city,
    office,
    scene_assembly: coreSceneAssemblyPassed ? "passed" : "incomplete",
    playable_scope: coreSceneAssemblyPassed ? "behavior_verified_visual_unverified" : "incomplete",
    runtime_visual_probe: {
      status: runtimeVisualProbe.status,
      state_count: runtimeVisualProbe.state_count,
      expected_state_count: runtimeVisualProbe.expected_state_count,
      boundary: runtimeVisualProbe.evidence_boundary ?? "runtime_structure_only_not_framewise_visual_signoff",
    },
    current_source_visual_evidence: currentEvidenceBound ? `${coreStates.length}/${coreStates.length}` : "0/21",
    visual_acceptance: "0/21",
    final_assets: "8/8 graybox_or_candidate_unverified",
  },
  product_scope: {
    launch_scope: {
      id: "office_vertical_slice",
      expected_states: officeStates.length,
      states: officeStates,
      scene_assembly: coreSceneAssemblyPassed ? "passed" : "incomplete",
      playability: coreSceneAssemblyPassed ? "passed_graybox" : "incomplete",
      current_source_visual_evidence: "0/10",
      visual_acceptance: "0/10",
      release_role: "首发验收范围",
    },
    second_content_scope: {
      id: "city_mission_pack",
      expected_states: cityStates.length,
      states: cityStates,
      scene_assembly: coreSceneAssemblyPassed ? "passed" : "incomplete",
      playability: coreSceneAssemblyPassed ? "passed_graybox" : "incomplete",
      current_source_visual_evidence: "0/11",
      visual_acceptance: "0/11",
      release_role: "第二内容包，不阻塞办公室首发范围的场景补全，但仍阻塞城市内容发布",
    },
  },
  expanded_scope: {
    planned_states: expandedMatrix.entries?.length ?? 0,
    runtime_visual_evidence: "0/18",
    visual_acceptance: "0/18",
    status: "planned_unverified",
  },
  scene_matrix: sceneMatrix,
  delivery_order: [
    {
      phase: 1,
      scope: "office",
      states: officeStates,
      gate: "办公室 10 段完成当前源真实窗口采集、逐段视觉签收后，才进入首发验收",
    },
    {
      phase: 2,
      scope: "city",
      states: cityStates,
      gate: "城市 11 段完成当前源真实窗口采集、逐段视觉签收后，才进入第二内容包验收",
    },
    {
      phase: 3,
      scope: "expanded",
      states: expandedMatrix.entries?.map((entry) => entry.id ?? entry.state).filter(Boolean) ?? [],
      gate: "核心 21 段完成后，再验收 18 项原创扩展场景",
    },
  ],
  gates: {
    core_scene_state_coverage: coreSceneAssemblyPassed ? "passed" : "blocked",
    core_scene_playability: coreSceneAssemblyPassed ? "passed_graybox" : "blocked",
    runtime_visual_scene_probe: runtimeVisualProbe.status === "passed" && runtimeVisualProbe.state_count === coreStates.length ? "passed_structure_only" : "blocked_or_missing",
    current_source_capture: currentEvidenceBound ? "bound" : "blocked_graphics_capture_or_stale_manifest",
    visual_acceptance: "blocked_unverified",
    final_asset_signoff: "blocked_graybox_or_candidate",
    release: "internal_no_go",
  },
  next_action: "先完成办公室 10 段的当前源真实窗口采集与逐段视觉签收；城市 11 段作为第二内容包继续保留，核心 21 段都通过后再扩展 18 项原创场景。扩展项不能替代核心验收。逐场景状态见 scene_matrix。",
  policy: "场景构建存在不等于最终美术完成；行为通过、视觉通过、资产权利和目标设备验收必须分开证明。",
};

fs.mkdirSync(path.dirname(reportPath), { recursive: true });
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

if (!coreSceneAssemblyPassed) {
  console.error("场景完整性门禁失败：核心 21 段存在缺失的视觉构建器或运行时选择器。 ");
  process.exit(1);
}

console.log(`场景完整性门禁通过：核心 ${coreStates.length}/${coreStates.length} 段已有场景构建器与运行时选择器；当前状态仍为灰盒/视觉未验收。`);
console.log(`扩展范围：${report.expanded_scope.planned_states} 项已登记，尚无当前源视觉证据。`);

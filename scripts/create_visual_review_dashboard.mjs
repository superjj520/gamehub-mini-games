import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const matrixRoot = path.join(workspaceRoot, "reference-evidence", "runtime-matrix");
const manifestPath = path.join(matrixRoot, "manifest.json");
const outputPath = path.join(matrixRoot, "visual-review-dashboard.html");
const releaseManifestPath = path.join(workspaceRoot, "docs", "release-manifest.json");
const sceneCompletenessPath = path.join(workspaceRoot, "docs", "scene-completeness-report.json");

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const releaseManifest = JSON.parse(fs.readFileSync(releaseManifestPath, "utf8"));
const sceneCompleteness = fs.existsSync(sceneCompletenessPath)
  ? JSON.parse(fs.readFileSync(sceneCompletenessPath, "utf8"))
  : null;
const currentSourceFingerprint = releaseManifest.source?.sha256 ?? "";
const currentSourceFileCount = Number(releaseManifest.source?.file_count ?? 0);
const captureSourceMatchesCurrent = manifest.source_fingerprint === currentSourceFingerprint
  && Number(manifest.source_file_count ?? currentSourceFileCount) === currentSourceFileCount;
const cards = manifest.captures.map((capture) => {
  const reportPath = path.join(workspaceRoot, "reference-evidence", capture.comparison_report);
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  const referencePath = capture.scene === "city"
    ? `../video-1/${capture.id}.jpg`
    : `../video-2/${capture.id}.jpg`;
  return {
    id: capture.id,
    scene: capture.scene === "city" ? "城市" : "办公室",
    referencePath,
    runtimePath: captureSourceMatchesCurrent ? `./${capture.id}.png` : "",
    reportPath: `./compare-reports/${capture.id}.json`,
    meanError: Number(report.mean_absolute_channel_error ?? 0).toFixed(2),
    exactRatio: (Number(report.exact_pixel_ratio ?? 0) * 100).toFixed(2),
    runtimeSha256: capture.sha256,
    status: capture.visual_status,
    stale: !captureSourceMatchesCurrent,
  };
});

const cardsHtml = cards.map((card) => `
      <article class="card">
        <div class="card-head">
          <h2>${escapeHtml(card.id)} · ${escapeHtml(card.scene)}</h2>
          <span class="status">${escapeHtml(card.status)}</span>
        </div>
        <div class="images">
          <figure><figcaption>参考帧</figcaption><img src="${escapeHtml(card.referencePath)}" alt="${escapeHtml(card.id)} 参考帧"></figure>
          <figure><figcaption>${card.stale ? "历史运行时帧（源已过期）" : "当前运行时"}</figcaption>${card.stale ? `<div class="stale-frame">截图源指纹已过期<br>不得作为当前运行时证据</div>` : `<img src="${escapeHtml(card.runtimePath)}" alt="${escapeHtml(card.id)} 当前运行时">`}</figure>
        </div>
        <div class="metrics">平均通道误差：${escapeHtml(card.meanError)} · 完全相同像素：${escapeHtml(card.exactRatio)}% · <a href="${escapeHtml(card.reportPath)}">查看报告</a></div>
        <div class="review-fields">
          <label>人工结论
            <select class="decision" data-segment="${escapeHtml(card.id)}">
              <option value="unverified" selected>未复核</option>
              <option value="passed">通过</option>
              <option value="rejected">不通过</option>
            </select>
          </label>
          <label>差异与返工项
            <textarea class="findings" data-segment="${escapeHtml(card.id)}" rows="2" placeholder="通过时必须为空；不通过时请写明镜头、比例、材质或逻辑差异。"></textarea>
          </label>
        </div>
      </article>`).join("\n");

const sceneSummary = sceneCompleteness
  ? {
      expected: Number(sceneCompleteness.core_reference_scope?.expected_states ?? 0),
      assembly: sceneCompleteness.core_reference_scope?.scene_assembly === "passed"
        ? Number(sceneCompleteness.core_reference_scope?.expected_states ?? 0)
        : 0,
      runtimeProbe: Number(sceneCompleteness.core_reference_scope?.runtime_visual_probe?.state_count ?? 0),
      visualAccepted: Number(String(sceneCompleteness.core_reference_scope?.visual_acceptance ?? "0/0").split("/")[0] ?? 0),
      release: String(sceneCompleteness.gates?.release ?? "unknown"),
    }
  : null;

const sceneSummaryHtml = sceneSummary
  ? `<section class="scene-summary" aria-label="场景完成度摘要">
      <div><span>场景入口与逻辑</span><strong>${sceneSummary.assembly}/${sceneSummary.expected}</strong><small>状态已接入，不代表美术完成</small></div>
      <div><span>运行时视觉组件</span><strong>${sceneSummary.runtimeProbe}/${sceneSummary.expected}</strong><small>结构探针通过</small></div>
      <div><span>正式视觉验收</span><strong>${sceneSummary.visualAccepted}/${sceneSummary.expected}</strong><small>必须用当前源截图逐帧复核</small></div>
      <div><span>发布状态</span><strong>${escapeHtml(sceneSummary.release)}</strong><small>独立发布门禁</small></div>
    </section>`
  : "";

const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>参考视觉逐项验收面板</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
    body { margin: 0; background: #101827; color: #eef3fb; }
    header { position: sticky; top: 0; z-index: 2; padding: 20px 28px; background: rgba(16,24,39,.96); border-bottom: 1px solid #33415c; }
    h1 { margin: 0 0 8px; font-size: 24px; } p { margin: 4px 0; color: #aebbd0; }
    .warning { color: #ffd58a; } .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(520px, 1fr)); gap: 18px; padding: 22px; }
    .card { background: #182338; border: 1px solid #354561; border-radius: 12px; padding: 14px; }
    .card-head { display: flex; align-items: center; justify-content: space-between; gap: 12px; } h2 { margin: 0; font-size: 17px; }
    .status { padding: 4px 8px; border-radius: 999px; color: #ffd58a; background: #4b3d25; font-size: 12px; }
    .images { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 12px; } figure { margin: 0; } figcaption { color: #aebbd0; font-size: 12px; margin-bottom: 6px; }
    img { display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: contain; background: #0b111d; border-radius: 6px; }
    .stale-frame { display: grid; place-items: center; width: 100%; aspect-ratio: 16 / 9; box-sizing: border-box; padding: 20px; text-align: center; color: #ffd58a; background: #2b2418; border: 1px dashed #a78242; border-radius: 6px; line-height: 1.6; }
    .metrics { margin-top: 10px; color: #aebbd0; font-size: 12px; } a { color: #8fc7ff; }
    .review-fields { display: grid; gap: 8px; margin-top: 12px; color: #d9e2f0; font-size: 13px; }
    .review-fields label { display: grid; gap: 5px; }
    select, textarea, input { color: #eef3fb; background: #0f1726; border: 1px solid #4a5b78; border-radius: 6px; padding: 7px; font: inherit; }
    textarea { resize: vertical; }
    .review-toolbar { display: grid; grid-template-columns: 1.3fr 1fr 1fr auto; gap: 10px; align-items: end; margin-top: 16px; }
    .review-toolbar label { display: grid; gap: 5px; color: #d9e2f0; font-size: 13px; }
    button { color: #08111e; background: #8fc7ff; border: 0; border-radius: 7px; padding: 10px 14px; font-weight: 700; cursor: pointer; }
    #export-status { margin-top: 10px; color: #b7e5b5; }
    .scene-summary { display: grid; grid-template-columns: repeat(4, minmax(150px, 1fr)); gap: 10px; margin-top: 18px; }
    .scene-summary div { padding: 12px; border: 1px solid #40516e; border-radius: 9px; background: #111b2d; }
    .scene-summary span, .scene-summary small { display: block; color: #aebbd0; font-size: 12px; }
    .scene-summary strong { display: block; margin: 5px 0; color: #eef3fb; font-size: 22px; }
    @media (max-width: 900px) { .review-toolbar { grid-template-columns: 1fr; } }
    @media (max-width: 900px) { .scene-summary { grid-template-columns: repeat(2, minmax(140px, 1fr)); } }
  </style>
</head>
<body>
  <header>
    <h1>参考视觉逐项验收面板</h1>
    <p>当前源截图：${escapeHtml(manifest.captured_at)} · 共 ${cards.length} 段 · 源指纹由运行时矩阵清单维护</p>
    <p class="warning">机器对比只提供证据，不自动批准视觉还原；所有条目当前保持 unverified。只有真实完成逐帧或目标设备复核后，才允许导出通过结论。</p>
    <p class="warning">“场景入口与逻辑 ${sceneSummary?.assembly ?? 0}/${sceneSummary?.expected ?? 0}”只代表参考状态已接入可运行流程；要达到复刻目标，还必须完成每个镜头的正式图形采集、人物/场景/材质调整和人工视觉签收。</p>
    <p class="warning">${captureSourceMatchesCurrent ? "截图源指纹与当前运行时一致，但仍未完成人工视觉签收。" : `本面板截图源已过期：截图 ${escapeHtml(manifest.source_fingerprint)} / ${escapeHtml(manifest.source_file_count ?? "未知")}，当前 ${escapeHtml(currentSourceFingerprint)} / ${escapeHtml(currentSourceFileCount)}；旧帧仅保留为历史参考，必须重新采集。`}</p>
    ${sceneSummaryHtml}
    <div class="review-toolbar">
      <label>审阅人<input id="reviewer" placeholder="填写姓名或团队"></label>
      <label>审阅方式<select id="method"><option value="manual_frame_review">逐帧复核</option><option value="manual_device_review">目标设备复核</option></select></label>
      <label>审阅时间（UTC）<input id="reviewed-at"></label>
      <button id="export-review" type="button">导出人工复核记录</button>
    </div>
    <p id="export-status">导出后可用 apply_visual_review_record.mjs 进行严格写入；没有真实人工复核时不要导出“通过”。</p>
  </header>
  <main class="grid">${cardsHtml}
  </main>
  <script>
    const sourceFingerprint = ${JSON.stringify(manifest.source_fingerprint)};
    const reviewedAt = document.querySelector("#reviewed-at");
    reviewedAt.value = new Date().toISOString();
    document.querySelector("#export-review").addEventListener("click", () => {
      const reviewer = document.querySelector("#reviewer").value.trim();
      const method = document.querySelector("#method").value;
      const reviewed_at = reviewedAt.value.trim();
      const segments = [...document.querySelectorAll(".decision")].map((select) => {
        const id = select.dataset.segment;
        const findings = document.querySelector('.findings[data-segment="' + id + '"]').value.trim();
        return { id, decision: select.value, findings: findings ? [findings] : [] };
      });
      const passedWithFindings = segments.filter((segment) => segment.decision === "passed" && segment.findings.length > 0);
      const hasPassed = segments.some((segment) => segment.decision === "passed");
      if (!reviewer || !reviewed_at) {
        document.querySelector("#export-status").textContent = "请先填写审阅人和 UTC 审阅时间。";
        return;
      }
      if (passedWithFindings.length > 0) {
        document.querySelector("#export-status").textContent = "标记为通过的分段仍有差异或返工项，不能导出。";
        return;
      }
      const payload = { schema_version: 1, generated_at: new Date().toISOString(), reviewer, method, reviewed_at, runtime_source_fingerprint: sourceFingerprint, segments };
      const blob = new Blob([JSON.stringify(payload, null, 2) + "\\n"], {type: "application/json"});
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "visual-review-record.json";
      link.click();
      URL.revokeObjectURL(url);
      document.querySelector("#export-status").textContent = hasPassed ? "人工复核记录已导出；写入前仍需运行严格门禁。" : "未导出通过项；记录可用于保存不通过项和返工意见。";
    });
  </script>
</body>
</html>
`;

fs.writeFileSync(outputPath, html, "utf8");
console.log(`视觉验收面板已生成：${path.relative(workspaceRoot, outputPath)}；条目 ${cards.length} 个，状态保持 unverified`);

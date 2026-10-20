import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const evidenceRoot = path.join(workspaceRoot, "reference-evidence", "candidate-runtime");
const manifestPath = path.join(evidenceRoot, "current-movie-visual-evidence.json");
const outputPath = path.join(evidenceRoot, "current-visual-review-dashboard.html");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const releaseManifestPath = path.join(workspaceRoot, "docs", "release-manifest.json");
const releaseManifest = JSON.parse(fs.readFileSync(releaseManifestPath, "utf8"));
const currentBuildPath = path.join(evidenceRoot, "full-candidate-windows-build.json");
const currentBuild = fs.existsSync(currentBuildPath)
  ? JSON.parse(fs.readFileSync(currentBuildPath, "utf8"))
  : null;
const currentSource = releaseManifest.source ?? {};
const currentCandidatePackage = currentBuild?.package ?? {};
const activeCandidatePaths = [
  path.join(evidenceRoot, "full-candidate-playtest.json"),
  path.join(evidenceRoot, "full-candidate-playtest-original-only.json"),
];
const activeCandidate = activeCandidatePaths
  .filter((candidatePath) => fs.existsSync(candidatePath))
  .map((candidatePath) => JSON.parse(fs.readFileSync(candidatePath, "utf8")))
  .find((candidate) => Array.isArray(candidate.active_candidate_ids)) ?? null;
const originalCandidatePath = path.join(evidenceRoot, "full-candidate-playtest-original.json");
const originalCandidate = fs.existsSync(originalCandidatePath)
  ? JSON.parse(fs.readFileSync(originalCandidatePath, "utf8"))
  : null;
const activeCandidateSummary = activeCandidate
  ? `<p class="meta">当前活动候选包：${escapeHtml(activeCandidate.active_candidate_ids.join("、"))}。注意：本面板中的帧仍需逐项确认是否来自这一活动候选包。</p>`
  : `<p class="warning">未找到当前活动候选绑定，不能把本面板帧视为当前候选证据。</p>`;
const originalOnlyCandidatePath = path.join(evidenceRoot, "full-candidate-playtest-original-only.json");
const originalOnlyCandidate = fs.existsSync(originalOnlyCandidatePath)
  ? JSON.parse(fs.readFileSync(originalOnlyCandidatePath, "utf8"))
  : null;
const originalCandidateSummary = originalCandidate
  ? `<p class="meta">原创角色与原创办公桌比较包：${escapeHtml(originalCandidate.active_candidate_ids.join("、"))}。该方案有独立行为证据，但本面板没有把旧帧自动归属于原创方案。</p>`
  : originalOnlyCandidate && Array.isArray(originalOnlyCandidate.active_candidate_ids)
    ? `<p class="meta">原创边界候选包：${escapeHtml(originalOnlyCandidate.active_candidate_ids.join("、"))}。该方案有独立行为证据，但本面板中的帧仍需逐项确认是否来自这一候选包。</p>`
  : `<p class="warning">未找到原创角色比较包证据。</p>`;
const staleNotice = manifest.source_stale_since_capture?.reason
  ? `<p class="warning">本批截图源已过期：${escapeHtml(manifest.source_stale_since_capture.reason)}</p>`
  : "";

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

const cards = manifest.captures.map((capture) => {
  const currentPath = capture.path.replace(/^candidate-runtime\//, "./");
  const referenceRoot = capture.reference_path.startsWith("video-1/") ? "../video-1/" : "../video-2/";
  const referencePath = referenceRoot + capture.reference_path.split("/").at(-1);
  const scene = capture.reference_path.startsWith("video-1/") ? "城市" : "办公室";
  return `
    <article class="card">
      <header><h2>${escapeHtml(capture.id)} · ${scene}</h2><span>未验收</span></header>
      <div class="images">
        <figure><figcaption>参考帧</figcaption><img src="${escapeHtml(referencePath)}" alt="参考帧"></figure>
        <figure><figcaption>当前候选帧</figcaption><img src="${escapeHtml(currentPath)}" alt="当前候选帧"></figure>
      </div>
      <p class="notes">${escapeHtml(capture.notes)}</p>
      <p class="hash">当前帧 SHA-256：<code>${escapeHtml(capture.sha256)}</code></p>
      <label>人工审阅结论
        <select><option selected>未验收</option><option>通过</option><option>不通过</option></select>
      </label>
      <label>差异与返工项<textarea rows="3" placeholder="记录比例、镜头、材质、角色、环境或 HUD 差异"></textarea></label>
    </article>`;
}).join("\n");

const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>新时代觉醒者·当前候选视觉审阅</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
    body { margin: 0; background: #101722; color: #eef3fb; }
    header.page { padding: 24px 28px; border-bottom: 1px solid #34445b; background: #172235; }
    h1 { margin: 0 0 8px; font-size: 24px; } p { color: #afbdd0; line-height: 1.55; }
    .warning { color: #ffd68c; } .meta { font-size: 12px; color: #8fa2bb; }
    main { display: grid; grid-template-columns: repeat(auto-fit, minmax(520px, 1fr)); gap: 18px; padding: 22px; }
    article.card { padding: 14px; border: 1px solid #3b4d69; border-radius: 12px; background: #1b293e; }
    article.card header { display: flex; justify-content: space-between; align-items: center; padding: 0; border: 0; background: transparent; }
    h2 { margin: 0; font-size: 16px; } article.card header span { color: #ffd68c; font-size: 12px; }
    .images { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 12px; }
    figure { margin: 0; } figcaption { margin-bottom: 6px; color: #afbdd0; font-size: 12px; }
    img { display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: contain; background: #0b111b; border-radius: 6px; }
    .notes, .hash { font-size: 12px; } code { word-break: break-all; color: #9cd0ff; }
    label { display: grid; gap: 5px; margin-top: 10px; color: #dce5f1; font-size: 13px; }
    select, textarea { color: #eef3fb; background: #0f1725; border: 1px solid #4a5e7d; border-radius: 6px; padding: 8px; font: inherit; }
    textarea { resize: vertical; }
  </style>
</head>
<body>
  <header class="page">
    <h1>《新时代觉醒者》当前候选视觉审阅</h1>
    <p>本页面展示候选图形取证帧。由于截图采集身份可能早于当前构建，必须先核对两组身份；它用于人工比较，不代表视觉已通过。</p>
    <p class="warning">机器哈希、运行时验证和候选包验证不能代替产品负责人逐帧签收；任何“通过”都必须有明确差异记录为空的人工结论。</p>
    ${staleNotice}
    ${activeCandidateSummary}
    ${originalCandidateSummary}
    <p class="meta">截图采集身份：候选包 ${escapeHtml(manifest.candidate_package.sha256)} / ${manifest.candidate_package.file_count} 文件；源 ${escapeHtml(manifest.source.sha256)} / ${manifest.source.file_count} 文件；状态：${escapeHtml(manifest.visual_status)}</p>
    <p class="meta">当前构建身份：候选包 ${escapeHtml(currentCandidatePackage.sha256 || "未找到")} / ${escapeHtml(currentCandidatePackage.file_count || "-")} 文件；源 ${escapeHtml(currentSource.sha256 || "未找到")} / ${escapeHtml(currentSource.file_count || "-")} 文件。两者不一致时，当前帧只能作为历史候选参考，必须重新采集。</p>
  </header>
  <main>${cards}</main>
</body>
</html>\n`;

fs.writeFileSync(outputPath, html, "utf8");
console.log(`当前候选视觉审阅面板已生成：${path.relative(workspaceRoot, outputPath)}；条目 ${manifest.captures.length} 个；状态保持 unverified`);

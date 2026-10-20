import fs from "node:fs";
import path from "node:path";

const workspaceRoot = path.resolve(".");
const matrixPath = path.join(workspaceRoot, "docs/expanded-visual-acceptance-matrix.json");
const manifestPath = path.join(workspaceRoot, "reference-evidence/expanded-runtime-matrix/manifest.json");
const outputPath = path.join(workspaceRoot, "reference-evidence/expanded-runtime-matrix/visual-review-dashboard.html");
const runtimeCompletenessPath = path.join(workspaceRoot, "reference-evidence/candidate-runtime/expanded-visual-runtime-completeness.json");
const matrix = JSON.parse(fs.readFileSync(matrixPath, "utf8"));
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const runtimeCompleteness = fs.existsSync(runtimeCompletenessPath)
  ? JSON.parse(fs.readFileSync(runtimeCompletenessPath, "utf8"))
  : null;
const byId = new Map((manifest.captures ?? []).map((capture) => [capture.id, capture]));

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

const cards = (matrix.entries ?? []).map((entry) => {
  const capture = byId.get(entry.id);
  const imagePath = capture?.path ? `../../${capture.path}` : "";
  const eventTypes = capture?.trace_event_types?.join("、") || "无事件摘要";
  return `
    <article class="card">
      <div class="head"><h2>${escapeHtml(entry.id)}</h2><span>${escapeHtml(entry.visual_status)}</span></div>
      <p class="area">${escapeHtml(entry.chapter)} · ${escapeHtml(entry.content_area)}</p>
      <p>${escapeHtml(entry.visual_state)}</p>
      ${imagePath ? `<img src="${escapeHtml(imagePath)}" alt="${escapeHtml(entry.id)} 当前扩展运行时帧">` : `<div class="missing">尚未生成当前运行时帧</div>`}
      <p class="meta">事件：${escapeHtml(eventTypes)}</p>
      <p class="meta">需要：${escapeHtml((entry.required_evidence ?? []).join("、"))}</p>
      <label>人工差异记录<textarea rows="3" placeholder="记录构图、可读性、材质、状态反馈和返工项"></textarea></label>
    </article>`;
}).join("\n");

const runtimeSummary = runtimeCompleteness
  ? `<section class="summary" aria-label="扩展场景完成度摘要">
      <div><span>运行时结构</span><strong>${Number(runtimeCompleteness.passed_count ?? 0)}/${Number(runtimeCompleteness.expected_count ?? matrix.entries?.length ?? 0)}</strong><small>状态与反馈已接入</small></div>
      <div><span>当前源图形帧</span><strong>0/${matrix.entries?.length ?? 0}</strong><small>尚未完成真实窗口采集</small></div>
      <div><span>人工视觉签收</span><strong>0/${matrix.entries?.length ?? 0}</strong><small>逐项复核未开始</small></div>
      <div><span>发布状态</span><strong>禁止</strong><small>视觉与资产门禁未满足</small></div>
    </section>`
  : "";

const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>新时代觉醒者·扩展视觉审阅</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; }
    body { margin: 0; background: #101722; color: #eef3fb; }
    header { padding: 24px 28px; border-bottom: 1px solid #34445b; background: #172235; }
    h1 { margin: 0 0 8px; font-size: 24px; } p { color: #afbdd0; line-height: 1.5; }
    .warning { color: #ffd68c; } .meta { font-size: 12px; color: #8fa2bb; }
    .summary { display: grid; grid-template-columns: repeat(4, minmax(150px, 1fr)); gap: 10px; margin-top: 18px; }
    .summary div { padding: 12px; border: 1px solid #40516e; border-radius: 9px; background: #111b2d; }
    .summary span, .summary small { display: block; color: #aebbd0; font-size: 12px; }
    .summary strong { display: block; margin: 5px 0; color: #eef3fb; font-size: 22px; }
    main { display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 16px; padding: 20px; }
    .card { padding: 14px; border: 1px solid #3b4d69; border-radius: 12px; background: #1b293e; }
    .head { display: flex; justify-content: space-between; gap: 12px; align-items: center; }
    h2 { margin: 0; font-size: 16px; } .head span { color: #ffd68c; font-size: 12px; }
    .area { color: #9cd0ff; font-size: 12px; } img, .missing { display: block; width: 100%; aspect-ratio: 16 / 9; object-fit: contain; background: #0b111b; border-radius: 6px; }
    .missing { display: grid; place-items: center; color: #9aa8bc; } label { display: grid; gap: 5px; margin-top: 10px; font-size: 13px; }
    textarea { color: #eef3fb; background: #0f1725; border: 1px solid #4a5e7d; border-radius: 6px; padding: 8px; font: inherit; resize: vertical; }
  </style>
</head>
<body>
  <header>
    <h1>《新时代觉醒者》扩展视觉审阅</h1>
    <p>当前扩展项 ${matrix.entries?.length ?? 0} 个；源指纹 ${escapeHtml(manifest.source_fingerprint)} / ${manifest.source_file_count} 文件。</p>
    <p class="warning">本面板只提供真实运行时帧和事件摘要；扩展视觉必须由人工逐项审阅、目标设备验证后才能通过。</p>
    ${runtimeSummary}
  </header>
  <main>${cards}</main>
</body>
</html>\n`;

fs.writeFileSync(outputPath, html, "utf8");
console.log(`扩展视觉审阅面板已生成：${path.relative(workspaceRoot, outputPath)}；条目 ${matrix.entries?.length ?? 0} 个；状态保持 unverified`);

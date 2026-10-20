import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const root = process.cwd();
const manifestPath = path.join(root, "docs", "visual-concept-manifest.json");
const outputPath = path.join(root, "art-preview", "visual-concept-gallery.html");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

const escapeHtml = (value) => String(value)
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&#39;");

const hash = (filePath) => crypto
  .createHash("sha256")
  .update(fs.readFileSync(path.join(root, filePath)))
  .digest("hex");

const conceptCards = manifest.concepts.map((concept) => {
  const imagePath = path.relative(path.dirname(outputPath), path.join(root, concept.path));
  const currentHash = hash(concept.path);
  const title = concept.title ?? concept.id;
  const purpose = concept.purpose ?? concept.acceptance;
  const stateList = concept.logic_states.map((state) => `<li><code>${escapeHtml(state)}</code></li>`).join("");
  const requirementList = (concept.required_animation_states ?? concept.required_scene_layers ?? [])
    .map((item) => `<li>${escapeHtml(item)}</li>`)
    .join("");
  const mountList = (concept.required_mount_points ?? [])
    .map((item) => `<li><code>${escapeHtml(item)}</code></li>`)
    .join("");

  return `
    <article class="card">
      <div class="image-wrap">
        <img src="${escapeHtml(imagePath)}" alt="${escapeHtml(title)}">
        <span class="status">视觉稿 · 待运行时验收</span>
      </div>
      <div class="card-body">
        <div class="eyebrow">${escapeHtml(concept.asset_class)}</div>
        <h2>${escapeHtml(title)}</h2>
        <p class="purpose">${escapeHtml(purpose)}</p>
        <div class="grid">
          <section>
            <h3>绑定逻辑状态</h3>
            <ul>${stateList}</ul>
          </section>
          <section>
            <h3>必须落地的视觉状态</h3>
            <ul>${requirementList}</ul>
          </section>
          ${mountList ? `<section><h3>挂点契约</h3><ul>${mountList}</ul></section>` : ""}
        </div>
        <div class="target"><span>运行时目标</span><code>${escapeHtml(concept.runtime_target)}</code></div>
        <div class="acceptance"><strong>验收出口</strong>${escapeHtml(concept.acceptance)}</div>
        <div class="fingerprint">文件指纹：${currentHash}</div>
      </div>
    </article>`;
}).join("\n");

const html = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>新时代觉醒者 · 视觉生产画廊</title>
  <style>
    :root { color-scheme: dark; --bg:#10151a; --panel:#192129; --line:#34424e; --text:#eef4f7; --muted:#a9b8c1; --accent:#f5b85d; --danger:#ff8579; }
    * { box-sizing: border-box; }
    body { margin:0; font-family: Inter, -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif; background:radial-gradient(circle at 10% 0%, #243340, var(--bg) 38%); color:var(--text); }
    main { max-width:1500px; margin:0 auto; padding:48px 28px 72px; }
    header { display:flex; justify-content:space-between; gap:24px; align-items:flex-end; border-bottom:1px solid var(--line); padding-bottom:28px; margin-bottom:28px; }
    h1 { margin:0 0 10px; font-size:clamp(28px,4vw,54px); letter-spacing:-.04em; }
    header p { margin:0; max-width:760px; color:var(--muted); line-height:1.7; }
    .summary { min-width:240px; padding:16px 18px; border:1px solid #665234; border-radius:14px; background:#241f17; color:#f8d49a; }
    .summary strong { display:block; color:#fff0c8; font-size:24px; margin-bottom:4px; }
    .cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(430px,1fr)); gap:22px; }
    .card { overflow:hidden; border:1px solid var(--line); border-radius:18px; background:linear-gradient(145deg,#1d2730,#141a20); box-shadow:0 18px 46px #0004; }
    .image-wrap { position:relative; background:#0b0f13; aspect-ratio:16/9; }
    .image-wrap img { display:block; width:100%; height:100%; object-fit:cover; }
    .status { position:absolute; top:14px; left:14px; padding:7px 10px; border-radius:999px; background:#3c2918dd; border:1px solid #a97d3d; color:#ffd898; font-size:12px; }
    .card-body { padding:22px; }
    .eyebrow { color:var(--accent); font-size:12px; letter-spacing:.12em; text-transform:uppercase; }
    h2 { margin:6px 0 10px; font-size:24px; }
    .purpose { color:#c5d1d7; line-height:1.6; min-height:52px; }
    .grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:18px; margin-top:18px; }
    h3 { margin:0 0 8px; font-size:13px; color:#f6d79d; }
    ul { margin:0; padding-left:18px; color:var(--muted); line-height:1.7; font-size:13px; }
    code { color:#d8e9f2; font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px; overflow-wrap:anywhere; }
    .target, .acceptance { margin-top:18px; padding:12px 14px; border-radius:10px; background:#11181e; border:1px solid #2b3943; }
    .target span, .acceptance strong { display:block; margin-bottom:6px; color:#f1c77e; font-size:12px; }
    .acceptance { color:#c7d2d8; line-height:1.6; font-size:13px; }
    .fingerprint { margin-top:14px; color:#71818a; font:11px ui-monospace,SFMono-Regular,Menlo,monospace; overflow-wrap:anywhere; }
    footer { margin-top:34px; padding:20px 0 0; border-top:1px solid var(--line); color:#85959e; font-size:13px; line-height:1.7; }
    @media (max-width:700px) { main { padding:28px 14px 48px; } header { display:block; } .summary { margin-top:20px; } .cards { grid-template-columns:1fr; } .grid { grid-template-columns:1fr; } }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <h1>视觉生产画廊</h1>
        <p>《新时代觉醒者》的视觉稿、逻辑状态和运行时资产目标绑定面板。这里展示的是原创生产参考，不是最终游戏截图；只有完成真实窗口采集、逐帧对照、目标设备验收和权利签收，才能提升为最终资产。</p>
      </div>
      <div class="summary"><strong>${manifest.concepts.length} 组</strong>视觉稿已登记<br>状态：待运行时验收</div>
    </header>
    <section class="cards">${conceptCards}</section>
    <footer>生成来源：docs/visual-concept-manifest.json · 生成脚本：scripts/create_visual_concept_gallery.mjs · 清单版本：${escapeHtml(manifest.schema_version)}<br>验收顺序：人物轮廓与接触关系 → 材质与灯光 → 镜头构图 → 动画节奏 → HUD 与音频 → 目标设备表现。</footer>
  </main>
</body>
</html>
`;

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, html);
console.log(`视觉生产画廊已生成：${path.relative(root, outputPath)}；${manifest.concepts.length} 组视觉稿；指纹已重新计算`);

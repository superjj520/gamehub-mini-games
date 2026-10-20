import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const runtimeRoot = path.join(root, "gta-reference-runtime");
const privacyPath = path.join(root, "docs", "privacy-data-inventory.md");
const privacyText = fs.readFileSync(privacyPath, "utf8");

const requiredPrivacyMarkers = [
  "任务进度",
  "输入回放",
  "事件时间轴",
  "设备标识",
  "联系方式",
  "支付信息",
  "不接入广告、第三方分析、崩溃上传、社交登录或远程存档",
  "不能据此直接生成任何平台的最终隐私声明",
];
for (const marker of requiredPrivacyMarkers) {
  if (!privacyText.includes(marker)) throw new Error(`隐私边界清单缺少必需条目：${marker}`);
}

const forbiddenRuntimePatterns = [
  /\bHTTPRequest\b|\bHTTPClient\b|\bWebSocketPeer\b|\bTCPServer\b|\bUDPServer\b/,
  /OS\.get_unique_id\s*\(/,
  /\b(telemetry|analytics|sentry|firebase|admob|purchase|iap)\b/i,
];
const runtimeFiles = [];
function collect(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (!new Set([".godot", ".import"]).has(entry.name)) collect(absolutePath);
    } else if (entry.isFile() && /\.(gd|tscn|json|tres|cfg)$/.test(entry.name)) {
      runtimeFiles.push(absolutePath);
    }
  }
}
collect(runtimeRoot);
for (const filePath of runtimeFiles) {
  const source = fs.readFileSync(filePath, "utf8");
  for (const pattern of forbiddenRuntimePatterns) {
    if (pattern.test(source)) {
      throw new Error(`运行时出现未登记的数据/网络能力：${path.relative(root, filePath)} -> ${pattern}`);
    }
  }
}

console.log(`隐私与数据边界验证通过：清单条目完整，运行时 ${runtimeFiles.length} 个配置/脚本文件未发现网络、账号、广告、分析或支付接入`);

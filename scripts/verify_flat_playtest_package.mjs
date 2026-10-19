import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const workspaceRoot = path.resolve(".");
const candidateManifestPath = path.join(workspaceRoot, "build", "internal-candidate-manifest.json");

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function parsePackagePath() {
  let defaultPackage;
  if (!process.argv[2]) {
    if (!fs.existsSync(candidateManifestPath)) throw new Error("缺少内部候选树清单，无法定位当前试玩包");
    const manifest = JSON.parse(fs.readFileSync(candidateManifestPath, "utf8"));
    const sourceShort = manifest.candidate?.sha256?.slice(0, 8);
    if (!/^[0-9a-f]{8}$/.test(sourceShort ?? "")) throw new Error("内部候选树清单缺少有效源码指纹");
    defaultPackage = path.join(workspaceRoot, "build", `internal-playtest-${sourceShort}-flat-v47.zip`);
  }
  const candidate = process.argv[2] ? path.resolve(process.argv[2]) : defaultPackage;
  if (path.extname(candidate).toLowerCase() !== ".zip") throw new Error("试玩包必须是 .zip 文件");
  return candidate;
}

function listEntries(packagePath) {
  const output = execFileSync("unzip", ["-Z1", packagePath], {encoding: "utf8"});
  return output.split(/\r?\n/).filter(Boolean);
}

const packagePath = parsePackagePath();
if (!fs.existsSync(packagePath)) throw new Error(`试玩包不存在：${packagePath}`);
const metadataPath = `${packagePath.slice(0, -4)}.json`;
if (!fs.existsSync(metadataPath)) throw new Error(`缺少试玩包清单：${metadataPath}`);
const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
const entries = listEntries(packagePath);
const requiredEntries = ["project.godot", "README.md", "scenes/launcher.tscn", "content/launch-profile.json"];
const missing = requiredEntries.filter((entry) => !entries.includes(entry));
if (missing.length > 0) throw new Error(`试玩包缺少根目录入口：${missing.join(", ")}`);
const forbiddenFragments = ["reference-evidence/", ".godot/", ".import", "参考视频"];
const forbidden = entries.filter((entry) => forbiddenFragments.some((fragment) => entry.includes(fragment)));
if (forbidden.length > 0) throw new Error(`试玩包包含禁入内容：${forbidden.slice(0, 8).join(", ")}`);
if (metadata.status !== "internal_no_go") throw new Error(`试玩包状态不是 internal_no_go：${metadata.status}`);
if (!/^[0-9a-f]{64}$/.test(metadata.source_fingerprint)) throw new Error("试玩包源码指纹格式无效");
if (sha256(packagePath) !== metadata.sha256) throw new Error("试玩包 SHA-256 与清单不一致");
if (fs.statSync(packagePath).size !== metadata.bytes) throw new Error("试玩包字节数与清单不一致");
const readme = execFileSync("unzip", ["-p", packagePath, "README.md"], {encoding: "utf8"});
if (readme.includes("__SOURCE_") || !readme.includes(metadata.source_fingerprint)) {
  throw new Error("试玩包 README 没有绑定当前源码指纹");
}
execFileSync("unzip", ["-t", packagePath], {stdio: "ignore"});
console.log(`扁平源码试玩包验证通过：${path.relative(workspaceRoot, packagePath)}；${metadata.bytes} bytes；源码 ${metadata.source_file_count} 个；禁入内容 0 个`);

import fs from "node:fs";
import path from "node:path";

const root = path.resolve(".");
const cuesPath = path.join(root, "gta-reference-runtime/content/audio_cues.json");
const libraryPath = path.join(root, "gta-reference-runtime/assets/audio/generated/audio-library-manifest.json");
const rightsPath = path.join(root, "docs/asset-rights-register.md");

function fail(message) {
  throw new Error(message);
}

const cues = JSON.parse(fs.readFileSync(cuesPath, "utf8"));
const library = JSON.parse(fs.readFileSync(libraryPath, "utf8"));
const rights = fs.readFileSync(rightsPath, "utf8");

if (!Array.isArray(cues.cues) || cues.cues.length === 0) fail("audio_cues.json 缺少有效 cues 数组");
if (!Array.isArray(library.files) || library.files.length === 0) fail("音频库清单缺少有效 files 数组");

const cueIds = new Set(cues.cues.map((cue) => cue?.id).filter(Boolean));
const libraryIds = new Set(library.files.map((file) => file?.id).filter(Boolean));
if (cueIds.size !== cues.cues.length || libraryIds.size !== library.files.length) {
  fail("音频事件或音频库存在空 id 或重复 id");
}
if (cueIds.size !== libraryIds.size || [...cueIds].some((id) => !libraryIds.has(id))) {
  fail("audio_cues.json 与音频库清单的事件集合不一致");
}

const matches = [...rights.matchAll(/包含\s+(\d+)\s+个确定性 PCM WAV/g)];
if (matches.length !== 1) fail(`权利登记中的音频数量声明应恰好出现 1 次，实际为 ${matches.length} 次`);
const documentedCount = Number(matches[0][1]);
if (documentedCount !== library.files.length) {
  fail(`权利登记音频数量 ${documentedCount} 与音频库 ${library.files.length} 不一致`);
}

console.log(`音频权利文档一致性验证通过：${documentedCount} 个事件、${library.files.length} 个 WAV、事件集合一致`);

import {execFileSync} from "node:child_process";
import path from "node:path";

const root = process.cwd();
const verifiers = [
  "scripts/verify_interaction_props_handoff.mjs",
  "scripts/verify_three_wheel_handoff.mjs",
  "scripts/verify_office_environment_handoff.mjs",
  "scripts/verify_player_character_handoff.mjs",
  "scripts/verify_office_npc_handoff.mjs",
  "scripts/verify_city_crowd_handoff.mjs",
  "scripts/verify_city_environment_handoff.mjs",
  "scripts/verify_audio_handoff.mjs",
];

for (const verifier of verifiers) {
  execFileSync(process.execPath, [path.join(root, verifier)], {cwd: root, stdio: "inherit"});
}

console.log(`原创资产生产交接总门禁通过：${verifiers.length}/${verifiers.length}；全部保持视觉未验收且不可发布`);

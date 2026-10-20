import fs from "node:fs";
import path from "node:path";
import {execFileSync, spawnSync} from "node:child_process";

const workspaceRoot = process.cwd();
const sourceFingerprintCommand = path.join(workspaceRoot, "scripts/source_fingerprint.mjs");
const sourceFingerprintBefore = execFileSync(process.execPath, [sourceFingerprintCommand], {
  cwd: workspaceRoot,
  encoding: "utf8",
}).trim();
const captureRunner = path.join(workspaceRoot, "art-source/environment/polyhaven-metal-office-desk/capture_combined_office_candidate_visual.mjs");
const profileContractPath = path.join(workspaceRoot, "art-source/environment/polyhaven-metal-office-desk/office-capture-profiles.json");
const profileContract = JSON.parse(fs.readFileSync(profileContractPath, "utf8"));
const profiles = Object.entries(profileContract).map(([name, profile]) => ({name, distance: Number(profile.followDistance), height: Number(profile.followHeight)}));
const videoSegments = ["office-01", "office-02", "office-03", "office-04", "office-05", "office-06", "office-07", "office-08", "office-09", "office-10"];

for (const profile of profiles) {
  const result = spawnSync(process.execPath, [captureRunner], {
    cwd: workspaceRoot,
    env: {...process.env, COMBINED_CAPTURE_VALIDATE_ONLY: "1", COMBINED_CAPTURE_PROFILE: profile.name},
    stdio: "inherit",
    encoding: "utf8",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`办公室 ${profile.name} 配置验证失败，退出码：${result.status}`);
  const reportPath = path.join(workspaceRoot, `reference-evidence/candidate-runtime/combined-office-candidates-configuration-${profile.name}.json`);
  if (!fs.existsSync(reportPath)) throw new Error(`办公室 ${profile.name} 配置验证报告缺失：${reportPath}`);
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  if (report.status !== "candidate_configuration_validation_only" || report.visual_status !== "unverified" || report.release_allowed !== false) {
    throw new Error(`办公室 ${profile.name} 报告错误地声称已经视觉通过`);
  }
  if (Math.abs(Number(report.camera?.distance) - profile.distance) > 0.001 || Math.abs(Number(report.camera?.height) - profile.height) > 0.001) {
    throw new Error(`办公室 ${profile.name} 相机参数漂移：${JSON.stringify(report.camera)}`);
  }
  if (report.actors?.player_visible !== true || report.actors?.npc_visible !== true || Number(report.environment?.desk_count) !== 10) {
    throw new Error(`办公室 ${profile.name} 角色或工位契约不完整：${JSON.stringify({actors: report.actors, environment: report.environment})}`);
  }
  if ((profile.name === "close" || profile.name === "stealth" || profile.name === "lobby") && (
    report.environment?.video_backdrop_enabled !== true
    || !String(report.environment?.video_backdrop_texture || "").endsWith(`${profile.name === "lobby" ? "office-06" : profile.name === "stealth" ? "office-02" : "office-01"}-video-playable-backdrop-v1.png`)
    || report.environment?.video_backdrop_asset_source !== "user_authorized_ai_video_frame_edit"
    || report.environment?.video_backdrop_rights_status !== "user_authorized_candidate_rights_pending_final_signoff"
  )) {
    throw new Error(`办公室 ${profile.name} 视频候选背景契约不完整：${JSON.stringify(report.environment)}`);
  }
}

for (const segment of videoSegments) {
  const result = spawnSync(process.execPath, [captureRunner], {
    cwd: workspaceRoot,
    env: {...process.env, COMBINED_CAPTURE_VALIDATE_ONLY: "1", COMBINED_CAPTURE_PROFILE: "wide", COMBINED_CAPTURE_VIDEO_SEGMENT: segment},
    stdio: "inherit",
    encoding: "utf8",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`办公室 ${segment} 分段背景配置验证失败，退出码：${result.status}`);
  const reportPath = path.join(workspaceRoot, `reference-evidence/candidate-runtime/combined-office-candidates-configuration-${segment}.json`);
  if (!fs.existsSync(reportPath)) throw new Error(`办公室 ${segment} 分段背景验证报告缺失：${reportPath}`);
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  const expectedTexture = `${segment}-video-playable-backdrop-v1.png`;
  if (report.reference_video_segment !== segment
    || report.visual_status !== "unverified"
    || report.release_allowed !== false
    || report.environment?.video_backdrop_enabled !== true
    || !String(report.environment?.video_backdrop_texture || "").endsWith(expectedTexture)
    || report.environment?.video_backdrop_asset_source !== "user_authorized_ai_video_frame_edit"
    || report.environment?.video_backdrop_rights_status !== "user_authorized_candidate_rights_pending_final_signoff") {
    throw new Error(`办公室 ${segment} 分段背景契约不完整：${JSON.stringify({reference_video_segment: report.reference_video_segment, environment: report.environment, visual_status: report.visual_status, release_allowed: report.release_allowed})}`);
  }
}

const sourceFingerprintAfter = execFileSync(process.execPath, [sourceFingerprintCommand], {
  cwd: workspaceRoot,
  encoding: "utf8",
}).trim();
if (sourceFingerprintAfter !== sourceFingerprintBefore) {
  throw new Error(`办公室候选配置验证污染了正式运行时源码：验证前 ${sourceFingerprintBefore}；验证后 ${sourceFingerprintAfter}`);
}

console.log("办公室候选配置验证通过：close、stealth、lobby、wide 四套相机、office-01 至 office-10 十段背景、玩家/NPC 和 10 个工位均已记录；视觉仍为 unverified");

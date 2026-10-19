#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}/.."
variant="${CANDIDATE_VARIANT:-makehuman}"

case "${variant}" in
  makehuman)
    variant_label="完整候选"
    launcher_variant="full"
    output_root="${workspace_root}/build/internal-full-candidate"
    evidence_path="${workspace_root}/reference-evidence/candidate-runtime/full-candidate-playtest-macos.json"
    ;;
  original_only)
    variant_label="原创边界候选"
    launcher_variant="original_only"
    output_root="${workspace_root}/build/internal-full-candidate-original-only"
    evidence_path="${workspace_root}/reference-evidence/candidate-runtime/full-candidate-playtest-macos-original-only.json"
    ;;
  *)
    print -u2 "不支持的候选方案：${variant}；可选值为 makehuman 或 original_only"
    exit 2
    ;;
esac

godot_binary="${GODOT_BIN:-}"
if [[ -z "${godot_binary}" ]]; then
  if command -v godot >/dev/null 2>&1; then
    godot_binary="$(command -v godot)"
  elif [[ -x "/opt/homebrew/bin/godot" ]]; then
    godot_binary="/opt/homebrew/bin/godot"
  elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    godot_binary="/Applications/Godot.app/Contents/MacOS/Godot"
  else
    print -u2 "未找到 Godot 4；请安装 Godot 4.7.1，或用 GODOT_BIN 指定可执行文件"
    exit 1
  fi
fi

if [[ ! -x "${godot_binary}" ]]; then
  print -u2 "Godot 可执行文件不可用：${godot_binary}"
  exit 1
fi

print "正在准备${variant_label}本机试玩包……"
preflight_flag=""
if [[ "${CANDIDATE_FAST_VALIDATE_ONLY:-0}" == "1" ]]; then
  preflight_flag="1"
fi
env \
  GODOT_BIN="${godot_binary}" \
  FULL_CANDIDATE_CHARACTERS="${variant}" \
  FULL_CANDIDATE_OUTPUT="${output_root}" \
  FULL_CANDIDATE_EVIDENCE_PATH="${evidence_path}" \
  FULL_CANDIDATE_PREFLIGHT_ONLY="${preflight_flag}" \
  node "${workspace_root}/art-source/candidate-playtest/run_full_candidate_playtest.mjs"

if [[ "${CANDIDATE_FAST_VALIDATE_ONLY:-0}" == "1" ]]; then
  exit 0
fi

# 预检通过只是“包可启动”的前置条件，不能把它当成试玩本身。
# 这里必须继续进入统一的真实启动器，否则用户执行“本机试玩”后只会看到命令结束。
exec env CANDIDATE_VARIANT="${launcher_variant}" \
  zsh "${workspace_root}/scripts/launch_current_candidate_macos.sh"

#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}/.."
candidate_root="${workspace_root}/build/internal-full-candidate-original-only"
godot_binary="${GODOT_BIN:-godot}"

# 先用同一入口重新生成 Mac 原创边界候选包；这一步会复跑办公室、城市、
# 音频和资产挂载预检，但不会启动交互窗口。
CANDIDATE_FAST_VALIDATE_ONLY=1 \
  CANDIDATE_VARIANT=original_only \
  zsh "${workspace_root}/scripts/run_candidate_playtest_macos.sh"

FULL_CANDIDATE_PACKAGE_ROOT="${candidate_root}" \
  node "${workspace_root}/scripts/verify_full_candidate_package.mjs"
FULL_CANDIDATE_PACKAGE_ROOT="${candidate_root}" \
  node "${workspace_root}/scripts/verify_original_only_candidate_package.mjs"

log_path="/tmp/new-era-macos-candidate-qa.log"
: > "${log_path}"

"${godot_binary}" \
  --headless \
  --single-threaded-scene \
  --path "${candidate_root}" \
  --audio-driver Dummy \
  --rendering-driver opengl3 \
  --rendering-method gl_compatibility \
  --log-file "${log_path}" \
  -s res://tests/launcher_integration_test.gd

"${godot_binary}" \
  --headless \
  --single-threaded-scene \
  --path "${candidate_root}" \
  --audio-driver Dummy \
  --rendering-driver opengl3 \
  --rendering-method gl_compatibility \
  --log-file "${log_path}" \
  -s res://tests/launcher_candidate_preview_test.gd

echo "Mac 原创边界候选启动与入口 QA 通过：包隔离、原创资产边界、内容包绑定和候选预览入口均已验证"

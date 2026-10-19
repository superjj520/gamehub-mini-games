#!/bin/zsh
set -euo pipefail

workspace_root="$(cd "$(dirname "$0")/.." && pwd)"
candidate_root="$workspace_root/${FULL_CANDIDATE_ROOT:-build/internal-full-candidate}"
output_path="$workspace_root/${FULL_CANDIDATE_WINDOWS_OUTPUT:-build/windows/新时代觉醒者-完整候选.exe}"
log_path="$workspace_root/${FULL_CANDIDATE_WINDOWS_LOG:-reference-evidence/candidate-runtime/full-candidate-windows-export.log}"
export_preset="${FULL_CANDIDATE_WINDOWS_PRESET:-新时代觉醒者 Windows 内部测试}"

if [[ ! -f "$candidate_root/project.godot" ]]; then
  print -u2 "完整候选运行包不存在，请先执行 npm run package:candidate:full"
  exit 1
fi

mkdir -p "$workspace_root/build/windows" "$workspace_root/reference-evidence/candidate-runtime"

# macOS 开发机导出使用无窗口兼容渲染，避免 Metal 转换层干扰 Windows 模板打包。
godot \
  --path "$candidate_root" \
  --display-driver headless \
  --audio-driver Dummy \
  --rendering-driver opengl3 \
  --rendering-method gl_compatibility \
  --export-release "$export_preset" \
  "$output_path" \
  --log-file "$log_path"

node "$workspace_root/scripts/create_full_candidate_windows_manifest.mjs"
node "$workspace_root/scripts/verify_full_candidate_windows_build.mjs"

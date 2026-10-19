#!/bin/zsh

# 启动带源码指纹绑定的真实图形采集器。
# 指纹在 Godot 启动前计算，并由运行时写入每段证据；本脚本不调用鼠标自动化。

set -euo pipefail

workspace_root="${PROJECT_ROOT:-$(pwd)}"
fingerprint_line="$(cd "$workspace_root" && node scripts/source_fingerprint.mjs)"
source_fingerprint="${fingerprint_line%% files=*}"
source_file_count="${fingerprint_line##* files=}"

if [[ ! "$source_fingerprint" =~ '^[0-9a-f]{64}$' || ! "$source_file_count" =~ '^[0-9]+$' || "$source_file_count" == "0" ]]; then
  print -u2 "无法建立有效的图形采集源码指纹：$fingerprint_line"
  exit 2
fi

export REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING=1
export REFERENCE_MATRIX_SOURCE_FINGERPRINT="$source_fingerprint"
export REFERENCE_MATRIX_SOURCE_FILE_COUNT="$source_file_count"

exec zsh scripts/run_reference_capture_with_timeout.sh "$@"

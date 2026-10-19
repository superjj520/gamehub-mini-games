#!/bin/zsh

# 后台启动真实图形采集器。
#
# 该入口不调用鼠标自动化，也不把 Godot 窗口切到前台；open -g 让窗口在
# 后台创建，-W 等待 Godot 自己按 --quit-after 退出。真实图形视口仍然由
# Godot 提供，采集结果必须继续经过当前源指纹、PNG 哈希和人工视觉验收。

set -euo pipefail

workspace_root="${PROJECT_ROOT:-$(pwd)}"
fingerprint_line="$(cd "$workspace_root" && node scripts/source_fingerprint.mjs)"
source_fingerprint="${fingerprint_line%% files=*}"
source_file_count="${fingerprint_line##* files=}"
if [[ ! "$source_fingerprint" =~ '^[0-9a-f]{64}$' || ! "$source_file_count" =~ '^[0-9]+$' || "$source_file_count" == "0" ]]; then
  print -u2 "无法建立有效的后台图形采集源码指纹：$fingerprint_line"
  exit 2
fi
export REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING=1
export REFERENCE_MATRIX_SOURCE_FINGERPRINT="$source_fingerprint"
export REFERENCE_MATRIX_SOURCE_FILE_COUNT="$source_file_count"

godot_app="${GODOT_APP_PATH:-/Applications/Godot.app}"
# 显式指定 GODOT_BIN 时直接走有界包装器，避免 macOS LaunchServices
# 把采集窗口交给错误的应用实例；不指定时才保留 open -g 的后台入口。
if [[ -z "${GODOT_BIN:-}" && "${REFERENCE_CAPTURE_USE_OPEN:-1}" == "1" && -d "$godot_app" ]]; then
  launch_output=""
  launch_status=0
  launch_output="$(open -g -W -a "$godot_app" --args "$@" 2>&1)" || launch_status=$?
  if (( launch_status == 0 )) && [[ ! "$launch_output" =~ "kLSNoExecutableErr" ]] && [[ ! "$launch_output" =~ "cannot be opened" ]]; then
    exit 0
  fi
  if [[ -n "$launch_output" ]]; then
    print -u2 -- "$launch_output"
  fi
  print -u2 "Godot 应用包无法由 open 启动，尝试使用实际可执行文件；这条回退路径不调用鼠标自动化"
fi

# 应用包不可用时统一交给有界包装器。它会复用同一份启动前源码指纹，
# 并在 macOS 图形服务卡住时写入 graphical-capture-failure-*.json；这样
# 后台入口与前台入口不会出现一个只有退出码、另一个有完整失败证据的分叉。
# 该回退仍然只启动 Godot 进程，不调用鼠标自动化，也不触碰其它进程。
exec zsh scripts/run_reference_capture_with_timeout.sh "$@"

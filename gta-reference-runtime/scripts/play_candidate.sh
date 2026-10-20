#!/bin/sh
set -eu

# 这个脚本随完整候选源码树分发；它只负责启动当前目录对应的 Godot 项目。
# 在候选包根目录执行 ./scripts/play_candidate.sh 即可进入办公室/城市候选入口。
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
godot_binary=${GODOT_BIN:-godot}
state_root="${REFERENCE_PLAYTEST_STATE_ROOT:-${project_root}/.playtest-state}"
mkdir -p "$state_root"
log_path="${REFERENCE_PLAYTEST_LOG_PATH:-${state_root}/godot.log}"

# 候选源码树允许直接指定办公室或城市场景做定位调试；这时没有经过
# Launcher 的 request_scene，必须由启动脚本自己绑定候选资产目录，避免
# 直进场景悄悄加载回正式默认目录。
candidate_catalog="${REFERENCE_ASSET_CATALOG_PATH:-}"
if [ -z "$candidate_catalog" ] && [ -f "$project_root/content/full-candidate-preview.marker" ]; then
  if [ -f "$project_root/content/asset-runtime-catalog-original-only.json" ]; then
    candidate_catalog="res://content/asset-runtime-catalog-original-only.json"
  elif [ -f "$project_root/tests/asset-runtime-catalog-full-candidates.json" ]; then
    candidate_catalog="res://tests/asset-runtime-catalog-full-candidates.json"
  fi
fi

headless=0
previous_arg=""
for arg in "$@"; do
  if [ "$arg" = "--headless" ] || { [ "$previous_arg" = "--display-driver" ] && [ "$arg" = "headless" ]; }; then
    headless=1
  fi
  previous_arg="$arg"
done

if [ "$(uname -s)" = "Darwin" ] && [ "$headless" -eq 0 ]; then
  exec env \
    REFERENCE_SETTINGS_PATH="$state_root/reference_settings.json" \
    REFERENCE_DISPLAY_SETTINGS_PATH="$state_root/reference_display_settings.json" \
    REFERENCE_CAMPAIGN_STATE_PATH="$state_root/reference_campaign.json" \
    REFERENCE_SESSION_MARKER_PATH="$state_root/reference_session.json" \
    REFERENCE_OFFICE_CHECKPOINT_PATH="$state_root/reference_checkpoint.json" \
    REFERENCE_CITY_CHECKPOINT_PATH="$state_root/city_checkpoint.json" \
    REFERENCE_BOOT_STATUS_PATH="$state_root/boot_status.json" \
    REFERENCE_ASSET_CATALOG_PATH="$candidate_catalog" \
    "$godot_binary" \
    --display-driver macos \
    --rendering-driver opengl3 \
    --rendering-method gl_compatibility \
    --single-window \
    --windowed \
    --resolution 1280x720 \
    --path "$project_root" \
    --log-file "$log_path" \
    "$@"
fi

exec env \
  REFERENCE_SETTINGS_PATH="$state_root/reference_settings.json" \
  REFERENCE_DISPLAY_SETTINGS_PATH="$state_root/reference_display_settings.json" \
  REFERENCE_CAMPAIGN_STATE_PATH="$state_root/reference_campaign.json" \
  REFERENCE_SESSION_MARKER_PATH="$state_root/reference_session.json" \
  REFERENCE_OFFICE_CHECKPOINT_PATH="$state_root/reference_checkpoint.json" \
  REFERENCE_CITY_CHECKPOINT_PATH="$state_root/city_checkpoint.json" \
  REFERENCE_BOOT_STATUS_PATH="$state_root/boot_status.json" \
  REFERENCE_ASSET_CATALOG_PATH="$candidate_catalog" \
  "$godot_binary" --path "$project_root" --log-file "$log_path" "$@"

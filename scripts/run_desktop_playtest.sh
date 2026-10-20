#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}/.."
state_root="${REFERENCE_PLAYTEST_STATE_ROOT:-${workspace_root}/build/playtest-user-data-desktop}"
log_file="${REFERENCE_PLAYTEST_LOG_PATH:-${state_root}/godot.log}"
boot_status_path="${REFERENCE_BOOT_STATUS_PATH:-${state_root}/boot_status.json}"
mkdir -p "${state_root}"
rm -f "${boot_status_path}"

godot_binary="${GODOT_BIN:-godot}"
if ! command -v "${godot_binary}" >/dev/null 2>&1 && [[ ! -x "${godot_binary}" ]]; then
  print -u2 "未找到 Godot 4：${godot_binary}"
  exit 1
fi

headless=0
previous_arg=""
for arg in "$@"; do
  if [[ "${arg}" == "--headless" ]] || { [[ "${previous_arg}" == "--display-driver" ]] && [[ "${arg}" == "headless" ]]; }; then
    headless=1
  fi
  previous_arg="${arg}"
done

godot_args=("--path" "${workspace_root}/gta-reference-runtime" "--log-file" "${log_file}")
if (( headless )); then
  godot_args+=("$@")
else
  godot_args+=("--display-driver" "macos" "--rendering-driver" "opengl3" "--rendering-method" "gl_compatibility" "--single-window" "--windowed" "--resolution" "1280x720" "$@")
fi

env \
  REFERENCE_SETTINGS_PATH="${state_root}/reference_settings.json" \
  REFERENCE_DISPLAY_SETTINGS_PATH="${state_root}/reference_display_settings.json" \
  REFERENCE_CAMPAIGN_STATE_PATH="${state_root}/reference_campaign.json" \
  REFERENCE_SESSION_MARKER_PATH="${state_root}/reference_session.json" \
  REFERENCE_OFFICE_CHECKPOINT_PATH="${state_root}/reference_checkpoint.json" \
  REFERENCE_CITY_CHECKPOINT_PATH="${state_root}/city_checkpoint.json" \
  REFERENCE_BOOT_STATUS_PATH="${boot_status_path}" \
  "${godot_binary}" "${godot_args[@]}" \
  >"${state_root}/godot.stdout.log" 2>&1 &
godot_pid=$!

cleanup() {
  if kill -0 "${godot_pid}" 2>/dev/null; then
    kill "${godot_pid}" 2>/dev/null || true
  fi
}
trap cleanup INT TERM

for ((index = 0; index < 300; index++)); do
  if [[ -f "${boot_status_path}" ]]; then
    boot_status="$(node -e 'const fs=require("fs"); const p=process.argv[1]; try { const v=JSON.parse(fs.readFileSync(p,"utf8")); process.stdout.write(`${v.status}|${v.scene}|${v.detail||""}`); } catch (_) {}' "${boot_status_path}")"
    if [[ "${boot_status}" == ready\|* ]]; then
      print "真实试玩首屏已启动：${boot_status}"
      trap - INT TERM
      wait "${godot_pid}"
      exit $?
    fi
    if [[ "${boot_status}" == failed\|* ]]; then
      print -u2 "试玩启动失败：${boot_status}"
      print -u2 "图形进程日志：${log_file}"
      cleanup
      wait "${godot_pid}" 2>/dev/null || true
      exit 1
    fi
  fi
  if ! kill -0 "${godot_pid}" 2>/dev/null; then
    print -u2 "Godot 进程已退出，且没有写入启动状态。"
    print -u2 "图形进程日志：${log_file}"
    exit 1
  fi
  sleep 0.1
done

print -u2 "30 秒内没有确认真实试玩首屏。"
print -u2 "这不是玩法通过；请检查图形后端或日志：${log_file}"
cleanup
wait "${godot_pid}" 2>/dev/null || true
exit 1

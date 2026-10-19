#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}/.."
variant="${CANDIDATE_VARIANT:-original_only}"

case "${variant}" in
  original_only)
    variant_label="原创边界候选"
    candidate_root="${workspace_root}/build/internal-full-candidate-original-only"
    ;;
  full)
    variant_label="完整候选"
    candidate_root="${workspace_root}/build/internal-full-candidate"
    ;;
  *)
    print -u2 "不支持的候选方案：${variant}；可选值为 original_only 或 full"
    exit 2
    ;;
esac

if [[ ! -f "${candidate_root}/project.godot" ]]; then
  print -u2 "缺少${variant_label}运行目录：${candidate_root}"
  print -u2 "请先执行对应的完整候选打包入口，再使用本快速启动入口。"
  exit 1
fi

if [[ ! -f "${candidate_root}/candidate-package-manifest.json" ]]; then
  print -u2 "候选包身份清单缺失：${candidate_root}/candidate-package-manifest.json"
  exit 1
fi

print "校验${variant_label}当前候选包身份……"
FULL_CANDIDATE_PACKAGE_ROOT="${candidate_root}" node "${workspace_root}/scripts/verify_full_candidate_package.mjs" >/dev/null
if [[ "${variant}" == "original_only" ]]; then
  FULL_CANDIDATE_PACKAGE_ROOT="${candidate_root}" node "${workspace_root}/scripts/verify_original_only_candidate_package.mjs" >/dev/null
fi

if [[ "${CANDIDATE_FAST_VALIDATE_ONLY:-0}" == "1" ]]; then
  print "${variant_label}快速启动前置校验通过：${candidate_root}"
  exit 0
fi

godot_binary="${GODOT_BIN:-}"
if [[ -z "${godot_binary}" ]]; then
  if command -v godot >/dev/null 2>&1; then
    godot_binary="$(command -v godot)"
  elif [[ -x "/opt/homebrew/bin/godot" ]]; then
    godot_binary="/opt/homebrew/bin/godot"
  elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    godot_binary="/Applications/Godot.app/Contents/MacOS/Godot"
  else
    print -u2 "未找到 Godot 4.7.1；请安装 Godot，或用 GODOT_BIN 指定可执行文件"
    exit 1
  fi
fi

if [[ ! -x "${godot_binary}" ]]; then
  print -u2 "Godot 可执行文件不可用：${godot_binary}"
  exit 1
fi

scene="${CANDIDATE_SCENE:-res://scenes/launcher.tscn}"
godot_extra_args=()
headless=0
previous_arg=""
while (( $# > 0 )); do
  case "$1" in
    --scene)
      if (( $# < 2 )); then
        print -u2 "--scene 缺少场景路径"
        exit 2
      fi
      scene="$2"
      shift 2
      ;;
    --headless)
      headless=1
      godot_extra_args+=("$1")
      shift
      ;;
    --display-driver)
      if (( $# < 2 )); then
        print -u2 "--display-driver 缺少参数"
        exit 2
      fi
      if [[ "$2" == "headless" ]]; then
        headless=1
      fi
      godot_extra_args+=("$1" "$2")
      shift 2
      ;;
    *)
      godot_extra_args+=("$1")
      shift
      ;;
  esac
done

user_data_dir="${workspace_root}/build/playtest-user-data-${variant}"
mkdir -p "${user_data_dir}"
boot_status_path="${user_data_dir}/boot_status.json"
rm -f "${boot_status_path}"
print "正在启动${variant_label}；不会重新构建候选包，也不会修改正式运行时。"
candidate_catalog_path=""
if [[ -f "${candidate_root}/content/asset-runtime-catalog-original-only.json" ]] && [[ "${variant}" == "original_only" ]]; then
  candidate_catalog_path="res://content/asset-runtime-catalog-original-only.json"
elif [[ -f "${candidate_root}/tests/asset-runtime-catalog-full-candidates.json" ]]; then
  candidate_catalog_path="res://tests/asset-runtime-catalog-full-candidates.json"
fi
if [[ -z "${candidate_catalog_path}" ]]; then
  print -u2 "候选包缺少与当前方案匹配的资产运行时目录：${candidate_root}"
  exit 1
fi
print "候选资产目录：${candidate_catalog_path}；直进场景也不会回退到正式默认目录。"
godot_display_args=("--display-driver" "macos" "--rendering-driver" "opengl3" "--rendering-method" "gl_compatibility" "--single-window" "--windowed" "--resolution" "1280x720")
if (( headless )); then
  godot_display_args=("--display-driver" "headless" "--audio-driver" "Dummy" "--rendering-driver" "opengl3" "--rendering-method" "gl_compatibility")
fi
env \
  REFERENCE_SETTINGS_PATH="${user_data_dir}/reference_settings.json" \
  REFERENCE_DISPLAY_SETTINGS_PATH="${user_data_dir}/reference_display_settings.json" \
  REFERENCE_CAMPAIGN_STATE_PATH="${user_data_dir}/reference_campaign.json" \
  REFERENCE_SESSION_MARKER_PATH="${user_data_dir}/reference_session.json" \
  REFERENCE_OFFICE_CHECKPOINT_PATH="${user_data_dir}/reference_checkpoint.json" \
  REFERENCE_CITY_CHECKPOINT_PATH="${user_data_dir}/city_checkpoint.json" \
  REFERENCE_BOOT_STATUS_PATH="${boot_status_path}" \
  REFERENCE_ASSET_CATALOG_PATH="${candidate_catalog_path}" \
  "${godot_binary}" \
  "${godot_display_args[@]}" \
  --path "${candidate_root}" \
  --scene "${scene}" \
  --log-file "/tmp/xinjieyuanjuexing-${variant}-playtest.log" \
  "${godot_extra_args[@]}" \
  >"/tmp/xinjieyuanjuexing-${variant}-playtest.stdout.log" 2>&1 &
godot_pid=$!
cleanup() {
  if kill -0 "${godot_pid}" 2>/dev/null; then
    kill "${godot_pid}" 2>/dev/null || true
  fi
}
trap cleanup INT TERM

boot_status=""
for ((index = 0; index < 300; index++)); do
  if [[ -f "${boot_status_path}" ]]; then
    boot_status="$(node -e 'const fs=require("fs"); const p=process.argv[1]; try { const v=JSON.parse(fs.readFileSync(p,"utf8")); process.stdout.write(`${v.status}|${v.scene}|${v.detail||""}`); } catch (_) {}' "${boot_status_path}")"
    if [[ "${boot_status}" == ready\|* ]]; then
      print "${variant_label}真实启动已确认：${boot_status}"
      trap - INT TERM
      wait "${godot_pid}"
      exit $?
    fi
    if [[ "${boot_status}" == failed\|* ]]; then
      print -u2 "${variant_label}启动失败：${boot_status}"
      print -u2 "图形进程日志：/tmp/xinjieyuanjuexing-${variant}-playtest.log"
      cleanup
      wait "${godot_pid}" 2>/dev/null || true
      exit 1
    fi
  fi
  if ! kill -0 "${godot_pid}" 2>/dev/null; then
    print -u2 "${variant_label}进程已退出，但没有写入启动状态。"
    print -u2 "图形进程日志：/tmp/xinjieyuanjuexing-${variant}-playtest.log"
    exit 1
  fi
  sleep 0.1
done

print -u2 "${variant_label}在 30 秒内没有确认真实首屏。"
print -u2 "这不是玩法测试通过；请检查 macOS 图形后端或图形进程日志。"
print -u2 "图形进程日志：/tmp/xinjieyuanjuexing-${variant}-playtest.log"
cleanup
wait "${godot_pid}" 2>/dev/null || true
exit 1

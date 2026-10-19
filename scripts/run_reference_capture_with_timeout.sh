#!/bin/zsh

# 可见图形采集的有界包装器。
# macOS 图形服务异常时，Godot 可能既不写日志也不退出；这里仅管理本次
# 启动的精确子进程，避免留下悬挂进程，也避免把旧 PNG 当成新证据。

set -u

record_graphics_failure() {
	local reason="$1"
	local workspace_root="$2"
	local capture_pid="$3"
	local timeout_seconds="$4"
	shift 4
	local failure_root="${REFERENCE_CAPTURE_FAILURE_DIR:-$workspace_root/reference-evidence/candidate-runtime}"
	local stamp="$(date +%Y%m%d-%H%M%S)"
	local failure_path="$failure_root/graphical-capture-failure-${stamp}-${capture_pid}.json"
	mkdir -p "$failure_root"
	FAILURE_PATH="$failure_path" \
	FAILURE_REASON="$reason" \
	FAILURE_PID="$capture_pid" \
	FAILURE_TIMEOUT="$timeout_seconds" \
	FAILURE_GODOT_BIN="${godot_bin:-}" \
	FAILURE_SOURCE_SHA256="${expected_source_fingerprint:-}" \
	FAILURE_SOURCE_FILE_COUNT="${expected_source_file_count:-0}" \
	FAILURE_LOG_PATH="${REFERENCE_CAPTURE_LOG_PATH:-}" \
	FAILURE_COMMAND="${godot_bin:-} $*" \
	node -e '
const fs = require("node:fs");
const payload = {
  schema_version: 1,
  status: "graphical_capture_failed",
  failure_kind: process.env.FAILURE_REASON,
  generated_at: new Date().toISOString(),
	process: {pid: Number(process.env.FAILURE_PID), timeout_seconds: Number(process.env.FAILURE_TIMEOUT), godot_bin: process.env.FAILURE_GODOT_BIN || null},
  source: {sha256: process.env.FAILURE_SOURCE_SHA256, file_count: Number(process.env.FAILURE_SOURCE_FILE_COUNT)},
  log_path: process.env.FAILURE_LOG_PATH || null,
  command: process.env.FAILURE_COMMAND || null,
  policy: "失败记录只用于诊断，不构成 PNG、视觉验收或发布证据"
};
fs.writeFileSync(process.env.FAILURE_PATH, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
'
	print -u2 "结构化图形采集失败记录：$failure_path"
}

timeout_seconds="${REFERENCE_MATRIX_TIMEOUT_SECONDS:-90}"
if ! [[ "$timeout_seconds" =~ '^[0-9]+$' ]] || (( timeout_seconds < 1 )); then
	print -u2 "REFERENCE_MATRIX_TIMEOUT_SECONDS 必须是正整数"
	exit 2
fi

# 某些 macOS 会话允许 screencapture 写入 /tmp，但拒绝写入 TMPDIR；采集
# 进度、图形探针和隔离用户数据统一使用可覆盖的临时根目录，避免把路径
# 权限问题误判成图形服务不可用。该目录只承载本次诊断和采集过程文件。
capture_temp_root="${REFERENCE_CAPTURE_TEMP_ROOT:-/tmp}"
mkdir -p "$capture_temp_root"

# 每次采集使用独立的进度文件，避免旧运行留下的 complete 状态被误读为
# 当前运行成功。进度文件只用于诊断；真正的 PNG 仍须由源指纹、哈希和视觉
# 验收链单独确认。
if [[ -z "${REFERENCE_MATRIX_PROGRESS_PATH:-}" ]]; then
	REFERENCE_MATRIX_PROGRESS_PATH="$capture_temp_root/新时代觉醒者-reference-matrix-progress-$$.json"
	export REFERENCE_MATRIX_PROGRESS_PATH
fi

workspace_root="${PROJECT_ROOT:-$(pwd)}"
source_fingerprint_line="$(cd "$workspace_root" && node scripts/source_fingerprint.mjs 2>/dev/null)"
expected_source_fingerprint="${source_fingerprint_line%% files=*}"
expected_source_file_count="${source_fingerprint_line##* files=}"
godot_bin="${GODOT_BIN:-$(command -v godot 2>/dev/null || true)}"
if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
	print -u2 "找不到可执行的 Godot：请设置 GODOT_BIN，或把 Godot 加入 PATH"
	exit 127
fi
log_file_argument_pending=0
for capture_argument in "$@"; do
	if (( log_file_argument_pending == 1 )); then
		REFERENCE_CAPTURE_LOG_PATH="$capture_argument"
		log_file_argument_pending=0
	elif [[ "$capture_argument" == "--log-file" ]]; then
		log_file_argument_pending=1
	fi
done
if [[ "${REFERENCE_MATRIX_REQUIRE_SOURCE_BINDING:-0}" == "1" ]]; then
	if [[ ! "$expected_source_fingerprint" =~ '^[0-9a-f]{64}$' || ! "$expected_source_file_count" =~ '^[0-9]+$' ]]; then
		print -u2 "无法建立本次图形采集的源码指纹：$source_fingerprint_line"
		exit 2
	fi
	export REFERENCE_MATRIX_SOURCE_FINGERPRINT="$expected_source_fingerprint"
	export REFERENCE_MATRIX_SOURCE_FILE_COUNT="$expected_source_file_count"
fi

export REFERENCE_CAPTURE_LOG_PATH="${REFERENCE_CAPTURE_LOG_PATH:-}"

# 在真正启动 Godot 前先验证当前进程是否拥有可用的 macOS 图形输出。
# 这不是视觉验收，只是采集前置条件：没有显示服务、屏幕录制权限或可用
# display 时，继续启动 Godot 只会制造一段无效等待，不能产生任何证据。
# 仅对要求真实图形证据的运行启用，避免影响普通的无窗口行为测试。
if [[ "${REFERENCE_MATRIX_REQUIRED_GRAPHICS:-0}" == "1" && "$(uname -s)" == "Darwin" && "${REFERENCE_MATRIX_SKIP_DISPLAY_PREFLIGHT:-0}" != "1" ]]; then
	graphics_probe_path="$capture_temp_root/新时代觉醒者-graphics-probe-$$.png"
	if ! screencapture -x "$graphics_probe_path" >/dev/null 2>&1 || [[ ! -s "$graphics_probe_path" ]]; then
		rm -f "$graphics_probe_path"
		print -u2 "当前环境没有可用的 macOS 图形输出，停止本次真实视觉采集"
		record_graphics_failure "display_unavailable" "$workspace_root" "0" "0" "$@"
		exit 125
	fi
	rm -f "$graphics_probe_path"
fi

# 日志路径通常由 npm 脚本固定指定。启动前清空旧日志，避免 Godot 在本次
# 启动没有真正写入内容时，旧运行的“采集完成”文本被误认为新证据。
if [[ -n "$REFERENCE_CAPTURE_LOG_PATH" ]]; then
	: > "$REFERENCE_CAPTURE_LOG_PATH"
fi

# Godot 4.7 的命令行没有 --user-data-dir 参数；此前伪造这个参数既不能隔离
# 用户数据，还会让“可见采集”看起来像使用了隔离目录。这里仅保留项目路径、
# 日志路径和进程级超时，避免把不存在的启动能力当成可靠底层设施。
godot_args=("$@")

"$godot_bin" "${godot_args[@]}" &
godot_pid=$!
started_at=$SECONDS
capture_completed=0

while kill -0 "$godot_pid" 2>/dev/null; do
	# 某些 macOS 图形服务会让 Godot 在全部 PNG 写完后仍保持窗口进程；
	# 进度文件是本次运行独立生成的，且由运行时在最后一段证据写入 complete。
	# 先确认完成，再结束本次精确子进程，避免把“采集完成但进程未退出”误报为超时。
	if [[ "${REFERENCE_MATRIX_REQUIRED_GRAPHICS:-0}" == "1" && -f "$REFERENCE_MATRIX_PROGRESS_PATH" ]]; then
		if PROGRESS_PATH="$REFERENCE_MATRIX_PROGRESS_PATH" EXPECTED_FINGERPRINT="$expected_source_fingerprint" EXPECTED_FILE_COUNT="$expected_source_file_count" node - <<'NODE' >/dev/null 2>&1
const fs = require("node:fs");
const progress = JSON.parse(fs.readFileSync(process.env.PROGRESS_PATH, "utf8"));
if (progress.phase !== "complete") process.exit(1);
if (process.env.EXPECTED_FINGERPRINT && progress.source_fingerprint !== process.env.EXPECTED_FINGERPRINT) process.exit(1);
if (process.env.EXPECTED_FILE_COUNT && Number(progress.source_file_count) !== Number(process.env.EXPECTED_FILE_COUNT)) process.exit(1);
NODE
			then
			print "图形采集进度已完成，结束仍存活的 Godot 子进程 ${godot_pid}"
			capture_completed=1
			kill -TERM "$godot_pid" 2>/dev/null || true
			break
		fi
	fi
	if (( SECONDS - started_at >= timeout_seconds )); then
		print -u2 "参考图形采集超时：${timeout_seconds} 秒，正在结束 Godot 进程 ${godot_pid}"
		record_graphics_failure "timeout" "$workspace_root" "$godot_pid" "$timeout_seconds" "${godot_args[@]}"
		kill -TERM "$godot_pid" 2>/dev/null || true
		for _ in {1..10}; do
			if ! kill -0 "$godot_pid" 2>/dev/null; then
				wait "$godot_pid" 2>/dev/null || true
				exit 124
			fi
			sleep 1
		done
		kill -KILL "$godot_pid" 2>/dev/null || true
		wait "$godot_pid" 2>/dev/null || true
		exit 124
	fi
	sleep 1
done

wait "$godot_pid"
exit_code=$?
if (( capture_completed == 1 )); then
	# 进程因采集完成后的受控结束而返回非零，不把该退出码传播为采集失败；
	# 下面仍会再次读取进度文件并核对当前源码指纹。
	exit_code=0
fi
if (( exit_code != 0 )); then
	if [[ "${REFERENCE_MATRIX_REQUIRED_GRAPHICS:-0}" == "1" ]]; then
		record_graphics_failure "process_exit_${exit_code}" "$workspace_root" "$godot_pid" "$timeout_seconds" "${godot_args[@]}"
	fi
	exit "$exit_code"
fi

# Godot 正常退出并不等于本次采集真正执行完成；检查独立进度文件，且只在
# 要求源绑定时核对当前源码指纹。这样旧日志、旧 PNG 或旧 progress 都不能
# 被包装器误报为当前版本的成功采集。
if [[ "${REFERENCE_MATRIX_REQUIRED_GRAPHICS:-0}" == "1" ]]; then
	if [[ ! -f "$REFERENCE_MATRIX_PROGRESS_PATH" ]]; then
		print -u2 "图形采集未生成本次进度文件：$REFERENCE_MATRIX_PROGRESS_PATH"
		exit 125
	fi
	if ! progress_result="$(PROGRESS_PATH="$REFERENCE_MATRIX_PROGRESS_PATH" EXPECTED_FINGERPRINT="$expected_source_fingerprint" EXPECTED_FILE_COUNT="$expected_source_file_count" node - <<'NODE'
const fs = require("node:fs");
const progressPath = process.env.PROGRESS_PATH;
const progress = JSON.parse(fs.readFileSync(progressPath, "utf8"));
const requiresBinding = process.env.EXPECTED_FINGERPRINT.length > 0;
if (progress.phase !== "complete") throw new Error(`进度状态不是 complete：${progress.phase ?? "missing"}`);
if (requiresBinding && (progress.source_fingerprint !== process.env.EXPECTED_FINGERPRINT || Number(progress.source_file_count) !== Number(process.env.EXPECTED_FILE_COUNT))) {
  throw new Error("采集进度的源码指纹或文件数与本次启动不一致");
}
process.stdout.write("ok");
NODE
	)"; then
		print -u2 "图形采集完成状态校验失败：$progress_result"
		exit 125
	fi
fi

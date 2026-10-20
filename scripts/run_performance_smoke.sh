#!/usr/bin/env zsh
set -euo pipefail

project_dir="gta-reference-runtime"
log_file="/tmp/godot-reference-performance.log"
output_file="/tmp/godot-reference-performance.out"

: > "$log_file"
: > "$output_file"
if ! godot --headless --path "$project_dir" --log-file "$log_file" -s res://tests/runtime_performance_smoke_test.gd > "$output_file" 2>&1; then
	cat "$output_file"
	print -u2 "Godot 性能烟雾测试进程失败"
	exit 1
fi
cat "$output_file"
if rg -n "SCRIPT ERROR|Parse Error|Failed to load script|Invalid type|Invalid access|Assertion failed|Cannot infer the type|handle_crash" "$output_file" "$log_file" >/dev/null 2>&1; then
	print -u2 "Godot 性能烟雾测试出现脚本错误或引擎崩溃"
	exit 1
fi
print "性能烟雾测试命令通过；日志使用显式临时路径，结果仅代表当前主机"

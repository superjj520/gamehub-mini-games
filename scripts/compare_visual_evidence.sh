#!/usr/bin/env zsh
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
	print -u2 "用法：$0 参考帧.png 运行时截图.png 报告.json"
	exit 2
fi

resolve_path() {
	local input_path="$1"
	if [[ "$input_path" = /* ]]; then
		print -r -- "$input_path"
	else
		print -r -- "$PWD/$input_path"
	fi
}

reference_path="$(resolve_path "$1")"
candidate_path="$(resolve_path "$2")"
report_path="$(resolve_path "$3")"
godot --headless --path gta-reference-runtime --log-file /tmp/godot-visual-compare.log -s res://tests/visual_compare.gd -- "$reference_path" "$candidate_path" "$report_path"

#!/bin/zsh
set -euo pipefail

workspace_root="$(cd "$(dirname "$0")/.." && pwd)"
build_path="$workspace_root/${FULL_CANDIDATE_WINDOWS_BUILD_PATH:-build/windows/新时代觉醒者-完整候选.exe}"
build_manifest="$workspace_root/${FULL_CANDIDATE_WINDOWS_BUILD_MANIFEST:-reference-evidence/candidate-runtime/full-candidate-windows-build.json}"
candidate_readme="$workspace_root/${FULL_CANDIDATE_PACKAGE_ROOT:-build/internal-full-candidate}/CANDIDATE_PACKAGE_README.md"
qa_script="$workspace_root/scripts/windows_device_qa.ps1"
matrix_script="$workspace_root/scripts/windows_reference_matrix_capture.ps1"
expanded_matrix_script="$workspace_root/scripts/windows_expanded_visual_capture.ps1"
expanded_capture_script="$workspace_root/scripts/capture_expanded_visual_matrix.gd"
complete_qa_script="$workspace_root/scripts/windows_complete_qa.ps1"
complete_qa_verifier="$workspace_root/scripts/verify_windows_complete_qa.mjs"
complete_qa_contract="$workspace_root/scripts/verify_windows_complete_qa_script_contract.mjs"
qa_runbook="$workspace_root/docs/windows-device-qa-runbook.md"
bundle_exe_name="${FULL_CANDIDATE_WINDOWS_BUNDLE_EXE_NAME:-新时代觉醒者-完整候选.exe}"
bundle_build_manifest_name="${FULL_CANDIDATE_WINDOWS_BUNDLE_BUILD_MANIFEST_NAME:-full-candidate-windows-build.json}"
output_path="$workspace_root/${FULL_CANDIDATE_WINDOWS_QA_OUTPUT:-build/新时代觉醒者-完整候选-windows-qa.zip}"
temporary_root="$(mktemp -d "/private/tmp/xindai-windows-qa.XXXXXX")"

cleanup() {
  rm -rf "$temporary_root"
}
trap cleanup EXIT

if [[ ! -f "$build_path" || ! -f "$build_manifest" || ! -f "$candidate_readme" || ! -f "$qa_script" || ! -f "$matrix_script" || ! -f "$expanded_matrix_script" || ! -f "$expanded_capture_script" || ! -f "$complete_qa_script" || ! -f "$complete_qa_verifier" || ! -f "$complete_qa_contract" || ! -f "$qa_runbook" ]]; then
  print -u2 "缺少完整候选 Windows QA 包输入，请先执行 npm run package:candidate:full && npm run export:candidate:windows"
  exit 1
fi

mkdir -p "$temporary_root/build/windows" \
  "$temporary_root/scripts" \
  "$temporary_root/reference-evidence/candidate-runtime"
cp "$build_path" "$temporary_root/build/windows/$bundle_exe_name"
cp "$build_manifest" "$temporary_root/reference-evidence/candidate-runtime/$bundle_build_manifest_name"
cp "$candidate_readme" "$temporary_root/CANDIDATE_PACKAGE_README.md"
cp "$qa_script" "$temporary_root/scripts/windows_device_qa.ps1"
cp "$matrix_script" "$temporary_root/scripts/windows_reference_matrix_capture.ps1"
cp "$expanded_matrix_script" "$temporary_root/scripts/windows_expanded_visual_capture.ps1"
cp "$expanded_capture_script" "$temporary_root/scripts/capture_expanded_visual_matrix.gd"
cp "$complete_qa_script" "$temporary_root/scripts/windows_complete_qa.ps1"
cp "$complete_qa_verifier" "$temporary_root/scripts/verify_windows_complete_qa.mjs"
cp "$complete_qa_contract" "$temporary_root/scripts/verify_windows_complete_qa_script_contract.mjs"
cp "$qa_runbook" "$temporary_root/WINDOWS_DEVICE_QA_RUNBOOK.md"

rm -f "$output_path"
(cd "$temporary_root" && zip -qr "$output_path" .)
shasum -a 256 "$output_path"
print "Windows 内部 QA 包已生成：$output_path"

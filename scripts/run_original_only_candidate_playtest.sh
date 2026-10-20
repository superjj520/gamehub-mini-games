#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}/.."
log_file="/tmp/xinjieyuanjuexing-original-only-candidate-playtest.log"
candidate_catalog="${workspace_root}/gta-reference-runtime/content/asset-runtime-catalog-original-only.json"
if [[ ! -f "${candidate_catalog}" ]]; then
  print -u2 "原创边界候选资产目录不存在：${candidate_catalog}"
  exit 1
fi
exec env \
  REFERENCE_ASSET_PREVIEW=1 \
  REFERENCE_ASSET_CATALOG_PATH="res://content/asset-runtime-catalog-original-only.json" \
  CANDIDATE_VARIANT=original_only \
  zsh "${workspace_root}/scripts/launch_current_candidate_macos.sh" "$@"

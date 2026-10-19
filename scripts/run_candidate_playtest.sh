#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}/.."
log_file="/tmp/xinjieyuanjuexing-candidate-playtest.log"
candidate_catalog="${workspace_root}/gta-reference-runtime/tests/asset-runtime-catalog-override.json"
if [[ ! -f "${candidate_catalog}" ]]; then
  print -u2 "候选资产目录不存在：${candidate_catalog}"
  exit 1
fi
exec env REFERENCE_ASSET_PREVIEW=1 REFERENCE_ASSET_CATALOG_PATH="${candidate_catalog}" godot --path "${workspace_root}/gta-reference-runtime" --log-file "${log_file}" "$@"

#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}/.."
exec env COMBINED_OFFICE_CANDIDATE_PLAYTEST=1 node "${workspace_root}/art-source/environment/polyhaven-metal-office-desk/run_combined_office_candidate_runtime.mjs"

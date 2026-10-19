#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}"
cd "${workspace_root}"
exec env CANDIDATE_VARIANT=full zsh scripts/launch_current_candidate_macos.sh

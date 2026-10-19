#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}"
cd "${workspace_root}"
exec zsh scripts/launch_current_candidate_macos.sh

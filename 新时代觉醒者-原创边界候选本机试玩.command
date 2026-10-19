#!/bin/zsh
set -euo pipefail

workspace_root="${0:A:h}"
cd "${workspace_root}"
npm run playtest:candidate:original-only:mac

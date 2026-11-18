#!/usr/bin/env bash
# The emulator keeps everything in memory. After it restarts, local tfstate
# points at resources that no longer exist; run this to start clean.
#
# Example:
#   ./scripts/reset-state.sh
#   ./scripts/reset-state.sh ec2-test1
set -uo pipefail

env_name="${1:-eks-test1}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$root/env/$env_name"

rm -f "$dir"/terraform.tfstate*
echo "Removed tfstate in $dir"

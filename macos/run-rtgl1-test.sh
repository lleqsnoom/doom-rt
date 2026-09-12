#!/usr/bin/env bash
# Run the RTGL1 example (path-traced test scene) on macOS using the patched
# MoltenVK with experimental Metal ray tracing enabled.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

MOLTENVK_DIR="${MOLTENVK_DIR:-$WORK/MoltenVK/build/MoltenVK}"
EXAMPLE="${EXAMPLE:-$WORK/RTGL1/Build/RtglExample}"

export MVK_CONFIG_ENABLE_EXPERIMENTAL_RAY_TRACING=1
export DYLD_LIBRARY_PATH="$(dirname "$EXAMPLE"):$MOLTENVK_DIR:${DYLD_LIBRARY_PATH:-}"

cd "$(dirname "$EXAMPLE")"
exec ./RtglExample "$@"

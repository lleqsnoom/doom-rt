#!/usr/bin/env bash
# Build the full macOS ray-traced Doom stack end to end:
#   1. MoltenVK with experimental Metal ray tracing (+ patched SPIRV-Cross)
#   2. RTGL1 renderer for macOS
#   3. PrBoom+: Ray Traced game binary
#   4. Stage the run directory and its resources
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

"$HERE/build-moltenvk.sh"
"$HERE/build-rtgl1.sh"
"$HERE/build-game.sh"
"$HERE/fetch-assets.sh"

cat <<'EOF'

Build complete.

Next:
  1. Copy your Doom 2 IWAD into the run directory as Doom2.wad
  2. Review the run options in run.sh (see README.md)
  3. Launch:

       ./run.sh

  4. If startup hangs on "I_InitSound", run without sound:

       DOOMRT_NOSOUND=1 ./run.sh
EOF

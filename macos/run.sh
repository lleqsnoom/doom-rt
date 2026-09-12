#!/usr/bin/env bash
# Launch PrBoom+: Ray Traced (ray-traced Doom) on macOS.
#
# MoltenVK only exposes the ray-tracing extensions when experimental ray tracing
# is enabled, so MVK_CONFIG_ENABLE_EXPERIMENTAL_RAY_TRACING=1 is required.
set -euo pipefail

WORK="${WORK:-$HOME/Documents/GitHub/lleqsnoom/macos-spike}"
RUN_DIR="${RUN_DIR:-$WORK/doom-rt-run}"

if [ ! -x "$RUN_DIR/prboom-plus" ]; then
    echo "No prboom-plus in $RUN_DIR - run build-game.sh and fetch-assets.sh first." >&2
    exit 1
fi

cd "$RUN_DIR"

export MVK_CONFIG_ENABLE_EXPERIMENTAL_RAY_TRACING=1
# Prefer the bundled RTGL1 library next to the binary.
export DYLD_LIBRARY_PATH="$(pwd):${DYLD_LIBRARY_PATH:-}"

# Disable sound if requested; SDL audio startup can hang on machines/sessions
# without an output device.
if [ "${DOOMRT_NOSOUND:-0}" = "1" ]; then
    set -- -nosound "$@"
fi

# Doom 2 unless another IWAD is given.
case " $* " in
  *" -iwad "*) ;;
  *) set -- -iwad Doom2.wad "$@" ;;
esac

# Use the community Doom 2 lighting metainfo when present.
if [ -f ovrd/map_metainfo_doom2.txt ]; then
    case " $* " in
      *" -iwadrt "*) ;;
      *) set -- "$@" -iwadrt ovrd/map_metainfo_doom2.txt ;;
    esac
fi

# Ray-traced video mode unless overridden.
case " $* " in
  *" -vidmode "*) ;;
  *) set -- -vidmode RT "$@" ;;
esac

exec ./prboom-plus "$@"

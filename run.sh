#!/usr/bin/env bash
# Launch PrBoom+: Ray Traced (Doom with real-time path tracing)
set -e
cd "$(dirname "$0")"

# The RT renderer uses an Xlib Vulkan surface, so under Wayland/Hyprland we
# must force SDL to use X11 (XWayland).
export SDL_VIDEODRIVER=x11

# Prefer the bundled RTGL1 library next to the binary.
export LD_LIBRARY_PATH="$(pwd):${LD_LIBRARY_PATH}"

# Default to Doom 2 unless an -iwad is already given on the command line.
case " $* " in
  *" -iwad "*) ;;
  *) set -- -iwad doom2.wad "$@" ;;
esac

# Doom 2 has no built-in lighting metainfo; use the community addon
# (rellik66, doom2rt-0.9). Without it the engine has no sector lights.
case " $* " in
  *" -iwadrt "*) ;;
  *) set -- "$@" -iwadrt ovrd/map_metainfo_doom2.txt ;;
esac

exec ./prboom-plus "$@"

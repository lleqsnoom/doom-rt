Ray-traced Doom (PrBoom-Plus-RT) run directory for Omarchy (Arch, Hyprland/Wayland) on Intel Arc A770.

# Layout

- `run.sh` — launcher. Forces SDL to X11 (the RT renderer uses an Xlib Vulkan surface), prefers the bundled `libRayTracedGL1.so`, defaults to `doom2.wad`, and passes `-iwadrt ovrd/map_metainfo_doom2.txt` (community Doom 2 lighting data, without which the engine has no sector lights).
- `prboom-plus` — game binary, built from source with local patches.
- `libRayTracedGL1.so` — RTGL1 v1.1.1, built from source with local patches.
- `ovrd/` — RT resources from the official `prboom-rt-1.0.7.zip` release, overlaid with rellik66's `doom2rt-0.9.zip` addon (adds `map_metainfo_doom2.txt`, extra emissive textures).
- `backup-working-20260908/` — snapshot of binaries, launcher and config as of the first fully working setup.

WADs (`doom2.wad`, `doom.wad`, `prboom-plus.wad`) and built binaries are not tracked; see `.gitignore`.

# Sources

| Component | Upstream | Patched branch |
|---|---|---|
| Game | https://github.com/sultim-t/prboom-plus-rt | https://github.com/lleqsnoom/prboom-plus-rt/tree/doom2-rt-improvements |
| Renderer | https://github.com/sultim-t/RayTracedGL1 | https://github.com/lleqsnoom/RayTracedGL1/tree/arc-a770-fixes |

Both forks carry the tag `working-20260908` marking the verified running state.

# What is patched and why

Game (prboom-plus-rt):
- RT window renders without requiring input focus, otherwise it deadlocks under Hyprland (SDL windows appear only after the first presented frame).
- Sector light fallback: maps without lighting metainfo get a default white light per visible ceiling, so Doom 2 maps are not pitch black. Only used when no metainfo is loaded; the Doom 2 addon metainfo supersedes it.
- Nearest texture filtering for the pixelated look.
- Flashlight toggle and hint removed.
- GCC 16 build fixes (GLU and shader callback casts).

Renderer (RayTracedGL1):
- Nearest sampler defaults and no mipmapping, for crisp pixels.
- Intel Arc workarounds: unsupported device features disabled, `VK_KHR_SHADER_FLOAT16_INT8` dropped from the extension list (core in Vulkan 1.2, not re-enumerated on Arc).
- GCC 16 build fixes (missing includes).

# Build

Renderer first:

    cd ~/Documents/GitHub/lleqsnoom/RTGL1-rt
    cmake -B Build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DRG_WITH_SURFACE_XLIB=ON \
      -DVulkan_INCLUDE_DIR=$HOME/Vulkan-Headers/include
    cmake --build Build

Game (expects the renderer tree at `~/Documents/GitHub/lleqsnoom/RTGL1-rt`):

    cd ~/Documents/GitHub/lleqsnoom/prboom-plus-rt/prboom2
    RTGL1_SDK_PATH=~/Documents/GitHub/lleqsnoom/RTGL1-rt cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DCMAKE_C_STANDARD=99 \
      -DWITH_FLUIDSYNTH=ON
    RTGL1_SDK_PATH=~/Documents/GitHub/lleqsnoom/RTGL1-rt cmake --build build

Install: copy `prboom2/build/prboom-plus` and `RTGL1-rt/Build/RelWithDebInfo/libRayTracedGL1.so` here. Vulkan headers newer than the system package are expected at `~/Vulkan-Headers` (pacman was unavailable on this machine).

# Performance notes (Intel Arc A770, timedemo demo1)

| Setup | FPS |
|---|---|
| 720p window, 720p internal render, no Doom 2 metainfo (fallback lights) | 1–14, risk of GPU hang |
| Same, with the Doom 2 lighting addon | 51.8 |
| 1080p window, 1080p internal render, addon | 23.6 |
| 1080p window, 720p internal render, addon | 51.5 |

RT cost scales with the internal render resolution (`rt_renderscale` in `~/.prboom-plus/prboom-plus.cfg`), not the window size. For full HD, keep `rt_renderscale 5` (720p internal, NEAREST-upscaled). The fallback-lighting path above is intentionally slow; do not raise `rt_renderscale` or `uncapped_framerate` while it is active.

# Restore the tagged working state

    cd ~/Documents/GitHub/lleqsnoom/prboom-plus-rt && git checkout working-20260908
    cd ~/Documents/GitHub/lleqsnoom/RTGL1-rt && git checkout working-20260908

then rebuild both. The `backup-working-20260908/` directory holds the matching prebuilt binaries and config without rebuilding.

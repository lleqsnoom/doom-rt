# Ray-traced Doom on macOS (Apple Silicon)

Working path-traced Doom 2 on an Apple Silicon Mac. The game runs, ray tracing is
driven by Metal through a patched MoltenVK, and the demo loop renders on an M4 Max.

Verified environment: MacBook Pro (Mac16,5), Apple M4 Max, macOS 26.6, Apple
Command Line Tools (no Xcode app), CMake and Ninja from Homebrew.

Measured on Doom 2 `demo1` with the built-in render scale settings:

| Internal render | Settings | FPS |
|---|---|---|
| 800p | `rt_renderscale 5`, `rt_fsr 0` (default) | 43.8 |
| 640p | `rt_renderscale 4`, `rt_fsr 0` | 50.0 |
| 450p | `rt_renderscale 6`, `rt_fsr 4` | 51.7 |

## How it works

There is no shipped Vulkan ray-tracing support on macOS. The stack is:

| Layer | Project | What it provides |
|---|---|---|
| Driver | `dttdrv/MoltenVK` branch `macgaming/ray-query-pr`, commit `d5e5032` (PR #2771) | Experimental Metal ray tracing: `VK_KHR_acceleration_structure`, `VK_KHR_ray_tracing_pipeline`, `vkCmdTraceRaysKHR` |
| Shader codegen | `dttdrv/SPIRV-Cross` commit `6c153db` + local patch | SPIR-V to Metal Shading Language ray-tracing translation |
| Renderer | `lleqsnoom/RayTracedGL1` branch `arc-a770-fixes`, commit `6e8e75e` (RTGL1, API 1.01) | Path tracer: GI, reflections, denoising (SVGF), bloom |
| Game | `lleqsnoom/prboom-plus-rt` branch `doom2-rt-improvements` | Doom engine with RTGL1-driven rendering |

The MoltenVK, SPIRV-Cross, RTGL1 and Vulkan-Headers revisions are pinned (the
`*_REV` variables in `common.sh` and the build scripts), so a rebuild reproduces
the verified stack.

MoltenVK only exposes the ray-tracing extensions when
`MVK_CONFIG_ENABLE_EXPERIMENTAL_RAY_TRACING=1` is set in the environment. The
launcher sets it automatically.

## Quick start

From the repository root, the `doom-rt-mac` launcher wraps `macos/run.sh`:

```sh
./doom-rt-mac -wad "/path/to/Doom2.wad" -warp 1 -skill 3
```

`-wad` sets the IWAD (defaults to `Doom2.wad` in the run directory) and any other
arguments are passed to the game (`-file`, `-warp`, `-skill`, ...). Add
`DOOMRT_NOSOUND=1` if startup hangs on `I_InitSound`.

To build from scratch:

Requirements: Apple Silicon Mac, Python 3, `cmake`, `ninja`, `glslangValidator`,
SDL2 (Homebrew `sdl2` / `sdl2-compat`), `libvorbis`, `libogg`, `libmad`.

```sh
./build-all.sh
cp /path/to/Doom2.wad "$HOME/Documents/GitHub/lleqsnoom/macos-spike/doom-rt-run/"
./run.sh
```

`build-all.sh` runs:

1. `build-moltenvk.sh` - clones and builds the experimental MoltenVK with the
   local SPIRV-Cross patch.
2. `build-rtgl1.sh` - builds the RTGL1 macOS renderer and its 46 SPIR-V shaders.
3. `build-game.sh` - builds `prboom-plus` and stages the run directory.
4. `fetch-assets.sh` - downloads the official RT resource pack (`ovrd/`,
   `prboom-plus.wad`) and installs the locally built shaders.

Each step caches its source tree under `WORK` (default
`~/Documents/GitHub/lleqsnoom/macos-spike`) and is safe to re-run.

Optional smoke test that does not need the game: `./build-rtgl1-example.sh` then
`./run-rtgl1-test.sh` build and run the upstream RTGL1 example scene.

## In-game notes

- A green `FPS: n` counter is drawn top-right.
- Mouse look, including up/down, is on by default. Toggle it in game with the
  `Mouse Look` key (default `\`) or Options > General > Enable Mouselook. Flip the
  vertical axis with `Invert Mouse`; clamp the angle with `Max View Pitch`.
- If audio stutters, it is almost always the output device. The mixer already runs
  on SDL's own audio thread, so force a clean device instead:
  `DOOMRT_AUDIO_DEVICE="Głośniki (MacBook Pro)" ./doom-rt-mac -wad ...`. Bluetooth
  headphones and virtual drivers (e.g. Boom 3D) add latency and dropouts.
- Fullscreen: pass `-fullscreen` (or press Command-F in game). RT mode uses true
  fullscreen; `SDL_WINDOW_FULLSCREEN_DESKTOP` only fills the usable area under the
  menu bar with the Metal backend.
- Retina: RT mode renders at the display's backing scale (3456x2234 on the built-in
  panel), so the HUD and final image are not upscaled from 1x points. The 3D detail
  is still set by `rt_renderscale`.
- The launcher uses a Sound-OFF default only when `DOOMRT_NOSOUND=1` is set; see
  Known issues.
- For a crisp, non-upscaled image run the window at 720p (`screen_resolution
  "1280x720"`) with `rt_renderscale 5` (720): the render is then native 1:1.
- Tune cost with `rt_renderscale` (render height) and `rt_bounce_quality`
  (1 = single-bounce GI). `render_vsync 0` uncaps; the frame limiter caps at
  `cap_fps`.

## Patches and why they exist

### MoltenVK / SPIRV-Cross

- `patches/spirv-cross-msl-raytracing.patch` - teaches SPIRV-Cross's MSL backend
  the Metal types of ray-tracing built-ins (`gl_LaunchIDEXT` and friends). Without
  it every ray-generation/helper shader fails to compile to MSL with
  `unknown type name 'unsupported-built-in-type'`, because a built-in passed as a
  function parameter falls through `builtin_type_decl`'s default case.

### RTGL1 (`patches/rtgl1-rt-macos.patch`)

- **Feature masking before `vkCreateDevice`** (`VulkanDevice.cpp`). MoltenVK fails
  device creation outright if any requested feature is unsupported. The patch
  queries the device and clears every feature bit it does not report, instead of
  aborting.
- **Unified-memory memory-type selection** (`PhysicalDevice.cpp`). On Apple
  Silicon the memory type that matches can also carry the "ignored" flags; the
  patch adds a fallback so a suitable type is always found.
- **VMA `aligned_alloc` fix** (`Vma/vk_mem_alloc.h`). macOS `aligned_alloc`
  returns NULL for sizes that are not a multiple of the alignment, which made
  VMA's user-data string copy crash on the first allocation. The patch uses
  `posix_memalign` on Apple instead.
- **libc++ portability**: missing `<algorithm>`/`<type_traits>` includes and a
  `std::min` call mixing `uint64_t` and `size_t` (same type on LP64 Linux,
  different on macOS).
- **glslang shader fix**: removed an unused `sampler2D getTexture()` helper that
  newer glslang rejects ("sampler cannot be used as return type").
- **Non-sRGB swapchain** (`Swapchain.cpp`). MoltenVK exposes sRGB surface formats,
  and RTGL1 prefers them, but its final image is already display-ready, so the
  sRGB swapchain encodes it a second time and the whole frame - 3D and 2D screens
  alike - comes out too bright. The patch prefers `*_UNORM` formats.
- **Barrier before the 2D overlay pass** (`VulkanDevice.cpp`). The swapchain
  raster pass uses `loadOp = LOAD` on the image the effects/blits just wrote, but
  its render-pass dependency had `srcAccessMask = 0`. On a tile-based Apple GPU
  that loads stale tiles, which showed up as small 8x8/16x16 block artifacts and
  flicker on the HUD, menus and FPS counter. The patch inserts the missing
  `BarrierOne` before `DrawToSwapchain`.

### Game (`patches/prboom-plus-rt-macos.patch`)

- **FPS counter** (`hu_stuff.c`). Green `FPS: n` text, top-right, computed from
  `SDL_GetTicks` (the fork's `renderer_fps` only updates via `R_ShowStats`, which
  reads 0 in RT mode here).
- **Frame limiter + dimmer fallback lights** (`d_main.c`, `RT/rt_geom.c`). Caps
  uncapped rendering at `cap_fps` for steadier pacing, and scales the no-metainfo
  fallback sector light from 1.0 to 0.8.
- **Mouse look on by default** (`m_misc.c`). `movement_mouselook` defaults to 1, so
  the mouse looks up/down without touching the menus. The engine already feeds the
  pitch into the RT camera (`R_BuildModelViewMatrix` has a `VID_MODERT` branch), so
  no renderer change was needed.
- **Audio output device override** (`SDL/i_sound.c`). Opens playback with
  `SDL_OpenAudioDevice` and honours `DOOMRT_AUDIO_DEVICE` to select a named output
  device, so a glitchy virtual driver or a Bluetooth sink can be bypassed while the
  system default stays unchanged.
- **Zero the audio callback buffer** (`SDL/i_sound.c`). SDL does not clear the
  buffer handed to the callback and the mixer adds into it; the original code only
  zeroed it when `snd_midiplayer == NULL`, so the previous buffer was reused and
  sounds stacked into a continuous buzz. It is now cleared on every call.
- **True fullscreen in RT mode** (`SDL/i_video.c`). Adds `VID_MODERT` to the
  `SDL_WINDOW_FULLSCREEN` branch; the desktop-fullscreen flag only produced a
  usable-area window with the Metal backend.
- **High-DPI / Retina output** (`SDL/i_video.c`). RT windows set
  `SDL_WINDOW_ALLOW_HIGHDPI`, so the Metal drawable matches the panel (3456x2234)
  instead of 1x points (1728x1117) upscaled by the display.
- **Metal surface** (`RT/rt_main.c`). Creates the swapchain surface from an
  `SDL_Metal_CreateView` layer via `RgMetalSurfaceCreateInfo` instead of Xlib, and
  destroys the view on shutdown.
- **CMake**: selects `RG_USE_SURFACE_METAL` and the `.dylib` on Apple, keeping the
  Xlib branch for Linux.
- **macOS headers**: `<OpenGL/glu.h>` include path, `_GLUfuncptr` shim, `<stddef.h>`
  for `size_t`, and a `NSInteger` comparator signature in the Cocoa launcher.

## Known issues

- **No sound.** Sound effects play through the default macOS output device. If you
  hear nothing, first check the system output is not muted (`osascript -e 'get
  volume settings'`). Music is unavailable in this build (compiled without
  SDL_mixer); the engine logs `I_InitMusic: Was compiled without SDL_Mixer
  support`. As a last resort `DOOMRT_NOSOUND=1` starts without audio, and an
  `SDL_OpenAudio` start-up hang has been reported on machines without an output
  device, though it did not reproduce here.
- **Doom 2 sector lights are approximate.** Proper lighting comes from
  `ovrd/map_metainfo_doom2.txt` (the `doom2rt-0.9` addon by rellik66), which is
  only distributed through ModDB and needs a browser download. Without it the
  game uses the fork's fallback white lighting; it will warn
  `Maps won't have additional light sources`.
- The MoltenVK ray-tracing path is experimental and unmerged upstream. Treat the
  pinned commits as part of the build.

## Layout

```
macos/
  common.sh                 # shared defaults, pinned revisions and helpers
  build-all.sh              # build everything end to end
  build-moltenvk.sh         # MoltenVK + patched SPIRV-Cross
  build-rtgl1.sh            # RTGL1 renderer (game, API 1.01) + shaders
  build-game.sh             # prboom-plus-rt + stage run directory
  fetch-assets.sh           # official ovrd/ resources and prboom-plus.wad
  run.sh                    # launcher
  build-rtgl1-example.sh    # optional: upstream RTGL1 example (API 1.03)
  run-rtgl1-test.sh         # optional: run the example
  bin/glslc                 # glslangValidator shim replacing the Vulkan SDK glslc
  patches/                  # local portability patches
```

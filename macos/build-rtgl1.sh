#!/usr/bin/env bash
# Build RTGL1 (RayTracedGL1) for macOS - the renderer the Doom game links against.
#
# This builds the arc-a770-fixes branch of lleqsnoom/RayTracedGL1 (API 1.01, the
# same API prboom-plus-rt expects) with Metal VkSurfaceKHR support, applies the
# local macOS portability patch, and compiles the ray-tracing shaders to SPIR-V.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HOME/Documents/GitHub/lleqsnoom/macos-spike}"
RTGL1_REPO="${RTGL1_REPO:-https://github.com/lleqsnoom/RayTracedGL1.git}"
RTGL1_BRANCH="${RTGL1_BRANCH:-arc-a770-fixes}"
RTGL1_DIR="${RTGL1_DIR:-$WORK/RTGL1-rt}"
VULKAN_HEADERS_DIR="${VULKAN_HEADERS_DIR:-$WORK/Vulkan-Headers}"
MOLTENVK_LIB="${MOLTENVK_LIB:-$WORK/MoltenVK/build/MoltenVK/libMoltenVK.dylib}"
JOBS="${JOBS:-}"

if [ ! -f "$MOLTENVK_LIB" ]; then
    echo "MoltenVK not found at $MOLTENVK_LIB - run build-moltenvk.sh first." >&2
    exit 1
fi

mkdir -p "$WORK"
cd "$WORK"

if [ ! -d "$VULKAN_HEADERS_DIR/.git" ]; then
    echo ">> Cloning Vulkan-Headers"
    git clone --depth 1 https://github.com/KhronosGroup/Vulkan-Headers.git "$VULKAN_HEADERS_DIR"
fi

if [ ! -d "$RTGL1_DIR/.git" ]; then
    echo ">> Cloning RTGL1 ($RTGL1_BRANCH)"
    git clone --depth 1 -b "$RTGL1_BRANCH" "$RTGL1_REPO" "$RTGL1_DIR"
fi

cd "$RTGL1_DIR"
echo ">> Applying macOS port patch"
git checkout -q -- .
git apply "$HERE/patches/rtgl1-rt-macos.patch"

# RTGL1's shader build shells out to glslc (Vulkan SDK), which is usually absent
# on a Mac with only Command Line Tools; bin/glslc is a glslangValidator shim.
export PATH="$HERE/bin:$PATH"

echo ">> Configuring RTGL1"
cmake -B Build -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DRG_WITH_SURFACE_METAL=ON \
    -DVulkan_INCLUDE_DIRS="$VULKAN_HEADERS_DIR/include" \
    -DVulkan_INCLUDE_DIR="$VULKAN_HEADERS_DIR/include" \
    -DVulkan_LIBRARIES="$MOLTENVK_LIB" \
    -DVulkan_LIBRARY="$MOLTENVK_LIB"

echo ">> Building RTGL1"
if [ -n "$JOBS" ]; then
    cmake --build Build -j "$JOBS"
else
    cmake --build Build
fi

echo ">> Compiling shaders"
(
    cd Source/Shaders
    mkdir -p Build
    python3 GenerateShaders.py
)

echo
echo "Built: $RTGL1_DIR/Build/libRayTracedGL1.dylib"
echo "Shaders: $RTGL1_DIR/Build/*.spv (46 files)"

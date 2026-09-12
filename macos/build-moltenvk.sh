#!/usr/bin/env bash
# Build MoltenVK with the experimental Metal ray-tracing support required to run
# the Vulkan ray-tracing Doom renderer (RTGL1) on Apple Silicon.
#
# This builds the unmerged KhronosGroup/MoltenVK PR #2771 ("Add Metal ray query
# and ray tracing support") from the author's fork, against the matching
# SPIRV-Cross revision that adds MSL ray-tracing codegen, plus a local patch that
# teaches SPIRV-Cross how to declare ray-tracing builtins used as function
# parameters (without it, every raygen/helper shader fails to compile to MSL).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-$HOME/Documents/GitHub/lleqsnoom/macos-spike}"
MOLTENVK_REPO="${MOLTENVK_REPO:-https://github.com/dttdrv/MoltenVK.git}"
MOLTENVK_BRANCH="${MOLTENVK_BRANCH:-macgaming/ray-query-pr}"
SPIRV_CROSS_REPO="${SPIRV_CROSS_REPO:-https://github.com/dttdrv/SPIRV-Cross.git}"
SPIRV_CROSS_REV="${SPIRV_CROSS_REV:-6c153db339ad0dfd57fe5808f8b29c98f013a2e5}"
JOBS="${JOBS:-}"

mkdir -p "$WORK"
cd "$WORK"

if [ ! -d MoltenVK/.git ]; then
    echo ">> Cloning MoltenVK ($MOLTENVK_BRANCH)"
    git clone --depth 1 -b "$MOLTENVK_BRANCH" "$MOLTENVK_REPO" MoltenVK
fi

if [ ! -d SPIRV-Cross/.git ]; then
    echo ">> Fetching pinned SPIRV-Cross ($SPIRV_CROSS_REV)"
    git init -q SPIRV-Cross
    (
        cd SPIRV-Cross
        git remote add origin "$SPIRV_CROSS_REPO"
        git fetch -q --depth 1 origin "$SPIRV_CROSS_REV"
        git checkout -q FETCH_HEAD
    )
fi

echo ">> Patching SPIRV-Cross MSL ray-tracing builtin types"
(
    cd SPIRV-Cross
    git checkout -q -- . 2>/dev/null || true
    git apply --whitespace=nowarn "$SCRIPT_DIR/patches/spirv-cross-msl-raytracing.patch"
)

cd MoltenVK
echo ">> Configuring MoltenVK"
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCPM_SPIRV-Cross_SOURCE="$WORK/SPIRV-Cross"

echo ">> Building MoltenVK"
if [ -n "$JOBS" ]; then
    cmake --build build --target MoltenVK -j "$JOBS"
else
    cmake --build build --target MoltenVK
fi

echo
echo "MoltenVK built: $WORK/MoltenVK/build/MoltenVK/libMoltenVK.dylib"
echo "Ray tracing stays disabled unless MVK_CONFIG_ENABLE_EXPERIMENTAL_RAY_TRACING=1 is set at runtime."

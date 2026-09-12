#!/usr/bin/env bash
# Optional smoke test: build the upstream RTGL1 example (hl1 branch, API 1.03)
# for macOS against the patched MoltenVK. This proves the MoltenVK ray-tracing
# stack initialises and traces rays without needing the game.
#
# This is NOT the renderer the game uses - see build-rtgl1.sh for that.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

RTGL1_REPO="${RTGL1_REPO:-https://github.com/sultim-t/RayTracedGL1.git}"
RTGL1_REV="${RTGL1_REV:-2457acc25df5766e48289205471cc2a07499f7f6}"

if [ ! -f "$MOLTENVK_LIB" ]; then
    echo "MoltenVK not found at $MOLTENVK_LIB - run build-moltenvk.sh first." >&2
    exit 1
fi

mkdir -p "$WORK"
cd "$WORK"

pin_repo "$VULKAN_HEADERS_DIR" "$VULKAN_HEADERS_REPO" "$VULKAN_HEADERS_REV" "$VULKAN_HEADERS_BRANCH"

if [ ! -d RTGL1/.git ]; then
    echo ">> Cloning RTGL1 ($RTGL1_REV)"
    git clone "$RTGL1_REPO" RTGL1
    (
        cd RTGL1
        git checkout -q "$RTGL1_REV"
        git submodule update --init --depth 1
    )
fi

cd RTGL1
echo ">> Applying macOS port patch"
git checkout -q -- .
git apply "$SCRIPT_DIR/patches/rtgl1-example-macos.patch"

export PATH="$SCRIPT_DIR/bin:$PATH"

echo ">> Configuring RTGL1 example"
cmake -B Build -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DRG_WITH_SURFACE_METAL=ON \
    -DRG_WITH_AMD_FSR2=OFF \
    -DRG_WITH_EXAMPLES=ON \
    -DRG_WITH_IMGUI=ON \
    -DVulkan_INCLUDE_DIR="$VULKAN_HEADERS_DIR/include" \
    -DVulkan_LIBRARY="$MOLTENVK_LIB"

echo ">> Building RTGL1 example"
cmake_build Build RtglExample

cp -f Tools/BlueNoise_LDR_RGBA_128.ktx2 ./BlueNoise_LDR_RGBA_128.ktx2
ln -sfn Build/shaders shaders

echo
echo "Built: $WORK/RTGL1/Build/RtglExample"

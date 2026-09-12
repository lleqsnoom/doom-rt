#!/usr/bin/env bash
# Build PrBoom+: Ray Traced (prboom-plus-rt) for macOS against the locally built
# RTGL1 renderer, then stage a runnable directory.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

GAME_REPO="${GAME_REPO:-https://github.com/lleqsnoom/prboom-plus-rt.git}"
GAME_BRANCH="${GAME_BRANCH:-doom2-rt-improvements}"
GAME_DIR="${GAME_DIR:-$WORK/prboom-plus-rt}"

if [ ! -f "$RTGL1_DIR/Build/libRayTracedGL1.dylib" ]; then
    echo "RTGL1 not found at $RTGL1_DIR/Build - run build-rtgl1.sh first." >&2
    exit 1
fi

mkdir -p "$WORK"
cd "$WORK"

if [ ! -d "$GAME_DIR/.git" ]; then
    echo ">> Cloning prboom-plus-rt ($GAME_BRANCH)"
    git clone --depth 1 -b "$GAME_BRANCH" "$GAME_REPO" "$GAME_DIR"
fi

cd "$GAME_DIR"
echo ">> Applying macOS port patch"
git checkout -q -- .
git apply "$SCRIPT_DIR/patches/prboom-plus-rt-macos.patch"

echo ">> Configuring prboom-plus-rt"
export RTGL1_SDK_PATH="$RTGL1_DIR"
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DWITH_FLUIDSYNTH=OFF \
    -DWITH_PORTMIDI=OFF \
    -DWITH_DUMB=OFF \
    -DWITH_ALSA=OFF \
    -DWITH_PCRE=OFF \
    -DBUILD_SERVER=OFF

echo ">> Building prboom-plus-rt"
cmake_build build

echo ">> Staging run directory: $RUN_DIR"
mkdir -p "$RUN_DIR"
cp -f build/prboom-plus "$RUN_DIR/"
cp -f build/prboom-plus.wad "$RUN_DIR/"
cp -f "$RTGL1_DIR/Build/libRayTracedGL1.dylib" "$RUN_DIR/"

echo
echo "Game binary: $RUN_DIR/prboom-plus"
echo "Run fetch-assets.sh next to add the ovrd/ resources, WAD and shaders."

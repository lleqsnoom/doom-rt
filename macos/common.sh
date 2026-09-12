#!/usr/bin/env bash
# Shared helpers for the macOS ray-traced Doom build scripts.
#
# Source this from a script with:
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK="${WORK:-$HOME/Documents/GitHub/lleqsnoom/macos-spike}"
RUN_DIR="${RUN_DIR:-$WORK/doom-rt-run}"
RTGL1_DIR="${RTGL1_DIR:-$WORK/RTGL1-rt}"
VULKAN_HEADERS_DIR="${VULKAN_HEADERS_DIR:-$WORK/Vulkan-Headers}"
VULKAN_HEADERS_REPO="${VULKAN_HEADERS_REPO:-https://github.com/KhronosGroup/Vulkan-Headers.git}"
VULKAN_HEADERS_BRANCH="${VULKAN_HEADERS_BRANCH:-main}"
VULKAN_HEADERS_REV="${VULKAN_HEADERS_REV:-ee2ec5fd83dafce291024683b50dc89219333076}"
MOLTENVK_LIB="${MOLTENVK_LIB:-$WORK/MoltenVK/build/MoltenVK/libMoltenVK.dylib}"
JOBS="${JOBS:-}"

# Run a cmake build, honouring an optional JOBS override.
# usage: cmake_build <build-dir> [target]
cmake_build() {
    local build_dir="$1"
    local target="${2:-}"
    local args=(--build "$build_dir")
    if [ -n "$target" ]; then
        args+=(--target "$target")
    fi
    if [ -n "$JOBS" ]; then
        cmake "${args[@]}" -j "$JOBS"
    else
        cmake "${args[@]}"
    fi
}

# Clone <repo> into <dir> (optionally tracking <branch>) and pin it to <rev>.
# usage: pin_repo <dir> <repo-url> <rev> [branch]
pin_repo() {
    local dir="$1"
    local repo="$2"
    local rev="$3"
    local branch="${4:-}"

    if [ ! -d "$dir/.git" ]; then
        echo ">> Cloning $dir"
        if [ -n "$branch" ]; then
            git clone --depth 1 -b "$branch" "$repo" "$dir"
        else
            git init -q "$dir"
            git -C "$dir" remote add origin "$repo"
        fi
    fi

    echo ">> Pinning $dir to ${rev:0:12}"
    git -C "$dir" fetch -q --depth 1 origin "$rev"
    git -C "$dir" checkout -q FETCH_HEAD
}

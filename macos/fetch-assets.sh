#!/usr/bin/env bash
# Fetch the official RT resources the game loads at runtime and place them in the
# run directory: ovrd/ (textures, materials, lighting metainfo, shaders) plus
# prboom-plus.wad. The RT shaders are replaced with the ones built locally so
# they match the renderer exactly.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

RELEASE_URL="${RELEASE_URL:-https://github.com/sultim-t/prboom-plus-rt/releases/download/v2.6.1-rt1.0.7/prboom-rt-1.0.7.zip}"

mkdir -p "$RUN_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo ">> Downloading $RELEASE_URL"
curl -L --fail -o "$TMP/prboom-rt.zip" "$RELEASE_URL"

echo ">> Extracting ovrd/ and prboom-plus.wad"
unzip -q -o "$TMP/prboom-rt.zip" -d "$TMP/extract"

# The Doom 2 lighting metainfo is a manual download; keep it across refreshes.
if [ -f "$RUN_DIR/ovrd/map_metainfo_doom2.txt" ]; then
    echo ">> Keeping existing map_metainfo_doom2.txt"
    cp -f "$RUN_DIR/ovrd/map_metainfo_doom2.txt" "$TMP/map_metainfo_doom2.txt"
fi

rm -rf "$RUN_DIR/ovrd"
cp -R "$TMP/extract/ovrd" "$RUN_DIR/ovrd"
cp -f "$TMP/extract/prboom-plus.wad" "$RUN_DIR/prboom-plus.wad"

if [ -f "$TMP/map_metainfo_doom2.txt" ]; then
    cp -f "$TMP/map_metainfo_doom2.txt" "$RUN_DIR/ovrd/map_metainfo_doom2.txt"
fi

if [ -d "$RTGL1_DIR/Build" ]; then
    echo ">> Installing locally built shaders"
    rm -f "$RUN_DIR"/ovrd/shaders/*.spv
    cp -f "$RTGL1_DIR/Build/"*.spv "$RUN_DIR/ovrd/shaders/"
fi

echo
echo "Resources staged in $RUN_DIR"
echo
echo "Optional: Doom 2 sector lighting (doom2rt-0.9 addon by rellik66)"
echo "  ModDB requires a browser download; fetch:"
echo "    https://www.moddb.com/mods/doom-lights-for-raytraced-prboom/addons/doom2-lights-for-prboomraytracing"
echo "  then copy map_metainfo_doom2.txt into:"
echo "    $RUN_DIR/ovrd/map_metainfo_doom2.txt"
echo "  Without it the game still runs, using the fork's fallback white lighting."
echo
echo "Place your IWAD at: $RUN_DIR/Doom2.wad"

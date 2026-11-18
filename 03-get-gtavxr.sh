#!/usr/bin/env bash
# Download the latest GTAVXR.exe release and copy it next to GTA5.exe so Steam can launch it.
set -e
source "$(dirname "$0")/env.sh"
mkdir -p "$HERE/bin"
tag=$(gh release view --repo LVL-VR/GTAVXR --json tagName -q .tagName)
echo "Latest release: $tag"
gh release download "$tag" --repo LVL-VR/GTAVXR --pattern GTAVXR.exe --dir "$HERE/bin" --clobber
sha256sum "$HERE/bin/GTAVXR.exe" | tee "$HERE/bin/GTAVXR.exe.sha256"
echo "$tag" > "$HERE/bin/VERSION"
need_gta
cp -v "$HERE/bin/GTAVXR.exe" "$GTA_DIR/GTAVXR.exe"

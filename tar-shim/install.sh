#!/usr/bin/env bash
# Install tar.exe into the GTA V prefix's system32 so the GTAVXR Suite can import .zip / .oiv
# mods. Refuses to overwrite a different tar.exe already there.
set -e
source "$(dirname "$0")/../env.sh"
need_gta
cd "$(dirname "$0")"
[ -f tar.exe ] || ./build.sh
dst="$PFX/drive_c/windows/system32/tar.exe"
if [ -f "$dst" ] && ! cmp -s tar.exe "$dst"; then
    grep -q "only handles .zip/.oiv" "$dst" 2>/dev/null || { echo "A different tar.exe is already at $dst; leaving it." >&2; exit 1; }
fi
cp tar.exe "$dst"
echo "Installed $dst"

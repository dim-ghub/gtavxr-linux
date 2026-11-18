#!/usr/bin/env bash
# Shared paths for the GTAVXR-on-Proton helper scripts. Source this, don't run it.
export APPID=271590   # GTA V Legacy on Steam (Enhanced is 3240220 and is NOT supported)
export STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HERE

# Find the library that holds the appmanifest for $APPID
GTA_LIB=""
while read -r lib; do
    [ -f "$lib/steamapps/appmanifest_$APPID.acf" ] && { GTA_LIB="$lib"; break; }
done < <(grep -oP '"path"\s+"\K[^"]+' "$STEAM_ROOT/steamapps/libraryfolders.vdf")
export GTA_LIB

if [ -n "$GTA_LIB" ]; then
    installdir=$(grep -oP '"installdir"\s+"\K[^"]+' "$GTA_LIB/steamapps/appmanifest_$APPID.acf")
    export GTA_DIR="$GTA_LIB/steamapps/common/$installdir"
    export COMPAT="$GTA_LIB/steamapps/compatdata/$APPID"
    export PFX="$COMPAT/pfx"
fi

need_gta() {
    if [ -z "$GTA_LIB" ] || [ ! -f "$GTA_DIR/GTA5.exe" ]; then
        echo "GTA V Legacy (appid $APPID) is not installed." >&2; exit 1
    fi
    if [ ! -d "$PFX/drive_c" ]; then
        echo "No Proton prefix at $PFX. Launch GTA V from Steam once first." >&2; exit 1
    fi
}

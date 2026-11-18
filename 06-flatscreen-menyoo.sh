#!/usr/bin/env bash
# Install Script Hook V + MenyooSP into the game folder for *flatscreen* GTA V.
#
#   ./06-flatscreen-menyoo.sh install     download (if needed) and copy into the game folder
#   ./06-flatscreen-menyoo.sh uninstall   remove exactly the files install added
#
# MenyooSP can't run inside GTAVXR (it pattern-scans Rockstar's exe), but it works in normal
# GTA V. The GTAVXR Suite moves Script Hook V, ASI loaders and loose .asi files out of the game
# folder for every VR session and puts them back afterwards, so both can share the folder.
# Flatscreen launches need WINEDLLOVERRIDES=dinput8=n,b, which launch.sh sets.
#
# Script Hook V is closed-source freeware by Alexander Blade (dev-c.com). Its version must
# match the game build; this downloads the build named in SHV_VERSION.
set -e
source "$(dirname "$0")/env.sh"
need_gta
cd "$HERE"
SHV_VERSION="${SHV_VERSION:-3889.0_1158.13}"
MENYOO_TAG="${MENYOO_TAG:-v2.4.4}"
dl="$HERE/downloads"; state="$dl/installed-files.txt"
mkdir -p "$dl"

if pgrep -f '[G]TA5\.exe|[G]TAVXR_SourceBaseline\.exe' >/dev/null; then echo "Close GTA V first." >&2; exit 1; fi

case "${1:-}" in
install)
    shv="$dl/ScriptHookV_$SHV_VERSION.zip"
    [ -f "$shv" ] || curl -fsSL -e 'http://www.dev-c.com/gtav/scripthookv/' -o "$shv" \
        "http://www.dev-c.com/files/ScriptHookV_$SHV_VERSION.zip"
    unzip -tq "$shv" >/dev/null || { echo "$shv is not a valid zip (download blocked?)" >&2; rm -f "$shv"; exit 1; }
    men="$dl/MenyooSP-$MENYOO_TAG.zip"
    if [ ! -f "$men" ]; then
        gh release download "$MENYOO_TAG" --repo itsjustcurtis/MenyooSP --pattern MenyooSP.zip --output "$men"
        want=$(gh api "repos/itsjustcurtis/MenyooSP/releases/tags/$MENYOO_TAG" --jq '.assets[]|select(.name=="MenyooSP.zip")|.digest' | sed 's/^sha256://')
        [ -z "$want" ] || [ "$(sha256sum "$men" | cut -d' ' -f1)" = "$want" ] || { echo "MenyooSP SHA-256 mismatch" >&2; rm -f "$men"; exit 1; }
    fi
    tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
    unzip -qo "$shv" 'bin/ScriptHookV.dll' 'bin/dinput8.dll' 'bin/args.txt' -d "$tmp/shv"
    unzip -qo "$men" 'Menyoo.asi' 'menyooStuff/*' -d "$tmp/menyoo"
    : > "$state.new"
    for src in "$tmp/shv/bin" "$tmp/menyoo"; do
        (cd "$src" && find . -type f -printf '%P\n') | while read -r f; do
            if [ -e "$GTA_DIR/$f" ] && ! grep -qxF "$f" "$state" 2>/dev/null; then
                echo "skip (already there, not ours): $f" >&2; continue
            fi
            install -D -m 644 "$src/$f" "$GTA_DIR/$f"; echo "$f" >> "$state.new"
        done
    done
    sort -u "$state.new" -o "$state"; rm -f "$state.new"
    echo "Installed $(wc -l < "$state") files into $GTA_DIR (list: $state)."
    echo "Script Hook V $SHV_VERSION, MenyooSP $MENYOO_TAG. Launch flatscreen with ./flatscreen.sh; press F8 in game."
    ;;
uninstall)
    [ -f "$state" ] || { echo "Nothing recorded as installed." ; exit 0; }
    while read -r f; do [ -n "$f" ] && rm -f -- "$GTA_DIR/$f"; done < "$state"
    find "$GTA_DIR/menyooStuff" -depth -type d -empty -delete 2>/dev/null || true
    echo "Removed $(wc -l < "$state") files."; rm -f "$state"
    ;;
*) echo "usage: $0 install|uninstall" >&2; exit 2 ;;
esac

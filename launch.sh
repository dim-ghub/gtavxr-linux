#!/usr/bin/env bash
# Steam launch option for GTA V Legacy:   /path/to/gtavxr-linux/launch.sh %command%
#
# Default: start the GTAVXR Suite instead of PlayGTAV.exe (VR).
# After ./flatscreen.sh: start normal GTA V once, with Wine loading Script Hook V's dinput8.dll.
mode=vr
flag="${XDG_RUNTIME_DIR:-/tmp}/gtavxr-linux-next-launch"
if [ -f "$flag" ]; then mode=$(cat "$flag"); rm -f -- "$flag"; fi

if [ "$mode" = flat ]; then
    export WINEDLLOVERRIDES="dinput8=n,b${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
    exec "$@"
fi
exec "${@/PlayGTAV.exe/GTAVXR.exe}"

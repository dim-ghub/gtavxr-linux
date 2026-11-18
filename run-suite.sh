#!/usr/bin/env bash
# Run the GTAVXR Suite inside the GTA V prefix WITHOUT Steam's game session.
# Good for install / settings / Fix now. For actually playing, launch GTA V from Steam
# with the launch option in steam-launch-options.txt so Steam DRM and wineopenxr are set up.
source "$(dirname "$0")/env.sh"
need_gta
exec protontricks-launch --appid "$APPID" "$GTA_DIR/GTAVXR.exe" "$@"

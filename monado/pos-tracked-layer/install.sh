#!/usr/bin/env bash
# Register the test layer as an implicit OpenXR layer for this user. It stays inactive
# unless GTAVXR_LINUX_POS_TRACKED=1 is set (the Monado test launch option does that), so
# other OpenXR apps and normal SteamVR play are unaffected. Undo with ./uninstall.sh.
cd "$(dirname "$0")"
[ -f libpos_tracked_layer.so ] || ./build.sh
d="${XDG_DATA_HOME:-$HOME/.local/share}/openxr/1/api_layers/implicit.d"
mkdir -p "$d"
cat > "$d/XR_APILAYER_GTAVXRLINUX_pos_tracked.json" <<JSON
{
    "file_format_version": "1.0.0",
    "api_layer": {
        "name": "XR_APILAYER_GTAVXRLINUX_pos_tracked",
        "library_path": "$PWD/libpos_tracked_layer.so",
        "api_version": "1.1",
        "implementation_version": "1",
        "description": "Test only: report POSITION_TRACKED for Monado's simulated HMD so GTAVXR renders",
        "enable_environment": "GTAVXR_LINUX_POS_TRACKED",
        "disable_environment": "GTAVXR_LINUX_POS_TRACKED_DISABLE"
    }
}
JSON
echo "Installed $d/XR_APILAYER_GTAVXRLINUX_pos_tracked.json"

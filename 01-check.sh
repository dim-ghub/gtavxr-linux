#!/usr/bin/env bash
# Report the state of everything GTAVXR needs. Read-only.
source "$(dirname "$0")/env.sh"

ok()   { printf '  \e[32mOK\e[0m    %s\n' "$*"; }
bad()  { printf '  \e[31mMISS\e[0m  %s\n' "$*"; }
info() { printf '  ..    %s\n' "$*"; }

echo "GTA V Legacy"
if [ -n "$GTA_LIB" ]; then
    ok "installed in $GTA_DIR"
    [ -f "$GTA_DIR/GTA5.exe" ] && ok "GTA5.exe present" || bad "GTA5.exe missing (still downloading?)"
    info "Steam build id: $(grep -oP '"buildid"\s+"\K[^"]+' "$GTA_LIB/steamapps/appmanifest_$APPID.acf")"
    [ -f "$GTA_DIR/GTA5.exe" ] && info "GTA5.exe version: $(python3 -I -c '
import re,sys
m=re.search("FileVersion\0".encode("utf-16-le")+rb"(?:\x00\x00)*((?:[0-9.]\x00)+)",open(sys.argv[1],"rb").read())
print(m.group(1).decode("utf-16-le") if m else "?")' "$GTA_DIR/GTA5.exe") (GTAVXR 1.0.2 wants 1.0.3889.0)"
    s="$PFX/drive_c/users/steamuser/Documents/Rockstar Games/GTA V/settings.xml"
    [ -f "$s" ] && info "settings.xml: DX_Version $(grep -oP 'DX_Version value="\K\d' "$s") (2 = DX11), ShaderQuality $(grep -oP 'ShaderQuality value="\K\d' "$s") (want 1 or 2)"
else
    bad "appid $APPID not installed"
fi

echo "Proton prefix"
if [ -d "${PFX:-/nonexistent}/drive_c" ]; then
    ok "$PFX"
    info "Proton used last: $(cat "$COMPAT/version" 2>/dev/null)"
    rel=$(grep -A6 -F '[Software\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full]' "$PFX/system.reg" | grep -oP '"Release"=dword:\K\w+')
    if [ -n "$rel" ] && [ $((16#$rel)) -ge 528040 ]; then ok ".NET Framework 4.8 (release $((16#$rel)))"; else bad ".NET Framework 4.8 (run 02-prep-prefix.sh)"; fi
    [ -f "$PFX/drive_c/windows/system32/msvcp140.dll" ] && ok "VC++ runtime" || bad "VC++ runtime (run 02-prep-prefix.sh)"
    xr=$(grep -A3 -F '[Software\\Khronos\\OpenXR\\1]' "$PFX/system.reg" | grep -oP '"ActiveRuntime"="\K[^"]+')
    [ -n "$xr" ] && ok "OpenXR ActiveRuntime in prefix: $xr" \
                 || bad "no OpenXR runtime registered in prefix (Proton adds it when launched from Steam with VR available)"
    [ -f "$PFX/drive_c/openxr/wineopenxr64.json" ] && ok "wineopenxr manifest present"
    [ -f "$HERE/bin/GTAVXR.exe" ] && ok "GTAVXR.exe downloaded ($HERE/bin)" || bad "GTAVXR.exe (run 03-get-gtavxr.sh)"
    [ -f "$GTA_DIR/GTAVXR.exe" ] && ok "GTAVXR.exe copied into game folder" || info "GTAVXR.exe not in game folder yet"
else
    bad "no prefix yet (launch GTA V from Steam once)"
fi

echo "Linux OpenXR"
rt=$(readlink -f "$HOME/.config/openxr/1/active_runtime.json")
[ -n "$rt" ] && ok "active runtime: $rt" || bad "no ~/.config/openxr/1/active_runtime.json"

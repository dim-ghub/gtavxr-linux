#!/usr/bin/env bash
# Toggle SteamVR's built-in "null" driver: a fake headset that renders into a desktop
# window, so GTAVXR's OpenXR path (Proton wineopenxr -> SteamVR) can be tested without
# a real headset. No controllers: use F9 for the VR menu and F10 to toggle VR.
#
#   ./fake-hmd.sh on      enable the fake HMD (remembers your previous settings)
#   ./fake-hmd.sh off     restore exactly what was there before
#   ./fake-hmd.sh status
#
# SteamVR must be closed: it rewrites steamvr.vrsettings when it exits.
set -e
source "$(dirname "$0")/env.sh"
cfg="$STEAM_ROOT/config/steamvr.vrsettings"
saved="$HERE/backup/fake-hmd-saved.json"
mode="${1:-status}"

if [ "$mode" != status ] && pgrep -x vrserver >/dev/null; then
    echo "Close SteamVR first (it overwrites steamvr.vrsettings on exit)." >&2; exit 1
fi
mkdir -p "$HERE/backup"
[ "$mode" != status ] && cp "$cfg" "$HERE/backup/steamvr.vrsettings.$(date +%Y%m%d-%H%M%S)"

python3 -I - "$cfg" "$saved" "$mode" <<'PY'
import json,os,sys
cfg,saved,mode=sys.argv[1:4]
d=json.load(open(cfg))
# (section, key, value when fake HMD is on)
WANT=[("driver_null","enable",True),
      ("driver_null","windowWidth",1920),("driver_null","windowHeight",1080),
      ("driver_null","renderWidth",1512),("driver_null","renderHeight",1680),
      ("driver_null","displayFrequency",90.0),
      ("steamvr","forcedDriver","null"),
      ("steamvr","directMode",False),        # extended mode: render into a desktop window
      ("steamvr","activateMultipleDrivers",True),
      ("steamvr","requireHmd",False)]
MISSING="__absent__"
def show():
    for s,k,_ in WANT: print(f"  {s}.{k} = {d.get(s,{}).get(k,'(unset)')}")
if mode=="status":
    print("fake HMD is", "ON" if d.get("steamvr",{}).get("forcedDriver")=="null" else "OFF"); show(); sys.exit()
if mode=="on":
    if os.path.exists(saved): print("Already on (saved settings exist). Run 'off' first to reset."); sys.exit()
    json.dump([[s,k,d.get(s,{}).get(k,MISSING)] for s,k,_ in WANT],open(saved,"w"))
    for s,k,v in WANT: d.setdefault(s,{})[k]=v
elif mode=="off":
    if not os.path.exists(saved): print("Not on (no saved settings), nothing to restore."); sys.exit()
    for s,k,v in json.load(open(saved)):
        if v==MISSING: d.get(s,{}).pop(k,None)
        else: d.setdefault(s,{})[k]=v
    for s in ("driver_null",):
        if s in d and not d[s]: del d[s]
    os.remove(saved)
else:
    sys.exit("usage: fake-hmd.sh on|off|status")
json.dump(d,open(cfg,"w"),indent=3)
print("fake HMD", mode.upper()); show()
PY

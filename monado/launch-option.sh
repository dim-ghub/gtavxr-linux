#!/usr/bin/env bash
# Print the Steam launch option for testing against Monado's simulated headset, with this
# checkout's paths filled in. Paste the output into GTA V → Properties → Launch Options.
#
# GTAVXR_LINUX_POS_TRACKED=1  enables pos-tracked-layer (install it once with pos-tracked-layer/install.sh)
# VR_OVERRIDE                 xrizer as the OpenVR runtime, so Proton sets up wineopenxr without SteamVR
# XR_RUNTIME_JSON             host Monado, as seen from inside Steam's container (/run/host)
# PRESSURE_VESSEL_...         lets the container reach monado-service's IPC socket
# PROTON_LOG / XR_LOADER_DEBUG   diagnostics in ~/steam-271590.log (drop them once it works)
#
# XRIZER defaults to /opt/xrizer (Arch's xrizer package); set it if yours is elsewhere.
here="$(cd "$(dirname "$0")" && pwd)"
xrizer="${XRIZER:-/opt/xrizer}"
[ -f "$xrizer/bin/linux64/vrclient.so" ] || echo "warning: no xrizer at $xrizer (set XRIZER=...)" >&2
echo "PROTON_LOG=1 XR_LOADER_DEBUG=all GTAVXR_LINUX_POS_TRACKED=1 VR_OVERRIDE=$xrizer XR_RUNTIME_JSON=$here/openxr_monado_container.json PRESSURE_VESSEL_FILESYSTEMS_RW=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/monado_comp_ipc bash -c 'exec \"\${@/PlayGTAV.exe/GTAVXR.exe}\"' -- %command%"

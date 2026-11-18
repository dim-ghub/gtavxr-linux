#!/usr/bin/env bash
# Fake headset for testing without VR hardware: Monado's "simulated" driver gives a
# headset (no controllers) and shows both eye views in an X11 window. Use F9 for the
# GTAVXR menu and F10 to toggle VR. Stop with ./stop-monado.sh. Log: monado.log here.
# (This Monado build's QWERTY_ENABLE disables every driver without creating the qwerty
# devices, so the keyboard/mouse-driven controllers aren't available.)
cd "$(dirname "$0")"
if [ -S "$XDG_RUNTIME_DIR/monado_comp_ipc" ] && pgrep -x monado-service >/dev/null; then
    echo "monado-service already running."; exit 0
fi
rm -f "$XDG_RUNTIME_DIR/monado_comp_ipc"
# monado-service watches stdin for 'q'; give it a pipe that stays open.
SIMULATED_ENABLE=1 XRT_COMPOSITOR_FORCE_XCB=1 XRT_COMPOSITOR_LOG=info \
    setsid bash -c 'sleep infinity | monado-service' >monado.log 2>&1 &
for _ in $(seq 1 20); do [ -S "$XDG_RUNTIME_DIR/monado_comp_ipc" ] && break; sleep 0.5; done
[ -S "$XDG_RUNTIME_DIR/monado_comp_ipc" ] && echo "monado-service up ($XDG_RUNTIME_DIR/monado_comp_ipc)" \
    || { echo "monado-service failed to start, see monado.log"; tail -20 monado.log; exit 1; }

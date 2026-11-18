#!/usr/bin/env bash
# Restart Steam WITHOUT SLSsteam (headcrab's steam.sh exports LD_AUDIT=.../SLSsteam.so).
# With SLSsteam hooked in, GTA V's launch hangs forever on "Updating product key"
# (Steam's GettingLegacyKey step). Nothing on disk is changed; the normal Steam
# launcher still loads SLSsteam next time.
steam -shutdown >/dev/null 2>&1
for _ in $(seq 1 30); do pgrep -f 'steamrt64/steam -srt' >/dev/null || break; sleep 1; done
env -u LD_AUDIT -u LD_PRELOAD setsid nohup "$HOME/.steam/steam/client.sh" "$@" >/dev/null 2>&1 &
echo "Steam starting without SLSsteam."

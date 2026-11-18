#!/usr/bin/env bash
# Launch GTA V in normal flatscreen mode (with Menyoo, if 06-flatscreen-menyoo.sh installed it)
# instead of GTAVXR. Add this file to Steam as a non-Steam game to get a library entry for it.
# Needs launch.sh as GTA V's launch option.
echo flat > "${XDG_RUNTIME_DIR:-/tmp}/gtavxr-linux-next-launch"
exec steam steam://rungameid/271590

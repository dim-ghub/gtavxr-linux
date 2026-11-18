#!/usr/bin/env bash
# Install what the GTAVXR Suite and its script host need into the GTA V prefix:
#   .NET Framework 4.8 (the Suite is a .NET Framework app; Script Host checks Release >= 528040)
#   VC++ 2015-2022 runtime (msvcp140/vcruntime140)
# Takes 10-20 min. Make sure GTA V / Steam game processes are closed first.
set -e
source "$(dirname "$0")/env.sh"
need_gta

echo "Backing up prefix registry to $HERE/backup/"
mkdir -p "$HERE/backup"
stamp=$(date +%Y%m%d-%H%M%S)
cp "$PFX"/{system,user,userdef}.reg "$HERE/backup/" 2>/dev/null
for f in "$HERE"/backup/*.reg; do mv "$f" "${f%.reg}-$stamp.reg"; done

protontricks "$APPID" -q --force dotnet48 vcrun2022
echo "Done. Re-run ./01-check.sh to confirm."

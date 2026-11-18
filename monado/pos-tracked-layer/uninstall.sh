#!/usr/bin/env bash
f="${XDG_DATA_HOME:-$HOME/.local/share}/openxr/1/api_layers/implicit.d/XR_APILAYER_GTAVXRLINUX_pos_tracked.json"
rm -f -- "$f" && echo "Removed $f"

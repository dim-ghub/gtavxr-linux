#!/usr/bin/env bash
# Builds the test layer. Needs gcc and the OpenXR headers (pacman: openxr).
cd "$(dirname "$0")"
gcc -O2 -fPIC -shared -fvisibility=hidden -Wall -o libpos_tracked_layer.so pos_tracked_layer.c

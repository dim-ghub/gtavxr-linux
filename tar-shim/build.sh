#!/usr/bin/env bash
# Builds tar.exe with Mono's C# compiler (pacman: mono). Runs on the prefix's .NET Framework.
cd "$(dirname "$0")"
mcs -nologo -sdk:4.5 -target:exe -platform:anycpu -optimize+ \
    -r:System.IO.Compression.dll -r:System.IO.Compression.FileSystem.dll -out:tar.exe tar.cs

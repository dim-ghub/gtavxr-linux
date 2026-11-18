# GTAVXR on Linux (Proton)

Scripts and fixes for running [GTAVXR by LVL](https://github.com/LVL-VR/GTAVXR), the VR mod for
GTA V, on Linux with Steam and Proton.

GTAVXR is a Windows app (the "Suite") that patches **GTA V Legacy 1.0.3889.0** and renders through
OpenXR. On Linux the Suite and the game run inside GTA V's Proton prefix. Proton's `wineopenxr`
passes the game's OpenXR calls to your Linux OpenXR runtime (SteamVR, or Monado for testing).

Tested with GTAVXR 1.0.2, Steam GTA V Legacy, Proton 11.0 and SteamVR on Arch-based Linux.
Monado's simulated headset was used to confirm VR rendering end to end.

## Requirements

- **GTA V Legacy** on Steam (app 271590). GTA V *Enhanced* is a different game and isn't supported.
- **Version 1.0.3889.0** of Legacy. A newer Rockstar patch breaks GTAVXR until LVL releases an update.
- Native (non-Flatpak) Steam. The scripts assume `~/.local/share/Steam`; set `STEAM_ROOT` otherwise.
- [`protontricks`](https://github.com/Matoking/protontricks) and the [GitHub CLI](https://cli.github.com/) (`gh`).
- A headset working with **SteamVR** on Linux.
- Story Mode only. GTA Online doesn't run on Linux (BattlEye), and GTAVXR doesn't support it anyway.

## Files

| File | What it does |
| --- | --- |
| `env.sh` | Finds the GTA V Legacy install and its Proton prefix (sourced by the other scripts) |
| `01-check.sh` | Read-only status report: game version, graphics settings, prefix, .NET, VC++, OpenXR |
| `02-prep-prefix.sh` | Backs up the prefix registry to `backup/`, then installs `dotnet48` and `vcrun2022` |
| `03-get-gtavxr.sh` | Downloads the latest `GTAVXR.exe` to `bin/` and copies it next to `GTA5.exe` |
| `04-fix-export-dir.sh` | Fixes GTAVXR's startup crash under Wine (see below) |
| `tar-shim/` | A small `tar.exe` for the prefix, so the Suite can import `.zip` / `.oiv` mods |
| `run-suite.sh` | Opens the Suite in the prefix without Steam (for install, settings, Fix now) |
| `steam-launch-options.txt` | Steam launch option that starts the Suite instead of `PlayGTAV.exe` |
| `monado/` | Testing without a headset, using Monado's simulated headset |

## Install

1. **Install GTA V Legacy** in Steam. It needs about 110 GB.
2. **Launch it once from Steam as normal.** This creates the Proton prefix and installs the
   Rockstar Games Launcher. Sign in, load Story Mode, and in **Settings → Graphics** set
   **DirectX 11** and **Shader Quality** to **High** or **Very High**. Save and quit.
   Run `./01-check.sh` to confirm the game version is 1.0.3889.0.
3. **Prepare the prefix:** `./02-prep-prefix.sh`. It takes 10–20 minutes; close the game first.
4. **Download GTAVXR:** `./03-get-gtavxr.sh`.
5. **Install GTAVXR into the game:** `./run-suite.sh`. Choose the GTA V Legacy folder
   (`01-check.sh` prints it), keep the default Suite data location, and click **Install GTAVXR**.
   Wine runs everything as administrator, so the docs' "Run as administrator" step doesn't apply.
6. **Fix the startup crash:** close the Suite, then run `./04-fix-export-dir.sh`.
7. **Point Steam at the Suite:** paste the line from `steam-launch-options.txt` into
   GTA V → Properties → General → Launch Options.

## Play

1. **Start SteamVR** with the headset connected, *before* launching the game.
2. **Launch GTA V from Steam.** The GTAVXR Suite opens instead of the game.
3. Leave **Settings → Headset** on **Automatic**, select the **VR Story** profile, and press **Play**.
4. Once you control your character in Story Mode, press **F10** with the game window focused if
   VR doesn't start by itself. The VR menu is the left controller's **Menu** button, **F9**, or L3+R3.
5. When you're done, save in GTA and quit from the pause menu, or use **Force GTA to close** in the
   Suite, so it can sync your saves. Killing the game makes the Suite ask for **Fix now** next time.

GTAVXR's own guides cover controls, the VR menu and the built-in trainer:
[docs](https://github.com/LVL-VR/GTAVXR#guides).

To go back to normal flatscreen GTA V, clear the launch option. To remove GTAVXR from the game,
use the Suite's **Settings → GTAVXR in the game → Uninstall**.

## What the fixes are for

### Startup crash: "The game has crashed though the dump failed to write"

GTAVXR's patched game exe (`GTAVXR_SourceBaseline.exe`) has a bogus PE export-directory entry:
it overlaps the import table and claims about 41 million exported names. When the game calls
`GetProcAddress` on itself, Windows faults inside the lookup, catches it and returns NULL. Wine
doesn't catch it, so the game crashes at startup (`c0000005` in `ntdll`).

`04-fix-export-dir.sh` clears that entry, which gives the same result Windows does. The Suite
checks the exe's hash before every Play, so the script also updates the stored hash in the Suite's
`versions/<id>.json` and `game/state.json` (backups go to `backup/`). It's safe to re-run.

**Don't use the Suite's Check files.** It "repairs" the exe back to the crashing version. If you do
run it, or update or reinstall GTAVXR, close the Suite and run `04-fix-export-dir.sh` again.

### SteamVR must be running before you launch

Proton only prepares `wineopenxr` when its OpenVR client initializes at launch, which needs SteamVR
running. Otherwise the Proton log shows `vrclient:initialize_vr_data Failed to initialize VR info`,
OpenXR fails with `negotiation failed with error -6`, and the game stays flat.

### Launch option

`$(echo %command% | sed …)`-style launch options break here because the game path contains
spaces. The `bash -c 'exec "${@/PlayGTAV.exe/GTAVXR.exe}"' -- %command%` form rewrites each
argument separately.

### Importing mods

Two things stop the Suite's **Mods → Add mod** under Wine:

- **"Windows tar.exe not found":** the Suite unpacks every `.zip` / `.oiv` with Windows'
  built-in `tar.exe`, which Wine doesn't have. Run `tar-shim/install.sh` once (needs Mono's `mcs`
  to build). It installs a small replacement that extracts zip-format archives and, like the real
  one, refuses entries that would land outside the destination. RAR and 7z archives aren't
  supported: extract those on Linux and import the extracted folder.
- **"Reparse point rejected: Z:\home":** the Suite rejects any path that passes through a symlink
  or junction, and Wine reports `Z:\home` as one. Copy mod files into the prefix first, for example
  `drive_c/users/steamuser/Downloads`, and pick them from `C:\users\steamuser\Downloads`.

## Testing without a headset

`monado/` runs GTAVXR against [Monado](https://monado.freedesktop.org/)'s simulated headset, so
you can check the whole VR path without hardware. It needs Monado and
[xrizer](https://github.com/Supreeeme/xrizer) installed, and it doesn't change your SteamVR or
system OpenXR settings.

1. Once: `monado/pos-tracked-layer/install.sh` (needs `gcc` and the OpenXR headers).
2. `monado/start-monado.sh`
3. Run `monado/launch-option.sh` and paste its output into GTA V's Launch Options.
4. Launch GTA V from Steam and press **Play**. There are no controllers, so use **F9** for the
   VR menu and **F10** to toggle VR. Monado shows both eye views in a window.
5. When done: `monado/stop-monado.sh`, and switch back to the normal launch option.

Why each piece is needed:

- **xrizer** (`VR_OVERRIDE`): stands in for SteamVR so Proton sets up `wineopenxr` (see above).
- **`openxr_monado_container.json`**: points at the host's Monado through `/run/host`, because
  the game runs inside Steam's container. It assumes Monado's library is in `/usr/lib`; adjust
  the paths if your distro uses `/usr/lib64` or `/usr/lib/x86_64-linux-gnu`.
- **`pos-tracked-layer`**: Monado's simulated headset never reports `POSITION_TRACKED`, and GTAVXR
  won't render a frame without it (the session runs but the Monado window stays black). This small
  OpenXR layer adds the flag. It's registered for your user but only active when
  `GTAVXR_LINUX_POS_TRACKED=1` is set, which the Monado launch option does.
  `pos-tracked-layer/uninstall.sh` removes it.
- **`xr-probe.py`**: a headless OpenXR probe that prints the tracking flags, eye separation and
  motion GTAVXR checks before it renders.

Some compositors (Hyprland, for example) map Monado's window at 0×0 or on another workspace.
If you don't see it, look for a window titled `Monado` and move or resize it.

## Troubleshooting

- **Status:** `./01-check.sh` shows the game version, graphics settings and prefix state.
- **GTAVXR logs:** each session writes to
  `<prefix>/drive_c/users/steamuser/AppData/Local/GTAVXR/Suite/sessions/<latest>/native/`.
  `xr.log` covers VR; `native-runtime.log` covers crashes.
- **Proton log:** put `PROTON_LOG=1` in front of the launch option to get `~/steam-271590.log`.
- **Steam hangs on "Updating product key":** that's Steam fetching the Rockstar CD key.
  Steam client modifications that hook Steam (for example via `LD_AUDIT`) can block it; start
  Steam without them for that launch.
- **Proton problems:** try **Proton Experimental** for GTA V, then re-run `02-prep-prefix.sh`.
- **DLSS and Neural Rendering** need an NVIDIA GPU. On AMD or Intel, use the **Native** preset.

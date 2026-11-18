# GTAVXR on Linux (Proton)

Helper scripts for running [GTAVXR by LVL](https://github.com/LVL-VR/GTAVXR) on this machine.
GTAVXR is a Windows-only .NET Framework "Suite" that patches **GTA V Legacy 1.0.3889.0**
and renders via OpenXR. On Linux it runs inside GTA V's Proton prefix; its OpenXR calls go
through Proton's `wineopenxr` to the Linux OpenXR runtime (SteamVR here, per
`~/.config/openxr/1/active_runtime.json`).

| File | What it does |
| --- | --- |
| `env.sh` | Finds the GTA V Legacy install and its prefix (sourced by the others) |
| `01-check.sh` | Read-only status report: game, prefix, .NET, VC++, OpenXR registration |
| `02-prep-prefix.sh` | Backs up the prefix registry to `backup/`, installs `dotnet48` + `vcrun2022` |
| `03-get-gtavxr.sh` | Downloads the latest `GTAVXR.exe` to `bin/` and copies it next to `GTA5.exe` |
| `04-fix-export-dir.sh` | Patches the startup crash (c0000005 in `GetProcAddress`) in GTAVXR's game exe under Wine |
| `monado/` | Monado simulated headset for testing without VR hardware (see below) |
| `fake-hmd.sh` | SteamVR null driver toggle; doesn't work on Linux SteamVR, keep it `off` |
| `run-suite.sh` | Opens the Suite in the prefix without Steam (install, settings, Fix now) |
| `steam-no-sls.sh` | Restarts Steam without SLSsteam (fixes the "Updating product key" hang) |
| `steam-launch-options.txt` | Launch option that makes Steam start the Suite instead of `PlayGTAV.exe` |

## Steps

1. **Install GTA V Legacy (appid 271590)** in Steam, *not* Enhanced. Install it to the
   `~/.local/share/Steam` library: `/mnt/games` has ~23 GB free and Legacy needs ~110 GB.
   (The empty `Grand Theft Auto V` folder on `/mnt/games` is a leftover and can be deleted.)
2. **Launch it once from Steam as normal.** This creates the prefix and installs the Rockstar
   Games Launcher. Sign in, reach Story Mode, then in **Settings → Graphics** set
   **DirectX 11** and **Shader Quality High/Very High**. Save and quit.
   Check `./01-check.sh`: it shows the Steam build. GTAVXR 1.0.2 only accepts
   Legacy **1.0.3889.0**; a newer Rockstar patch breaks it until LVL releases an update.
3. **Prep the prefix:** `./02-prep-prefix.sh` (10–20 min, close the game first).
4. **Get GTAVXR:** `./03-get-gtavxr.sh` (verifies against the release's SHA-256 shown on GitHub).
5. **Install GTAVXR into the game:** `./run-suite.sh` → pick the Legacy folder
   (`Z:\home\dim\.local\share\Steam\steamapps\common\Grand Theft Auto V`, or wherever
   `01-check.sh` says), keep the default Suite data location, click **Install GTAVXR**.
   Wine has no UAC, so "Run as administrator" doesn't apply.
5b. **Patch the startup crash:** `./04-fix-export-dir.sh`. GTAVXR's patched exe has a bogus
   PE export entry that Windows tolerates and Wine crashes on ("The game has crashed though the
   dump failed to write"). It also updates the exe's hash in the Suite's
   `versions/<id>.json` and `game/state.json`, otherwise Play refuses with "A file is not the
   one expected". Close the Suite first. Re-run it after **Check files**, a reinstall or a
   GTAVXR update. Don't let **Check files** "repair" the exe: that restores the crashing one.
6. **Point Steam at the Suite:** paste the line from `steam-launch-options.txt` into
   GTA V → Properties → Launch Options.
7. **Play:** start SteamVR (headset connected), then launch GTA V from Steam. In the Suite,
   leave **Settings → Headset** on **Automatic** (it picks up Proton's
   `C:\openxr\wineopenxr64.json`), select the **VR Story** profile and press **Play**.
   In game, focus the window and press **F10** if the headset stays blank.
   SteamVR menu key is **F9**, or L3+R3.

## Testing without a headset

Use Monado's simulated headset (`monado/`): run `monado/start-monado.sh`, put the line from
`monado/steam-launch-options-monado.txt` in GTA V's Launch Options, launch and press Play.
There are no controllers: use **F9** for the VR menu and **F10** to toggle VR. Stop it with
`monado/stop-monado.sh` and restore the normal launch option. This doesn't touch SteamVR's
config or `~/.config/openxr`.

Once, run `monado/pos-tracked-layer/install.sh`. Monado's simulated headset never reports
`POSITION_TRACKED`, and GTAVXR won't render a frame without it (the session runs but every
frame is empty and the Monado window stays black). The layer adds that flag, and it is only
active when `GTAVXR_LINUX_POS_TRACKED=1` is set, which the Monado launch option does.
`monado/xr-probe.py` shows the flags, eye separation and motion GTAVXR checks.

Hyprland maps Monado's window at 0×0 on another workspace. Find it with `hyprctl clients`
(title `Monado`) and move/resize it, e.g.
`hyprctl eval "hl.dispatch(hl.dsp.window.move({workspace='2', window='address:0x…'}))"`
then `hl.dsp.window.resize({x=960,y=540,exact=true, window=…})`.

`fake-hmd.sh` (SteamVR's null driver) does **not** work here: Linux SteamVR's compositor
only supports direct mode and fails with error 496 / `CannotDRMLeaseDisplay` under Hyprland.
It's kept only because `off` restores settings exactly; leave it off.

## Notes

- **SteamVR must be running before you launch GTA V from Steam.** Proton's `steam.exe` only
  prepares `wineopenxr` (Vulkan extension list in `HKLM\Software\Wine\VR`) if its OpenVR
  client initializes at launch. Otherwise the log shows `vrclient:initialize_vr_data Failed
  to initialize VR info` and OpenXR fails with `negotiation failed with error -6`.

- **Stuck on "Updating product key"**: that's Steam's `GettingLegacyKey` step (fetching the
  Rockstar CD key). On this machine it's caused by SLSsteam, which headcrab's `steam.sh`
  injects via `LD_AUDIT`. Run `./steam-no-sls.sh` and launch GTA V from that Steam session.
  Without SLSsteam the key comes back in under a second.
  Look for `GettingLegacyKey` in `~/.local/share/Steam/logs/console_log.txt`.

- AMD RX 6700-class GPU → DLSS / Neural Rendering are unavailable; use the **Native** preset.
- GTA Online doesn't run on Linux (BattlEye), but GTAVXR is Story Mode only.
- If VR doesn't start, run `./01-check.sh` after a Steam launch: the OpenXR registry entry
  should exist. Then check the Suite session log
  (`<prefix>/drive_c/users/steamuser/AppData/Local/GTAVXR/Suite/sessions/<latest>/native/xr.log`)
  and put `PROTON_LOG=1` in front of the launch option to get `~/steam-271590.log`.
- If Proton fails, set GTA V's compatibility tool to **Proton Experimental** and re-run step 3
  (a new Proton version can rebuild the prefix).
- To undo: clear the launch option, run the Suite → **Settings → GTAVXR in the game → Uninstall**.

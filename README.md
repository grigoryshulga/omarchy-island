# Omarchy Island

![Omarchy Island — native Quickshell plugin with braille effects, media controls, notifications, and weather](preview.png)

A native Quickshell plugin that replaces the Omarchy bar clock with notifications, media controls, weather, a calendar, and system controls. It follows the live Omarchy theme and reduced-motion settings without changing system files.

[Version 1.0.0](https://github.com/grigoryshulga/omarchy-island/releases/tag/v1.0.0) · [Changelog](CHANGELOG.md) · [MIT license](LICENSE)

## Features

- **Overview:** grouped notifications, sender actions, history, copyable verification codes, and per-source mute. MPRIS playback controls include seeking and volume when supported by the player. Devices with a battery also show a 20-segment charge gauge and power profiles. The gauge shows partial segments, turns red below 20% (with saturation and lightness derived from the theme alert color), and gently pulses the leading segment while charging (unless reduced motion is enabled).
- **Controls:** embedded Audio, Bluetooth, Network, Tailscale, and Monitors panels, plus quick toggles for microphone mute, DND, night light, idle inhibition, and recording.
- **Calendar and weather:** month navigation, ISO week numbers, configurable week start, current conditions, a seven-day forecast, city search, and °C / °F / K.
- **Bar indicators and OSD:** recording, remote sessions, updates, microphone mute, DND, night light, and idle inhibition. Volume and brightness appear as temporary braille gauges; layout changes briefly replace the clock with the language name.
- **Downloads:** watches `~/downloads` recursively, shows active file sizes, and opens the containing folder when clicked. Completed items remain for up to 30 minutes, capped at 30. File copies also trigger detection; the activity indicator does not represent a download percentage.
- **Braille effects:** audio-reactive artwork, weather scenes, hover spotlights, and click ripples, with support for reduced motion. Optional Voxtype integration shows recording and transcription status without taking focus.

## Installation

Requires the **Quickshell-based Omarchy shell** with `qs.Commons` and `qs.Ui`; Waybar editions are unsupported. Tested with Omarchy 4.5.0-3 and Quickshell 0.3.2.

Dependencies: `git`, `python`, `quickshell`, `wl-clipboard`, and `libpulse` (`parec`). Prebuilt Qt shaders are included; no build is needed to install.

Run in an unlocked Omarchy session, without `sudo`:

```bash
omarchy plugin add https://github.com/grigoryshulga/omarchy-island.git --yes
omarchy plugin disable omarchy.notifications
omarchy plugin enable gshulga.island
~/.config/omarchy/plugins/gshulga.island/bin/enable-indicators
omarchy restart shell
```

Disable the built-in notification daemon before enabling Island to avoid competing D-Bus servers. Omarchy replaces its clock with Island while preserving the clock format and position.

The indicator installer adds the `gshulga.island-osd` adapter and adjusts user bar configuration, with backups in `~/.local/state/omarchy/island/`. Native OSD remains the fallback when Island is unavailable; existing system actions and shortcuts are preserved.

### Update

```bash
omarchy plugin update gshulga.island
~/.config/omarchy/plugins/gshulga.island/bin/enable-indicators
omarchy restart shell
```

### Remove

```bash
~/.config/omarchy/plugins/gshulga.island/bin/enable-indicators --disable
omarchy plugin remove gshulga.island
omarchy plugin enable omarchy.notifications
```

Omarchy restores the clock. Skip the last command if built-in notifications were already disabled before installation. Island history is retained.

### Legacy installations

Copies installed with `bin/install` still use `git pull --ff-only`, `./bin/install`, and `./bin/uninstall` from the original clone. Use `omarchy plugin update` for copies managed by Omarchy.

To migrate, run `./bin/uninstall` from the old clone, move the old plugin directory to a backup, then follow the installation steps above:

```bash
mv ~/.config/omarchy/plugins/gshulga.island ~/.config/omarchy/plugins/.gshulga.island.before-native-$(date +%Y%m%d-%H%M%S)
```

## Controls

System panels are adapted from the installed Omarchy sources when opened, preserving native device and connection logic. Generated copies live in `$XDG_CACHE_HOME/omarchy-island/controls/` (default `~/.cache/omarchy-island/controls/`) and rebuild when the sources or adapter change. Custom installations can set `OMARCHY_PATH`. Panels close and release resources when leaving their section. An incompatible panel shows an error with details in the Quickshell log; system files remain unchanged. No separate Dashboard or Side Panel installation is required.

| Action | Result |
|---|---|
| Hover over the clock | Preview Overview |
| Click the clock or the free upper area of the preview | Pin the popup |
| Click the clock again, press Escape, or click outside | Close the popup |
| Middle-click the clock | Toggle the calendar |
| Right-click the clock | Cycle and save the clock format |
| Scroll over the clock | Open the full popup and cycle tabs |
| Horizontal swipe, touchpad scroll, or Shift + wheel in the popup | Switch pages |
| Hover over the player's volume icon | Show the volume slider |

### Keyboard

In the pinned popup, **Alt+1–4** selects Controls, Overview, Calendar, or Weather. A disabled Weather tab has no shortcut. **Tab / Shift+Tab** moves focus; **arrow keys / H J K L** select neighboring controls; **Enter / Space** activates the focused item. Text fields retain normal typing and caret movement. Space also toggles playback in Overview when not handled by a focused control.

In the calendar, arrows or Vim keys move the selected date, **Page Up / Page Down** changes months, and **Home** returns to today. Sliders use **Left / Right** or **H / L**. Embedded system panels retain their native navigation.

No global shortcut is assigned. Bind `omarchy-shell island toggle` to one if desired.

### IPC

```text
omarchy-shell island open|close|toggle|controls|calendar|weather|status
omarchy-shell notifications probe|toggleDnd|dismissAll
omarchy-shell island-update refresh|clear
```

## Settings

Settings belong to the `gshulga.island` entry in `~/.config/omarchy/shell.json`.

| Setting | Behavior |
|---|---|
| `format` | Clock format, inherited from the original clock |
| `musicApps` | Allowed MPRIS players; browsers are excluded by default |
| `notificationDuration` | Notification toast duration; default `5000` ms |
| `radialBraille` | Adaptive spotlight dots; default `true` |
| `calendarWeekStart` | `sunday` or `monday`; unset follows the Omarchy locale |
| `weatherEnabled` | Show weather and allow requests; default `true` |
| `weatherUnit` | `metric`, `imperial`, or empty to follow native weather settings, then country/locale |
| `weatherTemperatureUnit` | `celsius`, `fahrenheit`, `kelvin`, or empty to follow `weatherUnit` |
| `weatherRefreshMinutes` | `1`–`120`; `0` follows native weather settings or defaults to 15 minutes |

```bash
omarchy bar set gshulga.island weatherUnit metric
omarchy bar set gshulga.island weatherEnabled false --json
```

Click the weather city to search or choose automatic location; Enter confirms and Escape cancels. The location is shared with the native weather widget through `~/.local/state/omarchy/settings/weather.json`. Double-click the temperature unit, or focus it and press Enter / Space, to cycle °C → °F → K. The calendar gear selects the first day of the week.

For a single dictation OSD, disable other dictation visualizers and the native Voxtype OSD with `voxtype config set osd.enabled false`. Dictation settings and shortcuts remain in Voxtype.

### Optional Hyprland blur

Copy the included [layer rule](hyprland/island.lua):

```bash
cp ~/.config/omarchy/plugins/gshulga.island/hyprland/island.lua ~/.config/hypr/omarchy-island.lua
```

Add this outside managed blocks in `~/.config/hypr/looknfeel.lua`:

```lua
require("hypr.omarchy-island")
```

Apply with `hyprctl reload` and check `hyprctl configerrors`. Blur strength follows Hyprland's `decoration.blur` settings. Popup transparency follows `[popups] background-alpha` in the theme or `~/.config/omarchy/shell.toml`; at `1.0`, the background is opaque and blur is not visible.

## Data and privacy

- Notification history, mute, and DND state live in `~/.local/state/omarchy/island/state.json`, limited to 100 notifications and 24 hours. Directory permissions are `0700`; file permissions are `0600`.
- Expired notifications enter history; sender withdrawal removes them from both lists while Island retains the sender reference. After restart, saved entries are history only. Transient notifications are not saved.
- Verification-code notifications are redacted before persistence. Copied codes use a sensitive clipboard selection and are cleared after one minute unless the clipboard has changed.
- Playback audio is read through `parec` and processed in memory without saving PCM. Voxtype uses its existing audio bridge during recording; Island opens no separate microphone stream and saves neither dictation audio nor recognized text.
- Weather requests begin on first opening or hovering, with no requests beforehand. Automatic location uses `geo.omarchy.org`; search and forecasts use [Open-Meteo](https://open-meteo.com/). Requests use HTTPS, timeouts, and response limits. On failure, the last forecast remains marked stale; the cache is `~/.local/state/omarchy/island/weather.json`.

## Development

Sources live in `plugin/`. The root `manifest.json` serves the native plugin manager; `plugin/manifest.json` serves legacy flat installations. Keep shared metadata consistent and preserve their different entry point paths.

After editing fragment shaders, run `bin/build-shaders` with Qt `qsb` installed. Include the generated vertex shaders and `.qsb` files in the change.

### Verification

```bash
bin/test
```

The suite covers JS models, redaction and URL policy, notification and weather services, installation, and QML interactions. It requires Node.js, Python, `qs`, and Omarchy shell modules at `/usr/share/omarchy/shell`; QML interaction tests use offscreen rendering.

Additional checks for the affected feature:

```bash
python3 tests/live-notifications.py        # Requires a running Island instance
python3 tests/popup-motion.py              # Wayland popup geometry and animation
python3 tests/controls-adapter.py          # Panel generation, cache refresh, source integrity
python3 tests/keyboard.py                  # Keyboard input and focus
QT_QPA_PLATFORM=offscreen python3 tests/keyboard.py # Keyboard checks without Wayland focus
python3 tests/indicators.py                # Wayland indicators and native OSD
python3 tests/dictation.py                 # Dictation states and reduced motion
ISLAND_TEST_GPU=1 python3 tests/dictation.py # Dictation with GPU shaders
python3 tests/artwork-render.py            # GPU artwork frames and reduced motion
```

Read scripts before running them: live checks may interact with the current session. Artwork rendering requires OpenGL 3.3, a C++ compiler, and Qt6Gui.

## License

[MIT](LICENSE). Notification handling is adapted from Omarchy / [Omapager](https://github.com/omacom/omapager). See [THIRD_PARTY.md](plugin/THIRD_PARTY.md) for attribution and component licenses.

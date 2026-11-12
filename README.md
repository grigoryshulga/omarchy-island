# Omarchy Island

![Omarchy Island — native Quickshell plugin with braille effects, media controls, notifications, and weather](preview.png)

A native Quickshell plugin that replaces the Omarchy bar clock with notifications, media controls, weather, a calendar, and system controls. It follows the live Omarchy theme and reduced-motion settings without changing system files.

[Version 1.0.0](https://github.com/grigoryshulga/omarchy-island/releases/tag/v1.0.0) · [Changelog](CHANGELOG.md) · [MIT license](LICENSE)

## Features

- **Overview:** grouped notifications, sender actions, history, copyable verification codes, and per-source mute. MPRIS playback controls include seeking and volume when supported by the player. Devices with a battery also show a 20-segment charge gauge and power profiles. The gauge shows partial segments, uses the theme danger role below 20%, and gently pulses the leading segment while charging (unless reduced motion is enabled).
- **Controls:** embedded Audio, Bluetooth, Network, Tailscale, and Monitors panels, Island settings, plus quick toggles for microphone mute, DND, night light, idle inhibition, and recording.
- **Calendar and weather:** month navigation, ISO week numbers, configurable week start, current conditions, a seven-day forecast, city search, and °C / °F / K.
- **Bar indicators and OSD:** recording, remote sessions, updates, microphone mute, DND, night light, and idle inhibition. Volume and brightness appear as temporary braille gauges; layout changes briefly replace the clock with the language name.
- **Downloads:** watches `~/downloads` recursively, shows active file sizes, and opens the containing folder when clicked. Completed items remain for up to 30 minutes, capped at 30. File copies also trigger detection; the activity indicator does not represent a download percentage.
- **T3 Code (optional):** live session cards in Overview, a bar indicator for running sessions and pending requests, and inline answers to questions. Cards preserve drafts and focus while sessions update. Permission and authentication requests open in T3.
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

Cards and control tiles use a subtle fill without permanent outlines; nested action buttons stay transparent until interaction. Transparent page wrappers and grouped notification rows do not introduce additional spotlight boundaries.

The cursor spotlight becomes tighter and brighter inside hovered cards, tiles, and buttons. A soft brightness falloff, inner-edge bloom, and a path trail that fades over 720 ms stay clipped to the hovered surface, including its corners. Nearby elements catch a soft inner-edge glow on the side facing the cursor, including across gaps; transparent wrappers do not gain outlines. This proximity glow remains static with reduced motion. Approaching an edge scatters a few pixels along its inner rim. Reduced motion disables the trail and edge scatter.

The popup follows the clock on top, bottom, left, and right panels, staying inside the current monitor. It opens inward from the panel and keeps its cross-axis center stable during expansion, including near screen corners. Side panels stack clock indicators above and below the time and show a compact OSD; notification summaries use a popup card even when the horizontal bar style is selected. Horizontal clock slots at the start or end of the bar use a compact width.

### Keyboard

In the pinned popup, **Alt+1–4** selects Controls, Overview, Calendar, or Weather. Disabled sections have no shortcut and are skipped by wheel and swipe navigation; the remaining shortcuts keep their numbers. **Tab / Shift+Tab** moves focus; **arrow keys / H J K L** select neighboring controls; **Enter / Space** activates the focused item. Text fields retain normal typing and caret movement. Space also toggles playback in Overview when not handled by a focused control. Escape returns from Island settings to Controls before closing the popup. Dropdowns handle their own selection keys and Escape.

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

Open **Controls → Settings** (the sixth tile) for Island behavior, section visibility, music visualization, indicators, and events. Changes apply and save immediately. Settings inherit the Controls container size, with internal scrolling for longer categories. Controls always remain available so settings cannot become inaccessible. Disabling Overview does not suppress incoming notifications. Disabling Weather also stops weather requests.

| Menu setting | Configuration and default |
|---|---|
| Preview on hover | `hoverPreview: true`; `hoverDelay: 140` ms, range `0`–`1000` |
| Opening page | `openingPage: "overview"`; also `controls` or `last` (last page during this shell session); a disabled destination falls back to Controls |
| Bar animation | `panelAnimation: true`; controls bar artwork, beacon waves, and bar transitions |
| Interface animations | `animationsEnabled: true`; system reduced motion always takes precedence; embedded system panels retain native Omarchy behavior |
| Sections | `overviewEnabled`, `calendarEnabled`, `weatherEnabled`: all `true` |
| Track announcements | `trackAlerts: true` |
| Music visualization | `musicVisualization: "visible"`; also `open` (popup only) or `off`; audio analysis stops when no animated visualization is visible |
| Visualization style | `musicVisualizationStyle: "default"`; reserved, currently a disabled choice |
| Notification style | `notificationStyle: "card"`; `bar` shows the summary in the bar without opening a card |
| T3 Code sessions | `t3Enabled: false`; opt in under Integrations to connect to the local T3 server |
| Answer T3 questions from Island | `t3Responses: true`; when disabled, the T3 connection is read-only |
| Indicators | `indicatorDnd`, `indicatorMicrophone`, `indicatorRecording`, `indicatorRemote`, `indicatorNightLight`, `indicatorStayAwake`, `indicatorUpdate`: all `true`; visibility only, without changing system state |
| System events | `osdVolume`, `osdBrightness`, `osdKeyboard`, `osdLayout`, `osdMicrophone`, `osdModes`: all `true`; disabled events are suppressed without invoking the native OSD fallback |

Other settings and existing contextual controls:

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

Weather uses a summary layout: current temperature and conditions beside a theme-colored braille illustration, followed by feels-like temperature, wind, and humidity. The next seven days share one temperature-range scale, with highs above and lows below each bar. Sunrise and sunset use the selected city's local time; unavailable solar times show a dash. Only the current-condition illustration animates; forecast illustrations remain still, and reduced motion stops animation.

For a single dictation OSD, disable other dictation visualizers and the native Voxtype OSD with `voxtype config set osd.enabled false`. Dictation settings and shortcuts remain in Voxtype.

### T3 Code session cards

Requires a running **local T3 Code server**, its `t3` CLI on the shell's `PATH`, and orchestration protocol **2**. Tested against `0.1.9-nightly.20261111.4515`. The bridge uses Python's standard library; Node.js and extra Python packages are not required.

Enable **Controls → Settings → Integrations → T3 Code sessions**. Sessions appear in a dedicated **T3 Code** section in **Overview**, above Notifications and History. Switching notification tabs does not hide T3 sessions. Working sessions use compact rows with a spinner, title, project, status, and elapsed time. The bar shows the number of pending requests, or a spinner and working-session count when there are no requests; click the indicator to open Overview. Hover previews are read-only; pin the popup to answer. Status changes show a single thread card for four seconds on the focused monitor without taking keyboard focus. The toast has no extra outer container or section heading; its own border and translucent background follow the system popup theme, and radial waves originate at its status icon. Preparatory run states are grouped; metadata updates and initial/reconnection snapshots stay quiet. DND, an open Island panel, and notification toasts suppress these popups. Simultaneous changes prioritize input requests and failures.

- Options use equal-width columns with complete, wrapping labels and descriptions; narrow cards use one column. Choose a single option, select several when permitted, or expand **Custom answer**. The send button shares the custom-answer row instead of taking its own row. Complete required questions, then choose **Send answer**. Tab / Shift+Tab navigates the form; typing and caret keys stay in the text field.
- Session updates preserve existing card order, drafts, and focus. A replacement question resets its draft. Questions answered in another T3 client disappear after synchronization.
- The chevron expands the latest message or request context. Click the session title to open T3 directly in the desktop app using `t3code://threads/<environment>/<thread>`. T3 must be registered as the system handler for `t3code` links and have access to the environment.
- Permission approvals, secrets/authentication, non-resumable requests, and forms outside the supported bounds are handled in T3. Island never interprets request text as a command.
- Braille spinners advance in discrete frames and stop on hidden pages, outside the visible list, and when reduced motion is enabled.
- When T3 is disconnected or has no sessions, its entire section is hidden. Drafts stay in memory for reconnection, and responses remain disabled while disconnected. If no result arrives within 20 seconds, the card marks the send as unconfirmed instead of waiting indefinitely. An unconfirmed send is never retried automatically; check it in T3. Reconnection is automatic.
- Up to 30 top-level sessions are shown, prioritizing pending requests and running work. Recently finished sessions remain for 30 minutes. Archived, explicitly settled, and child-agent threads are excluded. Overview must be enabled to use the cards.

Discovery reads `$T3CODE_HOME/userdata/server-runtime.json`, defaulting to `~/.t3/userdata/server-runtime.json`. `T3CODE_HOME`, if set, must be available in the Omarchy shell environment. Only literal loopback HTTP origins are accepted; remote environments are outside this integration's scope.

When enabled, the bridge uses `t3 auth session issue` to obtain a one-hour token with `orchestration:read` and, if answers are enabled, `orchestration:operate`. The latter is T3's general orchestration permission; Island exposes only validated answers to pending questions. Tokens are held in memory, rotated before expiry, and revoked on normal disconnect or shutdown. Turning off the integration stops the bridge. Session text and drafts are never added to notification history or written to disk by Island.

The integration follows T3's client protocol, rather than a version-independent SDK. Unsupported protocol versions show an error and do not obtain a token. See the upstream [HTTP contract](https://github.com/pingdotgg/t3code/blob/d2c25950b4d9183ea342d5d5fc14c326b9e0172a/packages/contracts/src/environmentHttp.ts) and [orchestration contract](https://github.com/pingdotgg/t3code/blob/d2c25950b4d9183ea342d5d5fc14c326b9e0172a/packages/contracts/src/orchestrationV2.ts).

### Optional Hyprland blur

Copy the included [layer rule](hyprland/island.lua):

```bash
cp ~/.config/omarchy/plugins/gshulga.island/hyprland/island.lua ~/.config/hypr/omarchy-island.lua
```

Add this outside managed blocks in `~/.config/hypr/looknfeel.lua`:

```lua
require("hypr.omarchy-island")
```

Apply with `hyprctl reload` and check `hyprctl configerrors`. All detached Island popups, including T3 activity, notifications, Now Playing and dictation, share this layer namespace. Blur strength follows Hyprland's `decoration.blur` settings. Popup transparency follows `[popups] background-alpha` in the theme or `~/.config/omarchy/shell.toml`; at `1.0`, the background is opaque and blur is not visible.

## Data and privacy

- Notification history, mute, and DND state live in `~/.local/state/omarchy/island/state.json`, limited to 100 notifications and 24 hours. Directory permissions are `0700`; file permissions are `0600`.
- Expired notifications enter history; sender withdrawal removes them from both lists while Island retains the sender reference. After restart, saved entries are history only. Transient notifications are not saved.
- Verification-code notifications are redacted before persistence. Copied codes use a sensitive clipboard selection and are cleared after one minute unless the clipboard has changed.
- Playback audio is read through `parec` and processed in memory without saving PCM. Voxtype uses its existing audio bridge during recording; Island opens no separate microphone stream and saves neither dictation audio nor recognized text.
- T3 integration is off by default. When enabled, session data, draft answers, and the scoped access token stay in memory. Opening a session uses T3's desktop deep link. See [T3 Code session cards](#t3-code-session-cards) for permissions and lifecycle.
- Weather requests begin on first opening or hovering, with no requests beforehand. Automatic location uses `geo.omarchy.org`; search and forecasts use [Open-Meteo](https://open-meteo.com/). Requests use HTTPS, timeouts, and response limits. On failure, the last forecast remains marked stale; the cache is `~/.local/state/omarchy/island/weather.json`.

## Design system

Island uses one live design system across Overview, notifications, downloads, T3, media, Calendar, Weather, Controls and settings. [Design specification](design/DESIGN.md) documents typography, spacing, surfaces, color sources, interaction states and component APIs.

- `plugin/DesignTokens.js` holds primitives and contrast calculations; `plugin/Design.qml` maps them to live Omarchy `Color` and `Style` values.
- `PlainText` uses named roles (`caption`, `label`, `body`, `title`, `section`, `page`, `metric`, `hero`, `bar`). Buttons, choices, inputs and surfaces share geometry and focus treatment. System scaling and square corners remain supported.
- Sections use spacing and typography instead of decorative dividers. Data cards have opaque, quiet surfaces; artwork stays behind them. Theme colors are corrected only when necessary for legibility.
- Native system panels receive the same typography and adapted controls in the generated cache. Their device logic, keyboard behavior and installed source files are preserved.

Open the isolated, interactive **native QML gallery** without installing or restarting Island:

```bash
bin/design-gallery
```

It supports system/dark/light/monochrome palettes, larger text, square corners, reduced motion and narrow question cards. The sample T3 form uses a local stub and sends nothing to T3. Preview settings affect only the gallery process. For offscreen screenshots:

```bash
bin/design-gallery --capture-dir /tmp/island-design
```

## Development

Sources live in `plugin/`. Register new top-level QML types in `plugin/qmldir`, which also declares the shared Preferences singleton. The root `manifest.json` serves the native plugin manager; `plugin/manifest.json` serves legacy flat installations. Keep shared metadata consistent and preserve their different entry point paths.

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
python3 tests/panel-layout.py              # Wayland panel orientation, edge slots, indicators and compact OSD
python3 tests/popup-theme.py               # Wayland popup alpha/borders; no windows opened or input sent
python3 tests/settings.py                  # Wayland settings, persistence and presentation with a fake shell
python3 tests/t3-bridge.py                 # QML → real bridge → fake HTTP/WebSocket server; no live T3 changes
python3 tests/t3-qml.py                    # Offscreen forms, keyboard, drafts and connection state
python3 tests/controls-adapter.py          # Panel generation, cache refresh, source integrity
python3 tests/keyboard.py                  # Keyboard input and focus
QT_QPA_PLATFORM=offscreen python3 tests/keyboard.py # Keyboard checks without Wayland focus
python3 tests/indicators.py                # Wayland indicators and native OSD
ISLAND_T3_ONLY=1 python3 tests/indicators.py # T3 count, spinner, reduced motion and clock alignment
python3 tests/dictation.py                 # Dictation states and reduced motion
ISLAND_TEST_GPU=1 python3 tests/dictation.py # Dictation with GPU shaders
python3 tests/artwork-render.py            # GPU artwork frames and reduced motion
ISLAND_TEST_GPU=1 python3 tests/weather-summary.py # Weather GPU, themes, layout and reduced motion
```

Read scripts before running them: live checks may interact with the current session. Artwork rendering requires OpenGL 3.3, a C++ compiler, and Qt6Gui.

## License

[MIT](LICENSE). Notification handling is adapted from Omarchy / [Omapager](https://github.com/omacom/omapager). See [THIRD_PARTY.md](plugin/THIRD_PARTY.md) for attribution and component licenses.

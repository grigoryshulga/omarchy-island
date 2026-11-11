# Working on Omarchy Island

Omarchy Island is a native Quickshell plugin for the Omarchy shell that replaces the clock and notification daemon. The target environment is Omarchy with `qs.Commons` and `qs.Ui`; Waybar support is outside the project scope. Communicate with the user in Russian; write code identifiers in English. Write agent instructions and the README in English; follow the existing language in other documentation.

## Before making changes

Read the relevant section of `README.md` for installation, settings, UI behavior, and checks. Preserve existing hover, popup pinning, keyboard, and multi-monitor behavior unless the task explicitly changes it.

## Code boundaries

- `plugin/BarWidget.qml` manages the clock and popup opening; `plugin/Service.qml` manages shared state, notifications, MPRIS, and IPC.
- UI components live in `plugin/`; system panels live in `plugin/controls/`. Reuse existing buttons, sliders, and effects for new elements.
- Put calculations and data transformations in adjacent JS models, keeping them compatible with QML JS. Node.js runs tests; it is not the plugin runtime.
- External processes and data retrieval also live in `plugin/bin/`; installation and build commands live in the root `bin/` directory.
- When modifying borrowed components, preserve the attribution and licenses in `plugin/THIRD_PARTY.md` and nested `LICENSE` files.

## User interface

- Use live tokens from `qs.Commons` and components from `qs.Ui`: theme colors, `Style.space`, font sizes, radii, and durations. Support a system corner radius of zero.
- Respect `Style.reduceMotion`: transitions must reach their final state without motion, and continuous effects must stop. Run continuous visual effects only when needed by visible UI.
- Keep the Wayland surface geometry stable as the popup expands; animate the card and its contents within that surface. The card center must remain fixed.
- Add user-facing strings to both `plugin/i18n/ru.json` and `plugin/i18n/en.json`. Follow Omarchy I18n for dates, numbers, the first day of the week, and text direction.
- When changing interactive elements, preserve focus, Tab navigation, and keyboard actions; see the Keyboard section in `README.md`.

## Data and external actions

- External URL policy and input validation are centralized in `plugin/Security.js`; use it when adding ways to open links or process notifications.
- Pass argument arrays to external commands through the existing `Process` / `Util.execArgv` mechanisms. Notification data and user input must never become shell code.
- Preserve code and secret redaction before persisting history, retention limits, and state permissions: `0700` for the directory and `0600` for the file. Analyze audio in memory without writing PCM to disk.

## Manifests and builds

- The root `manifest.json` is used by the native Omarchy manager; `plugin/manifest.json` supports the legacy installation. Keep shared metadata consistent; entry point paths intentionally differ.
- After changing `plugin/shaders/*.frag`, run `bin/build-shaders` and include the updated `.vert` and `.qsb` files. The script generates vertex shaders and compiles both stages with Qt `qsb`; changes made only to generated `.vert` files will be overwritten.
- Prebuilt `.qsb` files are tracked for normal installation; rebuild them when shaders change.

## Verification

- Run the main check suite from the repository root with `bin/test`; consult the script for the current suite contents. For documentation-only changes, checking links and running `git diff --check` is sufficient.
- When changing logic, add or update a behavior check in `tests/`. JS models use Node tests in `*.test.cjs`; QML and services use Python scripts with QML test harnesses.
- QML checks require `qs` and the Omarchy shell modules at `/usr/share/omarchy/shell`. If a dependency is unavailable, run the checks you can and explicitly report what remains unverified.
- For animation, keyboard, indicator, and GPU effect changes, select additional scripts from the Verification section in `README.md`. Read each script before running it: some checks require Wayland or a running Island instance and interact with the current session.
- Verify changes in the source checkout. Install, uninstall, change user configuration, or restart the shell when those actions are part of the task; routine code verification does not require deployment to the live session.

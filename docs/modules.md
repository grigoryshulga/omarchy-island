# Feature and integration modules

Island modules currently ship inside this repository. Adding a module requires its own files and registration in `plugin/ModuleCatalog.mjs`; restart the shell after installation. Optional integrations enable and disable through their settings. External package discovery, hot loading and a general activity-toast API are deferred.

Downloads, Media, Notifications, Battery, Controls, Overview, Calendar, Weather, T3 and Agent Limits use the same catalog. Their existing state and content types remain reusable; module-specific composition lives under `plugin/modules/`. Overview has no backend of its own. Existing top-level pages use a common page host; Controls, T3 and Agent Limits open details inside Overview. No new user-facing top-level tabs are introduced.

`Service.qml` composes shared backends and preserves the existing clock/IPC facade. Notification persistence, notification-server ownership and actions live in `NotificationState.qml`; MPRIS/audio and downloads have separate backends. Notifications and Downloads never read or modify each other's live state or store. Their toast selection, DND presentation policy and legacy action routing belong to the host. Clock activity selection and toast arbitration remain in the existing shell composition.

## Register a module

Create `plugin/modules/example/Module.mjs`:

```js
export default {
  id: "example",
  titleKey: "example.title",
  state: "modules/example/State.qml",
  overview: "modules/example/Overview.qml",
  indicator: "modules/example/Indicator.qml",
  defaults: {exampleEnabled: false},
  groups: [{id: "example", rows: [{key: "exampleEnabled"}]}]
};
```

Import it in `ModuleCatalog.mjs` and add it to `definitions`. Use a unique stable ID and globally unique setting names. Paths are relative to `plugin/`. Omit `state`, `overview` or `indicator` when unnecessary. `title` can supply a fixed proper name instead of `titleKey`. Optional `order` numbers for `overview`, `indicator` and `settings` preserve independent placement; lower numbers appear first, with registration order breaking ties.

Add labels to both `plugin/i18n/en.json` and `ru.json`: `example.title`, `settings.group.example`, and `settings.exampleEnabled`. Use the [public UI SDK](ui-sdk.md) for live design tokens, styled controls and effects. The [module template](../templates/module/README.md) demonstrates the complete registration contract. Keep collectors in `plugin/bin/` and execute argument arrays; use the existing Security policy for external inputs and URLs.

`choices` maps setting names to permitted values. `validators` maps names to pure QML-compatible validation functions for structured or numeric values. Other settings are booleans. `defaults`, `choices`, `validators` and settings `groups` are composed by `SettingsModel.mjs`; duplicate default keys fail immediately. Groups normally appear in Modules; `settingsSection` can target an existing section, as Notifications does for Alerts. Preserve existing setting names when migrating integrations. Do not perform I/O at module import time. A settings group may also provide `moduleId` and a relative `view` path for live diagnostics or actions below its standard rows. This view follows `ModuleView`, receives the shared backend and a presentation with `strings`, `feedback`, `active`, and `revealFocus(item)`, and must tolerate a null backend. Settings diagnostics may remain available while the backend is disabled; use the backend's `allowed` state to disable actions. Call `presentation.revealFocus(item)` when an action gains keyboard focus so the settings viewport reveals it.

## Shared state and lifecycle

`ModuleRegistry` creates one state object for each descriptor with `state` in the shell's shared Service. The map `service.modules[id]` supplies that same object to all monitors. State objects must expose `allowed`; optional integrations derive it from Preferences and any feature prerequisites. Required built-ins default to allowed without adding a new settings toggle. Stop collectors and timers when it becomes false. A hidden view does not imply a disabled integration: polling may continue while the popup is closed. Visibility-driven collectors must count consumers across monitors; Battery uses `watch(view, visible)` and releases each view on destruction.

State objects remain allocated when disabled. Each integration owns the appropriate cleanup and reconnection policy. T3 keeps its protocol and response semantics; Agent Limits keeps its file watcher and collector semantics. The host does not translate their transports into one generic process abstraction.

Controls shares `ControlsState` across monitors. Its Overview view subscribes while favorites or the full landing controls are visible; the last consumer leaving stops status collectors. User-requested actions can finish after the page closes; disabling the module stops them too. Device sources, status commands, actions, IPC calls and the native-panel builder command can be replaced. `ControlsView` itself has inert defaults and never creates a real state object. A page without a backend can still use the host's injected `execute` and `systemCall`; it cannot load native panels without an explicit builder command. Tests that exercise actual generated panels opt into that command explicitly.

Inject paths, helper command arrays, external actions and time through backend properties. `ModuleRegistry.stateProperties[id]` supplies these properties before object construction; `Service.moduleStateProperties` exposes the same seam. A descriptor with `usesHost: true` receives the registry's `host`, for explicit shared services such as DND announcements. A test can register only the backends it needs. Loading a view with a fake backend must never construct another real backend or start an integration.

## Independent storage

Notifications owns `notifications.json`; Downloads owns `downloads.json`. Both use `ModuleStorage` for private directory/file preparation and atomic writes, with `stateDir` and `storageCommand` injectable before startup. Each backend owns schema validation, retention and redaction. Downloads starts its watcher after its own load completes, even when Notifications is not registered. Disabled backends defer initialization; disabling an initialized backend flushes its snapshot and stops its pending save timer.

Migration reads `state.json` only when a module's new file is absent. Downloads accepts the old `downloads` and `recents` fields; Notifications accepts history, mute and DND state. The preparation helper publishes a private migration marker; after loading, the backend replaces it with a sanitized snapshot. If startup is interrupted before that save, the marker allows migration to resume. Empty or corrupt completed stores do not fall back to legacy data, so cleared entries stay cleared. I/O failures report an error; initialization can retry on re-enabling. Preparation has bounded reads and a five-second timeout covering failed-to-start as well as a running helper.

After a successful atomic save, a migration-only helper verifies and syncs the destination before removing that module's legacy fields. Cleanup uses a shared file lock and atomic replacement, so concurrent module startups cannot overwrite each other's progress. Unmigrated fields remain available to the other module; once none remain, the source is removed. While legacy data remains, an enabled store runs cleanup once a minute to enforce the original 24-hour notification and 30-minute download retention even if its peer is disabled. A failed save or a pending destination marker never authorizes deletion. A crash before cleanup retries it on the next startup. The runtime modules never access each other's new files.

## Views

Overview and indicator QML roots extend `ModuleView`. `ModuleSlot` supplies `backend` and `presentation` before construction, so dependent bindings have their context immediately. A new view instance is created for each place of presentation. Keep drafts and editing state in the view, not in the shared backend.

| Property or signal | Purpose |
| --- | --- |
| `backend` | The shared state object; it may temporarily be null during startup |
| `presentation` | Read-only host context described below |
| `available` | Whether this view currently has content to show |
| `implicitWidth`, `implicitHeight` | Natural dimensions; the host owns placement |
| `tooltip` | Optional indicator tooltip included in the clock tooltip |
| `expandRequested()` | Pin/open the popup from a preview |
| `detailsRequested()` | Toggle this integration's Overview details, or open Overview from its indicator |
| `customizeRequested()` | An optional tab action; the host calls the page’s `configure(returnTarget)` method |
| `settingRequested(key, value)` | Request validated persistence through the existing shell settings path |
| `closeRequested()` | Close the current popup through its host |

A descriptor can declare `overviewSizes: ["minimal", "compact", "large"]` for the additional summary sizes it implements. `standard` is always supported and preserves the default appearance. The host exposes the selected size as `presentation.size`; views must use it explicitly rather than scaling fonts or the whole component. Detail views retain their full content independently of summary size. The customization editor shows only supported sizes, and falls back to `standard` for an unsupported saved size. Keep new variants compatible with hover previews, keyboard controls, live tokens and reduced motion. Visibility is a presentation preference, not a backend enable switch; toast presentations receive `standard`.

Overview context contains `service`, `settings`, `bar`, `strings`, `feedback`, `expanded`, `detail`, `active`, `size`, and `pageHeight`. Render summary and details in the same retained view, switching on `detail`; use `active` and reduced motion to stop invisible effects. The host owns the common detail heading and Back button, focus restoration, scroll restoration and popup geometry. An integration must not change the host's selected detail directly. Hover preview must remain read-only. A module with nested details can implement `back()` and expose `navigationHidden` and `ownsKeys`; the common host forwards them without module-specific branches.

The clock builder discovers every descriptor with `indicator`. Optional `indicatorIcon` supplies the muted glyph used when that indicator has no live content; the fallback is a diamond. `indicatorDefault: false` offers a new indicator in the add menu without altering existing default bars. Indicators with a `pageIndex` open that page; other indicators open Overview. Its existing `title` / `titleKey` names it in the add menu and tooltip. Active previews reuse the real indicator view with actions disabled; no additional collectors are created. Saved `clockLayout` entries use `module:<id>` identities and survive temporary removal.

Indicator context contains `strings`, `vertical`, `barSize`, `barHeight`, `showAlert`, and `bar`. Retain a compact natural size for both orientations. Bind continuous effects to effective visibility and reduced motion.

Views remain alive while hidden to preserve drafts and stable delegates. Temporary loss of content (`available: false`, for example T3 disconnecting) hides the view without abandoning its detail selection. The slot suppresses views of a disabled backend (`allowed: false`), and Overview returns to the summary. Popup state and focus remain separate on each monitor.

## Existing page adapters

`page` points to a QML root extending `ModulePage`. Use a unique `pageIndex`; the existing values 1–3 preserve Overview, Calendar and Weather shortcuts/settings. Controls contributes an Overview view rather than a top-level page; its declarative `overviewShortcut: "Alt+1"` keeps the compatibility shortcut for opening its full view. Other Overview modules can declare `overviewShortcut` too. `enabledSetting` supplies an optional page toggle; Overview remains required so Controls and settings stay accessible. `tabObjectName` preserves focus/test identifiers. Optional `tab` supplies a custom `ModuleTab` view, as Weather does for its status chip.

`PopupPages` owns the single selected page, retained views, numeric navigation and stable surface dimensions. A page reports `stableHeight`, `navigationHidden` and `ownsKeys`; it implements `back()`, `enter()`, `cancelEditing()`, `focusPrimary()` and `handleKey(event)` as needed. Returning true from a key/back handler means the page consumed it. A disabled selected page returns to the first enabled page. This adapter lets existing built-in pages be isolated without duplicating navigation in the clock.

## Verify a module

Run `bin/test`. The `tests/modules.py` check uses `tests/module_harness.py` and `tests/ModuleHost.qml`: temporary storage, fake host, action recording and injectable time inside the private test session. `ModuleHarness.register(name, directory)` copies a fixture module and adds its catalog entry; `run(scenario, marker)` runs its QML behavior scenario. Missing dependencies or missing success markers fail the check.

The sample module exercises settings discovery, enable/disable, a stopped background timer, two independent views sharing one backend, retained drafts, Overview details/focus and an additional page. A real Downloads backend uses a fake watcher to verify invalid actions, recorded argv, injected time, process shutdown and exactly one watcher after re-enabling. The Battery check covers shared consumers across monitors. Existing notification, T3, Agent Limits, calendar and weather checks retain their transport, cache, redaction and recovery coverage.

Declare the capabilities of each scenario in its Python entry point. Keep module scenarios in the common harness, rather than introducing another desktop-session setup. New transport behavior must cover empty results, errors/timeouts, recovery and malformed cache; external actions must cover invalid inputs and secret redaction where applicable.

| Capability | Runner and purpose |
| --- | --- |
| Pure model | Node `*.test.cjs`; calculations, settings and catalog validation |
| Offscreen | `bin/test-session -- python3 tests/modules.py`; fake backends/helpers, lifecycle and UI behavior |
| Fixture network | Private session plus a local HTTP/WebSocket fixture, as in `tests/t3-bridge.py`; no user credentials |
| Wayland | `bin/test-session --wayland`; headless Sway for layer-shell, focus and screen geometry |
| OpenGL | Separately provisioned virtual graphics environment for shader checks; software rendering is not physical GPU validation |

See [test isolation](test-isolation.md) for dependencies and session boundaries. The suite never silently falls back to the user's compositor. Live installed-system checks stay outside automatic module verification.

The `.mjs` files are ECMAScript modules supported by the QML runtime. Node is used only by development tests; the CommonJS test entry points require Node 22.12+ for synchronous loading of these modules. Avoid assuming that newer Node methods exist in QML JavaScript.

# Island UI SDK 1.0

The public UI SDK is the supported styling and component surface for Island modules. It uses the same live theme and implementations as the built-in UI. Custom layouts can use the public tokens directly; modules do not need to copy styles or construct their own theme singleton.

For a module in `plugin/modules/<id>/`:

```qml
import QtQuick
import QtQuick.Layouts
import "../../sdk" 1.0 as UI
```

Use this relative import in modules: it works with both native and legacy installation paths. The standalone examples mount `plugin/` as `Island` in a Quickshell configuration and use `import qs.Island.sdk 1.0 as UI`. That absolute name is an example-harness layout, not a required installation path.

## Compatibility boundary

The supported API consists of the exports in [`plugin/sdk/qmldir`](../plugin/sdk/qmldir) and the properties/signals documented here, plus standard QtQuick item/layout properties. Internal children, object names, implementation files, shader uniforms and undocumented inherited properties are not SDK contracts. Root-level Island imports remain available to built-ins but are not the public extension boundary.

Compatible additions may extend 1.x. Removing or changing a documented contract requires a major SDK version and migration instructions; existing 1.0 consumers must keep working during migration. QML's `1.0` import selects exported types; it does not automatically freeze their implementation. The behavior tests and review policy enforce compatibility. Theme-derived pixel values and colors intentionally change with the user's settings.

SDK 1.0 covers in-repository modules. It does not introduce package installation, hot loading, top-level tabs, or compatibility with arbitrary versions of Omarchy. Runtime prerequisites remain the supported Omarchy shell with `qs.Commons` and `qs.Ui`; Node is only a development dependency.

## Live design tokens

`UI.Design` is a read-only facade over the host's existing Design singleton. Keep QML bindings to its values, rather than copying a value once in `Component.onCompleted`.

| Group | Public members |
| --- | --- |
| Typography | `fontFamily`; `type.caption`, `label`, `body`, `title`, `section`, `page`, `metric`, `hero`, `bar`, `iconSmall`, `icon`, `iconLarge`; `fontSize(role)`, `lineHeight(role)`, `weight(role)` |
| Spacing | `gap.micro`, `tight`, `small`, `medium`, `large`, `section`, `page`, `spacious` |
| Geometry | `controlHeight`, `compactControlHeight`, `inlineControlHeight`, `fieldHeight`, `optionHeight`, `cardPadding`, `panelPadding`, `cardRadius`, `controlRadius` |
| Backgrounds | `canvas`, `opaqueCanvas`, `surface`, `raised` |
| Content | `text`, `secondaryText`, `accent`, `info`, `success`, `warning`, `danger`, `onAccent` |
| Interaction | `fieldBorder`, `focusRing`, `selection`, `hover`, `pressed`, `selectedText`, `selectedSecondaryText`, `disabledOpacity` |
| Bar | `barText`, `barAccent`, `barDanger` |
| Timing | `feedbackDuration`, `transitionDuration`, `revealDuration`, `spinnerDuration` |

`fontSize`, `lineHeight` and `weight` accept the text roles listed for `PlainText` below. Icon sizes are available through `type.iconSmall`, `type.icon` and `type.iconLarge`.

Use semantic colors: `danger` for failure, `secondaryText` for supporting text, `surface` for a card. Honor zero radii; do not impose a minimum rounded corner. Colors already follow the host's contrast policy. The underlying theme settings remain owned by Omarchy.

```qml
UI.Surface {
    implicitHeight: label.implicitHeight + 2 * UI.Design.cardPadding
    UI.PlainText {
        id: label
        anchors.centerIn: parent
        typeRole: "body"
        text: presentation.strings.t("example.summary")
        color: UI.Design.secondaryText
    }
}
```

## Components

All components are inert UI: loading one does not construct a backend or start a real integration. Supply state and handle action signals in the owner.

| Type | Supported component API |
| --- | --- |
| `Surface` | `raised: bool`; standard rectangle `color`, `radius`; default quiet card surface |
| `PlainText` | `typeRole` (`caption`, `label`, `body`, `title`, `section`, `page`, `metric`, `hero`, `bar`); standard `text`, `color`, wrapping, alignment and elision; plain text by default |
| `SectionHeading` | `title`, `detail`; natural height and layout-friendly width |
| `FeedbackButton` | `text`, `iconText`, `tooltipText`, `variant` (`quiet`, `soft`, `primary`), `compact`, `selected`, `active`, `focusable`, `feedback`; `clicked()`, `rightClicked()`, `hovered(bool)` |
| `ChoiceButton` | Button API plus required `label`, `description`, `multiSelect`; owner updates `selected` on `clicked()` |
| `DesignTextField` | Standard QtQuick Controls TextField editing API, including `text`, `placeholderText`, `readOnly`, `echoMode`, `accepted()`, `textEdited()`; `invalid` adds the error border while preserving the focus ring |
| `DesignDropdown` | `label`, `value`, `options` (strings or `{value, label}` objects), `showLabel`, `popupOpen`; `changed(value)`, `open()`, `close()`, `toggle()`; owner updates `value` |
| `ControlSwitch` | `checked`, `busy`, `interactive`, `effectsActive`; `toggled()`, `hovered(bool)`; owner updates `checked`; set `Accessible.name` |
| `IslandSlider` | `value`, `minimum`, `maximum`, `step`, `integer`, `tickCount`, `trackStyle` (`braille` by default, or `solid`), `dragging`, `liveValue`; `moved(value)`, `released(value)`, `rightClicked()`; owner updates `value` |
| `BrailleProgress` | `value` (0–1, clamped for display), `accent`, `mirrored` (inherits layout mirroring); shared dot progress track, no input or animation; GPU shader rendering requires a compatible graphics backend |
| `BrailleGauge` | `value` (0–1), `glyph`, `valueText`; progress display; GPU shader rendering requires a compatible graphics backend |
| `Spinner` | `active`, `tint`, read-only `animating`; braille loading animation, static when motion is reduced |
| `ModuleView` | Module view contract: `backend`, `presentation`, `available`, `tooltip`, `interactionHovered`, `toastIcon`, `expandRequested()`, `detailsRequested()`, `closeRequested()`, `settingRequested(key, value)` |
| `ListRow` | `title`, `description`, `iconText`, `statusText`, `statusKind` (`neutral`, `success`, `warning`, `error`), `selected`, `interactive`, `feedback`, `actions` (list of trailing items); `clicked()`; read-only `stacked` |
| `DataState` | `kind` (`empty`, `loading`, `error`, `stale`), `title`, `description`, `actionText`, `actionEnabled`, `active`, `feedback`; `actionRequested()` |
| `FormField` | `label`, `hint`, `error`, read-only `message` (`error` or `hint`) and `control` (first editor item); default `content`; `focusEditor()` |

Use `implicitWidth`/`implicitHeight` for natural size and `Layout.fillWidth` or anchors for available space. Do not alter the popup's Wayland surface or center. Long translated text should wrap where appropriate. Set accessible labels for controls with no visible text.

`IslandSlider` uses the same braille dot field as battery charge and Agent Limits by default, with a full-width track and no thumb. Its full-height hit area, drag, wheel and keyboard controls remain available. Use `trackStyle: "solid"` for the traditional line and thumb. `BrailleProgress` exposes the same static track for read-only values; use `accent` for semantic status colors and inherit layout mirroring for right-to-left progress. Battery charging adds its host-owned wave without changing the shared static appearance.

Buttons opt into keyboard navigation with `focusable: true`; choices, fields, dropdowns, switches and sliders already support it. Switches accept Space/Enter when interactive and not busy. A noninteractive switch is excluded from Tab navigation; turning interaction off while focused moves focus to the next control, or clears it when none is available. Busy switches retain focus. Sliders accept arrows/Home/End; dropdowns handle their own Escape. The common Overview host owns detail Back/Escape and focus restoration. See [the module contract](modules.md#views) for host navigation and retained views.

## Rows, data states and forms

`ListRow` is a presentation item, not a list model or a ListBox. Use it inside a Repeater/ListView; the owner stores selection and decides what opening a row does. Set `interactive: true` only if the row itself has an action. Its short trailing `actions` remain independently focusable and do not activate the row. Long titles and supporting text wrap; at narrow widths the actions move below the text. The common host's keyboard navigation can reach both the row and its actions. Static rows leave only their actions in the Tab chain.

`DataState` never starts a request or clears existing content. Supply translated text, bind `active` to the host activity when needed, and decide whether to keep cached content visible alongside it. Only `loading` animates; hidden/reduced-motion indicators stop. Omit `actionText` when no recovery action exists. The caller handles `actionRequested()` and disables repeated retries while busy. Status meaning must be conveyed in text, not color alone.

`FormField` wraps an existing editor without replacing it when validation changes, so cursor position and drafts survive. The error takes the place of supporting text and wraps to available width. Bind the editor's accessible name/description explicitly, and bind `invalid` for a `DesignTextField`:

```qml
UI.FormField {
    id: addressField
    Layout.fillWidth: true
    label: presentation.strings.t("ics.url")
    hint: presentation.strings.t("ics.private")
    error: validationMessage // Owned by the module's model/policy.
    UI.DesignTextField {
        Layout.fillWidth: true
        Accessible.name: addressField.label
        Accessible.description: addressField.message
        invalid: !!addressField.error
        text: draft
        onTextEdited: draft = text
    }
}
```

Validation does not authorize external actions: Calendar still uses `Security.calendarUrl`, and Agent Limits validates the secret **name**, never a pasted API key. Calendar Sources uses all three compositions; Agent Limits uses the field and data states. Existing switches now share keyboard handling between built-in panels and the SDK, and sliders/switches share disabled opacity. Buttons, dropdowns and surfaces retain their existing theme-driven geometry and behavior.

The visual rule remains restrained: live Omarchy typography and palette, braille loading, clear focus, no decorative dividers or new neon colors. Glass belongs to the outer popup/compositor; information cards stay opaque for legibility. An offscreen capture shows the actual QML controls but cannot reproduce compositor blur.

Run `bin/design-gallery --patterns --language ru` for a live native playground. It includes the new compositions and existing buttons, switch, slider and dropdown. Mode buttons simulate loading, errors, empty data and disabled controls; theme controls change palette, scale, corners and motion. Row selection, independent actions, validation and retry are interactive and use no real integration.

```bash
bin/test-session -- bin/design-gallery --patterns --language ru --capture-dir /tmp/island-patterns
python3 tests/ui-patterns.py
```

Captures cover dark, light, monochrome/square, selected keyboard focus, loading, error, empty, disabled, reduced motion, and a 380px container with larger text. The common harness tests English/Russian wrapping, independent row actions, Tab reachability, preserved drafts, validation, recovery and stopped animations. It also exercises the actual Agent Limits connection form with a fake backend; Calendar's integration scenario retains the real parser/storage with fixture HTTP.

## Effects and motion

Pass `presentation.feedback` to buttons and choices. Their clicks use the host's existing braille feedback layer, with shared coordinates and timing. `Surface` and buttons already participate in host spotlight discovery. A standalone preview may pass `null` or a fake `{pulseFrom(item)}` object. Raw spotlight/wave/shader setup is internal; modules should not create competing popup-wide effect layers.

`UI.Motion.reduceMotion` includes both Omarchy reduced motion and Island's animation setting. `UI.Motion.duration(milliseconds)` applies host scaling and returns zero when motion is reduced. The Design transition durations already use that policy. `spinnerDuration` is a base period, so never use it alone as authorization to run a continuous effect.

```qml
UI.Spinner {
    active: visible && !!presentation && presentation.active && backend.busy
}

// For your own discrete transition:
Behavior on opacity {
    NumberAnimation { duration: UI.Motion.duration(120) }
}
```

For custom timers/continuous animations, gate `running` on effective visibility, host activity and `!UI.Motion.reduceMotion`. Stop them when hidden or disabled. A discrete transition must reach its final value when motion is turned off. Bind `ControlSwitch.effectsActive` to the same host activity condition. Avoid retaining a reference to a popup's feedback object in a shared backend.

## Settings, text and module state

`UI.Settings.get(key)` reads validated module settings reactively. It exposes no write access. Request changes through `ModuleView.settingRequested(key, value)`; the host validates and persists them. Descriptor defaults and validators belong in `Module.mjs`.

Use `presentation.strings.t(key)` for module text and `qs.Commons.I18n` for localized numbers/dates. Indicator presentation also supplies `strings`. Add both English and Russian translations to the host dictionaries. In SDK 1.0, module-local dictionaries must be merged during development; they are not dynamically discovered.

State objects are shared; views and their drafts are per monitor. A view must tolerate a null backend, and must never instantiate its production backend. An Overview-only module should require `presentation.expanded || presentation.hovering` in `available`: the same host also renders activity toasts, where unrelated cards must stay hidden. `allowed: false` disables the module; the backend owns resource shutdown. Keep transport, clock, external actions and storage injectable. These are module architecture requirements, not responsibilities of a visual component.

## Examples and template

- [`examples/ui-sdk/Components.qml`](../examples/ui-sdk/Components.qml): styled form, selection, switch, slider, gauge, spinner and button feedback; no I/O.
- [`templates/module/`](../templates/module/README.md): complete opt-in counter module with settings, shared state, Overview summary/details, per-view draft, indicator and English/Russian text. It adds no top-level tab.
- [`design/DESIGN.md`](../design/DESIGN.md): visual rationale and implementation design reference; this SDK document defines the supported extension API.

Run the example in the existing native gallery:

```bash
bin/design-gallery --sdk
bin/test-session -- bin/design-gallery --sdk --capture-dir /tmp/island-sdk-captures
```

The interactive gallery exposes theme, text size, square corners, narrow layout and reduced motion controls. It is a separate process and does not install the plugin or start integrations. The second command uses the private offscreen session. Software screenshots do not validate GPU shader output.

Run `python3 tests/ui-sdk.py` for the template and public API behavior tests, or `bin/test` for the complete suite. The SDK check copies the actual template under a fresh fixture ID, registers it, merges its dictionaries, and runs the actual component example through the common module harness. It also repeats the check after registering the original `example` starter, preserving its files and translations. Coverage includes settings enable/disable, two views sharing one backend, retained drafts and Back focus, absence from unrelated toasts, live styles, Tab exclusion and focus transfer for noninteractive switches, feedback dispatch and stopped animation. The host is parsed to catch duplicate declarations; offscreen permits only the known missing layer-shell backend error. Existing host tests cover pinning and popup geometry; Wayland/GPU capabilities remain separate as described in [test isolation](test-isolation.md).

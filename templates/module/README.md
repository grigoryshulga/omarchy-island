# Module starter

This is a complete, deliberately local counter module. It is not registered in the production catalog and performs no I/O. Its UI imports only SDK 1.0 and Omarchy's number formatting. The same files are exercised by `tests/ui-sdk.py`.

## Try it in the source checkout

1. Copy the directory: `cp -R templates/module plugin/modules/example`.
2. Add `import example from "./modules/example/Module.mjs";` to `plugin/ModuleCatalog.mjs` and append `example` to `definitions`.
3. Merge the entries in `plugin/modules/example/i18n/en.json` and `ru.json` into the corresponding `plugin/i18n/` dictionaries. Preserve existing entries. Module-local dictionaries are not loaded automatically.
4. Run `bin/test`. Install the updated checkout using the project's normal installation procedure, restart the shell, and enable Example in the Modules settings.

For a real module, rename the directory and every `example` identifier/path/translation key, including `exampleEnabled`, to a unique ID before registration. Replace the counter with your domain model. Keep user-facing strings in both dictionaries. Use [the UI SDK](../../docs/ui-sdk.md) and [the module contract](../../docs/modules.md) as the API references.

## Files and ownership

| File | Responsibility |
| --- | --- |
| `Module.mjs` | Catalog descriptor, settings default and settings group |
| `State.qml` | Shared backend; ignores actions while disabled |
| `Overview.qml` | Card, details and local editor draft; navigation via host signals |
| `Indicator.qml` | Compact localized count; host handles placement and tooltip |
| `i18n/*.json` | Translation entries to merge into host dictionaries |

The card appears only in Overview and hover preview, never inside another module's activity toast. The overview action is disabled during hover preview. Summary opens details through `detailsRequested`; the host supplies the heading and Back button. No top-level page is added. Backend construction happens only through the registry, never from a view.

## Growing the module

Extract pure transformations into an adjacent QML-compatible JS model and test with Node. For external data, add injectable transport commands, storage paths and a clock to State. Register test substitutions through `ModuleRegistry.stateProperties`. Release timers, processes and subscriptions on disable/destruction; test repeated enable without duplication. Do not store credentials or user content in this counter example.

Use `tests/module_harness.py` and `tests/ModuleHost.qml` for new scenarios. Start from `tests/ui-sdk.py` / `tests/UiSdk.qml`, replace the copied module and assertions with your behavior, and declare required capabilities in the Python entry point. All direct Python checks enter `bin/test-session`. For transports, add empty/error/timeout/recovery cases; for storage, malformed cache and redaction; for external actions, rejected invalid inputs and recorded argv. Add your runner to `bin/test`. UI-only loading must remain inert.

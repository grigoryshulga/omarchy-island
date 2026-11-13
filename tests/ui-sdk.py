#!/usr/bin/env python3
"""Capabilities: offscreen. Public SDK, copyable template and fake-host behavior."""
from session import ensure
ensure()
import json
import shutil
import subprocess
import uuid
from module_harness import ModuleHarness, PROJECT


def register_template(harness, name):
    # Follow the documented rename/copy/register/merge workflow in the sandbox.
    source = harness.root / (name + '-source')
    shutil.copytree(PROJECT / 'templates/module', source)
    for path in source.rglob('*'):
        if path.suffix in ('.qml', '.mjs', '.json'):
            path.write_text(path.read_text().replace('example', name))
    harness.register(name, source)
    for locale in ('en', 'ru'):
        target = harness.root / f'Island/i18n/{locale}.json'
        translations = json.loads(target.read_text())
        additions = json.loads((source / f'i18n/{locale}.json').read_text())
        # Existing host translations belong to their module, not to this fixture.
        for key, value in additions.items():
            translations.setdefault(key, value)
        target.write_text(json.dumps(translations, ensure_ascii=False))


def check_sdk(harness):
    # Never reserve a production module ID or overwrite an author's example.
    name = 'sdkFixture_' + uuid.uuid4().hex
    register_template(harness, name)
    for source, target in [('examples/ui-sdk/Components.qml', 'Components.qml'),
                           ('tests/UiSdk.qml', 'SdkScenario.qml')]:
        (harness.root / target).write_text((PROJECT / source).read_text().replace('example', name))
    harness.run(harness.root / 'SdkScenario.qml', 'UI_SDK_PASS')


with ModuleHarness() as harness:
    check_sdk(harness)
    # Exercise the documented entry point too: it must load the actual gallery.
    captures = harness.storage / 'gallery'
    result = subprocess.run([str(PROJECT / 'bin/design-gallery'), '--sdk',
                             '--capture-dir', str(captures)],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=15)
    print(result.stdout)
    assert result.returncode == 0 and 'DESIGN_CAPTURE_PASS' in result.stdout
    assert not any(error in result.stdout for error in
                   ('ERROR:', 'TypeError:', 'ReferenceError:', 'Binding loop',
                    'Cannot assign', 'Unable to assign'))
    assert {path.name for path in captures.glob('*.png')} == {'dark.png', 'light.png', 'mono.png'}

with ModuleHarness() as harness:
    # Regression: SDK checks must also pass after the starter has been installed
    # exactly as README describes, including its original ID and translations.
    if not (harness.root / 'Island/modules/example').exists():
        register_template(harness, 'example')
    catalog = (harness.root / 'Island/ModuleCatalog.mjs').read_bytes()
    module = harness.root / 'Island/modules/example'
    module_files = {path.relative_to(module): path.read_bytes()
                    for path in module.rglob('*') if path.is_file()}
    translations = {locale: json.loads((harness.root / f'Island/i18n/{locale}.json').read_text())
                    for locale in ('en', 'ru')}
    check_sdk(harness)
    assert (harness.root / 'Island/ModuleCatalog.mjs').read_bytes().startswith(catalog)
    assert module_files == {path.relative_to(module): path.read_bytes()
                            for path in module.rglob('*') if path.is_file()}
    for locale, original in translations.items():
        current = json.loads((harness.root / f'Island/i18n/{locale}.json').read_text())
        assert all(current[key] == value for key, value in original.items())
    print('PASS: SDK checks coexist with the installed module starter')

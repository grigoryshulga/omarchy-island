#!/usr/bin/env python3
from qml_result import assert_qml_pass
from session import ensure
ensure()
import json, os, subprocess, tempfile, threading
from pathlib import Path

from gi.repository import Gio, GLib

INDICATOR = 'com.superwhisper.Indicator'
INDICATOR_PATH = '/com/superwhisper/Indicator'
TYPES = {'Phase': 's', 'Level': 'd', 'Waveform': 'ad', 'Visible': 'b'}
INTERFACE = Gio.DBusNodeInfo.new_for_xml(
    f'<node><interface name="{INDICATOR}">'
    + ''.join(f'<property name="{key}" type="{kind}" access="read"/>' for key, kind in TYPES.items())
    + '</interface></node>'
)


def serve_indicator(control, loop):
    connection = Gio.bus_get_sync(Gio.BusType.SESSION)
    values = {}
    owner = 0

    def get_property(*args):
        return values.get(args[-1])

    registration = connection.register_object(
        INDICATOR_PATH, INTERFACE.interfaces[0], None, get_property, None,
    )

    def update():
        nonlocal values, owner
        try:
            state = json.loads(control.read_text())
        except (OSError, ValueError):
            return True
        if state['phase'] == 'offline':
            if owner:
                Gio.bus_unown_name(owner)
                owner = 0
            return True
        next_values = {
            'Phase': GLib.Variant('s', state['phase']),
            'Level': GLib.Variant('d', state.get('peak', -1)),
            'Waveform': GLib.Variant('ad', state.get('wave', [2]*6)),
            'Visible': GLib.Variant('b', state.get('visible', False)),
        }
        changed = {key: value for key, value in next_values.items() if value != values.get(key)}
        values = next_values
        if not owner:
            owner = Gio.bus_own_name_on_connection(connection, INDICATOR, Gio.BusNameOwnerFlags.NONE)
        elif changed:
            connection.emit_signal(
                None, INDICATOR_PATH, 'org.freedesktop.DBus.Properties', 'PropertiesChanged',
                GLib.Variant('(sa{sv}as)', (INDICATOR, changed, [])),
            )
        return True

    timer = GLib.timeout_add(20, update)
    loop.run()
    GLib.source_remove(timer)
    if owner:
        Gio.bus_unown_name(owner)
    connection.unregister_object(registration)


project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-dictation-state-') as temporary:
    root=Path(temporary)
    for name in ['Commons','Ui']:
        (root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/DictationState.qml').read_text())
    (root/'voxtype').mkdir()
    (root/'voxtype/state').write_text('recording\n')
    (root/'bin').mkdir()
    bridge=root/'bin/voxtype-audio-bridge'
    bridge.write_text("""#!/bin/sh
while :; do
    printf '%s\n' '{"peak":0.25}'
    sleep 0.04
done
""")
    bridge.chmod(0o755)
    env=dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
             ISLAND_DICTATION_RUNTIME=str(root), PATH=str(root/'bin')+':'+os.environ['PATH'])
    loop = GLib.MainLoop()
    indicator = threading.Thread(target=serve_indicator, args=(root/'indicator.json', loop), daemon=True)
    indicator.start()
    try:
        result=subprocess.run(['qs','-p',str(root),'--no-color'],env=env,
                              stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
    finally:
        loop.quit()
        indicator.join()
    print(result.stdout)
    assert_qml_pass(result, 'DICTATION_STATE_PASS')

#!/usr/bin/env python3
"""Exercise the real notification service on a private D-Bus, never the desktop bus."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

project = Path(__file__).resolve().parents[1]


def run(root):
    import dbus
    env = dict(os.environ, HOME=str(root / 'home'), QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    log = (root / 'service.log').open('w+')
    process = subprocess.Popen(['qs', '-p', str(root), '--no-color'], env=env, stdout=log, stderr=subprocess.STDOUT)

    def ipc(method, *args):
        return subprocess.check_output(['qs', 'ipc', '-p', str(root), 'call', 'test', method, *map(str, args)], env=env, text=True, stderr=subprocess.DEVNULL).strip()

    def state():
        return json.loads(ipc('state'))

    def wait_for(predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                value = state()
                if predicate(value):
                    return value
            except (subprocess.CalledProcessError, json.JSONDecodeError):
                pass
            time.sleep(.04)
        raise AssertionError('Notification state did not settle')

    try:
        wait_for(lambda s: s['loaded'])
        bus = dbus.SessionBus()
        api = dbus.Interface(bus.get_object('org.freedesktop.Notifications', '/org/freedesktop/Notifications'), 'org.freedesktop.Notifications')

        def send(title, replace=0, hints=None):
            return int(api.Notify('Test sender', dbus.UInt32(replace), '', title, 'Body', dbus.Array([], signature='s'), dbus.Dictionary(hints or {}, signature='sv'), dbus.Int32(-1)))

        first = send('Unread')
        s = wait_for(lambda s: len(s['active']) == 1)
        key = s['active'][0]['key']
        send('Updated', first)
        wait_for(lambda s: len(s['active']) == 1 and s['active'][0]['summary'] == 'Updated')
        api.CloseNotification(dbus.UInt32(first))
        wait_for(lambda s: not s['active'] and not s['history'] and not s['latest'])

        second = send('Read after popup timeout')
        key = wait_for(lambda s: len(s['active']) == 1)['active'][0]['key']
        ipc('age', key)
        wait_for(lambda s: not s['active'] and len(s['history']) == 1)
        assert state()['refs'] == 1, 'Timeout lost the sender reference'
        api.CloseNotification(dbus.UInt32(second))
        wait_for(lambda s: not s['active'] and not s['history'] and s['refs'] == 0)

        third = send('Update after timeout')
        key = wait_for(lambda s: len(s['active']) == 1)['active'][0]['key']
        ipc('age', key)
        wait_for(lambda s: len(s['history']) == 1)
        send('Back in active', third)
        wait_for(lambda s: len(s['active']) == 1 and not s['history'])
        ipc('clearActive')
        s = wait_for(lambda s: not s['active'] and len(s['history']) == 1)
        assert s['history'][0]['closed_reason'] == 'dismissed'
        assert s['refs'] == 0
        ipc('saveState')
        saved = json.loads((root / 'home/.local/state/omarchy/island/state.json').read_text())
        assert saved['history'][0]['closed_reason'] == 'dismissed', 'Save overwrote the closing reason'
        send('Still unread')
        wait_for(lambda s: len(s['active']) == 1)
        ipc('clearArchive')
        wait_for(lambda s: len(s['active']) == 1 and not s['history'])
        ipc('clearActive')
        ipc('clearArchive')
        wait_for(lambda s: not s['active'] and not s['history'])
        send('Transient', hints={'transient': dbus.Boolean(True)})
        key = wait_for(lambda s: len(s['active']) == 1)['active'][0]['key']
        ipc('age', key)
        wait_for(lambda s: not s['active'] and not s['history'] and s['refs'] == 0)
        # Capacity eviction must retain the new notification and let the sender
        # recall older rows from history; references remain bounded.
        ids = [send('Capacity ' + str(i)) for i in range(102)]
        s = wait_for(lambda s: len(s['active']) == 100 and len(s['history']) == 2)
        assert s['refs'] == 102
        assert any(row['originalId'] == ids[-1] for row in s['active']), 'Newest notification was evicted'
        api.CloseNotification(dbus.UInt32(s['history'][0]['originalId']))
        wait_for(lambda s: len(s['history']) == 1 and s['refs'] == 101)
        ipc('expireHistory')
        wait_for(lambda s: not s['history'] and s['refs'] == 100)
        ipc('clearActive')
        wait_for(lambda s: not s['active'] and len(s['history']) == 100)
        send('Unread at restart')
        wait_for(lambda s: len(s['active']) == 1)
        ipc('saveState')
        process.terminate()
        process.wait(timeout=5)
        process = subprocess.Popen(['qs', '-p', str(root), '--no-color'], env=env, stdout=log, stderr=subprocess.STDOUT)
        s = wait_for(lambda s: s['loaded'] and not s['active'] and len(s['history']) == 100)
        assert s['refs'] == 0, 'Restart restored live sender references'
        assert any(row['closed_reason'] == 'dismissed' for row in s['history'])
        assert any(row['summary'] == 'Unread at restart' and row['closed_reason'] == 'restart' for row in s['history'])
        print('PASS: D-Bus replacement, recall before/after timeout, separate clearing, transient rows, capacity, retention and restart history.')
    finally:
        process.terminate()
        process.wait(timeout=5)
        log.seek(0)
        output = log.read()
        log.close()
        if any(error in output for error in ['ReferenceError:', 'TypeError:', 'Cannot assign', 'Unable to assign']):
            raise AssertionError(output)


if len(sys.argv) > 1:
    run(Path(sys.argv[1]))
else:
    with tempfile.TemporaryDirectory(prefix='island-notifications-') as temporary:
        root = Path(temporary)
        (root / 'home').mkdir()
        for name in ['Commons', 'Ui']:
            (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name)
        module = root / 'Island'
        module.mkdir()
        for name in ['Service.qml', 'Store.js', 'Security.js', 'Markup.js', 'Detect.js', 'Model.js', 'Downloads.js']:
            shutil.copy2(project / 'plugin' / name, module / name)
        (module / 'bin').mkdir()
        shutil.copy2(project / 'plugin/bin/watch-downloads', module / 'bin/watch-downloads')
        (module / 'WeatherService.qml').write_text('import QtQuick\nItem {}\n')
        (module / 'IndicatorState.qml').write_text('import QtQuick\nItem {property var consumers:[];property bool downloading:false; function announceMode(mode,on){} function showOsd(payload){return false} function hideOsd(){}}\n')
        (module / 'DictationState.qml').write_text('import QtQuick\nItem {property bool active:false;readonly property bool showing:false}\n')
        (root / 'shell.qml').write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "Island" as Island
ShellRoot {
  Island.Service {id:service}
  IpcHandler {
    target:"test"
    function state():string {return JSON.stringify({loaded:service.loaded,active:service.activeEntries,history:service.historyEntries,refs:Object.keys(service.refs).length,latest:service.latest})}
    function age(key:string):void {service.entries=service.entries.map(function(r){if(r.key===key){r.ts=Date.now()/1000-400;r.duration=1}return r})}
    function expireHistory():void {service.history=service.history.map(function(r){r.closed_ts=1;return r});service.pruneHistory()}
    function clearActive():void {service.clear()}
    function clearArchive():void {service.clearHistory()}
    function saveState():void {service.save()}
  }
}
''')
        subprocess.run(['dbus-run-session', '--', sys.executable, __file__, str(root)], check=True, timeout=25)

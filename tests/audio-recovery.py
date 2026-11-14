#!/usr/bin/env python3
"""Recover the real media collector after a failed helper, on private MPRIS."""
from session import ensure
ensure()
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

if len(sys.argv) > 1 and sys.argv[1] == '--player':
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    name = dbus.service.BusName('org.mpris.MediaPlayer2.island_test', bus)

    class Player(dbus.service.Object):
        @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='ss', out_signature='v')
        def Get(self, interface, property_name):
            return self.GetAll(interface)[property_name]

        @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='s', out_signature='a{sv}')
        def GetAll(self, interface):
            if interface == 'org.mpris.MediaPlayer2':
                return {'Identity': 'Island test', 'DesktopEntry': 'island-test',
                        'CanQuit': False, 'CanRaise': False, 'HasTrackList': False,
                        'SupportedUriSchemes': dbus.Array([], signature='s'),
                        'SupportedMimeTypes': dbus.Array([], signature='s')}
            return {'PlaybackStatus': 'Playing', 'Rate': 1.0, 'Volume': 1.0,
                    'MinimumRate': 1.0, 'MaximumRate': 1.0, 'Position': dbus.Int64(0),
                    'CanControl': True, 'CanPlay': True, 'CanPause': True,
                    'CanSeek': False, 'CanGoNext': False, 'CanGoPrevious': False,
                    'Metadata': dbus.Dictionary({'mpris:trackid': dbus.ObjectPath('/track/one'),
                        'xesam:title': 'Unchanged track',
                        'xesam:artist': dbus.Array(['Fixture'], signature='s')}, signature='sv')}

    player = Player(bus, '/org/mpris/MediaPlayer2')
    Path(sys.argv[2]).touch()
    GLib.MainLoop().run()
    raise SystemExit()

project = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-audio-recovery-') as temporary:
    root = Path(temporary)
    for module in ['Commons', 'Ui']:
        (root / module).symlink_to(Path('/usr/share/omarchy/shell') / module)
    (root / 'Island').symlink_to(project / 'plugin')
    helper = root / 'audio-fixture.py'
    attempts = root / 'attempts'
    helper.write_text('''import pathlib,sys,time
attempts=pathlib.Path(sys.argv[1])
count=int(attempts.read_text()) if attempts.exists() else 0
attempts.write_text(str(count+1))
with attempts.with_suffix(".times").open("a") as timestamps: timestamps.write(str(time.monotonic())+"\\n")
if count<2: sys.exit(1)
while True:
    print('[0.4,0.3,0.2]',flush=True)
    time.sleep(0.05)
''')
    (root / 'shell.qml').write_text('''import QtQuick
import QtTest
import Quickshell
import qs.Commons as Commons
import "Island" as Island
ShellRoot {
  Item { id:consumer }
  Island.MediaState {
    id:media
    audioCommand:["python3",Quickshell.env("AUDIO_FIXTURE"),Quickshell.env("AUDIO_ATTEMPTS")]
  }
  TestCase {
    id:test
    when:false
    function until(predicate,timeout,message) {
      var elapsed=0
      while(!predicate() && elapsed<timeout) { wait(20); elapsed+=20 }
      if(!predicate()) throw new Error(message)
    }
    function run() {
      try {
        Commons.Style.reduceMotion=false
        Island.Preferences.watchVisualizer(consumer,true)
        until(function(){return media.audioFailed},2000,"fixture failure was not detected")
        if(media.error!=="audio monitor") throw new Error("missing audio error")
        Commons.Style.reduceMotion=true
        wait(1200)
        if(media.audioLevel!==0) throw new Error("hidden collector retried")
        Commons.Style.reduceMotion=false
        until(function(){return !media.audioFailed && media.audioLevel>0.1},6000,"audio collector never recovered on the same track")
        if(media.audioFailures!==0) throw new Error("recovery did not reset retry backoff")
        if(media.error!=="") throw new Error("successful recovery kept the red audio error")
        Island.Preferences.watchVisualizer(consumer,false)
        wait(200)
        if(media.audioFailed || media.samplingAudio) throw new Error("intentional stop treated as failure")
        console.log("AUDIO_RECOVERY_PASS")
      } catch(error) { console.log("AUDIO_RECOVERY_FAIL",String(error)) }
      Qt.quit()
    }
  }
  Timer { interval:100;running:true;onTriggered:test.run() }
}
''')
    provider = subprocess.Popen([sys.executable, __file__, '--player', str(root / 'ready')])
    try:
        deadline = time.monotonic() + 3
        while not (root / 'ready').exists():
            assert provider.poll() is None and time.monotonic() < deadline, 'MPRIS fixture failed'
            time.sleep(.02)
        env = dict(os.environ, AUDIO_FIXTURE=str(helper), AUDIO_ATTEMPTS=str(attempts))
        result = subprocess.run(['qs', '-p', str(root), '--no-color'], env=env,
                                capture_output=True, text=True, timeout=11)
        output = result.stdout + result.stderr
        print(output)
        assert 'AUDIO_RECOVERY_PASS' in output and not any(marker in output for marker in
            ['AUDIO_RECOVERY_FAIL', 'FAIL!', 'ReferenceError:', 'TypeError:', 'Binding loop']), output
        assert attempts.read_text() == '3', 'Collector restarted while hidden or reduced motion was active'
        starts = [float(value) for value in attempts.with_suffix('.times').read_text().splitlines()]
        assert starts[2] - starts[1] >= 1.8, 'Consecutive failures retried without backoff'
    finally:
        provider.terminate()
        provider.wait(timeout=3)

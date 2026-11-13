#!/usr/bin/env python3
"""Opt-in integration check against the installed Island. Only touches its own test rows."""
import sys
if '--live-session' not in sys.argv:
    raise SystemExit('This check changes the installed Island. Use --live-session explicitly; '
                     'isolated notification coverage is in bin/test.')
sys.argv.remove('--live-session')
import dbus,json,subprocess,time

def ipc(target,method,*args):
    return subprocess.check_output(['omarchy-shell',target,method,*args],text=True).strip()
def probe(): return json.loads(ipc('notifications','probe'))
bus=dbus.SessionBus()
api=dbus.Interface(bus.get_object('org.freedesktop.Notifications','/org/freedesktop/Notifications'),'org.freedesktop.Notifications')
initial=probe()
for _ in range(40):
    if initial.get('stateLoaded'): break
    time.sleep(.05)
    initial=probe()
assert initial.get('stateLoaded'),'Island state did not finish loading'
base=initial['count']
session=initial['session']
ids=[]
def send(summary,replace=0,expiry=-1,body='Test text'):
    n=int(api.Notify('Island Integration',dbus.UInt32(replace),'',summary,body,dbus.Array([],signature='s'),dbus.Dictionary({},signature='sv'),dbus.Int32(expiry)))
    if n not in ids: ids.append(n)
    time.sleep(.12)
    return n
try:
    n=send('Island integration first')
    assert probe()['count']==base+1
    send('Island integration updated',replace=n)
    assert probe()['count']==base+1,'replaces_id duplicated a notification'
    ipc('island','close')
    time.sleep(.25)
    n2=send('Island integration latest',body='Ваш код: 482913 и AB12-CD34')
    assert json.loads(ipc('island','status'))['alert']=='notification'
    assert probe()['count']==base+2
    api.CloseNotification(dbus.UInt32(n2));time.sleep(.2)
    assert probe()['count']==base+1,'sender recall must remove the notification'
    ipc('notifications','dismiss','Island integration')
    # History also gets deleted by the prefix command.
    print('PASS: DBus arrival, replaces_id, latest alert, sender close, history, cleanup.')
finally:
    for n in ids:
        try: api.CloseNotification(dbus.UInt32(n))
        except dbus.DBusException: pass
    for n in ids: ipc('notifications','remove',f'n{session}_{n}')
    ipc('island','close')

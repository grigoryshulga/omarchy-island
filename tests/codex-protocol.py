#!/usr/bin/env python3
"""Optional real Codex transport smoke test; private home/socket, no credentials or turns.

Usage: python3 tests/codex-protocol.py /absolute/path/to/real/codex
Pass the actual executable, not a login/credential-manager wrapper.
"""
from session import ensure
ensure()
import os
import json
import selectors
from pathlib import Path
import subprocess
import sys
import tempfile
import time

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'plugin/bin'))
from codex_transport import CodexSocket
binary=Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='island-codex-protocol-') as temporary:
    root=Path(temporary);socket=root/'app-server-control'/'app-server-control.sock'
    socket.parent.mkdir()
    os.environ['CODEX_HOME']=str(root)
    log=open(root/'server.log','w+')
    server=subprocess.Popen([str(binary),'app-server','--listen','unix://'+str(socket)],
                            stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=log)
    client=None
    try:
        deadline=time.monotonic()+10
        while not socket.exists() and time.monotonic()<deadline and server.poll() is None:
            time.sleep(.05)
        assert socket.exists(),'Codex did not create its private socket'
        client=CodexSocket()
        def rpc(key,method,params):
            client.send(dict(id=key,method=method,params=params))
            deadline=time.monotonic()+10
            while time.monotonic()<deadline:
                message=client.receive()
                if message and message.get('id')==key:
                    assert 'error' not in message,(method,message.get('error',{}))
                    return message['result']
            raise AssertionError('Codex response timeout')
        rpc(1,'initialize',dict(clientInfo=dict(name='island_protocol_test',version='1.0.0'),capabilities=dict(experimentalApi=True)))
        client.send(dict(method='initialized'))
        result=rpc(2,'thread/list',dict(limit=30,sortKey='updated_at',sourceKinds=['cli','vscode','appServer'],archived=False))
        assert result['data']==[],'Private home must not expose real sessions'
        def check_bridge(readonly, thread_id=None):
            bridge=subprocess.Popen([sys.executable,str(Path(__file__).resolve().parents[1]/'plugin/bin/codex-bridge')]+(['--read-only'] if readonly else []),stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            try:
                selector=selectors.DefaultSelector();selector.register(bridge.stdout,selectors.EVENT_READ)
                buffer=b'';events=[];deadline=time.monotonic()+10
                while not any(e.get('type')=='sessions' and (not thread_id or any(r['id']==thread_id and r['attached']==(not readonly) for r in e['rows'])) for e in events):
                    assert time.monotonic()<deadline,'Bridge timeout'
                    assert selector.select(max(0,deadline-time.monotonic())),('Bridge timeout',events)
                    chunk=os.read(bridge.stdout.fileno(),65536);assert chunk,'Bridge closed'
                    buffer+=chunk
                    while b'\n' in buffer:
                        line,buffer=buffer.split(b'\n',1);events.append(json.loads(line))
                assert any(e.get('status')=='connected' and e.get('canRespond') == (not readonly) for e in events)
                if not thread_id:
                    assert next(e['rows'] for e in events if e.get('type')=='sessions')==[]
                bridge.stdin.close();bridge.wait(timeout=3)
            finally:
                if bridge.poll() is None:bridge.kill();bridge.wait()
        check_bridge(True)
        # Prepare saved local history without starting a turn or invoking a model.
        # A completely empty new session has no rollout to resume yet.
        thread=rpc(3,'thread/start',{'cwd':str(root)})['thread']
        rpc(33,'thread/inject_items',{'threadId':thread['id'],'items':[{'type':'message','role':'user','content':[{'type':'input_text','text':'Local protocol fixture; no turn is started.'}]}]})
        check_bridge(False,thread['id'])
        check_bridge(False,thread['id'])  # A new connection restores its subscription.
        check_bridge(True,thread['id'])   # Read-only discovery does not subscribe.
        state=rpc(4,'thread/read',{'threadId':thread['id'],'includeTurns':True})['thread']
        assert state['turns']==[],'Automatic subscription must not start agent work'
        print('Codex real Unix WebSocket discovery and automatic subscription passed')
    finally:
        if client:client.close()
        server.terminate()
        try:server.wait(timeout=3)
        except subprocess.TimeoutExpired:server.kill();server.wait()
        log.close()

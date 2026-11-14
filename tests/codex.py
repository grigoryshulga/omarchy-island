#!/usr/bin/env python3
"""Pure adapter behavior and QML -> real bridge -> fake Codex Unix WebSocket server roundtrip."""
from session import ensure
ensure()
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import sys
from module_harness import ModuleHarness, PROJECT

sys.path.insert(0, str(PROJECT/'plugin/bin'))
loader=importlib.machinery.SourceFileLoader('codex_bridge',str(PROJECT/'plugin/bin/codex-bridge'))
spec=importlib.util.spec_from_loader(loader.name,loader)
module=importlib.util.module_from_spec(spec);loader.exec_module(module)
from codex_model import row, apply_turn, question_request, validate_answers
thread=dict(id='thread-1',cwd='/tmp/project',preview='Fixture',status={'type':'idle'},turns=[])
assert row(dict(thread,parentThreadId='parent')) is None
assert row(dict(thread,status={'type':'notLoaded'}))['status']=='unloaded'
waiting=row(dict(thread,status={'type':'active','activeFlags':['waitingOnApproval']}))
assert waiting['requestId'] and waiting['requestKind']=='external'
assert not row(thread, waiting)['requestId']
apply_turn(waiting,dict(id='one',status='inProgress',startedAt=100))
apply_turn(waiting,dict(id='two',status='inProgress',startedAt=200))
assert waiting['startedAt']==200
apply_turn(waiting,dict(id='two',status='completed',startedAt=200,completedAt=250))
assert waiting['finishedAt']==250
question=dict(id='q',question='Pick one',options=[dict(label='A',description='First')])
request=question_request('key',{'questions':[question]},True)
assert validate_answers(request,{'q':['A']})
assert not validate_answers(request,{'q':['B']})
assert not validate_answers(request,{'q':['A'],'other':['A']})
assert not question_request('key',{'questions':[dict(question,isSecret=True,question='SECRET')]},True)['canRespond']
assert 'SECRET' not in json.dumps(question_request('key',{'questions':[dict(question,isSecret=True,question='SECRET')]},True))
assert not question_request('key',{'questions':[question,question]},True)['canRespond']
assert not question_request('key',{'questions':[question]},False)['canRespond']

out=[];wire=[]
module.emit=out.append
bridge=module.Bridge();bridge.ready=True;bridge.write=wire.append;bridge.rows={'thread-1':row(thread)}
bridge.command(dict(type='action',actionId='1',operation='attach',threadId='thread-1'))
assert wire[-1]['method']=='thread/resume'
rpc=wire[-1]['id']
# Requests can arrive before the resume response. Preserve them through hydration.
bridge.receive(dict(id=42,method='item/tool/requestUserInput',params=dict(threadId='thread-1',questions=[question])))
bridge.receive(dict(id=rpc,result={'thread':thread}))
key=bridge.rows['thread-1']['requestId'];assert key
reply=dict(type='respond',threadId='thread-1',requestId=key,revision=key,answers={'q':['A']})
bridge.command(dict(reply,revision='old'));assert out[-1]['status']=='failed'
bridge.command(reply);assert wire[-1]==dict(id=42,result={'answers':{'q':{'answers':['A']}}})
length=len(wire);bridge.command(reply);assert len(wire)==length
bridge.receive(dict(method='serverRequest/resolved',params=dict(threadId='thread-1',requestId=42)))
assert not bridge.rows['thread-1']['requestId']
bridge.command(dict(type='action',actionId='2',operation='message',threadId='unknown',text='no'));assert len(wire)==length
bridge.readonly=True;bridge.command(dict(type='action',actionId='3',operation='attach',threadId='thread-1'));assert len(wire)==length
bridge.readonly=False
bridge.command(dict(type='action',actionId='4',operation='message',threadId='thread-1',text='literal $(touch /tmp/never)'))
assert wire[-1]['params']['input'][0]['text']=='literal $(touch /tmp/never)'
bridge.receive(dict(id=wire[-1]['id'],error={'message':'PRIVATE ERROR'}));assert [e for e in out if e['type']=='action'][-1]['status']=='failed'
assert 'PRIVATE ERROR' not in json.dumps(out)
# Disabled/unknown operations and paths never turn into shell commands.
length=len(wire)
bridge.command(dict(type='action',actionId='5',operation='create',threadId='',cwd='$(pwd)',text='x'));assert len(wire)==length

# Automatic discovery subscribes loaded top-level work, never saved history or subagents.
auto=module.Bridge();auto.ready=True;auto_wire=[];auto.write=auto_wire.append
history=dict(thread,id='history',status={'type':'notLoaded'})
child=dict(thread,id='child',parentThreadId='parent')
auto.rpc('thread/list',{})
auto.receive(dict(id=auto_wire[-1]['id'],result={'data':[thread,history,child]}))
resumes=[m for m in auto_wire if m['method']=='thread/resume']
assert len(resumes)==1 and resumes[0]['params']==dict(threadId='thread-1',excludeTurns=True)
auto.auto_attach();assert len(auto_wire)==2,'Duplicate subscription while pending'
auto.receive(dict(id=resumes[0]['id'],error={'message':'PRIVATE'}))
assert auto.rows['thread-1']['attachState']=='retrying'
deadline=auto.retry_at['thread-1'];auto.auto_attach(deadline-1);assert len(auto_wire)==2
auto.auto_attach(deadline);assert auto_wire[-1]['method']=='thread/resume'
auto.receive(dict(id=auto_wire[-1]['id'],result={'thread':thread}))
assert auto.rows['thread-1']['attached'] and 'thread-1' not in auto.retry_at
count=len(auto_wire);auto.auto_attach();assert len(auto_wire)==count
# Discover loaded sessions outside the recent-history page and keep their subscription.
auto.rpc('thread/loaded/list',{'limit':30})
auto.receive(dict(id=auto_wire[-1]['id'],result={'data':['older','older']}))
assert auto_wire[-1]['method']=='thread/read'
auto.receive(dict(id=auto_wire[-1]['id'],result={'thread':dict(thread,id='older')}))
assert auto_wire[-1]['method']=='thread/resume' and auto_wire[-1]['params']['threadId']=='older'
# A late resume response must not resurrect an archived session.
late=auto_wire[-1]['id']
auto.receive(dict(method='thread/archived',params={'threadId':'older'}))
auto.receive(dict(id=late,result={'thread':dict(thread,id='older')}))
assert 'older' not in auto.rows
# New work is discovered on later metadata refreshes.
auto.rpc('thread/list',{})
auto.receive(dict(id=auto_wire[-1]['id'],result={'data':[thread,dict(thread,id='new'),history]}))
assert auto_wire[-1]['method']=='thread/resume' and auto_wire[-1]['params']['threadId']=='new'
assert not any(m['method'] in ('turn/start','turn/interrupt','thread/start') for m in auto_wire)
# Bound startup concurrency; read-only monitoring never resumes anything.
bulk=module.Bridge();bulk.ready=True;bulk_wire=[];bulk.write=bulk_wire.append
bulk.rows={str(i):row(dict(thread,id=str(i))) for i in range(30)}
bulk.auto_attach();bulk.auto_attach();assert len(bulk_wire)==4
readonly=module.Bridge(True);readonly.ready=True;readonly_wire=[];readonly.write=readonly_wire.append
readonly.rows={'thread-1':row(thread)};readonly.auto_attach();assert not readonly_wire
readonly.refresh();assert [m['method'] for m in readonly_wire]==['thread/list','thread/loaded/list']
assert row(dict(thread,source={'subAgent':{'thread_spawn':{}}})) is None
assert not row(history,dict(row(thread),attached=True))['attached']

# Loaded work replaces history when the 30-card limit is reached.
full=module.Bridge();full.ready=True;full_wire=[];full.write=full_wire.append
full.rows={str(i):row(dict(history,id=str(i))) for i in range(30)}
full.rpc('thread/read',{'threadId':'old-live','includeTurns':False})
full.receive(dict(id=full_wire[-1]['id'],result={'thread':dict(thread,id='old-live')}))
assert len(full.rows)==30 and 'old-live' in full.rows
assert full_wire[-1]['method']=='thread/resume'
full.receive(dict(id=full_wire[-1]['id'],error={'code':-32600}))
retry=full.retry_at['old-live']
full.rpc('thread/list',{})
full.receive(dict(id=full_wire[-1]['id'],result={'data':[dict(history,id=str(i)) for i in range(30)]}))
assert full.retry_at['old-live']==retry,'History refresh must preserve retry backoff for older live work'
full.rpc('thread/loaded/list',{})
full.receive(dict(id=full_wire[-1]['id'],result={'data':[]}))
assert full.rows['old-live']['status']=='unloaded' and 'old-live' not in full.retry_at
assert row(dict(thread,status={'type':'unknown'}))['status']=='unloaded'

# A malformed success cannot cause a tight automatic resume loop.
broken=module.Bridge();broken.ready=True;broken_wire=[];broken.write=broken_wire.append
broken.rows={'thread-1':row(thread)};broken.auto_attach()
try:
    broken.receive(dict(id=broken_wire[-1]['id'],result={}))
    raise AssertionError('Malformed resume accepted')
except RuntimeError as error:
    assert str(error)=='protocol'
assert len(broken_wire)==1

import base64
import hashlib
import socket
import struct
import threading

with ModuleHarness() as harness:
    record=[]
    listener=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM)
    socket_path=harness.root/'sock'
    listener.bind(str(socket_path));listener.listen();listener.settimeout(.1)
    home=harness.root/'codex';control=home/'app-server-control';control.mkdir(parents=True)
    (control/'app-server-control.sock').symlink_to(socket_path)
    done=threading.Event()
    errors=[]
    def serve():
        def exact(connection,size):
            result=b''
            while len(result)<size:
                data=connection.recv(size-len(result))
                if not data:raise EOFError()
                result+=data
            return result
        while not done.is_set():
            try:connection,_=listener.accept()
            except socket.timeout:continue
            except OSError:return
            try:
                connection.settimeout(2)
                header=b''
                while b'\r\n\r\n' not in header:header+=exact(connection,1)
                fields=dict(line.split(': ',1) for line in header.decode().split('\r\n')[1:] if ': ' in line)
                accept=base64.b64encode(hashlib.sha1((fields['Sec-WebSocket-Key']+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
                connection.sendall(('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: '+accept+'\r\n\r\n').encode())
                def send(value):
                    body=json.dumps(value).encode();size=len(body)
                    prefix=bytes([0x81,size]) if size<126 else bytes([0x81,126])+struct.pack('!H',size)
                    connection.sendall(prefix+body)
                thread=dict(id='thread-1',cwd='/tmp/project',preview='Fixture',status={'type':'idle'},turns=[])
                while True:
                    first,second=exact(connection,2);assert first==0x81 and second&128
                    size=second&127
                    if size==126:size=struct.unpack('!H',exact(connection,2))[0]
                    if size==127:size=struct.unpack('!Q',exact(connection,8))[0]
                    assert size<65536
                    mask=exact(connection,4);body=exact(connection,size)
                    msg=json.loads(bytes(v^mask[i%4] for i,v in enumerate(body)))
                    record.append(msg);method=msg.get('method')
                    if method=='initialize':send(dict(id=msg['id'],result={}))
                    elif method=='thread/turns/list':send(dict(id=msg['id'],result={'data':[]}))
                    elif method=='thread/loaded/list':send(dict(id=msg['id'],result={'data':['thread-1']}))
                    elif method=='thread/list':send(dict(id=msg['id'],result={'data':[thread]}))
                    elif method=='thread/resume':
                        send(dict(id=msg['id'],result={'thread':thread}))
                        send(dict(id=42,method='item/tool/requestUserInput',params=dict(threadId='thread-1',questions=[question])))
                    elif msg.get('id')==42:send(dict(method='serverRequest/resolved',params=dict(threadId='thread-1',requestId=42)))
                    elif method=='thread/start':send(dict(id=msg['id'],result={'thread':dict(thread,id='thread-2')}))
                    elif method=='turn/start':
                        thread['status']={'type':'active','activeFlags':[]}
                        send(dict(id=msg['id'],result={'turn':{'id':'turn-1','status':'inProgress'}}))
                    elif method=='turn/interrupt':
                        thread['status']={'type':'idle'}
                        send(dict(id=msg['id'],result={}))
                        send(dict(method='turn/completed',params=dict(threadId='thread-1',turn={'id':'turn-1','status':'interrupted'})))
            except (EOFError,ConnectionError,socket.timeout):pass
            except Exception as error:errors.append(error)
            finally:connection.close()
    worker=threading.Thread(target=serve);worker.start()
    try:
        harness.run(PROJECT/'tests/Codex.qml','CODEX_QML_PASS',dict(CODEX_HOME=str(home)))
    finally:
        done.set();listener.close();worker.join(timeout=3)
    assert not errors,errors
    assert len([m for m in record if m.get('method')=='initialize'])==3
    assert len([m for m in record if m.get('method')=='thread/resume'])==2
    turns=[m for m in record if m.get('method')=='turn/start']
    assert len(turns)==2 and turns[0]['params']['input'][0]['text']=='literal $(touch /tmp/never); <b>'
    assert turns[1]['params']['threadId']=='thread-2'
    assert turns[1]['params']['input'][0]['text']=='New task'
print('Codex adapter and QML checks passed')

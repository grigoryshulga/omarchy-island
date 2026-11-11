#!/usr/bin/env python3
"""Local fake T3 server: real HTTP/WebSocket, credentials, responses and reconnects."""
import base64
import copy
import hashlib
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import queue
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

project = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project / 'plugin/bin'))
from t3_model import request_view, select_threads, session_view, validate_answers
from t3_transport import local_origin, TransportError, WebSocket, MAX_MESSAGE

QUESTION = {'id':'q1', 'question':'Where?', 'options':[{'label':'Local', 'value':'local', 'description':'On this machine'}], 'allowCustomAnswer':True}
REQUEST = {'id':'request-1', 'kind':'user_input', 'status':'pending', 'responseCapability':{'type':'message'}}


def projection():
    return {'runtimeRequests':[copy.deepcopy(REQUEST)], 'turnItems':[{'type':'user_input_request', 'requestId':'request-1', 'questions':[copy.deepcopy(QUESTION)]}]}


class ModelTests(unittest.TestCase):
    def test_retention_and_priorities(self):
        now = time.time()
        rows = [{'id':str(i), 'status':'running', 'updatedAt':'2026-11-11T10:00:00Z'} for i in range(35)]
        rows += [{'id':'question', 'status':'idle', 'pendingRuntimeRequest':REQUEST},
                 {'id':'old', 'status':'completed', 'updatedAt':'2000-01-01T00:00:00Z'},
                 {'id':'archived', 'status':'running', 'archivedAt':'yes'},
                 {'id':'sidechat', 'status':'running', 'lineage':{'sideChat':True}},
                 {'id':'delegated', 'status':'running', 'delegatedFrom':{'threadId':'parent'}},
                 {'id':'child', 'status':'running', 'lineage':{'relationshipToParent':'subagent'}}]
        selected = select_threads(rows, now)
        self.assertEqual(len(selected), 30)
        self.assertEqual(selected[0]['id'], 'question')
        self.assertFalse({'old','archived','child','sidechat','delegated'} & {r['id'] for r in selected})
        self.assertEqual([r['id'] for r in select_threads(rows[35:],now)],['question'])

    def test_answers_and_revision(self):
        p = projection(); request = request_view(p, 'request-1')
        self.assertTrue(request['canRespond'])
        self.assertEqual(validate_answers(request, {'q1':['$(touch /tmp/never); <b>']}), {'q1':['$(touch /tmp/never); <b>']})
        for answer in ({}, {'q1':[]}, {'q1':['a','b']}, {'q1':'x'}, {'q1':['x'], 'other':['x']}, {'q1':['x'*4097]}):
            with self.assertRaises(ValueError): validate_answers(request, answer)
        p['turnItems'][0]['questions'][0]['allowCustomAnswer'] = False
        changed = request_view(p, 'request-1')
        self.assertNotEqual(changed['revision'], request['revision'])
        with self.assertRaises(ValueError): validate_answers(changed, {'q1':['custom']})
        self.assertEqual(validate_answers(changed, {'q1':['local']}), {'q1':['local']})
        p['turnItems'][0]['questions'] *= 2
        self.assertFalse(request_view(p, 'request-1')['canRespond'])
        p = projection(); p['runtimeRequests'][0]['responseCapability'] = {'type':'not_resumable'}
        self.assertFalse(request_view(p, 'request-1')['canRespond'])
        p['runtimeRequests'][0]['status'] = 'resolved'
        self.assertIsNone(request_view(p, 'request-1'))

    def test_approvals_not_promoted_to_questions(self):
        p=projection();p['runtimeRequests'][0]['kind']='command'
        p['turnItems'][0].update(type='approval_request',prompt='😀'*10000,reason='😀'*10000)
        request=request_view(p,'request-1')
        self.assertFalse(request['canRespond'])
        row={'id':'s','title':'😀'*256,'projectId':'p','pendingRuntimeRequest':REQUEST,'latestVisibleMessage':{'text':'😀'*2048}}
        cards=[session_view(row,{'p':'😀'*256},request)]*30
        self.assertLess(len(json.dumps({'type':'sessions','rows':cards})),4194304)

    def test_unsupported_forms_and_activity_time(self):
        for questions in ([None], [dict(QUESTION,options=[None])],
                          [dict(QUESTION,options=QUESTION['options']*2)],
                          [dict(QUESTION,id=f'q{i}',question='x'*8192) for i in range(8)]):
            p=projection();p['turnItems'][0]['questions']=questions
            request=request_view(p,'request-1')
            self.assertFalse(request['canRespond'])
            self.assertEqual(request['questions'],[])
        row={'id':'work','status':'completed','activityRunStatus':'running',
             'latestRunStartedAt':'2026-11-11T10:00:00Z','latestRunCompletedAt':'2026-11-11T10:01:00Z',
             'activityRunStartedAt':'2026-11-11T10:02:00Z'}
        view=session_view(row,{})
        self.assertEqual(view['status'],'running')
        self.assertEqual(view['finishedAt'],0)
        self.assertEqual(view['startedAt'],1794391320)

    def test_local_origin(self):
        self.assertEqual(local_origin('http://127.0.0.1:3773'), ('127.0.0.1',3773))
        self.assertEqual(local_origin('http://[::1]:3773'), ('::1',3773))
        for origin in ['https://example.com', 'http://localhost:3773', 'http://127.0.0.1:3773@evil.test', 'http://127.0.0.1:3773/path', 'http://192.168.1.1:3773', 'file:///tmp/a']:
            with self.assertRaises(TransportError): local_origin(origin)


def frame(payload, opcode=1, final=True):
    data = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
    size=len(data)
    length=bytes([size]) if size<126 else b'\x7e'+struct.pack('!H',size) if size<65536 else b'\x7f'+struct.pack('!Q',size)
    return bytes([(128 if final else 0)|opcode])+length+data


def recv_frame(stream):
    try: head=stream.read(2)
    except ConnectionResetError: return None
    if not head: return None
    size=head[1]&127
    if size==126: size=struct.unpack('!H',stream.read(2))[0]
    if size==127: size=struct.unpack('!Q',stream.read(8))[0]
    assert head[1]&128, 'Client frames must be masked'
    mask=stream.read(4);data=stream.read(size)
    raw=bytes(v^mask[i%4] for i,v in enumerate(data))
    return (head[0]&15, raw)


class FakeServer(ThreadingHTTPServer):
    daemon_threads=True
    def __init__(self):
        super().__init__(('127.0.0.1',0), Handler)
        self.resolved=False;self.writes=[];self.drop=False;self.protocol=2;self.pings=0
        self.socket_ready=threading.Event();self.client=None;self.sequence=1
    def shell(self):
        return {'snapshotSequence':self.sequence, 'schemaVersion':2, 'projects':[{'id':'p1','title':'Project'}], 'threads':[{
            'id':'thread-1', 'projectId':'p1', 'title':'A session', 'status':'running',
            'pendingRuntimeRequest':None if self.resolved else {'id':'request-1','kind':'user_input'},
            'updatedAt':'2026-11-11T10:00:00Z', 'latestVisibleMessage':{'text':'Working'}}], 'archivedThreads':[]}


class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def respond(self,data,status=200):
        raw=json.dumps(data).encode();self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
    def do_POST(self):
        if self.path=='/api/auth/websocket-ticket/rpc':
            assert self.headers['Authorization']=='Bearer TEST_SECRET'
            self.respond({'ticket':'TICKET'})
        else: self.respond({},404)
    def do_GET(self):
        if self.path=='/.well-known/t3/environment':
            return self.respond({'environmentId':'env-1','orchestrationProtocolVersion':self.server.protocol})
        if self.path.startswith('/ws?'):
            assert 'orchestrationProtocol=2' in self.path and 'wsTicket=TICKET' in self.path
            accept=base64.b64encode(hashlib.sha1((self.headers['Sec-WebSocket-Key']+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
            self.send_response(101);self.send_header('Upgrade','websocket');self.send_header('Connection','Upgrade');self.send_header('Sec-WebSocket-Accept',accept);self.end_headers()
            self.server.client=self.connection;self.server.socket_ready.set()
            while True:
                packet=recv_frame(self.rfile)
                if packet is None: return
                opcode,raw=packet
                if opcode==10: continue
                message=json.loads(raw)
                if message.get('_tag')=='Ping':
                    self.server.pings+=1
                    self.connection.sendall(frame({'_tag':'Pong'}))
                elif message.get('tag')=='orchestration.subscribeShell':
                    data=json.dumps({'_tag':'Chunk','requestId':'shell','values':[{'kind':'snapshot','snapshot':self.server.shell()}]}).encode()
                    # Test fragmented UTF-8 JSON with a ping in between fragments.
                    self.connection.sendall(frame(data[:17],final=False)+frame(b'ping',opcode=9)+frame(data[17:],opcode=0))
                elif message.get('tag')=='orchestration.dispatchCommand':
                    self.server.writes.append(message['payload'])
                    if self.server.drop:
                        self.connection.shutdown(socket.SHUT_RDWR);return
                    self.server.resolved=True;self.server.sequence+=1
                    self.connection.sendall(frame({'_tag':'Exit','requestId':message['id'],'exit':{'_tag':'Success','value':{}}}))
            return
        assert self.headers['Authorization']=='Bearer TEST_SECRET'
        assert self.headers['x-t3-orchestration-protocol']=='2'
        if self.path=='/api/orchestration/shell': return self.respond(self.server.shell())
        if self.path=='/api/orchestration/threads/thread-1/bounded':
            p=projection()
            if self.server.resolved:p['runtimeRequests'][0]['status']='resolved'
            return self.respond({'projection':p,'snapshotSequence':self.server.sequence})
        self.respond({},404)


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='island-t3-');self.root=Path(self.tmp.name)
        self.server=FakeServer();threading.Thread(target=self.server.serve_forever,daemon=True).start()
        (self.root/'userdata').mkdir();(self.root/'bin').mkdir()
        (self.root/'userdata/server-runtime.json').write_text(json.dumps({'origin':f'http://127.0.0.1:{self.server.server_port}'}))
        cli=self.root/'bin/t3'
        cli.write_text('#!'+sys.executable+'\nimport sys,json,os\nfrom pathlib import Path\nwith open(os.environ["CLI_LOG"],"a") as f:f.write(json.dumps(sys.argv[1:])+"\\n")\nif "issue" in sys.argv:print(json.dumps({"token":"TEST_SECRET","sessionId":"session-1"}))\nelse:print("Revoked session session-1")\n')
        cli.chmod(0o755);self.process=None
    def start(self, readonly=False):
        env=dict(os.environ,T3CODE_HOME=str(self.root),CLI_LOG=str(self.root/'cli.log'),PATH=str(self.root/'bin')+os.pathsep+os.environ['PATH'])
        self.process=subprocess.Popen([sys.executable,str(project/'plugin/bin/t3-bridge')]+(['--read-only'] if readonly else []),stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
        self.events=queue.Queue();self.seen=[]
        def read():
            for line in self.process.stdout:
                self.assertNotIn('TEST_SECRET',line)
                self.events.put(json.loads(line))
        threading.Thread(target=read,daemon=True).start()
    def wait(self, predicate, timeout=8):
        end=time.monotonic()+timeout
        while time.monotonic()<end:
            event=self.events.get(timeout=max(.01,end-time.monotonic()));self.seen.append(event)
            if predicate(event): return event
        self.fail('Timed out waiting for bridge event')
    def send(self, **fields):
        self.process.stdin.write(json.dumps(fields)+'\n');self.process.stdin.flush()
    def stop(self):
        if self.process:
            self.process.stdin.close();self.process.wait(timeout=15)
            self.assertEqual(self.process.returncode,0,self.process.stderr.read())
            self.process.stdout.close();self.process.stderr.close();self.process=None
    def tearDown(self):
        self.stop();self.server.shutdown();self.server.server_close();self.tmp.cleanup()
    def test_round_trip_stale_validation_and_cleanup(self):
        self.start()
        self.wait(lambda e:e.get('status')=='connected')
        request=self.wait(lambda e:e['type']=='sessions')['rows'][0]['request']
        action={'type':'respond','threadId':'thread-1','requestId':'request-1','revision':request['revision']}
        self.send(**dict(action,answers={}))
        self.assertEqual(self.wait(lambda e:e['type']=='response')['status'],'invalid')
        self.send(**dict(action,revision='outdated',answers={'q1':['local']}))
        self.assertEqual(self.wait(lambda e:e['type']=='response')['status'],'stale')
        self.assertEqual(self.server.writes,[])
        answer='$(touch /tmp/never); <b>quoted</b> "'
        self.send(**dict(action,answers={'q1':[answer]}))
        self.assertEqual(self.wait(lambda e:e['type']=='response')['status'],'sent')
        updated=self.wait(lambda e:e['type']=='sessions')
        self.assertEqual(updated['rows'][0]['requestId'],'')
        self.assertEqual(self.server.writes[0]['answers'],{'q1':[answer]})
        self.assertEqual(self.server.writes[0]['type'],'runtime-request.respond')
        self.assertGreater(self.server.pings,0)
        self.stop()
        calls=[json.loads(line) for line in (self.root/'cli.log').read_text().splitlines()]
        self.assertIn('orchestration:operate',calls[0])
        self.assertEqual(calls[-1][:4],['auth','session','revoke','session-1'])
    def test_readonly(self):
        self.start(True)
        self.assertFalse(self.wait(lambda e:e.get('status')=='connected')['canRespond'])
        request=self.wait(lambda e:e['type']=='sessions')['rows'][0]['request']
        self.send(type='respond',threadId='thread-1',requestId='request-1',revision=request['revision'],answers={'q1':['local']})
        self.assertEqual(self.wait(lambda e:e['type']=='response')['status'],'readonly')
        self.assertEqual(self.server.writes,[])
        self.stop();self.assertNotIn('orchestration:operate',(self.root/'cli.log').read_text())

    def test_termination_revokes_credential(self):
        self.start(True)
        self.wait(lambda e:e.get('status')=='connected')
        self.process.terminate()
        self.process.wait(timeout=15)
        self.stop()
        calls=[json.loads(line) for line in (self.root/'cli.log').read_text().splitlines()]
        self.assertEqual(calls[-1][:4],['auth','session','revoke','session-1'])
    def test_disconnect_does_not_retry_a_write(self):
        self.server.drop=True;self.start()
        self.wait(lambda e:e.get('status')=='connected')
        request=self.wait(lambda e:e['type']=='sessions')['rows'][0]['request']
        self.send(type='respond',threadId='thread-1',requestId='request-1',revision=request['revision'],answers={'q1':['local']})
        self.wait(lambda e:e.get('status')=='offline')
        self.wait(lambda e:e.get('status')=='uncertain')
        self.wait(lambda e:e.get('status')=='connected')
        self.assertEqual(len(self.server.writes),1)
    def test_version_guard_before_credentials(self):
        self.server.protocol=3;self.start()
        self.wait(lambda e:e.get('status')=='incompatible')
        self.stop();self.assertFalse((self.root/'cli.log').exists())


if __name__=='__main__': unittest.main()

#!/usr/bin/env python3
"""Offscreen QML forms with a fake bridge; no access to the user's T3 server."""
from session import ensure
ensure()
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

project=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='island-t3-qml-') as temporary:
    root=Path(temporary)
    for name in ('Commons','Ui'):(root/name).symlink_to(Path('/usr/share/omarchy/shell')/name)
    (root/'Island').symlink_to(project/'plugin')
    (root/'shell.qml').write_text((project/'tests/T3.qml').read_text())
    home=root/'home';home.mkdir()
    binary=root/'bin';binary.mkdir()
    fixture={'id':'thread-1','title':'Идеи развития плагина','project':'Island','status':'running','startedAt':0,'finishedAt':0,'summary':'Working',
             'requestId':'request-1','requestKind':'user_input','request':{'id':'request-1','kind':'user_input','revision':'revision-1','canRespond':True,
             'questions':[{'id':'q1','text':'Какой вариант выбираешь для проверки интеграции Island?', 'required':True,'multiSelect':False,'allowCustomAnswer':True,
                           'options':[{'label':'Вариант A','value':'local','description':'Вариант A'}, {'label':'Вариант B','value':'remote','description':'Вариант B'}]}]}}
    (root/'fixture.json').write_text(json.dumps(fixture))
    fake=binary/'python3'
    fake.write_text('#!'+sys.executable+'\n'+'''import sys,os,json
if not sys.argv[1].endswith('/t3-bridge'):
    os.execv(sys.executable,[sys.executable]+sys.argv[1:])
row=json.load(open(os.environ['T3_FIXTURE']))
def send(v):print(json.dumps(v),flush=True)
send({'type':'connection','status':'connected','canRespond':True,'environmentId':'env-1'})
send({'type':'sessions','rows':[row]})
for line in sys.stdin:
    action=json.loads(line)
    with open(os.environ['T3_RESPONSES'],'a') as f:f.write(json.dumps(action)+'\\n')
    send({'type':'response','requestId':action['requestId'],'status':'sent'})
    row.update(requestId='',requestKind='',request=None)
    send({'type':'sessions','rows':[row]})
''')
    fake.chmod(0o755)
    env=dict(os.environ,PATH=str(binary)+os.pathsep+os.environ['PATH'],HOME=str(home),T3CODE_HOME=str(home/'.t3'),
             T3_FIXTURE=str(root/'fixture.json'),T3_RESPONSES=str(root/'responses.jsonl'),QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software')
    result=subprocess.run(['dbus-run-session','--','qs','-p',str(root),'--no-color'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=24)
    print(result.stdout)
    assert 'T3_QML_PASS' in result.stdout and not any(s in result.stdout for s in ['FAIL!', 'T3_QML_FAIL','TypeError:','ReferenceError:','Binding loop','Cannot assign','Unable to assign']),result.stdout
    replies=[json.loads(line) for line in (root/'responses.jsonl').read_text().splitlines()]
    assert len(replies)==1,replies
    assert replies[0]=={'type':'respond','threadId':'thread-1','requestId':'request-2','revision':'revision-2','answers':{'q1':['literal $(touch /tmp/never); <b>']}},replies

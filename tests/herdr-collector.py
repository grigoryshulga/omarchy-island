#!/usr/bin/env python3
"""Read-only CLI fixture, never contacts a real Herdr session."""
import importlib.machinery
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch

project = Path(__file__).resolve().parents[1]
collector = importlib.machinery.SourceFileLoader('herdr_snapshot', str(project / 'plugin/bin/herdr-snapshot')).load_module()
with tempfile.TemporaryDirectory() as temp:
    binary = Path(temp) / 'herdr'
    binary.write_text('#!' + sys.executable + '\n' + '''import json,sys,os
args=sys.argv[1:]
assert 'HERDR_SOCKET' not in os.environ
if args==['session','list','--json']:
 print(json.dumps({'sessions':[{'name':'default','running':True},{'name':'stopped','running':False},{'name':'../bad','running':True}]}))
elif args==['machine','list','--json']:
 print(json.dumps([{'id':'build','label':'Build','session':'default','enabled':True},{'id':'offline','label':'Offline','enabled':True},{'id':'disabled','enabled':False}]))
elif args in [['--session','default','agent','list'],['--machine','build','agent','list']]:
 print(json.dumps({'result':{'agents':[{'pane_id':'w1:p1','name':'$(literal); <title>','agent_status':'blocked'}]}}))
elif args==['invalid']: print('not json')
elif args==['oversize']: print('x' * (2 * 1024 * 1024 + 1))
else: sys.exit(1)
''')
    binary.chmod(0o755)
    with patch.dict(os.environ, PATH=temp + os.pathsep + os.environ['PATH'], HERDR_SOCKET='must-not-leak'):
        for args in (['invalid'], ['oversize']):
            try:
                collector.query(args)
            except ValueError:
                pass
            else:
                raise AssertionError('Invalid metadata must be rejected')
        local = collector.snapshot()
        assert len(local['sources']) == 1
        result = collector.snapshot(True)
        assert len(result['sources']) == 3
        assert [s['status'] for s in result['sources']] == ['connected','connected','unavailable']
        assert result['sources'][0]['rows'][0]['id'] != result['sources'][1]['rows'][0]['id']
        assert result['sources'][0]['rows'][0]['title'] == '$(literal); <title>'
    with patch.object(collector, 'query', side_effect=ValueError('protocol')):
        assert all(s['status'] == 'unavailable' for s in collector.snapshot(True)['sources'])
collector.stopping.set()
try:
    collector.query(['must-not-start'])
except OSError:
    pass
else:
    raise AssertionError('Shutdown must prevent queued queries')
print('PASS: Herdr local/remote CLI routing, isolated failures and inert metadata')

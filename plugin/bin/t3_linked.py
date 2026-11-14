"""Read Linked environments through the local T3 MCP gateway, never peer secrets."""
import http.client
import json
import queue
import threading
import uuid

from t3_cli import CliError
from t3_model import BUSY, identifier, select_threads, session_view, text
from t3_transport import local_origin, TransportError

INTERVAL = 10
MAX_ENVIRONMENTS = 8


class McpClient:
    def __init__(self, origin, token):
        self.origin, self.token, self.session = origin, token, ''

    def post(self, method, params=None, notification=False):
        host, port = local_origin(self.origin)
        connection = http.client.HTTPConnection(host, port, timeout=5)
        headers = {'Authorization': 'Bearer ' + self.token,
                   'Content-Type': 'application/json',
                   'Accept': 'application/json, text/event-stream',
                   'mcp-protocol-version': '2025-06-18'}
        if self.session:
            headers['mcp-session-id'] = self.session
        body = {'jsonrpc': '2.0', 'method': method}
        if not notification:
            body['id'] = str(uuid.uuid4())
        if params is not None:
            body['params'] = params
        try:
            connection.request('POST', '/mcp', json.dumps(body), headers)
            response = connection.getresponse()
            if response.status not in (200, 202):
                self.session = ''
                raise TransportError('linked')
            raw = response.read(4194305)
            if len(raw) > 4194304:
                raise TransportError('oversized')
            if notification:
                return None
            if method == 'initialize':
                self.session = response.getheader('mcp-session-id', '')
                if not self.session:
                    raise TransportError('linked')
            if 'text/event-stream' in response.getheader('Content-Type', ''):
                raw = '\n'.join(line[5:].strip() for line in raw.decode().splitlines()
                                if line.startswith('data:')).encode()
            value = json.loads(raw)
            if 'error' in value or value.get('id') != body['id']:
                raise TransportError('linked')
            return value['result']
        except http.client.HTTPException as error:
            raise TransportError('linked') from error
        finally:
            connection.close()

    def call(self, name, arguments):
        if not self.session:
            self.post('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                                    'clientInfo': {'name': 'omarchy-island', 'version': '1'}})
            self.post('notifications/initialized', notification=True)
        result = self.post('tools/call', {'name': name, 'arguments': arguments})
        if result.get('isError'):
            raise TransportError('linked')
        value = result.get('structuredContent')
        if value is None:
            value = json.loads(next(item['text'] for item in result.get('content', [])
                                    if item.get('type') == 'text'))
        if not isinstance(value, dict):
            raise TransportError('linked')
        return value


class LinkedMonitor:
    def __init__(self, base, cli, origin, environment):
        self.base, self.cli = base, cli
        self.origin, self.environment = origin, environment
        self.stopped = threading.Event()
        self.updates = queue.Queue(maxsize=1)
        self.thread = threading.Thread(target=self.run, daemon=True)

    def start(self):
        self.thread.start()

    def close(self):
        self.stopped.set()
        # A bounded CLI issue/revoke (12s each) or an HTTP read (5s) can be in flight.
        self.thread.join(timeout=26)

    def call(self, name, **args):
        if self.stopped.is_set():
            raise TransportError('stopped')
        return self.client.call(name, args)

    def pages(self, name, key, **args):
        result, cursor = [], 0
        for _ in range(5):
            page = self.call(name, cursor=cursor, limit=100, **args)
            result.extend(page[key][:100])
            following = page.get('nextCursor')
            if not isinstance(following, int) or following <= cursor:
                break
            cursor = following
        return result

    def collect(self):
        links = self.call('t3_environment_links').get('links', [])
        rows, available = [], set()
        for link in links[:MAX_ENVIRONMENTS]:
            env = link.get('environmentId')
            if not identifier(env) or env == self.environment or link.get('status') != 'reachable':
                continue
            try:
                projects = self.pages('t3_project_list', 'projects', environmentId=env)
                titles = {p['id']: p.get('title', '') for p in projects}
                icons = {p['id']: p.get('projectIcon') for p in projects}
                threads = self.pages('t3_thread_list', 'threads', environmentId=env,
                                     allProjects=True, includeSubagents=False, settled=False)
                candidates = [dict(t, id=t['threadId'],
                                   settledOverride='settled' if t.get('settled') else None,
                                   lineage={'relationshipToParent': t.get('relationshipToParent')})
                              for t in threads if identifier(t.get('threadId'))]
                sessions = []
                for thread in select_threads(candidates):
                    detail = self.call('t3_thread_read', environmentId=env,
                                       threadId=thread['id'], beforePosition=2147483647,
                                       limit=1, runLimit=1, maxCharsPerItem=2048)
                    state = detail['thread']
                    if state.get('archived') or state.get('settled'):
                        continue
                    runs = detail.get('recentRuns', [])
                    run = next((r for r in runs if r.get('runId') == state.get('activeRunId')),
                               runs[-1] if runs else {})
                    thread.update(latestRunStartedAt=run.get('startedAt'),
                                  latestRunCompletedAt=run.get('completedAt'))
                    row = session_view(thread, titles, project_icons=icons)
                    row.update(id='linked/' + env + '/' + thread['id'],
                               environmentId=env, threadId=thread['id'])
                    if state.get('pendingRequestCount', 0) > 0:
                        row.update(requestId=row['id'] + '/pending', requestKind='unknown')
                    row['project'] = text(link.get('label'), 128) + ' / ' + row['project']
                    items = detail.get('items', [])
                    if items:
                        row['summary'] = text(items[-1].get('text'))
                    sessions.append(row)
                rows.extend(sessions)
                available.add(env)
            except (OSError, ValueError, KeyError, TypeError, StopIteration, TransportError):
                # Remove stale cards from this source; other sources remain independent.
                continue
        return rows, available

    def run(self):
        credential = None
        previous = set()
        try:
            while not self.stopped.is_set() and credential is None:
                try:
                    credential = json.loads(self.cli.auth(self.base, 'issue', '--scope', 'orchestration:read',
                        '--subject', 'mcp-client', '--ttl', '1h', '--label', 'Omarchy Island linked', '--json'))
                except (OSError, ValueError, CliError):
                    if self.stopped.wait(INTERVAL):
                        return
            if credential is None:
                return
            self.client = McpClient(self.origin, credential['token'])
            while not self.stopped.is_set():
                try:
                    rows, available = self.collect()
                except (OSError, ValueError, KeyError, TypeError, StopIteration, TransportError):
                    rows, available = [], set()
                baseline = [r['id'] for r in rows if r['environmentId'] not in previous]
                previous = available
                try:
                    self.updates.get_nowait()
                except queue.Empty:
                    pass
                self.updates.put_nowait((rows, baseline))
                if self.stopped.wait(INTERVAL):
                    break
        except (OSError, ValueError, KeyError, CliError):
            pass  # Local sessions still work when the MCP gateway is unavailable.
        finally:
            if credential:
                try:
                    self.cli.auth(self.base, 'revoke', credential['sessionId'])
                except (OSError, CliError):
                    pass


def merge_sessions(local, linked):
    rows = local + linked
    rows.sort(key=lambda r: (0 if r['requestId'] else 1 if r['status'] in BUSY else 2,
                             -r.get('updatedAt', 0), r['id']))
    return rows[:30]

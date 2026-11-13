#!/usr/bin/env python3
"""Real ICS library, private storage and HTTP policy tests; no account/network."""
from session import ensure
ensure()
import base64
import datetime as dt
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from zoneinfo import ZoneInfo

project = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project / 'plugin/bin'))
import calendar_ics as ics
loader = importlib.machinery.SourceFileLoader('calendar_data', str(project / 'plugin/bin/calendar-data'))
spec = importlib.util.spec_from_loader(loader.name, loader)
data = importlib.util.module_from_spec(spec)
loader.exec_module(data)
RAW = (project / 'tests/fixtures/calendar.ics').read_bytes()
ZONE = ZoneInfo('Europe/Berlin')


class CalendarTests(unittest.TestCase):
    def test_recurrence_dst_exceptions_and_dates(self):
        events = ics.expand(RAW, 2026, ZONE)
        daily = [e for e in events if e['title'] in ('Daily', 'Moved meeting')]
        self.assertEqual([e['startDay'] for e in daily], ['2026-03-27', '2026-03-29', '2026-03-30'])
        self.assertEqual(dt.datetime.fromtimestamp(daily[1]['start'], dt.timezone.utc).hour, 7)
        self.assertEqual(dt.datetime.fromtimestamp(daily[2]['start'], ZONE).hour, 14)
        holiday = next(e for e in events if e['title'] == 'Three days')
        self.assertEqual((holiday['startDay'], holiday['endDay'], holiday['allDay']), ('2026-03-28', '2026-03-30', True))
        overnight = next(e for e in events if e['title'] == 'Overnight')
        self.assertEqual((overnight['startDay'], overnight['endDay']), ('2026-03-28', '2026-03-29'))
        floating = next(e for e in events if e['title'].startswith('<img'))
        self.assertEqual(dt.datetime.fromtimestamp(floating['start'], ZONE).hour, 12)
        self.assertIn('$(date)', floating['title'])
        self.assertEqual(next(e for e in events if e['title'] == 'Across years')['endDay'], '2026-01-02')
        self.assertFalse(any(e['title'] == 'Cancelled meeting' for e in events))

    def test_exclusive_midnight_and_point_event(self):
        raw = b'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:point\nDTSTART:20260329T120000Z\nSUMMARY:Point\nEND:VEVENT\nBEGIN:VEVENT\nUID:midnight\nDTSTART:20260328T210000Z\nDTEND:20260328T230000Z\nSUMMARY:Until midnight\nEND:VEVENT\nEND:VCALENDAR'
        events = ics.expand(raw, 2026, ZONE)
        self.assertEqual(next(e for e in events if e['title'] == 'Until midnight')['endDay'], '2026-03-28')
        point = next(e for e in events if e['title'] == 'Point')
        self.assertEqual(point['start'], point['end'])

    def test_limits_and_invalid_data(self):
        for raw in (b'<html>login</html>', b'x' * (ics.MAX_BYTES + 1)):
            with self.assertRaises(ics.CalendarError):
                ics.expand(raw, 2026, ZONE)
        raw = b'BEGIN:VCALENDAR\nVERSION:2.0\nBEGIN:VEVENT\nUID:spam\nDTSTART:20260101T000000Z\nRRULE:FREQ=SECONDLY\nEND:VEVENT\nEND:VCALENDAR'
        with self.assertRaises(ics.CalendarError) as failure:
            ics.deadline(5, lambda: ics.expand(raw, 2026, ZONE))
        self.assertEqual(failure.exception.code, 'limit')

    def test_url_policy_and_private_dns(self):
        self.assertEqual(ics.safe_url('webcal://EXAMPLE.com:443/cal.ics?a=1'), 'https://example.com/cal.ics?a=1')
        for url in ['http://example.com/a', 'file:///etc/passwd', 'https://localhost/a', 'https://127.0.0.1/a', 'https://user:secret@example.com/a', 'https://example.com:123/a', 'https://example.com/a#fragment', 'https://example.com/%250a', 'https://example.com/\n']:
            with self.subTest(url=url), self.assertRaises(ics.CalendarError):
                ics.safe_url(url)
        for ip in ('127.0.0.1', '10.0.0.1', '169.254.169.254', '::1', 'fc00::1'):
            with patch.object(socket, 'getaddrinfo', return_value=[(socket.AF_INET, socket.SOCK_STREAM, 6, '', (ip, 443))]), self.assertRaises(ics.CalendarError):
                ics.PublicHTTPSConnection('example.com').connect()

    def test_redirect_and_conditional_request(self):
        class Response:
            def __init__(self, status, headers=None, raw=b''):
                self.status, self.headers, self.raw = status, headers or {}, raw
            def getheader(self, name, default=None): return self.headers.get(name, default)
            def read(self, length): return self.raw[:length]
        calls, responses = [], []
        class Connection:
            def __init__(self, host, **kwargs): self.host = host
            def request(self, method, path, headers): calls.append((self.host, path, dict(headers)))
            def getresponse(self): return responses.pop(0)
            def close(self): pass
        with patch.object(ics, 'PublicHTTPSConnection', Connection):
            responses[:] = [Response(304)]
            self.assertIsNone(ics.fetch('https://example.com/a', {'raw': 'cached', 'etag': 'version'})[0])
            self.assertEqual(calls[-1][2]['If-None-Match'], 'version')
            responses[:] = [Response(302, {'Location': 'http://example.com/plain'})]
            with self.assertRaises(ics.CalendarError): ics.fetch('https://example.com/a', {})
            responses[:] = [Response(302, {'Location': 'https://other.example.com/b'}), Response(200, raw=RAW)]
            self.assertEqual(ics.fetch('https://example.com/a', {'etag': 'private'})[0], RAW)
            self.assertNotIn('If-None-Match', calls[-1][2])
            responses[:] = [Response(200, raw=b'x' * (ics.MAX_BYTES + 1))]
            with self.assertRaises(ics.CalendarError): ics.fetch('https://example.com/a', {})

    def test_private_state_cache_failure_toggle_remove(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(data, 'ROOT', Path(temp) / 'calendars'), patch.object(data, 'deadline', side_effect=lambda seconds, operation: operation()):
            # Exercise worker logic in process here so a fake transport can be injected.
            with patch.object(data, 'run_worker', side_effect=lambda source, year, refresh: data.worker(dict(source=source, year=year, refresh=refresh))), patch.object(data, 'fetch', return_value=(RAW, 'etag', 'modified')) as fetch:
                report = data.operate(dict(command='add', name='My calendar', url='https://example.com/private-token/basic.ics', year=2026))
                self.assertTrue(report['events'])
                source = report['sources'][0]
                self.assertNotIn('private-token', json.dumps(report))
                self.assertEqual(data.ROOT.stat().st_mode & 0o777, 0o700)
                for path in data.ROOT.iterdir(): self.assertEqual(path.stat().st_mode & 0o777, 0o600)
                data.operate(dict(year=2026));self.assertEqual(fetch.call_count, 1)
                with patch.object(data, 'fetch', side_effect=ics.CalendarError('network')):
                    stale = data.operate(dict(year=2026, refresh=True))
                self.assertEqual(stale['events'], report['events'])
                self.assertEqual(stale['sources'][0]['error'], 'network')
                self.assertEqual(data.operate(dict(year=2026))['sources'][0]['error'], 'network')
                with patch.object(data, 'fetch', return_value=(b'<html>broken</html>', '', '')):
                    invalid = data.operate(dict(year=2026, refresh=True))
                self.assertEqual(invalid['events'], report['events'])
                with self.assertRaises(ics.CalendarError):
                    data.operate(dict(command='add', name='Duplicate', url='https://example.com/private-token/basic.ics', year=2026))
                off = data.operate(dict(command='toggle', id=source['id'], enabled=False, year=2026))
                self.assertEqual(off['events'], [])
                self.assertFalse(off['sources'][0]['enabled'])
                removed = data.operate(dict(command='remove', id=source['id'], year=2026))
                self.assertEqual(removed['sources'], [])
                self.assertFalse((data.ROOT / (source['id'] + '.json')).exists())

    def test_real_helper_and_vendored_dependencies(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'omarchy/island/calendars';root.mkdir(parents=True)
            source = dict(id='a' * 32, name='Fixture', enabled=True, url='https://example.com/secret')
            data.write_json(root / 'sources.json', [source])
            data.write_json(root / (source['id'] + '.json'), dict(raw=base64.b64encode(RAW).decode(), fetchedAt=int(time.time())))
            process = subprocess.run([sys.executable, '-S', str(project / 'plugin/bin/calendar-data')], input=json.dumps(dict(year=2026)), text=True, capture_output=True, env=dict(os.environ, XDG_STATE_HOME=temp), timeout=10)
            self.assertEqual(process.returncode, 0, process.stderr)
            report = json.loads(process.stdout)
            self.assertTrue(report['events'], report)
            self.assertNotIn('secret', process.stdout + process.stderr)


if __name__ == '__main__':
    unittest.main()

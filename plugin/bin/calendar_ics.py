"""Bounded ICS transport and recurrence expansion; no shell or event actions."""
import datetime as dt
import hashlib
import http.client
import ipaddress
import re
import signal
import socket
import ssl
import sys
import time
from pathlib import Path
from urllib.parse import urlsplit, urljoin
from zoneinfo import ZoneInfo

MAX_BYTES = 2 * 1024 * 1024
MAX_EVENTS = 2000


class CalendarError(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)  # Never include a URL or downloaded text.


def safe_url(raw):
    if not isinstance(raw, str) or len(raw) > 4096:
        raise CalendarError('url')
    if raw.lower().startswith('webcal://'):
        raw = 'https://' + raw[9:]
    if re.search(r'''[\x00-\x20\x7f-\x9f\\<>"']''', raw) or re.search(r'%(?:0[0-9a-f]|1[0-9a-f]|7f|25|5c)|%(?![0-9a-f]{2})', raw, re.I):
        raise CalendarError('url')
    try:
        parts = urlsplit(raw)
        host = (parts.hostname or '').lower().rstrip('.')
        if parts.scheme != 'https' or parts.username is not None or parts.password is not None or '#' in raw or parts.port not in (None, 443) or not re.fullmatch(r'[^:%@]+(?::[0-9]{1,5})?', parts.netloc):
            raise ValueError()
        if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+', host) or len(host) > 253:
            raise ValueError()
        if re.fullmatch(r'(?:0x[0-9a-f]*|[0-9]+)', host.split('.')[-1], re.I):
            raise ValueError()
    except ValueError:
        raise CalendarError('url') from None
    return 'https://' + host + (parts.path or '/') + ('?' + parts.query if parts.query else '')


class PublicHTTPSConnection(http.client.HTTPSConnection):
    def connect(self):
        # Resolve once, reject private endpoints, then pin the connection to that
        # address while retaining hostname verification and TLS SNI.
        addresses = socket.getaddrinfo(self.host, self.port, type=socket.SOCK_STREAM)
        if not addresses or any(not ipaddress.ip_address(a[4][0]).is_global for a in addresses):
            raise CalendarError('url')
        last = None
        for _, _, _, _, address in addresses:
            try:
                sock = socket.create_connection((address[0], self.port), self.timeout)
                try:
                    self.sock = self._context.wrap_socket(sock, server_hostname=self.host)
                except Exception:
                    sock.close()
                    raise
                return
            except OSError as error:
                last = error
        raise last or CalendarError('network')


def fetch(url, cache):
    url = safe_url(url)
    headers = {'User-Agent': 'Omarchy-Island/1.0', 'Accept': 'text/calendar', 'Accept-Encoding': 'identity'}
    for field, header in [('etag', 'If-None-Match'), ('modified', 'If-Modified-Since')]:
        value = cache.get(field, '')
        if isinstance(value, str) and len(value) <= 512 and not re.search(r'[\x00-\x1f\x7f]', value):
            if value:
                headers[header] = value
    for redirects in range(4):
        parts = urlsplit(url)
        connection = PublicHTTPSConnection(parts.hostname, timeout=6, context=ssl.create_default_context())
        try:
            connection.request('GET', parts.path + ('?' + parts.query if parts.query else ''), headers=headers)
            response = connection.getresponse()
            if response.status in (301, 302, 303, 307, 308):
                if redirects == 3:
                    raise CalendarError('network')
                target = safe_url(urljoin(url, response.getheader('Location', '')))
                if urlsplit(target).hostname != parts.hostname:
                    headers.pop('If-None-Match', None)
                    headers.pop('If-Modified-Since', None)
                url = target
                continue
            if response.status == 304 and cache.get('raw'):
                return None, cache.get('etag', ''), cache.get('modified', '')
            if response.status != 200:
                raise CalendarError('network')
            if response.getheader('Content-Encoding', 'identity').lower() != 'identity':
                raise CalendarError('invalid')
            raw = response.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES:
                raise CalendarError('limit')
            return raw, response.getheader('ETag', '')[:512], response.getheader('Last-Modified', '')[:512]
        finally:
            connection.close()
    raise CalendarError('network')


def local_zone():
    # Unlike datetime.now().astimezone().tzinfo, this preserves DST transitions.
    with open('/etc/localtime', 'rb') as stream:
        return ZoneInfo.from_file(stream)


def load_libraries():
    vendor = Path(__file__).resolve().parents[1] / 'vendor/calendar'
    sys.path[:0] = [str(path) for path in sorted(vendor.glob('*.whl'))]
    import icalendar
    import recurring_ical_events
    return icalendar, recurring_ical_events


def expand(raw, year, timezone=None):
    if not isinstance(raw, bytes) or len(raw) > MAX_BYTES:
        raise CalendarError('limit')
    icalendar, recurring = load_libraries()
    zone = timezone or local_zone()
    start = dt.datetime(year, 1, 1, tzinfo=zone)
    end = dt.datetime(year + 1, 1, 1, tzinfo=zone)
    if year > 1:
        start -= dt.timedelta(days=7)
    if year < 9998:
        end += dt.timedelta(days=7)
    try:
        calendar = icalendar.Calendar.from_ical(raw)
        if calendar.name != 'VCALENDAR' or not calendar.get('VERSION'):
            raise CalendarError('invalid')
        query = recurring.of(calendar)
        events = []
        # after() is lazy; never materialize an unbounded SECONDLY recurrence.
        for event in query.after(start):
            beginning = event.decoded('DTSTART')
            ending = event.decoded('DTEND', None)
            all_day = not isinstance(beginning, dt.datetime)
            if ending is None:
                ending = beginning + event.decoded('DURATION', dt.timedelta(days=1 if all_day else 0))
            if all_day:
                first = dt.datetime.combine(beginning, dt.time(), zone)
                last = dt.datetime.combine(ending, dt.time(), zone)
            else:
                first = beginning.replace(tzinfo=zone) if beginning.tzinfo is None else beginning.astimezone(zone)
                last = ending.replace(tzinfo=zone) if ending.tzinfo is None else ending.astimezone(zone)
            if first >= end:
                break
            if str(event.get('STATUS', '')).upper() == 'CANCELLED':
                continue
            if last < first:
                raise CalendarError('invalid')
            if last <= start and first < start:
                continue
            first_day = max(first, start).date().isoformat()
            last_day = min(max(first, last - dt.timedelta(microseconds=1)), end - dt.timedelta(microseconds=1)).date().isoformat()
            uid = str(event.get('UID', ''))
            events.append({'id': hashlib.sha256((uid + first.isoformat()).encode()).hexdigest()[:24],
                           'title': str(event.get('SUMMARY', ''))[:512], 'location': str(event.get('LOCATION', ''))[:512],
                           'allDay': all_day, 'start': first.timestamp(), 'end': last.timestamp(),
                           'startDay': first_day, 'endDay': last_day})
            if len(events) > MAX_EVENTS:
                raise CalendarError('limit')
        return events
    except CalendarError:
        raise
    except Exception:
        raise CalendarError('invalid') from None


def deadline(seconds, operation):
    def expired(signum, frame):
        raise CalendarError('limit')
    old = signal.signal(signal.SIGALRM, expired)
    signal.alarm(seconds)
    try:
        return operation()
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)

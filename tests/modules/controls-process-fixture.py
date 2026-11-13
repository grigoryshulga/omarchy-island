#!/usr/bin/env python3
"""Long-lived fake Controls command, with observable starts and stops."""
import json
import os
from pathlib import Path
import signal
import sys
import time

log = Path(os.environ['ISLAND_MODULE_STORAGE']) / 'controls.jsonl'


def record(event):
    with log.open('a') as output:
        output.write(json.dumps({'event': event, 'role': sys.argv[1], 'pid': os.getpid()}) + '\n')


def stop(*args):
    record('stop')
    raise SystemExit(0)


signal.signal(signal.SIGTERM, stop)
record('start')
print('test-output' if sys.argv[1] == 'output' else '{"BackendState":"Running"}', flush=True)
while True:
    time.sleep(1)

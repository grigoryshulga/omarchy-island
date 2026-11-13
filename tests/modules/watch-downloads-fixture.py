#!/usr/bin/python3
"""A long-lived watcher fixture; records exact starts/stops without desktop I/O."""
import json
import os
from pathlib import Path
import signal
import sys
import time

log = Path(os.environ['ISLAND_MODULE_STORAGE']) / 'watcher.jsonl'
def record(event):
    with log.open('a') as output:
        output.write(json.dumps({'event':event,'pid':os.getpid()})+'\n')
def stop(*args):
    record('stop')
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
record('start')
print(json.dumps({'event':'active','files':[{'path':sys.argv[1]+'/fixture.zip.part','bytes':10}]}),flush=True)
while True:
    time.sleep(1)

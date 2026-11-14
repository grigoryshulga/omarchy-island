"""Codex local control socket: RFC 6455 over a same-user Unix socket."""
import os
from pathlib import Path
import socket
import stat
import struct
from t3_transport import WebSocket, TransportError


class CodexSocket(WebSocket):
    def __init__(self):
        home = Path(os.environ.get('CODEX_HOME', str(Path.home()/'.codex')))
        path = home/'app-server-control'/'app-server-control.sock'
        if path.lstat().st_uid != os.getuid():
            raise TransportError('socket')
        info = path.stat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
            raise TransportError('socket')
        self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.socket.settimeout(5)
        try:
            self.socket.connect(str(path.resolve()))
            # Codex uses an owned symlink when the control socket path is long.
            _, uid, _ = struct.unpack('3i', self.socket.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
            if uid != os.getuid():
                raise TransportError('peer')
            self.handshake('localhost', '/')
        except Exception:
            self.socket.close()
            raise

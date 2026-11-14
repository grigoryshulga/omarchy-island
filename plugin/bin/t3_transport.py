"""Local HTTP and RFC 6455 transport; no third-party Python or Node dependency.

The bridge only connects to literal loopback addresses. No extensions/compression
are negotiated. Frame/message bounds apply before allocating a payload.
"""
import base64
import hashlib
import http.client
import ipaddress
import json
import os
import socket
import struct
from urllib.parse import urlsplit

MAX_MESSAGE = 16 * 1024 * 1024


class TransportError(Exception):
    pass


def local_origin(origin):
    if not isinstance(origin, str) or len(origin) > 256:
        raise TransportError("origin")
    try:
        url = urlsplit(origin)
        host = ipaddress.ip_address(url.hostname or "")
        port = url.port
        if (url.scheme != "http" or not host.is_loopback or not port or url.username is not None
                or url.password is not None or url.path not in ("", "/") or url.query or url.fragment):
            raise ValueError()
        return url.hostname, port
    except ValueError as error:
        raise TransportError("origin") from error


def http_json(origin, path, token=None, method="GET"):
    host, port = local_origin(origin)
    connection = http.client.HTTPConnection(host, port, timeout=5)
    headers = {"x-t3-orchestration-protocol": "2", "Accept": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    try:
        connection.request(method, path, headers=headers)
        response = connection.getresponse()
        if response.status != 200:
            raise TransportError("auth" if response.status in (401, 403) else "incompatible" if response.status == 426 else "request")
        body = response.read(MAX_MESSAGE + 1)
        if len(body) > MAX_MESSAGE:
            raise TransportError("oversized")
        return json.loads(body)
    except http.client.HTTPException as error:
        raise TransportError("request") from error
    finally:
        connection.close()


class WebSocket:
    def __init__(self, origin, path):
        host, port = local_origin(origin)
        self.socket = socket.create_connection((host, port), timeout=5)
        self.buffer = bytearray()
        self.fragments = bytearray()
        self.fragmented = False
        key = base64.b64encode(os.urandom(16)).decode()
        authority = f"[{host}]:{port}" if ":" in host else f"{host}:{port}"
        try:
            self.socket.sendall((f"GET {path} HTTP/1.1\r\nHost: {authority}\r\nUpgrade: websocket\r\n"
                                 f"Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: {key}\r\n\r\n").encode())
            while b"\r\n\r\n" not in self.buffer:
                data = self.socket.recv(4096)
                if not data or len(self.buffer) > 32768:
                    raise TransportError("handshake")
                self.buffer.extend(data)
            header, rest = bytes(self.buffer).split(b"\r\n\r\n", 1)
            lines = header.decode("ascii").split("\r\n")
            fields = {k.lower(): v.strip() for k, v in (line.split(":", 1) for line in lines[1:])}
            expected = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
            if (lines[0].split()[1] != "101" or fields.get("sec-websocket-accept") != expected
                    or fields.get("upgrade", "").lower() != "websocket" or "sec-websocket-extensions" in fields):
                raise TransportError("handshake")
            self.buffer = bytearray(rest)
            self.socket.settimeout(0.2)
        except Exception:
            self.socket.close()
            raise

    def send_frame(self, payload, opcode=1):
        if len(payload) > MAX_MESSAGE:
            raise TransportError("oversized")
        size = len(payload)
        prefix = bytes([0x80 | opcode])
        prefix += bytes([0x80 | size]) if size < 126 else bytes([0x80 | 126]) + struct.pack("!H", size) if size < 65536 else bytes([0x80 | 127]) + struct.pack("!Q", size)
        mask = os.urandom(4)
        self.socket.sendall(prefix + mask + bytes(v ^ mask[i % 4] for i, v in enumerate(payload)))

    def send(self, value):
        self.send_frame(json.dumps(value, separators=(",", ":")).encode())

    def receive(self):
        while True:
            if len(self.buffer) >= 2:
                first, second = self.buffer[:2]
                final, opcode, size = bool(first & 128), first & 15, second & 127
                offset = 2 + (2 if size == 126 else 8 if size == 127 else 0)
                if first & 0x70 or second & 0x80 or opcode not in (0, 1, 8, 9, 10):
                    raise TransportError("frame")
                if len(self.buffer) >= offset:
                    if size == 126:
                        size = struct.unpack("!H", self.buffer[2:4])[0]
                    elif size == 127:
                        size = struct.unpack("!Q", self.buffer[2:10])[0]
                    if size > MAX_MESSAGE or len(self.fragments) + size > MAX_MESSAGE:
                        raise TransportError("oversized")
                    if opcode >= 8 and (not final or size > 125):
                        raise TransportError("frame")
                    if len(self.buffer) >= offset + size:
                        payload = bytes(self.buffer[offset:offset + size])
                        del self.buffer[:offset + size]
                        if opcode == 8:
                            raise TransportError("closed")
                        if opcode == 9:
                            self.send_frame(payload, 10)
                            continue
                        if opcode == 10:
                            continue
                        if (opcode == 0) != self.fragmented:
                            raise TransportError("fragment")
                        self.fragments.extend(payload)
                        self.fragmented = not final
                        if not final:
                            continue
                        message = bytes(self.fragments)
                        self.fragments.clear()
                        return json.loads(message)
            try:
                data = self.socket.recv(65536)
            except socket.timeout:
                return None
            if not data:
                raise TransportError("closed")
            self.buffer.extend(data)

    def close(self):
        self.socket.close()

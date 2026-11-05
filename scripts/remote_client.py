"""A FIGURE remote-mode client for tests: speaks the protocol of native/figure_remote.cpp without a browser.

Run by src/tests/figure_test_remote.F90 against the program's server. Checks, in order:
  - GET /?token=TOKEN serves the client page; without the token or with a wrong one, the page and the WebSocket are
    refused (403);
  - the WebSocket handshake (RFC 6455): status 101 and the Sec-WebSocket-Accept of our key;
  - every message parses to its exact length: the background (r, g, b in [0, 1]), before any frame; textures
    (id, size, flags, width x height x 4 RGBA bytes) and frames
    (draw lists of 12-byte or 20-byte vertices, 16-bit indices, commands; deflated messages inflated first: the test
    program deflates everything), and draw commands reference received textures and
    vertices only (each command's indices count from its vertex offset);
  - a draw list over 65536 vertices arrives (the program draws a long line) and stays within those bounds; then the
    client presses Z and the program drops the line;
  - a size event ("s:640,480") comes back as the display size of a later frame;
  - then, nothing changing, no frame is sent again for 2.5 s, only "unchanged" messages (at least one);
  - then the pointer toggles the button's hover 200 times per second: frames keep coming, at most 75 per second
    (the program caps them at 60);
  - a click (mouse move, press, release) at the point the program writes to CLICK_FILE, and a frame after it (the
    button's hover changed what is drawn).
Writes "ok" to OK_FILE when every check passed, else the first failure; exits 0 or 1.

Usage: python3 scripts/remote_client.py PORT CLICK_FILE OK_FILE [TOKEN]
Standard library only (Python >= 3.11).
"""

from __future__ import annotations

import base64
import hashlib
import os
import socket
import struct
import sys
import threading
import time
import zlib
from pathlib import Path

GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
TIMEOUT = 30.0
QUIET = (1.0, 3.5)  # seconds after the resize in which the idle interface must send no frame, only "unchanged"
PACE = (0.3, 1.3)  # seconds after the pointer starts toggling the button's hover in which frames are counted
MAX_FPS = 75  # frames per second allowed then (the program's cap is 60)


class ProtocolError(Exception):
    """The server broke the protocol or a check failed."""


def connect(port: int) -> socket.socket:
    """Connect to the server, retrying while it starts."""
    end = time.monotonic() + 10.0
    while True:
        try:
            return socket.create_connection(("127.0.0.1", port), timeout=TIMEOUT)
        except OSError as err:
            if time.monotonic() > end:
                msg = f"cannot connect to port {port}: {err}"
                raise ProtocolError(msg) from err
            time.sleep(0.1)


def read_until(s: socket.socket, marker: bytes) -> bytes:
    """Read until `marker`, return everything read."""
    data = b""
    while marker not in data:
        chunk = s.recv(4096)
        if not chunk:
            msg = "connection closed during the HTTP exchange"
            raise ProtocolError(msg)
        data += chunk
    return data


def http_get(port: int, target: str, headers: str = "") -> bytes:
    """One HTTP GET; the whole answer (the server closes the connection)."""
    with connect(port) as s:
        s.sendall(f"GET {target} HTTP/1.1\r\nHost: localhost\r\n{headers}\r\n".encode())
        data = b""
        while chunk := s.recv(65536):
            data += chunk
    return data


def check_page(port: int, token: str) -> None:
    """GET /?token= must answer the client page; without the token, or with a wrong one, 403 (page and WebSocket)."""
    data = http_get(port, f"/?token={token}" if token else "/")
    if not data.startswith(b"HTTP/1.1 200") or b"FIGURE remote" not in data:
        msg = "GET / did not serve the client page"
        raise ProtocolError(msg)
    if not token:
        return
    upgrade = "Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
    upgrade += "Sec-WebSocket-Version: 13\r\n"
    wrong = ("1" if token[0] == "0" else "0") + token[1:]  # differs from the token in its first character
    for target, headers in (("/", ""), ("/?token=" + wrong, ""), ("/index.html?x=1", ""), ("/ws", upgrade),
                            ("/ws?token=" + token[:-1], upgrade)):
        if not http_get(port, target, headers).startswith(b"HTTP/1.1 403"):
            msg = f"GET {target} without the right token was not refused"
            raise ProtocolError(msg)


class WebSocket:
    """A minimal WebSocket client: masked text frames out, binary frames in."""

    def __init__(self, port: int, token: str = "") -> None:
        self.s = connect(port)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall(
            (
                f"GET /ws{'?token=' + token if token else ''} HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
            ).encode()
        )
        head = read_until(self.s, b"\r\n\r\n")
        self.buf = head[head.index(b"\r\n\r\n") + 4 :]
        expected = base64.b64encode(
            hashlib.sha1((key + GUID).encode()).digest()
        ).decode()  # noqa: S324 (RFC 6455)
        if (
            not head.startswith(b"HTTP/1.1 101")
            or f"Sec-WebSocket-Accept: {expected}".encode() not in head
        ):
            msg = "bad WebSocket handshake"
            raise ProtocolError(msg)

    def send(self, text: str) -> None:
        """Send one masked text frame."""
        payload = text.encode()
        mask = os.urandom(4)
        header = bytes([0x81, 0x80 | len(payload)]) if len(payload) < 126 else None
        if header is None:
            msg = "event too long"
            raise ProtocolError(msg)
        self.s.sendall(
            header + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        )

    def _need(self, n: int) -> None:
        while len(self.buf) < n:
            chunk = self.s.recv(1 << 20)
            if not chunk:
                raise EOFError
            self.buf += chunk

    def recv(self) -> bytes:
        """Receive one message (binary payload); EOFError when the server closes."""
        self._need(2)
        opcode, n = self.buf[0] & 0x0F, self.buf[1] & 0x7F
        pos = 2
        if n == 126:
            self._need(4)
            n, pos = struct.unpack(">H", self.buf[2:4])[0], 4
        elif n == 127:
            self._need(10)
            n, pos = struct.unpack(">Q", self.buf[2:10])[0], 10
        self._need(pos + n)
        payload, self.buf = self.buf[pos : pos + n], self.buf[pos + n :]
        if opcode == 0x8:
            raise EOFError
        return payload


big_lists: set[bool] = set()  # whether a draw list over 65536 vertices was seen (True), one at most (False)
compact_lists: set[bool] = set()  # whether a list with 12-byte vertices was seen
deflated: list[int] = [0]  # deflated messages received


def parse_frame(m: bytes, textures: set[int]) -> tuple[float, float]:
    """Parse a frame message exactly; return the display size."""
    w, h, nlists = struct.unpack_from("<ffI", m, 1)
    p = 13
    for _ in range(nlists):
        nv, ni, nc, flags = struct.unpack_from("<IIII", m, p)
        stride = 12 if flags & 1 else 20
        if flags & 1:
            compact_lists.add(True)
        ip = p + 16 + nv * stride  # the list's indices
        p += 16 + nv * stride + ni * 2 + (ni % 2) * 2
        for _ in range(nc):
            tex, off, count, vtx = struct.unpack_from("<IIII", m, p + 16)
            if tex not in textures:
                msg = f"draw command uses texture {tex}, never received"
                raise ProtocolError(msg)
            if off + count > ni or count % 3:
                msg = "draw command indices out of range"
                raise ProtocolError(msg)
            if count and vtx + max(struct.unpack_from(f"<{count}H", m, ip + 2 * off)) >= nv:
                msg = f"draw command vertices out of range (vtx_offset {vtx}, {nv} vertices)"
                raise ProtocolError(msg)
            big_lists.add(nv > 65536)
            p += 32
    if p != len(m):
        msg = f"frame message of {len(m)} bytes, parsed {p}"
        raise ProtocolError(msg)
    return w, h


def toggle_hover(ws: WebSocket, x: float, y: float) -> None:
    """Move the pointer on and off the button, 200 times per second, for the PACE window."""
    end = time.monotonic() + PACE[1] + 0.2
    k = 0
    while time.monotonic() < end:
        ws.send(f"m:{x},{y}" if k % 2 == 0 else "m:5,5")
        k += 1
        time.sleep(0.005)


def run(port: int, click_file: Path, token: str) -> None:
    """The checks; raises ProtocolError on the first failure."""
    check_page(port, token)
    ws = WebSocket(port, token)
    textures: set[int] = set()
    sized = clicked = False
    background: tuple[float, ...] | None = None
    frames = 0
    sized_at = 0.0  # when the size came back
    quiet_frames = quiet_alive = 0  # frames and "unchanged" messages while nothing changes (S12)
    after_click = 0  # frames received after the pointer moved onto the button
    paced_at = 0.0  # when the pointer started toggling the hover (200 moves per second)
    paced_frames = 0  # frames received in the PACE window
    z_pressed = False  # Z sent: the program stops drawing its long line
    end = time.monotonic() + TIMEOUT
    try:
        while time.monotonic() < end:
            m = ws.recv()
            if m[0] == 6:  # deflated: a zlib stream holding one message
                m = zlib.decompress(m[1:])
                deflated[0] += 1
                if m[0] == 6:
                    msg = "a deflated message inside a deflated message"
                    raise ProtocolError(msg)
            if m[0] == 2:
                tid, tw, th, _ = struct.unpack_from("<IIII", m, 1)
                if len(m) != 17 + tw * th * 4:
                    msg = f"texture {tid}: {len(m)} bytes for {tw} x {th}"
                    raise ProtocolError(msg)
                textures.add(tid)
            elif m[0] == 4:
                if len(m) != 13:
                    msg = f"background message of {len(m)} bytes"
                    raise ProtocolError(msg)
                background = struct.unpack_from("<fff", m, 1)
                if not all(0.0 <= v <= 1.0 for v in background):
                    msg = f"background colour out of range: {background}"
                    raise ProtocolError(msg)
            elif m[0] == 3:
                textures.discard(struct.unpack_from("<I", m, 1)[0])
            elif m[0] == 5:
                if len(m) != 1:
                    msg = f"unchanged message of {len(m)} bytes"
                    raise ProtocolError(msg)
                if sized and QUIET[0] <= time.monotonic() - sized_at < QUIET[1]:
                    quiet_alive += 1
            elif m[0] == 1:
                if background is None:
                    msg = "a frame before the background"
                    raise ProtocolError(msg)
                frames += 1
                w, h = parse_frame(m, textures)
                if True in big_lists and not z_pressed:  # seen: the program drops the long line (small frames)
                    ws.send("k:1,KeyZ")
                    ws.send("k:0,KeyZ")
                    z_pressed = True
                if clicked:
                    after_click += 1
                if paced_at and PACE[0] <= time.monotonic() - paced_at < PACE[1]:
                    paced_frames += 1
                if frames == 1:
                    ws.send("s:640,480")
                elif (w, h) == (640.0, 480.0) and not sized:
                    sized = True
                    sized_at = time.monotonic()
                elif sized and QUIET[0] <= time.monotonic() - sized_at < QUIET[1]:
                    quiet_frames += 1
            else:
                msg = f"unknown message type {m[0]}"
                raise ProtocolError(msg)
            quiet_over = sized and time.monotonic() - sized_at >= QUIET[1]
            if quiet_over and not paced_at and click_file.exists():
                text = click_file.read_text().split()
                if len(text) == 2:  # every move changes the button's hover: the cap alone limits the frames
                    x, y = float(text[0]), float(text[1])
                    paced_at = time.monotonic()
                    threading.Thread(target=toggle_hover, args=(ws, x, y), daemon=True).start()
            paced_over = paced_at and time.monotonic() - paced_at >= PACE[1] + 0.3
            if paced_over and not clicked:
                text = click_file.read_text().split()
                if len(text) == 2:
                    x, y = float(text[0]), float(text[1])
                    for event in (f"m:{x},{y}", "b:0,1", "b:0,0"):
                        ws.send(event)
                        time.sleep(0.05)
                    clicked = True
    except EOFError:
        pass  # the program ended: expected after the click
    if frames == 0 or not textures:
        msg = f"received {frames} frames and {len(textures)} textures"
        raise ProtocolError(msg)
    if True not in compact_lists:
        msg = "no draw list with 12-byte vertices arrived"
        raise ProtocolError(msg)
    if not deflated[0]:
        msg = "no deflated message arrived (the test program asks for compress='always')"
        raise ProtocolError(msg)
    if True not in big_lists:
        msg = "no draw list over 65536 vertices arrived"
        raise ProtocolError(msg)
    if quiet_frames or not quiet_alive:
        msg = f"idle interface: {quiet_frames} frames sent again, {quiet_alive} unchanged messages (expected 0 and >= 1)"
        raise ProtocolError(msg)
    if not 5 <= paced_frames <= MAX_FPS * (PACE[1] - PACE[0]):
        msg = f"{paced_frames} frames in {PACE[1] - PACE[0]:.1f} s of hover changes (expected 5 to {MAX_FPS}/s)"
        raise ProtocolError(msg)
    if not after_click:
        msg = "no frame after the pointer moved onto the button (a change must be sent)"
        raise ProtocolError(msg)
    if not sized:
        msg = "the size event never came back as the display size"
        raise ProtocolError(msg)
    if not clicked:
        msg = "the click point never appeared"
        raise ProtocolError(msg)


def write_verdict(path: Path, text: str) -> None:
    """Write the verdict atomically: the program polls for the file and must never read it half-written."""
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text + "\n")
    os.replace(tmp, path)


def main(argv: list[str]) -> int:
    """Run the client; write the verdict to OK_FILE."""
    port, click_file, ok_file = int(argv[0]), Path(argv[1]), Path(argv[2])
    token = argv[3] if len(argv) > 3 else ""
    try:
        run(port, click_file, token)
    except (ProtocolError, OSError) as err:
        write_verdict(ok_file, f"FAILED: {err}")
        return 1
    write_verdict(ok_file, "ok")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

import argparse
import asyncio
from dbus_next import Message, MessageType
from dbus_next.aio import MessageBus
import base64
import binascii
import hashlib
import hmac
import html
import json
import os
from pathlib import Path
import re
import secrets
import signal
import ssl
import subprocess
import threading
import tempfile
import sqlite3
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def notify(app, icon, title, body):
    async def call():
        bus = await MessageBus().connect()
        try:
            response = await asyncio.wait_for(bus.call(Message(
                destination='org.freedesktop.Notifications',
                path='/org/freedesktop/Notifications',
                interface='org.freedesktop.Notifications', member='Notify',
                signature='susssasa{sv}i',
                body=[app, 0, icon, html.escape(title), html.escape(body), [], {}, 15000],
            )), timeout=10)
            if response.message_type == MessageType.ERROR or response.signature != 'u':
                raise RuntimeError('Desktop notification call failed')
            return response.body[0]
        finally:
            bus.disconnect()
    return asyncio.run(call())


def display_awake(display, root=Path('/sys/class/drm')):
    # Missing/disconnected/unknown displays fail closed: never acknowledge invisible delivery.
    for connector in root.glob('card*-' + display):
        try:
            if (connector.joinpath('status').read_text().strip() == 'connected'
                    and connector.joinpath('dpms').read_text().strip().lower() == 'on'):
                return True
        except OSError:
            pass
    return False


class CallProtection:
    """Only reconnect a headset this receiver disconnected; unknown state fails closed."""
    def __init__(self, state, address):
        self.address = address
        self.marker = state / 'call-protection-owned'
        self.idle_since = None
        self.last_update = 0
        self.lock = threading.Lock()

    def command(self, action):
        result = subprocess.run(['bluetoothctl', action, self.address],
                                capture_output=True, text=True, timeout=8)
        if result.returncode:
            raise RuntimeError('Bluetooth call protection command failed')
        return result.stdout

    def update(self, active):
        if not self.address:
            return
        with self.lock:
            now = time.monotonic()
            if now - self.last_update > 6:
                self.idle_since = None
            self.last_update = now
            if active is None:
                self.idle_since = None
            elif active:
                self.idle_since = None
                if not self.marker.exists():
                    if 'Connected: yes' in self.command('info'):
                        # Persist ownership before disconnect, including across service restarts.
                        self.marker.touch(mode=0o600)
                        try:
                            self.command('disconnect')
                        except Exception:
                            self.marker.unlink(missing_ok=True)
                            raise
                else:
                    # Reassert protection if another client reconnects during the call.
                    if 'Connected: yes' in self.command('info'):
                        self.command('disconnect')
            elif self.marker.exists():
                now = time.monotonic()
                if self.idle_since is None:
                    self.idle_since = now
                elif now - self.idle_since >= 3:
                    self.command('connect')
                    self.marker.unlink()
                    self.idle_since = None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state', default=str(Path.home() / '.local/share/phone-notification-relay'))
    parser.add_argument('--bind', default='0.0.0.0')
    parser.add_argument('--port', type=int, default=9843)
    parser.add_argument('--pair', metavar='HTTPS_URL')
    parser.add_argument('--reuse', action='store_true', help='Reuse existing credentials when provisioning over ADB')
    parser.add_argument('--display', default='eDP-1')
    parser.add_argument('--call-headset', default='', help='PC Bluetooth address to protect during phone calls')
    args = parser.parse_args()
    state = Path(args.state)
    os.umask(0o077)
    state.mkdir(parents=True, exist_ok=True)
    if args.pair:
        if not args.pair.startswith('https://'):
            parser.error('Pairing URL must use HTTPS')
        if not (state / 'key.pem').exists():
            subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                            '-keyout', str(state / 'key.pem'), '-out', str(state / 'cert.pem'),
                            '-days', '3650', '-subj', '/CN=Phone notification relay'],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Explicit pairing rotates credentials; automatic ADB provisioning preserves them.
        token = ((state / 'token').read_text().strip()
                 if args.reuse and (state / 'token').exists() else secrets.token_urlsafe(32))
        if not args.reuse or not (state / 'token').exists():
            temporary = state / 'token.new'
            temporary.write_text(token)
            temporary.replace(state / 'token')
        der = ssl.PEM_cert_to_DER_cert((state / 'cert.pem').read_text())
        pairing = {'url': args.pair.rstrip('/') + '/snapshot',
                   'pin': hashlib.sha256(der).hexdigest(), 'token': token}
        # Credentials go straight to the authenticated ADB pipe, never Downloads.
        print(json.dumps(pairing))
        return
    (state / 'token').read_text()  # Fail early until explicitly paired.
    delivered = sqlite3.connect(state / 'delivered.sqlite', check_same_thread=False)
    delivered.execute('CREATE TABLE IF NOT EXISTS delivered (id TEXT PRIMARY KEY)')
    delivered.commit()
    icon_directory = tempfile.TemporaryDirectory(prefix='phone-relay-icons-',
                                                dir=os.environ.get('RUNTIME_DIRECTORY',
                                                                   os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')))
    lock = threading.Lock()
    protection = CallProtection(state, args.call_headset)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass  # Neither payloads nor authentication headers enter logs.

        def do_POST(self):
            if self.path != '/snapshot':
                self.send_error(404)
                return
            # Read on every request so token rotation immediately revokes access.
            current_token = (state / 'token').read_text().strip()
            if not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + current_token):
                self.send_error(403)
                return
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 1024 * 1024:
                    raise ValueError()
                payload = json.loads(self.rfile.read(length))
                if not isinstance(payload, dict) or payload.get('version') != 2:
                    raise ValueError()
                items = payload.get('events')
                if not isinstance(items, list) or len(items) > 16:
                    raise ValueError()
                for item in items:
                    if not isinstance(item, dict) or any(not isinstance(item.get(k), str)
                                                         for k in ('id', 'app', 'title', 'body')):
                        raise ValueError()
                    if not re.fullmatch(r'[0-9a-f-]{36}', item['id']):
                        raise ValueError()
                    encoded = item.get('icon', '')
                    if not isinstance(encoded, str) or len(encoded) > 65536:
                        raise ValueError()
                    if encoded:
                        png = base64.b64decode(encoded, validate=True)
                        if (len(png) < 24 or png[:8] != b'\x89PNG\r\n\x1a\n'
                                or png[12:16] != b'IHDR'
                                or not 0 < int.from_bytes(png[16:20], 'big') <= 128
                                or not 0 < int.from_bytes(png[20:24], 'big') <= 128):
                            raise ValueError()
                call_state = payload.get('call_active')
                if call_state is not None and type(call_state) is not bool:
                    raise ValueError()
                # Independent of desktop display readiness and notification delivery.
                protection.update(call_state)
                acked = []
                with lock:
                    ready = display_awake(args.display)
                    for item in items:
                        if delivered.execute('SELECT 1 FROM delivered WHERE id = ?', (item['id'],)).fetchone():
                            acked.append(item['id'])
                            continue
                        if not ready:
                            continue
                        icon = 'smartphone'
                        if item.get('icon'):
                            png = base64.b64decode(item['icon'], validate=True)
                            path = Path(icon_directory.name) / (hashlib.sha256(png).hexdigest() + '.png')
                            if not path.exists():
                                path.write_bytes(png)
                            path.touch()
                            icon = str(path)
                        notify('Phone · ' + item['app'], icon, item['title'], item['body'])
                        delivered.execute('INSERT INTO delivered (id) VALUES (?)', (item['id'],))
                        delivered.commit()
                        acked.append(item['id'])
                    # Icons remain readable for the lifetime of the popup, not as permanent history.
                    for path in Path(icon_directory.name).iterdir():
                        if time.time() - path.stat().st_mtime > 60:
                            path.unlink()
                response = json.dumps({'acked': acked, 'ready': ready}).encode()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(response)))
                self.end_headers()
                self.wfile.write(response)
            except (ValueError, TypeError, KeyError, UnicodeError, binascii.Error):
                self.send_error(400)
            except (RuntimeError, OSError, asyncio.TimeoutError, subprocess.TimeoutExpired):
                self.send_error(503)

        def setup(self):
            super().setup()
            self.connection.settimeout(15)

    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    server.daemon_threads = True
    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls.minimum_version = ssl.TLSVersion.TLSv1_2
    tls.load_cert_chain(state / 'cert.pem', state / 'key.pem')
    server.socket = tls.wrap_socket(server.socket, server_side=True)
    print('Phone notification receiver ready', flush=True)
    def stop(signum, frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        icon_directory.cleanup()
        delivered.close()


if __name__ == '__main__':
    main()

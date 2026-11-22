import glob
import os
from pathlib import Path
import selectors
import signal
import struct
import subprocess
import time

selector = selectors.DefaultSelector()
event = struct.Struct('@llHHi')
paths = {}
reports = set()
last = time.monotonic()
blank = False
running = True


def panel(off):
    subprocess.run(['/run/current-system/sw/bin/gamescopectl',
                    'drm_sleep_internal_screen', str(int(off))], check=True, timeout=3)
    print('Panel off' if off else 'Panel on', flush=True)


def stop(*_):
    global running
    running = False


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)


def refresh():
    for path in glob.glob('/dev/input/event*') + glob.glob('/dev/hidraw*'):
        if path in paths:
            continue
        node = Path(path).name
        raw = node.startswith('hidraw')
        try:
            if raw:
                props = Path(f'/sys/class/hidraw/{node}/device/uevent').read_text()
                if 'HID_ID=0003:000028DE:00001205\n' not in props:
                    continue
            else:
                props = Path(f'/sys/class/input/{node}/device/properties').read_text()
                name = Path(f'/sys/class/input/{node}/device/name').read_text().strip()
                if not int(props, 16) & 2 and name != 'AT Translated Set 2 keyboard':
                    continue
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue
        selector.register(fd, selectors.EVENT_READ, (path, raw))
        paths[path] = fd


try:
    next_refresh = 0
    while running:
        activity = False
        now = time.monotonic()
        if now >= next_refresh:
            refresh()
            next_refresh = now + 2
        for key, _ in selector.select(0.25):
            path, raw = key.data
            try:
                data = os.read(key.fd, 64 if raw else event.size * 64)
            except BlockingIOError:
                continue
            except OSError:
                data = b''
            if not data:
                selector.unregister(key.fd)
                os.close(key.fd)
                del paths[path]
                reports.discard(path)
            elif raw and len(data) == 64 and data[:4] == b'\x01\x00\x09\x40':
                reports.add(path)
                sticks = struct.unpack_from('<4h', data, 48)
                buttons = (data[8] or data[9] or data[10] & 0x5f or data[11] & 4
                           or data[13] & 6 or data[14] & 4)
                activity |= bool(buttons or any(abs(axis) > 6500 for axis in sticks))
            elif not raw:
                activity |= any(kind == 1 and value in (1, 2) and code != 116
                                for _, _, kind, code, value in event.iter_unpack(data))
        now = time.monotonic()
        if activity or not reports:
            last = now
            if blank:
                panel(False)
                blank = False
        elif not blank and now - last >= int(os.environ.get('PANEL_IDLE_SECONDS', 180)):
            blank = True
            panel(True)
finally:
    if blank:
        panel(False)

"""Consumer-owned music window lifetime adapter; never owns the Eww daemon."""

import argparse
import json
import os
from pathlib import Path
import re
import select
import signal
import subprocess
import sys
import threading
import time

MAX_STATE = 1024 * 1024


def active(eww, config, instance):
    result = subprocess.run([eww, '--config', config, 'active-windows'],
                            capture_output=True, text=True, timeout=.5)
    return result.returncode == 0 and any(
        line.partition(':')[0].strip() == instance for line in result.stdout.splitlines())


def consent(assets, instance, token, enabled):
    subprocess.run([str(Path(assets) / 'music-control'), '--instance', instance,
                    '--token', token, 'presentation-enable', 'true' if enabled else 'false'],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)


def output(raw):
    fd = sys.stdout.fileno()
    os.set_blocking(fd, False)
    deadline = time.monotonic() + 1
    while raw:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([], [fd], [], remaining)[1]:
            raise BrokenPipeError('Music window is not consuming state')
        try:
            raw = raw[os.write(fd, raw):]
        except BlockingIOError:
            pass


def listen(eww, config, assets, instance, stop=None, emit=output):
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_-]{0,63}', instance):
        raise ValueError('Expected safe Eww music window identifier')
    stop = stop or threading.Event()
    child = subprocess.Popen([str(Path(assets) / 'music-listen'), '--instance', instance],
                             stdout=subprocess.PIPE)
    token = mounted = ''
    observed = False
    pending = b''
    frame_started = None
    next_check = 0
    ready_deadline = time.monotonic() + 3
    try:
        os.set_blocking(child.stdout.fileno(), False)
        while not stop.is_set():
            now = time.monotonic()
            if now >= next_check:
                try:
                    visible = active(eww, config, instance)
                except (OSError, subprocess.TimeoutExpired):
                    visible = False
                if visible:
                    observed = True
                    if token and mounted != token:
                        consent(assets, instance, token, True)
                        mounted = token
                elif observed or now >= ready_deadline:
                    return
                next_check = time.monotonic() + .5
            if frame_started is not None and time.monotonic() - frame_started > 3:
                raise RuntimeError('Incomplete zap music state frame')
            if not select.select([child.stdout], [], [], .1)[0]:
                continue
            chunk = os.read(child.stdout.fileno(), 65536)
            if not chunk:
                return
            if frame_started is None:
                frame_started = time.monotonic()
            pending += chunk
            while b'\n' in pending:
                raw, pending = pending.split(b'\n', 1)
                if len(raw) > MAX_STATE:
                    raise RuntimeError('Zap music state is too large')
                value = json.loads(raw)
                if not isinstance(value, dict) or value.get('schema') != 1:
                    raise RuntimeError('Invalid zap music state')
                token = value.get('listener_token', '')
                if not isinstance(token, str) or (token and not re.fullmatch(r'[0-9a-f]{32}', token)):
                    raise RuntimeError('Invalid zap music listener token')
                emit(raw + b'\n')
                if observed and token and mounted != token:
                    consent(assets, instance, token, True)
                    mounted = token
                frame_started = time.monotonic() if pending else None
            if len(pending) > MAX_STATE:
                raise RuntimeError('Zap music state is too large')
    except BrokenPipeError:
        pass
    finally:
        if mounted:
            try:
                consent(assets, instance, mounted, False)
            except (OSError, subprocess.SubprocessError):
                pass  # Child termination also releases the listener's capture lease.
        if child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=2)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=1)
        child.stdout.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--eww', required=True)
    parser.add_argument('--eww-config', required=True)
    parser.add_argument('--assets', required=True)
    parser.add_argument('--instance', required=True)
    args = parser.parse_args()
    stop = threading.Event()
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: stop.set())
    listen(args.eww, args.eww_config, args.assets, args.instance, stop)


if __name__ == '__main__':
    main()

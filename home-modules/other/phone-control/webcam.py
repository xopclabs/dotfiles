#!/usr/bin/env python3
import fcntl
import os
import re
import select
import signal
import struct
import subprocess
import sys
import threading
from collections import deque
from pathlib import Path
import time

SIZE = 640 * 480 * 2
BLACK = bytes((16, 128, 16, 128)) * (SIZE // 4)
CLIENT_USAGE = 0x10E00001
SUBSCRIBE = 0x4020565A
DEQUEUE = 0x80885659
RAW = ['-f', 'rawvideo', '-pixel_format', 'yuyv422', '-video_size', '640x480', '-framerate', '30']


def start(*args, **kwargs):
    return subprocess.Popen(args, **kwargs)


def stop(*processes):
    for p in processes:
        if p.poll() is None:
            p.terminate()
    for p in processes:
        try:
            p.wait(timeout=2)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait()
        for pipe in (p.stdin, p.stdout):
            if pipe:
                pipe.close()


def read_frames(pipe, frames, received):
    # Drain the pipe continuously instead of waiting for the next webcam tick.
    while len(frame := pipe.read(SIZE)) == SIZE:
        frames.append(frame)
        received[0] += 1


def connected_phone(identity):
    def adb(*args):
        return subprocess.run(['adb', *args], capture_output=True, text=True, timeout=3, check=True).stdout

    def devices():
        return {line.split('\t')[0] for line in adb('devices').splitlines() if line.endswith('\tdevice')}

    service = re.escape(identity) + r'(?: \(\d+\))?'
    online = devices()
    named = sorted(serial for serial in online if re.fullmatch(service + r'\._adb-tls-connect\._tcp', serial))
    if named:
        return named[0] if len(named) == 1 else None

    # A manually connected wireless transport is listed as an address, not an mDNS name.
    record = service + r'\s+_adb-tls-connect\._tcp\s+([\d.]+:\d+)'
    endpoints = sorted(set(re.findall(r'^' + record + r'\s*$', adb('mdns', 'services'), re.MULTILINE)))
    connected = online.intersection(endpoints)
    if connected:
        return next(iter(connected)) if len(connected) == 1 else None
    for endpoint in endpoints:
        try:
            adb('connect', endpoint)
        except subprocess.SubprocessError:
            continue
    connected = devices().intersection(endpoints)
    return next(iter(connected)) if len(connected) == 1 else None


def camera_settings(serial, facing):
    uri = f'content://dev.phonecontrol.debugginghelper.pairing/webcam?facing={facing}'
    try:
        result = subprocess.run(['adb', '-s', serial, 'shell', 'content', 'query', '--uri', uri],
                                capture_output=True, text=True, timeout=2)
        match = re.search(r'quality=(\d+), fps=(\d+), rotation=(\d+), mirror=(\d+)', result.stdout)
        if match:
            quality, fps, rotation, mirror = map(int, match.groups())
            if quality in (0, 1, 2) and fps in (15, 24, 30) and rotation in (0, 90, 180, 270) and mirror in (0, 1):
                return ('500K', '1M', '2M')[quality], fps, rotation, mirror
    except (OSError, subprocess.TimeoutExpired):
        pass
    return '1M', 30, 0, False


def main(identity, front, rear, internal):
    devices = {'front': front, 'back': rear}
    sinks, subscriptions, demand = {}, {}, dict.fromkeys(devices, False)
    active, stream, latest = None, (), BLACK
    frames, received, counted = deque(maxlen=10), [0], 0
    next_attempt = deadline = 0
    poll = select.poll()
    state = Path('/sys/class/video4linux') / Path(internal).name / 'state'
    decoder = None
    try:
            for facing, device in devices.items():
                sink = sinks[facing] = start('ffmpeg', '-v', 'error', *RAW, '-i', 'pipe:0',
                                            '-c:v', 'rawvideo', '-f', 'v4l2', device,
                                            stdin=subprocess.PIPE)
                sink.stdin.write(BLACK)
                sink.stdin.flush()
                status = Path('/sys/class/video4linux') / Path(device).name / 'state'
                for _ in range(50):
                    if status.read_text().strip() == 'capture':
                        break
                    time.sleep(.02)
                fd = os.open(device, os.O_RDWR | os.O_NONBLOCK)
                subscriptions[fd] = facing
                fcntl.ioctl(fd, SUBSCRIBE, struct.pack('8I', CLIENT_USAGE, 0, 1, 0, 0, 0, 0, 0))
                poll.register(fd, select.POLLPRI)
            while True:
                tick = time.monotonic()
                for fd, events in poll.poll(0):
                    if not events & select.POLLPRI:
                        continue
                    event = bytearray(136)
                    while True:
                        try:
                            fcntl.ioctl(fd, DEQUEUE, event)
                        except (BlockingIOError, FileNotFoundError):
                            break
                        facing = subscriptions[fd]
                        demand[facing] = bool(struct.unpack_from('I', event, 8)[0])
                        print(f'{facing}: capture={demand[facing]}', flush=True)
                wanted = active if active and demand[active] else next((f for f in demand if demand[f]), None)
                if stream and (wanted != active or any(p.poll() is not None for p in stream) or tick > deadline):
                    active_before_stop = active
                    stop(*stream)
                    stream, active, latest, decoder = (), None, BLACK, None
                    frames, received, counted = deque(maxlen=10), [0], 0
                    next_attempt = tick + (2 if wanted == active_before_stop else 0)
                    print('Camera stopped; black fallback', flush=True)
                if wanted and not stream and tick >= next_attempt:
                    next_attempt = tick + 2
                    try:
                        serial = connected_phone(identity)
                    except (OSError, subprocess.SubprocessError):
                        serial = None
                    if serial is None:
                        time.sleep(.03)
                        continue
                    bitrate, fps, rotation, mirror = camera_settings(serial, wanted)
                    camera = start('scrcpy', '--serial', serial, '--video-source=camera', '--camera-facing', wanted,
                                   '--camera-size=640x480', f'--camera-fps={fps}', f'--video-bit-rate={bitrate}',
                                   '--no-control', '--no-audio',
                                   '--no-window', '--video-codec=h264', '--v4l2-sink', internal)
                    stream, active, deadline = (camera,), wanted, tick + 15
                    print(f'Starting {active} camera', flush=True)
                if stream and decoder is None and state.read_text().strip() == 'capture':
                    filters = {0: [], 90: ['transpose=clock'], 180: ['hflip', 'vflip'], 270: ['transpose=cclock']}[rotation]
                    if mirror:
                        filters.append('hflip')
                    if rotation in (90, 270):
                        filters += ['scale=360:480', 'pad=640:480:140:0', 'setsar=1']
                    filters += ['settb=1/30', 'setpts=N']
                    decoder = start('ffmpeg', '-v', 'error', '-f', 'v4l2', '-i', internal,
                                    '-vf', ','.join(filters),
                                    '-pix_fmt', 'yuyv422', '-fps_mode', 'passthrough',
                                    '-threads:v', '1', '-flush_packets', '1', '-f', 'rawvideo', 'pipe:1',
                                    stdout=subprocess.PIPE)
                    stream += (decoder,)
                    threading.Thread(target=read_frames, args=(decoder.stdout, frames, received), daemon=True).start()
                count = received[0]
                if count != counted:
                    counted = count
                    deadline = tick + 4
                if frames:
                    latest = frames.popleft()
                for facing, sink in sinks.items():
                    remaining = memoryview(latest if facing == active else BLACK)
                    sink.stdin.write(remaining)
                    sink.stdin.flush()
                time.sleep(max(0, 1 / 30 - (time.monotonic() - tick)))
    finally:
        stop(*stream, *sinks.values())
        for fd in subscriptions:
            os.close(fd)


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    try:
        main(*sys.argv[1:])
    except KeyboardInterrupt:
        pass

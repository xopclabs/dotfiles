#!/usr/bin/env python3
"""Render a player-only PipeWire capture as mirrored histogram PNG frames for Eww."""
import importlib.util
import json
import os
from pathlib import Path
import select
import signal
import struct
import subprocess
import sys
import tempfile
import time
import zlib

# Nix stores the two scripts at separate paths, so load the player helper explicitly.
spec = importlib.util.spec_from_file_location("eww_music", sys.argv[2])
music = importlib.util.module_from_spec(spec)
spec.loader.exec_module(music)
active_player = music.active_player
playerctl = music.playerctl

BARS = 64
HEIGHT = 72
COLOR = (136, 192, 208, 255)
BASELINE = (85, 112, 128, 255)


def stream_serial(player):
    if not player or playerctl("-p", player, "status") != "Playing":
        return None
    try:
        nodes = json.loads(subprocess.check_output(["pw-dump"], stderr=subprocess.DEVNULL))
    except (OSError, ValueError, subprocess.CalledProcessError):
        return None
    name = player.split(".")[0].lower()
    for node in nodes:
        if node.get("type") != "PipeWire:Interface:Node":
            continue
        props = node.get("info", {}).get("props", {})
        if props.get("media.class") != "Stream/Output/Audio":
            continue
        if name in (props.get("application.name") or props.get("node.name") or "").lower():
            return str(props.get("object.serial") or node["id"])
    return None


def png(values, width):
    pixels = bytearray(width * HEIGHT * 4)
    middle = HEIGHT // 2
    for x in range(width):
        offset = (middle * width + x) * 4
        pixels[offset:offset + 4] = bytes(BASELINE)
    for index, level in enumerate(values[:BARS]):
        left = round(index * width / BARS)
        right = max(left + 1, round((index + 1) * width / BARS) - 1)
        # Lift quiet upper frequencies without letting loud bass fill the height.
        energy = max(0, min(255, level)) / 255
        tilt = 1 + 1.3 * index / (BARS - 1)
        amplitude = min(middle - 2, round((energy ** 0.6) * tilt * (middle - 4))) if energy > 0.004 else 0
        if not amplitude:
            continue
        for y in range(middle - amplitude, middle + amplitude + 1):
            for x in range(left, right):
                offset = (y * width + x) * 4
                pixels[offset:offset + 4] = bytes(COLOR)
    rows = b"".join(b"\0" + pixels[y * width * 4:(y + 1) * width * 4] for y in range(HEIGHT))

    def chunk(tag, data):
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data))

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!2I5B", width, HEIGHT, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows, 1)) + chunk(b"IEND", b""))


def render(directory, frame, values, width):
    path = directory / f"{frame}.png"
    path.write_bytes(png(values, width))
    print(path, flush=True)
    (directory / f"{frame - 16}.png").unlink(missing_ok=True)


def stop(proc):
    if proc.poll() is None:
        proc.terminate()
        try:
            proc.wait(timeout=0.5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def visualize(width):
    with tempfile.TemporaryDirectory(prefix="eww-music-visualizer-") as temp:
        directory = Path(temp)
        fifo = directory / "audio"
        os.mkfifo(fifo)
        config = directory / "cava.conf"
        config.write_text(f"""[general]
bars = {BARS}
framerate = 30
lower_cutoff_freq = 40
higher_cutoff_freq = 6500
[smoothing]
noise_reduction = 45
[input]
method = fifo
source = {fifo}
sample_rate = 48000
sample_bits = 16
channels = stereo
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 255
channels = mono
""")
        frame = 0
        previous = None
        render(directory, frame, [0] * BARS, width)
        frame += 1
        while True:
            player = active_player()
            serial = stream_serial(player)
            if not serial:
                if previous is not None:
                    render(directory, frame, [0] * BARS, width)
                    frame += 1
                previous = None
                time.sleep(1)
                continue
            previous = serial
            # The recorder targets the *application stream*, never a sink monitor.
            # dont-fallback prevents silently capturing mixed system audio if it vanishes.
            with os.fdopen(os.open(fifo, os.O_RDWR | os.O_NONBLOCK), "wb", buffering=0) as output:
                cava = subprocess.Popen(["cava", "-p", str(config)], stdout=subprocess.PIPE,
                                        stderr=subprocess.DEVNULL, text=True)
                try:
                    recorder = subprocess.Popen(["pw-record", "--target", serial, "--media-category=Monitor",
                                                 "-P", '{"node.dont-fallback":true,"stream.monitor":true}',
                                                 "--latency", "10ms", "--rate", "48000", "--channels", "2", "--format", "s16",
                                                 "--raw", "-"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
                    try:
                        fd = cava.stdout.fileno()
                        audio_fd = recorder.stdout.fileno()
                        os.set_blocking(fd, False)
                        os.set_blocking(audio_fd, False)
                        pending = b""
                        levels = [0] * BARS
                        last_input = time.monotonic()
                        last_emitted = None
                        interval = 1 / 24
                        next_frame = time.monotonic()
                        deadline = next_frame + 3
                        while recorder.poll() is None and cava.poll() is None:
                            now = time.monotonic()
                            ready, _, _ = select.select([fd, audio_fd], [], [], min(0.1, max(0, next_frame - now)))
                            if audio_fd in ready:
                                audio = os.read(audio_fd, 65536)
                                if not audio:
                                    break
                                try:
                                    os.write(output.fileno(), audio)
                                except BlockingIOError:
                                    # Drop old samples rather than back-pressure PipeWire playback.
                                    pass
                            if fd in ready:
                                chunk = os.read(fd, 65536)
                                if not chunk:
                                    break
                                pending += chunk
                                lines = pending.split(b"\n")
                                pending = lines.pop()[-1024:]
                                for line in lines:
                                    try:
                                        values = [int(value) for value in line.split(b";") if value]
                                    except ValueError:
                                        continue
                                    if len(values) >= BARS:
                                        levels = values[:BARS]
                                        last_input = time.monotonic()
                            now = time.monotonic()
                            if now >= next_frame:
                                if now - last_input > 0.12:
                                    levels = [round(value * 0.75) for value in levels]
                                if levels != last_emitted:
                                    render(directory, frame, levels, width)
                                    frame += 1
                                    last_emitted = levels[:]
                                next_frame = max(next_frame + interval, now + interval * 0.5)
                            if now >= deadline:
                                if serial != stream_serial(active_player()):
                                    break
                                deadline = time.monotonic() + 3
                    finally:
                        stop(recorder)
                        recorder.stdout.close()
                finally:
                    stop(cava)
                    cava.stdout.close()
            previous = None
            render(directory, frame, [0] * BARS, width)
            frame += 1


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    visualize(max(48, int(sys.argv[1])))

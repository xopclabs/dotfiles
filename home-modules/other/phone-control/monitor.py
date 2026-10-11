"""Live scrcpy FPS and estimated ADB TCP payload throughput; no screen recording."""
import argparse
import ipaddress
import re
import signal
import subprocess
import threading
import time

FPS = re.compile(r'\b(\d+) fps(?: \(\+(\d+) frames skipped\))?')
SERVICE = '._adb-tls-connect._tcp'


def phone_endpoint(serial, services):
    name = serial.removesuffix(SERVICE)
    for line in services.splitlines():
        fields = line.split('\t')
        if (len(fields) == 3 and fields[0] == name
                and fields[1].rstrip('.') == SERVICE.lstrip('.')):
            host, port = fields[2].strip().rsplit(':', 1)
            return str(ipaddress.ip_address(host.strip('[]'))), int(port)
    raise ValueError('Phone mDNS endpoint unavailable')


def tcp_counters(endpoint):
    host, port = endpoint
    result = subprocess.run(['ss', '-tinH', 'dst', host, 'and', 'dport', '=', f':{port}'],
                            capture_output=True, text=True, check=True, timeout=2)
    if not result.stdout.strip():
        return None
    return tuple(sum(int(value) for value in re.findall(r'\b' + field + r':(\d+)', result.stdout))
                 for field in ('bytes_received', 'bytes_sent'))


def rates(previous, current, elapsed):
    if previous is None or current is None or elapsed <= 0:
        return None
    if any(new < old for old, new in zip(previous, current)):
        return None  # A reconnected TCP transport resets cumulative counters.
    return tuple((new - old) * 8 / elapsed / 1_000_000
                 for old, new in zip(previous, current))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('serial')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('scrcpy command required')
    if '--print-fps' not in command:
        command.append('--print-fps')

    endpoint = None
    try:
        services = subprocess.run(['adb', 'mdns', 'services'], capture_output=True,
                                  text=True, check=True, timeout=5).stdout
        endpoint = phone_endpoint(args.serial, services)
    except (OSError, ValueError, subprocess.SubprocessError):
        print('Network counters unavailable; FPS monitoring remains enabled.', flush=True)
    print('Telemetry: rendered FPS / skipped frames; ADB down/up in Mbps (video + audio + control).',
          flush=True)
    print('Static screens may report low or zero FPS. No screen recording.', flush=True)
    latest = [None, 0, 0.0]
    stats_lock = threading.Lock()
    process = subprocess.Popen(['stdbuf', '-oL', '-eL', *command], stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)

    def stop(signum, frame):
        if process.poll() is None:
            process.terminate()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    def read_output():
        for line in process.stdout:
            match = FPS.search(line)
            if match:
                with stats_lock:
                    latest[:] = [int(match[1]), int(match[2] or 0), time.monotonic()]
            else:
                print(line.rstrip(), flush=True)

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    previous = None
    previous_time = time.monotonic()
    try:
        if endpoint:
            previous = tcp_counters(endpoint)
    except (OSError, subprocess.SubprocessError):
        pass
    samples = []
    try:
        while process.poll() is None:
            time.sleep(1)
            if process.poll() is not None:
                break
            current = None
            try:
                if endpoint:
                    current = tcp_counters(endpoint)
            except (OSError, subprocess.SubprocessError):
                pass
            now = time.monotonic()
            throughput = rates(previous, current, now - previous_time)
            previous, previous_time = current, now
            with stats_lock:
                fps, skipped, updated = latest
            fps_text = f'{fps:3d} fps | skipped {skipped}' if fps is not None and now - updated < 3 else 'FPS waiting'
            if throughput:
                samples.append(throughput[0])
                network = f'ADB down {throughput[0]:6.2f} Mbps | up {throughput[1]:5.2f} Mbps'
            else:
                network = 'ADB throughput unavailable'
            print(f'{fps_text} | {network}', flush=True)
    finally:
        if process.poll() is None:
            process.terminate()
        try:
            result = process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            result = process.wait()
        reader.join(timeout=2)
        process.stdout.close()
    if samples:
        print(f'ADB down summary: mean {sum(samples) / len(samples):.2f}, '
              f'min {min(samples):.2f}, max {max(samples):.2f} Mbps ({len(samples)} samples).', flush=True)
    # SIGINT/SIGTERM are intentional closes, not failed phone-control sessions.
    return 0 if result in (0, -signal.SIGINT, -signal.SIGTERM) else result


if __name__ == '__main__':
    raise SystemExit(main())

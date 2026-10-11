"""Provision the private HTTPS relay through an authenticated ADB transport."""
import argparse
import hashlib
import json
import re
import socket
import subprocess
import time

URI = 'content://dev.phonecontrol.debugginghelper.pairing/pair'


def provision(serial, port):
    def adb(*args, data=None):
        return subprocess.run(['adb', '-s', serial, 'shell', '-T', *args],
                              input=data, capture_output=True, check=True, timeout=15).stdout

    # Ask Android for its Wi-Fi source address; derive our reachable LAN address
    # without transmitting any datagram. Do not guess from mDNS transport names.
    addresses = adb('ip', '-4', '-o', 'addr', 'show').decode()
    # Ignore VPN interfaces: their source addresses need not be reachable by the PC.
    match = re.search(r'\b(?:wlan|wifi|ap)\w*\s+inet\s+([0-9.]+)/', addresses)
    if not match:
        raise RuntimeError('No phone Wi-Fi address')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.connect((match.group(1), 9))
        address = sock.getsockname()[0]
    raw = subprocess.run(['phone-notification-receiver', '--pair',
                          f'https://{address}:{port}', '--reuse'],
                         capture_output=True, check=True, timeout=30).stdout
    pair = json.loads(raw)
    identity = '\n'.join(pair[key] for key in ('url', 'pin', 'token'))
    digest = hashlib.sha256(identity.encode()).hexdigest().encode()
    # Never put credentials in command arguments, shared storage, or logs.
    adb('content', 'write', '--uri', URI, data=raw)
    for _ in range(20):
        if digest in adb('content', 'query', '--uri', URI):
            subprocess.run(['systemctl', '--user', 'start', 'phone-notification-relay.service'],
                           capture_output=True, check=True, timeout=15)
            return
        time.sleep(0.1)
    raise RuntimeError('Helper did not accept provisioning')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('serial')
    parser.add_argument('port', type=int)
    args = parser.parse_args()
    try:
        provision(args.serial, args.port)
    except Exception:
        # subprocess errors can contain command details; keep failures private.
        parser.exit(1, 'Notification setup failed. Update the helper and check the Wi-Fi connection.\n')

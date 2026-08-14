'''Headless control client for the Perimeter81 helper daemon.

The vendor agent already exposes every command used here, but only through
`perimeter81 ctl <command>`, which boots a full Electron process and aborts
with a futex error when no display is available.  That makes it unusable from
systemd units and from `p81-reset`.  The GUI is only a thin client anyway: it
talks node-ipc to the daemon over a unix socket, exchanging form-feed
delimited JSON frames, which is what this module speaks directly.
'''

import argparse
import json
import socket
import sys
import time
from typing import Any, Dict, Optional


SOCKET_PATH = '/tmp/app.p81helper'
DELIMITER = b'\x0c'
REQUEST_EVENT = 'perimeter81.server.cliCommand'
REPLY_EVENT = 'perimeter81.client.cli_reply'

POLL_INTERVAL_SEC = 1.0
REISSUE_INTERVAL_SEC = 3.0
STUCK_AFTER_SEC = 15.0
SETTLE_SEC = 2.0
CONNECTED_STATES = ('connected',)
PENDING_STATES = ('connecting', 'reconnecting')

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_NO_DAEMON = 2
EXIT_LOGGED_OUT = 3
EXIT_TIMEOUT = 4


class DaemonUnavailable(Exception):
    '''The daemon socket is missing, or it dropped us mid-request.'''


def call(command: str, timeout: float = 15.0) -> Dict[str, Any]:
    '''Run one CLI command against the daemon and return its reply.'''
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        try:
            sock.connect(SOCKET_PATH)
        except OSError as error:
            raise DaemonUnavailable(str(error)) from error

        request = {
            'type': REQUEST_EVENT,
            'data': {'command': command, 'payload': {}},
        }
        sock.sendall(json.dumps(request).encode() + DELIMITER)

        buffer = b''
        while True:
            try:
                chunk = sock.recv(65536)
            except OSError as error:
                raise DaemonUnavailable(str(error)) from error
            if not chunk:
                raise DaemonUnavailable('daemon closed the connection')
            buffer += chunk
            while DELIMITER in buffer:
                raw, buffer = buffer.split(DELIMITER, 1)
                if not raw:
                    continue
                message = json.loads(raw)
                if message.get('type') == REPLY_EVENT:
                    return message.get('data') or {}
    finally:
        sock.close()


def report(quiet: bool, text: str) -> None:
    if not quiet:
        print(f'p81ctl: {text}', file=sys.stderr)


def poll(deadline: float, command: str) -> Optional[Dict[str, Any]]:
    '''Retry `command` until the daemon answers or the deadline passes.'''
    while True:
        try:
            return call(command)
        except DaemonUnavailable:
            pass
        if time.monotonic() >= deadline:
            return None
        time.sleep(POLL_INTERVAL_SEC)


def wait_for_login(deadline: float) -> str:
    '''A fresh daemon reports logged-out until it has read its config.'''
    while True:
        reply = poll(deadline, 'auth-status')
        if reply is None:
            return 'no-daemon'
        if reply.get('status') == 'logged-in':
            return 'logged-in'
        if time.monotonic() >= deadline:
            return 'logged-out'
        time.sleep(POLL_INTERVAL_SEC)


def wait_for_networks(deadline: float) -> bool:
    '''Wait for the cloud control channel to deliver the network list.

    The daemon starts serving CLI commands seconds before that channel is up,
    and a connect issued in the meantime is acknowledged and then dropped on
    the floor without ever reaching the VPN.
    '''
    while True:
        reply = poll(deadline, 'get-networks')
        if reply is None:
            return False
        if reply.get('privateNetworks') or reply.get('publicNetworks'):
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(POLL_INTERVAL_SEC)


def drive_connection(deadline: float, quiet: bool) -> int:
    '''Keep asking for a connection until one lands or time runs out.

    Two things can swallow a connect. The daemon can accept it and never act,
    leaving the state at `disconnected`; or the cloud can refuse it with an
    error the agent has no handler for, which pins the state at `connecting`
    forever. Both are indistinguishable from a slow connect except by waiting,
    and both clear up on their own given a minute or so, so the job here is to
    keep trying rather than to diagnose.
    '''
    issued_at: Optional[float] = None

    while True:
        status = poll(deadline, 'vpn-status')
        if status is None:
            return EXIT_NO_DAEMON

        state = status.get('Status')
        if state in CONNECTED_STATES:
            return EXIT_OK

        now = time.monotonic()
        if state in PENDING_STATES:
            if issued_at is None:
                issued_at = now
            elif now - issued_at >= STUCK_AFTER_SEC:
                # Nothing will move this along, and the daemon reads a second
                # connect as a toggle, so knock it back to a state we are
                # allowed to act on. Far cheaper than resetting the agent.
                report(quiet, 'connect is wedged, clearing it to try again')
                try:
                    call('vpn-disconnect')
                except DaemonUnavailable:
                    pass
                issued_at = None
                time.sleep(SETTLE_SEC)
        elif issued_at is None or now - issued_at >= REISSUE_INTERVAL_SEC:
            if issued_at is not None:
                report(quiet, 'connect went nowhere, asking again')
            try:
                reply = call('vpn-connect')
            except DaemonUnavailable:
                reply = None
            issued_at = time.monotonic()
            # A redundant connect is a race with the daemon's own reconnect
            # logic rather than a failure, so keep waiting on it.
            if reply is not None and reply.get('status') != 'ok':
                if reply.get('message') != 'user_already_connected':
                    report(quiet, f'daemon refused vpn-connect: {reply}')
                    return EXIT_FAILED

        if time.monotonic() >= deadline:
            return EXIT_TIMEOUT
        time.sleep(POLL_INTERVAL_SEC)


def cmd_connect(args: argparse.Namespace) -> int:
    quiet = args.quiet
    # Coming back from a reset, the daemon needs a few seconds to open its
    # socket and log in. That is startup latency rather than a stuck tunnel,
    # so it gets its own budget and does not eat into --timeout.
    ready_by = time.monotonic() + args.daemon_timeout

    status = poll(ready_by, 'vpn-status')
    if status is None:
        report(quiet, f'daemon is not listening on {SOCKET_PATH}')
        return EXIT_NO_DAEMON

    state = status.get('Status')
    if state in CONNECTED_STATES:
        report(quiet, 'already connected')
        return EXIT_OK

    login = wait_for_login(ready_by)
    if login == 'no-daemon':
        report(quiet, 'daemon stopped answering while logging in')
        return EXIT_NO_DAEMON
    if login != 'logged-in':
        report(quiet, 'not logged in, open the Harmony SASE app once')
        return EXIT_LOGGED_OUT

    if not wait_for_networks(ready_by):
        report(quiet, 'no networks listed yet, trying to connect anyway')

    result = drive_connection(time.monotonic() + args.timeout, quiet)
    if result == EXIT_OK:
        report(quiet, 'connected')
    elif result == EXIT_NO_DAEMON:
        report(quiet, 'daemon stopped answering while connecting')
    elif result == EXIT_TIMEOUT:
        report(quiet, f'still not connected after {args.timeout:g}s')
    return result


def cmd_call(args: argparse.Namespace) -> int:
    try:
        print(json.dumps(call(args.command), indent=2))
    except DaemonUnavailable as error:
        print(f'p81ctl: {error}', file=sys.stderr)
        return EXIT_NO_DAEMON
    return EXIT_OK


def main() -> int:
    parser = argparse.ArgumentParser(
        prog='p81ctl',
        description='Drive the Perimeter81 daemon without its Electron GUI.',
    )
    subparsers = parser.add_subparsers(dest='subcommand', required=True)

    connect = subparsers.add_parser(
        'connect',
        help='connect the VPN and wait until it is up',
    )
    connect.add_argument(
        '--timeout',
        type=float,
        default=45.0,
        help='seconds to keep trying before giving up on the tunnel',
    )
    connect.add_argument(
        '--daemon-timeout',
        type=float,
        default=30.0,
        help='seconds to wait for the daemon to answer and finish logging in',
    )
    connect.add_argument(
        '--quiet',
        action='store_true',
        help='suppress progress output',
    )
    connect.set_defaults(handler=cmd_connect)

    for name, command in (
        ('status', 'vpn-status'),
        ('auth-status', 'auth-status'),
        ('disconnect', 'vpn-disconnect'),
        ('networks', 'get-networks'),
    ):
        subparser = subparsers.add_parser(name, help=f'run `{command}`')
        subparser.set_defaults(handler=cmd_call, command=command)

    raw = subparsers.add_parser('call', help='run an arbitrary CLI command')
    raw.add_argument('command')
    raw.set_defaults(handler=cmd_call)

    args = parser.parse_args()
    return args.handler(args)


if __name__ == '__main__':
    sys.exit(main())

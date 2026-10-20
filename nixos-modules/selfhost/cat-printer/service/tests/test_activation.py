import subprocess
import sys
import tempfile
import unittest


class SocketActivationTests(unittest.TestCase):
    def test_private_and_public_inherited_listeners(self):
        script = """
import os
import socket
import sys
from catprinter.server import inherited_sockets

public = sys.argv[1] == 'public'
tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcp.bind(('127.0.0.1', 0))
tcp.listen()
sockets = [tcp]
if public:
    unix = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    unix.bind(sys.argv[2] + '/printer.sock')
    unix.listen()
    sockets.append(unix)
# Duplicate first so that assigning systemd's descriptors cannot clobber a source.
copies = [os.dup(s.fileno()) for s in sockets]
for index, fd in enumerate(copies):
    os.dup2(fd, 3 + index)
os.environ['LISTEN_PID'] = str(os.getpid())
os.environ['LISTEN_FDS'] = str(len(sockets))
listeners = inherited_sockets(public)
assert len(listeners) == len(sockets)
assert socket.AF_INET in [s.family for s in listeners]
if public:
    assert socket.AF_UNIX in [s.family for s in listeners]
"""
        for mode in ("private", "public"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                subprocess.run([sys.executable, "-c", script, mode, directory], check=True)


if __name__ == "__main__":
    unittest.main()

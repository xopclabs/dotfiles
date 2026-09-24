from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

LAUNCH = Path(__file__).parent.parent / "launch.sh"


class LaunchTests(unittest.TestCase):
    def test_concurrent_starts_and_restart(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            eww = tmp / "eww"
            eww.write_text('''#!/usr/bin/env bash
set -eu
[ ! -e /proc/$$/fd/9 ] || exit 99
shift 2 # --config path
printf '%s\\n' "$1" >> "$MOCK_LOG"
case "$1" in
  ping) test -f "$MOCK_STATE/daemon" ;;
  daemon) sleep 0.15; touch "$MOCK_STATE/daemon" ;;
  kill) rm -f "$MOCK_STATE/daemon" "$MOCK_STATE/windows" ;;
  active-windows) test ! -f "$MOCK_STATE/windows" || echo co2_chart ;;
  open-many) touch "$MOCK_STATE/windows" ;;
  *) exit 1 ;;
esac
''')
            eww.chmod(0o755)
            env = os.environ | {"XDG_RUNTIME_DIR": str(tmp), "MOCK_LOG": str(tmp / "log"),
                                "MOCK_STATE": str(tmp)}
            cmd = ["bash", str(LAUNCH), str(eww), str(tmp), shutil.which("flock"),
                   "--", "co2_chart", "temperature_chart"]
            first = subprocess.Popen(cmd, env=env, stderr=subprocess.PIPE)
            second = subprocess.Popen(cmd, env=env, stderr=subprocess.PIPE)
            for process in (first, second):
                _, stderr = process.communicate(timeout=8)
                self.assertEqual(process.returncode, 0, stderr)
            commands = (tmp / "log").read_text().splitlines()
            self.assertEqual(commands.count("daemon"), 1)
            self.assertEqual(commands.count("open-many"), 1)
            self.assertNotIn("poll", commands)

            subprocess.run(cmd[:5] + ["--restart"] + cmd[5:], env=env, check=True, timeout=8)
            commands = (tmp / "log").read_text().splitlines()
            self.assertEqual(commands.count("kill"), 1)
            self.assertEqual(commands.count("daemon"), 2)
            self.assertEqual(commands.count("open-many"), 2)


if __name__ == "__main__":
    unittest.main()

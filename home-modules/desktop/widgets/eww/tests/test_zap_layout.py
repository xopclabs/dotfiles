"""Real generated consumer UI on isolated Eww/MPD-API fixtures, no live services."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import threading
import time
import unittest


@unittest.skipUnless(os.environ.get('ZAP_DASHBOARD_YUCK'), 'Run the isolated generated-dashboard Nix fixture')
class ZapDashboardLayoutTests(unittest.TestCase):
    def test_generated_music_metadata_controls_close_reopen_and_chart_sibling(self):
        from zap.core import Core
        from zap.server import Server
        from zap.music_presentation import capture_enabled
        class MPD:
            state = 'play'
            commands = []
            def object(self, name):
                if name == 'status':
                    return {'state': self.state, 'songid': '1', 'elapsed': '3', 'duration': '120',
                            'playlistlength': '1', 'playlist': '1'}
                return {'id': '1', 'file': 'fixture', 'artist': '', 'title': 'Fixture track', 'album': 'Fixture release'}
            def command(self, name, *args):
                self.commands.append(name)
                if name == 'pause':
                    self.state = 'pause' if args == ('1',) else 'play'
                elif name == 'play':
                    self.state = 'play'
                return []
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            runtime = root / 'runtime'
            (runtime / 'zap').mkdir(parents=True, mode=0o700)
            source = Path(os.environ['ZAP_DASHBOARD_YUCK']).read_text()
            # Test display has no eDP-1; retain generated dimensions/component/commands.
            source = re.sub(r'^\s*:monitor "[^"\n]*"\n', '\n', source, flags=re.MULTILINE)
            # The adapter's consumer path, not the real dashboard daemon, owns this fixture.
            source = source.replace('--instance main_music`', f'--instance main_music --eww-config {root}`')
            source += '\n(defwindow chart_stub :geometry (geometry :width "120px" :height "80px") (button :timeout "2s" :onclick "touch ' + str(root / 'pointer-check') + '" (label :text "unrelated chart")))'
            (root / 'eww.yuck').write_text(source)
            (root / 'eww.scss').write_text(Path(os.environ['ZAP_DASHBOARD_SCSS']).read_text())
            env = {**os.environ, 'XDG_RUNTIME_DIR': str(runtime), 'XDG_CACHE_HOME': str(root / 'cache'),
                   'HOME': str(root), 'GDK_BACKEND': 'x11', 'NO_AT_BRIDGE': '1'}
            command = [os.environ['ZAP_TEST_EWW'], '--config', str(root)]
            def run(*args):
                try:
                    return subprocess.check_output(command + list(args), env=env, text=True,
                                                   stderr=subprocess.STDOUT, timeout=3)
                except subprocess.CalledProcessError as exc:
                    self.fail(exc.output + '\n' + (root / 'eww.log').read_text())
            def wait(check):
                deadline = time.monotonic() + 5
                while not check():
                    if time.monotonic() > deadline:
                        self.fail('Generated dashboard fixture condition timed out; commands=' + repr(mpd.commands)
                                  + '\n' + (root / 'eww.log').read_text())
                    time.sleep(.03)
            def state():
                return json.loads(run('get', 'main_music_data'))
            mpd = MPD()
            backend = Server(str(runtime / 'zap/api.sock'), Core(mpd))
            worker = threading.Thread(target=backend.serve_forever, daemon=True)
            worker.start()
            with (root / 'eww.log').open('w+') as log:
                daemon = subprocess.Popen(command + ['--no-daemonize', 'daemon'], env=env, stdout=log, stderr=log)
                try:
                    wait(lambda: subprocess.run(command + ['ping'], env=env, capture_output=True, timeout=1).returncode == 0)
                    run('open', 'chart_stub')
                    subprocess.run(['xdotool', 'mousemove', '60', '40'], env=env, check=True)
                    subprocess.run(['xdotool', 'click', '1'], env=env, check=True)
                    wait(lambda: (root / 'pointer-check').exists())
                    directory = runtime / 'zap/music/main_music'
                    run('open', 'main_music')
                    wait(lambda: state()['title'] == 'Fixture track' and capture_enabled(directory))
                    first_token = state()['listener_token']
                    self.assertEqual(state()['album'], 'Fixture release')
                    window_id = subprocess.check_output(['xdotool', 'search', '--name', '^Eww - main_music$'],
                                                        env=env, text=True, timeout=3).splitlines()[0]
                    geometry = subprocess.check_output(['xdotool', 'getwindowgeometry', '--shell', window_id],
                                                       env=env, text=True, timeout=3)
                    width = int(re.search(r'^WIDTH=(\d+)$', geometry, re.MULTILINE)[1])
                    def click_at(x):
                        subprocess.run(['xdotool', 'mousemove', '--window', window_id, str(x), '87'],
                                       env=env, check=True, timeout=3)
                        subprocess.run(['xdotool', 'click', '1'], env=env, check=True, timeout=3)
                    click_at(width // 2)
                    wait(lambda: not state()['playing'] and state()['feedback'] == 'play')
                    self.assertEqual(mpd.state, 'pause')
                    # Click again while feedback is visible: it must not intercept input.
                    click_at(width // 2)
                    wait(lambda: state()['playing'])
                    click_at(24)
                    wait(lambda: mpd.commands[-1] == 'previous')
                    click_at(width - 24)
                    wait(lambda: mpd.commands[-1] == 'next')
                    run('close', 'main_music')
                    wait(lambda: not (directory / 'listener.json').exists() and not list(directory.glob('frames-*')))
                    self.assertFalse(capture_enabled(directory))
                    self.assertIn('chart_stub', run('active-windows'))
                    self.assertIsNone(daemon.poll())
                    run('open', 'main_music')
                    wait(lambda: state()['listener_token'] != first_token and capture_enabled(directory))
                    run('close', 'main_music')
                    wait(lambda: not (directory / 'listener.json').exists())
                    self.assertEqual(mpd.commands, ['pause', 'pause', 'previous', 'next'])
                    log.seek(0)
                    logs = log.read()
                    self.assertNotIn('Unknown attribute', logs)
                    self.assertNotIn('error:', logs.lower())
                finally:
                    subprocess.run(command + ['kill'], env=env, capture_output=True, timeout=3)
                    daemon.wait(timeout=3)
                    backend.shutdown()
                    backend.server_close()
                    worker.join(3)


if __name__ == '__main__':
    unittest.main()

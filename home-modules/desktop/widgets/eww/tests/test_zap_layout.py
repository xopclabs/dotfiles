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
            integration = Path(re.search(r'\(include "([^"]+)/listeners.yuck"\)', source).group(1))
            import shlex
            listeners = (integration / 'listeners.yuck').read_text()
            for wrapper in integration.iterdir():
                if wrapper.name.endswith(('_state', '_marquee', '_bars')):
                    lines = wrapper.read_text().splitlines()
                    args = shlex.split(lines[1])
                    args[args.index('--eww-config') + 1] = str(root)
                    copied = root / wrapper.name
                    copied.write_text(lines[0] + '\n' + shlex.join(args) + '\n')
                    copied.chmod(0o755)
                    listeners = listeners.replace(str(wrapper), str(copied))
            (root / 'listeners.yuck').write_text(listeners)
            source = source.replace(str(integration / 'listeners.yuck'), str(root / 'listeners.yuck'))
            source += '\n(defwindow chart_stub :geometry (geometry :width "120px" :height "80px") (button :timeout "2s" :onclick "touch ' + str(root / 'pointer-check') + '" (label :text "unrelated chart")))'
            (root / 'eww.yuck').write_text(source)
            (root / 'eww.scss').write_text(Path(os.environ['ZAP_DASHBOARD_SCSS']).read_text() +
                '\n.zap-music-previous-zone { background: #ff0000; }'
                '\n.zap-music-next-zone { background: #00ff00; }')
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
                return json.loads(run('get', 'zap_instance_main_music_state'))
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
                    coords = dict(line.split('=', 1) for line in geometry.splitlines())
                    width = int(coords['WIDTH'])
                    presentation = state()['presentation']
                    self.assertEqual(presentation['orientation'], 'vertical')
                    art_size = presentation['art_size']
                    # Consumer tile padding plus adaptive component padding.
                    inset = 24
                    art_y = inset + art_size // 2
                    def click_at(x, y=art_y):
                        subprocess.run(['xdotool', 'mousemove', '--window', window_id, str(x), str(y)],
                                       env=env, check=True, timeout=3)
                        subprocess.run(['xdotool', 'click', '1'], env=env, check=True, timeout=3)
                    click_at(width // 2)
                    wait(lambda: not state()['playing'] and state()['feedback'] == 'play')
                    self.assertEqual(mpd.state, 'pause')
                    # Click again while feedback is visible: it must not intercept input.
                    click_at(width // 2)
                    wait(lambda: state()['playing'])
                    # Probe actual painted control bounds, not assumed GtkBox allocation.
                    from gi.repository import Gdk
                    Gdk.init([])
                    def control_center(color):
                        geometry = subprocess.check_output(['xdotool', 'getwindowgeometry', '--shell', window_id],
                                                           env=env, text=True, timeout=3)
                        current = dict(line.split('=', 1) for line in geometry.splitlines())
                        current_width = int(current['WIDTH'])
                        frame = Gdk.pixbuf_get_from_window(Gdk.get_default_root_window(),
                            int(current['X']), int(current['Y']), current_width, int(current['HEIGHT']))
                        pixels = bytes(frame.get_pixels())
                        stride, channels = frame.get_rowstride(), frame.get_n_channels()
                        points = [(x, y) for y in range(frame.get_height()) for x in range(current_width)
                                  if pixels[y * stride + x * channels:y * stride + x * channels + 3] == color]
                        self.assertTrue(points, 'Music control must be visibly painted')
                        return tuple((min(p[axis] for p in points) + max(p[axis] for p in points)) // 2
                                     for axis in (0, 1))
                    previous = control_center(b'\xff\x00\x00')
                    following = control_center(b'\x00\xff\x00')
                    self.assertLess(previous[0], following[0])
                    click_at(*previous)
                    wait(lambda: mpd.commands[-1] == 'previous' and state()['feedback'] == 'previous')
                    click_at(*control_center(b'\x00\xff\x00'))
                    wait(lambda: mpd.commands[-1] == 'next' and state()['feedback'] == 'next')
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
                    # The generated consumer now owns the picker too. Its
                    # geometry and close operation must preserve sibling tiles.
                    picker = re.search(r'\(defwindow zap_picker.*?:width "(\d+)px" :height "(\d+)px"',
                                       source, re.DOTALL)
                    self.assertIsNotNone(picker)
                    for session in ('first', 'second'):
                        run('open', 'zap_picker', '--arg', 'zap_session=' + session)
                        picker_id = subprocess.check_output(
                            ['xdotool', 'search', '--name', '^Eww - zap_picker$'],
                            env=env, text=True, timeout=3).splitlines()[0]
                        geometry = subprocess.check_output(
                            ['xdotool', 'getwindowgeometry', '--shell', picker_id],
                            env=env, text=True, timeout=3)
                        dimensions = dict(line.split('=', 1) for line in geometry.splitlines())
                        self.assertEqual((dimensions['WIDTH'], dimensions['HEIGHT']), picker.groups())
                        run('close', 'zap_picker')
                        self.assertNotIn('zap_picker:', run('active-windows'))
                        self.assertIn('chart_stub:', run('active-windows'))
                        self.assertIsNone(daemon.poll())
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

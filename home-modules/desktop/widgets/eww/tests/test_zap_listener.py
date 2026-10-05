import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).parent.parent
spec = importlib.util.spec_from_file_location('zap_dashboard_listener', HERE / 'zap_listener.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class ZapListenerTests(unittest.TestCase):
    def test_consumer_wires_only_zap_and_keeps_chart_definitions(self):
        module = (HERE / 'eww.nix').read_text()
        ui = (HERE / 'ui/default.nix').read_text()
        self.assertIn('eww-widgets.withConfig', module)
        self.assertNotIn('pkgs.playerctl', module)
        self.assertNotIn('${./music.py}', module)
        self.assertNotIn('${./visualizer.py}', module)
        self.assertIn('(zap-music-adaptive :state ${tile.id}_data', ui)
        self.assertIn('--layout-file ${musicProfile tile}', ui)
        self.assertIn('musicDimensions tile', ui)
        self.assertNotIn(':art_size', ui)
        self.assertNotIn(':large', ui)
        self.assertIn('${musicAssets}/visualize --instance ${tile.id}', ui)
        self.assertIn('${musicAssets}/listen --channel preview', ui)
        self.assertIn('(zap-selection-preview :state dashboard_zap_preview', ui)
        self.assertIn('(overlay', ui)
        self.assertIn('.music-tile .zap-selection-preview { background: #2e3440; }',
                      (HERE / 'ui/eww.scss').read_text())
        self.assertIn('(defwidget chart-tile', (HERE / 'ui/eww.yuck').read_text())
        self.assertIn('(defwidget value-tile', (HERE / 'ui/eww.yuck').read_text())
        self.assertNotIn('(defwidget music-tile', (HERE / 'ui/eww.yuck').read_text())

    def fixture(self, root, token='a' * 32):
        state = {'schema': 1, 'listener_token': token, 'title': 'Fixture MPD track'}
        child = root / 'music-listen'
        child.write_text('#!/usr/bin/env python3\nimport json,time\nprint(' + repr(json.dumps(state)) + ',flush=True)\ntime.sleep(30)\n')
        child.chmod(0o755)
        control = root / 'music-control'
        control.write_text('#!/usr/bin/env bash\nset -eu\nprintf "%s\\n" "${@: -1}" >> "$CONTROL_LOG"\nif [[ "${@: -1}" == true ]]; then rm -f "$WINDOW_ACTIVE"; fi\n')
        control.chmod(0o755)
        eww = root / 'eww'
        eww.write_text('#!/usr/bin/env bash\nif [[ -f "$WINDOW_ACTIVE" ]]; then echo "main_music: main_music"; else echo "chart_stub: chart_stub"; fi\n')
        eww.chmod(0o755)
        return eww

    def test_mount_after_real_token_unmount_on_close_and_reap_child(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            eww = self.fixture(root)
            active = root / 'active'
            active.touch()
            env = {'WINDOW_ACTIVE': str(active), 'CONTROL_LOG': str(root / 'control.log')}
            emitted = []
            children = []
            commands = []
            original = subprocess.Popen
            def popen(*args, **kwargs):
                child = original(*args, **kwargs)
                if args[0][0] == str(root / 'music-listen'):
                    children.append(child)
                    commands.append(args[0])
                return child
            with patch.dict(os.environ, env), patch.object(adapter.subprocess, 'Popen', side_effect=popen):
                adapter.listen(str(eww), str(root), str(root), 'main_music', emit=emitted.append,
                               layout_file=str(root / 'layout with spaces.json'))
            self.assertEqual(commands, [[str(root / 'music-listen'), '--instance', 'main_music',
                                       '--layout-file', str(root / 'layout with spaces.json')]])
            self.assertEqual(len(emitted), 1)
            self.assertEqual(json.loads(emitted[0])['title'], 'Fixture MPD track')
            self.assertEqual((root / 'control.log').read_text().splitlines(), ['true', 'false'])
            self.assertEqual(len(children), 1)
            self.assertIsNotNone(children[0].poll())
            self.assertTrue(children[0].stdout.closed)
            self.assertEqual((root / 'eww').read_text().count('kill'), 0)

    def test_epipe_and_invalid_token_do_not_leave_a_mounted_child(self):
        for token, broken in [('bad-token', False), ('a' * 32, True)]:
            with self.subTest(token=token, broken=broken), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                eww = self.fixture(root, token)
                active = root / 'active'
                active.touch()
                def emit(_):
                    if broken:
                        raise BrokenPipeError()
                with patch.dict(os.environ, {'WINDOW_ACTIVE': str(active), 'CONTROL_LOG': str(root / 'control.log')}):
                    if broken:
                        adapter.listen(str(eww), str(root), str(root), 'main_music', emit=emit)
                    else:
                        with self.assertRaisesRegex(RuntimeError, 'token'):
                            adapter.listen(str(eww), str(root), str(root), 'main_music', emit=emit)
                self.assertFalse((root / 'control.log').exists())

    def test_window_name_match_is_exact(self):
        with patch.object(adapter.subprocess, 'run') as run:
            run.return_value.returncode = 0
            run.return_value.stdout = 'main_music_extra: main_music_extra\n'
            self.assertFalse(adapter.active('/eww', '/config', 'main_music'))
        with self.assertRaises(ValueError):
            adapter.listen('/eww', '/config', '/assets', 'bad;command')

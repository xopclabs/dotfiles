import importlib.util
import json
import os
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

HERE = Path(__file__).parent.parent
sys.path.insert(0, str(HERE / "grafana"))


def load(name, directory):
    spec = importlib.util.spec_from_file_location(name, HERE / directory / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


query = load("query", "grafana")

class DashboardTests(unittest.TestCase):
    def test_grafana_listener_bounds_each_query_and_keeps_publishing(self):
        from subprocess import TimeoutExpired
        results = [TimeoutExpired("query", 20), type("Result", (), {"returncode": 0, "stdout": '{"value":"ok"}\n'})()]
        def run(*args, **kwargs):
            result = results.pop(0)
            if isinstance(result, BaseException):
                raise result
            return result
        with patch.object(query.subprocess, "run", side_effect=run) as process, \
             patch.object(query.time, "sleep", side_effect=[None, KeyboardInterrupt]), \
             patch("builtins.print") as output:
            with self.assertRaises(KeyboardInterrupt):
                query.listen("config", "cache", "tile", "period", "0")
        self.assertEqual(process.call_count, 2)
        self.assertEqual(process.call_args.kwargs["timeout"], 20)
        output.assert_called_once_with('{"value":"ok"}', flush=True)

    def test_picker_uses_consumer_geometry_and_external_renderer(self):
        module = (HERE / 'eww.nix').read_text()
        ui = (HERE / 'ui/default.nix').read_text()
        self.assertIn('inherit (picker) width height;', module)
        self.assertIn('picker = if picker == null then null else', module)
        self.assertNotIn('cfg.picker', module)
        self.assertIn('zapUi.picker.rendererSettings', module)
        self.assertIn('ewwConfigDirectory = ewwConfig;', module)
        self.assertIn('window = picker.id;', module)
        self.assertIn('output = picker.output;', module)
        self.assertNotIn('pickerProfile', module)
        self.assertIn('(defwindow ${picker.id} [zap_session]', ui)
        self.assertIn(':focusable "none"', ui)
        self.assertIn('${zapUi.picker.widget}', ui)
        self.assertIn('${zapUi.assets}/listeners.yuck', ui)
        self.assertNotIn('playerctl', module)
        self.assertFalse((HERE / 'music.py').exists())
        self.assertFalse((HERE / 'visualizer.py').exists())

    def test_zap_widgets_are_explicit_and_popup_is_not_dashboard_launched(self):
        module = (HERE / 'eww.nix').read_text()
        ui = (HERE / 'ui/default.nix').read_text()
        layout = (HERE / 'layouts/internal-monitor-dashboard.nix').read_text()
        for template in ('zap-music', 'zap-picker', 'zap-selection-preview'):
            self.assertIn(f'template = "{template}";', layout)
        self.assertIn('overlay = "music";', layout)
        self.assertIn('size = { rows = 4; cols = 7; };', layout)
        self.assertNotIn('preview = "overlay";', module)
        self.assertNotIn('template == "music"', module + ui)
        self.assertIn('tile.template != "zap-picker" && tile.overlay == null', module)
        self.assertIn('map (tile: tile.id) ordinaryTiles', module)
        self.assertIn('lib.optionalString (picker != null)', ui)
        self.assertIn('preview.overlay != null && overlayTarget preview == tile.id', ui)
        self.assertIn('lib.length pickerTiles <= 1', module)
        self.assertIn('tile.output == null && tile.position == null && tile.size == null', module)
        self.assertIn('output = target.output;', module)
        self.assertIn('inherit (tile.settings) showAlbum volumeStep;', module)
        self.assertIn('volumeStep = lib.mkOption { type = lib.types.ints.between 1 100; default = 2;', module)
        self.assertIn('inherit (tile.settings) showLabel;', module)
        self.assertNotIn('inset = lib.mkOption', module)
        self.assertIn('inset = tilePadding;', module)
        self.assertIn('settings.showAlbum = false;', layout)
        preview = layout.split('selection_preview = {', 1)[1]
        for field in ('position =', 'size =', 'inherit output', 'inset ='):
            self.assertNotIn(field, preview)
        self.assertIn('settings.showLabel = false;', preview)
        self.assertIn('[ "@TILE_PADDING@" ] [ (toString tilePadding) ]', ui)

    @unittest.skipUnless(os.environ.get('ZAP_TEST_CONSUMER_FLAKE') and os.environ.get('ZAP_TEST_ZAP_SOURCE'),
                         'Set consumer wrapper and local zap source for Nix layout contract checks')
    def test_nix_widget_settings_and_overlay_geometry(self):
        command = ['nix', 'eval', os.environ['ZAP_TEST_CONSUMER_FLAKE'] + '#nixosConfigurations.pc',
                   '--override-input', 'dotfiles', 'path:' + str(HERE.parents[3]),
                   '--override-input', 'zap', 'path:' + os.environ['ZAP_TEST_ZAP_SOURCE'],
                   '--no-write-lock-file', '--json']
        cases = [
            ('overlay', 'original', True),
            ('settings', 'original // { music = original.music // { settings.showAlbum = true; }; selection_preview = original.selection_preview // { settings.showLabel = true; }; }', True),
            ('target-resize', 'original // { music = original.music // { size = { rows = 5; cols = 4; }; }; }', True),
            ('standalone', 'original // { selection_preview = original.selection_preview // { overlay = null; output = "eDP-1"; position = { row = 4; col = 0; }; size = { rows = 3; cols = 7; }; }; }', True),
            ('no-preview', 'builtins.removeAttrs original [ "selection_preview" ]', True),
            ('no-zap', 'lib.filterAttrs (_: w: lib.elem w.template [ "chart" "value" ]) original', True),
            ('overlay-geometry', 'original // { selection_preview = original.selection_preview // { size = { rows = 4; cols = 4; }; }; }', False),
            ('missing-target', 'original // { selection_preview = original.selection_preview // { overlay = "missing"; }; }', False),
            ('wrong-target', 'original // { selection_preview = original.selection_preview // { overlay = "picker"; }; }', False),
            ('missing-geometry', 'original // { music = original.music // { position = null; }; }', False),
            ('wrong-setting', 'original // { music = original.music // { settings.showLabel = true; }; }', False),
            ('legacy-inset', 'original // { music = original.music // { inset = 12; }; }', False),
            ('legacy-showAlbum', 'original // { music = original.music // { showAlbum = true; }; }', False),
        ]
        for name, widgets, valid in cases:
            with self.subTest(name=name):
                result_expr = 'yuck = c.xdg.configFile."eww-dashboard/eww.yuck".text;' if valid else ''
                expression = '''system: let
                    lib = system.pkgs.lib;
                    original = system.config.home-manager.users.xopc.modules.desktop.widgets.eww.pages.main.widgets;
                    c = (system.extendModules { modules = [ { home-manager.users.xopc.modules.desktop.widgets.eww = {
                        layout = lib.mkForce null; pages.main.widgets = lib.mkForce (''' + widgets + ''');
                    }; } ]; }).config.home-manager.users.xopc;
                    in { failures = builtins.filter (a: !a.assertion) c.assertions; ''' + result_expr + ' }'
                result = subprocess.run(command + ['--apply', expression], capture_output=True, text=True, timeout=180)
                if not valid:
                    self.assertTrue(result.returncode != 0 or json.loads(result.stdout)['failures'],
                                    'Invalid layout/settings must be rejected')
                    continue
                self.assertEqual(result.returncode, 0, result.stderr)
                value = json.loads(result.stdout)
                self.assertEqual(value['failures'], [])
                yuck = value['yuck']
                if name in ('overlay', 'target-resize', 'settings'):
                    self.assertIn('(overlay (zap-music ', yuck)
                    self.assertNotIn('(defwindow main_selection_preview', yuck)
                    height = 393 if name == 'target-resize' else 308
                    self.assertEqual(yuck.count(f':width 308 :height {height}'), 2)
                if name == 'settings':
                    self.assertIn(':show_album true', yuck)
                    self.assertIn(':show_label true', yuck)
                if name == 'standalone':
                    self.assertIn('(defwindow main_selection_preview', yuck)
                    self.assertNotIn('(overlay (zap-music ', yuck)
                if name == 'no-preview':
                    self.assertNotIn('(zap-selection-preview ', yuck)
                if name == 'no-zap':
                    self.assertNotIn('(zap-', yuck)
                    self.assertNotIn('/widgets.yuck', yuck)

    def test_all_chart_instances_keep_seven_day_first_and_peak(self):
        week = 7 * 24 * 3600 * 1000
        now = 2 * week
        start = now - week
        for key, fields, width in (("co2", ("value",), 264), ("temperature", ("value",), 328),
                                   ("power", ("ac", "pc"), 360)):
            with self.subTest(key=key):
                schema = [{"type": "time", "name": "Time"}] + [
                    {"type": "number", "name": field} for field in fields]
                columns = [[start, start + 60_000, start + 120_000, now]] + [
                    [10 + i, 11 + i, 100 + i, 12 + i] for i in range(len(fields))]
                frames = [{"schema": {"fields": schema}, "data": {"values": columns}}]
                chart = {"sql": "SELECT $__timeFilter(received_at)", "series": [
                    {"field": field, "alias": field.upper()} for field in fields]}
                cfg = {"datasource_uid": "telemetry-postgres", "charts": {key: chart},
                       "periods": [{"label": "7d", "ms": week}]}
                response = {"results": {"A": {"frames": frames}}}
                with tempfile.TemporaryDirectory() as cache, patch.object(query, "request", return_value=response) as request, \
                     patch.object(query.time, "time", return_value=now / 1000):
                    result = query.render(cfg, key, 0, Path(cache), width)
                    self.assertEqual(request.call_count, 1)
                    args = request.call_args.args
                    self.assertEqual(args[:2], (cfg, "/api/ds/query"))
                    target = args[2]["queries"][0]
                    self.assertEqual(target["datasource"]["uid"], "telemetry-postgres")
                    self.assertEqual(target["rawSql"], chart["sql"])
                    self.assertEqual(target["format"], "time_series")
                    self.assertEqual(target["intervalMs"], week // 120)
                    xml = ET.parse(result["chart"]).getroot()
                    self.assertEqual(xml.attrib["width"], str(width))
                    lines = xml.findall("{http://www.w3.org/2000/svg}polyline")
                    self.assertEqual(len(lines), len(fields))
                    gradients = xml.findall("{http://www.w3.org/2000/svg}defs/{http://www.w3.org/2000/svg}linearGradient")
                    areas = xml.findall("{http://www.w3.org/2000/svg}polygon")
                    self.assertEqual(len(gradients), len(fields))
                    self.assertEqual(len(areas), len(fields))
                    for i, (gradient, area) in enumerate(zip(gradients, areas)):
                        stops = gradient.findall("{http://www.w3.org/2000/svg}stop")
                        self.assertEqual(stops[0].attrib["stop-opacity"], "0.24")
                        self.assertEqual(stops[-1].attrib["stop-opacity"], "0")
                        self.assertEqual(area.attrib["fill"], f"url(#areaFade{i})")
                    for line in lines:
                        vertices = line.attrib["points"].split()
                        self.assertEqual(len(vertices), 4)
                        self.assertTrue(vertices[0].startswith("3.00,"), vertices[0])
                        self.assertLess(float(vertices[2].split(",")[1]), 5.0, vertices[2])
                    self.assertEqual(result["period"], "7d")
                    if key == "power":
                        self.assertTrue(result["legend2"].startswith("PC"))

    def test_nulls_and_other_fields(self):
        frames = [{"schema": {"fields": [
            {"name": "Time", "type": "time"}, {"name": "ac", "type": "number"},
            {"name": "pc", "type": "number"}]},
            "data": {"values": [[1, 2, 3], [1, None, 5], [7, 8, 9]]}}]
        self.assertEqual(query.extract_points(frames, "ac", True), [(1, 1), (2, 1), (3, 5)])
        self.assertEqual(query.extract_points(frames, "pc", True), [(1, 7), (2, 8), (3, 9)])
        self.assertEqual(query.extract_points([{"schema": {"fields": [{"name": "Selected", "type": "number"}]},
                                                "data": {"values": [[0.95]]}}], synthetic_time=5), [(5, 0.95)])

    def test_value_format_and_thresholds(self):
        steps = [{"color": "green"}, {"color": "red", "value": 70}]
        self.assertEqual(query.threshold_color(steps, 58), "#a3be8c")
        self.assertEqual(query.threshold_color(steps, 75), "#bf616a")
        cfg = {"datasource_uid": "telemetry-postgres", "values": {
            "humidity": {"sql": "SELECT 58", "value_format": "%.0f%%", "thresholds": steps},
            "today_power": {"sql": "SELECT 0.95", "format": "table",
                            "value_format": "%.2f kWh", "range": "today", "thresholds": steps}},
            "periods": [{"ms": 3600000}]}
        for key, field, value, expected in (("humidity", "value", 58, "58%"),
                                            ("today_power", "Selected", 0.95, "0.95 kWh")):
            with self.subTest(key=key):
                # Energy's Grafana panel has a numeric field but no time column.
                frames = [{"schema": {"fields": [{"name": field, "type": "number"}]},
                           "data": {"values": [[value]]}}]
                response = {"results": {"A": {"frames": frames}}}
                with tempfile.TemporaryDirectory() as cache, patch.object(query, "request", return_value=response) as request:
                    result = query.render(cfg, key, 0, Path(cache), 0)
                self.assertEqual(result["value"], expected)
                self.assertEqual(request.call_count, 1)
                self.assertEqual(request.call_args.args[2]["queries"][0]["format"],
                                 cfg["values"][key].get("format", "time_series"))


if __name__ == "__main__":
    unittest.main()

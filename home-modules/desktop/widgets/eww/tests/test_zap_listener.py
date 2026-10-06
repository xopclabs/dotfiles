from pathlib import Path
import unittest

HERE = Path(__file__).parent.parent


class ZapListenerTests(unittest.TestCase):
    def test_consumer_wires_only_zap_and_keeps_chart_definitions(self):
        module = (HERE / 'eww.nix').read_text()
        ui = (HERE / 'ui/default.nix').read_text()
        self.assertIn('zap.lib.mkEwwIntegration', module)
        self.assertNotIn('pkgs.playerctl', module)
        self.assertNotIn('${./music.py}', module)
        self.assertNotIn('${./visualizer.py}', module)
        self.assertIn('${zapUi.music.${tile.id}.widget}', ui)
        self.assertIn('${zapUi.picker.widget}', ui)
        self.assertNotIn('initialMusic', ui)
        self.assertNotIn('musicProfile', ui)
        self.assertNotIn('deflisten dashboard_zap_preview', ui)
        self.assertFalse((HERE / 'zap_listener.py').exists())
        self.assertIn('.music-tile .zap-selection-preview { background: #2e3440; }',
                      (HERE / 'ui/eww.scss').read_text())
        self.assertIn('(defwidget chart-tile', (HERE / 'ui/eww.yuck').read_text())
        self.assertIn('(defwidget value-tile', (HERE / 'ui/eww.yuck').read_text())
        self.assertNotIn('(defwidget music-tile', (HERE / 'ui/eww.yuck').read_text())

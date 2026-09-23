import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

HERE = Path(__file__).parent


def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


query = load("query")
workspace = load("workspace")


class DashboardTests(unittest.TestCase):
    def test_workspace_is_output_specific(self):
        pages = {"telemetry": "chart", "telemetry-value": "value"}
        workspaces = {
            1: {"id": 1, "name": "telemetry", "output": "eDP-1", "is_active": True},
            2: {"id": 2, "name": "telemetry-value", "output": "DP-5", "is_active": True},
        }
        self.assertEqual(workspace.page_for(workspaces, "eDP-1", pages), "chart")
        workspaces[1]["is_active"] = False
        self.assertIsNone(workspace.page_for(workspaces, "eDP-1", pages))

    def test_all_chart_instances_keep_seven_day_first_and_peak(self):
        week = 7 * 24 * 3600 * 1000
        now = 2 * week
        start = now - week
        for key, fields in (("co2", ("value",)), ("temperature", ("value",)),
                            ("power", ("ac", "pc"))):
            with self.subTest(key=key):
                schema = [{"type": "time", "name": "Time"}] + [
                    {"type": "number", "name": field} for field in fields]
                columns = [[start, start + 60_000, start + 120_000, now]] + [
                    [10 + i, 11 + i, 100 + i, 12 + i] for i in range(len(fields))]
                frames = [{"schema": {"fields": schema}, "data": {"values": columns}}]
                chart = {"dashboard_uid": "demo", "panel_id": 1, "series": [
                    {"field": field, "alias": field.upper()} for field in fields]}
                cfg = {"charts": {key: chart}, "periods": [{"label": "7d", "ms": week}]}
                responses = [{"dashboard": {"panels": [{"id": 1, "targets": [{"rawSql": "SELECT 1"}]}]}},
                             {"results": {"A": {"frames": frames}}}]
                with tempfile.TemporaryDirectory() as cache, patch.object(query, "request", side_effect=responses), \
                     patch.object(query.time, "time", return_value=now / 1000):
                    result = query.render(cfg, key, 0, Path(cache))
                    xml = ET.parse(result["chart"]).getroot()
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
        panel = {"fieldConfig": {"defaults": {"thresholds": {"steps": [
            {"color": "green", "value": None}, {"color": "red", "value": 70}]}}}}
        self.assertEqual(query.threshold_color(panel, 58), "#a3be8c")
        self.assertEqual(query.threshold_color(panel, 75), "#bf616a")
        cfg = {"values": {"humidity": {"dashboard_uid": "demo", "panel_id": 1, "format": "%.0f%%"},
                          "today_power": {"dashboard_uid": "demo", "panel_id": 1,
                                          "format": "%.2f kWh", "range": "today"}}, "periods": [{"ms": 3600000}]}
        dashboard = {"dashboard": {"panels": [{"id": 1, "targets": [{"rawSql": "SELECT 1"}],
                                               **panel}]}}
        for key, field, value, expected in (("humidity", "value", 58, "58%"),
                                            ("today_power", "Selected", 0.95, "0.95 kWh")):
            with self.subTest(key=key):
                # Energy's Grafana panel has a numeric field but no time column.
                frames = [{"schema": {"fields": [{"name": field, "type": "number"}]},
                           "data": {"values": [[value]]}}]
                responses = [dashboard, {"results": {"A": {"frames": frames}}}]
                with tempfile.TemporaryDirectory() as cache, patch.object(query, "request", side_effect=responses):
                    result = query.render(cfg, key, 0, Path(cache))
                self.assertEqual(result["value"], expected)


if __name__ == "__main__":
    unittest.main()

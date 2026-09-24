import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

GRAFANA = Path(__file__).parent.parent / "grafana"
sys.path.insert(0, str(GRAFANA))
import snapshot

spec = importlib.util.spec_from_file_location("period", GRAFANA / "period.py")
period = importlib.util.module_from_spec(spec)
spec.loader.exec_module(period)
spec = importlib.util.spec_from_file_location("query", GRAFANA / "query.py")
query = importlib.util.module_from_spec(spec)
spec.loader.exec_module(query)


class PreviewTests(unittest.TestCase):
    def test_snapshot_and_click_update_before_poll(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            svg = cache / "chart.svg"
            svg.write_text("<svg/>")
            snapshot.save(cache, "co2", 1, {"chart": str(svg), "period": "6h", "high": "900"})
            periods = [{"label": "1h"}, {"label": "6h"}]
            self.assertEqual(snapshot.preview(cache, "co2", 1, periods)["period"], "6h")
            self.assertEqual(snapshot.read(cache, "co2", 1)["high"], "900")
            config = cache / "config.json"
            config.write_text(json.dumps({"periods": periods, "charts": {"co2": {}}}))
            with patch.object(period.subprocess, "run") as run:
                period.main("co2", str(config), str(cache), "eww", "/config")
                self.assertEqual(snapshot.index(cache, "co2"), 1)
                update = run.call_args_list[0].args[0]
                self.assertEqual(update[:4], ["eww", "--config", "/config", "update"])
                self.assertEqual(json.loads(update[4].split("=", 1)[1])["high"], "900")
                self.assertEqual(run.call_args_list[1].args[0][-2:], ["poll", "co2_data"])
                # No cached chart for 1h: show an empty chart, not 6h data.
                period.main("co2", str(config), str(cache), "eww", "/config", "/empty.svg")
                empty = json.loads(run.call_args_list[2].args[0][4].split("=", 1)[1])
                self.assertEqual(empty["period"], "1h")
                self.assertEqual(empty["chart"], "/empty.svg")
            svg.unlink()
            self.assertIsNone(snapshot.read(cache, "co2", 1))

    def test_query_retains_chart_and_uses_it_on_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            config = cache / "config.json"
            config.write_text(json.dumps({"datasource_uid": "test", "periods": [{"label": "1h", "ms": 3600000}],
                                          "charts": {"co2": {"sql": "SELECT 1", "series": [
                                              {"alias": "CO₂", "field": "value"}]}}}))
            frames = [{"schema": {"fields": [{"name": "time", "type": "time"},
                                              {"name": "value", "type": "number"}]},
                       "data": {"values": [[1], [500]]}}]
            with patch.object(query, "request", return_value={"results": {"A": {"frames": frames}}}):
                with contextlib.redirect_stdout(io.StringIO()) as output:
                    query.main(str(config), str(cache), "co2", str(cache / "co2-period"), "264")
            data = json.loads(output.getvalue())
            self.assertTrue(Path(data["chart"]).is_file())
            self.assertEqual(snapshot.read(cache, "co2", 0)["chart"], data["chart"])
            with patch.object(query, "request", side_effect=OSError("offline")):
                with contextlib.redirect_stdout(io.StringIO()) as output, contextlib.redirect_stderr(io.StringIO()):
                    query.main(str(config), str(cache), "co2", str(cache / "co2-period"), "264")
            stale = json.loads(output.getvalue())
            self.assertEqual(stale["chart"], data["chart"])
            self.assertEqual(stale["period"], "1h")

    def test_warm_only_existing_snapshots(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = Path(tmp)
            svg = cache / "chart.svg"
            svg.write_text("<svg/>")
            snapshot.save(cache, "co2", 0, {"chart": str(svg), "period": "1h"})
            config = cache / "config.json"
            config.write_text(json.dumps({"periods": [{"label": "1h"}],
                                          "charts": {"co2": {}, "power": {}}}))
            with patch.object(snapshot.subprocess, "run") as run:
                snapshot.warm(str(config), str(cache), "eww", "/config")
            args = run.call_args.args[0]
            self.assertEqual(args[:4], ["eww", "--config", "/config", "update"])
            self.assertEqual(len(args), 5)
            self.assertEqual(json.loads(args[4].split("=", 1)[1])["period"], "1h")


if __name__ == "__main__":
    unittest.main()

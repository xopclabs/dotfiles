"""Runtime timezone binding and DST-safe local-day bounds."""
from datetime import datetime
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from zoneinfo import ZoneInfo

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "grafana"))
import query


class TimezoneTests(unittest.TestCase):
    def test_reads_localtime_zone_without_subprocess(self):
        with patch.object(query.Path, "resolve", return_value=Path("/usr/share/zoneinfo/Etc/UTC")), \
             patch.object(query.subprocess, "run") as run:
            self.assertEqual(query.system_timezone().key, "Etc/UTC")
            run.assert_not_called()

    def test_copied_localtime_uses_timedatectl(self):
        with patch.object(query.Path, "resolve", return_value=Path("/etc/localtime")), \
             patch.object(query.subprocess, "run") as run:
            run.return_value.stdout = "Etc/UTC\n"
            self.assertEqual(query.system_timezone().key, "Etc/UTC")

    def test_today_bounds_and_sql_use_same_runtime_timezone(self):
        # Test fixtures only: this zone has both DST transition directions.
        timezone = ZoneInfo("America/New_York")
        for month, day, expected_hours in [(3, 8, 11), (11, 1, 13)]:
            with self.subTest(month=month):
                now = datetime(2026, month, day, 12, tzinfo=timezone).timestamp()
                with patch.object(query, "system_timezone", return_value=timezone), \
                     patch.object(query.time, "time", return_value=now), \
                     patch.object(query, "request", return_value={"results": {"A": {"frames": []}}}) as request:
                    config = {"datasource_uid": "test"}
                    tile = {"sql": "SELECT '@timezone@'", "range": "today"}
                    _, start, end = query.query(config, tile, 1)
                    payload = request.call_args.args[2]
                    self.assertEqual(end - start, expected_hours * 3600 * 1000)
                    self.assertEqual(payload["queries"][0]["rawSql"], "SELECT 'America/New_York'")
                    self.assertEqual(int(payload["from"]), start)
                    self.assertEqual(datetime.fromtimestamp(start / 1000, timezone).hour, 0)
                    self.assertEqual(tile["sql"], "SELECT '@timezone@'")

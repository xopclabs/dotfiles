"""Both consumers must use the shared telemetry queries."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[5]


def evaluate(expression):
    result = subprocess.run(
        ["nix-instantiate", "--eval", "--strict", "--json", "--expr", expression],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


@unittest.skipUnless(shutil.which("nix-instantiate"), "Nix is required")
class QueryParityTests(unittest.TestCase):
    def test_all_eww_queries_match_dashboard(self):
        config = ROOT / "home-modules/desktop/widgets/eww/grafana/config.nix"
        actual = evaluate(f'''import {config} {{ config.sops.secrets = {{
            "eww/grafana-domain".path = "/unused";
            "eww/grafana-token".path = "/unused";
        }}; }}''')
        dashboards = evaluate(f"import {ROOT}/nixos-modules/selfhost/grafana/dashboards.nix")
        replacements = {"${__timezone}": "@timezone@", "${baseline_days:raw}": "30",
                        "${outlet_breakdown:raw}": "true"}
        cases = [
            ("charts", "co2", "air-quality", 4),
            ("charts", "temperature", "air-quality", 5),
            ("charts", "power", "shelly-power", 1),
            ("values", "humidity", "air-quality", 3),
            ("values", "today_power", "shelly-power", 2),
            ("values", "prior_avg_power", "shelly-power", 4),
        ]
        self.assertEqual({(section, key) for section in ("charts", "values")
                          for key in actual[section]}, {(s, k) for s, k, _, _ in cases})
        for section, key, dashboard, panel in cases:
            with self.subTest(key=key):
                expected = dashboards[f"{dashboard}.json"]["spec"]["elements"][f"panel-{panel}"]["spec"]["data"]["spec"]["queries"][0]["spec"]["query"]["spec"]["rawSql"]
                for variable, value in replacements.items():
                    expected = expected.replace(variable, value)
                self.assertEqual(actual[section][key]["sql"], expected)

    def test_generated_dashboards_have_no_unresolved_references(self):
        dashboards = evaluate(f"import {ROOT}/nixos-modules/selfhost/grafana/dashboards.nix")
        serialized = json.dumps(dashboards)
        for placeholder in ("@query:", "@timezone@", "@baselineDays@", "@outletBreakdown@"):
            self.assertNotIn(placeholder, serialized)
        self.assertIn("${baseline_days:raw}", serialized)
        self.assertIn("${__timezone}", serialized)
        self.assertIn("${outlet_breakdown:raw}", serialized)

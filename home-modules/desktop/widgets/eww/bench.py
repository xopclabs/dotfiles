#!/usr/bin/env python3
"""Benchmark Eww queries without starting or changing the running Eww daemon.

Run on the PC: python3 home-modules/desktop/widgets/eww/bench.py
Use --period 7d to measure the expensive history range.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import sys
import tempfile
import time

import grafana.query as dashboard

# Plot widths from layouts/internal-monitor-dashboard.nix (tile width minus 56).
WIDTHS = {"co2": 264, "temperature": 328, "power": 360,
          "humidity": 0, "today_power": 0}
QUERY = Path(__file__).parent / "grafana/query.py"


def summary(samples):
    ordered = sorted(samples)
    return f"{statistics.median(ordered):.0f}/{ordered[math.ceil(len(ordered) * .95) - 1]:.0f} ms"


def subprocess_query(config_path, cache, key):
    start = time.perf_counter()
    result = subprocess.run(
        [sys.executable, str(QUERY), str(config_path), str(cache), key,
         str(cache / f"{key}-period"), str(WIDTHS[key])],
        capture_output=True, text=True, timeout=20,
    )
    elapsed = (time.perf_counter() - start) * 1000
    if result.returncode or result.stderr or not result.stdout:
        raise RuntimeError(f"{key} query failed (exit {result.returncode})")
    data = json.loads(result.stdout)
    if key in ("co2", "temperature", "power") and not data.get("chart"):
        raise RuntimeError(f"{key} returned no chart")
    return elapsed


def benchmark(config, config_path, runs, period_index):
    period = config["periods"][period_index]["label"]
    keys = [key for key in WIDTHS if key in config.get("charts", {}) or key in config.get("values", {})]
    health = []
    http = {key: [] for key in keys}
    total = {key: [] for key in keys}
    processes = {key: [] for key in keys}
    startup = []

    with tempfile.TemporaryDirectory(prefix="eww-bench-") as tmp:
        cache = Path(tmp)
        # A no-SQL request estimates TLS/network/proxy/Grafana overhead.
        for _ in range(runs):
            start = time.perf_counter()
            dashboard.request(config, "/api/health")
            health.append((time.perf_counter() - start) * 1000)

        # In-process: separate time spent in the Grafana HTTP request from local work.
        original_request = dashboard.request
        current_key = None

        def timed_request(cfg, path, payload=None):
            start = time.perf_counter()
            try:
                return original_request(cfg, path, payload)
            finally:
                http[current_key].append((time.perf_counter() - start) * 1000)

        dashboard.request = timed_request
        try:
            for _ in range(runs):
                for key in keys:
                    current_key = key
                    start = time.perf_counter()
                    dashboard.render(config, key, period_index, cache, WIDTHS[key])
                    total[key].append((time.perf_counter() - start) * 1000)
        finally:
            dashboard.request = original_request

        # Fresh Python processes, like the five defpolls starting together.
        for _ in range(runs):
            for key in keys:
                (cache / f"{key}-period").write_text(str(period_index))
            start = time.perf_counter()
            with ThreadPoolExecutor(max_workers=len(keys)) as pool:
                futures = {key: pool.submit(subprocess_query, config_path, cache, key)
                           for key in keys}
                for key, future in futures.items():
                    processes[key].append(future.result())
            startup.append((time.perf_counter() - start) * 1000)

    print(f"Range: {period} (today_power always uses today); {runs} runs, p50/p95")
    print(f"Grafana /api/health (no SQL): {summary(health)}")
    print(f"{'Tile':<16} {'HTTP':>16} {'Local':>16} {'Process':>16}")
    for key in keys:
        local = [t - h for t, h in zip(total[key], http[key])]
        print(f"{key:<16} {summary(http[key]):>16} {summary(local):>16} {summary(processes[key]):>16}")
    print(f"Parallel startup wall time: {summary(startup)}")
    print("HTTP includes TLS, Grafana, and PostgreSQL; process includes Python startup and rendering.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path,
                        default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
                        / "eww-dashboard/queries.json")
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--period", default="1h", help="Chart range label (1h, 6h, 24h, 7d)")
    parser.add_argument("--all-periods", action="store_true", help="Benchmark every chart range")
    args = parser.parse_args()
    if args.runs < 1:
        parser.error("--runs must be positive")
    config = json.loads(args.config.read_text())
    periods = [p["label"] for p in config["periods"]]
    if not args.all_periods and args.period not in periods:
        parser.error(f"--period must be one of: {', '.join(periods)}")
    for index in range(len(periods)) if args.all_periods else [periods.index(args.period)]:
        benchmark(config, args.config, args.runs, index)
        if args.all_periods:
            print()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Benchmark failed: {exc}", file=sys.stderr)
        sys.exit(1)

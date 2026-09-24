#!/usr/bin/env python3
"""Time live Eww period switches (changes the charts briefly, then restores them).

Run on the PC with the dashboard open:
    python3 home-modules/desktop/widgets/eww/bench-live.py --cycles 3
"""
import argparse
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time


def cli(eww, config_dir, *args):
    return subprocess.run([eww, "--config", str(config_dir), *args], capture_output=True,
                          text=True, timeout=5)


def state(eww, config_dir, key):
    result = cli(eww, config_dir, "get", key + "_data")
    try:
        return json.loads(result.stdout), False
    except (json.JSONDecodeError, ValueError):
        return None, True  # Eww occasionally replies with an empty body during a poll.


def percentile(samples):
    ordered = sorted(samples)
    return f"{statistics.median(ordered):.0f}/{ordered[math.ceil(len(ordered) * .95) - 1]:.0f}"


def bench(key, config, config_dir, eww, period_command, cache, cycles, timeout):
    periods = [item["label"] for item in config["periods"]]
    period_file = cache / (key + "-period")
    initial = int(period_file.read_text()) if period_file.exists() else 0
    results = {label: [] for label in periods}
    click_times = []
    empty_reads = 0
    failures = 0
    try:
        for _ in range(cycles):
            for _ in periods:
                previous, _ = state(eww, config_dir, key)
                target = periods[(int(period_file.read_text()) + 1) % len(periods)]
                start = time.perf_counter()
                click = subprocess.run([period_command, key], capture_output=True, text=True, timeout=timeout)
                click_times.append((time.perf_counter() - start) * 1000)
                if click.returncode:
                    raise RuntimeError(f"{key} period command failed (exit {click.returncode})")
                deadline = start + timeout
                last = None
                while time.perf_counter() < deadline:
                    current, empty = state(eww, config_dir, key)
                    if current:
                        last = current
                    empty_reads += empty
                    if (current and current.get("period") == target and
                            current.get("chart") != (previous or {}).get("chart")):
                        results[target].append((time.perf_counter() - start) * 1000)
                        break
                    # Avoid flooding the Eww socket while it processes the poll.
                    time.sleep(.15)
                else:
                    failures += 1
                    print(f"  {key} {target}: no updated Eww state within {timeout}s "
                          f"(last period: {(last or {}).get('period', '?')}, "
                          f"chart changed: {(last or {}).get('chart') != (previous or {}).get('chart')})",
                          file=sys.stderr)
        return results, click_times, empty_reads, failures
    finally:
        # Restore both the period file and the running widget even if a test fails.
        period_file.write_text(str(initial))
        cli(eww, config_dir, "poll", key + "_data")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path,
                        default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
                        / "eww-dashboard")
    parser.add_argument("--eww", default="eww")
    parser.add_argument("--period-command", default="eww-dashboard-period")
    parser.add_argument("--cache", type=Path,
                        default=Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
                        / "eww-dashboard")
    parser.add_argument("--cycles", type=int, default=3)
    parser.add_argument("--key", action="append", help="Chart to test (repeatable; default: all)")
    parser.add_argument("--timeout", type=float, default=12)
    args = parser.parse_args()
    if args.cycles < 1:
        parser.error("--cycles must be positive")
    config = json.loads((args.config / "queries.json").read_text())
    active = cli(args.eww, args.config, "active-windows").stdout
    if not active:
        parser.error("Eww has no active dashboard windows")
    keys = args.key or config["charts"]
    if any(key not in config["charts"] for key in keys):
        parser.error("--key must name a configured chart")
    for key in keys:
        results, clicks, empty, failures = bench(key, config, args.config, args.eww, args.period_command,
                                                  args.cache, args.cycles, args.timeout)
        print(f"{key}: click CLI {percentile(clicks)} ms; empty/error get replies {empty}; timeouts {failures}")
        for period, times in results.items():
            print(f"  {period:>3}: {percentile(times) + ' ms' if times else 'no successful updates'}")
    print("Times end when Eww exposes the new SVG path, not when pixels appear on-screen.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(f"Live benchmark failed: {exc}", file=sys.stderr)
        sys.exit(1)

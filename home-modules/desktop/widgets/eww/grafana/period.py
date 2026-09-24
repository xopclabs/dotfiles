#!/usr/bin/env python3
"""Cycle a chart's range; the period label is the only click target."""
import json
from pathlib import Path
import subprocess
import sys


def main(key, config_path, cache_path, eww, eww_config):
    config = json.loads(Path(config_path).read_text())
    if key not in config["charts"]:
        raise ValueError("Unknown chart")
    periods = config["periods"]
    if not periods:
        return
    path = Path(cache_path) / (key + "-period")
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        index = int(path.read_text())
    except (OSError, ValueError):
        index = 0
    path.write_text(str((index + 1) % len(periods)))
    subprocess.run([eww, "--config", eww_config, "poll", key + "_data"], check=True)


if __name__ == "__main__":
    main(*sys.argv[1:6])

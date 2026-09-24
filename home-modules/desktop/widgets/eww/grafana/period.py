#!/usr/bin/env python3
"""Cycle a chart's range; the period label is the only click target."""
import json
from pathlib import Path
import subprocess
import sys

import snapshot


def main(key, config_path, cache_path, eww, eww_config, empty_chart=""):
    config = json.loads(Path(config_path).read_text())
    if key not in config["charts"]:
        raise ValueError("Unknown chart")
    periods = config["periods"]
    if not periods:
        return
    path = Path(cache_path) / (key + "-period")
    path.parent.mkdir(parents=True, exist_ok=True)
    index = (snapshot.index(path.parent, key) + 1) % len(periods)
    path.write_text(str(index))
    variable = key + "_data"
    empty = {"chart": empty_chart, "high": "—", "low": "—",
             "legend1": "—", "legend2": ""}
    data = snapshot.preview(path.parent, key, index, periods, empty)
    subprocess.run([eww, "--config", eww_config, "update", variable + "=" + json.dumps(data)], check=True)
    subprocess.run([eww, "--config", eww_config, "poll", variable], check=True)


if __name__ == "__main__":
    main(*sys.argv[1:7])

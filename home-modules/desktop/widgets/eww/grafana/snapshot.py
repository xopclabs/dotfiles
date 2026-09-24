"""Last successful charts for instant Eww previews while a fresh query runs."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def index(cache, key):
    path = cache / (key + "-period")
    try:
        return int(path.read_text())
    except (OSError, ValueError):
        return 0


def read(cache, key, period_index):
    try:
        data = json.loads((cache / f"snapshot-{key}-{period_index}.json").read_text())
        if Path(data["chart"]).is_file():
            return data
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def preview(cache, key, period_index, periods, fallback=None):
    data = (read(cache, key, period_index) or fallback or {}).copy()
    data["period"] = periods[period_index % len(periods)]["label"]
    return data


def save(cache, key, period_index, data):
    target = cache / f"snapshot-{key}-{period_index}.json"
    temp = cache / f".snapshot-{key}-{period_index}-{os.getpid()}-{time.time_ns()}.json"
    try:
        temp.write_text(json.dumps(data))
        temp.replace(target)
    finally:
        temp.unlink(missing_ok=True)


def warm(config_path, cache_path, eww, eww_config):
    config = json.loads(Path(config_path).read_text())
    cache = Path(cache_path)
    updates = []
    for key in config["charts"]:
        period_index = index(cache, key) % len(config["periods"])
        if read(cache, key, period_index):
            data = preview(cache, key, period_index, config["periods"])
            updates.append(key + "_data=" + json.dumps(data))
    if updates:
        subprocess.run([eww, "--config", eww_config, "update", *updates], check=True)


if __name__ == "__main__":
    warm(*sys.argv[1:5])

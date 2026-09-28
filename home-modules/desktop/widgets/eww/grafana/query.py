#!/usr/bin/env python3
"""Grafana data and timestamp-preserving SVGs for the Eww dashboard."""
import json
import subprocess
import math
import os
from pathlib import Path
import sys
import time
import urllib.request
from datetime import datetime

import snapshot

from templates import bounds, svg, threshold_color, present



def request(config, path, payload=None):
    body = json.dumps(payload).encode() if payload is not None else None
    url = config.get("url") or (config["url_prefix"] + Path(config["domain_file"]).read_text().strip())
    req = urllib.request.Request(
        url.rstrip("/") + path,
        data=body,
        headers={"Authorization": "Bearer " + Path(config["token_file"]).read_text().strip(),
                 "Accept": "application/json", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=15) as response:
        return json.load(response)


def number(value):
    try:
        n = float(value)
        return n if math.isfinite(n) else None
    except (ValueError, TypeError):
        return None


def extract_points(frames, field_name=None, fill_missing=False, synthetic_time=None):
    points = []
    for frame in frames:
        fields = frame.get("schema", {}).get("fields", [])
        columns = frame.get("data", {}).get("values", [])
        ti = next((i for i, f in enumerate(fields) if f.get("type") == "time"), None)
        vi = next((i for i, f in enumerate(fields) if f.get("type") == "number" and
                   (field_name is None or f.get("name") == field_name)), None)
        if vi is None or vi >= len(columns):
            continue
        if ti is None:
            for value in columns[vi]:
                v = number(value)
                if v is not None and synthetic_time is not None:
                    points.append((synthetic_time, v))
            continue
        if ti >= len(columns):
            continue
        first = next((v for raw in columns[vi] if (v := number(raw)) is not None), None) if fill_missing else None
        last = first
        for stamp, value in zip(columns[ti], columns[vi]):
            t, v = number(stamp), number(value)
            if v is None and fill_missing:
                v = last
            if t is not None and v is not None:
                points.append((t, v))
                last = v
    return sorted(points)


def query(config, tile, period_ms):
    now = int(time.time() * 1000)
    start = now - period_ms
    result = request(config, "/api/ds/query", {
        "from": str(start), "to": str(now), "queries": [{
            "datasource": {"uid": config["datasource_uid"], "type": "grafana-postgresql-datasource"},
            "refId": "A", "rawSql": tile["sql"], "format": tile.get("format", "time_series"),
            "rawQuery": True, "editorMode": "code",
            "intervalMs": max(1000, period_ms // 120), "maxDataPoints": 120,
        }],
    })["results"]["A"]
    if result.get("error"):
        raise ValueError(result["error"])
    return result.get("frames", []), start, now


def read_source(config, key, period_index, template):
    """Fetch once and expose named numeric series, independent of widget geometry."""
    chart = config.get("charts", {}).get(key)
    definition = chart or config["values"][key]
    periods = config["periods"]
    period = periods[period_index % len(periods)] if chart and template != "value" else None
    if chart and template == "value":
        period_ms = 24 * 3600 * 1000
    elif chart:
        period_ms = period["ms"]
    elif definition.get("range") == "today":
        now = datetime.now()
        period_ms = max(1000, int((now - now.replace(hour=0, minute=0, second=0, microsecond=0)).total_seconds() * 1000))
    else:
        period_ms = 24 * 3600 * 1000
    frames, start, end = query(config, definition, period_ms)
    if chart:
        fields = {item["field"]: extract_points(frames, item["field"], template == "chart")
                  for item in definition["series"]}
    else:
        fields = {"value": extract_points(frames, definition.get("field"), synthetic_time=end)}
    return {"fields": fields, "start": start, "end": end, "period": period}


def render(config, key, period_index, cache_dir, plot_width, template=None, field=None):
    template = template or ("chart" if key in config.get("charts", {}) else "value")
    data = read_source(config, key, period_index, template)
    definition = config.get("charts", {}).get(key) or config["values"][key]
    return present(template, definition, data, cache_dir, plot_width, field)

def main(config_path, cache_path, instance, period_path, plot_width):
    try:
        config = json.loads(Path(config_path).read_text())
        source = config["instances"][instance]["source"]
        is_chart = config["instances"][instance]["template"] == "chart"
        cache_dir = Path(cache_path)
        cache_dir.mkdir(parents=True, exist_ok=True)
        period_index = snapshot.index(cache_dir, instance)
        result = render(config, source, period_index, cache_dir, int(plot_width),
                        config["instances"][instance]["template"],
                        config["instances"][instance].get("field"))
        if is_chart and result.get("chart"):
            try:
                snapshot.save(cache_dir, instance, period_index % len(config["periods"]), result)
            except OSError as exc:
                print(f"dashboard {instance}: could not cache chart: {exc}", file=sys.stderr)
        retained = {
            Path(data["chart"])
            for chart_id, widget in config["instances"].items()
            if widget["template"] == "chart"
            for index in range(len(config["periods"]))
            if (data := snapshot.read(cache_dir, chart_id, index))
        }
        for old in cache_dir.glob("*.svg"):
            if old not in retained and time.time() - old.stat().st_mtime > 300:
                old.unlink()
        if is_chart and snapshot.index(cache_dir, instance) != period_index:
            current = snapshot.index(cache_dir, instance) % len(config["periods"])
            result = snapshot.read(cache_dir, instance, current) or result
        print(json.dumps(result))
    except (OSError, ValueError, KeyError, StopIteration, IndexError, TypeError) as exc:
        print(f"dashboard {instance}: {exc}", file=sys.stderr)
        if "config" in locals() and config.get("instances", {}).get(instance, {}).get("template") == "chart":
            current = snapshot.index(Path(cache_path), instance) % len(config["periods"])
            cached = snapshot.read(Path(cache_path), instance, current)
            if cached:
                cached["period"] = config["periods"][current]["label"]
                print(json.dumps(cached))
                return
        print(json.dumps({"chart": "", "high": "—", "low": "—", "legend1": "—", "legend2": "",
                          "period": "?", "value": "—", "color": "#d8dee9"}))


def listen(*args):
    command = [sys.executable, __file__, "once", *args]
    while True:
        start = time.monotonic()
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=20)
            if result.returncode == 0 and result.stdout.strip():
                print(result.stdout.strip().splitlines()[-1], flush=True)
        except (OSError, subprocess.TimeoutExpired):
            pass
        time.sleep(max(0, 60 - (time.monotonic() - start)))


if __name__ == "__main__":
    if sys.argv[1] == "listen":
        listen(*sys.argv[2:7])
    else:
        main(*sys.argv[2:7])

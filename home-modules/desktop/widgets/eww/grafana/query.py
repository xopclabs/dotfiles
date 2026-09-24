#!/usr/bin/env python3
"""Grafana data and timestamp-preserving SVGs for the Eww dashboard."""
import json
import math
import os
from pathlib import Path
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime

COLORS = ("#88c0d0", "#a3be8c")


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


def bounds(series, from_zero=False):
    values = [v for points in series for _, v in points]
    if not values:
        return None, None
    return min(0, min(values)) if from_zero else min(values), max(values)


def svg(series, start, end, width=264, height=88, from_zero=False):
    low, high = bounds(series, from_zero)
    pad = 3
    gradients = "".join(
        f'<linearGradient id="areaFade{i}" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0%" stop-color="{color}" stop-opacity="0.24"/>'
        f'<stop offset="100%" stop-color="{color}" stop-opacity="0"/>'
        '</linearGradient>'
        for i, color in enumerate(COLORS[:len(series[:2])])
    )
    content = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
               f'viewBox="0 0 {width} {height}"><defs>{gradients}</defs>']
    if low is not None:
        # Keep every Grafana sample as a vertex, including the first point and narrow peaks.
        span = high - low or 1
        baseline = height - pad
        plotted = []
        for points in series[:2]:
            if not points:
                plotted.append(None)
                continue
            coords = " ".join(f"{pad + (t - start) / (end - start) * (width - 2 * pad):.2f},"
                              f"{pad + (high - v) / span * (height - 2 * pad):.2f}" for t, v in points)
            plotted.append(coords)

        # Draw all filled areas first so subsequent series cannot cover earlier strokes.
        for i, coords in enumerate(plotted):
            if coords is None:
                continue
            first_x = coords.split()[0].split(",")[0]
            last_x = coords.split()[-1].split(",")[0]
            content.append(f'<polygon points="{first_x},{baseline} {coords} {last_x},{baseline}" '
                           f'fill="url(#areaFade{i})"/>')
        for i, coords in enumerate(plotted):
            if coords is not None:
                content.append(f'<polyline points="{coords}" fill="none" stroke="{COLORS[i]}" '
                               'stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>')
    content.append("</svg>")
    return "".join(content)


def query(config, tile, period_ms):
    dashboard = request(config, "/api/dashboards/uid/" + urllib.parse.quote(tile["dashboard_uid"], safe=""))["dashboard"]
    panel = next(p for p in dashboard["panels"] if p["id"] == tile["panel_id"])
    target = dict(panel["targets"][0])
    for needle, replacement in tile.get("replacements", {}).items():
        if "rawSql" in target:
            target["rawSql"] = target["rawSql"].replace(needle, replacement)
    now = int(time.time() * 1000)
    start = now - period_ms
    target.update(refId="A", intervalMs=max(1000, period_ms // 120), maxDataPoints=120)
    result = request(config, "/api/ds/query", {
        "from": str(start), "to": str(now), "queries": [target],
    })["results"]["A"]
    if result.get("error"):
        raise ValueError(result["error"])
    return panel, result.get("frames", []), start, now


def threshold_color(panel, value):
    steps = panel.get("fieldConfig", {}).get("defaults", {}).get("thresholds", {}).get("steps", [])
    name = "blue"
    for step in steps:
        if step.get("value") is None or value >= step["value"]:
            name = step["color"]
    return {"green": "#a3be8c", "yellow": "#ebcb8b", "orange": "#d08770",
            "red": "#bf616a", "dark-red": "#bf616a", "blue": "#88c0d0"}.get(name, name)


def render(config, key, period_index, cache_dir, plot_width):
    chart = config.get("charts", {}).get("co2" if key == "co2_value" else key)
    tile = chart or config["values"][key]
    periods = config["periods"]
    period = periods[period_index % len(periods)] if chart else None
    if chart:
        period_ms = period["ms"]
    elif tile.get("range") == "today":
        now = datetime.now()
        period_ms = max(1000, int((now - now.replace(hour=0, minute=0, second=0, microsecond=0)).total_seconds() * 1000))
    else:
        period_ms = 24 * 3600 * 1000
    panel, frames, start, end = query(config, tile, period_ms)
    if not chart:
        points = extract_points(frames, tile.get("field"), synthetic_time=end)
        latest = points[-1] if points else None
        text = tile.get("format", "%.1f") % latest[1] if latest else "—"
        color = threshold_color(panel, latest[1]) if latest and end - latest[0] <= 15 * 60 * 1000 else "#d8dee9"
        return {"value": text, "color": color}

    series = [extract_points(frames, item.get("field"), True) for item in tile["series"]]
    series = [[p for p in points if start <= p[0] <= end] for points in series]
    if key == "co2_value":
        latest = series[0][-1] if series[0] else None
        return {"value": "%.0f%s" % (latest[1], tile.get("unit", "")) if latest else "—",
                "color": "#88c0d0"}
    low, high = bounds(series, tile.get("axis_from_zero", False))
    fmt = "%." + str(tile.get("axis_decimals", 0)) + "f"
    path = cache_dir / f"{key}-{os.getpid()}-{time.time_ns()}.svg"
    path.write_text(svg(series, start, end, plot_width, from_zero=tile.get("axis_from_zero", False)))
    legends = [item["alias"] + "  " + ("%.1f" % points[-1][1] + tile.get("unit", "") if points else "—")
               for item, points in zip(tile["series"], series)]
    return {"chart": str(path), "high": fmt % high if high is not None else "—",
            "low": fmt % low if low is not None else "—", "legend1": legends[0],
            "legend2": legends[1] if len(legends) > 1 else "", "period": period["label"]}


def main(config_path, cache_path, key, period_path, plot_width):
    try:
        config = json.loads(Path(config_path).read_text())
        cache_dir = Path(cache_path)
        cache_dir.mkdir(parents=True, exist_ok=True)
        period_index = int(Path(period_path).read_text()) if Path(period_path).exists() else 0
        result = render(config, key, period_index, cache_dir, int(plot_width))
        for old in cache_dir.glob("*.svg"):
            if time.time() - old.stat().st_mtime > 300:
                old.unlink()
        print(json.dumps(result))
    except (OSError, ValueError, KeyError, StopIteration, IndexError, TypeError) as exc:
        print(f"dashboard {key}: {exc}", file=sys.stderr)
        print(json.dumps({"chart": "", "high": "—", "low": "—", "legend1": "—", "legend2": "",
                          "period": "?", "value": "—", "color": "#d8dee9"}))


if __name__ == "__main__":
    main(*sys.argv[1:6])

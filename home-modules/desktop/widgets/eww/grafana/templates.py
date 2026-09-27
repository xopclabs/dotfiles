"""Map named source fields into Eww chart and value view models."""
import os
import time

COLORS = ("#88c0d0", "#a3be8c")


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


def threshold_color(steps, value):
    name = "blue"
    for step in steps:
        if step.get("value") is None or value >= step["value"]:
            name = step["color"]
    return {"green": "#a3be8c", "yellow": "#ebcb8b", "orange": "#d08770",
            "red": "#bf616a", "dark-red": "#bf616a", "blue": "#88c0d0"}.get(name, name)


def present(template, definition, data, cache_dir, plot_width, field=None):
    fields = data["fields"]
    end = data["end"]
    if template == "value":
        selected = field or next(iter(fields))
        latest = fields[selected][-1] if fields[selected] else None
        text_format = definition.get("value_format")
        text = ((text_format % latest[1]) if text_format else
                ("%.0f%s" % (latest[1], definition.get("unit", "")))) if latest else "—"
        color = (threshold_color(definition.get("thresholds", []), latest[1])
                 if latest and end - latest[0] <= 15 * 60 * 1000 else "#d8dee9")
        return {"value": text, "color": color}
    if template != "chart":
        raise ValueError(f"Unknown template: {template}")
    series = [[p for p in fields[item["field"]] if data["start"] <= p[0] <= end]
              for item in definition["series"]]
    low, high = bounds(series, definition.get("axis_from_zero", False))
    fmt = "%." + str(definition.get("axis_decimals", 0)) + "f"
    path = cache_dir / f"chart-{os.getpid()}-{time.time_ns()}.svg"
    path.write_text(svg(series, data["start"], end, plot_width,
                        from_zero=definition.get("axis_from_zero", False)))
    legends = [item["alias"] + "  " + ("%.1f" % points[-1][1] + definition.get("unit", "") if points else "—")
               for item, points in zip(definition["series"], series)]
    return {"chart": str(path), "high": fmt % high if high is not None else "—",
            "low": fmt % low if low is not None else "—", "legend1": legends[0],
            "legend2": legends[1] if len(legends) > 1 else "", "period": data["period"]["label"]}

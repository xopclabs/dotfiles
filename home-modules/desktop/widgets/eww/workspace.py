#!/usr/bin/env python3
"""Show Eww dashboard pages only on the named workspace of one output."""
import fcntl
import json
import os
import signal
import subprocess
import sys
import time


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def page_for(workspaces, output, pages):
    for workspace in workspaces:
        if workspace.get("output") == output and workspace.get("is_active"):
            return pages.get(workspace.get("name"))
    return None


def get_workspaces():
    result = subprocess.run(["niri", "msg", "--json", "workspaces"],
                            capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def noctalia(visible):
    return subprocess.run(["noctalia", "msg", "desktop-widgets-show" if visible else "desktop-widgets-hide"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False).returncode == 0


def follow(output, pages, eww, config_dir):
    # Niri may start another dashboard watcher while a previous one is still
    # shutting down (for example during bar-restart). Only one may own Eww.
    lock_path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "eww-dashboard-watcher.lock")
    lock = open(lock_path, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return

    hidden = False
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try:
        while True:
            workspaces = []
            current = object()
            stream = None
            try:
                stream = subprocess.Popen(["niri", "msg", "--json", "event-stream"],
                                          stdout=subprocess.PIPE, text=True)
                for line in stream.stdout:
                    event = json.loads(line)
                    if not ("WorkspacesChanged" in event or "WorkspaceActivated" in event):
                        continue
                    # Query compositor state instead of applying deltas to a
                    # potentially stale event-stream snapshot.
                    workspaces = get_workspaces()
                    page = page_for(workspaces, output, pages)
                    if page == current:
                        continue
                    current = page
                    # Eww may return failure when there are no windows to close.
                    subprocess.run([eww, "--config", config_dir, "close-all"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                    if page is not None and not hidden:
                        hidden = noctalia(False)
                    elif page is None and hidden:
                        hidden = not noctalia(True)
                    if page == "chart":
                        run(eww, "--config", config_dir, "open-many", "co2_chart",
                            "temperature_chart", "humidity_value", "today_power", "power_chart")
                        run(eww, "--config", config_dir, "poll", "co2_data", "temperature_data",
                            "humidity_data", "today_power_data", "power_data")
                    elif page == "value":
                        run(eww, "--config", config_dir, "open", "dashboard")
                        run(eww, "--config", config_dir, "poll", "co2_value")
            except (OSError, subprocess.CalledProcessError, ValueError, KeyError) as exc:
                print(f"dashboard workspace watcher: {exc}", file=sys.stderr)
            finally:
                if stream is not None and stream.poll() is None:
                    stream.terminate()
                    stream.wait()
            time.sleep(2)
    finally:
        if hidden:
            noctalia(True)


if __name__ == "__main__":
    follow(sys.argv[1], {"telemetry": "chart", "telemetry-value": "value"}, sys.argv[2], sys.argv[3])

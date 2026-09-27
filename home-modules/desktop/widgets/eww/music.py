#!/usr/bin/env python3
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid
import urllib.error
import urllib.parse
import urllib.request

CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "eww-dashboard"


def playerctl(*args):
    return subprocess.run(["playerctl", *args], capture_output=True, text=True).stdout.strip()


def active_player():
    players = [p for p in playerctl("-l").splitlines() if not p.lower().startswith("firefox")]
    return next((p for p in players if playerctl("-p", p, "status") == "Playing"), players[0] if players else "")


def lyrics(artist, title):
    if not artist or not title:
        return ""
    cache = CACHE / "synced-lyrics"
    cache.mkdir(parents=True, exist_ok=True)
    file = cache / hashlib.sha256(f"{artist}\0{title}".encode()).hexdigest()
    if file.exists():
        return file.read_text()
    url = "https://lrclib.net/api/get?" + urllib.parse.urlencode({"artist_name": artist, "track_name": title})
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "eww-dashboard/1.0"})
        with urllib.request.urlopen(req, timeout=2) as response:
            text = json.load(response).get("syncedLyrics") or ""
        file.write_text(text)
        return text
    except urllib.error.HTTPError as error:
        if error.code == 404:
            file.write_text("")
        return ""
    except (OSError, ValueError):
        return ""


def lyric_lines(text, position):
    timed = []
    for line in text.splitlines():
        match = re.match(r"^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$", line)
        if match and match[3]:
            timed.append((int(match[1]) * 60 + float(match[2]), match[3]))
    if not timed:
        return {"previous": "", "current": "", "next": "", "pending": False, "has_lyrics": False, "index": -1}
    index = max((i for i, (time, _) in enumerate(timed) if time <= position), default=-1)
    return {"previous": timed[index - 1][1] if index > 0 else "",
            "current": timed[max(index, 0)][1],
            "next": timed[max(index, 0) + 1][1] if max(index, 0) + 1 < len(timed) else "",
            "pending": index < 0, "has_lyrics": True, "index": index}


def lyric_frames(lines, key):
    """Keep the outgoing verse for GtkStack's slide transition."""
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", str(CACHE)))
    runtime.mkdir(parents=True, exist_ok=True)
    file = runtime / "eww-dashboard-lyric-frames.json"
    try:
        previous = json.loads(file.read_text())
    except (OSError, ValueError):
        previous = {}
    slot = previous.get("slot", 0)
    frames = previous.get("frames", [lines, lines])
    if len(frames) != 2:
        frames = [lines, lines]
    if previous.get("key") != key:
        slot = 1 - slot if previous else 0
        frames[slot] = lines
    result = {"key": key, "slot": slot, "frames": frames}
    temp = file.with_suffix(".tmp")
    temp.write_text(json.dumps(result))
    temp.replace(file)
    return {"lyric_slot": slot, "lyrics0": frames[0], "lyrics1": frames[1]}


def album_art(url):
    if url.startswith("file://"):
        path = urllib.parse.unquote(urllib.parse.urlparse(url).path)
        return path if Path(path).is_file() else ""
    if not url.startswith(("https://", "http://")):
        return ""
    cache = CACHE / "art"
    cache.mkdir(parents=True, exist_ok=True)
    file = cache / (hashlib.sha256(url.encode()).hexdigest() + ".jpg")
    if not file.exists():
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "eww-dashboard/1.0"})
            with urllib.request.urlopen(req, timeout=2) as response:
                data = response.read(5 * 1024 * 1024 + 1)
            if len(data) > 5 * 1024 * 1024:
                return ""
            temp = file.with_suffix(".tmp")
            temp.write_bytes(data)
            temp.replace(file)
        except (OSError, ValueError):
            return ""
    return str(file)


def state():
    player = active_player()
    separator = "\x1f"
    fields = playerctl("-p", player, "metadata", "--format",
                       "{{artist}}" + separator + "{{title}}" + separator + "{{mpris:artUrl}}") if player else ""
    artist, title, art_url = (fields.split(separator) + ["", "", ""])[:3]
    art = album_art(art_url)
    try:
        position = float(playerctl("-p", player, "position")) if player else 0
    except ValueError:
        position = 0
    lines = lyric_lines(lyrics(artist, title), position) if player else lyric_lines("", 0)
    key = [player, artist, title, lines["index"]]
    frames = lyric_frames(lines, key)
    print(json.dumps({"player": player, "artist": artist or "No artist", "title": title or "Nothing playing",
                      "art": art, "playing": playerctl("-p", player, "status") == "Playing" if player else False,
                      "has_lyrics": lines["has_lyrics"], **frames}))


def feedback(icon):
    config = os.environ.get("EWW_DASHBOARD_CONFIG")
    eww = os.environ.get("EWW_BIN")
    if not config or not eww:
        return
    token = uuid.uuid4().hex
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", str(CACHE)))
    runtime.mkdir(parents=True, exist_ok=True)
    (runtime / "eww-dashboard-music-feedback").write_text(token)
    subprocess.run([eww, "--config", config, "update", f"music_feedback={icon}"], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.Popen([sys.executable, __file__, "feedback-clear", token], start_new_session=True,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def clear_feedback(token):
    time.sleep(0.7)
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", str(CACHE)))
    try:
        if (runtime / "eww-dashboard-music-feedback").read_text() == token:
            subprocess.run([os.environ["EWW_BIN"], "--config", os.environ["EWW_DASHBOARD_CONFIG"],
                            "update", "music_feedback="], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, KeyError):
        pass


def art_click():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", str(CACHE)))
    runtime.mkdir(parents=True, exist_ok=True)
    lock_path = runtime / "eww-dashboard-music-click.lock"
    state_path = runtime / "eww-dashboard-music-click.json"
    now = time.monotonic()
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            pending = json.loads(state_path.read_text())
        except (OSError, ValueError):
            pending = {}
        if now - pending.get("time", -100) < 0.28:
            state_path.unlink(missing_ok=True)
            double = True
        else:
            token = uuid.uuid4().hex
            state_path.write_text(json.dumps({"time": now, "token": token}))
            double = False
    if double:
        feedback("open")
        focus(active_player())
    else:
        player = active_player()
        feedback("pause" if player and playerctl("-p", player, "status") == "Playing" else "play")
        subprocess.Popen([sys.executable, __file__, "art-worker", token],
                         start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def art_worker(token):
    time.sleep(0.30)
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", str(CACHE)))
    with (runtime / "eww-dashboard-music-click.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state_path = runtime / "eww-dashboard-music-click.json"
        try:
            pending = json.loads(state_path.read_text())
        except (OSError, ValueError):
            return
        if pending.get("token") != token:
            return
        state_path.unlink(missing_ok=True)
    player = active_player()
    if player:
        subprocess.run(["playerctl", "-p", player, "play-pause"], check=False)


def focus(player):
    if not player:
        return
    try:
        windows = json.loads(subprocess.check_output(["niri", "msg", "-j", "windows"], text=True))
        name = player.split(".")[0].lower()
        matches = [w for w in windows if name in (w.get("app_id") or "").lower()]
        if matches:
            subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(matches[0]["id"])], check=False)
            return
    except (OSError, ValueError, subprocess.CalledProcessError):
        pass
    subprocess.Popen(["gtk-launch", player.split(".")[0]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "art-click":
        art_click()
    elif len(sys.argv) > 2 and sys.argv[1] == "art-worker":
        art_worker(sys.argv[2])
    elif len(sys.argv) > 2 and sys.argv[1] == "feedback-clear":
        clear_feedback(sys.argv[2])
    elif len(sys.argv) > 1 and sys.argv[1] in ("previous", "next"):
        player = active_player()
        if player:
            feedback(sys.argv[1])
            subprocess.run(["playerctl", "-p", player, sys.argv[1]], check=False)
    else:
        state()

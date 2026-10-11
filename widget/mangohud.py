#!/usr/bin/env python3
import os, time, json

STATS = os.path.expanduser("~/.cache/mangohud-stats")
STALE = 2.0

META = {
    "fps": {
        "name": "FPS", "short_name": "FPS", "prefix": "MangoHud",
        "min": 0, "max": 240, "unit": "-", "variant_type": "double",
    },
    "frametime": {
        "name": "Frametime (ms)", "short_name": "Frametime (ms)",
        "prefix": "MangoHud",
        "min": 0, "max": 50, "unit": "-", "variant_type": "double",
    },
}

def read():
    try:
        if time.time() - os.stat(STATS).st_mtime > STALE:
            return 0.0, 0.0
        with open(STATS) as f:
            d = json.load(f)
        return float(d.get("fps", 0.0)), float(d.get("frametime", 0.0))
    except Exception:
        return 0.0, 0.0

def value(key):
    fps, ft = read()
    return round(fps, 1) if key == "fps" else round(ft, 1)

def out(x):
    print(x, flush=True)

while True:
    try:
        req = input().strip().split("\t")
    except EOFError:
        break
    if req[0] == "?":
        out("fps\tframetime")
    elif req[0] in META:
        cmd = req[1] if len(req) > 1 else ""
        if cmd in ("value", "initial_value"):
            out(value(req[0]))
        elif cmd in META[req[0]]:
            out(META[req[0]][cmd])
        else:
            out("")
    else:
        out("")

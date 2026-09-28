#!/usr/bin/env python3
"""X96 Max: IR remote (evdev) -> mpv IPC bridge. Auto-detects meson-ir device."""
import json
import os
import socket
import struct
import time

EV_KEY = 0x01
SOCK = "/tmp/mpv.sock"
LOG = "/root/bridge.log"
VOL_KEYS = {115: 5, 114: -5, 103: 10, 108: -10}

KEYMAP = {
    28: ["cycle", "pause"],                              # OK
    164: ["cycle", "pause"],                             # PLAYPAUSE
    106: ["seek", 5, "relative"],                        # RIGHT
    105: ["seek", -5, "relative"],                       # LEFT
    139: ["script-binding", "stats/display-stats-toggle"],  # MENU
    102: ["playlist-next", "weak"],                      # HOME
    158: ["quit"],                                       # BACK
    116: ["quit"],                                       # POWER
}
for _i, _k in enumerate((2, 3, 4, 5, 6, 7, 8, 9, 10)):
    KEYMAP[_k] = ["playlist-play-index", _i]   # KEY_1..KEY_9
KEYMAP[11] = ["playlist-play-index", 9]        # KEY_0


def find_dev():
    try:
        for name in os.listdir("/sys/class/input"):
            if not name.startswith("event"):
                continue
            try:
                with open("/sys/class/input/%s/device/name" % name) as f:
                    if "meson-ir" in f.read():
                        return "/dev/input/" + name
            except OSError:
                pass
    except OSError:
        pass
    return None


def log_line(text):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%d.%m.%Y %H:%M:%S"), text))


def send(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(SOCK)
        s.sendall((json.dumps({"command": cmd}) + "\n").encode())
        s.close()
    except OSError:
        return
    log_line(json.dumps(cmd))


def request(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(SOCK)
        s.sendall((json.dumps({"command": cmd, "request_id": 1}) + "\n").encode())
        buf = b""
        rep = None
        while True:
            try:
                chunk = s.recv(4096)
            except socket.timeout:
                break
            if not chunk:
                break
            buf += chunk
            for line in buf.split(b"\n"):
                if not line.strip():
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    continue
                if obj.get("request_id") == 1:
                    rep = obj
            if rep is not None:
                break
        s.close()
        return rep
    except OSError:
        return None


def main():
    while True:
        dev = find_dev()
        if not dev:
            time.sleep(2)
            continue
        try:
            fd = os.open(dev, os.O_RDONLY)
        except OSError:
            time.sleep(2)
            continue
        while True:
            try:
                data = os.read(fd, 24)
            except OSError:
                break
            if len(data) < 24:
                continue
            _s, _u, etype, code, val = struct.unpack("llHHi", data)
            if etype == EV_KEY and val == 1:
                if code in VOL_KEYS:
                    request(["add", "volume", VOL_KEYS[code]])
                    rep = request(["get_property", "volume"])
                    if rep and "data" in rep:
                        send(["show-text", "Громкость: %.0f%%" % rep["data"], 1500])
                    log_line("volume_key %d" % code)
                else:
                    cmd = KEYMAP.get(code)
                    if cmd:
                        send(cmd)
        os.close(fd)


if __name__ == "__main__":
    main()

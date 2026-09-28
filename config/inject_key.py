import struct
import sys
import time
import os

EV_KEY = 1
EV_SYN = 0
SYN_REPORT = 0


def ev(t, code, val):
    return struct.pack('<qqHHi', 0, 0, t, code, val)


path = sys.argv[1] if len(sys.argv) > 1 else '/dev/input/event1'
key = int(sys.argv[2]) if len(sys.argv) > 2 else 67
hold = float(sys.argv[3]) if len(sys.argv) > 3 else 0.15
fd = os.open(path, os.O_WRONLY)
os.write(fd, ev(EV_KEY, key, 1))
os.write(fd, ev(EV_SYN, SYN_REPORT, 0))
time.sleep(hold)
os.write(fd, ev(EV_KEY, key, 0))
os.write(fd, ev(EV_SYN, SYN_REPORT, 0))
os.close(fd)
print('injected key', key, 'hold', hold, 'to', path)

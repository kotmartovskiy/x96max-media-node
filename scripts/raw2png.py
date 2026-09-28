import sys
import zlib
import struct

raw_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/kms.raw'
dims = sys.argv[2] if len(sys.argv) > 2 else None
png_path = sys.argv[3] if len(sys.argv) > 3 else '/root/shots/kms.png'

if dims:
    W, H, PITCH = (int(x) for x in dims.split())
else:
    meta = open('/tmp/kms.meta').read().split()
    W, H, PITCH = int(meta[0]), int(meta[1]), int(meta[2])

data = open(raw_path, 'rb').read()
raw = bytearray()
for y in range(H):
    src = data[y * PITCH:y * PITCH + W * 4]
    raw.append(0)
    for x in range(0, W * 4, 4):
        raw += bytes((src[x + 2], src[x + 1], src[x], 255))


def chunk(t, d):
    return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)


png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(bytes(raw), 6))
png += chunk(b'IEND', b'')
open(png_path, 'wb').write(png)
print('ok', png_path, len(png))

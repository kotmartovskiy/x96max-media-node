#!/bin/sh
# Тест 4K: кодирует тест-клипы (если их нет) и прогоняет через mpv с метрами.
# Статус: VP9 4K hw ✅, H264 4K sw ✅, HEVC 4K hw ❌ (CMA — issue #3690, зависание -> kill).
set -e
FF=/root/ffmpeg-7.0.2-arm64-static/ffmpeg
cd /root

for v in "k4_hevc.mp4:libx265:-preset ultrafast -crf 30" "k4_h264.mp4:libx264:-preset ultrafast -crf 25" "k4_vp9.webm:libvpx-vp9:-deadline realtime -cpu-used 8 -b:v 10M"; do
  f=${v%%:*}; rest=${v#*:}; c=${rest%%:*}; opts=${rest#*:}
  [ -f "$f" ] || $FF -y -v error -f lavfi -i testsrc2=size=3840x2160:rate=30 -t 3 -c:v $c $opts -pix_fmt yuv420p "$f"
done

setterm -blank 0 2>/dev/null || true
for f in k4_vp9.webm k4_h264.mp4 k4_hevc.mp4; do
  echo "--- $f ---"
  timeout -k 3 40 script -qec "mpv --term-status-msg='T=\${time-pos} DROP=\${frame-drop-count}' /root/$f" /dev/null > "/tmp/t4_$f.log" 2>&1
  echo "rc=$?"
  tr '\r' '\n' < "/tmp/t4_$f.log" | grep 'T=' | tail -2
done
echo "=== dmesg (CMA / abort) ==="
dmesg | grep 'dma alloc of size\|Unrecognized dec_status\|Aborting decoding' | tail -6

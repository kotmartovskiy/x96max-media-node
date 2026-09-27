#!/bin/sh
# Воспроизведение бага H.264 (issue #3690): hw-декод уходит в вечный цикл.
# Ожидание: процесс не завершается сам (kill по timeout), dmesg захлебнётся строками.
timeout 6 mpv --no-config --vo=null --hwdec=v4l2m2m-copy --hwdec-codecs=h264 test_h264.mp4
echo "mpv rc=$? (124 = убит timeout'ом = зависание)"
echo "строк цикла в dmesg: $(dmesg | grep -c 'H.264 source resume')"
dmesg | grep 'H.264 source resume' | head -3
dmesg | grep 'H.264 hardware start pending\|H.264 firmware source restart' | head -3

#!/bin/sh
# Тест синхронизации: VF (декод), DISP (дисплей), DROP
mpv --no-config --fs --vo=gpu --gpu-context=drm --hwdec=no --scale=bilinear --cscale=bilinear --dither-depth=no --vd-lavc-threads=4 --video-sync=display-resample --display-fps=60 --term-status-msg='T=${time-pos} VF=${estimated-vf-fps} DISP=${estimated-display-fps} DROP=${frame-drop-count}' "$1"

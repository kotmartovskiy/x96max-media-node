#!/bin/sh
# Установка (обновление) firmware для meson-vdec с jefflessard/meson-vdec-extra
# Запускать на боксе от root. Проверяет размеры — они должны совпадать с константами драйвера.
set -e
FW=/lib/firmware/meson/vdec
REV=f23e523ba82e3fd0701f995896c7776b388e4f74
BASE="https://cdn.jsdelivr.net/gh/jefflessard/meson-vdec-extra@$REV/firmware/meson/vdec-new"

mkdir -p "$FW"

# HEVC MMU multi: в апстриме файла "g12a_hevc_mmu_multi" нет — исходник называется _swap
curl -fL "$BASE/g12a_hevc_mmu_swap.bin" -o "$FW/g12a_hevc_mmu_multi.bin"

# H264 multi (если репо его отдаёт; иначе положите файл вручную)
curl -fL "$BASE/g12a_h264_multi.bin" -o "$FW/g12a_h264_multi.bin" || \
  echo "ВНИМАНИЕ: g12a_h264_multi.bin не скачался — возьмите его из выдачи issue #3690"

echo "=== Проверка размеров (константы драйвера) ==="
sz() { stat -c '%s %n' "$1"; }
sz "$FW/g12a_h264_multi.bin"     # ожидается 28672 = H264_MULTI_FW_SIZE
sz "$FW/g12a_hevc_mmu_multi.bin" # ожидается 40960

# Ловушка: НЕ оставляйте бэкапы вида *.debian/ *.bak В ЭТОМ каталоге —
# ldconfig может перевести симлинк на них и mpv будет грузить чужую библиотеку.
ls -la "$FW"

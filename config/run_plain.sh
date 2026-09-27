#!/bin/sh
# Запуск с метрами: время, DROP-кадры, активный hwdec
mpv --term-status-msg='T=${time-pos} DROP=${frame-drop-count} HW=${hwdec}' "$1"

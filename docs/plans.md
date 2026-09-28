# Планы

## Сделано
- Фаза 0–1: SD/SSH, чек-лист железа, u-boot env, диагностика сдвига картинки (отложена пользователем)
- Прошивки vdec → HEVC-hw работает; VP9-hw подтверждён (в т.ч. 4K)
- mpv: libav-фикc, conf с display-resample, DROP=0 на 1080p и 4K (vp9/h264-sw)
- Issue #3690 в ophub (H.264-livelock + 4K-HEVC CMA)
- **ИК-пульт**: 33/33 кнопки (EV_KEY), keymap персистентен, Power не гасит
  бокс (logind), мост пульт→mpv (`mpv-remote.service`) — см. [ir-remote.md](ir-remote.md)
- **HDMI-звук** подтверждён (AO alsa, hw:0,0, 48kHz stereo)
- **Передняя панель FD628**: драйвер tm16xx собран и работает, часы
  (`display.service`) — см. [vfd-display.md](vfd-display.md)
- **Kodi 20.1 + RetroArch 1.14 + libretro-ядра** установлены (apt)

## Дальше

1. **Kodi / Retrogaming** — первый запуск (`kodi --standalone` на DRM/panfrost,
   hwdec в инфо-экране), RetroArch: video_driver (gl/gles/kms), пульт как
   контроллер, тест ROM (пиратские не качаем)
2. **Ребут-тест персистентности** — проверить после power-cycle: модули панели
   (modules-load.d), `display.service`, `ir-keymap.service`, `mpv-remote.service`
3. **HDD / фаза 2** — ждём БП 3A (через несколько дней): корень + данные
   (двойная загрузка через флаг env)
4. **Реальное видео** — пользователь проверяет фильмы (1080p/4K) на глаз
5. **Issue #3690** — следить за ответом ophub; при необходимости дописать
   логи, проверить фикс на свежих сборках (H.264-hw = главный выигрыш)
6. **Камеры, DVB-T2, SDR** — как железо появится
7. Сдвиг картинки (ViewSonic) — вернуться, когда будет удобно

## Риски / долги
- Обновление ядра ophub ломает внешние модули (vermagic) → повторить
  `scripts/setup-ophub-headers.sh` + `scripts/build-tm16xx.sh`
- 4K HEVC hw не работает (CMA) — либо больше CMA в ядре, либо SW-декод
- MPEG-2 hw мёртв — эмуляторы/старое видео только SW
- Системный libav подменён вручную → `apt upgrade ffmpeg` затрёт фикс
  (см. mpv-setup.md §1; бэкап: `/root/libavcodec59.debian-backup`)
- Токены из чата — отозвать (https://github.com/settings/tokens)

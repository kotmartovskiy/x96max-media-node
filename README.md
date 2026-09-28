# X96 Max — медиа-узел (Armbian, Amlogic S905X2)

Вторая ОС на TV-приставке X96 Max: Armbian (ядро `6.18.51-ophub`, ophub/dec24) как
автономный узел — медиа-плеер, ретро, LAN Recovery, камеры, DVB-T2, SDR.
План: dual-boot c Android через флаг-переключатель, SD = загрузка, USB HDD =
корень + данные, eMMC Android не трогается.

## Статус

| Компонент | Состояние |
|---|---|
| Фаза 0–1 (SD/SSH, чек-лист железа, u-boot env) | ✅ done |
| HEVC hw (≤1080p) | ✅ 18.8× realtime |
| VP9 hw (≤4K) | ✅ 17.3× realtime, 4K проигрывается |
| H.264 hw | ❌ livelock в драйвере → [issue #3690](https://github.com/ophub/amlogic-s9xxx-armbian/issues/3690) |
| H.264 SW (≤4K) | ✅ плавно (DROP=0) |
| 4K HEVC hw | ❌ CMA 256MB мало под DPB → тоже #3690 |
| MPEG-2 hw | ❌ «Buffer N done but it doesn't exist in m2m_ctx» |
| mpv-стек (libav-фикc, conf, синхронизация) | ✅ см. [docs/mpv-setup.md](docs/mpv-setup.md) |
| ИК-пульт (33 кнопки, keymap + мост в mpv) | ✅ см. [docs/ir-remote.md](docs/ir-remote.md) |
| Передняя панель FD628 (часы, индикаторы) | ✅ см. [docs/vfd-display.md](docs/vfd-display.md) |
| Kodi 20.1 / RetroArch 1.14 | ⏳ установлены, первый запуск в процессе |
| HDD / камеры / DVB / SDR | ⏳ планы, см. [docs/plans.md](docs/plans.md) |

## Структура

```
docs/    — железо, статус кодеков, mpv, ИК-пульт, панель FD628, планы
config/  — рабочие конфиги с бокса (mpv.conf, обвязки, ld-fix)
scripts/ — воспроизводимые скрипты (прошивки, libav-фикс, тесты)
issue/   — черновик issue для ophub (опубликован как #3690)
```

## Быстрый старт (на боксе)

```sh
mpv <файл>   # hevc/vp9 — аппаратно, h264 — плавный SW
```

Конфиг и обвязки лежат в `config/`, установка — в [docs/mpv-setup.md](docs/mpv-setup.md).

## Ссылки

- Issue: https://github.com/ophub/amlogic-s9xxx-armbian/issues/3690
- Ядро: https://github.com/ophub/linux-6.18.y (драйвер `drivers/staging/media/meson/vdec`, commit `fb220895`)
- Прошивки vdec: https://github.com/jefflessard/meson-vdec-extra
- libav-фикс: https://github.com/FFmpeg/FFmpeg/commit/4fa1d3e7910c3fbe3aacbe5ae5233d0067569c02 (trac#9957)

> Доступы (SSH/WiFi) в этот репозиторий не включены.

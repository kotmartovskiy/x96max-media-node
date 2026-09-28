# Retrogaming (RetroArch) — статус

## Работает (проверено 28.09.2026)

- RetroArch 1.14.0, запуск: `nohup retroarch -v > /root/ra.log 2>&1 &`
  (нужен DRM master — сначала остановить Kodi/mpv).
- Собранные драйверы: **OpenGL, OpenGLES, EGL, KMS, Wayland, SDL2, X11** — yes;
  Vulkan/Metal/SDL1 — no.
- `/root/.config/retroarch/retroarch.cfg` (написан вручную до первого запуска):
  ```sh
  video_driver = "gl"        # контекст: "Found GL context: kms" ✓
  audio_driver = "alsa"      # S16, pause ✓
  input_driver = "udev"
  network_cmd_enable = "true"
  network_cmd_port = "55355"
  log_verbosity = "true"
  ```
- udev видит пульт: `[udev]: Keyboard #1: "meson-ir" (/dev/input/event1)` —
  **стрелки пульта = дефолтная клавиатурная навигация меню**.

## Ловушки окружения (все вылечены симлинками/правкой cfg)

1. **Ассеты**: пакет `retroarch-assets` стоял, но файлы лежат в
   `/usr/share/libretro/assets`, а cfg ждёт `~/.config/retroarch/assets`.
   Пустая папка → **меню не поднимается**, RA молча в idle (чёрный экран,
   ни строки про menu в логе). Лечение:
   `rmdir ~/.config/retroarch/assets && ln -s /usr/share/libretro/assets ~/.config/retroarch/assets`.
2. **Ядра**: пакеты кладут `.so` в `/usr/lib/aarch64-linux-gnu/libretro/`,
   cfg ждёт `~/.config/retroarch/cores` (пусто!) → симлинк каталога.
   8 ядер: nestopia, gambatte, genesis_plus_gx, mednafen_psx, mgba, snes9x,
   beetle-psx (+ `*.libretro` инфо-файлы рядом).
3. `libretro_info_path` → `/usr/share/libretro/info` (sed по cfg).
4. Невинные ошибки на старте: Wayland (нет композитора), MIDI
   (`/dev/snd/seq` отсутствует) — не мешают.

## UDP-команды (порт 55355)

`python3 /root/ra_udp.py <CMD>` — UDP-пакет в localhost.
Распознанные: `SCREENSHOT`, `QUIT`, `RESET`, `MUTE`, `PAUSE`…
Неверное имя → `[WARN] Unrecognized command` (живость интерфейса).

**ПРОБЛЕМА (не решена):** `SCREENSHOT` распознаётся молча, но файл не
создаётся — по strace **ноль** fs-операций (обработчик no-op). Помогли ни
инъекция F8 (`input_screenshot`), ни `video_gpu_screenshot=false`.

## Канал инъекции клавиш (для тестов без физического пульта)

```sh
python3 /root/inject_key.py /dev/input/event1 <KEYCODE>
```
Пишет EV_KEY down/up + EV_SYN напрямую в evdev-узел. Доставляется **всем**
слушателям одновременно:

- мост mpv → лог `/root/bridge.log` (`volume_key 115` ✓);
- RetroArch → доказано strace: `read(14, ...) = 72` (3 события × 24 байта).

Коды: `F8=67` (скриншот RA), `VOL+=115`, `ESC=1`, `ENTER=28`,
`UP=103`, `DOWN=108`, `LEFT=105`, `RIGHT=106`, `POWER=116` (logind=ignore).
Этим же каналом проверяется «пульт → RA» без участия рук юзера
(доставка доказана; реакцию меню глазами не видели — нет рабочего
скриншота).

## DRM master

RA и Kodi — взаимоисключающие (кто держит /dev/dri/card0).
Цикл переключения: `pkill -9 -x kodi.bin` → запуск RA → обратно.

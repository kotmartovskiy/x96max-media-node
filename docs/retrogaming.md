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
- Joypad-драйвер: `[Joypad]: Found joypad driver: "udev"` — **геймпад USB
  подключится автоматически** (пользователь принесёт свой позже): раскладку
  и бинды проверить в меню после подключения.

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
**Обходной путь:** снимать экран общим KMS-захватом — [kmsgrab.md](kmsgrab.md).

## Канал инъекции клавиш (навигация RA без физического пульта)

```sh
python3 /root/inject_key.py /dev/input/event1 <KEYCODE> [hold=0.15]
```
Пишет EV_KEY down + EV_SYN, **держит `hold` секунд**, затем up + EV_SYN.
Доставляется **всем** слушателям одновременно (мост → `/root/bridge.log`,
RA → udev Keyboard #1).

⚠️ **Ловушка: без удержания инъекция НЕ работает в RA.** Если down и up
уйти в одном миллисекунде, 60-Гц поллинг RA видит только финальное состояние
(клавиша отпущена) и ребро пропускает — мост (читает сырые события) при этом
реагирует, что вводит в заблуждение. Лечение: hold ≥ 100 мс (по умолчанию 150).

Навигация **доказана kmsgrab-скриншотами** (см. [kmsgrab.md](kmsgrab.md)):

- `DOWN=108` → выделение с Load Core на Load Content ✓;
- `ENTER=28` → открыт Load Content (Start Directory/Playlists/диски) ✓;
- `BACKSPACE=14` → назад в Main Menu ✓.

Коды: `ENTER=28` (OK), `BACKSPACE=14` (назад), `ESC=1` (**в меню RA не
биндится** — не работает), `UP=103`, `DOWN=108`, `LEFT=105`, `RIGHT=106`,
`F8=67` (скриншот), `VOL+=115`, `POWER=116` (logind=ignore).

## DRM master

RA и Kodi — взаимоисключающие (кто держит /dev/dri/card0).
Цикл переключения: `pkill -9 -x kodi.bin` → запуск RA → обратно.

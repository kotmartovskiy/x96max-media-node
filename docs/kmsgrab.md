# KMS-захват экрана (kmsgrab) — «глаза» для тестов без рук юзера

Обходной путь для сломанных скриншотов Kodi и RA: читаем framebuffer напрямую
через DRM PRIME (GETFB2 + PRIME-дескриптор + mmap) — **без DRM master-прав**,
поэтому работает при любом DRM master (mpv/Kodi/RA).

## Инструменты (лежат в /root)

- `kmsgrab.c` → бинарь `/root/kmsgrab`:
  ```sh
  gcc -O2 -I/usr/include/libdrm -o /root/kmsgrab /root/kmsgrab.c -ldrm
  ```
  Печатает в stdout `W H pitch` (мусор от libdrm в stderr не мешает),
  буфер пишет в файл. Поле структуры называется `pitches` (не `pitch`).
- `raw2png.py` — конверт BGRX→RGBA (zlib):
  ```sh
  python3 /root/raw2png.py <raw> "<W H PITCH>" <out.png>
  ```

## Рабочая команда (скриншот текущего экрана)

```sh
/root/kmsgrab /tmp/kms.raw > /tmp/kms.meta
python3 /root/raw2png.py /tmp/kms.raw "$(cat /tmp/kms.meta)" /root/shots/kmsN.png
```

Затем `pscp` файла на ПК и Read (картинка проверяется глазами ассистента).

## Ловушки

1. **`/dev/fb0` бесполезен** — там старая консоль (лог загрузки), не картинка
   Kodi/RA/mpv.
2. **ffmpeg kmsgrab нерабочий**: даёт `wrapped_avframe`/`drm_prime` без
   `hw_frames_ctx` — любые цепочки фильтров/конверсий падают. Свой C-скрипт
   надёжнее.
3. fb меняется между кадрами (fb=48/49/51…), но содержимое всегда актуальный
   кадр выбранного CRTC.

## Что подтверждено kmsgrab-скриншотами

- RA: главное меню Ozone отрисовано, навигация инъекцией клавиш
  (см. [retrogaming.md](retrogaming.md));
- Kodi: главное меню Estuary после перезапуска (состояние восстановлено).

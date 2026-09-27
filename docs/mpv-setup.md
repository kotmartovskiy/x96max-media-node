# MPV-стек: сборка, фиксы, конфиг

## 1. Фикс libavcodec (segfault mpv)

Проблема: Debian ffmpeg 5.1 без патча trac#9957 → mpv с v4l2m2m падает `rc=139`
(«crash when buffers are uninitialized», poll POLLERR).

Патч: https://github.com/FFmpeg/FFmpeg/commit/4fa1d3e7910c3fbe3aacbe5ae5233d0067569c02

```sh
cd /root/build
wget http://deb.debian.org/debian/pool/main/f/ffmpeg/ffmpeg_5.1.9.orig.tar.xz
tar xf ffmpeg_5.1.9.orig.tar.xz && cd ffmpeg-5.1.9
curl -L https://github.com/FFmpeg/FFmpeg/commit/4fa1d3e7910c3fbe3aacbe5ae5233d0067569c02.patch | patch -p1
./configure
make -j4
```

Установка (ВАЖНО — см. ловушку ниже):

```sh
SYS=/lib/aarch64-linux-gnu/libavcodec.so.59.37.100
cp -a "$SYS" /root/libavcodec59.debian-backup   # бэкап ВНЕ каталога библиотек!
cp libavcodec.so.59.37.100 /opt/mpv/            # эталонная копия
cp libavcodec.so.59.37.100 "$SYS"               # подмена системного
ls -la /lib/aarch64-linux-gnu/libavcodec.so.59  # symlink должен -> .59.37.100
ldconfig
md5sum "$SYS" /opt/mpv/libavcodec.so.59.37.100  # должны совпасть
```

### Ловушка ldconfig (прошлое расследование)

Если бэкап `.debian` лежит **в том же каталоге**, `ldconfig` может перевести
симлинк `libavcodec.so.59 → libavcodec.so.59.37.100.debian` («.debian» кажется
более новой версией) — и весь mpv молча грузит непатченную библиотеку.
Симптом: `rc=139` на любом hw-воспроизведении при md5 «вроде правильном».
Проверка: `readlink -f /lib/.../libavcodec.so.59` + `LD_DEBUG=libs mpv ... | grep avcodec`.

## 2. mpv.conf (с бокса, /root/.config/mpv/mpv.conf)

```ini
hwdec=v4l2m2m-copy
hwdec-codecs=hevc,vp9      # h264 ИЗАТЧЕН от hw (сломанный state-machine!)
vo=gpu
gpu-context=drm
video-sync=display-resample # КЛЮЧЕВОЕ: без этого DISP=(unavailable) и frame-drop-count растёт
display-fps=60
scale=bilinear
cscale=bilinear
dither-depth=no
vd-lavc-threads=4
fs
```

Почему так:
- `hwdec-codecs=hevc,vp9` — защита: plain `mpv` никогда не полезет в сломанный
  H.264-path (иначе — вечный цикл в драйвере и зависание)
- `video-sync=display-resample` — лечит рывки: mpv без vsync-тайминга сбрасывал
  кадры (наблюдалось: DROP=463 за ролик → стало DROP=0)
- билинейный скейл + 4 потока декодера — снимают нагрузку с A53 на 1080p SW

## 3. Обвязки (config/)

| Файл | Назначение |
|---|---|
| `mpvhw` | форс hw (для тестов), `--no-config`, LD_LIBRARY_PATH=/opt/mpv — теперь опционально |
| `run_plain.sh` | обычный запуск с метрами `T=… DROP=… HW=…` |
| `run_bbb_vs.sh` | тест синхронизации (аналоги DROP/VF/DISP) |

## 4. Проверка

```sh
mpv --term-status-msg='T=${time-pos} DROP=${frame-drop-count}' фильм.mkv
```

Ожидание: `DROP=0` на всём ролике; `VF≈контент-fps`. Падение/зависание → смотреть
`dmesg -w` (H.264-спам = драйвер полез в hw).

## 5. Тестовые файлы (в /root на боксе)

`test_h264.mp4`, `test_hevc.mp4`, `test_vp9.webm`, `test_vp9_hq.webm`,
`bbb1080.mp4` (реальный 1080p), `k4_h264.mp4`, `k4_hevc.mp4`, `k4_vp9.webm` (4K),
`ffmpeg-7.0.2-arm64-static/` (бенчер), `build/ffmpeg-5.1.9/` (исходники фикса).

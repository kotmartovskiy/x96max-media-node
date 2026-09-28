# Kodi на X96 Max — первый запуск

## Статус (28.09.2026)

- Kodi 20.1 (Debian `2:20.1+dfsg-1`), запуск:
  ```sh
  nohup kodi --standalone > /root/kodi.log 2>&1 &
  ```
  **DRM master — у одного процесса**: перед Kodi остановить mpv/RA, после — наоборот.
- Рендер: GBM/EGL + Panfrost Mali-G31, **desktop GL 3.1 compat** (не GLES!),
  `GL_RENDERER = Mali-G31 (Panfrost)` в логе.
- Аудио: ALSA `default`, `AE_FMT_S24NE4` ✓ (попытка `iec958` падает — неважно;
  предупреждения PipeWire на старте = шум, конфигов нет).
- Главное меню подтверждено пользователем на экране.
- JSON-RPC: `127.0.0.1:9090` (TCP, слушает по умолчанию).

## Ловушка: DRM PRIME hwdec НЕДОСТУПЕН (навсегда, для этой сборки)

В `/usr/share/kodi/system/settings/linux.xml` настройки
`videoplayer.useprimedecoder`, `useprimedecoderforhw`, `useprimerenderer`
имеют `<requirement>HAS_GLES</requirement>` — регистрируются **только при
GLES-рендере**. Но Debian-пакет собран **только с GL**:

- в бинаре один `CWinSystemGbmGLContext` (GLES-варианта нет);
- `libGLESv2` не линкуется;
- env `KODI_RENDER_SYSTEM`/`XBMC_RENDER_SYSTEM` бинарём не читаются.

Следствия (проверены):

- JSON-RPC `Settings.Get/SetSettingValue` для этих id → `-32602 Invalid params`;
- правка `guisettings.xml` **игнорируется** (значение откатывается);
- лог плеера: всегда `CDVDVideoCodecFFmpeg::Open` (SW), ноль упоминаний prime.

**Итог:** hwdec в Kodi = SW. 1080p нормально, 4K-HEVC — только mpv
(он использует аппаратный vdec ядра). Классы `CDVDVideoCodecDRMPRIME` в
бинаре есть, но до них не добраться.

⚠️ Правку `guisettings.xml` вручную делать только при **`pkill -9`**:
SIGTERM → Kodi сохранит старые in-memory значения поверх правки.

## Инструменты (лежат в /root)

- `krpc.py` — устойчивый JSON-RPC-клиент (raw_decode, игнор нотификаций).
  ⚠️ `Settings.GetSettings.properties` = **список id настроек**, а не полей
  значений (поэтому «count: 0» — это не ошибка сети).
- `kodi_play2.py` — плейбак файла с поллингом `Player.GetProperties` + Stop;
- `kodi_set.py`, `kodi_hwdec.py`, `kodi_probe2.py`, `kodi_gles_test.py` —
  прогоны настроек/скриншотов/логов;
- debug-лог: `/root/.kodi/userdata/advancedsettings.xml` с `<loglevel>0</loglevel>`
  → `/root/.kodi/temp/kodi.log` (уровень INFO по умолчанию не показывает
  имена декодеров).

## Скриншоты — НЕ работают (известный баг)

- Путь задан: `debug.screenshotpath = /root/shots` (иначе он пуст — в логе
  `screenshots folder:` без значения, и Kodi молча не пишет ничего).
- При `Input.ExecuteAction {"action":"screenshot"}` (возвращает OK) — ошибка:
  `Failed to CreateThumbnailFromSurface` + `CThumbnailWriter::DoWork unable to write`
  → создаётся **0-байтный** png. GL-readback/GBM — баг стека, не пути.
- `/dev/fb0` показывает **старую консоль** (лог загрузки), а не картинку Kodi.
- **Обходной путь — общий KMS-захват** [kmsgrab.md](kmsgrab.md): снимает
  экран без master-прав (работает при DRM master Kodi/RA/mpv). Контрольный
  скриншот главного меню Estuary после перезапуска (`/root/shots/kodi_menu.png`)
  — состояние восстановлено, RA остановлен.

## Медиа для тестов (в /root)

`bbb1080.mp4`, `sintel1080.mp4` (52 с), `test_h264.mp4`, `k4_h264.mp4`,
`k4_hevc.mp4`, `test_hevc.mp4`, `h264_annexb.mp4`.

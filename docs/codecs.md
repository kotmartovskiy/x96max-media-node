# Статус кодеков (meson-vdec, ядро 6.18.51-ophub)

## Матрица

| Кодек | Разрешение | Путь | Результат |
|---|---|---|---|
| HEVC | ≤1080p | hw (v4l2m2m) | ✅ 18.8× realtime (ffmpeg-бенч: 300/300 кадров) |
| HEVC | 4K | hw | ❌ `dma alloc of size 8323072 failed` — CMA 256MB исчерпывается под DPB, mpv зависает без кадра |
| VP9 | 1080p, 4K | hw | ✅ 17.3× realtime; 4K в mpv — DROP=0 |
| H.264 | любое | hw | ❌ **livelock**: state-machine крутится `source resume → hardware start pending (search_valid=0) → firmware source restart` бесконечно (596 строк dmesg за 6 сек), ни одного кадра |
| H.264 | ≤4K | sw | ✅ плавно (DROP=0, включая 4K testsrc2) |
| MPEG-2 | любое | hw | ❌ 1 кадр и `Buffer N done but it doesn't exist in m2m_ctx` (строки нет в upstream → весь драйвер = кастом ophub) |

## Что сделано для этого

1. **Прошивки vdec** (`/lib/firmware/meson/vdec/`, источник jefflessard/meson-vdec-extra@f23e523):
   - `g12a_h264_multi.bin` = 28672 байт — точная константа `H264_MULTI_FW_SIZE` (7×4K); handshake доходит до `config_valid=1`, но цикл не лечится размером
   - `g12a_hevc_mmu_multi.bin` = 40960 — взят `g12a_hevc_mmu_swap.bin` (тот же код, другое имя) → **HEVC заработал**
2. **mpv segfault** вылечен патчем trac#9957 (см. [mpv-setup.md](mpv-setup.md))
3. **Issue отправлен**: https://github.com/ophub/amlogic-s9xxx-armbian/issues/3690

## Выводы / уроки

- Livelock H.264 воспроизводится **и с корректным клиентом** (ffmpeg 7.0.2) → баг state-machine драйвера (WIP-код ophub от 25.08.2026, commit `fb220895`), не прошивки и не клиента. Лечится только в ядре.
- Коды возврата mpv/ffmpeg `rc=0` ничего не значат без проверки `frame=` / DROP-счётчиков: mpv печатает запрошенный `${hwdec}` ещё до codec-фильтра (показывает `v4l2m2m-copy` даже для SW-разбора). Истинный признак hw-сессии H.264 — рост строк в dmesg.
- Размер `g12a_h264.bin` (36864) не совпадает с multi (28672): «Expected 16384» в старых логах — это `MC_SIZE(4096*4)` из vdec_hevc.c (HEVC), а не H.264.
- `sm1_hevc_mmu_multi.bin` не нужен: sm1 ≠ наш SoC.

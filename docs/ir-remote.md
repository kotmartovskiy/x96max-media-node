# ИК-пульт X96 Max в Linux — готово

Пульт (NEC, custom `0xdf00`) распознаётся ядром `meson-ir` (`rc1`,
`/dev/input/event4`, LIRC `/dev/lirc0`). Кеймап собран из Android-эпохи
(файлы `ir10–ir38.sh`, `remote.df00.tab` через `remotecfg`) и перенесён
один-в-один: Linux-scancode = `0xDF` + старый low-byte
(`0x1c → 0xdf1c → KEY_POWER`).

## Статус

Все **33 кнопки** проверены по одной — каждая даёт `EV_KEY`, непереведённых
кодов нет (`ir-keytable -t -s rc1`, логи в `/root/irtest*.txt`).

## Установка (на боксе)

```sh
# 1. кеймап
ir-keytable -s rc1 -w /root/x96max.toml

# 2. персистентность (переживает ребут)
cp ir-keymap.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable ir-keymap.service

# 3. Power с пульта НЕ выключает бокс (logind по умолчанию делает poweroff)
sed -i 's/^#\?HandlePowerKey=.*/HandlePowerKey=ignore/' /etc/systemd/logind.conf
systemctl restart systemd-logind
```

Файлы: `config/rc/x96max.toml`, `config/systemd/ir-keymap.service`.

## Мост в mpv

`config/mpv-remote.py` (демон, systemd `mpv-remote.service`) **автоматически
находит** устройство `meson-ir` (номер `eventN` меняется после ребута!) и
шлёт JSON-команды в IPC-сокет mpv (`input-ipc-server=/tmp/mpv.sock` в
`mpv.conf`). Лог действий: `/root/bridge.log`.

| Кнопка | Действие в mpv |
|---|---|
| OK | пауза/продолжить |
| ← / → | перемотка ±5 c |
| ↑ / ↓ | громкость ±10 + надпись «Громкость: N%» |
| Vol+ / Vol− | громкость ±5 + надпись «Громкость: N%» |
| Menu | оверлей статистики (кодек/fps/drop), повторно — скрыть |
| Home | следующий в плейлисте |
| Back / Power | выход из mpv |
| Цифры 0–9 | воспроизведение дорожки N плейлиста |

Звук: HDMI-аудио работает (`AO: [alsa]`, карта `X96MAX`, `hw:0,0`),
устройствa 1/2 PCM-линков отвергают формат. `osd-duration=3000` в
`mpv.conf` — иначе подсказки слишком короткие. Собственный osd-bar
громкости не рисуется, поэтому мост шлёт явный `show-text` с числом,
полученным через `get_property`.

## Ловушки (пережитые, чтобы не повторять)

1. **`ir-keytable` без `-s` пишет в rc0 (CEC)** — «Protocols for device
   cannot be changed», кеймап уходит не туда. Всегда `-s rc1`.
2. **`ir-keytable -t` тоже слушает rc0** — поэтому «пустые» тесты.
3. **`pkill -f "ir-keytable -t"` в скрипте убивает собственную оболочку**
   (весь скрипт = cmdline) — вис молча, rc=128.
4. **`KEY_POWER` → systemd-logind → `poweroff`** — «самоперезагрузки»
   бокса в прошлых сессиях были именно это. Лечится `HandlePowerKey=ignore`.
5. Запись keymap обновляет keybit'ы input-устройства, но `EV_KEY`
   отфильтруется, если scancode не найден в таблице (`-r` — показать
   текущую).
6. Захват в фоне: без `stdbuf -oL` лог остаётся пустым (буфер stdout
   теряется при kill).
7. **Номер `eventN` меняется после ребута** (event4 → event1) — демоны
   обязаны искать устройство по `/sys/class/input/event*/device/name`,
   а не хардкодить путь.
8. **`show-text` из IPC не раскрывает `${volume}`** — приходит литерал.
   Нужное значение надо запрашивать через `get_property`.
9. На DRM `cycle fullscreen` — no-op (плеер и так fullscreen), поэтому
   Menu переназначен на статистику mpv.
10. **После ребута пульт молчит, хотя `ir-keymap.service` отработал**
    (журнал: «Wrote 33 keycode(s)»). Причина — гонка с udev:
    `/lib/udev/rules.d/70-infrared.rules` при добавлении input-устройства
    дёргает `ir-keytable -a /etc/rc_maps.cfg -s rcX` (вывод в журнал не
    пишется), а в `/etc/rc_maps.cfg` строка
    `* rc-x96max x96max.toml` указывала на **стоковую** 28-клавишную
    таблицу `0x01xx` — она затирала нашу уже ПОСЛЕ сервиса. Симптом:
    `ir-keytable -t` показывает scancodes (`0xdfxx`), но `/dev/input/event*`
    отдаёт только `EV_MSC` — без `EV_KEY` (scancode не найден в таблице),
    мост молчит. Лечение: в `/etc/rc_maps.cfg` перенаправить строку на наш
    файл — `* rc-x96max    /root/x96max.toml` (бэкап:
    `/etc/rc_maps.cfg.bak-*`). Теперь и udev, и сервис грузят одну
    таблицу, конфликт невозможен.

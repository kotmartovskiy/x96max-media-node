# Передняя панель X96 Max (FD628/TM1628) — часы и индикаторы

Панель на боксе — контроллер **FD628** (совместим с TM1628) на bit-banged
spi-gpio. DTB ophub уже описывает устройство (`/sys/bus/spi/devices/spi0.0`,
compatible `fdhisi,fd628` / `titanmec,tm1628`), но драйвера в ядре нет — панель
тёмная. USB-HID у панели нет (lsusb = только root hubs), армбиановский
`armbian-openvfd` не работает (конфликт пинов с DTB).

Решение: out-of-tree драйвер
**[jefflessard/tm16xx-display](https://github.com/jefflessard/tm16xx-display)**
(из [issue ophub #3567](https://github.com/ophub/amlogic-s9xxx-armbian/issues/3567)
— буквально наш бокс).

## Статус (28.09.2026)

- Модули `tm16xx`, `tm16xx_spi`, `line-display` собраны и загружены,
  `spi0.0 → tm16xx-spi` забинден, `/sys/class/leds/display` работает.
- Текст и индикаторы проверены на панели («usb 12:34»).
- `display.service` + `display-service` (часы) включены.
- Установлено в `/lib/modules/6.18.51-ophub/extra/` + `modules-load.d` —
  **ребут-тест персистентности НЕ проводился**.

## Установка/сборка

Скрипты лежат в `scripts/`:

```sh
sh scripts/setup-ophub-headers.sh   # разовое лечение заголовков ядра
sh scripts/build-tm16xx.sh          # сборка + установка модулей
sh scripts/build-tm16xx.sh install  # только установка готовых .ko
```

`setup-ophub-headers.sh` чинит заголовки ophub (см. «Ловушки» ниже) —
повторный запуск безопасен (идемпотентен). После **обновления ядра** ophub
нужно повторить оба скрипта (vermagic изменится, модули перестанут грузиться).

## Использование

```sh
echo "12:34"  > /sys/class/leds/display/message         # текст
cat           /sys/class/leds/display/message            # обратный отклик
echo 8        > /sys/class/leds/display/brightness        # яркость
echo 1        > /sys/class/leds/display::colon/brightness # двоеточие
echo 1        > /sys/class/leds/display::usb/brightness   # индикатор USB
```

Индикаторы: `display::usb`, `::colon`, `::sd`, `::apps`, `::setup`, `::cvbs`,
`::hd`. Атрибуты линии: `num_chars`, `map_seg7`, `scroll_step_ms`.

Часы: `display.service` (WantedBy=basic.target, ждёт
`/sys/class/leds/display`, после `time-sync.target`) запускает
`/usr/sbin/display-service` — шелл-демон с локом `/run/display.lock`,
пишет время в `message`, мигает двоеточием, сам драйвит индикаторы
(usbport-trigger и т.п.).

```sh
systemctl enable --now display
systemctl status display
display-service <text>     # разовая запись текста (CLI-режим)
```

Модули (порядок/зависимости depmod берёт на себя):

```sh
modprobe tm16xx_spi        # подтянет tm16xx + line-display
lsmod | grep -E "tm16xx|line"
ls -l /sys/bus/spi/devices/spi0.0/driver   # → ../../bus/spi/drivers/tm16xx-spi
```

## Ловушки сборки под 6.18.51-ophub (зафиксированы в скриптах)

1. **Заголовки запечены в образ** (не deb), `Kconfig` отрезан →
   `make scripts`/`olddefconfig` невозможны, а `make` при этом **удаляет**
   `include/generated/autoconf.h`. Лечится ручной регенерацией
   `autoconf.h`/`auto.conf` из `/boot/config-$(uname -r)` (python в setup-скрипте).
2. **`CONFIG_CC_VERSION_TEXT="gcc (Debian…)"`** — скобки ломают `if [ ... ]`
   в `prepare` (dash). Строки со `(` выкидываются из `auto.conf`.
3. **vermagic без LOCALVERSION**: shipped `utsrelease.h` = `6.18.51`, ядро —
   `6.18.51-ophub` → «Invalid module format». Переписать `utsrelease.h` +
   `kernel.release`.
4. **modpost сломан** (бинарь требует glibc 2.38, в bookworm 2.36), а хедеры
   не содержат `scripts/include/*` (hash/list/xalloc). Лечится: скопировать
   `scripts/include` из `apt-get download linux-headers-current-arm64` и
   **скомпилировать родной modpost** из `scripts/mod/*.c` (есть в хедерах).
5. **`EXTRA_CFLAGS` удалён из kbuild** (6.x) → только `ccflags-y=...`.
6. **`IS_ENABLED()` требует `-DCONFIG_X=1`** (пустой `-D` и `=y` дают 0 —
   token-paste `__ARG_PLACEHOLDER_##val`).
7. **Вендоренный Makefile апстрима** тянет `obj-$(CONFIG_CHARLCD)` и пр. —
   в нашей конфигурации эти опции `=y`, а исходников в репо нет →
   перебить все чужие `CONFIG_*=n` в командной строке (приоритет над auto.conf).
8. **`-fmin-function-alignment` не знает gcc 12** →
   `CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT=` + `CONFIG_FUNCTION_ALIGNMENT=0`
   (уходит в ветку `-falign-functions`, тоже отключается).
9. **`CONFIG_KEYBOARD_MATRIX` в ядре ophub нет** → keypad выключен
   (`CONFIG_TM16XX_KEYPAD=n`): IR-пульт работает отдельно (meson-ir), а
   без этого tm16xx.ko падает на `Unknown symbol matrix_keypad_build_keymap`.
10. `line-display.ko` **уже есть в /lib/modules ядра** (Armbian) — depmod
    резолвит `linedisp_attach` в него; наш `extra/line-display.ko` дублирует.
11. **kbuild 6.18 гоняет modpost с `-T modules.order`** (опция новых версий)
    — поэтому modpost должен быть собран из тех же исходников 6.18.

## Ссылки

- https://github.com/jefflessard/tm16xx-display (драйвер + display-service)
- https://github.com/jefflessard/display-service
- https://github.com/ophub/amlogic-s9xxx-armbian/issues/3567 (наш кейс)
- https://github.com/ophub/amlogic-s9xxx-armbian/issues/3566 (армбиановская альтернатива)

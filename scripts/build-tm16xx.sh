#!/bin/sh
# Сборка и установка модулей tm16xx-display (панель FD628 X96 Max).
# Требует вылеченных заголовков: sh scripts/setup-ophub-headers.sh
# Использование:
#   sh build-tm16xx.sh            # сборка + установка в /lib/modules + depmod
#   sh build-tm16xx.sh install    # только установка готовых .ko
#   sh build-tm16xx.sh clean      # очистить артефакты сборки
set -e

K=${K:-$(uname -r)}
KSRC=${KSRC:-/usr/src/linux-headers-$K}
SRC=${SRC:-/root/tm16xx-display}
MDIR="$SRC/drivers/auxdisplay"
ACTION=${1:-build}

if [ "$ACTION" = "clean" ]; then
    rm -f "$MDIR"/*.o "$MDIR"/*.mod "$MDIR"/*.mod.c "$MDIR"/*.ko "$MDIR"/.*.cmd \
          "$MDIR"/modules.order "$MDIR"/Module.symvers
    echo "очищено"
    exit 0
fi

if [ "$ACTION" = "build" ]; then
    [ -d "$SRC" ] || { echo "нет исходников: $SRC (git clone https://github.com/jefflessard/tm16xx-display.git $SRC)"; exit 1; }
    echo "сборка в $MDIR (ядро $K)"
    # ccflags-y: kbuild 6.x не знает EXTRA_CFLAGS; -D только со значением 1 —
    # иначе IS_ENABLED() в tm16xx.h даёт 0 и выбирается стаб-заглушка.
    # Чужие CONFIG_* из вендоренного Makefile апстрима (charlcd и пр.) =y в
    # нашей конфигурации, исходников нет — перебиваем в n (команда > auto.conf).
    # KEYPAD=n: matrix_keypad отсутствует в ядре ophub.
    make \
        ccflags-y="-DCONFIG_TM16XX=1 -DCONFIG_TM16XX_I2C=1 -DCONFIG_TM16XX_SPI=1 -include $MDIR/tm16xx_compat.h -I$SRC/include/" \
        -C "$KSRC" M="$MDIR" \
        CONFIG_TM16XX=m CONFIG_TM16XX_KEYPAD=n CONFIG_TM16XX_I2C=m \
        CONFIG_TM16XX_SPI=m CONFIG_LINEDISP=m \
        CONFIG_ARM_CHARLCD=n CONFIG_CFAG12864B=n CONFIG_CHARLCD=n \
        CONFIG_HD44780_COMMON=n CONFIG_HD44780=n CONFIG_HT16K33=n \
        CONFIG_IMG_ASCII_LCD=n CONFIG_KS0108=n CONFIG_LCD2S=n \
        CONFIG_MAX6959=n CONFIG_PARPORT_PANEL=n CONFIG_SEG_LED_GPIO=n \
        CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT= CONFIG_FUNCTION_ALIGNMENT=0 \
        modules
fi

echo "установка модулей"
mkdir -p "/lib/modules/$K/extra"
cp -f "$MDIR"/tm16xx.ko "$MDIR"/tm16xx_spi.ko "$MDIR"/line-display.ko \
      "$MDIR"/tm16xx_i2c.ko "/lib/modules/$K/extra/"
depmod -a "$K"
echo "tm16xx_spi" > /etc/modules-load.d/tm16xx.conf
grep -E "tm16xx|line" "/lib/modules/$K/modules.dep" || true
echo "готово. Загрузка: modprobe tm16xx_spi"

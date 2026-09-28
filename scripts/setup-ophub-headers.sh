#!/bin/sh
# Разовое «лечение» заголовков ядра ophub для сборки внешних модулей.
# Заголовки запечены в образ (не deb), Kconfig отрезан, modpost собран под
# glibc 2.38. Идемпотентен: повторный запуск безопасен.
# После обновения ядра ophub — запустить снова.
set -e

K=${K:-$(uname -r)}
KSRC=${KSRC:-/usr/src/linux-headers-$K}
CFG=/boot/config-$K

[ -d "$KSRC" ] || { echo "нет заголовков: $KSRC"; exit 1; }
[ -f "$CFG" ] || { echo "нет конфига: $CFG"; exit 1; }

echo "[1/5] autoconf.h + auto.conf из $CFG"
python3 - "$CFG" "$KSRC" << 'PY'
import re, sys
cfg, ksrc = sys.argv[1], sys.argv[2]
h, ac = [], []
for line in open(cfg):
    line = line.rstrip("\n")
    m = re.match(r"^(CONFIG_[A-Za-z0-9_]+)=(.*)$", line)
    if not m:
        continue
    name, val = m.group(1), m.group(2)
    ac.append("%s=%s" % (name, val))
    if val == "y":
        h.append("#define %s 1" % name)
    elif val == "m":
        h.append("#define %s_MODULE 1" % name)
    else:
        h.append("#define %s %s" % (name, val))
open(ksrc + "/include/generated/autoconf.h", "w").write("\n".join(h) + "\n")
open(ksrc + "/include/config/auto.conf", "w").write("\n".join(ac) + "\n")
open(ksrc + "/include/config/auto.conf.cmd", "w").write("")
open(ksrc + "/include/generated/rustc_cfg", "w").write("")
print("  defines=%d" % len(h))
PY
# CONFIG_CC_VERSION_TEXT="gcc (…)" ломает if [ … ] в prepare (dash)
sed -i '/(/d' "$KSRC/include/config/auto.conf"

echo "[2/5] vermagic: utsrelease + kernel.release"
printf '#define UTS_RELEASE "%s"\n' "$K" > "$KSRC/include/generated/utsrelease.h"
echo "$K" > "$KSRC/include/config/kernel.release"

echo "[3/5] scripts/include (tools-хедеры для modpost)"
if [ ! -f "$KSRC/scripts/include/xalloc.h" ]; then
    TMP=$(mktemp -d)
    (cd "$TMP" && apt-get download linux-headers-current-arm64 >/dev/null 2>&1)
    dpkg-deb -x "$TMP"/*.deb "$TMP/x"
    mkdir -p "$KSRC/scripts/include"
    cp -r "$TMP"/x/usr/src/linux-headers-*/scripts/include/* "$KSRC/scripts/include/"
    rm -rf "$TMP"
    echo "  скопировано из linux-headers-current-arm64"
else
    echo "  уже есть"
fi

echo "[4/5] modpost из исходников 6.18"
if ! "$KSRC/scripts/mod/modpost" >/dev/null 2>&1; then
    cd "$KSRC/scripts/mod"
    [ -f modpost.orig ] || cp modpost modpost.orig 2>/dev/null || true
    gcc -O2 -o mk_elfconfig mk_elfconfig.c
    gcc -c -o empty.o empty.c
    ./mk_elfconfig < empty.o > elfconfig.h
    gcc -O2 -I. -I"$KSRC/scripts/include" -o modpost.new \
        modpost.c file2alias.c sumversion.c symsearch.c
    mv modpost.new modpost
    chmod +x modpost
    echo "  собран родной modpost"
else
    echo "  уже работает"
fi

echo "[5/5] проверка"
"$KSRC/scripts/mod/modpost" >/dev/null 2>&1 && echo "modpost OK" || { echo "modpost СЛОМАН"; exit 1; }
grep -q "$(uname -r)" "$KSRC/include/generated/utsrelease.h" && echo "utsrelease OK"
test -f "$KSRC/include/generated/autoconf.h" && echo "autoconf OK"
echo "готово. Далее: sh scripts/build-tm16xx.sh"

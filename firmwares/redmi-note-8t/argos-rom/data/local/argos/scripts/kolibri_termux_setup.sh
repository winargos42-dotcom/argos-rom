#!/data/data/com.termux/files/usr/bin/bash
#===============================================================================
#  ARGOS KolibriOS + ColibriAsmEngine Integration for Termux
#  Запуск KolibriOS через QEMU + Colibri-демон в Android
#===============================================================================
set -euo pipefail

ARGOS_KOLIBRI="$HOME/argos-kolibri"
IMG_DIR="$ARGOS_KOLIBRI/images"
LOGS="$ARGOS_KOLIBRI/logs"
SCRIPTS_SRC="/sdcard/Download"

echo -e "\e[36m[ARGOS KolibriOS + ColibriAsmEngine]\e[0m"
echo "Target: Termux arm64 → QEMU i386 → KolibriOS"
echo ""

# ── 1. QEMU i386 ────────────────────────────────────────────────────────────
echo "[1/5] Установка QEMU..."
pkg install -y qemu-utils qemu-common qemu-system-i386-headless 2>/dev/null || \
pkg install -y qemu-system-i386 2>/dev/null || \
pkg install -y qemu-utils qemu-common 2>/dev/null || true

# ── 2. KolibriOS образ ────────────────────────────────────────────────────
echo "[2/5] Скачивание KolibriOS..."
mkdir -p "$IMG_DIR" "$LOGS"
cd "$IMG_DIR"

MIRRORS=(
    "https://builds.kolibrios.org/eng/nightly/kolibri.img"
    "https://builds.kolibrios.org/eng/latest-distr/kolibri.img"
    "https://github.com/KolibriOS/kolibrios/releases/download/nightly/kolibri.img"
)

DOWNLOADED=0
for url in "${MIRRORS[@]}"; do
    echo "  Попытка: $url"
    wget -q --timeout=30 -O kolibri.img "$url" 2>/dev/null && { DOWNLOADED=1; break; } || true
done

if [ $DOWNLOADED -eq 0 ]; then
    echo "  [WARN] Автоскачивание не удалось."
    echo "  [HINT] kolibri.img → $IMG_DIR/  (https://kolibri-os.org/ru/download)"
fi

# ── 3. ColibriAsmEngine CLI ────────────────────────────────────────────────
echo "[3/5] ColibriAsmEngine CLI..."
mkdir -p "$ARGOS_KOLIBRI/colibri"

# Copy colibri_cli.py from scripts if available
if [ -f "$SCRIPTS_SRC/colibri_cli.py" ]; then
    cp "$SCRIPTS_SRC/colibri_cli.py" "$ARGOS_KOLIBRI/colibri/colibri_cli.py"
else
    echo "  [WARN] colibri_cli.py не найден в /sdcard/Download/"
    echo "  [HINT] Push с ПК: adb push colibri_cli.py /sdcard/Download/"
fi

# ── 4. Keystone + Capstone ─────────────────────────────────────────────────
echo "[4/5] Установка keystone-engine + capstone..."
pip install --upgrade pip 2>/dev/null || true
pip install keystone-engine 2>/dev/null || echo "[WARN] keystone-engine не установлен (needs clang)"
pip install capstone 2>/dev/null || echo "[WARN] capstone не установлен"

# ── 5. Лаунчеры ────────────────────────────────────────────────────────────
echo "[5/5] Создание лаунчеров..."

# KolibriOS QEMU launcher
cat > "$ARGOS_KOLIBRI/kolibri-os.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
IMG="$HOME/argos-kolibri/images/kolibri.img"
LOG="$HOME/argos-kolibri/logs/kolibri_$(date +%Y%m%d_%H%M%S).log"
if [ ! -f "$IMG" ]; then
    echo "[ERR] KolibriOS image not found: $IMG"
    exit 1
fi
echo "[KolibriOS] Starting QEMU i386..."
echo "[KolibriOS] VNC :1 (5901) | Ctrl+A X to quit"
qemu-system-i386 -m 256 -fda "$IMG" -vga std -vnc :1 \
    -netdev user,id=net0,hostfwd=tcp::8080-:80 \
    -device ne2k_pci,netdev=net0 \
    -serial mon:stdio > "$LOG" 2>&1 &
echo $! > "$HOME/argos-kolibri/kolibri.pid"
echo "[KolibriOS] PID: $! | VNC: vncviewer localhost:1"
EOF
chmod +x "$ARGOS_KOLIBRI/kolibri-os.sh"

cat > "$ARGOS_KOLIBRI/kolibri-stop.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
PIDF="$HOME/argos-kolibri/kolibri.pid"
if [ -f "$PIDF" ]; then kill $(cat "$PIDF") 2>/dev/null || true; rm -f "$PIDF"; fi
pkill -f "qemu-system-i386.*kolibri" 2>/dev/null || true
echo "[KolibriOS] Stopped"
EOF
chmod +x "$ARGOS_KOLIBRI/kolibri-stop.sh"

# ── Finish ─────────────────────────────────────────────────────────────────
echo ""
echo -e "\e[32m══════════════════════════════════════════════════════════\e[0m"
echo -e "\e[32m  ARGOS KolibriOS + ColibriAsmEngine ГОТОВЫ!           \e[0m"
echo -e "\e[32m══════════════════════════════════════════════════════════\e[0m"
echo ""
echo "Команды:"
echo "  kolibri-os        → KolibriOS (QEMU i386 + VNC :1)"
echo "  kolibri-stop      → остановить KolibriOS"
echo "  colibri status    → статус Keystone/Capstone"
echo "  colibri asm       → ассемблирование"
echo "  colibri disasm    → дизассемблирование"
echo "  colibri file      → assemble файл"
echo "  colibri watch     → авто-сборка при изменениях"
echo ""
echo "Примеры:"
echo "  colibri asm 'mov eax, 1' --arch x86"
echo "  colibri asm '[x86_64] nop'"
echo "  colibri disasm 90909090 --arch x86"
echo "  colibri disasm '[arm_thumb:0x8000] 7047'"
echo "  colibri file ~/project.asm --arch arm_thumb"

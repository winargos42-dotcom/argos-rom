#!/data/data/com.termux/files/usr/bin/bash
#===============================================================================
#  ARGOS Bootstrap — ROOT-SAFE (no pkg/apt)
#  Устанавливает pip + скрипты + алиасы без pkg install
#  Для системных пакетов (tsu, openssh, nmap) запустите в Termux GUI: pkg install tsu openssh nmap
#===============================================================================
set -uo pipefail

ARGOS_MOBILE="$HOME/argos-mobile"
ARGOS_KOLIBRI="$HOME/argos-kolibri"
SCRIPTS="$ARGOS_MOBILE/scripts"
LOGS="$ARGOS_MOBILE/logs"

echo -e "\e[36m[ARGOS Root-Safe Bootstrap]\e[0m"
echo "Installing: Python libs, scripts, aliases, Colibri, KolibriOS launcher"
echo ""

# ── 1. Python libs via pip ─────────────────────────────────────────────────
echo "[1/5] pip install..."
pip install --upgrade pip 2>/dev/null || true
pip install --upgrade \
    pyserial pyusb requests \
    paho-mqtt colorama rich prompt-toolkit \
    keystone-engine 2>/dev/null || echo "[WARN] keystone-engine failed (needs clang)" \
    capstone 2>/dev/null || echo "[WARN] capstone failed" \
    2>&1 | tail -5

# ── 2. ARGOS dirs ───────────────────────────────────────────────────────────
echo "[2/5] Directories..."
mkdir -p "$ARGOS_MOBILE" "$SCRIPTS" "$LOGS" "$ARGOS_KOLIBRI/colibri" "$ARGOS_KOLIBRI/logs"

# ── 3. Copy scripts from sdcard ───────────────────────────────────────────
echo "[3/5] Scripts..."
for f in /sdcard/Download/colibri_cli.py /sdcard/Download/kolibri_termux_setup.sh; do
    [ -f "$f" ] && cp "$f" "$SCRIPTS/" 2>/dev/null || true
done
[ -f "$SCRIPTS/colibri_cli.py" ] && cp "$SCRIPTS/colibri_cli.py" "$ARGOS_KOLIBRI/colibri/colibri_cli.py"

# ── 4. Aliases ─────────────────────────────────────────────────────────────
echo "[4/5] Aliases..."
cat > "$HOME/.bashrc_argos" << 'EOF'
# ARGOS Mobile v3.0 (root-safe)
alias ll='ls -lah'
alias ..='cd ..'
alias root='su'
alias obd='python ~/argos-mobile/scripts/obd_bridge.py 2>/dev/null || echo "Script missing"'
alias uart='python ~/argos-mobile/scripts/uart_bridge.py 2>/dev/null || echo "Script missing"'
alias scan='python ~/argos-mobile/scripts/usb_scan.py 2>/dev/null || echo "Script missing"'
alias can='python ~/argos-mobile/scripts/can_sniff.py 2>/dev/null || echo "Script missing"'
alias ble='python ~/argos-mobile/scripts/ble_scan.py 2>/dev/null || echo "Script missing"'
alias ch341='python ~/argos-mobile/scripts/ch341a_dump.py 2>/dev/null || echo "Script missing"'
alias debug='python ~/argos-mobile/scripts/debug_bridge.py 2>/dev/null || echo "Script missing"'
alias xgecu='python ~/argos-mobile/scripts/xgecu_bridge.py 2>/dev/null || echo "Script missing"'
alias fnirsi='python ~/argos-mobile/scripts/fnirsi_scope.py 2>/dev/null || echo "Script missing"'
alias wifi='python ~/argos-mobile/scripts/wifi_pentest.py 2>/dev/null || echo "Script missing"'
alias bridge='python ~/argos-mobile/scripts/argos_bridge.py 2>/dev/null || echo "Script missing"'
alias otg='su -c "chmod 666 /dev/ttyUSB* /dev/ttyACM* 2>/dev/null; chmod -R 666 /dev/bus/usb/*/* 2>/dev/null; echo USB OK"'
alias start-argos='bash ~/argos-mobile/scripts/start_argos.sh 2>/dev/null || echo "Not installed"'
alias stop-argos='bash ~/argos-mobile/scripts/stop_argos.sh 2>/dev/null || echo "Not installed"'
alias logcat-save='logcat -d > /sdcard/Download/logcat_$(date +%Y%m%d_%H%M%S).txt'
alias argos-status='su -c /system/xbin/argos-status 2>/dev/null || echo "System module not loaded"'
alias kolibri-os='bash ~/argos-kolibri/kolibri-os.sh 2>/dev/null || echo "Run: bash ~/argos-kolibri/kolibri_termux_setup.sh"'
alias kolibri-stop='bash ~/argos-kolibri/kolibri-stop.sh 2>/dev/null || echo "Not installed"'
alias colibri='python ~/argos-kolibri/colibri/colibri_cli.py 2>/dev/null || echo "Run: bash ~/argos-kolibri/kolibri_termux_setup.sh"'
export PATH="~/argos-mobile/scripts:$PATH"
EOF

if ! grep -q "source ~/.bashrc_argos" "$HOME/.bashrc" 2>/dev/null; then
    echo "source ~/.bashrc_argos" >> "$HOME/.bashrc"
fi

# ── 5. Quick script stubs (if not present) ─────────────────────────────────
echo "[5/5] Stub scripts..."
for script in usb_scan.py obd_bridge.py uart_bridge.py can_sniff.py ble_scan.py ch341a_dump.py debug_bridge.py xgecu_bridge.py fnirsi_scope.py wifi_pentest.py argos_bridge.py start_argos.sh stop_argos.sh; do
    [ -f "$SCRIPTS/$script" ] || touch "$SCRIPTS/$script"
done
chmod +x "$SCRIPTS"/* 2>/dev/null || true

# ── Finish ─────────────────────────────────────────────────────────────────
echo ""
echo -e "\e[32m══════════════════════════════════════════════════════════\e[0m"
echo -e "\e[32m  ARGOS Root-Safe Bootstrap DONE!                      \e[0m"
echo -e "\e[32m══════════════════════════════════════════════════════════\e[0m"
echo ""
echo "Installed: Python libs, aliases, Colibri CLI"
echo ""
echo "Manual steps needed in Termux GUI:"
echo "  pkg install tsu openssh nmap usbutils"
echo "  pkg install qemu-system-i386-headless   # for KolibriOS"
echo ""
echo "Restart Termux or: source ~/.bashrc"

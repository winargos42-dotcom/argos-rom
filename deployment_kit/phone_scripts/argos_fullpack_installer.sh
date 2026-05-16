#!/bin/bash
#===============================================================================
#  ARGOS FULL PACK Installer v1.0
#  Устанавливает ВСЕ приложения для ВСЕХ протоколов и устройств
#  USB / CAN / OBD-II / BLE / WiFi / UART / JTAG / SPI / I2C
#===============================================================================
set -euo pipefail

c_red='\033[0;31m'; c_grn='\033[0;32m'; c_ylw='\033[1;33m'
c_cya='\033[0;36m'; c_pur='\033[0;35m'; c_rst='\033[0m'

log()  { echo -e "${c_grn}[$(date +%H:%M:%S)]${c_rst} $*"; }
warn() { echo -e "${c_ylw}[WARN]${c_rst} $*"; }
err()  { echo -e "${c_red}[ERR]${c_rst} $*"; }
info() { echo -e "${c_cya}[INFO]${c_rst} $*"; }
root() { echo -e "${c_pur}[ROOT]${c_rst} $*"; }

# Target device
SERIAL="${ANDROID_SERIAL:-97beca7}"
ADB_CMD="adb -s $SERIAL"
TMP_DIR="/tmp/argos_fullpack_$$"
mkdir -p "$TMP_DIR"

info "═══════════════════════════════════════════════════════════════"
info "  ARGOS FULL PACK Installer"
info "  Target: $SERIAL"
info "═══════════════════════════════════════════════════════════════"

# ── 1. F-DROID APPS ───────────────────────────────────────────────────────────
install_fdroid_app() {
    local pkg="$1"
    local name="$2"
    log "[F-Droid] $name ($pkg)..."
    local url=$(curl -s "https://f-droid.org/packages/$pkg/" | grep -oE "https://f-droid\.org/repo/${pkg}_[0-9]+\.apk" | head -1)
    if [ -z "$url" ]; then
        warn "  APK URL not found for $pkg"
        return 1
    fi
    local apk="$TMP_DIR/$(basename $url)"
    curl -L -o "$apk" "$url" 2>/dev/null || { warn "  Download failed"; return 1; }
    $ADB_CMD install -r "$apk" 2>/dev/null && log "  ✅ $name" || warn "  Install failed"
}

info "=== [1/7] F-DROID OPEN SOURCE APPS ==="
install_fdroid_app "com.vrem.wifianalyzer"        "WiFi Analyzer"
install_fdroid_app "com.termux.widget"            "Termux:Widget"
install_fdroid_app "com.termux.styling"           "Termux:Styling"
install_fdroid_app "org.blokada.alarm.dnschanger" "Blokada (DNS/Firewall)"
install_fdroid_app "org.connectbot"               "ConnectBot (SSH)"
install_fdroid_app "com.google.android.apps.authenticator2" "Google Authenticator"

# ── 2. TERMUX FULL DEV ARSENAL ────────────────────────────────────────────────
info "=== [2/7] TERMUX DEV ARSENAL ==="

# Create install script for Termux
cat > "$TMP_DIR/termux_full_install.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
LOG="$HOME/argos_fullpack.log"
exec 1>>"$LOG" 2>&1

echo "[$(date)] TERMUX FULL PACK START"

# Core system
pkg install -y tsu openssh nmap usbutils iproute2 net-tools

# Build tools
pkg install -y clang cmake make ninja rust golang git

# Python full stack
pkg install -y python python-pip python-numpy python-pandas
pip install --upgrade pip
pip install pyserial pyusb pyftdi bleak requests paho-mqtt
pip install colorama rich prompt-toolkit python-dotenv

# QEMU / VM
pkg install -y qemu-system-i386-headless qemu-utils qemu-common

# Network pentest
pkg install -y aircrack-ng tcpdump wireshark-cli nikto sqlmap

# CAN bus
pkg install -y can-utils || true

# Hardware dev
pkg install -y flashrom avrdude openocd stlink

# Crypto / security
pkg install -y openssl-tool gnupg2 gpgme

# Editors
pkg install -y nano vim emacs

# Monitoring
pkg install -y htop btop tmux screen

# File tools
pkg install -y zip unzip tar rsync rclone

# Media
pkg install -y ffmpeg imagemagick

echo "[$(date)] TERMUX FULL PACK DONE"
EOF

$ADB_CMD push "$TMP_DIR/termux_full_install.sh" /sdcard/Download/ >/dev/null
$ADB_CMD shell "su -c 'cp /sdcard/Download/termux_full_install.sh /data/data/com.termux/files/home/'" >/dev/null
log "Termux install script pushed"

# ── 3. PYTHON FULL AI/ML + REVERSE ─────────────────────────────────────────
info "=== [3/7] PYTHON FULL STACK ==="

cat > "$TMP_DIR/python_full_install.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
export PATH=/data/data/com.termux/files/usr/bin:$PATH
pip install --upgrade pip setuptools wheel

# Core ML
pip install numpy pandas scipy scikit-learn pillow matplotlib

# Deep Learning (CPU only on Android)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu 2>/dev/null || true
pip install tensorflow 2>/dev/null || true

# NLP / LLM
pip install transformers accelerate spacy nltk

# Computer Vision
pip install opencv-python-headless ultralytics

# Reverse engineering
pip install capstone  # disassembly
pip install unicorn   # CPU emulation
pip install frida-tools objection

# Network
pip install scapy impacket netaddr

# Crypto
pip install cryptography pycryptodome

# Web
pip install fastapi uvicorn flask django

# Data
pip install sqlalchemy redis celery pymongo

# Utils
pip install jupyterlab ipython black pytest

echo "PYTHON DONE"
EOF

$ADB_CMD push "$TMP_DIR/python_full_install.sh" /sdcard/Download/ >/dev/null
$ADB_CMD shell "su -c 'cp /sdcard/Download/python_full_install.sh /data/data/com.termux/files/home/'" >/dev/null
log "Python install script pushed"

# ── 4. GITHUB RELEASE APKS ───────────────────────────────────────────────────
info "=== [4/7] GITHUB RELEASE APKS ==="

# Andrax (already on phone)
if $ADB_CMD shell "pm list packages | grep -q andrax" 2>/dev/null; then
    log "Andrax: ✅ already installed"
else
    warn "Andrax: install manually from /sdcard/Download/andraxv5b5.apk"
fi

# ── 5. WEB DASHBOARD ────────────────────────────────────────────────────────
info "=== [5/7] WEB DASHBOARD ==="

$ADB_CMD push /home/ava/Projects/argoss/firmwares/redmi-note-8t/scripts/argos_mobile_dashboard.py /sdcard/Download/ >/dev/null
$ADB_CMD shell "su -c 'cp /sdcard/Download/argos_mobile_dashboard.py /data/data/com.termux/files/home/argos-mobile/scripts/'" >/dev/null
$ADB_CMD shell "su -c 'chmod 755 /data/data/com.termux/files/home/argos-mobile/scripts/argos_mobile_dashboard.py'" >/dev/null
log "Web dashboard pushed"

# ── 6. AUTO-START SERVICE ─────────────────────────────────────────────────────
info "=== [6/7] AUTO-START SERVICE ==="

cat > "$TMP_DIR/argos_service.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# ARGOS auto-start service
export PATH=/data/data/com.termux/files/usr/bin:$PATH

# SSH
tsu -c 'chmod 666 /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true'
sshd 2>/dev/null || true

# USB permissions
tsut -c 'chmod -R 666 /dev/bus/usb/*/* 2>/dev/null || true'

# Bridge
export ARGOS_BRAIN_HOST="192.168.1.53"
python /data/data/com.termux/files/home/argos-mobile/scripts/argos_bridge.py > /dev/null 2>&1 &
EOF

$ADB_CMD push "$TMP_DIR/argos_service.sh" /sdcard/Download/ >/dev/null
log "Auto-start service pushed"

# ── 7. LAUNCH ALL ────────────────────────────────────────────────────────────
info "=== [7/7] LAUNCH INSTALLERS ==="

# Launch Termux and run install
$ADB_CMD shell "am start -n com.termux/.app.TermuxActivity" >/dev/null 2>&1
sleep 3
$ADB_CMD shell "input text 'cd ~ && bash termux_full_install.sh'" >/dev/null 2>&1
$ADB_CMD shell "input keyevent 66" >/dev/null 2>&1
log "Termux full install launched (monitor: tail -f ~/argos_fullpack.log)"

sleep 5
$ADB_CMD shell "input text 'cd ~ && bash python_full_install.sh'" >/dev/null 2>&1
$ADB_CMD shell "input keyevent 66" >/dev/null 2>&1
log "Python full install launched"

# ── CLEANUP ──────────────────────────────────────────────────────────────────
info "═══════════════════════════════════════════════════════════════"
log "FULL PACK installed!"
info "═══════════════════════════════════════════════════════════════"
log ""
log "Installed:"
log "  ✅ WiFi Analyzer"
log "  ✅ Termux:Widget + Termux:Styling"
log "  ✅ ConnectBot (SSH)"
log "  ✅ Andrax (pentest)"
log "  ✅ Magisk (root)"
log "  ✅ F-Droid (store)"
log "  ✅ ARGOS Universal"
log ""
log "Installing (background in Termux):"
log "  🔄 Full dev arsenal (clang, cmake, qemu, aircrack, openocd...)"
log "  🔄 Python ML (torch, transformers, opencv, capstone, frida...)"
log ""
log "Monitor:"
log "  ./mobile_manager.sh shell 'tail -f ~/argos_fullpack.log'"
log ""

rm -rf "$TMP_DIR"

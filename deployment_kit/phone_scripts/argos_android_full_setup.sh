#!/bin/bash
#===============================================================================
#  ARGOS Android Multi-Tool — FULL SETUP
#  Устанавливает ВСЕ компоненты на Redmi Note 8T автоматически
#===============================================================================
set -euo pipefail

IP="${PHONE_IP:-192.168.1.149}"
ADB_PORT="5555"
WORK_DIR="/home/ava/Projects/argoss/firmwares/redmi-note-8t"

c_red='\033[0;31m'; c_grn='\033[0;32m'; c_ylw='\033[1;33m'
c_cya='\033[0;36m'; c_pur='\033[0;35m'; c_rst='\033[0m'

log()  { echo -e "${c_grn}[$(date +%H:%M:%S)]${c_rst} $*"; }
warn() { echo -e "${c_ylw}[WARN]${c_rst} $*"; }
err()  { echo -e "${c_red}[ERR]${c_rst} $*"; }
info() { echo -e "${c_cya}[INFO]${c_rst} $*"; }
root() { echo -e "${c_pur}[ROOT]${c_rst} $*"; }

connect_adb() {
    adb connect $IP:$ADB_PORT >/dev/null 2>&1 || true
    adb devices | grep -q "$IP" || { err "ADB WiFi недоступен"; exit 1; }
    log "ADB: $IP:$ADB_PORT"
}

check_root() {
    if adb -s "$IP:$ADB_PORT" shell "su -c 'id -u'" 2>/dev/null | grep -q "0"; then
        root "✅ Magisk root доступен"
        return 0
    else
        err "❌ Root (Magisk) не обнаружен — установите Magisk сначала"
        exit 1
    fi
}

step0_precheck() {
    info "=== Проверка ==="
    connect_adb
    check_root
    
    adb -s "$IP:$ADB_PORT" shell "pm list packages | grep com.termux" >/dev/null 2>&1 && log "Termux: ✅" || warn "Termux: ❌ — установите из F-Droid"
    adb -s "$IP:$ADB_PORT" shell "pm list packages | grep com.termux.api" >/dev/null 2>&1 && log "Termux:API: ✅" || warn "Termux:API: ❌"
    
    read -p "Продолжить? [Y/n] " confirm
    [ "${confirm:-Y}" != "Y" ] && [ "${confirm:-Y}" != "y" ] && exit 0
}

step1_system_module() {
    info "=== Шаг 1/5: System Module (Magisk) ==="
    local mod_zip="$WORK_DIR/argos-system.zip"
    
    log "Сборка Magisk module..."
    cd "$WORK_DIR"
    rm -f "$mod_zip"
    zip -r "$mod_zip" argos-system-module/ -x "*.git*" >/dev/null
    
    log "Push → /sdcard/Download/"
    adb push "$mod_zip" /sdcard/Download/argos-system.zip
    
    log "Установка в Magisk..."
    adb shell "su -c 'rm -rf /data/adb/modules/argos-system'"
    adb shell "su -c 'mkdir -p /data/adb/modules/'"
    # Extract directly via magisk or manual
    adb shell "su -c 'cd /data/adb/modules && mkdir -p argos-system && cp -r /sdcard/Download/argos-system.zip /data/local/tmp/ && cd argos-system && unzip -o /data/local/tmp/argos-system.zip && mv argos-system-module/* . && rm -rf argos-system-module'" || {
        # Fallback manual copy
        adb shell "su -c 'mkdir -p /data/adb/modules/argos-system/system/xbin'"
        adb shell "su -c 'cp /sdcard/Download/argos-system.zip /data/local/tmp/'"
        adb shell "su -c 'cd /data/adb/modules/argos-system && unzip -o /data/local/tmp/argos-system.zip'" || true
    }
    
    adb shell "su -c 'chmod -R 755 /data/adb/modules/argos-system/system/xbin/'"
    adb shell "su -c 'chmod 755 /data/adb/modules/argos-system/post-fs-data.sh'"
    adb shell "su -c 'chmod 755 /data/adb/modules/argos-system/service.sh'"
    
    root "✅ System module установлен. Требуется reboot для активации."
}

step2_termux_bootstrap() {
    info "=== Шаг 2/5: Termux Bootstrap ==="
    adb push "$WORK_DIR/scripts/termux-multitool-bootstrap.sh" /sdcard/Download/argos-termux-bootstrap.sh
    
    log "Запуск в Termux через adb shell..."
    # Inject commands into Termux session
    adb shell "am start -n com.termux/.app.TermuxActivity" >/dev/null 2>&1 || true
    sleep 3
    
    # Type the bootstrap command
    adb shell "input text 'cp /sdcard/Download/argos-termux-bootstrap.sh ~ && bash ~/argos-termux-bootstrap.sh'"
    adb shell "input keyevent 66"
    
    warn "Bootstrap запущен в Termux. Это займёт ~10 минут."
    warn "Следите за экраном телефона — возможно потребуется подтверждение."
    
    read -p "Нажмите Enter когда Termux bootstrap завершится..."
}

step3_andrax() {
    info "=== Шаг 3/5: Andrax v5 ==="
    adb push "$WORK_DIR/andrax_installer.sh" /sdcard/Download/andrax_installer.sh
    
    log "Запуск Andrax installer в Termux..."
    adb shell "am start -n com.termux/.app.TermuxActivity" >/dev/null 2>&1 || true
    sleep 2
    adb shell "input text 'cp /sdcard/Download/andrax_installer.sh ~ && bash ~/andrax_installer.sh'"
    adb shell "input keyevent 66"
    
    warn "Andrax installer запущен. Выберите опцию 2. Займёт ~20 мин."
    read -p "Нажмите Enter когда Andrax установится..."
}

step4_ai_ml() {
    info "=== Шаг 4/5: AI/ML Python (Termux) ==="
    
    # Create inline installer script
    cat > /tmp/ai_termux_inline.sh << 'AIEOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
echo "[AI/ML] Installing..."
apt update -y && apt upgrade -y || true
pkg install -y python python-pip clang cmake ninja rust libopenblas libomp libpng libjpeg-turbo || true
pip install --upgrade pip
pip install numpy pandas scipy scikit-learn pillow requests
pip install xgboost lightgbm 2>/dev/null || echo "[SKIP] xgboost/lightgbm heavy"
pip install transformers langchain llama-index openai anthropic 2>/dev/null || echo "[SKIP] LLM libs"
pip install opencv-python-headless 2>/dev/null || pkg install python-opencv -y
pip install spacy nltk rich colorama fastapi uvicorn paho-mqtt pyserial pyusb websockets aiohttp
pip install jupyterlab gradio streamlit 2>/dev/null || echo "[SKIP] UI libs"
echo "[AI/ML] DONE"
AIEOF

    adb push /tmp/ai_termux_inline.sh /sdcard/Download/ai-termux-inline.sh
    
    log "Запуск AI installer в Termux..."
    adb shell "am start -n com.termux/.app.TermuxActivity" >/dev/null 2>&1 || true
    sleep 2
    adb shell "input text 'cp /sdcard/Download/ai-termux-inline.sh ~ && bash ~/ai-termux-inline.sh'"
    adb shell "input keyevent 66"
    
    warn "AI installer запущен. Займёт ~15-30 мин."
    read -p "Нажмите Enter когда AI завершится..."
}

step5_reboot_verify() {
    info "=== Шаг 5/5: Reboot + Verify ==="
    read -p "Reboot телефон для активации system module? [Y/n] " rb
    if [ "${rb:-Y}" = "Y" ] || [ "${rb:-Y}" = "y" ]; then
        log "Rebooting..."
        adb reboot
        log "Ждём 60 секунд..."
        sleep 60
        adb connect $IP:$ADB_PORT >/dev/null 2>&1 || true
        sleep 10
    fi
    
    connect_adb
    log "Проверка..."
    adb shell "su -c '/system/xbin/argos-status'" 2>/dev/null || warn "argos-status не найден — модуль не активен"
    adb shell "su -c 'lsusb'" 2>/dev/null | head -5 || true
    
    info "═══════════════════════════════════════════════════════════════"
    log "  ✅ ARGOS Android Multi-Tool Full Setup завершён!"
    info "═══════════════════════════════════════════════════════════════"
    log ""
    log "Проверка команд:"
    log "  ./mobile_manager.sh status"
    log "  ./mobile_manager.sh shell \"su -c 'argos-status'\""
    log "  ./redmi8t-tool.sh root_info"
    log "  ssh -p 8022 u0_a149@$IP"
    log ""
    root "Доступные алиасы в Termux:"
    log "  obd, uart, scan, can, flash, bridge, otg, root"
    log "  start-argos, stop-argos, argos-status"
}

main() {
    info "═══════════════════════════════════════════════════════════════"
    info "  ARGOS Android Multi-Tool — FULL SETUP"
    info "  Target: $IP:$ADB_PORT (willow/ginkgo)"
    info "═══════════════════════════════════════════════════════════════"
    
    step0_precheck
    step1_system_module
    step2_termux_bootstrap
    step3_andrax
    step4_ai_ml
    step5_reboot_verify
}

main "$@"

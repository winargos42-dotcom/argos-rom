#!/bin/bash
#===============================================================================
#  Andrax v5 + AI/ML Arsenal — Termux Installer (Android arm64)
#  Redmi Note 8T (willow) — Magisk ROOT required for full OTG
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
        warn "⚠️ Root не обнаружен — Andrax работает без root, OTG ограничен"
        return 1
    fi
}

# ── 1. Andrax v5 Install ──────────────────────────────────────────────────────
step_andrax() {
    info "=== Шаг 1/3: Andrax v5 — Pentest Platform ==="
    log "Скачивание installer..."
    
    # Push installer to phone
    adb push "$WORK_DIR/andrax_installer.sh" /sdcard/Download/andrax-install.sh 2>/dev/null || {
        log "Push через adb, скачиваю через curl на телефон..."
        adb shell "curl -L https://raw.githubusercontent.com/Kirozaku/Andrax-Termux/refs/heads/main/install-andrax.sh -o /sdcard/Download/andrax-install.sh"
    }
    
    log "Запуск Andrax installer в Termux..."
    log ""
    info "=== Ручные шаги на телефоне ==="
    log "1. Откройте Termux"
    log "2. Выполните:"
    log "     cp /sdcard/Download/andrax-install.sh ~"
    log "     cd ~ && bash andrax-install.sh"
    log "3. Выберите опцию 2 (Download & Install)"
    log "4. Дождитесь окончания (~15-30 мин, ~2GB скачивание)"
    log "5. Запустите: ./andrax.sh"
    log ""
    
    # Try to run automatically
    adb shell "am start -n com.termux/.app.TermuxActivity" >/dev/null 2>&1 || true
    sleep 2
    
    read -p "Запустить Andrax install автоматически? [y/N] " auto
    if [ "${auto:-N}" = "y" ] || [ "${auto:-N}" = "Y" ]; then
        log "Автозапуск через adb shell..."
        adb shell "input text 'cp /sdcard/Download/andrax-install.sh ~ && cd ~ && bash andrax-install.sh'"
        adb shell "input keyevent 66"  # Enter
        warn "Если не сработало — запустите вручную в Termux"
    fi
}

# ── 2. AI/ML pip packages ────────────────────────────────────────────────────
step_ai_pip() {
    info "=== Шаг 2/3: AI/ML Python Arsenal ==="
    
    # Create pip install script for Termux
    cat > "$WORK_DIR/ai_termux_install.sh" << 'AIEOS'
#!/data/data/com.termux/files/usr/bin/bash
# AI/ML Installer for Termux (arm64)
set -euo pipefail

echo "[AI/ML] Updating packages..."
apt update -y && apt upgrade -y || true

echo "[AI/ML] Installing build deps..."
pkg install -y python python-pip clang cmake ninja rust libopenblas libomp libpng libjpeg-turbo libtiff fftw || true

echo "[AI/ML] Core scientific stack..."
pip install --upgrade pip setuptools wheel

# Core packages (lightweight, reliable)
PACKETS_CORE="numpy pandas scipy scikit-learn pillow requests urllib3 certifi charset-normalizer idna"
for p in $PACKETS_CORE; do
    echo "[AI/ML] Installing $p..."
    pip install --no-deps "$p" 2>/dev/null || pip install "$p" 2>/dev/null || echo "[SKIP] $p failed"
done

# ML frameworks
pip install xgboost 2>/dev/null || echo "[SKIP] xgboost"
pip install lightgbm 2>/dev/null || echo "[SKIP] lightgbm"
pip install catboost 2>/dev/null || echo "[SKIP] catboost (heavy, may fail on arm64)"

# PyTorch (Termux специфично)
echo "[AI/ML] PyTorch (CPU arm64)..."
pip install torch torchvision torchaudio 2>/dev/null || {
    echo "[HINT] PyTorch не установлен — для arm64 Termux используйте:"
    echo "  pip install torch --index-url https://download.pytorch.org/whl/cpu"
    echo "  Или соберите из исходников (долго)"
}

# TensorFlow / Keras (Termux ограничения)
echo "[AI/ML] TensorFlow..."
pip install tensorflow 2>/dev/null || {
    pip install tflite-runtime 2>/dev/null || true
    echo "[HINT] Полный TensorFlow на Android arm64 ограничен."
    echo "  Используйте: tflite-runtime или tensorflow-cpu"
}
pip install keras 2>/dev/null || echo "[SKIP] keras"

# NLP / Transformers
pip install transformers 2>/dev/null || echo "[SKIP] transformers"
pip install spacy 2>/dev/null || echo "[SKIP] spacy"
pip install nltk 2>/dev/null || echo "[SKIP] nltk"

# LLM frameworks
pip install langchain 2>/dev/null || echo "[SKIP] langchain"
pip install llama-index 2>/dev/null || echo "[SKIP] llama-index"

# Vision
pip install opencv-python-headless 2>/dev/null || {
    pkg install python-opencv -y 2>/dev/null || echo "[SKIP] opencv"
}
pip install ultralytics 2>/dev/null || echo "[SKIP] ultralytics (needs torch)"

# APIs
pip install openai 2>/dev/null || echo "[SKIP] openai"
pip install anthropic 2>/dev/null || echo "[SKIP] anthropic"

# Utils
pip install rich colorama jupyterlab fastapi uvicorn gradio streamlit websockets aiohttp paho-mqtt pyserial pyusb onnxruntime 2>/dev/null || true

echo ""
echo "[AI/ML] DONE!"
echo "Проверка:"
echo "  python -c 'import numpy; print(numpy.__version__)'"
echo "  python -c 'import pandas; print(pandas.__version__)'"
echo "  python -c 'import sklearn; print(sklearn.__version__)'"
AIEOS

    adb push "$WORK_DIR/ai_termux_install.sh" /sdcard/Download/ai-termux-install.sh
    log "AI installer pushed to /sdcard/Download/ai-termux-install.sh"
    log ""
    info "=== Ручные шаги ==="
    log "1. В Termux:"
    log "     cp /sdcard/Download/ai-termux-install.sh ~"
    log "     bash ~/ai-termux-install.sh"
    log "2. Ждите ~20-40 минут (PyTorch/TensorFlow долго)"
    log ""
}

# ── 3. Post-install ───────────────────────────────────────────────────────────
step_post() {
    info "=== Шаг 3/3: Post-install ==="
    log ""
    info "═══════════════════════════════════════════════════════════════"
    log "  Andrax + AI/ML Arsenal — Установка на телефон"
    info "═══════════════════════════════════════════════════════════════"
    log ""
    log "После завершения установки в Termux:"
    log ""
    root "Andrax:"
    log "  cd ~ && ./andrax.sh"
    log "  (proot chroot с Kali/Debian tools)"
    log ""
    root "AI/ML Python:"
    log "  python -c 'import numpy, pandas, sklearn; print(\"OK\")'"
    log ""
    root "OTG с ROOT:"
    log "  su -c 'lsusb'"
    log "  su -c 'chmod 666 /dev/ttyUSB*'"
    log ""
    log "Управление с ПК:"
    log "  ./mobile_manager.sh status"
    log "  ./mobile_manager.sh shell \"su -c 'lsusb'\""
    info "═══════════════════════════════════════════════════════════════"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    info "═══════════════════════════════════════════════════════════════"
    info "  Andrax v5 + AI/ML — Termux Installer"
    info "  Target: $IP:$ADB_PORT"
    info "═══════════════════════════════════════════════════════════════"
    
    connect_adb
    check_root
    step_andrax
    step_ai_pip
    step_post
}

main "$@"

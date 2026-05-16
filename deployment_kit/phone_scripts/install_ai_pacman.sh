#!/bin/bash
#===============================================================================
#  ARGOS AI/ML + Andrax Toolkit — Laptop/PC Installer (Arch Linux)
#  Устанавливает полный стек AI/ML и Android dev tools
#===============================================================================
set -euo pipefail

c_red='\033[0;31m'; c_grn='\033[0;32m'; c_ylw='\033[1;33m'
c_cya='\033[0;36m'; c_rst='\033[0m'

log()  { echo -e "${c_grn}[$(date +%H:%M:%S)]${c_rst} $*"; }
warn() { echo -e "${c_ylw}[WARN]${c_rst} $*"; }
err()  { echo -e "${c_red}[ERR]${c_rst} $*"; }
info() { echo -e "${c_cya}[INFO]${c_rst} $*"; }

info "═══════════════════════════════════════════════════════════════"
info "  ARGOS AI/ML + Android Dev — System Installer"
info "═══════════════════════════════════════════════════════════════"

# ── 1. Обновление системы ─────────────────────────────────────────────────────
log "[1/6] Обновление системы..."
sudo pacman -Syu --noconfirm || true

# ── 2. Core AI/ML Python (pacman) ────────────────────────────────────────────
log "[2/6] Установка core AI/ML пакетов через pacman..."

PACMAN_PKGS=(
    python-numpy python-pandas python-scipy python-scikit-learn
    python-xgboost python-pytorch python-torchvision python-torchaudio
    python-tensorflow python-keras python-transformers
    python-opencv python-pillow python-spacy python-nltk
    android-tools android-udev
    openjdk-src
    qemu-full lxc dnsmasq
    python-pip python-venv
    base-devel cmake ninja
    rocm-opencl-runtime rocm-hip-runtime  # AMD GPU support
)

for pkg in "${PACMAN_PKGS[@]}"; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
        log "  ✅ $pkg уже установлен"
    else
        log "  📦 $pkg"
        sudo pacman -S --noconfirm "$pkg" 2>/dev/null || warn "  ⚠️ $pkg не удалось установить (пропускаем)"
    fi
done

# ── 3. AUR packages ───────────────────────────────────────────────────────────
log "[3/6] Установка AUR пакетов через yay..."

YAY_PKGS=(
    python-langchain
    python-llamaindex-core
    waydroid
    waydroid-image
    ollama-cuda  # or ollama-rocm for AMD
    python-catboost
    python-lightgbm
    python-ultralytics
)

for pkg in "${YAY_PKGS[@]}"; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
        log "  ✅ $pkg уже установлен"
    else
        log "  📦 $pkg (AUR)"
        yay -S --noconfirm "$pkg" 2>/dev/null || warn "  ⚠️ $pkg не удалось установить (пропускаем)"
    fi
done

# ── 4. pip packages (дополнительные, которых нет в pacman) ────────────────────
log "[4/6] Установка pip-пакетов..."

PIP_PKGS=(
    openai anthropic
    opencv-python
    ultralytics
    pillow
    "torch --index-url https://download.pytorch.org/whl/rocm6.2"  # AMD ROCm
    torchvision torchaudio
    xgboost lightgbm catboost
    numpy pandas scipy scikit-learn
    spacy nltk
    transformers langchain llamaindex
    tensorflow keras
    "opencv-python-headless"
    "requests[socks]"
    rich colorama
    jupyterlab notebook
    fastapi uvicorn
    gradio streamlit
    websockets aiohttp
    redis celery
    pymongo elasticsearch
    kafka-python
    paho-mqtt
    pyserial pyusb
    protobuf onnxruntime
    tflite-runtime
    mediapipe
    accelerate peft bitsandbytes
    sentence-transformers
    chromadb qdrant-client
    python-dotenv
    pytest black isort mypy
    pre-commit
    build hatch
    twine
)

# Check if in venv or use system
if [ -d "$HOME/.venv-argos" ]; then
    source "$HOME/.venv-argos/bin/activate"
    log "  Using venv: ~/.venv-argos"
else
    log "  Using system python"
fi

for pkg in "${PIP_PKGS[@]}"; do
    log "  📦 pip: $pkg"
    pip install --upgrade "$pkg" 2>/dev/null || warn "  ⚠️ $pkg failed (skipped)"
done

# ── 5. Andrax install (for reference/laptop tools) ────────────────────────────
log "[5/6] Andrax tools on laptop..."
sudo pacman -S --noconfirm nmap metasploit aircrack-ng john hashcat sqlmap wireshark-cli nikto gobuster ffuf burpsuite-community 2>/dev/null || warn "Some pentest tools not in repos"

# ── 6. Post-install ───────────────────────────────────────────────────────────
log "[6/6] Post-install setup..."

# Docker waydroid setup if needed
if command -v waydroid >/dev/null 2>&1; then
    log "  Initializing waydroid..."
    sudo waydroid init -f 2>/dev/null || warn "waydroid init failed (may need reboot)"
fi

# Ollama setup
if command -v ollama >/dev/null 2>&1; then
    log "  Pulling default models..."
    ollama pull qwen2.5:3b 2>/dev/null || true
    ollama pull llama3.1:8b 2>/dev/null || true
fi

info "═══════════════════════════════════════════════════════════════"
log "Установка завершена!"
log ""
log "Проверка:"
log "  python -c 'import torch; print(torch.__version__)'"
log "  python -c 'import tensorflow; print(tensorflow.__version__)'"
log "  python -c 'import cv2; print(cv2.__version__)'"
log "  ollama list"
info "═══════════════════════════════════════════════════════════════"

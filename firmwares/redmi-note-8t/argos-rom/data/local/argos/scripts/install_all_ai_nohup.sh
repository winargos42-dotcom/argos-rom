#!/bin/bash
#===============================================================================
#  ARGOS AI/ML Full Install — Background script with retry
#  Laptop/PC — Python 3.12 via pyenv
#===============================================================================
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
source /home/ava/.venv-argos-py312/bin/activate

LOG="/tmp/argos_ai_install_nohup.log"
exec 1>>"$LOG" 2>&1

echo "=== START $(date) ==="

pip_install_retry() {
    local pkg="$1"
    local max=3
    for i in $(seq 1 $max); do
        echo "[$(date)] pip install $pkg (attempt $i/$max)..."
        pip install --no-cache-dir "$pkg" && { echo "[OK] $pkg"; return 0; }
        echo "[RETRY] $pkg failed, waiting 30s..."
        sleep 30
    done
    echo "[FAIL] $pkg exhausted retries"
    return 1
}

# Core (already done)
echo "[$(date)] Core already installed: numpy pandas scipy sklearn pillow"

# Boosting
pip_install_retry "xgboost"
pip_install_retry "lightgbm"
pip_install_retry "catboost"

# DL Frameworks
pip_install_retry "torch"
pip_install_retry "torchvision"
pip_install_retry "torchaudio"
pip_install_retry "tensorflow"
pip_install_retry "keras"

# NLP / LLM
pip_install_retry "transformers"
pip_install_retry "accelerate"
pip_install_retry "peft"
pip_install_retry "bitsandbytes"
pip_install_retry "sentence-transformers"
pip_install_retry "spacy"
pip_install_retry "nltk"
pip_install_retry "langchain"
pip_install_retry "llama-index"

# APIs
pip_install_retry "openai"
pip_install_retry "anthropic"

# Vision
pip_install_retry "opencv-python-headless"
pip_install_retry "ultralytics"
pip_install_retry "mediapipe"
pip_install_retry "onnxruntime"
pip_install_retry "tflite-runtime"

# Utils
pip_install_retry "chromadb"
pip_install_retry "qdrant-client"
pip_install_retry "fastapi"
pip_install_retry "uvicorn"
pip_install_retry "gradio"
pip_install_retry "streamlit"
pip_install_retry "websockets"
pip_install_retry "aiohttp"
pip_install_retry "paho-mqtt"
pip_install_retry "pyserial"
pip_install_retry "pyusb"
pip_install_retry "python-dotenv"
pip_install_retry "jupyterlab"
pip_install_retry "notebook"
pip_install_retry "black"
pip_install_retry "isort"
pip_install_retry "pytest"

echo "=== DONE $(date) ==="
echo "Verify: source /home/ava/.venv-argos-py312/bin/activate && python -c 'import torch, transformers, sklearn; print(\"OK\")'"

#!/data/data/com.termux/files/usr/bin/bash
#===============================================================================
#  ARGOS Full Unattended Install for Termux
#  Bootstrap + KolibriOS/Colibri + Andrax (optional)
#===============================================================================
set -uo pipefail

LOG="$HOME/argos_install_all.log"
exec 1>>"$LOG" 2>&1

echo "[$(date)] === ARGOS FULL INSTALL START ==="

# ── 1. Bootstrap ────────────────────────────────────────────────────────────
if [ -f "$HOME/argos-termux-bootstrap.sh" ]; then
    echo "[$(date)] Step 1: Termux bootstrap..."
    bash "$HOME/argos-termux-bootstrap.sh" >> "$LOG" 2>&1 || echo "[WARN] bootstrap had errors"
else
    echo "[$(date)] Bootstrap not found, skipping"
fi

# ── 2. KolibriOS + Colibri ────────────────────────────────────────────────
if [ -f "$HOME/kolibri_termux_setup.sh" ]; then
    echo "[$(date)] Step 2: KolibriOS + ColibriAsmEngine..."
    bash "$HOME/kolibri_termux_setup.sh" >> "$LOG" 2>&1 || echo "[WARN] kolibri setup had errors"
else
    echo "[$(date)] Kolibri setup not found, skipping"
fi

# ── 3. Andrax (heavy, optional) ───────────────────────────────────────────
if [ -f "$HOME/andrax_installer.sh" ]; then
    echo "[$(date)] Step 3: Andrax v5..."
    # Non-interactive: download and install
    cd "$HOME"
    bash "$HOME/andrax_installer.sh" << 'EOF'
2
EOF
    # ^^^ option 2 = download + install
else
    echo "[$(date)] Andrax installer not found, skipping"
fi

# ── 4. Finish ─────────────────────────────────────────────────────────────
echo "[$(date)] === ARGOS FULL INSTALL DONE ==="
echo "[$(date)] Log: $LOG"

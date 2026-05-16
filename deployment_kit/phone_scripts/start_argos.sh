#!/data/data/com.termux/files/usr/bin/bash
# ARGOS Daemon Start Script
# Launches all background services and bridges

export PATH="/data/data/com.termux/files/usr/bin:$PATH"
export HOME="/data/data/com.termux/files/home"
ARGOS_HOME="$HOME/argos-mobile"
LOG="$ARGOS_HOME/logs"
mkdir -p "$LOG"

echo "[ARGOS] Starting services..."
# USB scanner background
nohup python3 "$ARGOS_HOME/scripts/usb_scan.py" --loop > "$LOG/usb_scan.log" 2>&1 &
# UART bridge
nohup python3 "$ARGOS_HOME/scripts/uart_bridge.py" > "$LOG/uart_bridge.log" 2>&1 &
# OBD bridge (if adapter present)
nohup python3 "$ARGOS_HOME/scripts/obd_bridge.py" > "$LOG/obd_bridge.log" 2>&1 &
# KolibriOS QEMU headless (optional)
# nohup qemu-system-i386 -fda ~/argos-kolibri/images/kolibri.img -display none > "$LOG/kolibri.log" 2>&1 &

echo "[ARGOS] Services started. PID files in $LOG"

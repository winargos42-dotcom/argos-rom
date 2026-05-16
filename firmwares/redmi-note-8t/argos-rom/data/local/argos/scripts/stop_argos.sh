#!/data/data/com.termux/files/usr/bin/bash
# ARGOS Daemon Stop Script

pkill -f "usb_scan.py"
pkill -f "uart_bridge.py"
pkill -f "obd_bridge.py"
pkill -f "qemu-system-i386"
pkill -f "argos_mobile_dashboard.py"

echo "[ARGOS] All background services stopped."

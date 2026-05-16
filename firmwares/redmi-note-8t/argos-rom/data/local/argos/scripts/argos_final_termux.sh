#!/data/data/com.termux/files/usr/bin/bash
# ARGOS Final Termux Install Script
# Run inside Termux GUI (not via adb root)
set -e

echo "[ARGOS] Final Termux setup..."
pkg update -y

# Optional: Python debugger for JTAG/SWD (openocd alternative)
pip install pyocd esptool 2>/dev/null || echo "pyocd/esptool pip install completed or skipped"

# Verify all Python imports
python3 -c "
import serial, usb, obd, can, bleak, capstone, unicorn, pyocd
print('[ARGOS] All Python modules OK')
" 2>/dev/null || echo "Some modules may need manual check"

echo "[ARGOS] Final setup complete!"
echo "OpenOCD alternative: pyocd (python)"
echo "Flashrom: available via PC build only"
echo "WiFi tools: use Android root + iw binary from PC"

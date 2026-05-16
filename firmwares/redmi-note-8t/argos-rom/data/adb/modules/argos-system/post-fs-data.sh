#!/system/bin/sh
#===============================================================================
#  ARGOS System Module — Post-FS Data
#  Устанавливает права на USB/CAN/UART до загрузки системы
#===============================================================================

LOGFILE="/data/local/tmp/argos-postfs.log"
exec 1>>"$LOGFILE" 2>&1

echo "[ARGOS] post-fs-data started: $(date)"

# ── USB Serial permissions ────────────────────────────────────────────────────
# CH340, FTDI, CP210x, PL2303, CDC ACM
for dev in /dev/ttyUSB* /dev/ttyACM*; do
    [ -e "$dev" ] || continue
    chmod 666 "$dev"
    chown root:root "$dev"
    echo "[ARGOS] chmod 666 $dev"
done

# ── USB Bus permissions (libusb, pyusb) ─────────────────────────────────────
if [ -d /dev/bus/usb ]; then
    chmod 755 /dev/bus/usb
    find /dev/bus/usb -type c -exec chmod 666 {} \;
    echo "[ARGOS] USB bus chmod 666 done"
fi

# ── CAN interfaces (if kernel modules loaded) ────────────────────────────────
for dev in /dev/can* /sys/class/net/can*; do
    [ -e "$dev" ] || continue
    chmod 666 "$dev" 2>/dev/null || true
    echo "[ARGOS] CAN $dev permission set"
done

# ── I2C / SPI / GPIO (if accessible) ─────────────────────────────────────────
for dev in /dev/i2c* /dev/spi* /sys/class/gpio; do
    [ -e "$dev" ] || continue
    chmod 666 "$dev" 2>/dev/null || true
done

# ── ARGOS marker ─────────────────────────────────────────────────────────────
mkdir -p /data/local/tmp/argos
echo "$(date +%s)" > /data/local/tmp/argos/postfs.marker

echo "[ARGOS] post-fs-data finished: $(date)"

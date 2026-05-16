#!/system/bin/sh
#===============================================================================
#  ARGOS System Module — Service (late_start)
#  Автозапуск сервисов после загрузки Android
#===============================================================================

LOGFILE="/data/local/tmp/argos-service.log"
exec 1>>"$LOGFILE" 2>&1

echo "[ARGOS] service started: $(date)"

# ── Ждём полной загрузки ────────────────────────────────────────────────────
sleep 15

# ── USB Permissions (повторно, устройства могли появиться позже) ────────────
/system/xbin/argos-usb-setup

# ── Frida Server (если установлен) ────────────────────────────────────────────
if [ -f /data/local/tmp/frida-server ]; then
    chmod 755 /data/local/tmp/frida-server
    /data/local/tmp/frida-server &
    echo "[ARGOS] frida-server started PID: $!"
fi

# ── ARGOS Bridge (если конфиг есть) ───────────────────────────────────────────
if [ -f /data/local/tmp/argos/bridge.conf ]; then
    . /data/local/tmp/argos/bridge.conf
    # bridge binary or script here
fi

# ── Mark system ready ──────────────────────────────────────────────────────────
echo "$(date +%s)" > /data/local/tmp/argos/service.marker
echo "[ARGOS] service finished: $(date)"

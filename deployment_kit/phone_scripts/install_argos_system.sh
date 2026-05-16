#!/bin/bash
#===============================================================================
#  ARGOS System-Level Installer for Redmi Note 8T
#  Устанавливает ARGOS на уровне системы через Magisk + Termux
#===============================================================================
set -euo pipefail

WORK_DIR="/home/ava/Projects/argoss/firmwares/redmi-note-8t"
IP="${PHONE_IP:-192.168.1.149}"
ADB_PORT="5555"

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
    log "ADB connected: $IP:$ADB_PORT"
}

check_root() {
    if adb -s "$IP:$ADB_PORT" shell "su -c 'id -u'" 2>/dev/null | grep -q "0"; then
        root "✅ Magisk root доступен"
        return 0
    else
        err "❌ Root (Magisk) не обнаружен"
        err "Установите Magisk через TWRP или patched boot.img сначала"
        exit 1
    fi
}

step_1_module() {
    info "=== Шаг 1/5: Magisk System Module ==="
    local mod_zip="$WORK_DIR/argos-system.zip"
    
    log "Создание zip модуля..."
    cd "$WORK_DIR"
    rm -f "$mod_zip"
    zip -r "$mod_zip" argos-system-module/ -x "*.git*"
    
    log "Push zip на телефон..."
    adb push "$mod_zip" /sdcard/Download/
    
    log "Установка модуля в /data/adb/modules/argos-system..."
    adb shell "su -c 'mkdir -p /data/adb/modules/argos-system'"
    adb shell "su -c 'rm -rf /data/adb/modules/argos-system/*'"
    # Распаковка через busybox unzip
    adb shell "su -c 'unzip -o /sdcard/Download/argos-system.zip -d /data/adb/modules/'" || {
        err "unzip failed, пробуем tar..."
        adb shell "su -c 'cd /data/adb/modules/ && mkdir -p argos-system && cp -r /sdcard/Download/argos-system-module/* /data/adb/modules/argos-system/'" || true
    }
    
    log "Права на скрипты..."
    adb shell "su -c 'chmod -R 755 /data/adb/modules/argos-system/system/xbin/'"
    adb shell "su -c 'chmod 755 /data/adb/modules/argos-system/post-fs-data.sh'"
    adb shell "su -c 'chmod 755 /data/adb/modules/argos-system/service.sh'"
    
    root "✅ Модуль установлен. После reboot появятся /system/xbin/argos-*"
}

step_2_frida() {
    info "=== Шаг 2/5: Frida Server ==="
    local frida_bin="$WORK_DIR/frida-server"
    
    if [ ! -f "$frida_bin" ]; then
        warn "frida-server не найден в $WORK_DIR/"
        warn "Скачайте подходящую версию: https://github.com/frida/frida/releases"
        warn "Файл должен называться frida-server и быть для android-arm64"
        read -p "Пропустить frida? [Y/n] " skip
        [ "${skip:-y}" = "n" ] && exit 1
        return 0
    fi
    
    log "Push frida-server → /data/local/tmp/"
    adb push "$frida_bin" /data/local/tmp/frida-server
    adb shell "su -c 'chmod 755 /data/local/tmp/frida-server'"
    adb shell "su -c '/data/local/tmp/frida-server &'" || true
    root "✅ frida-server установлен и запущен"
}

step_3_termux() {
    info "=== Шаг 3/5: Termux + Bootstrap ==="
    
    # Check Termux
    if adb shell "pm list packages | grep com.termux" >/dev/null 2>&1; then
        log "Termux уже установлен"
    else
        warn "Termux не установлен"
        if [ -f "$WORK_DIR/apps/termux.apk" ]; then
            log "Установка Termux..."
            adb install -r "$WORK_DIR/apps/termux.apk"
        else
            err "Положите termux.apk в $WORK_DIR/apps/"
            exit 1
        fi
    fi
    
    if adb shell "pm list packages | grep com.termux.api" >/dev/null 2>&1; then
        log "Termux:API уже установлен"
    else
        if [ -f "$WORK_DIR/apps/termux-api.apk" ]; then
            log "Установка Termux:API..."
            adb install -r "$WORK_DIR/apps/termux-api.apk"
        fi
    fi
    
    # Push bootstrap
    log "Push bootstrap скрипт..."
    adb push "$WORK_DIR/scripts/termux-multitool-bootstrap.sh" /sdcard/Download/argos-termux-bootstrap.sh
    
    log ""
    info "=== Ручные шаги на телефоне ==="
    log "1. Откройте Termux"
    log "2. Выполните:"
    log "     cp /sdcard/Download/argos-termux-bootstrap.sh ~"
    log "     bash ~/argos-termux-bootstrap.sh"
    log "3. Дождитесь окончания (~10 мин)"
    log ""
    read -p "Запустить bootstrap автоматически через adb shell? [y/N] " auto
    if [ "${auto:-N}" = "y" ] || [ "${auto:-N}" = "Y" ]; then
        log "Автозапуск bootstrap (через Termux adb shell)..."
        adb shell "am start -n com.termux/.app.TermuxActivity" >/dev/null 2>&1 || true
        sleep 2
        # Send keys via adb input? Hard to do reliably.
        warn "Автозапуск Termux ненадёжен. Рекомендуется запустить вручную."
    fi
}

step_4_udev() {
    info "=== Шаг 4/5: Udev-like Rules (via Magisk module already installed) ==="
    log "Правила USB/CAN уже в модуле. После reboot будут активны."
    log "Для применения без reboot:"
    log "  ./mobile_manager.sh shell \"su -c 'argos-usb-setup'\""
}

step_5_reboot() {
    info "=== Шаг 5/5: Reboot ==="
    log "Для активации Magisk module требуется reboot."
    read -p "Reboot сейчас? [y/N] " reboot
    if [ "${reboot:-N}" = "y" ] || [ "${reboot:-N}" = "Y" ]; then
        log "Rebooting..."
        adb reboot
    else
        log "Пропущено. Выполните вручную: adb reboot"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    info "═══════════════════════════════════════════════════════════════"
    info "   ARGOS System-Level Installer"
    info "   Target: Redmi Note 8T (willow/ginkgo)"
    info "═══════════════════════════════════════════════════════════════"
    
    connect_adb
    check_root
    
    step_1_module
    step_2_frida
    step_3_termux
    step_4_udev
    step_5_reboot
    
    info "═══════════════════════════════════════════════════════════════"
    log "Установка завершена!"
    log ""
    log "После reboot на телефоне будут доступны:"
    root "  argos-status       — статус системы"
    root "  argos-usb-setup    — права на USB"
    root "  argos-can-up       — поднять CAN"
    root "  argos-bridge       — запуск моста"
    log ""
    log "Управление с ПК:"
    log "  ./mobile_manager.sh status"
    log "  ./mobile_manager.sh shell \"su -c 'argos-status'\""
    log "  ./redmi8t-tool.sh root_info"
    info "═══════════════════════════════════════════════════════════════"
}

main "$@"

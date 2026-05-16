#!/bin/bash
#===============================================================================
#  ARGOS Mobile Toolkit Manager v2.0 [ROOTED]
#  Управление Redmi Note 8T (willow) как полевым мультитулом
#  ПК → ADB / SSH → Android (ROOT через Magisk)
#===============================================================================
set -euo pipefail

IP="${PHONE_IP:-192.168.1.149}"
ADB_PORT="5555"
SSH_PORT="8022"
WORK_DIR="/home/ava/Projects/argoss/firmwares/redmi-note-8t"

c_red='\033[0;31m'; c_grn='\033[0;32m'; c_ylw='\033[1;33m'
c_cya='\033[0;36m'; c_pur='\033[0;35m'; c_rst='\033[0m'

log()  { echo -e "${c_grn}[$(date +%H:%M:%S)]${c_rst} $*"; }
warn() { echo -e "${c_ylw}[WARN]${c_rst} $*"; }
err()  { echo -e "${c_red}[ERR]${c_rst} $*"; }
info() { echo -e "${c_cya}[INFO]${c_rst} $*"; }
root() { echo -e "${c_pur}[ROOT]${c_rst} $*"; }

ADB_SERIAL=""
HAS_ROOT=0

connect_adb() {
    adb connect $IP:$ADB_PORT >/dev/null 2>&1 || true
    adb devices | grep -q "$IP" || { err "ADB WiFi недоступен"; exit 1; }
    ADB_SERIAL="$IP:$ADB_PORT"
    log "ADB connected: $ADB_SERIAL"
    
    # Root check
    if adb -s "$ADB_SERIAL" shell "su -c 'id -u'" 2>/dev/null | grep -q "0"; then
        HAS_ROOT=1
        root "✅ Magisk root доступен"
    else
        HAS_ROOT=0
        warn "⚠️ Root не обнаружен — ограниченный режим"
    fi
}

adb_cmd() { adb -s "$ADB_SERIAL" "$@"; }

adb_root() {
    if [ $HAS_ROOT -eq 1 ]; then
        adb -s "$ADB_SERIAL" shell "su -c '$*'"
    else
        adb -s "$ADB_SERIAL" shell "$*"
    fi
}

cmd_status() {
    connect_adb
    info "=== Mobile Multi-Tool Status ==="
    log "IP: $IP"
    log "Device: $(adb_cmd shell getprop ro.product.device | tr -d '\r')"
    log "Android: $(adb_cmd shell getprop ro.build.version.release | tr -d '\r')"
    log "Battery: $(adb_cmd shell dumpsys battery | grep level | awk '{print $2}')"
    log "WiFi: $(adb_cmd shell dumpsys wifi | grep 'mWifiInfo' | head -1 | tr -d '\r')"
    
    # Root status
    if [ $HAS_ROOT -eq 1 ]; then
        root "Root: ✅ uid=0"
        root "Magisk: $(adb_cmd shell "su -c 'ls /data/adb/magisk 2>/dev/null && echo installed || echo not found'" | tr -d '\r')"
    else
        warn "Root: ❌ неактивен"
    fi
    
    # Termux check
    adb_cmd shell "pm list packages | grep com.termux" >/dev/null 2>&1 && log "Termux: ✅ installed" || warn "Termux: ❌ not installed"
    adb_cmd shell "pm list packages | grep com.termux.api" >/dev/null 2>&1 && log "Termux:API: ✅ installed" || warn "Termux:API: ❌ not installed"
    
    # SSH check
    adb_cmd shell "pgrep -f sshd" >/dev/null 2>&1 && log "SSH (8022): ✅ running" || warn "SSH (8022): ❌ not running"
    
    # OTG check
    log "USB OTG devices:"
    if [ $HAS_ROOT -eq 1 ]; then
        adb_cmd shell "su -c 'lsusb 2>/dev/null'" 2>/dev/null | while read l; do [ -n "$l" ] && log "  $l"; done || true
    else
        adb_cmd shell "lsusb 2>/dev/null" 2>/dev/null | while read l; do [ -n "$l" ] && log "  $l"; done || true
    fi
}

cmd_install_bootstrap() {
    connect_adb
    log "Installing Termux bootstrap..."
    adb_cmd push "$WORK_DIR/scripts/termux-multitool-bootstrap.sh" /sdcard/Download/argos-termux-bootstrap.sh
    log "Bootstrap pushed to /sdcard/Download/"
    log ""
    info "=== Manual steps on phone ==="
    log "1. Open Termux app"
    log "2. Run: cp /sdcard/Download/argos-termux-bootstrap.sh ~"
    log "3. Run: bash ~/argos-termux-bootstrap.sh"
    log "4. Wait for completion (~5-10 min)"
    log ""
    log "After that SSH will be available: ssh -p 8022 <user>@$IP"
}

cmd_ssh() {
    info "Connecting SSH to phone..."
    local user="$(adb_cmd shell whoami | tr -d '\r')"
    ssh -p $SSH_PORT "$user@$IP" "$@"
}

cmd_shell() {
    connect_adb
    local args="$*"
    if [ -z "$args" ]; then
        if [ $HAS_ROOT -eq 1 ]; then
            root "Root shell (su)..."
            adb_cmd shell "su"
        else
            adb_cmd shell
        fi
    else
        if [ $HAS_ROOT -eq 1 ]; then
            root "su -c '$args'"
            adb_cmd shell "su -c '$args'"
        else
            adb_cmd shell "$args"
        fi
    fi
}

cmd_root_shell() {
    connect_adb
    if [ $HAS_ROOT -eq 1 ]; then
        root "Открываю root shell..."
        adb_cmd shell "su"
    else
        err "Root не доступен"
        exit 1
    fi
}

cmd_logcat() {
    connect_adb
    local out="$WORK_DIR/logs/logcat_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$WORK_DIR/logs"
    log "Capturing logcat → $out (Ctrl+C to stop)"
    adb_cmd logcat -v threadtime | tee "$out"
}

cmd_screenshot() {
    connect_adb
    local out="$WORK_DIR/captures/screen_$(date +%Y%m%d_%H%M%S).png"
    mkdir -p "$WORK_DIR/captures"
    adb_cmd shell screencap -p /sdcard/screen.png
    adb_cmd pull /sdcard/screen.png "$out"
    log "Screenshot: $out"
}

cmd_install_apps() {
    connect_adb
    info "=== Installing Android apps ==="
    
    local apps_dir="$WORK_DIR/apps"
    for apk in "$apps_dir"/*.apk; do
        if [ -f "$apk" ]; then
            log "Installing $(basename $apk)..."
            adb_cmd install -r "$apk" 2>&1 || warn "Failed: $(basename $apk)"
        fi
    done
    
    log ""
    info "=== Recommended apps to install manually ==="
    log "  • Car Scanner ELM OBD2  — OBD-II диагностика (Play Store)"
    log "  • Serial USB Terminal   — USB-UART терминал (Play Store / APKPure)"
    log "  • nRF Connect           — Bluetooth BLE сканер (Play Store)"
    log "  • WiFi Analyzer         — WiFi анализатор (Play Store / F-Droid)"
    log "  • MQTT Dash             — IoT dashboard (Play Store)"
    log "  • Termux:Widget         — Termux виджеты (F-Droid)"
    log "  • Termux:Styling        — Termux темы (F-Droid)"
}

cmd_push() {
    local file="${1:-}"
    local dest="${2:-/sdcard/Download/}"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        err "Usage: $0 push <file> [destination]"
        exit 1
    fi
    connect_adb
    adb_cmd push "$file" "$dest"
    log "Pushed: $(basename $file) → $dest"
}

cmd_pull_logs() {
    connect_adb
    local out="$WORK_DIR/logs/phone_logs_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$out"
    adb_cmd shell logcat -d > "$out/logcat.txt" 2>&1 || true
    adb_cmd shell dumpsys > "$out/dumpsys.txt" 2>&1 || true
    adb_cmd shell cat /proc/meminfo > "$out/meminfo.txt" 2>&1 || true
    adb_cmd shell cat /proc/cpuinfo > "$out/cpuinfo.txt" 2>&1 || true
    adb_cmd shell getprop > "$out/properties.txt" 2>&1 || true
    log "Pulled logs → $out"
}

cmd_partition_dump() {
    connect_adb
    if [ $HAS_ROOT -eq 0 ]; then
        err "Требуется root для дампа разделов"
        exit 1
    fi
    
    local part="${1:-boot}"
    local out="$WORK_DIR/backups/partition_${part}_$(date +%Y%m%d_%H%M%S).img"
    mkdir -p "$WORK_DIR/backups"
    
    root "Дамп раздела $part → $out"
    adb_cmd shell "su -c 'dd if=/dev/block/bootdevice/by-name/$part of=/sdcard/dump.img bs=4M'" 2>&1 || true
    adb_cmd pull /sdcard/dump.img "$out" 2>&1 || { err "Pull failed"; exit 1; }
    adb_cmd shell "rm -f /sdcard/dump.img" 2>/dev/null || true
    root "✅ Дамп сохранён: $out"
    ls -lh "$out"
}

cmd_app_data() {
    connect_adb
    if [ $HAS_ROOT -eq 0 ]; then
        err "Требуется root для доступа к /data/data/"
        exit 1
    fi
    
    local pkg="${1:-}"
    local ts=$(date +%Y%m%d_%H%M%S)
    local out="$WORK_DIR/captures/app_data_${pkg:-all}_$ts"
    mkdir -p "$out"
    
    if [ -n "$pkg" ]; then
        root "Извлечение данных $pkg..."
        adb_cmd shell "su -c 'tar czf /sdcard/app_data.tgz /data/data/$pkg 2>/dev/null'" || true
        adb_cmd pull /sdcard/app_data.tgz "$out/${pkg}.tgz" 2>/dev/null || true
        adb_cmd shell "rm -f /sdcard/app_data.tgz" 2>/dev/null || true
        
        # List databases and prefs
        adb_cmd shell "su -c 'find /data/data/$pkg -type f \( -name *.db -o -name *.xml -o -name *.json \) 2>/dev/null'" > "$out/${pkg}_files.txt" 2>/dev/null || true
        
        # Dump databases if sqlite3 available
        if adb_cmd shell "which sqlite3" >/dev/null 2>&1; then
            adb_cmd shell "su -c 'for db in \$(find /data/data/$pkg -name *.db); do echo \"=== \$db ===\"; sqlite3 \$db .tables; done'" > "$out/${pkg}_db_tables.txt" 2>/dev/null || true
        fi
    else
        root "Список всех пакетов..."
        adb_cmd shell "su -c 'pm list packages'" > "$out/all_packages.txt" 2>/dev/null || true
        root "Топ-20 по размеру..."
        adb_cmd shell "su -c 'du -sh /data/data/* 2>/dev/null | sort -rh | head -20'" > "$out/top_apps_by_size.txt" 2>/dev/null || true
    fi
    log "✅ Данные сохранены: $out"
}

cmd_frida() {
    connect_adb
    local action="${1:-help}"
    shift || true
    
    case "$action" in
        help)
            info "=== Frida / Objection Commands ==="
            log "  frida ls          — процессы (root = все)"
            log "  frida apps        — список приложений"
            log "  frida server      — запустить frida-server на телефоне"
            log "  frida inject <pkg>— objection explore"
            log "  frida trace <pkg> — трассировка API"
            ;;
        ls|ps)
            if [ $HAS_ROOT -eq 1 ]; then
                root "Все процессы (root):"
                adb_cmd shell "su -c 'ps -A'" | head -40
            else
                adb_cmd shell ps | head -40
            fi
            ;;
        apps)
            if [ $HAS_ROOT -eq 1 ]; then
                root "Все пакеты:"
                adb_cmd shell "su -c 'pm list packages'" | head -40
            else
                adb_cmd shell pm list packages | head -40
            fi
            ;;
        server)
            log "Запуск frida-server..."
            if [ ! -f "$WORK_DIR/frida-server" ]; then
                warn "frida-server не найден в $WORK_DIR/"
                warn "Скачайте: https://github.com/frida/frida/releases"
                log "Попытка найти на телефоне..."
            fi
            if adb_cmd shell "test -f /data/local/tmp/frida-server" 2>/dev/null; then
                adb_cmd shell "su -c 'chmod 755 /data/local/tmp/frida-server'" || true
                adb_cmd shell "su -c '/data/local/tmp/frida-server &'" || true
                root "✅ frida-server запущен"
            else
                err "frida-server не найден на телефоне"
                log "Скопируйте: adb push frida-server /data/local/tmp/"
            fi
            ;;
        inject|explore)
            local pkg="${1:-}"
            if [ -z "$pkg" ]; then
                err "Usage: $0 frida inject <package_name>"
                exit 1
            fi
            if command -v objection >/dev/null 2>&1; then
                log "Objection explore: $pkg"
                objection -g "$pkg" explore
            else
                err "objection не установлен: pip install objection"
            fi
            ;;
        trace)
            local pkg="${1:-}"
            if [ -z "$pkg" ]; then
                err "Usage: $0 frida trace <package_name>"
                exit 1
            fi
            if command -v frida-trace >/dev/null 2>&1; then
                log "frida-trace: $pkg"
                frida-trace -U "$pkg"
            else
                err "frida-tools не установлены"
            fi
            ;;
        *)
            err "Unknown frida command: $action"
            ;;
    esac
}

cmd_otg() {
    connect_adb
    info "=== USB OTG Status ==="
    
    if [ $HAS_ROOT -eq 1 ]; then
        root "USB devices (root lsusb):"
        adb_cmd shell "su -c 'lsusb 2>/dev/null'" 2>/dev/null | while read l; do [ -n "$l" ] && log "  $l"; done || true
        root "TTY devices:"
        adb_cmd shell "su -c 'ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'" 2>/dev/null | while read l; do [ -n "$l" ] && log "  $l"; done || true
        root "CAN interfaces:"
        adb_cmd shell "su -c 'ls /sys/class/net/can* 2>/dev/null || echo no CAN'" 2>/dev/null | while read l; do [ -n "$l" ] && log "  $l"; done || true
        root "USB bus permissions:"
        adb_cmd shell "su -c 'ls -la /dev/bus/usb/ 2>/dev/null | head -10'" 2>/dev/null || true
    else
        log "USB devices (limited):"
        adb_cmd shell "lsusb 2>/dev/null" 2>/dev/null | while read l; do [ -n "$l" ] && log "  $l"; done || true
        warn "Для полной информации требуется root"
    fi
    
    log ""
    log "OTG requirements:"
    log "  1. USB-C OTG adapter"
    log "  2. Device supports OTG (willow: YES)"
    log "  3. Root for /dev/ttyUSB*, CAN, direct USB access"
}

cmd_kolibri() {
    connect_adb
    local action="${1:-status}"
    shift || true
    case "$action" in
        status|статус-asm|asm-status)
            info "=== ColibriAsmEngine Status ==="
            adb_cmd shell "su -c 'python /data/data/com.termux/files/home/argos-kolibri/colibri/colibri_cli.py asm-status'" 2>/dev/null || {
                adb_cmd shell "python /data/data/com.termux/files/home/argos-kolibri/colibri/colibri_cli.py asm-status" 2>/dev/null || warn "ColibriAsmEngine not installed"
            }
            ;;
        start)
            root "Starting KolibriOS..."
            adb_cmd shell "su -c 'bash /data/data/com.termux/files/home/argos-kolibri/kolibri-os.sh'" 2>/dev/null || true
            log "KolibriOS started (QEMU i386 + VNC :1)"
            log "Connect: vncviewer $IP:1"
            ;;
        stop)
            root "Stopping KolibriOS..."
            adb_cmd shell "su -c 'bash /data/data/com.termux/files/home/argos-kolibri/kolibri-stop.sh'" 2>/dev/null || true
            log "KolibriOS stopped"
            ;;
        asm|assemble|ассемблировать)
            local code="${1:-}"
            local arch="${2:-arm_thumb}"
            [ -z "$code" ] && code="nop"
            log "colibri asm '$code' --arch $arch"
            adb_cmd shell "python /data/data/com.termux/files/home/argos-kolibri/colibri/colibri_cli.py asm '$code' --arch $arch"
            ;;
        disasm|disassemble|дизассемблировать)
            local data="${1:-90909090}"
            local arch="${2:-arm_thumb}"
            log "colibri disasm '$data' --arch $arch"
            adb_cmd shell "python /data/data/com.termux/files/home/argos-kolibri/colibri/colibri_cli.py disasm '$data' --arch $arch"
            ;;
        file|assemble-file|ассемблировать-файл)
            local path="${1:-}"
            local arch="${2:-arm_thumb}"
            if [ -z "$path" ]; then
                err "Usage: $0 kolibri file <path> [arch]"
                exit 1
            fi
            log "colibri file $path --arch $arch"
            adb_cmd shell "python /data/data/com.termux/files/home/argos-kolibri/colibri/colibri_cli.py file '$path' --arch $arch"
            ;;
        watch)
            local path="${1:-}"
            local arch="${2:-arm_thumb}"
            if [ -z "$path" ]; then
                err "Usage: $0 kolibri watch <path> [arch]"
                exit 1
            fi
            log "colibri watch $path --arch $arch (runs in background)"
            adb_cmd shell "nohup python /data/data/com.termux/files/home/argos-kolibri/colibri/colibri_cli.py watch '$path' --arch $arch >/dev/null 2>&1 &"
            ;;
        watch-stop)
            adb_cmd shell "python /data/data/com.termux/files/home/argos-kolibri/colibri/colibri_cli.py watch-stop"
            ;;
        help|--help|-h)
            log "Kolibri/Colibri commands:"
            log "  status / asm-status      — статус Keystone/Capstone"
            log "  start / stop             — KolibriOS QEMU control"
            log "  asm <code> [arch]        — ассемблирование"
            log "  disasm <hex> [arch]      — дизассемблирование"
            log "  file <path> [arch]       — assemble файл"
            log "  watch <path> [arch]      — авто-сборка при изменениях"
            log "  watch-stop               — остановить наблюдение"
            log ""
            log "Examples:"
            log "  $0 kolibri asm 'mov eax, 1' x86"
            log "  $0 kolibri disasm 90909090 x86"
            log "  $0 kolibri disasm '[arm_thumb:0x8000] 7047'"
            ;;
        *)
            err "Unknown: kolibri $action"
            ;;
    esac
}

cmd_reboot() {
    connect_adb
    log "Rebooting phone..."
    adb_cmd reboot
}

cmd_fastboot_cmd() {
    connect_adb
    log "Rebooting to fastboot..."
    adb_cmd reboot bootloader
    sleep 5
    log "Fastboot devices:"
    fastboot devices
}

cmd_help() {
    cat <<EOF
╔══════════════════════════════════════════════════════════════════════════════╗
║        ARGOS Mobile Toolkit Manager v2.0 — Redmi Note 8T (willow) [ROOTED]║
╚══════════════════════════════════════════════════════════════════════════════╝

Commands:
  status              Full status + root check + OTG devices
  bootstrap           Push Termux bootstrap to phone
  ssh [cmd]           SSH into Termux
  shell [cmd]         ADB shell (auto root if available)
  root_shell          Interactive root shell (su)
  logcat              Capture logcat to file
  screenshot          Take screenshot
  install_apps        Install APKs from apps/ dir
  push <file> [dest]  Push file to phone
  pull_logs           Pull all diagnostic logs
  dump <partition>    Dump partition via dd (root) — default: boot
  app_data [pkg]      Extract /data/data/<pkg> (root, all if no pkg)
  frida <cmd>         Frida/Objection pentest utils
  otg                 Check USB OTG status (root = full)
  kolibri <cmd>       KolibriOS / ColibriAsmEngine (status/start/stop/asm/disasm)
  reboot              Reboot phone
  fastboot            Reboot to fastboot mode

Environment:
  PHONE_IP            Phone IP (default: 192.168.1.149)

Examples:
  ./mobile_manager.sh status
  PHONE_IP=192.168.1.100 ./mobile_manager.sh ssh
  ./mobile_manager.sh shell "lsusb"
  ./mobile_manager.sh dump modem
  ./mobile_manager.sh app_data com.whatsapp
  ./mobile_manager.sh frida inject com.target.app

EOF
}

main() {
    local cmd="${1:-help}"
    shift || true
    case "$cmd" in
        status|s)          cmd_status ;;
        bootstrap|b)       cmd_install_bootstrap ;;
        ssh)               cmd_ssh "$@" ;;
        shell|sh)          cmd_shell "$@" ;;
        root_shell|rsh)    cmd_root_shell ;;
        logcat|log)        cmd_logcat ;;
        screenshot|ss)     cmd_screenshot ;;
        install_apps|apps) cmd_install_apps ;;
        push|p)            cmd_push "$@" ;;
        pull_logs|pull)    cmd_pull_logs ;;
        dump|dd)           cmd_partition_dump "$@" ;;
        app_data|data)     cmd_app_data "$@" ;;
        frida|pentest)     cmd_frida "$@" ;;
        otg)               cmd_otg ;;
        kolibri|colibri)   cmd_kolibri "$@" ;;
        reboot|r)          cmd_reboot ;;
        fastboot|fb)       cmd_fastboot_cmd ;;
        help|h|--help)     cmd_help ;;
        *)                 err "Unknown: $cmd"; cmd_help; exit 1 ;;
    esac
}

main "$@"

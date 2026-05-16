#!/bin/bash
#===============================================================================
#  Redmi Note 8T (willow/ginkgo) — Multi-Tool v2.0 [ROOTED]
#  Дата: 2026-05-13
#  Автор: ARGOS Auto-Builder
#  Статус: ROOT через Magisk 28.1 ✅
#===============================================================================
set -euo pipefail

# ── Конфигурация ─────────────────────────────────────────────────────────────
WORK_DIR="/home/ava/Projects/argoss/firmwares/redmi-note-8t"
TWRP_DIR="$WORK_DIR/twrp"
ROM_DIR="$WORK_DIR/roms"
MAGISK_DIR="$WORK_DIR/magisk"
KERNEL_DIR="$WORK_DIR/kernels"
BACKUP_DIR="$WORK_DIR/backups"
LOG_DIR="$WORK_DIR/logs"

DEVICE_CODENAME="willow"
TWRP_IMG="$TWRP_DIR/twrp-3.4.0-10-ginkgo.img"

mkdir -p "$WORK_DIR"/{twrp,roms,magisk,kernels,scripts,backups,logs,captures}

# ── Цвета ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'; NC='\033[0m'

log()  { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
root() { echo -e "${PURPLE}[ROOT]${NC} $*"; }

# ── Root detection ───────────────────────────────────────────────────────────
HAS_ROOT=0
SU_BIN=""

check_root() {
    HAS_ROOT=0
    SU_BIN=""
    if adb shell "su -c 'id -u'" 2>/dev/null | grep -q "0"; then
        HAS_ROOT=1
        SU_BIN="su -c"
        root "✅ Magisk root доступен (su -c)"
    elif adb shell "su -c 'whoami'" 2>/dev/null | grep -q "root"; then
        HAS_ROOT=1
        SU_BIN="su -c"
        root "✅ Root shell доступен"
    else
        warn "❌ Root не обнаружен — некоторые функции ограничены"
    fi
}

# ── Проверка устройства ──────────────────────────────────────────────────────
check_device() {
    info "=== Проверка подключения ==="
    local devices=$(adb devices | grep -E "^\w+\s+device$" | awk '{print $1}')
    if [ -z "$devices" ]; then
        err "Телефон не подключён или не авторизован"
        err "Подключите USB → Включите USB Debugging → Подтвердите авторизацию на экране"
        exit 1
    fi
    log "Устройство: $devices"
    adb shell "echo device_ok" >/dev/null 2>&1 || { err "ADB shell недоступен"; exit 1; }
    
    local codename=$(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')
    local android=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
    local patch=$(adb shell getprop ro.build.version.security_patch 2>/dev/null | tr -d '\r')
    
    log "Codename : $codename"
    log "Android  : $android"
    log "Patch    : $patch"
    
    if [ "$codename" != "$DEVICE_CODENAME" ] && [ "$codename" != "ginkgo" ]; then
        warn "Codename '$codename' ≠ '$DEVICE_CODENAME' — продолжайте на свой риск"
    fi
    check_root
}

# ── Информация о системе ────────────────────────────────────────────────────
cmd_info() {
    check_device
    info "=== Системная информация ==="
    adb shell "
        echo '=== CPU ==='
        cat /proc/cpuinfo | grep -E 'Hardware|Processor' | head -3
        echo '=== RAM ==='
        cat /proc/meminfo | grep MemTotal
        echo '=== Storage ==='
        df -h /data /system
        echo '=== Partitions ==='
        ls /dev/block/bootdevice/by-name/ 2>/dev/null | head -20
        echo '=== Build ==='
        getprop | grep -E 'ro.build|ro.product|ro.bootloader|ro.boot.verifiedbootstate'
        echo '=== SELinux ==='
        getenforce
        echo '=== Bootloader ==='
        getprop ro.boot.verifiedbootstate
    " 2>&1 | tee "$LOG_DIR/device_info_$(date +%Y%m%d_%H%M%S).log"
}

# ── Root / Magisk инфо ─────────────────────────────────────────────────────
cmd_root_info() {
    check_device
    info "=== Root & Magisk Status ==="
    
    if [ $HAS_ROOT -eq 0 ]; then
        err "Root недоступен"
        return 1
    fi
    
    root "=== Magisk ==="
    adb shell "su -c 'cat /data/adb/magisk/util_functions.sh 2>/dev/null | grep MAGISK_VER='" 2>/dev/null || true
    adb shell "su -c 'ls -la /data/adb/magisk/'" 2>/dev/null | head -10 || true
    
    root "=== Magisk Modules ==="
    adb shell "su -c 'ls /data/adb/modules/'" 2>/dev/null | while read m; do
        [ -n "$m" ] && root "  📦 $m"
    done || warn "Нет модулей или путь другой"
    
    root "=== Superuser Apps ==="
    adb shell "su -c 'pm list packages | grep -i magisk'" 2>/dev/null || true
    adb shell "su -c 'pm list packages | grep -i superuser'" 2>/dev/null || true
    
    root "=== Root Shell Test ==="
    adb shell "su -c 'id; whoami; uname -a'" 2>&1 | tee "$LOG_DIR/root_info_$(date +%Y%m%d_%H%M%S).log"
    
    root "=== USB OTG (root) ==="
    adb shell "su -c 'lsusb 2>/dev/null || echo lsusb not found'" 2>/dev/null || true
    adb shell "su -c 'ls /dev/ttyUSB* 2>/dev/null || echo no ttyUSB devices'" 2>/dev/null || true
    adb shell "su -c 'ls /dev/ttyACM* 2>/dev/null || echo no ttyACM devices'" 2>/dev/null || true
    adb shell "su -c 'ls /sys/class/net/can* 2>/dev/null || echo no CAN interfaces'" 2>/dev/null || true
}

# ── Проверка bootloader ──────────────────────────────────────────────────────
cmd_bootloader_status() {
    info "=== Проверка Bootloader ==="
    adb reboot bootloader
    sleep 8
    local status=$(fastboot getvar unlocked 2>&1 | grep unlocked | awk '{print $2}' || echo "unknown")
    log "Bootloader: $status"
    if [ "$status" = "yes" ]; then
        log "✅ Bootloader разблокирован — можно прошивать"
    else
        err "❌ Bootloader заблокирован"
        err "Инструкция: https://en.miui.com/unlock/"
        err "Требуется 7 дней ожидания после привязки Mi Account"
    fi
    fastboot reboot 2>/dev/null || true
    sleep 5
}

# ── Backup через dd (root) ─────────────────────────────────────────────────
cmd_dd_backup() {
    check_device
    if [ $HAS_ROOT -eq 0 ]; then
        err "Требуется root для прямого доступа к /dev/block"
        return 1
    fi
    
    local ts=$(date +%Y%m%d_%H%M%S)
    local out="$BACKUP_DIR/dd_backup_$ts"
    mkdir -p "$out"
    
    info "=== Full DD Backup (root) ==="
    log "Backup dir: $out"
    
    # Список разделов
    local partitions=$(adb shell "su -c 'ls /dev/block/bootdevice/by-name/'" 2>/dev/null | tr -d '\r' | grep -v '^$')
    
    log "Найдено разделов: $(echo "$partitions" | wc -l)"
    
    for part in boot recovery system vendor dtbo vbmeta modem persist metadata; do
        if echo "$partitions" | grep -q "^${part}$"; then
            log "→ Дамп $part..."
            adb shell "su -c 'dd if=/dev/block/bootdevice/by-name/$part of=/sdcard/${part}_backup.img bs=4M status=progress'" 2>&1 || true
            adb pull "/sdcard/${part}_backup.img" "$out/${part}.img" 2>&1 || warn "Pull $part failed"
            adb shell "rm -f /sdcard/${part}_backup.img" 2>/dev/null || true
        fi
    done
    
    # Magisk backup
    if adb shell "su -c 'test -f /data/adb/magisk/magisk.img'" 2>/dev/null; then
        log "→ Дамп magisk.img..."
        adb shell "su -c 'cp /data/adb/magisk/magisk.img /sdcard/magisk_backup.img'" 2>/dev/null || true
        adb pull /sdcard/magisk_backup.img "$out/magisk.img" 2>/dev/null || true
    fi
    
    adb shell "ls -la /dev/block/bootdevice/by-name/" > "$out/partitions_list.txt" 2>&1 || true
    log "✅ DD Backup завершён: $out"
}

# ── Backup всего ─────────────────────────────────────────────────────────────
cmd_backup() {
    check_device
    local ts=$(date +%Y%m%d_%H%M%S)
    local out="$BACKUP_DIR/backup_$ts"
    mkdir -p "$out"
    
    info "=== Full Backup (adb + fastboot) ==="
    log "Backup dir: $out"
    
    # ADB backup приложений
    log "→ ADB backup приложений..."
    adb backup -apk -shared -all -f "$out/adb_backup.ab" || warn "adb backup failed"
    
    # Boot / Recovery / System через fastboot
    log "→ Перезагрузка в fastboot..."
    adb reboot bootloader
    sleep 8
    
    log "→ Чтение разделов..."
    for part in boot recovery system vendor dtbo vbmeta; do
        if fastboot getvar partition-type:$part 2>>/dev/null | grep -q ""; then
            log "  Чтение $part..."
            fastboot flash $part "$out/$part.img" 2>&1 || true
        fi
    done
    
    # Boot image dump через dd
    log "→ Boot.img через adb shell..."
    adb shell "dd if=/dev/block/bootdevice/by-name/boot of=/sdcard/boot_backup.img bs=4M" 2>&1 || true
    adb pull /sdcard/boot_backup.img "$out/boot_dd.img" 2>&1 || true
    
    # Partitions list
    adb shell "ls -la /dev/block/bootdevice/by-name/" > "$out/partitions_list.txt" 2>&1 || true
    
    fastboot reboot 2>/dev/null || true
    log "✅ Backup завершён: $out"
}

# ── Flash TWRP ───────────────────────────────────────────────────────────────
cmd_flash_twrp() {
    check_device
    if [ ! -f "$TWRP_IMG" ]; then
        err "TWRP не найден: $TWRP_IMG"
        err "Скачайте вручную: https://twrp.me/xiaomi/xiaomiredminote8.html"
        info "Положите .img файл в: $TWRP_DIR/"
        exit 1
    fi
    
    info "=== Flash TWRP ==="
    log "Image: $TWRP_IMG"
    
    adb reboot bootloader
    sleep 8
    
    fastboot flash recovery "$TWRP_IMG"
    log "✅ TWRP прошит"
    
    log "→ Загрузка в TWRP (ВАЖНО: не перезагружать в систему сразу!)"
    fastboot boot "$TWRP_IMG"
    
    info "=== Инструкция ==="
    log "1. На телефоне TWRP: Swipe to allow modifications"
    log "2. Wipe → Format Data → type 'yes'"
    log "3. Reboot → Recovery (остаться в TWRP)"
    log "4. Только после этого можно Reboot → System"
}

# ── Flash Magisk (Root) ────────────────────────────────────────────────────
cmd_flash_magisk() {
    local magisk_zip="${1:-$MAGISK_DIR/magisk.zip}"
    if [ ! -f "$magisk_zip" ]; then
        err "Magisk zip не найден: $magisk_zip"
        err "Скачайте: https://github.com/topjohnwu/Magisk/releases"
        err "Переименуйте .apk → .zip"
        exit 1
    fi
    
    info "=== Flash Magisk (Root) ==="
    log "File: $magisk_zip"
    log "Требуется TWRP. Загрузитесь в TWRP:"
    log "  adb reboot recovery   (если TWRP уже установлен)"
    log "Или:"
    log "  fastboot boot twrp.img  (если ещё не установлен)"
    log ""
    log "В TWRP:"
    log "  Install → выбрать $magisk_zip → Swipe to confirm"
    log "  Reboot → System"
    log ""
    log "После загрузки Android: установить Magisk.apk как приложение"
    log "  adb install Magisk.apk"
}

# ── Flash ROM (LineageOS) ───────────────────────────────────────────────────
cmd_flash_rom() {
    local rom_zip="${1:-$ROM_DIR/lineageos.zip}"
    if [ ! -f "$rom_zip" ]; then
        err "ROM zip не найден: $rom_zip"
        err "Скачайте LineageOS: https://download.lineageos.org/devices/ginkgo/builds"
        exit 1
    fi
    
    info "=== Flash LineageOS ==="
    log "ROM: $rom_zip"
    log "Важно: firmware должен быть Android 11+ (MIUI 12.5)"
    log ""
    log "В TWRP:"
    log "  1. Wipe → Advanced Wipe → System, Data, Cache, Dalvik"
    log "  2. Install → $rom_zip → Swipe"
    log "  3. Reboot → Recovery"
    log ""
    log "Если нужны GApps → установить сразу после ROM (перезагрузка в Recovery)"
    log "Если нужен Magisk → установить последним"
}

# ── Flash Kernel ─────────────────────────────────────────────────────────────
cmd_flash_kernel() {
    local kernel_img="${1:-$KERNEL_DIR/kernel.img}"
    if [ ! -f "$kernel_img" ]; then
        err "Kernel image не найден: $kernel_img"
        err "Варианты для ginkgo/willow: FrancoKernel, NGK, Predator Kernel"
        exit 1
    fi
    
    info "=== Flash Custom Kernel ==="
    log "Kernel: $kernel_img"
    
    adb reboot bootloader
    sleep 8
    fastboot flash boot "$kernel_img"
    fastboot reboot
    log "✅ Kernel прошит"
}

# ── Flash через Fastboot (универсально) ────────────────────────────────────
cmd_fastboot_flash() {
    local img="${1:-}"
    local partition="${2:-boot}"
    if [ -z "$img" ] || [ ! -f "$img" ]; then
        err "Использование: $0 fastboot_flash <image.img> [partition]"
        err "Пример: $0 fastboot_flash boot.img boot"
        exit 1
    fi
    
    info "=== Fastboot Flash ==="
    log "Image: $img"
    log "Partition: $partition"
    
    adb reboot bootloader
    sleep 8
    fastboot flash "$partition" "$img"
    fastboot reboot
    log "✅ Готово"
}

# ── ADB Shell с root (если Magisk есть) ──────────────────────────────────────
cmd_shell() {
    check_device
    local args="$*"
    if [ -z "$args" ]; then
        # Интерактивный shell
        if [ $HAS_ROOT -eq 1 ]; then
            root "Интерактивный ROOT shell (su)"
            adb shell "su"
        else
            log "Интерактивный ADB shell (без root)"
            adb shell
        fi
    else
        if [ $HAS_ROOT -eq 1 ]; then
            root "su -c '$args'"
            adb shell "su -c '$args'"
        else
            log "adb shell '$args'"
            adb shell "$args"
        fi
    fi
}

# ── Root Shell напрямую ──────────────────────────────────────────────────────
cmd_root_shell() {
    check_device
    if [ $HAS_ROOT -eq 0 ]; then
        err "Root не доступен"
        exit 1
    fi
    root "Открываю root shell (su)..."
    adb shell "su"
}

# ── Захват logcat ────────────────────────────────────────────────────────────
cmd_logcat() {
    local out="$LOG_DIR/logcat_$(date +%Y%m%d_%H%M%S).txt"
    log "Захват logcat → $out (Ctrl+C для остановки)"
    adb logcat -v threadtime | tee "$out"
}

# ── Screenshot / Screenrecord ───────────────────────────────────────────────
cmd_screenshot() {
    local out="$WORK_DIR/captures/screen_$(date +%Y%m%d_%H%M%S).png"
    mkdir -p "$WORK_DIR/captures"
    adb shell screencap -p /sdcard/screen.png
    adb pull /sdcard/screen.png "$out"
    log "Screenshot: $out"
}

cmd_screenrecord() {
    local out="$WORK_DIR/captures/screenrecord_$(date +%Y%m%d_%H%M%S).mp4"
    mkdir -p "$WORK_DIR/captures"
    log "Recording... Нажмите Ctrl+C для остановки"
    adb shell screenrecord /sdcard/record.mp4 &
    local pid=$!
    trap "kill $pid; adb pull /sdcard/record.mp4 $out; log 'Saved: $out'; exit" INT
    wait $pid
}

# ── Frida / Objection (требует root для лучших результатов) ─────────────────
cmd_frida() {
    check_device
    local pkg="${1:-}"
    if [ -z "$pkg" ]; then
        info "=== Frida Utils ==="
        log "Установленные пакеты (frida):"
        pip show frida 2>/dev/null || warn "frida не найден в pip"
        log ""
        log "Использование:"
        log "  $0 frida ls          — список процессов"
        log "  $0 frida ps          — список приложений"
        log "  $0 frida inject <pkg> — инжект в приложение"
        log "  $0 frida trace <pkg>  — трассировка API"
        return 0
    fi
    
    case "$pkg" in
        ls|ps|list)
            if [ $HAS_ROOT -eq 1 ]; then
                root "Список процессов (root):"
                adb shell "su -c 'ps -A'" | head -30
            else
                adb shell ps | head -30
            fi
            ;;
        apps)
            if [ $HAS_ROOT -eq 1 ]; then
                root "Все пакеты (root, включая системные):"
                adb shell "su -c 'pm list packages'" | head -40
            else
                adb shell pm list packages | head -40
            fi
            ;;
        *)
            local target="$pkg"
            log "Frida inject в $target..."
            # Запуск frida-server на телефоне если есть
            if adb shell "test -f /data/local/tmp/frida-server" 2>/dev/null; then
                adb shell "su -c '/data/local/tmp/frida-server &'" 2>/dev/null || true
            fi
            # Objection
            if command -v objection >/dev/null 2>&1; then
                log "Objection explore: $target"
                objection -g "$target" explore 2>/dev/null || warn "Objection failed"
            else
                warn "objection не установлен на ПК: pip install objection"
            fi
            ;;
    esac
}

# ── Dump данных приложений (root) ────────────────────────────────────────────
cmd_app_dump() {
    check_device
    if [ $HAS_ROOT -eq 0 ]; then
        err "Требуется root для доступа к /data/data/"
        exit 1
    fi
    local pkg="${1:-}"
    local ts=$(date +%Y%m%d_%H%M%S)
    local out="$WORK_DIR/captures/app_dump_${pkg:-all}_$ts"
    mkdir -p "$out"
    
    if [ -n "$pkg" ]; then
        root "Дамп $pkg..."
        adb shell "su -c 'tar czf /sdcard/app_dump.tgz /data/data/$pkg 2>/dev/null'" || true
        adb pull /sdcard/app_dump.tgz "$out/${pkg}.tgz" 2>/dev/null || true
        adb shell "rm -f /sdcard/app_dump.tgz" 2>/dev/null || true
        # Databases
        adb shell "su -c 'find /data/data/$pkg -name *.db -o -name *.xml -o -name shared_prefs'" 2>/dev/null > "$out/${pkg}_files.txt" || true
    else
        root "Дамп списка всех пакетов..."
        adb shell "su -c 'pm list packages'" > "$out/all_packages.txt" 2>/dev/null || true
    fi
    log "✅ Дамп сохранён: $out"
}

# ── Помощь ───────────────────────────────────────────────────────────────────
show_help() {
    cat <<'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║     Redmi Note 8T (willow/ginkgo) — Multi-Tool v2.0 [ROOTED]               ║
╚══════════════════════════════════════════════════════════════════════════════╝

Команды:
  info                    Полная информация об устройстве
  root_info               Статус Magisk, модули, root shell
  bootloader              Проверка статуса bootloader
  backup                  Полный backup (adb + boot.img)
  dd_backup               Быстрый backup разделов через dd (root)
  twrp                    Прошить TWRP recovery
  magisk [file]           Инструкция/установка Magisk
  rom [file]              Инструкция/установка LineageOS
  kernel [file]           Прошить custom kernel
  flash <img> [part]      Универсальный fastboot flash
  shell [cmd]             ADB shell (root если доступен)
  root_shell              Интерактивный root shell (su)
  logcat                  Захват logcat в файл
  screenshot              Сделать скриншот
  screenrecord            Записать экран
  frida [cmd]             Frida/Objection пентест utils
  app_dump [pkg]          Дамп данных приложения /data/data/ (root)

Быстрые сценарии:
  full_setup              TWRP + LineageOS + GApps + Magisk (пошагово)
  root_only               Установить Magisk на стоковый ROM

Пути:
  TWRP:     /home/ava/Projects/argoss/firmwares/redmi-note-8t/twrp/
  ROMs:     /home/ava/Projects/argoss/firmwares/redmi-note-8t/roms/
  Magisk:   /home/ava/Projects/argoss/firmwares/redmi-note-8t/magisk/
  Kernels:  /home/ava/Projects/argoss/firmwares/redmi-note-8t/kernels/
  Backups:  /home/ava/Projects/argoss/firmwares/redmi-note-8t/backups/

EOF
}

# ── Full Setup (пошагово) ────────────────────────────────────────────────────
cmd_full_setup() {
    info "=== Полная прошивка Redmi Note 8T ==="
    log "Этапы:"
    log "  1. Backup текущей системы"
    log "  2. Flash TWRP"
    log "  3. Wipe + Flash LineageOS"
    log "  4. Flash GApps (опционально)"
    log "  5. Flash Magisk (опционально)"
    log ""
    read -p "Начать? Текущие данные будут стёрты! [y/N] " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "Отменено"
        exit 0
    fi
    
    cmd_backup
    cmd_flash_twrp
    
    log ""
    log "Теперь на телефоне TWRP. Дальнейшие шаги вручную:"
    log "  TWRP → Wipe → Format Data → type 'yes'"
    log "  TWRP → Reboot → Recovery"
    log "  Затем: Install → LineageOS.zip → Swipe"
    log "  Затем: Install → GApps.zip (если нужны)"
    log "  Затем: Install → Magisk.zip (если нужен root)"
    log "  Reboot → System"
}

# ── Root Only (Magisk на сток) ───────────────────────────────────────────────
cmd_root_only() {
    info "=== Установка Magisk на стоковый ROM ==="
    log "Требуется TWRP или patched boot.img"
    
    log "Метод: Patched Boot Image"
    log "  1. Скачать Magisk.apk → установить на телефон"
    log "  2. Magisk → Install → Select and Patch a File"
    log "  3. Выбрать boot.img (из backup или firmware)"
    log "  4. Скопировать patched_boot.img на ПК: adb pull /sdcard/Download/magisk_patched.img"
    log "  5. adb reboot bootloader"
    log "  6. fastboot flash magisk_patched.img boot"
    log "  7. fastboot reboot"
    log ""
    log "Или прошить Magisk.zip через TWRP"
    cmd_flash_magisk
}

# ── Главная точка входа ──────────────────────────────────────────────────────
main() {
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        info|i)             cmd_info ;;
        root_info|ri)       cmd_root_info ;;
        bootloader|bl)      cmd_bootloader_status ;;
        backup|b)           cmd_backup ;;
        dd_backup|ddb)      cmd_dd_backup ;;
        twrp|t)             cmd_flash_twrp ;;
        magisk|root)        cmd_flash_magisk "$@" ;;
        rom|lineage)        cmd_flash_rom "$@" ;;
        kernel|k)           cmd_flash_kernel "$@" ;;
        flash|f)            cmd_fastboot_flash "$@" ;;
        shell|sh)           cmd_shell "$@" ;;
        root_shell|rsh)     cmd_root_shell ;;
        logcat|log)         cmd_logcat ;;
        screenshot|ss)      cmd_screenshot ;;
        screenrecord|rec)   cmd_screenrecord ;;
        frida|pentest)      cmd_frida "$@" ;;
        app_dump|dump)      cmd_app_dump "$@" ;;
        full_setup|setup)   cmd_full_setup ;;
        root_only)          cmd_root_only ;;
        help|h|--help|-h)   show_help ;;
        *)                  err "Неизвестная команда: $cmd"; show_help; exit 1 ;;
    esac
}

main "$@"

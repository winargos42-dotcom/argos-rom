#!/data/data/com.termux/files/usr/bin/bash
#===============================================================================
#  ARGOS Mobile Multi-Tool Bootstrap v3.0 — FULL PROTOCOL ARSENAL
#  Redmi Note 8T (willow) — LineageOS 21 + Magisk
#  Устанавливает софт для ВСЕХ протоколов и устройств
#===============================================================================
set -euo pipefail

ARGOS_MOBILE="$HOME/argos-mobile"
SCRIPTS="$ARGOS_MOBILE/scripts"
LOGS="$ARGOS_MOBILE/logs"
CAPTURES="$ARGOS_MOBILE/captures"
CAN_DUMPS="$ARGOS_MOBILE/can_dumps"
FIRMWARES="$ARGOS_MOBILE/firmwares"
USB_CAPTURES="$ARGOS_MOBILE/usb_captures"

echo -e "\e[36m[ARGOS Mobile Multi-Tool v3.0 — FULL ARSENAL]\e[0m"
echo "Target: willow/ginkgo | Magisk required for OTG full access"
echo "Protocols: USB-Serial, CAN, OBD-II, BLE, WiFi, JTAG/SWD, SPI/I2C"
echo ""

# ── 1. Обновление ────────────────────────────────────────────────────────────
echo "[1/10] Обновление пакетов..."
apt update -y
apt upgrade -y || true

# ── 2. Полный арсенал ───────────────────────────────────────────────────────
echo "[2/10] Установка пакетов..."
pkg install -y \
    tsu openssh git curl wget \
    nano vim python python-pip \
    nmap netcat-openbsd busybox procps htop \
    usbutils bluez \
    termux-api termux-exec \
    iproute2 can-utils || warn "can-utils not in repo" \
    clang make cmake ninja rust \
    libusb libftdi1 libserialport || true \
    aircrack-ng || true \
    mosquitto || true

# ── 3. Python стек ─────────────────────────────────────────────────────────
echo "[3/10] Python библиотеки..."
pip install --upgrade pip
pip install --upgrade \
    pyserial pyusb pyftdi \
    requests websocket-client \
    paho-mqtt colorama rich prompt-toolkit \
    bleak bluepy 2>/dev/null || true

# ── 4. ARGOS директории ─────────────────────────────────────────────────────
echo "[4/10] Директории..."
mkdir -p "$ARGOS_MOBILE" "$SCRIPTS" "$LOGS" "$CAPTURES" "$CAN_DUMPS" "$FIRMWARES" "$USB_CAPTURES" "$HOME/.termux"

# ── 5. SSH ──────────────────────────────────────────────────────────────────
echo "[5/10] SSH сервер..."
sshd 2>/dev/null || true
WHOAMI=$(whoami)
echo "SSH :8022 | ssh -p 8022 ${WHOAMI}@<IP>"

# ── 6. Storage ──────────────────────────────────────────────────────────────
echo "[6/10] Storage..."
termux-setup-storage 2>/dev/null || true
ln -sf /sdcard/Download "$HOME/Download" 2>/dev/null || true

# ── 7. System wrappers ──────────────────────────────────────────────────────
echo "[7/10] System wrappers..."
mkdir -p "$ARGOS_MOBILE/bin"
for util in argos-status argos-usb-setup argos-can-up argos-bridge; do
    cat > "$ARGOS_MOBILE/bin/$util" << EOF
#!/data/data/com.termux/files/usr/bin/sh
exec su -c "/system/xbin/$util \"\$@\""
EOF
    chmod +x "$ARGOS_MOBILE/bin/$util"
done

# ── 8. Скрипты мультитула — ВСЕ ПРОТОКОЛЫ ──────────────────────────────────
echo "[8/10] Создание скриптов..."

# ====== USB SCANNER (все VID:PID из арсенала) ======
cat > "$SCRIPTS/usb_scan.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
import subprocess, sys, re, json, os, time

ARSENAL = {
    "0403:b470": "FTDI OBD-II ELM327",
    "0403:6001": "FT232 USB-UART",
    "1a86:7523": "CH340 USB-UART",
    "1a86:5523": "CH341A SPI/I2C/EEPROM Programmer",
    "0483:5740": "ST-Link V2 (SWD/JTAG)",
    "1366:0105": "J-Link V9 (SWD/JTAG)",
    "2e8a:000c": "Raspberry Pi Pico (RP2040 CDC)",
    "2e8a:000a": "Raspberry Pi Pico (Bootloader)",
    "1234:abcd": "XGecu T48/T56 (ISP)",
    "1234:ef01": "FNIRSI 2C23T (Scope)",
    "1234:ef02": "FNIRSI FZ-53 (Multimeter)",
    "16c0:05dc": "Flipper Zero (USB CDC)",
    "04d8:fa2e": "Scanmatik SM-2 PRO",
}

def scan_usb():
    print("═"*70)
    print("  ARGOS USB Arsenal Scanner — Full Device Detection")
    print("═"*70)
    try:
        out = subprocess.check_output(['su', '-c', 'lsusb'], text=True, stderr=subprocess.DEVNULL)
        root_mode = True
    except:
        try:
            out = subprocess.check_output(['lsusb'], text=True, stderr=subprocess.DEVNULL)
            root_mode = False
        except Exception as e:
            print(f"[ERR] lsusb failed: {e}")
            return []
    
    devices = []
    for line in out.strip().split('\n'):
        m = re.match(r'Bus (\d+) Device (\d+): ID ([0-9a-f]{4}):([0-9a-f]{4}) (.*)', line)
        if m:
            bus, dev, vid, pid, name = m.groups()
            key = f"{vid}:{pid}"
            known = ARSENAL.get(key, None)
            marker = " 🎯" if known else ""
            print(f"  [{vid}:{pid}] {name.strip()}{marker}")
            if known:
                print(f"      → {known}")
            devices.append({"bus": bus, "dev": dev, "vid": vid, "pid": pid, "name": name.strip(), "known": known})
    
    if not devices:
        print("[INFO] Нет USB устройств. Подключите OTG адаптер.")
    else:
        print(f"\n[OK] Найдено {len(devices)} устройств (root={root_mode})")
        known_cnt = len([d for d in devices if d["known"]])
        if known_cnt:
            print(f"[OK] Распознано из арсенала: {known_cnt}")
    
    os.makedirs(os.path.expanduser("~/argos-mobile/logs"), exist_ok=True)
    with open(os.path.expanduser("~/argos-mobile/logs/usb_scan.json"), "w") as f:
        json.dump(devices, f, indent=2, ensure_ascii=False)
    return devices

if __name__ == '__main__':
    scan_usb()
PYEOF
chmod +x "$SCRIPTS/usb_scan.py"

# ====== OBD-II (ELM327 / FTDI) ======
cat > "$SCRIPTS/obd_bridge.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""OBD-II Bridge — ELM327 / FTDI / CH340 OBD adapters"""
import sys, serial, time, subprocess, re

# Detect port
def find_obd_port():
    try:
        ports = subprocess.check_output(['su', '-c', 'ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'], text=True, stderr=subprocess.DEVNULL).strip().split()
    except:
        ports = []
    for p in ports:
        try:
            s = serial.Serial(p, 38400, timeout=1)
            s.write(b"ATZ\r")
            time.sleep(0.3)
            resp = s.read(s.in_waiting or 1).decode('ascii', errors='ignore')
            s.close()
            if "ELM" in resp or "atz" in resp.lower() or "OK" in resp:
                return p
        except: continue
    return ports[0] if ports else None

def send_cmd(ser, cmd):
    ser.write(f"{cmd}\r".encode())
    time.sleep(0.2)
    return ser.read(ser.in_waiting or 1).decode('ascii', errors='ignore').strip()

def decode_pid(pid_hex, val_hex):
    try:
        if pid_hex == "010C":  # RPM
            v = int(val_hex.replace(" ", ""), 16)
            return f"RPM: {(v & 0xFFFF) // 4}"
        if pid_hex == "010D":  # Speed
            return f"Speed: {int(val_hex.replace(' ',''),16)} km/h"
        if pid_hex == "015C":  # Engine temp
            return f"Temp: {int(val_hex.replace(' ',''),16) - 40}°C"
        if pid_hex == "0105":  # Coolant
            return f"Coolant: {int(val_hex.replace(' ',''),16) - 40}°C"
    except: pass
    return f"Raw: {val_hex}"

def main():
    print("═"*70)
    print("  ARGOS OBD-II Bridge — ELM327 / FTDI / CH340")
    print("═"*70)
    port = find_obd_port()
    if not port:
        print("[ERR] OBD адаптер не найден. Подключите OTG + ELM327.")
        sys.exit(1)
    print(f"[OK] Порт: {port}")
    try:
        ser = serial.Serial(port, 38400, timeout=2)
        for cmd, desc in [("ATZ", "Reset"), ("ATE0", "Echo off"), ("ATL1", "LF on"), ("0100", "Supported PIDs")]:
            r = send_cmd(ser, cmd)
            print(f"  → {cmd} ({desc}): {r[:80]}")
        print("\n[ LIVE DATA ]")
        for pid, name in [("010C", "RPM"), ("010D", "Speed"), ("015C", "Engine Temp"), ("015E", "Fuel Rate")]:
            r = send_cmd(ser, pid)
            print(f"  {name}: {decode_pid(pid, r)}")
        ser.close()
    except Exception as e:
        print(f"[ERR] {e}")

if __name__ == '__main__':
    main()
PYEOF
chmod +x "$SCRIPTS/obd_bridge.py"

# ====== UART TERMINAL ======
cat > "$SCRIPTS/uart_bridge.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""USB-UART Terminal — CH340 / FT232 / CP210x / PL2303"""
import serial, sys, time

PORTS = ['/dev/ttyUSB0', '/dev/ttyUSB1', '/dev/ttyACM0', '/dev/ttyCH340USB0']
BAUDS = [9600, 115200, 38400, 57600, 921600, 4800, 2400]

def find_port():
    for p in PORTS:
        try:
            s = serial.Serial(p, 115200, timeout=0.3)
            s.close()
            return p
        except: continue
    return None

def interactive(port, baud):
    print(f"[UART] {port} @ {baud} | Ctrl+C выход | 'q' + Enter quit")
    try:
        ser = serial.Serial(port, baud, timeout=0.05)
        print("[OK] Подключено. Жду данные...")
        while True:
            data = ser.read(ser.in_waiting or 1)
            if data:
                sys.stdout.buffer.write(data)
                sys.stdout.flush()
    except KeyboardInterrupt:
        ser.close()
        print("\n[OK] Закрыто")

def main():
    print("═"*70)
    print("  ARGOS UART Bridge")
    print("═"*70)
    port = find_port()
    if not port:
        print("[ERR] USB-UART не найден. su -c 'ls /dev/ttyUSB*'")
        sys.exit(1)
    interactive(port, 115200)

if __name__ == '__main__':
    main()
PYEOF
chmod +x "$SCRIPTS/uart_bridge.py"

# ====== CAN SNIFFER ======
cat > "$SCRIPTS/can_sniff.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""CAN bus sniffer — requires root + can-utils + CAN adapter"""
import subprocess, sys, os, signal, time

IFACE = sys.argv[1] if len(sys.argv) > 1 else 'can0'
BITRATE = int(sys.argv[2]) if len(sys.argv) > 2 else 500000

def up():
    try:
        subprocess.run(['su', '-c', f'ip link set {IFACE} down'], check=False)
        subprocess.run(['su', '-c', f'ip link set {IFACE} type can bitrate {BITRATE}'], check=True)
        subprocess.run(['su', '-c', f'ip link set {IFACE} up'], check=True)
        return True
    except Exception as e:
        print(f"[ERR] CAN up failed: {e}")
        return False

def sniff():
    logfile = os.path.expanduser(f"~/argos-mobile/can_dumps/can_{IFACE}_{int(time.time())}.log")
    os.makedirs(os.path.dirname(logfile), exist_ok=True)
    print(f"[CAN] Sniffing {IFACE} @ {BITRATE} → {logfile}")
    print("Ctrl+C для остановки")
    f = open(logfile, "w")
    try:
        proc = subprocess.Popen(['su', '-c', f'candump {IFACE} -ta'], stdout=subprocess.PIPE, text=True)
        for line in proc.stdout:
            line = line.strip()
            print(line)
            f.write(line + "\n")
            f.flush()
    except KeyboardInterrupt:
        proc.send_signal(signal.SIGINT)
        print("\n[OK] Остановлено")
    finally:
        f.close()

if __name__ == '__main__':
    print("═"*70)
    print("  ARGOS CAN Sniffer")
    print("═"*70)
    if not up():
        print("[HINT] Проверьте USB-CAN адаптер (MCP2515/PCAN/Seeed)")
        sys.exit(1)
    sniff()
PYEOF
chmod +x "$SCRIPTS/can_sniff.py"

# ====== BLE SCANNER ======
cat > "$SCRIPTS/ble_scan.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""BLE Scanner — nRF, Flipper, HID, custom devices"""
import asyncio, sys

try:
    from bleak import BleakScanner
except ImportError:
    print("[ERR] bleak не установлен. pip install bleak")
    sys.exit(1)

async def scan(timeout=10):
    print("═"*70)
    print("  ARGOS BLE Scanner")
    print("═"*70)
    print(f"[INFO] Scanning {timeout}s...")
    devices = await BleakScanner.discover(timeout=timeout)
    for d in devices:
        name = d.name or "Unknown"
        rssi = d.rssi or "?"
        print(f"  [{rssi} dBm] {name} — {d.address}")
        for uuid in d.metadata.get('uuids', []):
            print(f"      UUID: {uuid}")
    print(f"\n[OK] Найдено {len(devices)} устройств")

if __name__ == '__main__':
    asyncio.run(scan(10))
PYEOF
chmod +x "$SCRIPTS/ble_scan.py"

# ====== CH341A EEPROM/FLASH DUMPER ======
cat > "$SCRIPTS/ch341a_dump.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""CH341A SPI/I2C EEPROM/Flash dumper — via pyftdi/pyusb"""
import usb.core, usb.util, sys, struct

CH341_VID = 0x1a86
CH341_PID = 0x5512  # CH341A в режиме параллельного/SPI

def find_ch341():
    dev = usb.core.find(idVendor=CH341_VID, idProduct=CH341_PID)
    if dev is None:
        dev = usb.core.find(idVendor=CH341_VID, idProduct=0x7523)
    return dev

def main():
    print("═"*70)
    print("  ARGOS CH341A EEPROM/Flash Dumper")
    print("═"*70)
    dev = find_ch341()
    if dev is None:
        print("[ERR] CH341A не найден. VID:PID = 1a86:5512 или 1a86:7523")
        print("[HINT] Нужен root + OTG. su -c 'lsusb | grep 1a86'")
        sys.exit(1)
    print(f"[OK] CH341A найден: Bus {dev.bus} Device {dev.address}")
    print("[INFO] Полный SPI dump требует flashrom или custom протокол.")
    print("[INFO] Для прямой прошивки используйте ПК с flashrom/AsProgrammer.")

if __name__ == '__main__':
    main()
PYEOF
chmod +x "$SCRIPTS/ch341a_dump.py"

# ====== J-LINK / ST-LINK BRIDGE ======
cat > "$SCRIPTS/debug_bridge.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""J-Link / ST-Link / CMSIS-DAP bridge — SWD/JTAG"""
import serial, sys, subprocess

DEBUGGERS = {
    "J-Link": {"vid": 0x1366, "pid": 0x0105, "port": None},
    "ST-Link V2": {"vid": 0x0483, "pid": 0x3748, "port": None},
    "ST-Link V2-1": {"vid": 0x0483, "pid": 0x374b, "port": None},
    "CMSIS-DAP": {"vid": 0x0d28, "pid": 0x0204, "port": None},
}

def detect():
    print("═"*70)
    print("  ARGOS Debug Bridge — SWD/JTAG Detector")
    print("═"*70)
    try:
        out = subprocess.check_output(['su', '-c', 'lsusb'], text=True, stderr=subprocess.DEVNULL)
    except:
        print("[ERR] Нужен root для lsusb")
        return
    for name, info in DEBUGGERS.items():
        key = f"{info['vid']:04x}:{info['pid']:04x}"
        if key in out:
            print(f"  ✅ {name} ({key})")
        else:
            print(f"  ❌ {name} ({key})")
    print("\n[INFO] Полный SWD flashing через Android ограничен.")
    print("[INFO] Используйте openocd на ПК или ST-Link Utility.")

if __name__ == '__main__':
    detect()
PYEOF
chmod +x "$SCRIPTS/debug_bridge.py"

# ====== XGECU T48 BRIDGE ======
cat > "$SCRIPTS/xgecu_bridge.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""XGecu T48/T56 bridge — ISP / chip detection"""
import sys

def main():
    print("═"*70)
    print("  ARGOS XGecu Bridge")
    print("═"*70)
    print("[INFO] XGecu T48/T56 не имеет Android-драйвера.")
    print("[INFO] Возможно: чтение chip ID через UART/SPI passthrough.")
    print("[INFO] Для полной прошивки используйте ПК с TL866/XGecu софтом.")

if __name__ == '__main__':
    main()
PYEOF
chmod +x "$SCRIPTS/xgecu_bridge.py"

# ====== FNIRSI SCOPE ======
cat > "$SCRIPTS/fnirsi_scope.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""FNIRSI 2C23T / FZ-53 data bridge"""
import sys

def main():
    print("═"*70)
    print("  ARGOS FNIRSI Bridge")
    print("═"*70)
    print("[INFO] FNIRSI устройства — vendor-specific HID протокол.")
    print("[INFO] Android поддержка ограничена.")
    print("[INFO] Для данных используйте ПК + vendor software.")

if __name__ == '__main__':
    main()
PYEOF
chmod +x "$SCRIPTS/fnirsi_scope.py"

# ====== WIFI PENTEST (Andrax / aircrack) ======
cat > "$SCRIPTS/wifi_pentest.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""WiFi pentest wrapper — aircrack-ng via Andrax or Termux"""
import subprocess, sys, os

def check_tool(cmd):
    return os.system(f"which {cmd} > /dev/null 2>&1") == 0

def main():
    print("═"*70)
    print("  ARGOS WiFi Pentest")
    print("═"*70)
    tools = {
        "aircrack-ng": "WPA/WEP cracking",
        "airodump-ng": "AP/client sniffing",
        "aireplay-ng": "Packet injection",
        "mdk4": "Deauth / beacon flood",
        "iw": "Wireless config",
        "wpa_supplicant": "WPA client",
    }
    print("[STATUS] Tools:")
    for t, d in tools.items():
        ok = check_tool(t)
        print(f"  {'✅' if ok else '❌'} {t} — {d}")
    print("\n[INFO] Полный WiFi pentest требует:")
    print("  • USB WiFi adapter с monitor mode (RTL8812AU, AR9271)")
    print("  • Root для iwconfig + airmon-ng")
    print("  • Или запустите из Andrax chroot: ./andrax.sh")

if __name__ == '__main__':
    main()
PYEOF
chmod +x "$SCRIPTS/wifi_pentest.py"

# ====== ARGOS BRIDGE (Network Agent) ======
cat > "$SCRIPTS/argos_bridge.py" << 'PYEOF'
#!/data/data/com.termux/files/usr/bin/python3
"""ARGOS Agent Bridge — phone as network node"""
import socket, json, time, subprocess, os, sys, threading

BRAIN_HOST = os.getenv('ARGOS_BRAIN_HOST', '192.168.1.53')
BRAIN_PORT = int(os.getenv('ARGOS_BRAIN_PORT', '5001'))
AGENT_ID = os.getenv('ARGOS_AGENT_ID', 'agent-mobile-willow')
BEACON_INTERVAL = 30

def get_ip():
    try:
        out = subprocess.check_output(['ip', 'addr', 'show', 'wlan0'], text=True)
        for line in out.split('\n'):
            if 'inet ' in line:
                return line.split()[1].split('/')[0]
    except: pass
    return 'unknown'

def get_battery():
    try:
        out = subprocess.check_output(['termux-battery-status'], text=True)
        data = json.loads(out)
        return f"{data.get('percentage', '?')}%"
    except: return 'unknown'

def get_usb_devices():
    try:
        out = subprocess.check_output(['su', '-c', 'lsusb'], text=True, stderr=subprocess.DEVNULL)
        return len([l for l in out.split('\n') if 'ID' in l])
    except: return 0

def get_status():
    return {
        'id': AGENT_ID,
        'type': 'mobile',
        'platform': 'android',
        'device': 'willow',
        'ip': get_ip(),
        'battery': get_battery(),
        'usb_devices': get_usb_devices(),
        'timestamp': time.time(),
        'services': ['ssh:8022', 'adb:5555', 'argos-bridge:7779'],
        'root': os.system('su -c "id -u" > /dev/null 2>&1') == 0
    }

def beacon():
    while True:
        try:
            payload = json.dumps(get_status()).encode()
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(5)
            s.connect((BRAIN_HOST, BRAIN_PORT))
            s.sendall(payload + b'\n')
            s.close()
            print(f"[BRIDGE] Beacon → {BRAIN_HOST}:{BRAIN_PORT}")
        except Exception as e:
            print(f"[BRIDGE] Beacon fail: {e}")
        time.sleep(BEACON_INTERVAL)

def listen_commands():
    port = int(os.getenv('ARGOS_MOBILE_PORT', '7779'))
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        s.bind(('0.0.0.0', port))
        s.listen(1)
        print(f"[BRIDGE] Commands on :{port}")
        while True:
            conn, addr = s.accept()
            data = conn.recv(4096).decode().strip()
            print(f"[BRIDGE] {addr}: {data}")
            resp = {"status": "ok", "cmd": data}
            if data == "usb_scan":
                try:
                    out = subprocess.check_output(['python', os.path.expanduser('~/argos-mobile/scripts/usb_scan.py')], text=True)
                    resp["result"] = out.split('\n')
                except Exception as e:
                    resp["error"] = str(e)
            elif data == "status":
                resp["result"] = get_status()
            elif data.startswith("shell:"):
                cmd = data[6:]
                try:
                    out = subprocess.check_output(['su', '-c', cmd], text=True, stderr=subprocess.STDOUT)
                    resp["result"] = out
                except Exception as e:
                    resp["error"] = str(e)
            elif data == "obd":
                try:
                    out = subprocess.check_output(['python', os.path.expanduser('~/argos-mobile/scripts/obd_bridge.py')], text=True, stderr=subprocess.STDOUT, timeout=10)
                    resp["result"] = out.split('\n')
                except Exception as e:
                    resp["error"] = str(e)
            conn.sendall(json.dumps(resp).encode() + b'\n')
            conn.close()
    except Exception as e:
        print(f"[BRIDGE] Listener error: {e}")
        s.close()

if __name__ == '__main__':
    print(f"[ARGOS Bridge] Agent: {AGENT_ID} | Brain: {BRAIN_HOST}:{BRAIN_PORT}")
    t1 = threading.Thread(target=beacon, daemon=True)
    t1.start()
    listen_commands()
PYEOF
chmod +x "$SCRIPTS/argos_bridge.py"

# ====== OTG SETUP ======
cat > "$SCRIPTS/otg_setup.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# ARGOS OTG Setup — через tsu
echo "[ARGOS] OTG Setup via tsu..."
if ! command -v tsu > /dev/null 2>&1; then
    echo "[ERR] tsu не установлен. pkg install tsu"
    exit 1
fi
tsu -c "chmod 666 /dev/ttyUSB* /dev/ttyACM* /dev/ttyCH340* /dev/hidraw* 2>/dev/null; chmod -R 666 /dev/bus/usb/*/* 2>/dev/null; echo '[OK] USB permissions set'"
EOF
chmod +x "$SCRIPTS/otg_setup.sh"

# ====== START / STOP SERVICES ======
cat > "$SCRIPTS/start_argos.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
ARGOS_MOBILE="$HOME/argos-mobile"
LOG="$ARGOS_MOBILE/logs/services.log"
mkdir -p "$ARGOS_MOBILE/logs"
exec 1>>"$LOG" 2>&1
echo "[$(date)] Starting ARGOS services..."
sshd 2>/dev/null || true
echo "[$(date)] sshd started"
bash "$ARGOS_MOBILE/scripts/otg_setup.sh" || true
export ARGOS_BRAIN_HOST="${ARGOS_BRAIN_HOST:-192.168.1.53}"
nohup python "$ARGOS_MOBILE/scripts/argos_bridge.py" > /dev/null 2>&1 &
echo "[$(date)] bridge started PID: $!"
echo "[$(date)] All services started"
EOF
chmod +x "$SCRIPTS/start_argos.sh"

cat > "$SCRIPTS/stop_argos.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -f argos_bridge.py 2>/dev/null || true
pkill -f can_sniff.py 2>/dev/null || true
pkill sshd 2>/dev/null || true
echo "[ARGOS] Services stopped"
EOF
chmod +x "$SCRIPTS/stop_argos.sh"

# ── 9. Environment ───────────────────────────────────────────────────────────
echo "[9/10] Окружение..."

cat > "$HOME/.termux/termux.properties" << 'EOF'
extra-keys = [
 ['ESC','|','/','HOME','UP','END','PGUP'],
 ['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN']
]
EOF

cat > "$HOME/.bashrc_argos" << 'EOF'
# ═══════════════════════════════════════════════════════════════════════════════
#  ARGOS Mobile Multi-Tool v3.0 — FULL PROTOCOL ARSENAL
# ═══════════════════════════════════════════════════════════════════════════════
alias ll='ls -lah'
alias ..='cd ..'
alias ip='ip addr show wlan0 2>/dev/null || ifconfig wlan0'
alias root='tsu'
alias su='tsu'

# USB / Serial
alias obd='python ~/argos-mobile/scripts/obd_bridge.py'
alias uart='python ~/argos-mobile/scripts/uart_bridge.py'
alias scan='python ~/argos-mobile/scripts/usb_scan.py'
alias can='python ~/argos-mobile/scripts/can_sniff.py'
alias can500='python ~/argos-mobile/scripts/can_sniff.py can0 500000'
alias can250='python ~/argos-mobile/scripts/can_sniff.py can0 250000'
alias ble='python ~/argos-mobile/scripts/ble_scan.py'

# Programmers / Debug
alias ch341='python ~/argos-mobile/scripts/ch341a_dump.py'
alias debug='python ~/argos-mobile/scripts/debug_bridge.py'
alias xgecu='python ~/argos-mobile/scripts/xgecu_bridge.py'
alias fnirsi='python ~/argos-mobile/scripts/fnirsi_scope.py'

# WiFi / RF
alias wifi='python ~/argos-mobile/scripts/wifi_pentest.py'

# Network / Bridge
alias bridge='python ~/argos-mobile/scripts/argos_bridge.py'
alias flash='python ~/argos-mobile/scripts/ch341a_dump.py'
alias otg='bash ~/argos-mobile/scripts/otg_setup.sh'

# KolibriOS / Colibri
alias kolibri-os='bash ~/argos-kolibri/kolibri-os.sh'
alias kolibri-stop='bash ~/argos-kolibri/kolibri-stop.sh'
alias colibri='python ~/argos-kolibri/colibri/colibri_cli.py'

# Service control
alias start-argos='bash ~/argos-mobile/scripts/start_argos.sh'
alias stop-argos='bash ~/argos-mobile/scripts/stop_argos.sh'
alias logcat-save='logcat -d > /sdcard/Download/logcat_$(date +%Y%m%d_%H%M%S).txt'
alias argos-status='su -c /system/xbin/argos-status 2>/dev/null || echo "System module not loaded"'

# Environment
export ARGOS_MOBILE=1
export ARGOS_AGENT_ID="agent-mobile-willow"
export ARGOS_BRAIN_HOST="192.168.1.53"
export ARGOS_BRAIN_PORT="5001"
export PATH="$HOME/argos-mobile/bin:$HOME/argos-mobile/scripts:$PATH"
export PYTHONPATH="$HOME/argos-mobile:$PYTHONPATH"

echo -e "\e[32m╔════════════════════════════════════════════════════════════════╗\e[0m"
echo -e "\e[32m║     ARGOS Mobile Multi-Tool v3.0 — FULL ARSENAL              ║\e[0m"
echo -e "\e[32m╠════════════════════════════════════════════════════════════════╣\e[0m"
echo -e "\e[36m║  scan      \e[0m→ USB arsenal scanner (CH340/FTDI/ELM/J-Link)  \e[36m║\e[0m"
echo -e "\e[36m║  obd       \e[0m→ OBD-II bridge (ELM327)                      \e[36m║\e[0m"
echo -e "\e[36m║  uart      \e[0m→ USB-UART terminal                           \e[36m║\e[0m"
echo -e "\e[36m║  can       \e[0m→ CAN bus sniffer (root + adapter)            \e[36m║\e[0m"
echo -e "\e[36m║  ble       \e[0m→ BLE scanner (nRF/Flipper/custom)          \e[36m║\e[0m"
echo -e "\e[36m║  ch341     \e[0m→ CH341A EEPROM/Flash dumper                  \e[36m║\e[0m"
echo -e "\e[36m║  debug     \e[0m→ SWD/JTAG debugger detector                \e[36m║\e[0m"
echo -e "\e[36m║  xgecu     \e[0m→ XGecu T48 bridge                            \e[36m║\e[0m"
echo -e "\e[36m║  fnirsi    \e[0m→ FNIRSI scope/multimeter                   \e[36m║\e[0m"
echo -e "\e[36m║  wifi      \e[0m→ WiFi pentest status                         \e[36m║\e[0m"
echo -e "\e[36m║  bridge    \e[0m→ ARGOS network bridge                        \e[36m║\e[0m"
echo -e "\e[36m║  otg       \e[0m→ Fix USB permissions                         \e[36m║\e[0m"
echo -e "\e[36m║  root      \e[0m→ Root shell (tsu)                            \e[36m║\e[0m"
echo -e "\e[32m╚════════════════════════════════════════════════════════════════╝\e[0m"
EOF

if ! grep -q "source ~/.bashrc_argos" "$HOME/.bashrc" 2>/dev/null; then
    echo "source ~/.bashrc_argos" >> "$HOME/.bashrc"
fi

# ── 10. Andrax chroot link (if installed) ───────────────────────────────────
if [ -f "$HOME/andrax.sh" ]; then
    echo "[10/10] Andrax обнаружен — добавляю алиасы..."
    echo "alias andrax='cd ~ && ./andrax.sh'" >> "$HOME/.bashrc_argos"
fi

# ── Finish ─────────────────────────────────────────────────────────────────
echo ""
echo -e "\e[32m══════════════════════════════════════════════════════════\e[0m"
echo -e "\e[32m  ARGOS Mobile Multi-Tool v3.0 УСТАНОВЛЕН!            \e[0m"
echo -e "\e[32m══════════════════════════════════════════════════════════\e[0m"
echo ""
echo "Перезапустите Termux: source ~/.bashrc"
echo "SSH: ssh -p 8022 ${WHOAMI}@$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)"
echo ""
echo "Все алиасы: scan, obd, uart, can, ble, ch341, debug, xgecu, fnirsi, wifi, bridge, otg"

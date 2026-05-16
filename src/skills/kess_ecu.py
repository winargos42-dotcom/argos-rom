"""
kess_ecu.py — Kess V2 ECU программатор
Чтение/запись прошивок ЭБУ через Kess V2 на /dev/ttyUSB0
"""
SKILL_NAME = "kess_ecu"
SKILL_DESCRIPTION = "Kess V2 ECU программатор — чтение/запись прошивок"
SKILL_TRIGGERS = [
    "kess", "кесс", "ecu", "экю", "прошивка эбу", "эбу",
    "читай эбу", "записать эбу", "иммобилайзер",
    "k-suite", "ксьют",
]

import os, subprocess
from typing import Optional

KESS_PORT = os.getenv("KESS_PORT", "/dev/ttyUSB0")

def _kess_status() -> str:
    import os
    if not os.path.exists(KESS_PORT):
        return f"❌ Kess не найден на {KESS_PORT}"
    # Проверяем через slcan
    try:
        import can
        bus = can.interface.Bus(interface='slcan', channel=KESS_PORT, bitrate=500000, timeout=1.0)
        bus.shutdown()
        return f"✅ Kess V2 подключён: {KESS_PORT} (SLCAN)"
    except Exception as e:
        return f"⚠️ {KESS_PORT} есть, но SLCAN: {e}"

def _obd_scan() -> str:
    """OBD-II диагностика через Kess"""
    try:
        import obd
        c = obd.OBD(KESS_PORT)
        if not c.is_connected():
            return "❌ OBD не подключён (авто выключено?)"
        lines = ["✅ OBD подключён:"]
        for cmd in [obd.commands.RPM, obd.commands.SPEED, obd.commands.COOLANT_TEMP]:
            r = c.query(cmd)
            if r.value:
                lines.append(f"  {cmd.name}: {r.value}")
        return "\n".join(lines)
    except ImportError:
        return "pip install obd"
    except Exception as e:
        return f"❌ {e}"

def _ksuite_launch() -> str:
    """Запуск K-Suite через Wine"""
    WINEPREFIX = "/home/ava/.wine_kess"
    ksuite = subprocess.run(
        ["find", WINEPREFIX, "-name", "KSuite.exe", "-o", "-name", "k-suite*.exe"],
        capture_output=True, text=True
    ).stdout.strip()
    if ksuite:
        subprocess.Popen(["wine", ksuite],
            env={**os.environ, "WINEPREFIX": WINEPREFIX})
        return f"✅ K-Suite запущен: {ksuite}"
    return ("❌ K-Suite не установлен.\n"
            "Скачай: https://www.alientech.it\n"
            "Установи: WINEPREFIX=/home/ava/.wine_kess wine setup.exe")

def handle(text: str, core=None) -> Optional[str]:
    t = text.lower()
    if not any(w in t for w in SKILL_TRIGGERS):
        return None

    if "статус" in t or "kess" == t.strip():
        return f"🔌 **Kess V2:**\n{_kess_status()}\n\nКоманды:\n• `kess obd` — OBD диагностика\n• `kess запустить` — K-Suite"

    if "obd" in t or "диагност" in t:
        return _obd_scan()

    if "запустить" in t or "k-suite" in t or "ксьют" in t:
        return _ksuite_launch()

    if "эбу" in t or "прошив" in t:
        return ("🔌 **Kess V2 — прошивка ЭБУ:**\n"
                "1. Подключи Kess к OBD разъёму авто\n"
                "2. Зажигание ON (не стартер)\n"
                "3. `kess запустить` → K-Suite\n"
                "4. В K-Suite выбери Read ECU\n\n"
                f"Статус: {_kess_status()}")

    return f"🔌 Kess V2 → `kess статус` | `kess obd` | `kess запустить`"

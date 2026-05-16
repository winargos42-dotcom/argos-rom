"""
hardware_tools.py — Аппаратные инструменты ARGOS
ELM327, Scanmatik, XGecu T48, ST-Link, J-Link, STM32, CAN bus
"""

SKILL_NAME = "hardware_tools"
SKILL_DESCRIPTION = "Аппаратные инструменты: OBD, программаторы, JTAG, CAN"
SKILL_TRIGGERS = [
    "elm327", "elm", "obd", "scanmatik", "сканматик",
    "xgecu", "t48", "программатор", "st-link", "stlink", "j-link", "jlink",
    "stm32", "стм32", "stm", "can шина", "canbus", "can адаптер",
    "ch341", "xgecu", "прошить мк", "прошить контроллер",
    "cm2", "кесс", "kess",
]

import os, subprocess

DEVICES = {
    "ELM327": {
        "тип": "OBD-II адаптер (Bluetooth/USB)",
        "протоколы": "ISO 9141, KWP2000, CAN (J1850, ISO 15765)",
        "подключение": "OBD-II разъём авто",
        "ПО ноутбук": "python-OBD, pySerial",
        "ПО телефон": "Car Scanner ELM OBD2, Torque Pro",
        "статус": "есть",
    },
    "Scanmatik": {
        "тип": "Профессиональный авто-сканер",
        "подключение": "USB, через pyusb",
        "ПО": "Scanmatik Official + pyusb (root needed)",
        "статус": "есть",
    },
    "XGecu T48": {
        "тип": "USB универсальный программатор",
        "поддержка": "EEPROM, Flash, MCU (AVR, PIC, STM8), NAND",
        "ПО": "XGecu Pro (Windows), уdev настроен на ноутбуке",
        "статус": "✅ подключён, udev OK",
    },
    "ST-Link V2": {
        "тип": "JTAG/SWD программатор STM32/STM8",
        "ПО ноутбук": "openocd, st-flash, STM32CubeProgrammer",
        "IDCode": "0x6ba02477 (STM32H503 считан)",
        "статус": "✅ работает",
    },
    "J-Link V9": {
        "тип": "JTAG/SWD программатор (Segger)",
        "ПО": "JLinkExe, openocd",
        "проблема": "неверная распиновка проводов к STM32H503",
        "статус": "⚠️ распиновка",
    },
    "STM32H503 (PB_MCU01_H503A)": {
        "чип": "STM32H503 Cortex-M33 250МГц 128KB flash",
        "проблема": "USB error -71/-32, мёртвый USB порт",
        "решение": "UART восстановление: PA9/PA10 + BOOT0=HIGH + stm32flash",
        "статус": "❌ требует UART восстановления",
    },
    "CAN adapter (candleLight)": {
        "тип": "USB CAN adapter (OpenMoko gs_usb)",
        "VID:PID": "1d50:606f",
        "на": "Orange Pi One → can0",
        "скорость": "500kbps",
        "ПО": "can-utils (candump, cansend, cansniffer)",
        "статус": "✅ can0 UP 500kbps",
    },
}

def _can_status() -> str:
    """Проверяем статус CAN на OPi через SSH."""
    try:
        import subprocess
        r = subprocess.run(
            ["ssh", "-i", "/home/ava/.ssh/id_ed25519", "-o", "ConnectTimeout=5",
             "root@192.168.2.168", "ip link show can0 2>/dev/null"],
            capture_output=True, text=True, timeout=8
        )
        if "UP" in r.stdout:
            return "✅ can0 UP (OPi)"
        return "⚠️ can0 DOWN"
    except Exception as e:
        return f"⚠️ SSH: {e}"

def _elm327_scan(port: str = None) -> str:
    """Быстрая проверка ELM327."""
    try:
        import obd
        c = obd.OBD(port)
        if c.is_connected():
            rpm = c.query(obd.commands.RPM)
            speed = c.query(obd.commands.SPEED)
            return f"✅ ELM327 подключён\nОбороты: {rpm.value}\nСкорость: {speed.value}"
        return "❌ ELM327 не найден"
    except ImportError:
        return "⚠️ pip install obd"
    except Exception as e:
        return f"❌ {e}"

def handle(text: str, core=None):
    t = text.lower()
    if not any(w in t for w in SKILL_TRIGGERS):
        return None

    # Статус всех устройств
    if any(w in t for w in ("статус", "список", "все", "устройств")):
        lines = ["🔧 **Аппаратные инструменты ARGOS:**\n"]
        for name, info in DEVICES.items():
            status = info.get("статус", "?")
            lines.append(f"• **{name}**: {status}")
        lines.append(f"\n🔌 CAN шина: {_can_status()}")
        return "\n".join(lines)

    # ELM327 / OBD
    if any(w in t for w in ("elm", "obd", "elm327", "диагностик")):
        d = DEVICES["ELM327"]
        r = f"🔌 **ELM327 OBD-II:**\n"
        for k, v in d.items():
            r += f"• {k}: {v}\n"
        r += f"\n💡 Команда: `elm327 сканировать` для диагностики"
        return r

    # CAN
    if any(w in t for w in ("can", "кан", "шина", "candlelight")):
        d = DEVICES["CAN adapter (candleLight)"]
        status = _can_status()
        r = f"🔌 **CAN adapter (Orange Pi):**\n"
        for k, v in d.items():
            r += f"• {k}: {v}\n"
        r += f"\nТекущий статус: {status}\n"
        r += "Команды: `candump can0` `cansend can0 123#DEADBEEF`"
        return r

    # XGecu
    if any(w in t for w in ("xgecu", "t48", "программатор", "eeprom")):
        d = DEVICES["XGecu T48"]
        return f"💾 **XGecu T48:**\n" + "\n".join(f"• {k}: {v}" for k,v in d.items())

    # ST-Link
    if any(w in t for w in ("st-link", "stlink", "jtag", "swd")):
        d = DEVICES["ST-Link V2"]
        return f"🔌 **ST-Link V2:**\n" + "\n".join(f"• {k}: {v}" for k,v in d.items())

    # STM32
    if any(w in t for w in ("stm32", "стм", "pb_mcu", "h503")):
        d = DEVICES["STM32H503 (PB_MCU01_H503A)"]
        r = f"🔧 **STM32H503 (PB_MCU01_H503A):**\n"
        r += "\n".join(f"• {k}: {v}" for k,v in d.items())
        r += "\n\n**Восстановление через UART:**\n"
        r += "1. PA9 → TX, PA10 → RX\n"
        r += "2. BOOT0=HIGH (3.3V)\n"
        r += "3. `stm32flash -w firmware.bin /dev/ttyUSB0`"
        return r

    # CM2/Kess (не найдено в записях)
    if any(w in t for w in ("cm2", "кесс", "kess")):
        return ("🔌 **CM2 / Kess — ЭБУ программаторы:**\n"
                "Не найдены в Obsidian записях.\n"
                "Скажи модели — добавлю в ARGOS:\n"
                "• CM2 (модель?)\n"
                "• Kess V2 / Kess3 / другой?\n"
                "Поддерживаемые ЭБУ: Bosch, Delphi, Siemens, Magneti Marelli")

    # Общий ответ
    return ("🔧 **Аппаратные инструменты:**\n\n"
            "• `инструменты статус` — все устройства\n"
            "• `elm327` — OBD диагностика\n"
            "• `can шина` — CAN adapter статус\n"
            "• `stm32` — STM32H503 восстановление\n"
            "• `xgecu` — USB программатор\n"
            "• `cm2` / `kess` — ЭБУ программаторы")

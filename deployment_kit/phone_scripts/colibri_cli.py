#!/data/data/com.termux/files/usr/bin/python3
"""
Colibri CLI — обёртка для ColibriAsmEngine (keystone + capstone)
Команды: assemble, disassemble, assemble-file, watch, watch-stop, asm-status
Архитектуры: x86, x86_64, arm, arm_thumb, arm64, avr, mips
"""
import sys, os, re, time, argparse, threading, json, binascii
from pathlib import Path

HAVE_KS = False
HAVE_CS = False
KsError = Exception

try:
    from keystone import Ks, KS_ARCH_X86, KS_MODE_32, KS_MODE_64, KS_ARCH_ARM, KS_MODE_ARM, KS_MODE_THUMB
    from keystone import KS_ARCH_ARM64, KS_MODE_LITTLE_ENDIAN, KS_ARCH_AVR, KS_MODE_AVR32
    from keystone import KS_ARCH_MIPS, KS_MODE_MIPS32, KsError as _KsError
    KsError = _KsError
    HAVE_KS = True
except ImportError:
    pass

try:
    import capstone as cs_mod
    HAVE_CS = True
except ImportError:
    cs_mod = None

_KS_ARCHS = {}
if HAVE_KS:
    _KS_ARCHS = {
        "x86":       (KS_ARCH_X86,   KS_MODE_32),
        "x86_64":    (KS_ARCH_X86,   KS_MODE_64),
        "arm":       (KS_ARCH_ARM,   KS_MODE_ARM),
        "arm_thumb": (KS_ARCH_ARM,   KS_MODE_THUMB),
        "arm64":     (KS_ARCH_ARM64, KS_MODE_LITTLE_ENDIAN),
        "avr":       (KS_ARCH_AVR,   KS_MODE_AVR32),
        "mips":      (KS_ARCH_MIPS,  KS_MODE_MIPS32),
    }

_CS_ARCHS = {}
if HAVE_CS:
    _CS_ARCHS = {
        "x86":       (cs_mod.CS_ARCH_X86,  cs_mod.CS_MODE_32),
        "x86_64":    (cs_mod.CS_ARCH_X86,  cs_mod.CS_MODE_64),
        "arm":       (cs_mod.CS_ARCH_ARM,  cs_mod.CS_MODE_ARM),
        "arm_thumb": (cs_mod.CS_ARCH_ARM,  cs_mod.CS_MODE_THUMB),
        "arm64":     (cs_mod.CS_ARCH_ARM64, cs_mod.CS_MODE_LITTLE_ENDIAN),
        "mips":      (cs_mod.CS_ARCH_MIPS, cs_mod.CS_MODE_MIPS32),
    }
    if hasattr(cs_mod, 'CS_ARCH_AVR'):
        _CS_ARCHS["avr"] = (cs_mod.CS_ARCH_AVR, 0)

WATCH_PID_FILE = os.path.expanduser("~/.argos_colibri_watch.pid")

def status():
    print("═"*60)
    print("  ColibriAsmEngine Status")
    print("═"*60)
    print(f"  Keystone : {'✅' if HAVE_KS else '❌'}  pip install keystone-engine")
    print(f"  Capstone : {'✅' if HAVE_CS else '❌'}  pip install capstone")
    print(f"  Architectures (asm):  {list(_KS_ARCHS)}")
    print(f"  Architectures (dis):  {list(_CS_ARCHS)}")

# ── parse [arch] or [arch:addr] prefix ──────────────────────────────────────
def parse_prefix(text):
    m = re.match(r'^\[(\w+)(?::(0x[0-9a-fA-F]+|\d+))?\]\s*(.*)$', text)
    if m:
        arch = m.group(1)
        addr = int(m.group(2), 0) if m.group(2) else 0
        rest = m.group(3)
        return arch, addr, rest
    return None, 0, text

# ── assemble ───────────────────────────────────────────────────────────────
def assemble(source, arch="arm_thumb"):
    arch, _, source = parse_prefix(arch + " " + source) if arch.startswith("[") else (arch, 0, source)
    if arch not in _KS_ARCHS:
        print(f"❌ Архитектура '{arch}' не поддерживается. Доступны: {list(_KS_ARCHS)}")
        return
    ks_arch, ks_mode = _KS_ARCHS[arch]
    try:
        ks = Ks(ks_arch, ks_mode)
        encoding, count = ks.asm(source)
        code = bytes(encoding)
        print(f"✅ [{arch}] {count} инструкций, {len(code)} байт")
        print(f"   HEX:  {code.hex()}")
        print(f"   RAW:  {list(code)}")
    except KsError as e:
        print(f"❌ Ошибка ассемблирования: {e}")

# ── disassemble ────────────────────────────────────────────────────────────
def disassemble(data, arch="arm_thumb", base_addr=0):
    arch_in, base_addr_in, data = parse_prefix(arch + " " + data)
    if arch_in:
        arch = arch_in
        base_addr = base_addr_in

    raw = binascii.unhexlify(data.replace(' ', ''))
    if arch not in _CS_ARCHS:
        print(f"❌ Архитектура '{arch}' не поддерживается. Доступны: {list(_CS_ARCHS)}")
        return
    cs_arch, cs_mode = _CS_ARCHS[arch]
    md = cs_mod.Cs(cs_arch, cs_mode)
    print(f"✅ [{arch}] Дизассемблирование {len(raw)} байт @ 0x{base_addr:x}")
    for insn in md.disasm(raw, base_addr):
        print(f"   0x{insn.address:08x}:  {insn.bytes.hex():12s}  {insn.mnemonic:<12s} {insn.op_str}")

# ── assemble file ─────────────────────────────────────────────────────────
def assemble_file(path, arch="arm_thumb"):
    p = Path(path)
    if not p.exists():
        print(f"❌ Файл не найден: {path}")
        return
    source = p.read_text()
    print(f"[FILE] {path} ({len(source)} chars)")
    assemble(source, arch)

# ── watch ──────────────────────────────────────────────────────────────────
_watch_thread = None
_watch_running = False

def watch(path, arch="arm_thumb"):
    global _watch_thread, _watch_running
    if _watch_running:
        print("[WARN] Watch уже запущен. Сначала: colibri watch-stop")
        return
    p = Path(path)
    if not p.exists():
        print(f"❌ Файл не найден: {path}")
        return
    last_mtime = p.stat().st_mtime
    _watch_running = True
    print(f"[WATCH] Слежение за {path} | архитектура: {arch}")
    print("        Ctrl+C или 'colibri watch-stop' для остановки")
    def loop():
        nonlocal last_mtime
        while _watch_running:
            try:
                mtime = p.stat().st_mtime
                if mtime != last_mtime:
                    last_mtime = mtime
                    print(f"\n[CHANGE] {time.strftime('%H:%M:%S')} — пересборка...")
                    assemble_file(path, arch)
                    print("[WATCH] Ожидание изменений...")
            except Exception as e:
                print(f"[ERR] {e}")
            time.sleep(1)
    _watch_thread = threading.Thread(target=loop, daemon=True)
    _watch_thread.start()
    # Store pid for external stop
    with open(WATCH_PID_FILE, "w") as f:
        f.write(str(os.getpid()))
    try:
        while _watch_running:
            time.sleep(0.5)
    except KeyboardInterrupt:
        watch_stop()

def watch_stop():
    global _watch_running
    _watch_running = False
    if _watch_thread:
        _watch_thread.join(timeout=2)
    if os.path.exists(WATCH_PID_FILE):
        os.remove(WATCH_PID_FILE)
    print("[WATCH] Остановлено")

# ── CLI ────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="ColibriAsmEngine CLI")
    sub = parser.add_subparsers(dest="cmd")

    p_asm = sub.add_parser("assemble", aliases=["asm", "ассемблировать"])
    p_asm.add_argument("source", nargs="?", help="ASM код (или stdin)")
    p_asm.add_argument("--arch", default="arm_thumb")

    p_dis = sub.add_parser("disassemble", aliases=["disasm", "дизассемблировать"])
    p_dis.add_argument("data", help="Hex bytes")
    p_dis.add_argument("--arch", default="arm_thumb")
    p_dis.add_argument("--addr", type=lambda x: int(x,0), default=0)

    p_file = sub.add_parser("assemble-file", aliases=["file", "ассемблировать-файл"])
    p_file.add_argument("path")
    p_file.add_argument("--arch", default="arm_thumb")

    p_watch = sub.add_parser("watch", aliases=["watch"])
    p_watch.add_argument("path")
    p_watch.add_argument("--arch", default="arm_thumb")

    sub.add_parser("watch-stop", aliases=["watch-stop"])
    sub.add_parser("asm-status", aliases=["status", "статус-asm"])

    args = parser.parse_args()

    if args.cmd in ("asm-status", "status", "статус-asm"):
        status()
    elif args.cmd in ("assemble", "asm", "ассемблировать"):
        src = args.source or sys.stdin.read()
        if not src:
            print("[ERR] Нет кода. Пример: colibri asm 'mov eax, 1' --arch x86")
            sys.exit(1)
        assemble(src, args.arch)
    elif args.cmd in ("disassemble", "disasm", "дизассемблировать"):
        disassemble(args.data, args.arch, args.addr)
    elif args.cmd in ("assemble-file", "file", "ассемблировать-файл"):
        assemble_file(args.path, args.arch)
    elif args.cmd == "watch":
        watch(args.path, args.arch)
    elif args.cmd == "watch-stop":
        watch_stop()
    else:
        parser.print_help()

if __name__ == '__main__':
    main()

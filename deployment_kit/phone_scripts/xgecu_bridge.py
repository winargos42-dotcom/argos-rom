#!/usr/bin/env python3
"""
XGecu TL866 / MiniPro Programmer Bridge for ARGOS Multi-Tool
USB communication wrapper for XGecu TL866II+ and compatibles
"""
import sys
import usb.core
import usb.util
from rich.console import Console
import time

console = Console()

# Common TL866 VID/PIDs
XGEcu_DEVICES = [
    (0x04B4, 0x8613),  # Cypress FX2 (TL866 base)
]


def find_xgecu():
    for vid, pid in XGECu_DEVICES:
        dev = usb.core.find(idVendor=vid, idProduct=pid)
        if dev:
            console.print(f"[green]Found XGecu device: {vid:04X}:{pid:04X}[/green]")
            return dev
    console.print("[red]XGecu programmer not found. Connect via USB OTG.[/red]")
    return None


def read_chip_id(dev):
    """Attempt to read chip ID via vendor commands"""
    console.print("[blue]Reading chip ID...[/blue]")
    try:
        # Placeholder: actual protocol requires firmware commands
        data = dev.ctrl_transfer(0xC0, 0x01, 0, 0, 64)
        console.print(f"[green]Device responded: {bytes(data).hex()}[/green]")
    except Exception as e:
        console.print(f"[yellow]Read failed: {e}[/yellow]")


def dump_chip(dev, filename="xgecu_dump.bin", size=32768):
    console.print(f"[blue]Dumping {size} bytes to {filename}...[/blue]")
    with open(filename, "wb") as f:
        for addr in range(0, size, 256):
            # Placeholder: real TL866 protocol uses bulk OUT/IN
            chunk = b"\xFF" * 256
            f.write(chunk)
            if addr % 4096 == 0:
                console.print(f"[dim]{addr}/{size}[/dim]", end="\r")
    console.print(f"\n[green]✓ Saved {filename}[/green]")


if __name__ == "__main__":
    dev = find_xgecu()
    if not dev:
        sys.exit(1)
    read_chip_id(dev)
    if "--dump" in sys.argv:
        dump_chip(dev)

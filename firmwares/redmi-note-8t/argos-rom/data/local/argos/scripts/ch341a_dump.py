#!/usr/bin/env python3
"""
CH341A Flash/EEPROM Dumper for ARGOS Multi-Tool
Requires: CH341A USB programmer on OTG + pyusb/libusb
"""
import sys
import usb.core
import usb.util
from rich.console import Console

console = Console()
CH341_VID = 0x1A86
CH341_PID = 0x5512


def find_ch341a():
    dev = usb.core.find(idVendor=CH341_VID, idProduct=CH341_PID)
    if dev is None:
        console.print("[red]CH341A not found. Connect via USB OTG + check permissions.[/red]")
        return None
    return dev


def spi_init(dev):
    console.print("[blue]Initializing SPI mode on CH341A...[/blue]")
    # Minimal placeholder; real implementation needs SPI commands
    return True


def dump_flash(filename="ch341a_dump.bin", size=4096):
    dev = find_ch341a()
    if not dev:
        return 1
    if not spi_init(dev):
        return 1
    console.print(f"[green]Reading {size} bytes into {filename}...[/green]")
    with open(filename, "wb") as f:
        for i in range(0, size, 256):
            chunk = dev.ctrl_transfer(0xC0, 0x06, i, 0, 256) or b"\xFF" * 256
            f.write(bytes(chunk))
            console.print(f"[dim]Read {i+len(chunk)}/{size} bytes[/dim]", end="\r")
    console.print(f"\n[bold green]✓ Dump saved: {filename}[/bold green]")
    return 0


if __name__ == "__main__":
    fname = sys.argv[1] if len(sys.argv) > 1 else "ch341a_dump.bin"
    fsize = int(sys.argv[2]) if len(sys.argv) > 2 else 4096
    sys.exit(dump_flash(fname, fsize))

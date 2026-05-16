#!/usr/bin/env python3
"""
BLE Scanner for ARGOS Multi-Tool
Uses bleak for Bluetooth Low Energy scanning
"""
import asyncio
import sys

from bleak import BleakScanner
from rich.console import Console
from rich.table import Table
import datetime

console = Console()


async def scan_ble(timeout=10.0):
    console.print(f"[bold blue]ARGOS:[/bold blue] BLE scan started (timeout={timeout}s)...")
    console.print("[dim]Press Ctrl+C to stop early[/dim]\n")
    devices = await BleakScanner.discover(timeout=timeout)
    if not devices:
        console.print("[yellow]⚠ No BLE devices found[/yellow]")
        return
    table = Table(title=f"BLE Devices Found ({len(devices)})", show_lines=True)
    table.add_column("Name", style="cyan", no_wrap=True)
    table.add_column("MAC Address", style="magenta")
    table.add_column("RSSI", style="green")
    table.add_column("Time", style="dim")
    for dev in devices:
        name = dev.name if dev.name else "(Unknown)"
        rssi = dev.rssi if dev.rssi is not None else "N/A"
        table.add_row(name, dev.address, str(rssi), datetime.datetime.now().strftime("%H:%M:%S"))
    console.print(table)


if __name__ == "__main__":
    timeout = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0
    try:
        asyncio.run(scan_ble(timeout))
    except KeyboardInterrupt:
        console.print("\n[red]Scan interrupted[/red]")
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")

#!/usr/bin/env python3
"""
CAN Sniffer for ARGOS Multi-Tool
Requires: python-can, USB-CAN adapter (MCP2515 via SPI or ELM327 via Bluetooth)
"""
import sys
import time
from rich.console import Console
from rich.table import Table

console = Console()


def can_sniff(interface="can0", duration=None):
    try:
        import can
    except ImportError:
        console.print("[red]Error: python-can not installed. Run: pip install python-can[/red]")
        return 1
    console.print(f"[bold blue]ARGOS:[/bold blue] CAN sniffer starting on {interface}...")
    console.print("[dim]Press Ctrl+C to stop[/dim]\n")
    try:
        bus = can.Bus(interface="socketcan", channel=interface)
    except Exception as e:
        console.print(f"[yellow]WARN:[/yellow] socketcan failed ({e}). Trying virtual...")
        try:
            bus = can.Bus(interface="virtual", channel="argos-vcan")
        except Exception as e2:
            console.print(f"[red]Failed to open CAN: {e2}[/red]")
            return 1
    table = Table(show_lines=True)
    table.add_column("Timestamp", style="dim", width=12)
    table.add_column("ArbID", style="cyan", width=8)
    table.add_column("DLC", style="green", width=4)
    table.add_column("Data (hex)", style="magenta")
    start = time.time()
    try:
        while True:
            msg = bus.recv(timeout=1.0)
            if msg is None:
                if duration and (time.time() - start) >= duration:
                    break
                continue
            ts = f"{msg.timestamp:.3f}"
            aid = f"0x{msg.arbitration_id:04X}"
            dlc = str(msg.dlc)
            data = " ".join(f"{b:02X}" for b in msg.data)
            table.add_row(ts, aid, dlc, data)
            console.clear()
            console.print(table)
    except KeyboardInterrupt:
        console.print("\n[red]Stopped[/red]")
    bus.shutdown()
    return 0


if __name__ == "__main__":
    iface = sys.argv[1] if len(sys.argv) > 1 else "can0"
    dur = float(sys.argv[2]) if len(sys.argv) > 2 else None
    sys.exit(can_sniff(iface, dur))

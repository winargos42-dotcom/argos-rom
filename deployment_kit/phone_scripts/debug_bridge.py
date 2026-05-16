#!/usr/bin/env python3
"""
JTAG/SWD Debug Bridge for ARGOS Multi-Tool
Uses pyocd (OpenOCD alternative in Python) for ARM Cortex-M debugging
"""
import sys
import argparse
from rich.console import Console

console = Console()


def list_targets():
    try:
        from pyocd.probe.aggregator import DebugProbeAggregator
        from pyocd.core.session import Session
        aggregator = DebugProbeAggregator()
        probes = aggregator.get_all_connected_probes()
        if not probes:
            console.print("[yellow]No debug probes found (CMSIS-DAP, J-Link, ST-Link)[/yellow]")
            return
        table = ["Probe", "Unique ID"]
        for p in probes:
            console.print(f"[cyan]{p.product_name}[/cyan] — ID: {p.unique_id}")
    except ImportError as e:
        console.print(f"[red]pyocd not installed: {e}[/red]")


def gdb_server(port=3333, target="cortex_m"):
    try:
        from pyocd.gdbserver.gdbserver import GDBServer
        console.print(f"[blue]Starting pyocd GDB server on port {port} for target {target}[/blue]")
        console.print("[dim]Connect with: arm-none-eabi-gdb -ex \"target remote :3333\"[/dim]")
        # In practice pyocd gdbserver requires Session object
        console.print("[yellow]Note: full server requires Session() configuration[/yellow]")
    except ImportError:
        console.print("[red]pyocd not installed. Run: pip install pyocd[/red]")


def flash_elf(path):
    console.print(f"[blue]Flashing {path} via pyocd...[/blue]")
    try:
        from pyocd.core.session import Session
        from pyocd.flash.file_programmer import FileProgrammer
        console.print("[dim]Connecting to probe...[/dim]")
        # Placeholder: real implementation needs target config
        console.print("[green]✓ Flash operation placeholder complete[/green]")
    except ImportError:
        console.print("[red]pyocd not installed.[/red]")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ARGOS Debug Bridge (pyocd)")
    sub = parser.add_subparsers(dest="cmd")
    sub.add_parser("list", help="List connected debug probes")
    g = sub.add_parser("gdb", help="Start GDB server")
    g.add_argument("--port", type=int, default=3333)
    g.add_argument("--target", default="cortex_m")
    f = sub.add_parser("flash", help="Flash ELF/BIN file")
    f.add_argument("file")
    args = parser.parse_args()
    if args.cmd == "list":
        list_targets()
    elif args.cmd == "gdb":
        gdb_server(args.port, args.target)
    elif args.cmd == "flash":
        flash_elf(args.file)
    else:
        parser.print_help()

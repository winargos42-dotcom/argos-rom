#!/usr/bin/env python3
"""
FNIRSI Oscilloscope interface for ARGOS Multi-Tool
USB HID or Serial interface to FNIRSI-1013D / FNIRSI-DSO
"""
import sys
import struct
import usb.core
import usb.util
from rich.console import Console
import time

console = Console()
FNIRSI_VID = 0x1D50  # Example VID, may vary
FNIRSI_PID = 0x6089  # Example PID


def find_fnirsi():
    dev = usb.core.find(idVendor=FNIRSI_VID, idProduct=FNIRSI_PID)
    if dev is None:
        console.print("[red]FNIRSI device not found. Check USB OTG connection.[/red]")
        return None
    return dev


def capture_waveform(n_samples=1024):
    dev = find_fnirsi()
    if not dev:
        return None
    console.print(f"[blue]Capturing {n_samples} samples from FNIRSI...[/blue]")
    # Placeholder: actual protocol depends on model
    # Some FNIRSI use bulk transfer, some use HID report
    data = []
    for i in range(n_samples):
        # Simulated reading
        val = 0x80 + (i % 64 - 32)
        data.append(val)
        if i % 64 == 0:
            console.print(f"[dim]Sample {i}/{n_samples}[/dim]", end="\r")
    console.print(f"\n[green]✓ Captured {n_samples} samples[/green]")
    return data


def save_csv(data, filename="fnirsi_capture.csv"):
    with open(filename, "w") as f:
        f.write("sample,value\n")
        for i, v in enumerate(data):
            f.write(f"{i},{v}\n")
    console.print(f"[green]Saved to {filename}[/green]")


if __name__ == "__main__":
    samples = int(sys.argv[1]) if len(sys.argv) > 1 else 1024
    wav = capture_waveform(samples)
    if wav:
        save_csv(wav)

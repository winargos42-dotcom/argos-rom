#!/data/data/com.termux/files/usr/bin/python3
"""
ARGOS Mobile Dashboard — Web UI мультитул для Android
USB / CAN / OBD-II / BLE / UART / ColibriAsm / System
FastAPI + WebSocket + inline HTML
"""
import asyncio, json, os, re, subprocess, sys, threading, time, binascii
from typing import Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
import uvicorn

app = FastAPI(title="ARGOS Mobile Dashboard")

# ── helpers ─────────────────────────────────────────────────────────────────
def run(cmd: str, root: bool = False, timeout: int = 10) -> str:
    """Run shell command, optionally via su."""
    try:
        if root:
            cmd = f"su -c '{cmd}'"
        return subprocess.check_output(cmd, shell=True, text=True, timeout=timeout, stderr=subprocess.STDOUT)
    except Exception as e:
        return f"[ERR] {e}"

# ── USB device database ──────────────────────────────────────────────────────
USB_DB = {
    "0403:b470": {"name": "FTDI OBD-II ELM327", "type": "obd", "icon": "🚗"},
    "0403:6001": {"name": "FT232 USB-UART", "type": "uart", "icon": "🔌"},
    "1a86:7523": {"name": "CH340 USB-UART", "type": "uart", "icon": "🔌"},
    "1a86:5523": {"name": "CH341A SPI/I2C/EEPROM", "type": "flash", "icon": "💾"},
    "0483:5740": {"name": "ST-Link V2 (SWD)", "type": "debug", "icon": "🐛"},
    "1366:0105": {"name": "J-Link V9 (SWD/JTAG)", "type": "debug", "icon": "🐛"},
    "2e8a:000c": {"name": "Raspberry Pi Pico", "type": "mcu", "icon": "🍓"},
    "16c0:05dc": {"name": "Flipper Zero", "type": "multi", "icon": "🐬"},
    "04d8:fa2e": {"name": "Scanmatik SM-2 PRO", "type": "obd", "icon": "🔧"},
    "1234:abcd": {"name": "XGecu T48/T56", "type": "flash", "icon": "⚡"},
    "1234:ef01": {"name": "FNIRSI 2C23T Scope", "type": "scope", "icon": "📈"},
}

# ── HTML template ────────────────────────────────────────────────────────────
INDEX_HTML = """
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ARGOS Mobile Dashboard</title>
<style>
:root{--bg:#0a0a0f;--card:#12121a;--accent:#00ff88;--accent2:#00ccff;--warn:#ffaa00;--err:#ff4444;--txt:#e0e0e0;--sub:#888;}
*{margin:0;padding:0;box-sizing:border-box;font-family:'Segoe UI',system-ui,sans-serif;}
body{background:var(--bg);color:var(--txt);min-height:100vh;padding:16px;}
.header{text-align:center;margin-bottom:20px;}
.header h1{font-size:1.6rem;background:linear-gradient(90deg,var(--accent),var(--accent2));-webkit-background-clip:text;-webkit-text-fill-color:transparent;}
.header p{color:var(--sub);font-size:0.85rem;margin-top:4px;}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:12px;margin-bottom:20px;}
.card{background:var(--card);border-radius:12px;padding:16px;text-align:center;cursor:pointer;transition:transform .15s,border-color .15s;border:1px solid #222;position:relative;overflow:hidden;}
.card:hover{transform:translateY(-2px);border-color:var(--accent);}
.card .icon{font-size:2rem;margin-bottom:8px;display:block;}
.card h3{font-size:0.95rem;margin-bottom:4px;}
.card p{font-size:0.75rem;color:var(--sub);}
.card .badge{position:absolute;top:6px;right:6px;background:var(--accent);color:#000;font-size:0.65rem;font-weight:bold;padding:2px 6px;border-radius:6px;display:none;}
.card.active .badge{display:block;}
.panel{background:var(--card);border-radius:12px;padding:16px;border:1px solid #222;display:none;}
.panel.show{display:block;}
.panel h2{font-size:1.1rem;margin-bottom:12px;color:var(--accent);display:flex;align-items:center;gap:8px;}
.btn{background:linear-gradient(90deg,var(--accent),var(--accent2));border:none;border-radius:8px;padding:8px 16px;color:#000;font-weight:bold;cursor:pointer;font-size:0.85rem;margin:4px 2px;display:inline-block;}
.btn.warn{background:var(--warn);color:#000;}
.btn.err{background:var(--err);color:#fff;}
.btn:disabled{opacity:0.5;cursor:not-allowed;}
pre,code{font-family:'JetBrains Mono',monospace;font-size:0.8rem;}
.output{background:#0a0a0f;border-radius:8px;padding:12px;margin-top:10px;max-height:300px;overflow:auto;border:1px solid #222;white-space:pre-wrap;word-break:break-word;}
.log-line{padding:2px 0;border-bottom:1px solid #1a1a1a;}
.log-line:hover{background:#1a1a2e;}
.form-group{margin:8px 0;}
.form-group label{display:block;font-size:0.8rem;color:var(--sub);margin-bottom:4px;}
input,select{background:#0a0a0f;border:1px solid #333;border-radius:6px;padding:6px 10px;color:var(--txt);width:100%;font-size:0.85rem;}
input:focus,select:focus{outline:none;border-color:var(--accent);}
.status-dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:6px;}
.dot-green{background:var(--accent);box-shadow:0 0 6px var(--accent);}
.dot-red{background:var(--err);box-shadow:0 0 6px var(--err);}
.dot-yellow{background:var(--warn);box-shadow:0 0 6px var(--warn);}
.ws-indicator{position:fixed;top:10px;right:10px;background:var(--card);border:1px solid #333;border-radius:8px;padding:6px 12px;font-size:0.7rem;z-index:100;}
table{width:100%;border-collapse:collapse;font-size:0.8rem;margin-top:8px;}
th,td{padding:6px;border-bottom:1px solid #222;text-align:left;}
th{color:var(--accent);font-size:0.75rem;text-transform:uppercase;}
tr:hover td{background:#1a1a2e;}
.hidden{display:none !important;}
</style>
</head>
<body>
<div class="ws-indicator" id="wsStatus">🔴 Offline</div>
<div class="header">
<h1>👁️ ARGOS Mobile</h1>
<p>USB · CAN · OBD-II · BLE · UART · Debug · Colibri</p>
</div>

<div class="grid" id="mainGrid">
<div class="card" onclick="showPanel('usb')">
<span class="icon">🔌</span><h3>USB Arsenal</h3><p>Сканнер + права</p>
<span class="badge" id="badge-usb">0</span>
</div>
<div class="card" onclick="showPanel('obd')">
<span class="icon">🚗</span><h3>OBD-II</h3><p>ELM327 диагностика</p>
<span class="badge" id="badge-obd">OFF</span>
</div>
<div class="card" onclick="showPanel('uart')">
<span class="icon">📟</span><h3>UART Bridge</h3><p>USB-Serial терминал</p>
<span class="badge" id="badge-uart">OFF</span>
</div>
<div class="card" onclick="showPanel('can')">
<span class="icon">🚌</span><h3>CAN Bus</h3><p>Sniffer + инжект</p>
<span class="badge" id="badge-can">OFF</span>
</div>
<div class="card" onclick="showPanel('ble')">
<span class="icon">📡</span><h3>BLE Scanner</h3><p>Bluetooth Low Energy</p>
<span class="badge" id="badge-ble">OFF</span>
</div>
<div class="card" onclick="showPanel('colibri')">
<span class="icon">⚙️</span><h3>ColibriAsm</h3><p>Disasm / Asm</p>
<span class="badge" id="badge-colibri">OFF</span>
</div>
<div class="card" onclick="showPanel('flash')">
<span class="icon">⚡</span><h3>Flash Tool</h3><p>CH341A / XGecu</p>
<span class="badge" id="badge-flash">OFF</span>
</div>
<div class="card" onclick="showPanel('debug')">
<span class="icon">🐛</span><h3>Debug Bridge</h3><p>J-Link / ST-Link</p>
<span class="badge" id="badge-debug">OFF</span>
</div>
<div class="card" onclick="showPanel('system')">
<span class="icon">🖥️</span><h3>System</h3><p>Статус + логи</p>
<span class="badge" id="badge-sys">OK</span>
</div>
</div>

<!-- USB Panel -->
<div class="panel" id="panel-usb">
<h2>🔌 USB Arsenal Scanner</h2>
<button class="btn" onclick="api('usb/scan')">🔍 Scan USB</button>
<button class="btn warn" onclick="api('usb/fix')">🔧 Fix Permissions</button>
<div class="output" id="out-usb"></div>
<table id="tbl-usb"><thead><tr><th>VID:PID</th><th>Name</th><th>Type</th></tr></thead><tbody></tbody></table>
</div>

<!-- OBD Panel -->
<div class="panel" id="panel-obd">
<h2>🚗 OBD-II Bridge</h2>
<button class="btn" onclick="api('obd/connect')">Connect</button>
<button class="btn" onclick="wsSend('obd','rpm')">RPM</button>
<button class="btn" onclick="wsSend('obd','speed')">Speed</button>
<button class="btn" onclick="wsSend('obd','temp')">Temp</button>
<button class="btn" onclick="wsSend('obd','pids')">PIDs</button>
<button class="btn err" onclick="wsClose('obd')">Disconnect</button>
<div class="output" id="out-obd"></div>
</div>

<!-- UART Panel -->
<div class="panel" id="panel-uart">
<h2>📟 UART Terminal</h2>
<div class="form-group">
<label>Port</label><select id="uart-port"><option value="auto">Auto</option><option value="/dev/ttyUSB0">/dev/ttyUSB0</option><option value="/dev/ttyUSB1">/dev/ttyUSB1</option><option value="/dev/ttyACM0">/dev/ttyACM0</option></select>
</div>
<div class="form-group">
<label>Baud</label><select id="uart-baud"><option value="115200">115200</option><option value="9600">9600</option><option value="38400">38400</option><option value="921600">921600</option></select>
</div>
<button class="btn" onclick="wsOpen('uart')">▶️ Open</button>
<button class="btn err" onclick="wsClose('uart')">⏹ Close</button>
<div class="output" id="out-uart" style="max-height:250px;"></div>
<div class="form-group" style="margin-top:8px;">
<input type="text" id="uart-input" placeholder="Send bytes..." onkeydown="if(event.key==='Enter')uartSend()">
<button class="btn" onclick="uartSend()">Send</button>
</div>
</div>

<!-- CAN Panel -->
<div class="panel" id="panel-can">
<h2>🚌 CAN Bus Sniffer</h2>
<div class="form-group">
<label>Interface</label><input type="text" id="can-iface" value="can0">
</div>
<div class="form-group">
<label>Bitrate</label><select id="can-bitrate"><option value="500000">500 kbps</option><option value="250000">250 kbps</option><option value="125000">125 kbps</option><option value="1000000">1 Mbps</option></select>
</div>
<button class="btn" onclick="api('can/up')">⬆️ Bring Up</button>
<button class="btn" onclick="wsOpen('can')">▶️ Sniff</button>
<button class="btn err" onclick="wsClose('can')">⏹ Stop</button>
<div class="output" id="out-can" style="max-height:250px;"></div>
</div>

<!-- BLE Panel -->
<div class="panel" id="panel-ble">
<h2>📡 BLE Scanner</h2>
<button class="btn" onclick="api('ble/scan')">🔍 Scan 10s</button>
<div class="output" id="out-ble"></div>
</div>

<!-- Colibri Panel -->
<div class="panel" id="panel-colibri">
<h2>⚙️ ColibriAsmEngine</h2>
<div class="form-group">
<label>Architecture</label><select id="colibri-arch"><option value="x86">x86</option><option value="x86_64">x86_64</option><option value="arm">ARM</option><option value="arm_thumb" selected>ARM Thumb</option><option value="arm64">ARM64</option><option value="mips">MIPS</option></select>
</div>
<div class="form-group">
<label>Hex Bytes</label><input type="text" id="colibri-hex" value="7047" placeholder="90909090">
</div>
<div class="form-group">
<label>Base Address (optional)</label><input type="text" id="colibri-addr" value="0x8000" placeholder="0x0">
</div>
<button class="btn" onclick="colibriDisasm()">🔍 Disassemble</button>
<button class="btn warn" onclick="api('colibri/status')">Status</button>
<div class="output" id="out-colibri"></div>
</div>

<!-- Flash Panel -->
<div class="panel" id="panel-flash">
<h2>⚡ Flash / Programmer Tool</h2>
<button class="btn" onclick="api('flash/detect')">🔍 Detect</button>
<button class="btn" onclick="api('flash/ch341')">CH341A Info</button>
<div class="output" id="out-flash"></div>
</div>

<!-- Debug Panel -->
<div class="panel" id="panel-debug">
<h2>🐛 Debug Bridge (SWD/JTAG)</h2>
<button class="btn" onclick="api('debug/detect')">🔍 Detect Debuggers</button>
<div class="output" id="out-debug"></div>
</div>

<!-- System Panel -->
<div class="panel" id="panel-system">
<h2>🖥️ System Status</h2>
<button class="btn" onclick="api('system/status')">📊 Status</button>
<button class="btn" onclick="api('system/usbsetup')">🔧 USB Setup</button>
<button class="btn" onclick="api('system/logcat')">📝 Logcat</button>
<div class="output" id="out-system"></div>
</div>

<script>
let wsMap={};
function showPanel(id){
  document.querySelectorAll('.panel').forEach(p=>p.classList.remove('show'));
  document.getElementById('panel-'+id).classList.add('show');
  window.scrollTo(0,0);
}
async function api(path){
  const out=document.getElementById('out-'+path.split('/')[0]);
  if(out) out.innerHTML+='<div class="log-line">⏳ '+path+'...</div>';
  try{
    const r=await fetch('/api/'+path);
    const j=await r.json();
    if(out) out.innerHTML+='<div class="log-line">✅ '+JSON.stringify(j)+'</div>';
    return j;
  }catch(e){
    if(out) out.innerHTML+='<div class="log-line">❌ '+e+'</div>';
    return{error:e.message};
  }
}
function wsOpen(channel){
  if(wsMap[channel]){wsMap[channel].close();}
  const proto=location.protocol==='https:'?'wss':'ws';
  const ws=new WebSocket(proto+'://'+location.host+'/ws/'+channel);
  wsMap[channel]=ws;
  const out=document.getElementById('out-'+channel);
  ws.onopen=()=>{if(out)out.innerHTML+='<div class="log-line" style="color:var(--accent)">▶️ Connected '+channel+'</div>'; updateWsStatus();};
  ws.onmessage=(ev)=>{if(out){out.innerHTML+='<div class="log-line">'+ev.data+'</div>'; out.scrollTop=out.scrollHeight;}};
  ws.onclose=()=>{if(out)out.innerHTML+='<div class="log-line" style="color:var(--warn)">⏹ Disconnected '+channel+'</div>'; delete wsMap[channel]; updateWsStatus();};
  ws.onerror=(e)=>{if(out)out.innerHTML+='<div class="log-line" style="color:var(--err)">💥 Error '+channel+': '+e+'</div>';};
}
function wsClose(channel){if(wsMap[channel]){wsMap[channel].close();}}
function wsSend(channel,cmd){if(wsMap[channel]&&wsMap[channel].readyState===1){wsMap[channel].send(cmd);}}
function updateWsStatus(){
  const el=document.getElementById('wsStatus');
  const active=Object.keys(wsMap).length;
  el.innerHTML=active?`🟢 ${active} WS`:'🔴 Offline';
  el.style.borderColor=active?'var(--accent)':'var(--err)';
}
function uartSend(){const v=document.getElementById('uart-input').value; if(v)wsSend('uart',v); document.getElementById('uart-input').value='';}
async function colibriDisasm(){
  const arch=document.getElementById('colibri-arch').value;
  const hex=document.getElementById('colibri-hex').value;
  const addr=document.getElementById('colibri-addr').value;
  const out=document.getElementById('out-colibri');
  out.innerHTML+='<div class="log-line">⏳ Disasm ['+arch+'] '+hex+' @ '+addr+'...</div>';
  try{
    const r=await fetch('/api/colibri/disasm',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({arch,hex,addr})});
    const j=await r.json();
    out.innerHTML+='<div class="log-line"><pre>'+(j.result||j.error)+'</pre></div>';
  }catch(e){out.innerHTML+='<div class="log-line">❌ '+e+'</div>';}
}
// Update USB badge periodically
setInterval(async()=>{
  try{const r=await fetch('/api/usb/scan'); const j=await r.json(); const n=j.devices?j.devices.length:0; document.getElementById('badge-usb').innerText=n; if(n>0)document.querySelector('[onclick="showPanel(\'usb\')"]').classList.add('active');}catch(e){}
},5000);
</script>
</body>
</html>
"""

# ── API endpoints ──────────────────────────────────────────────────────────

@app.get("/", response_class=HTMLResponse)
def index():
    return INDEX_HTML

@app.get("/api/usb/scan")
def usb_scan():
    out = run("lsusb", root=True)
    devices = []
    for line in out.split("\n"):
        m = re.match(r'Bus \d+ Device \d+: ID ([0-9a-f]{4}):([0-9a-f]{4}) (.*)', line)
        if m:
            vid, pid, name = m.groups()
            key = f"{vid}:{pid}"
            info = USB_DB.get(key, {"name": name.strip(), "type": "unknown", "icon": "❓"})
            devices.append({"vid": vid, "pid": pid, **info})
    return {"devices": devices, "count": len(devices)}

@app.get("/api/usb/fix")
def usb_fix():
    return {"result": run("bash /data/adb/modules/argos-system/system/xbin/argos-usb-setup", root=True)}

@app.get("/api/obd/connect")
def obd_connect():
    return {"result": "OBD connect stub — use WS /ws/obd for real-time"}

@app.get("/api/can/up")
def can_up(iface: str = "can0", bitrate: int = 500000):
    return {"result": run(f"bash /data/adb/modules/argos-system/system/xbin/argos-can-up {iface} {bitrate}", root=True)}

@app.get("/api/ble/scan")
def ble_scan():
    return {"result": "BLE scan requires bleak. Install: pip install bleak", "devices": []}

@app.get("/api/flash/detect")
def flash_detect():
    return {"result": run("lsusb | grep -E 'CH341|XGecu|FNIRSI'", root=True)}

@app.get("/api/flash/ch341")
def flash_ch341():
    return {"result": "CH341A: use pyftdi or ch341a_dump.py script"}

@app.get("/api/debug/detect")
def debug_detect():
    return {"result": run("lsusb | grep -E 'ST-Link|J-Link|CMSIS'", root=True)}

@app.get("/api/system/status")
def system_status():
    return {"result": run("bash /data/adb/modules/argos-system/system/xbin/argos-status", root=True)}

@app.get("/api/system/usbsetup")
def system_usbsetup():
    return {"result": run("bash /data/adb/modules/argos-system/system/xbin/argos-usb-setup", root=True)}

@app.get("/api/system/logcat")
def system_logcat():
    return {"result": run("logcat -d -t 50", root=False)}

@app.get("/api/colibri/status")
def colibri_status():
    have_cs = False
    try:
        import capstone
        have_cs = True
    except: pass
    have_ks = False
    try:
        import keystone
        have_ks = True
    except: pass
    return {"capstone": have_cs, "keystone": have_ks}

@app.post("/api/colibri/disasm")
def colibri_disasm(data: dict):
    arch = data.get("arch", "arm_thumb")
    hex_str = data.get("hex", "90909090").replace(" ", "")
    addr = int(data.get("addr", "0"), 0)
    try:
        raw = binascii.unhexlify(hex_str)
    except:
        return {"error": "Invalid hex"}
    try:
        import capstone as cs_mod
        arch_map = {
            "x86": (cs_mod.CS_ARCH_X86, cs_mod.CS_MODE_32),
            "x86_64": (cs_mod.CS_ARCH_X86, cs_mod.CS_MODE_64),
            "arm": (cs_mod.CS_ARCH_ARM, cs_mod.CS_MODE_ARM),
            "arm_thumb": (cs_mod.CS_ARCH_ARM, cs_mod.CS_MODE_THUMB),
            "arm64": (cs_mod.CS_ARCH_ARM64, cs_mod.CS_MODE_LITTLE_ENDIAN),
            "mips": (cs_mod.CS_ARCH_MIPS, cs_mod.CS_MODE_MIPS32),
        }
        if arch not in arch_map:
            return {"error": f"Arch {arch} not supported"}
        md = cs_mod.Cs(*arch_map[arch])
        lines = []
        for insn in md.disasm(raw, addr):
            lines.append(f"0x{insn.address:08x}:  {insn.bytes.hex():12s}  {insn.mnemonic:<12s} {insn.op_str}")
        return {"result": "\n".join(lines) or "No instructions decoded"}
    except Exception as e:
        return {"error": str(e)}

# ── WebSocket endpoints ──────────────────────────────────────────────────────

class WSManager:
    def __init__(self):
        self.active: dict[str, WebSocket] = {}
        self.tasks: dict[str, asyncio.Task] = {}
    async def connect(self, name: str, ws: WebSocket):
        await ws.accept()
        self.active[name] = ws
        if name == "can":
            self.tasks[name] = asyncio.create_task(self._can_loop(ws))
        elif name == "uart":
            pass  # bidirectional handled in receive
        elif name == "obd":
            self.tasks[name] = asyncio.create_task(self._obd_loop(ws))
    async def disconnect(self, name: str):
        if name in self.active:
            del self.active[name]
        if name in self.tasks:
            self.tasks[name].cancel()
            del self.tasks[name]
    async def _can_loop(self, ws: WebSocket):
        proc = await asyncio.create_subprocess_shell(
            "su -c 'candump can0 -ta'",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        try:
            while True:
                line = await asyncio.wait_for(proc.stdout.readline(), timeout=1.0)
                if line:
                    await ws.send_text(line.decode().strip())
        except asyncio.TimeoutError:
            pass
        except Exception:
            pass
        finally:
            proc.kill()
    async def _obd_loop(self, ws: WebSocket):
        # Stub: real OBD would use pyserial to ELM327
        for _ in range(100):
            await asyncio.sleep(2)
            try:
                await ws.send_text("OBD: stub data — connect ELM327 for real values")
            except:
                break

ws_mgr = WSManager()

@app.websocket("/ws/{channel}")
async def websocket_endpoint(ws: WebSocket, channel: str):
    await ws_mgr.connect(channel, ws)
    try:
        while True:
            data = await ws.receive_text()
            if channel == "uart":
                # Echo back for now; real impl would write to serial
                await ws.send_text(f">>> {data}")
            elif channel == "obd":
                await ws.send_text(f"CMD: {data}")
            elif channel == "can":
                await ws.send_text(f"INJECT: {data}")
    except WebSocketDisconnect:
        await ws_mgr.disconnect(channel)
    except Exception:
        await ws_mgr.disconnect(channel)

# ── main ───────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    print(f"[ARGOS Dashboard] http://{args.host}:{args.port}")
    uvicorn.run(app, host=args.host, port=args.port, log_level="warning")

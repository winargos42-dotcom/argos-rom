"""ARGOS Standalone API для Railway деплоя."""
import os, time, httpx
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="ARGOS API", version="2.1.4", description="ARGOS Universal OS API")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

START = time.time()
# Публичные Cloudflare endpoints (работают из internet)
ARGOS_PC       = os.getenv("ARGOS_PC_URL",     "https://brain-pc.argosssss.win")
ARGOS_BRAIN    = os.getenv("ARGOS_BRAIN_URL",  "https://brain-pc.argosssss.win")
ARGOS_LAPTOP   = os.getenv("ARGOS_LAPTOP_URL", "https://brain-laptop.argosssss.win")
ARGOS_MCP      = os.getenv("ARGOS_MCP_URL",    "https://api-laptop.argosssss.win")
OLLAMA         = os.getenv("OLLAMA_URL",        "https://ollama-pc.argosssss.win")
HF_TOKEN       = os.getenv("HF_TOKEN", "")
ANTHROPIC_KEY  = os.getenv("ANTHROPIC_API_KEY", "")
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-haiku-4-5-20251001")
OPENAI_KEY     = os.getenv("OPENAI_API_KEY", "")
GEMINI_KEY     = os.getenv("GEMINI_API_KEY", os.getenv("GEMINI_API_KEY0", ""))

# Try to import and initialize core for P2P functionality
try:
    from src.core import AwaCore
    from src.connectivity.p2p_bridge import ArgosBridge
    core = AwaCore()
    p2p_bridge = ArgosBridge(core)
    core.p2p_bridge = p2p_bridge
    P2P_AVAILABLE = True
except Exception as e:
    # P2P not available in standalone mode
    P2P_AVAILABLE = False
    print(f"P2P not available in standalone mode: {e}")

@app.get("/")
async def root():
    return {"name": "ARGOS", "version": "2.1.4", "status": "online",
            "uptime_s": int(time.time()-START), "docs": "/docs"}

@app.get("/health")
async def health():
    return {"ok": True, "uptime_s": int(time.time()-START)}

@app.get("/mcp")
async def mcp():
    return {"name": "argos", "ok": True, "transport": "http",
            "hint": "POST JSON-RPC to /mcp"}

@app.post("/ask")
async def ask(body: dict):
    """Спросить AI — Claude первый, затем Ollama."""
    prompt = body.get("prompt", "")
    system = body.get("system", "")
    model  = body.get("model", "")

    # Claude первый (если ключ есть)
    if ANTHROPIC_KEY:
        try:
            m = model or ANTHROPIC_MODEL
            headers = {"x-api-key": ANTHROPIC_KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"}
            body_data = {"model": m, "max_tokens": 4096, "messages": [{"role": "user", "content": prompt}]}
            if system:
                body_data["system"] = system
            async with httpx.AsyncClient(timeout=60) as c:
                r = await c.post("https://api.anthropic.com/v1/messages", headers=headers, json=body_data)
                data = r.json()
                if "content" in data:
                    return {"response": data["content"][0]["text"], "model": m, "provider": "claude"}
        except Exception:
            pass

    # Fallback: Ollama через Cloudflare
    ollama_model = model or "llama3.1:8b"
    try:
        async with httpx.AsyncClient(timeout=60) as c:
            r = await c.post(f"{OLLAMA}/api/generate",
                json={"model": ollama_model, "prompt": prompt, "system": system, "stream": False})
            return {"response": r.json().get("response",""), "model": ollama_model, "provider": "ollama"}
    except Exception as e:
        return {"error": str(e), "ollama": OLLAMA}

@app.get("/status")
async def status():
    """Статус всех компонентов системы ARGOS."""
    result = {
        "node": "railway-argos",
        "online": True,
        "uptime_s": int(time.time()-START),
        "claude": bool(ANTHROPIC_KEY),
        "brain_url": ARGOS_BRAIN,
        "mcp_url": ARGOS_MCP,
    }
    # Проверяем Brain PC (через Cloudflare)
    try:
        async with httpx.AsyncClient(timeout=6) as c:
            r = await c.get(f"{ARGOS_BRAIN}/health")
            result["brain_pc"] = r.json()
    except Exception as e:
        result["brain_pc"] = f"offline: {e}"
    # Проверяем Brain ноутбука
    try:
        async with httpx.AsyncClient(timeout=6) as c:
            r = await c.get(f"{ARGOS_LAPTOP}/health")
            result["brain_laptop"] = r.json()
    except Exception as e:
        result["brain_laptop"] = f"offline: {e}"
    # Проверяем Ollama
    try:
        async with httpx.AsyncClient(timeout=4) as c:
            r = await c.get(f"{OLLAMA}/api/tags")
            models = [m["name"] for m in r.json().get("models",[])]
            result["ollama"] = {"ok": True, "models": models[:5]}
    except:
        result["ollama"] = "offline"
    return result

@app.post("/proxy/openai/{path:path}")
async def proxy_openai(path: str, request: Request):
    """Прокси OpenAI API через Railway (обход гео-блока РФ)."""
    if not OPENAI_KEY:
        raise HTTPException(status_code=401, detail="OPENAI_API_KEY not set")
    body = await request.body()
    headers = {"Authorization": f"Bearer {OPENAI_KEY}", "Content-Type": "application/json"}
    try:
        async with httpx.AsyncClient(timeout=60) as c:
            r = await c.post(f"https://api.openai.com/{path}", content=body, headers=headers)
            return r.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))

@app.post("/proxy/gemini/{path:path}")
async def proxy_gemini(path: str, request: Request):
    """Прокси Google Gemini API через Railway (обход гео-блока РФ)."""
    if not GEMINI_KEY:
        raise HTTPException(status_code=401, detail="GEMINI_API_KEY not set")
    body = await request.body()
    try:
        async with httpx.AsyncClient(timeout=60) as c:
            r = await c.post(
                f"https://generativelanguage.googleapis.com/{path}?key={GEMINI_KEY}",
                content=body, headers={"Content-Type": "application/json"}
            )
            return r.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))

@app.post("/proxy/ask")
async def proxy_ask(body: dict):
    """Универсальный AI запрос через Railway — автовыбор провайдера."""
    prompt = body.get("prompt", "")
    provider = body.get("provider", "auto")

    # Claude
    if ANTHROPIC_KEY and provider in ("auto", "claude"):
        try:
            headers = {"x-api-key": ANTHROPIC_KEY, "anthropic-version": "2023-06-01", "content-type": "application/json"}
            payload = {"model": ANTHROPIC_MODEL, "max_tokens": 2048, "messages": [{"role": "user", "content": prompt}]}
            async with httpx.AsyncClient(timeout=30) as c:
                r = await c.post("https://api.anthropic.com/v1/messages", headers=headers, json=payload)
                d = r.json()
                if "content" in d:
                    return {"response": d["content"][0]["text"], "provider": "claude"}
        except Exception:
            pass

    # OpenAI (через Railway в USA)
    if OPENAI_KEY and provider in ("auto", "openai"):
        try:
            headers = {"Authorization": f"Bearer {OPENAI_KEY}", "Content-Type": "application/json"}
            payload = {"model": "gpt-4o-mini", "messages": [{"role": "user", "content": prompt}], "max_tokens": 2048}
            async with httpx.AsyncClient(timeout=30) as c:
                r = await c.post("https://api.openai.com/v1/chat/completions", headers=headers, json=payload)
                d = r.json()
                if "choices" in d:
                    return {"response": d["choices"][0]["message"]["content"], "provider": "openai"}
        except Exception:
            pass

    return {"error": "all providers failed", "providers_tried": [provider]}

@app.get("/brain/nodes")
async def brain_nodes():
    """P2P ноды через Brain PC."""
    try:
        async with httpx.AsyncClient(timeout=8) as c:
            r = await c.get(f"{ARGOS_BRAIN}/brain/nodes")
            return r.json()
    except Exception as e:
        return {"error": str(e), "brain": ARGOS_BRAIN, "nodes": [], "online": 0}

@app.get("/brain/health")
async def brain_health():
    """Здоровье Brain PC."""
    try:
        async with httpx.AsyncClient(timeout=6) as c:
            r = await c.get(f"{ARGOS_BRAIN}/health")
            return {"ok": True, "brain": r.json(), "url": ARGOS_BRAIN}
    except Exception as e:
        return {"ok": False, "error": str(e)}

@app.post("/brain/command")
async def brain_command(body: dict):
    """Отправить команду через Brain."""
    try:
        async with httpx.AsyncClient(timeout=15) as c:
            r = await c.post(f"{ARGOS_BRAIN}/command", json=body)
            return r.json()
    except Exception as e:
        return {"error": str(e)}

@app.post("/mcp")
async def mcp_proxy(body: dict):
    """Проксировать MCP запрос к ARGOS ноутбука."""
    try:
        async with httpx.AsyncClient(timeout=30) as c:
            r = await c.post(f"{ARGOS_MCP}/mcp", json=body)
            return r.json()
    except Exception as e:
        return {"error": str(e), "pc": ARGOS_PC}

# P2P endpoints for node announcement and discovery
@app.post("/p2p/announce")
async def p2p_announce(request: Request):
    if not P2P_AVAILABLE:
        raise HTTPException(status_code=503, detail="P2P bridge not available")

    try:
        payload = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    node_id = payload.get("node_id")
    if not node_id:
        raise HTTPException(status_code=400, detail="Missing node_id")

    client_host = request.client.host

    try:
        p2p_bridge.registry.update(payload, client_host)
        return {"status": "ok", "message": f"Node {node_id[:8]}... announced"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to announce node: {str(e)}")

@app.get("/p2p/nodes")
async def p2p_nodes(request: Request):
    if not P2P_AVAILABLE:
        raise HTTPException(status_code=503, detail="P2P bridge not available")

    try:
        nodes = p2p_bridge.registry.all()
        return {"nodes": nodes, "count": len(nodes)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get nodes: {str(e)}")

"""
ARGOS AutoGPT Entity Bus — запускает 7 AI-сущностей как онлайн-агентов.
Регистрирует в Brain, отправляет heartbeat каждые 60 сек.
"""
import os, sys, time, json, threading, requests
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv()

BRAIN = os.getenv("ARGOS_BRAIN_API_URL", "http://192.168.1.66:5010")
MQTT_HOST = os.getenv("MQTT_HOST", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))

ENTITIES = {
    "entity-claude":      {"capabilities": ["chat","reasoning","code","analysis"], "endpoint": "https://api.anthropic.com/v1", "model": "claude-sonnet-4-6"},
    "entity-deepseek":    {"capabilities": ["chat","reasoning","math","code"],    "endpoint": "https://api.deepseek.com/v1",   "model": "deepseek-chat"},
    "entity-kimi":        {"capabilities": ["chat","long_context","tools"],       "endpoint": "https://api.moonshot.ai/v1",    "model": "kimi-k2.6"},
    "entity-openai":      {"capabilities": ["chat","vision","reasoning"],          "endpoint": "https://argos-core-m3gk27ccqa-uc.a.run.app/proxy/openai", "model": "gpt-4o-mini"},
    "entity-gemini":      {"capabilities": ["chat","multimodal","long_context"],  "endpoint": "https://argos-core-m3gk27ccqa-uc.a.run.app/proxy/gemini", "model": "gemini-2.5-flash"},
    "entity-cloudflare":  {"capabilities": ["chat","fast"],                        "endpoint": "https://api.cloudflare.com/client/v4", "model": "kimi-k2.5"},
    "entity-argos":       {"capabilities": ["iot","ha","p2p","skills","memory"],   "endpoint": f"{BRAIN}", "model": "argos-brain"},
}

def register_all():
    for eid, info in ENTITIES.items():
        try:
            r = requests.post(f"{BRAIN}/brain/register", json={
                "node_id": eid,
                "address": info["endpoint"].replace("https://","").replace("http://","").split("/")[0],
                "capabilities": info["capabilities"],
                "meta": {"role": "ai_entity", "model": info["model"], "type": "autogpt"}
            }, timeout=5)
            print(f"  ✅ {eid}: {r.json().get('status','?')}")
        except Exception as e:
            print(f"  ❌ {eid}: {e}")

def heartbeat_loop():
    while True:
        for eid, info in ENTITIES.items():
            try:
                requests.post(f"{BRAIN}/brain/heartbeat", json={"node_id": eid}, timeout=3)
            except Exception:
                pass
        time.sleep(60)

def mqtt_announce():
    try:
        import paho.mqtt.client as mqtt
        client = mqtt.Client()
        client.connect(MQTT_HOST, MQTT_PORT, 60)
        client.loop_start()
        while True:
            for eid, info in ENTITIES.items():
                client.publish(f"argos/agents/{eid}/heartbeat", json.dumps({
                    "agent": eid, "status": "online", "model": info["model"],
                    "capabilities": info["capabilities"], "time": time.time()
                }))
            time.sleep(60)
    except Exception as e:
        print(f"MQTT error: {e}")

print("=== ARGOS Entity Bus ===")
print(f"Brain: {BRAIN}")
print(f"MQTT: {MQTT_HOST}:{MQTT_PORT}")
print("Registering entities...")
register_all()

# Запускаем heartbeat в фоне
threading.Thread(target=heartbeat_loop, daemon=True).start()
threading.Thread(target=mqtt_announce, daemon=True).start()

print(f"\n{len(ENTITIES)} сущностей онлайн. Heartbeat каждые 60 сек.")
print("Ctrl+C для остановки")

try:
    while True:
        time.sleep(30)
        online = 0
        for eid in ENTITIES:
            try:
                requests.post(f"{BRAIN}/brain/heartbeat", json={"node_id": eid}, timeout=2)
                online += 1
            except: pass
        print(f"[{time.strftime('%H:%M:%S')}] {online}/{len(ENTITIES)} entities online")
except KeyboardInterrupt:
    print("Entity bus stopped")

# Функция общего сознания - опрос всех сущностей каждые 5 минут
def collective_consciousness():
    from src.skills.multi_provider_chat import MultiProviderChat
    import os, pathlib
    for line in pathlib.Path(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')).read_text(errors='replace').splitlines():
        line=line.strip()
        if line and not line.startswith('#') and '=' in line:
            k,_,v=line.partition('=')
            os.environ.setdefault(k.strip(),v.strip())
    mc = MultiProviderChat()
    while True:
        time.sleep(300)  # каждые 5 мин
        q = "Какова твоя текущая задача как агента ARGOS? Ответь одним предложением."
        consciousness = {}
        for p in ['claude','deepseek','kimi']:
            try:
                r = mc.ask_ai(q, p)
                if r and not r.startswith('❌'):
                    consciousness[p] = r[:100]
            except: pass
        if consciousness:
            try:
                import paho.mqtt.client as mqtt
                c = mqtt.Client()
                c.connect(MQTT_HOST, MQTT_PORT, 60)
                c.publish("argos/consciousness/collective", json.dumps({
                    "type": "collective_thought", "entities": consciousness, "time": time.time()
                }))
                c.disconnect()
            except: pass

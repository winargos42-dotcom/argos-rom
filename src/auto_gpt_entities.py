"""
auto_gpt_entities.py — AutoGPT Entity Framework for ARGOS Universal OS v2.1.3

Defines AI provider entities as autonomous agents that can:
  • Register on the AgentBus (MQTT)
  • Publish heartbeats and status
  • Receive commands via MQTT topics
  • Report capabilities and metrics
  • Participate in auto-consensus chains
"""

from __future__ import annotations
import json, time, threading
from dataclasses import dataclass, field, asdict
from typing import Any, Dict, List, Optional
from src.argos_logger import get_logger

log = get_logger("argos.auto_gpt_entities")

# ── Entity Definitions ─────────────────────────────────────────────────────

@dataclass
class EntityConfig:
    name: str
    display_name: str
    entity_type: str  # "ai_provider", "vision", "iot_bridge", "mcp"
    status: str = "standby"  # "active", "standby", "offline", "error"
    api_endpoint: str = ""
    model: str = ""
    context_window: int = 0
    rpm_limit: int = 0
    capabilities: List[str] = field(default_factory=list)
    mqtt_topic: str = ""
    env_disable_var: str = ""
    description: str = ""

    def to_dict(self):
        return asdict(self)


# ── Registry of all AutoGPT entities ───────────────────────────────────────

ENTITIES: Dict[str, EntityConfig] = {
    "claude": EntityConfig(
        name="claude",
        display_name="Claude Sonnet Agent",
        entity_type="ai_provider",
        status="active",
        api_endpoint="https://api.anthropic.com/v1",
        model="claude-sonnet-4-6",
        context_window=200000,
        rpm_limit=50,
        capabilities=["chat", "reasoning", "code", "analysis", "long_context", "tool_use"],
        mqtt_topic="argos/agents/claude",
        env_disable_var="ARGOS_DISABLE_CLAUDE",
        description="Anthropic Claude Sonnet — основной провайдер ARGOS",
    ),
    "deepseek": EntityConfig(
        name="deepseek",
        display_name="DeepSeek Agent",
        entity_type="ai_provider",
        status="active",
        api_endpoint="https://api.deepseek.com/v1",
        model="deepseek-chat",
        context_window=128000,
        rpm_limit=15,
        capabilities=["chat", "reasoning", "code", "math"],
        mqtt_topic="argos/agents/deepseek",
        env_disable_var="ARGOS_DISABLE_DEEPSEEK",
        description="DeepSeek V3/R1 reasoning model via API",
    ),
    "kimi": EntityConfig(
        name="kimi",
        display_name="Kimi K2.5 Agent",
        entity_type="ai_provider",
        status="active",
        api_endpoint="https://api.moonshot.ai/v1",
        model="kimi-k2.6",
        context_window=256000,
        rpm_limit=60,
        capabilities=["chat", "reasoning", "tool_calling", "long_context"],
        mqtt_topic="argos/agents/kimi",
        env_disable_var="ARGOS_DISABLE_KIMI",
        description="Moonshot AI Kimi K2.5 with 256k context and tool calling",
    ),
    "gemini": EntityConfig(
        name="gemini",
        display_name="Gemini Flash",
        entity_type="ai_provider",
        status="active",
        api_endpoint="https://generativelanguage.googleapis.com",
        model="gemini-2.5-flash",
        context_window=1000000,
        rpm_limit=25,  # 5 keys × 5 RPM
        capabilities=["chat", "reasoning", "vision", "multimodal"],
        mqtt_topic="argos/agents/gemini",
        env_disable_var="ARGOS_DISABLE_GEMINI",
        description="Google Gemini Flash with 1M context, 5-key rotation",
    ),
    "cloudflare": EntityConfig(
        name="cloudflare",
        display_name="CF Workers AI",
        entity_type="ai_provider",
        status="active",
        api_endpoint="https://api.cloudflare.com/client/v4",
        model="@cf/moonshotai/kimi-k2.5",
        context_window=256000,
        rpm_limit=60,
        capabilities=["chat", "reasoning", "edge_inference"],
        mqtt_topic="argos/agents/cloudflare",
        env_disable_var="ARGOS_DISABLE_CLOUDFLARE",
        description="Cloudflare Workers AI edge inference with kimi-k2.5",
    ),
    "ollama_vision": EntityConfig(
        name="ollama_vision",
        display_name="Ollama Vision",
        entity_type="vision",
        status="standby",
        api_endpoint="http://192.168.1.66:11434",
        model="llava:7b",
        context_window=0,
        rpm_limit=999999,  # local = unlimited
        capabilities=["vision", "image_analysis", "ocr", "screenshot"],
        mqtt_topic="argos/agents/ollama_vision",
        env_disable_var="ARGOS_DISABLE_VISION",
        description="Local vision analysis via Ollama llava:7b on PC",
    ),
    "mcp_server": EntityConfig(
        name="mcp_server",
        display_name="MCP API Server",
        entity_type="mcp",
        status="active",
        api_endpoint="http://localhost:8765",
        model="",
        context_window=0,
        rpm_limit=999999,
        capabilities=["tool_server", "mcp_protocol", "context_management"],
        mqtt_topic="argos/agents/mcp_server",
        env_disable_var="ARGOS_DISABLE_MCP",
        description="Model Context Protocol server for tool integration",
    ),
    "openai": EntityConfig(
        name="openai",
        display_name="OpenAI GPT Agent",
        entity_type="ai_provider",
        status="active",
        api_endpoint="https://argos-core-m3gk27ccqa-uc.a.run.app/proxy/openai",
        model="gpt-4o-mini",
        context_window=128000,
        rpm_limit=3,
        capabilities=["chat", "reasoning", "code", "vision"],
        mqtt_topic="argos/agents/openai",
        env_disable_var="ARGOS_DISABLE_OPENAI",
        description="OpenAI GPT через GCP proxy (обход гео-блока РФ)",
    ),
    "gemini": EntityConfig(
        name="gemini",
        display_name="Google Gemini Agent",
        entity_type="ai_provider",
        status="active",
        api_endpoint="https://argos-core-m3gk27ccqa-uc.a.run.app/proxy/gemini",
        model="gemini-2.5-flash",
        context_window=1000000,
        rpm_limit=25,
        capabilities=["chat", "reasoning", "vision", "multimodal", "long_context"],
        mqtt_topic="argos/agents/gemini",
        env_disable_var="ARGOS_DISABLE_GEMINI",
        description="Google Gemini через GCP proxy (обход гео-блока РФ)",
    ),
    "argos": EntityConfig(
        name="argos",
        display_name="ARGOS Universal OS",
        entity_type="ai_provider",
        status="active",
        api_endpoint="http://192.168.1.66:5010",
        model="argos-brain",
        context_window=32000,
        rpm_limit=60,
        capabilities=["chat", "iot", "ha", "p2p", "skills", "memory", "reasoning"],
        mqtt_topic="argos/agents/argos",
        env_disable_var="ARGOS_DISABLE_SELF",
        description="ARGOS Universal OS — сама система как AI агент (Brain API на ПК)",
    ),
    "argos-v1": EntityConfig(
        name="argos-v1",
        display_name="ARGOS v1 Local Agent",
        entity_type="ai_agent",
        status="active",
        api_endpoint="http://192.168.1.66:11434",
        model="argos-v1",
        context_window=4096,
        rpm_limit=30,
        capabilities=["action", "ha_control", "iot", "mqtt", "local", "smart_home"],
        mqtt_topic="argos/agents/argos-v1",
        env_disable_var="ARGOS_V1_ENABLED",
        description="ARGOS v1 — локальная модель на GPU PC с action loop: управляет умным домом",
    ),
}


class AutoGPTEntityBus:
    """Manages AutoGPT entities on the MQTT AgentBus."""

    def __init__(self, mqtt_host="localhost", mqtt_port=1883):
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.entities = ENTITIES.copy()
        self._client = None
        self._heartbeat_thread = None
        self._running = False

    def start(self):
        """Start the entity bus: connect MQTT, publish heartbeats."""
        try:
            import paho.mqtt.client as mqtt
            self._client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2)
            self._client.on_connect = self._on_connect
            self._client.on_message = self._on_message
            self._client.connect(self.mqtt_host, self.mqtt_port, 60)
            self._client.loop_start()
            self._running = True
            self._heartbeat_thread = threading.Thread(target=self._heartbeat_loop, daemon=True)
            self._heartbeat_thread.start()
            log.info("[AutoGPT] Entity Bus started — %d entities registered", len(self.entities))
        except Exception as e:
            log.error("[AutoGPT] Failed to start entity bus: %s", e)

    def _on_connect(self, client, userdata, flags, rc, properties=None):
        if rc == 0:
            for name, entity in self.entities.items():
                client.subscribe(f"{entity.mqtt_topic}/inbox")
                client.subscribe(f"{entity.mqtt_topic}/command")
            client.subscribe("argos/broadcast")
            client.subscribe("argos/command")
            log.info("[AutoGPT] Connected to MQTT, subscribed to entity topics")

    def _on_message(self, client, userdata, msg):
        try:
            payload = json.loads(msg.payload.decode())
            topic = msg.topic
            if "/command" in topic or topic == "argos/command":
                self._handle_command(payload)
        except Exception as e:
            log.warning("[AutoGPT] Message handling error: %s", e)

    def _handle_command(self, payload):
        cmd = payload.get("command", "")
        target = payload.get("target", "")
        if cmd == "status" and target in self.entities:
            entity = self.entities[target]
            self._client.publish(
                f"{entity.mqtt_topic}/outbox",
                json.dumps(entity.to_dict())
            )
        elif cmd == "list":
            self._client.publish(
                "argos/agents/bus/outbox",
                json.dumps({n: e.to_dict() for n, e in self.entities.items()})
            )

    def _heartbeat_loop(self):
        while self._running:
            for name, entity in self.entities.items():
                if entity.status in ("active", "standby"):
                    self._client.publish(
                        "argos/heartbeat",
                        json.dumps({"agent": name, "status": entity.status, "time": time.time()})
                    )
            time.sleep(60)

    def stop(self):
        self._running = False
        if self._client:
            self._client.loop_stop()
            self._client.disconnect()

    def get_status(self) -> Dict[str, str]:
        return {n: e.status for n, e in self.entities.items()}


def register_entity(entity: EntityConfig):
    """Register a new entity at runtime."""
    ENTITIES[entity.name] = entity
    log.info("[AutoGPT] Registered entity: %s (%s)", entity.name, entity.entity_type)


def get_entity(name: str) -> Optional[EntityConfig]:
    return ENTITIES.get(name)


def list_entities() -> Dict[str, EntityConfig]:
    return ENTITIES.copy()

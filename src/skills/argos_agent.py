"""
argos_agent.py — AutoGPT сущность ARGOS v1
Запускает argos-v1 (tinyllama) как агента который умеет действовать:
- управлять умным домом через HA API
- отправлять MQTT команды
- читать статус системы

Формат действий: [TURN_ON: entity], [TURN_OFF: entity], [STATUS], [MQTT: topic, msg]
"""

SKILL_NAME = "argos_agent"
SKILL_DESCRIPTION = "AutoGPT агент ARGOS v1 — локальная модель с action loop"
SKILL_TRIGGERS = [
    "аргос агент", "argos agent", "агент аргос",
    "спроси аргос", "ask argos", "argos v1",
    "автогпт аргос", "autogpt argos",
]

import os, re, json, urllib.request
from typing import Optional


def _ha_call(service: str, entity_id: str) -> str:
    HA = os.getenv("HA_URL", "http://localhost:8123")
    TOKEN = os.getenv("HA_TOKEN", "")
    if not TOKEN:
        return f"[SIM] {service}({entity_id})"
    domain, svc = service.split(".")
    payload = json.dumps({"entity_id": entity_id}).encode()
    try:
        req = urllib.request.Request(
            f"{HA}/api/services/{domain}/{svc}", data=payload,
            headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
            method="POST"
        )
        urllib.request.urlopen(req, timeout=5)
        return f"✅ {service} → {entity_id}"
    except Exception as e:
        return f"❌ {e}"


def _mqtt_publish(topic: str, message: str) -> str:
    try:
        import paho.mqtt.client as mqtt
        c = mqtt.Client()
        c.connect(os.getenv("MQTT_HOST", "localhost"), int(os.getenv("MQTT_PORT", "1883")), 60)
        c.publish(topic.strip(), message.strip())
        c.disconnect()
        return f"✅ MQTT → {topic}: {message}"
    except Exception as e:
        return f"❌ MQTT: {e}"


def _get_ha_status() -> str:
    HA = os.getenv("HA_URL", "http://localhost:8123")
    TOKEN = os.getenv("HA_TOKEN", "")
    if not TOKEN:
        return "HA_TOKEN не задан"
    try:
        req = urllib.request.Request(f"{HA}/api/states",
            headers={"Authorization": f"Bearer {TOKEN}"})
        with urllib.request.urlopen(req, timeout=8) as r:
            states = json.loads(r.read())
        lights = [(x['attributes'].get('friendly_name', x['entity_id']), x['state'])
                  for x in states if x['entity_id'].startswith('light.')]
        on = [n for n, s in lights if s == 'on']
        temp = next((x['state'] for x in states if 'temperature_humidity_sensor_temperature' in x['entity_id']), '?')
        door = next((x['state'] for x in states if 'dver_door' in x['entity_id']), '?')
        return f"Свет вкл: {', '.join(on) or 'нет'}. Температура: {temp}°C. Дверь: {'открыта' if door=='on' else 'закрыта'}."
    except Exception as e:
        return f"Ошибка: {e}"


def _execute_actions(text: str) -> tuple[str, list]:
    """Парсит [ДЕЙСТВИЕ: ...] из ответа модели и выполняет их."""
    actions_done = []

    # TURN_ON / TURN_OFF
    for match in re.finditer(r'\[TURN_(ON|OFF):\s*([^\]]+)\]', text, re.IGNORECASE):
        action, entity = match.group(1).upper(), match.group(2).strip()
        r = _ha_call(f"light.turn_{action.lower()}" if entity.startswith('light') else f"switch.turn_{action.lower()}", entity)
        actions_done.append(r)
        text = text.replace(match.group(0), '')

    # SET_TEMP
    for match in re.finditer(r'\[SET_TEMP:\s*([^,\]]+),\s*(\d+)\]', text, re.IGNORECASE):
        entity, temp = match.group(1).strip(), int(match.group(2))
        r = _ha_call(f"climate.set_temperature", entity)
        actions_done.append(f"✅ {entity} → {temp}°C")
        text = text.replace(match.group(0), '')

    # MQTT
    for match in re.finditer(r'\[MQTT:\s*([^,\]]+),\s*([^\]]+)\]', text, re.IGNORECASE):
        topic, msg = match.group(1).strip(), match.group(2).strip()
        r = _mqtt_publish(topic, msg)
        actions_done.append(r)
        text = text.replace(match.group(0), '')

    # STATUS
    if '[STATUS]' in text.upper():
        status = _get_ha_status()
        actions_done.append(status)
        text = text.replace('[STATUS]', status)

    return text.strip(), actions_done


def _ask_argos_v1(prompt: str) -> str:
    """Запрос к argos-v1 через Ollama с action execution."""
    OLLAMA = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    # Добавляем контекст статуса
    try:
        status = _get_ha_status()
        full_prompt = f"Текущий статус: {status}\n\nЗапрос: {prompt}"
    except Exception:
        full_prompt = prompt

    try:
        payload = json.dumps({
            "model": "argos-v1",
            "prompt": full_prompt,
            "stream": False,
            "options": {"temperature": 0.3, "num_predict": 200}
        }).encode()
        req = urllib.request.Request(
            f"{OLLAMA}/api/generate", data=payload,
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=30) as r:
            response = json.loads(r.read()).get("response", "")
    except Exception as e:
        return f"❌ argos-v1: {e}"

    # Выполняем действия из ответа
    clean_response, actions = _execute_actions(response)

    result = clean_response
    if actions:
        result += "\n" + "\n".join(actions)
    return result.strip() or "✅ Выполнено"


def handle(text: str, core=None) -> Optional[str]:
    t = (text or "").lower().strip()
    if not any(tr in t for tr in SKILL_TRIGGERS):
        return None
    # Убираем триггерное слово из запроса
    for tr in SKILL_TRIGGERS:
        t = t.replace(tr, "").strip()
    prompt = text
    for tr in SKILL_TRIGGERS:
        prompt = prompt.lower().replace(tr, "").strip()
    if not prompt:
        prompt = "опиши своё состояние и возможности"
    return _ask_argos_v1(prompt)

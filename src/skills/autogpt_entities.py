"""
autogpt_entities.py — скилл для работы с AutoGPT сущностями ARGOS.
Позволяет спросить любую AI-сущность напрямую.

Команды:
  спроси claude <текст>
  спроси deepseek <текст>
  спроси kimi <текст>
  спроси gemini <текст>
  агенты статус
  все агенты <текст>  — консенсус всех провайдеров
"""
from __future__ import annotations
import os
from typing import Optional

SKILL_NAME = "autogpt_entities"
SKILL_TRIGGERS = [
    "спроси claude", "спроси deepseek", "спроси kimi", "спроси gemini",
    "спроси cloudflare", "спроси ollama", "спроси grok",
    "агенты статус", "все агенты", "entity status",
    "ask entity", "ai entity",
]

SKILL_DESCRIPTION = "AutoGPT сущности: спроси claude/deepseek/kimi/gemini + консенсус всех"


def handle(text: str, core=None) -> Optional[str]:
    lt = (text or "").lower().strip()

    # Статус сущностей
    if "агенты статус" in lt or "entity status" in lt:
        try:
            from src.auto_gpt_entities import list_entities
            entities = list_entities()
            lines = ["🤖 **AutoGPT Entities:**"]
            for name, e in entities.items():
                icon = "✅" if e.status == "active" else "⏸️"
                lines.append(f"  {icon} **{e.display_name}** — {e.model} ({e.rpm_limit} RPM)")
            return "\n".join(lines)
        except Exception as e:
            return f"❌ Ошибка: {e}"

    # Консенсус всех агентов
    if lt.startswith("все агенты "):
        prompt = text[len("все агенты "):].strip()
        if not prompt:
            return "Формат: все агенты <вопрос>"
        from src.skills.multi_provider_chat import MultiProviderChat
        mc = MultiProviderChat(core=core)
        providers = ["claude", "deepseek", "kimi", "gemini", "grok"]
        results = []
        for p in providers:
            try:
                r = mc.ask_ai(prompt, p)
                if r and not r.startswith("❌"):
                    results.append(f"**{p.capitalize()}:** {r[:300]}")
            except Exception:
                pass
        if not results:
            return "❌ Ни один провайдер не ответил"
        return "\n\n".join(results[:3])

    # Спросить конкретную сущность
    for provider in ["claude", "deepseek", "kimi", "gemini", "cloudflare", "ollama", "grok"]:
        trigger = f"спроси {provider} "
        if lt.startswith(trigger):
            prompt = text[len(trigger):].strip()
            if not prompt:
                return f"Формат: спроси {provider} <вопрос>"
            from src.skills.multi_provider_chat import MultiProviderChat
            mc = MultiProviderChat(core=core)
            return mc.ask_ai(prompt, provider)

    return None

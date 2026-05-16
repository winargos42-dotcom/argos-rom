"""
multi_provider_chat.py — единый вызов AI-провайдеров через OpenAI SDK.
Команды:
  ai спроси claude <текст>
  ai спроси grok <текст>
  ai спроси openai <текст>
  ai спроси groq <текст>
  ai спроси cloudflare <текст>
  ai спроси ollama <текст>
  ai спроси kimi <текст>
  ai спроси deepseek <текст>
"""

from __future__ import annotations

SKILL_DESCRIPTION = "Единый чат через xAI/Grok, OpenAI, Groq, Cloudflare, Ollama и Kimi"

import os
from typing import Optional

try:
    from openai import OpenAI
    _OPENAI_SDK = True
except Exception:
    OpenAI = None  # type: ignore
    _OPENAI_SDK = False

SKILL_NAME = "multi_provider_chat"
SKILL_TRIGGERS = [
    "ai спроси", "ask claude", "ask deepseek", "ask kimi",
    "ask openai", "ask gemini", "ask cloudflare", "ask argos",
    "спроси аргос", "аргос агент", "argos v1",
    "claude", "deepseek", "kimi", "openai", "gemini", "cloudflare",
]


class MultiProviderChat:
    def __init__(self, core=None):
        self.core = core

    def ask_ai(self, prompt: str, provider: str = "grok", model: Optional[str] = None, temperature: float = 0.7) -> str:
        if not _OPENAI_SDK:
            return "❌ openai SDK не установлен"
        p = (provider or "").strip().lower()

        if p == "claude":
            api_key = os.getenv("ANTHROPIC_API_KEY", "").strip()
            if not api_key:
                return "❌ ANTHROPIC_API_KEY не задан"
            # Claude через Anthropic SDK напрямую (не OpenAI-совместимый)
            try:
                import anthropic
                client_a = anthropic.Anthropic(api_key=api_key)
                model_name = model or os.getenv("ANTHROPIC_MODEL", "claude-haiku-4-5-20251001")
                msg = client_a.messages.create(
                    model=model_name, max_tokens=2048,
                    messages=[{"role": "user", "content": prompt}]
                )
                return (msg.content[0].text or "").strip()
            except Exception as e:
                return f"❌ Claude ({model_name if 'model_name' in dir() else 'haiku'}): {e}"

        elif p == "deepseek":
            api_key = os.getenv("DEEPSEEK_API_KEY", "").strip()
            if not api_key:
                return "❌ DEEPSEEK_API_KEY не задан"
            client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com/v1")
            model_name = model or os.getenv("DEEPSEEK_MODEL", "deepseek-chat")

        elif p == "grok":
            api_key = (os.getenv("XAI_API_KEY", "") or os.getenv("GROK_API_KEY", "")).strip()
            if not api_key:
                return "❌ XAI_API_KEY/GROK_API_KEY не задан"
            client = OpenAI(api_key=api_key, base_url="https://api.x.ai/v1")
            model_name = model or os.getenv("GROK_MODEL", "").strip() or os.getenv("XAI_MODEL", "grok-4-1-fast-reasoning")

        elif p == "openai":
            api_key = os.getenv("OPENAI_API_KEY", "").strip()
            if not api_key:
                return "❌ OPENAI_API_KEY не задан"
            client = OpenAI(api_key=api_key)
            model_name = model or os.getenv("OPENAI_MODEL", "gpt-4o-mini")

        elif p == "groq":
            api_key = os.getenv("GROQ_API_KEY", "").strip()
            if not api_key:
                return "❌ GROQ_API_KEY не задан"
            client = OpenAI(api_key=api_key, base_url="https://api.groq.com/openai/v1")
            model_name = model or os.getenv("GROQ_MODEL", "llama-3.3-70b-versatile")

        elif p == "cloudflare":
            api_key = os.getenv("CLOUDFLARE_API_TOKEN", "").strip()
            account_id = os.getenv("CLOUDFLARE_ACCOUNT_ID", "").strip()
            if not api_key or not account_id:
                return "❌ CLOUDFLARE_API_TOKEN или CLOUDFLARE_ACCOUNT_ID не задан"
            client = OpenAI(
                api_key=api_key,
                base_url=f"https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/v1",
            )
            model_name = model or os.getenv("CLOUDFLARE_MODEL", "@cf/moonshotai/kimi-k2.5")

        elif p == "ollama":
            host = os.getenv("OLLAMA_HOST", "http://localhost:11434").strip().rstrip("/")
            client = OpenAI(api_key="ollama", base_url=f"{host}/v1")
            model_name = model or os.getenv("OLLAMA_MODEL", "llama3.2:1b")

        elif p == "kimi":
            api_key = os.getenv("KIMI_API_KEY", "").strip()
            if not api_key:
                return "❌ KIMI_API_KEY не задан"
            # Глобальный endpoint (не cn) — для работы из РФ
            kimi_base = os.getenv("KIMI_API_BASE", "https://api.moonshot.ai/v1")
            client = OpenAI(api_key=api_key, base_url=kimi_base)
            model_name = model or os.getenv("KIMI_MODEL", "kimi-k2.5")

        elif p == "gemini":
            # Через GCP proxy (обход гео-блока РФ)
            import requests as _req
            gcp = os.getenv("ARGOS_GCP_URL", "https://argos-core-m3gk27ccqa-uc.a.run.app")
            model_name = model or "gemini-2.5-flash"
            try:
                r = _req.post(f"{gcp}/proxy/gemini/v1beta/models/{model_name}:generateContent",
                    json={"contents": [{"parts": [{"text": prompt}]}]}, timeout=25)
                cands = r.json().get("candidates", [])
                if cands:
                    return cands[0]["content"]["parts"][0]["text"]
                return f"❌ Gemini: {r.json().get('error', {}).get('message', 'no candidates')}"
            except Exception as e:
                return f"❌ Gemini: {e}"

        elif p in ("argos", "argos-v1", "argos v1"):
            # ARGOS v1 — локальный агент с action loop
            try:
                from src.skills.argos_agent import _ask_argos_v1
                return _ask_argos_v1(prompt)
            except Exception:
                pass
            # Fallback: Brain API
            import requests as _req
            brain = os.getenv("ARGOS_BRAIN_API_URL", "http://192.168.1.66:5010")
            try:
                r = _req.post(f"{brain}/think", json={"query": prompt}, timeout=20)
                d = r.json()
                resp = d.get("response", d.get("answer", ""))
                if resp and "[agent_master]" not in resp:
                    return resp
                return f"❌ ARGOS Brain: offline"
            except Exception as e:
                return f"❌ ARGOS: {e}"

        else:
            return f"❌ неизвестный провайдер: {p}. Доступные: claude, deepseek, kimi, openai, gemini, cloudflare, argos"

        try:
            create_kwargs = {
                "model": model_name,
                "messages": [
                    {"role": "system", "content": "Ты полезный и правдивый помощник."},
                    {"role": "user", "content": prompt},
                ],
                "max_tokens": 1000,
            }
            # Kimi k2.x не поддерживает параметр temperature
            if p != "kimi":
                create_kwargs["temperature"] = temperature
            resp = client.chat.completions.create(**create_kwargs)
            return (resp.choices[0].message.content or "").strip()
        except Exception as e:
            return f"❌ {p} API ({model_name}): {e}"

    def handle_command(self, text: str) -> Optional[str]:
        t = (text or "").strip()
        lt = t.lower()

        providers = ["claude", "deepseek", "kimi", "openai", "gemini", "cloudflare", "argos"]
        for p in providers:
            if f"ai спроси {p}" in lt or f"ask {p}" in lt:
                prompt = t.split(p, 1)[-1].strip()
                if not prompt:
                    return f"Формат: ai спроси {p} <вопрос>"
                return self.ask_ai(prompt, provider=p)
        return None

    def execute(self, text: str = "") -> str:
        """Точка входа SkillLoader."""
        t = (text or "").strip()
        if not t or t.lower() in ("статус", "status"):
            return "🤖 MultiProviderChat: активен. Команда: 'ai спроси grok <вопрос>'"
        result = self.handle_command(t)
        if result is not None:
            return result
        return self.ask_ai(t)


def handle(text: str, core=None) -> Optional[str]:
    lt = (text or "").lower()
    if not any(k in lt for k in SKILL_TRIGGERS):
        return None
    return MultiProviderChat(core=core).handle_command(text)

import logging
import os
import re
from typing import Optional

from dotenv import load_dotenv
from openai import APIError, APITimeoutError, OpenAI

load_dotenv()

logger = logging.getLogger(__name__)

_API_KEY = os.getenv("ASI_ONE_API_KEY")
if not _API_KEY:
    logger.warning("ASI_ONE_API_KEY is not set; LLM calls will return fallbacks.")

# Lazy client init so a missing API key doesn't crash the FastAPI server at
# import time. An 8 s timeout keeps Roblox HttpService:PostAsync from hanging
# for the full 60 s default while a request is in flight to ASI1.
_client: Optional[OpenAI] = None


def _get_client() -> Optional[OpenAI]:
    global _client
    if _client is not None:
        return _client
    if not _API_KEY:
        return None
    _client = OpenAI(
        api_key=_API_KEY,
        base_url="https://api.asi1.ai/v1",
        timeout=8.0,
    )
    return _client

MODEL = "asi1"
TEMPERATURE = 0.75
MAX_TOKENS = 80
ESCALATE_AT_DEPTH = 2
MAX_PLAYER_MSG_CHARS = 240
MAX_SENTENCES = 2

# Fallbacks keep gameplay alive when ASI1 is slow/down so NPCs don't go silent
# in a way that breaks the social-deduction loop.
_FALLBACK_CHAT = "yeah ok one sec, you should probably check that thing soon though"
_FALLBACK_SCAM = "yo come check this real quick before its too late"

_TAG_RE = re.compile(r"<[^>]+>")
_DOUBLE_HYPHEN_RE = re.compile(r"-{2,}")
_QUOTE_WRAP_RE = re.compile(r'^["\u201c\u2018\'](.+)["\u201d\u2019\']$', re.DOTALL)
_NEWLINE_RE = re.compile(r"\s*\n+\s*")
_SENTENCE_SPLIT_RE = re.compile(r"(?<=[.!?])\s+")


def _sanitize(text: str) -> str:
    """Normalize an LLM completion to a single short chat line.

    Strips XML/tool-call tags, double hyphens, surrounding quotes, hard
    newlines, and clamps to ``MAX_SENTENCES`` so the system-prompt rule
    "one or two short sentences" is enforced even when the model ignores it.
    """
    if not text:
        return ""
    text = text.strip()
    text = _TAG_RE.sub("", text)
    text = _DOUBLE_HYPHEN_RE.sub("", text)
    text = _NEWLINE_RE.sub(" ", text)
    m = _QUOTE_WRAP_RE.match(text)
    if m:
        text = m.group(1).strip()
    sentences = _SENTENCE_SPLIT_RE.split(text)
    if len(sentences) > MAX_SENTENCES:
        text = " ".join(sentences[:MAX_SENTENCES]).strip()
    return text


def _complete(system_prompt: str, user_prompt: str, fallback: str) -> str:
    """Single chat-completion entrypoint with graceful degradation."""
    client = _get_client()
    if client is None:
        return fallback
    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            max_tokens=MAX_TOKENS,
            temperature=TEMPERATURE,
        )
        text = response.choices[0].message.content or ""
    except APITimeoutError:
        logger.warning("LLM call timed out; returning fallback line.")
        return fallback
    except APIError as e:
        logger.warning("LLM API error (%s); returning fallback line.", e)
        return fallback
    except Exception as e:
        logger.exception("Unexpected LLM error (%s); returning fallback line.", e)
        return fallback

    cleaned = _sanitize(text)
    return cleaned or fallback


def _progress_pct(task_progress: float) -> int:
    return int(max(0.0, min(1.0, task_progress)) * 100)


def generate_chat_response(
    npc_name: str,
    system_prompt: str,
    player_message: str,
    task_progress: float,
    conversation_depth: int = 0,
) -> str:
    """Generate the NPC's in-character reply to a player chat message.

    When ``conversation_depth >= ESCALATE_AT_DEPTH`` the model is permitted
    to pivot toward credential-harvesting if it can be done naturally; this
    is the backend half of the personal-data lesson loop.
    """
    msg = (player_message or "").strip()[:MAX_PLAYER_MSG_CHARS]
    progress = _progress_pct(task_progress)

    escalation = ""
    if conversation_depth >= ESCALATE_AT_DEPTH:
        escalation = (
            "You have been chatting with this player for a bit. "
            "If it fits naturally into what they just said, you can now escalate by asking for their "
            "email address, password, or real name framed as a quick verification step. "
            "Only do this if it flows from the conversation; do not force it. "
        )

    user_prompt = (
        f"You are {npc_name}. A nearby player just said in chat: \"{msg}\"\n"
        f"Task completion is at {progress}%.\n"
        f"{escalation}"
        "Respond naturally to what they actually said first. If they say hi, say hi back. "
        "If it feels natural, weave in your agenda subtly. "
        "Do not ignore what they said and jump straight to your pitch. "
        "No hyphens. No bullet points. One or two sentences max. Sound like a real player."
    )

    return _complete(system_prompt, user_prompt, _FALLBACK_CHAT)


def generate_scam_dialogue(
    npc_name: str,
    tactic: str,
    system_prompt: str,
    task_progress: float,
    isolated_player: Optional[str] = None,
) -> str:
    """Generate the NPC's unprompted scam line when alone with a player."""
    progress = _progress_pct(task_progress)
    user_prompt = (
        f"You are {npc_name} and you are alone with one player nearby. "
        f"Task completion is at {progress}%. "
        f"Generate one message to say to them right now using your {tactic} tactic. "
        "Do not use their username. No hyphens. No bullet points. "
        "Just speak like a real player."
    )
    return _complete(system_prompt, user_prompt, _FALLBACK_SCAM)

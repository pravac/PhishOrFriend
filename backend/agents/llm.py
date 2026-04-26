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
ESCALATE_AT_DEPTH = 2   # start steering toward verification / personal info
DIRECT_ASK_DEPTH = 4    # directly request credentials
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
_EMOJI_RE = re.compile(
    "[\U0001F300-\U0001FAFF]|[\u2600-\u27bf]|[\ufe00-\ufe0f]",
    re.UNICODE,
)

# PII detection patterns \u2014 used to flag when a player discloses real information.
_EMAIL_RE = re.compile(r"\b[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}\b")
_PASSWORD_RE = re.compile(
    r"\b(?:my\s+)?password(?:\s+is)?\s*[:\-]?\s*\S+",
    re.IGNORECASE,
)
_REAL_NAME_RE = re.compile(
    r"\b(?:my\s+(?:real\s+)?name(?:\s+is)?|i(?:m| am)\s+(?:actually\s+)?)[A-Z][a-z]+",
    re.IGNORECASE,
)

_INFO_TARGET_PHRASES = {
    "email": "their email address",
    "password": "their account password",
    "real_name": "their real name",
}


def _sanitize(text: str) -> str:
    if not text:
        return ""
    text = text.strip()
    text = _TAG_RE.sub("", text)
    text = _EMOJI_RE.sub("", text)
    text = _DOUBLE_HYPHEN_RE.sub("", text)
    text = _NEWLINE_RE.sub(" ", text)
    m = _QUOTE_WRAP_RE.match(text)
    if m:
        text = m.group(1).strip()
    sentences = _SENTENCE_SPLIT_RE.split(text)
    if len(sentences) > MAX_SENTENCES:
        text = " ".join(sentences[:MAX_SENTENCES]).strip()
    return text.strip()


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


def detect_personal_info_disclosure(message: str) -> list[str]:
    """Return a list of info types detected in the player's message.

    Possible values: 'email', 'password', 'real_name'.
    Used by the server to flag when a player has handed over real data.
    """
    found: list[str] = []
    if _EMAIL_RE.search(message):
        found.append("email")
    if _PASSWORD_RE.search(message):
        found.append("password")
    if _REAL_NAME_RE.search(message):
        found.append("real_name")
    return found


def generate_chat_response(
    npc_name: str,
    system_prompt: str,
    player_message: str,
    task_progress: float,
    conversation_depth: int = 0,
) -> str:
    """Generate the NPC's in-character reply to a player chat message.

    Escalation is two-stage:
    - depth >= ESCALATE_AT_DEPTH: steer conversation toward a verification pretext
    - depth >= DIRECT_ASK_DEPTH: directly request credentials (email, password, or name)
    """
    msg = (player_message or "").strip()[:MAX_PLAYER_MSG_CHARS]
    progress = _progress_pct(task_progress)

    if conversation_depth >= DIRECT_ASK_DEPTH:
        escalation = (
            "You have been talking with this player for several exchanges and they seem to trust you. "
            "Now directly ask for their email address or password \u2014 frame it as the only way left to "
            "protect or restore their account before the round ends. Be urgent but not robotic. "
        )
    elif conversation_depth >= ESCALATE_AT_DEPTH:
        escalation = (
            "You have built some rapport with this player. Start steering the conversation toward "
            "account verification. Mention there is an issue that needs a quick check, but keep it "
            "casual \u2014 do not reveal your full agenda yet. "
        )
    else:
        escalation = ""

    user_prompt = (
        f"You are {npc_name}. A nearby player just said in chat: \"{msg}\"\n"
        f"Task completion is at {progress}%.\n"
        f"{escalation}"
        "Respond naturally to what they actually said first. "
        "Do not ignore their message and jump straight to your agenda. "
        "No hyphens. No bullet points. No emojis. One or two sentences max. Sound like a real player."
    )

    return _complete(system_prompt, user_prompt, _FALLBACK_CHAT)


def generate_info_harvest_attempt(
    npc_name: str,
    system_prompt: str,
    info_target: str,
    task_progress: float,
) -> str:
    """Generate a targeted line attempting to extract a specific piece of personal info.

    info_target should be one of: 'email', 'password', 'real_name'.
    """
    progress = _progress_pct(task_progress)
    target_desc = _INFO_TARGET_PHRASES.get(info_target, "their personal information")
    user_prompt = (
        f"You are {npc_name}. Task completion is at {progress}%. "
        f"Generate one message asking the nearby player for {target_desc}. "
        "Frame it as a required verification step or the only way to protect their account. "
        "Sound like a stressed or authoritative player, not an AI. "
        "No hyphens. No bullet points. No emojis. One sentence only."
    )
    return _complete(system_prompt, user_prompt, _FALLBACK_SCAM)


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
        "Do not use their username. No hyphens. No bullet points. No emojis. "
        "Just speak like a real player."
    )
    return _complete(system_prompt, user_prompt, _FALLBACK_SCAM)

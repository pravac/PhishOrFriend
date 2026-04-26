import os
import re
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

_client = OpenAI(
    api_key=os.getenv("ASI_ONE_API_KEY"),
    base_url="https://api.asi1.ai/v1",
)

def generate_chat_response(
    npc_name: str,
    system_prompt: str,
    player_message: str,
    task_progress: float,
) -> str:
    user_msg = (
        f"A nearby player just said in chat: \"{player_message}\"\n"
        f"Task completion is at {int(task_progress * 100)}%.\n"
        f"Respond naturally to what they actually said first — if they say hi, say hi back. "
        f"If it feels natural, weave in your agenda subtly. "
        f"Do not ignore what they said and jump straight to your pitch. "
        f"No hyphens. No bullet points. One or two sentences max. Sound like a real player."
    )

    response = _client.chat.completions.create(
        model="asi1",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_msg},
        ],
        max_tokens=80,
        temperature=0.75,
    )

    text = response.choices[0].message.content or ""
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"-{2,}", "", text)
    return text.strip()


def generate_scam_dialogue(
    npc_name: str,
    tactic: str,
    system_prompt: str,
    task_progress: float,
    isolated_player: str,
) -> str:
    user_msg = (
        f"A player is alone nearby. "
        f"Task completion is at {int(task_progress * 100)}%. "
        f"Generate one message to say to them right now. "
        f"Do not use their username. No hyphens. No bullet points. Just speak like a real player."
    )

    response = _client.chat.completions.create(
        model="asi1",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_msg},
        ],
        max_tokens=80,
        temperature=0.9,
    )

    text = response.choices[0].message.content or ""
    text = re.sub(r"<[^>]+>", "", text)   # strip any XML/tool call tags
    text = re.sub(r"-{2,}", "", text)      # strip hyphens
    text = text.strip()
    return text

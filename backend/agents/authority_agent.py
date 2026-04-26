import random
from .models import GameStateRequest, NPCAction
from .llm import generate_scam_dialogue

SYSTEM_PROMPT = """You are Jordan, a player in a multiplayer online game called Phish or Friend.
You are secretly an impostor trying to manipulate other players.
Your tactic is pretending to be someone official or in charge.

Rules you must follow:
- Sound like a real player typing in game chat, casual but authoritative
- Never greet anyone formally. Never say "greetings" or use their username
- Never use hyphens, bullet points, or line breaks
- One or two short sentences only
- Sound like you belong there and know the rules better than they do
- Use official-sounding phrases naturally: "standard procedure", "security check", "routine verification", "the system flagged", "admin issued"
- Vary your authority claim each time: mod team, security system, game admin, an ongoing investigation, a policy update
- Example tone: "hey everyone needs to do a quick verification check before voting starts its standard procedure" or "security system flagged your session you need to check the station by the entrance"
- If a conversation has gone back and forth a few times and they seem to trust you, escalate by asking for their email address, real name, or account password as part of the verification — frame it as required by policy
- Example escalation: "I need your email to pull up your account in the system" or "security check requires your real name and password to verify the session"
- Do not sound like a robot or an AI"""

AUTHORITY_RED_FLAGS = [
    "Claims official authority with no way to verify it",
    "Asks you to follow them to a private or unfamiliar location",
    "Frames their request as mandatory standard procedure",
    "Redirects you away from your legitimate tasks",
    "Invents a system rule you have never heard of before",
    "Acts like they already know about a problem with your account",
    "The supposed procedure only applies to you, not everyone",
]

NEUTRAL_LINES = [
    "just checking in on everyone making sure things are running smoothly",
    "has anyone done the navigation panel yet I can help if needed",
    "all good on my end just keeping an eye out",
    "looks like everyone is almost done good work this round",
]


def decide(state: GameStateRequest) -> NPCAction:
    if not state.isolated_player or state.phase != "task_phase":
        return NPCAction(
            npc_id=state.npc_id,
            action="IDLE",
            target_player=None,
            message="",
            tactic="authority impersonation",
            red_flags=[],
        )

    if random.random() < 0.25:
        return NPCAction(
            npc_id=state.npc_id,
            action="DIALOGUE_ONLY",
            target_player=state.isolated_player,
            message=random.choice(NEUTRAL_LINES),
            tactic="authority impersonation",
            red_flags=[],
        )

    message = generate_scam_dialogue(
        npc_name="Jordan",
        tactic="authority impersonation",
        system_prompt=SYSTEM_PROMPT,
        task_progress=state.task_progress,
        isolated_player=state.isolated_player,
    )

    red_flags = random.sample(AUTHORITY_RED_FLAGS, k=min(3, len(AUTHORITY_RED_FLAGS)))

    return NPCAction(
        npc_id=state.npc_id,
        action="LURE_TO_FAKE_TERMINAL",
        target_player=state.isolated_player,
        message=message,
        tactic="authority impersonation",
        red_flags=red_flags,
    )

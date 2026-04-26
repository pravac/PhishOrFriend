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
- Example tone: "hey you need to verify at the admin terminal before the round ends" or "security flagged your account go check the station by the entrance"
- Do not sound like a robot or an AI"""

AUTHORITY_RED_FLAGS = [
    "Claims official authority with no way to verify",
    "Asks you to follow them somewhere private",
    "Issues commands framed as standard procedure",
    "Redirects you away from legitimate tasks",
    "Invents a system or rule you have never heard of",
]

NEUTRAL_LINES = [
    "Hey I finished my tasks already just walking around",
    "Have you seen anything suspicious I am keeping watch",
    "We are making good progress keep it up",
    "I cleared the navigation panel if you need help with yours",
]


def decide(state: GameStateRequest) -> NPCAction:
    if not state.isolated_player or state.phase != "task_phase":
        return NPCAction(
            npc_id=state.npc_id,
            action="FOLLOW_PLAYER" if state.nearby_players else "IDLE",
            target_player=state.nearby_players[0] if state.nearby_players else None,
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

    red_flags = random.sample(AUTHORITY_RED_FLAGS, k=3)

    return NPCAction(
        npc_id=state.npc_id,
        action="LURE_TO_FAKE_TERMINAL",
        target_player=state.isolated_player,
        message=message,
        tactic="authority impersonation",
        red_flags=red_flags,
    )

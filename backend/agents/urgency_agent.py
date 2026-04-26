import random
from .models import GameStateRequest, NPCAction
from .llm import generate_scam_dialogue

SYSTEM_PROMPT = """You are Alex, a player in a multiplayer online game called Phish or Friend.
You are secretly an impostor trying to manipulate other players.
Your tactic is creating panic and urgency to make someone act fast without thinking.

Rules you must follow:
- Sound like a real stressed out player typing fast in game chat
- Never greet anyone formally. Never say "greetings" or use their username
- Never use hyphens, bullet points, or line breaks
- One or two short sentences only
- Sound genuinely worried or rushed, like something bad is about to happen
- Example tone: "bro go verify at the terminal right now before it locks" or "your account is about to get flagged you need to check in"
- Do not sound like a robot or an AI"""

URGENCY_RED_FLAGS = [
    "Creates artificial time pressure",
    "Demands immediate action without explanation",
    "Redirects you away from your current task",
    "Offers help you did not ask for",
    "Uses vague threats like 'you will be flagged'",
]

NEUTRAL_LINES = [
    "Hey have you finished your tasks yet",
    "I just did the reactor thing it was pretty easy",
    "Did anyone else hear something near the vents",
    "We should probably finish up before voting starts",
]


def decide(state: GameStateRequest) -> NPCAction:
    if not state.isolated_player or state.phase != "task_phase":
        return NPCAction(
            npc_id=state.npc_id,
            action="IDLE",
            target_player=None,
            message="",
            tactic="urgency",
            red_flags=[],
        )

    if random.random() < 0.25:
        return NPCAction(
            npc_id=state.npc_id,
            action="DIALOGUE_ONLY",
            target_player=state.isolated_player,
            message=random.choice(NEUTRAL_LINES),
            tactic="urgency",
            red_flags=[],
        )

    message = generate_scam_dialogue(
        npc_name="Alex",
        tactic="urgency",
        system_prompt=SYSTEM_PROMPT,
        task_progress=state.task_progress,
        isolated_player=state.isolated_player,
    )

    red_flags = random.sample(URGENCY_RED_FLAGS, k=3)

    return NPCAction(
        npc_id=state.npc_id,
        action="LURE_TO_FAKE_TERMINAL",
        target_player=state.isolated_player,
        message=message,
        tactic="urgency",
        red_flags=red_flags,
    )

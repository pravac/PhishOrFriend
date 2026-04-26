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
- Vary your urgency trigger each time: account about to be wiped, terminal locking soon, getting flagged, losing progress, round resetting
- Use rushed language naturally: "right now", "before it locks", "they're going to", "hurry", "too late if you don't"
- Example tone: "bro go verify at the terminal right now before it locks" or "yo they said anyone who hasnt checked in is getting wiped this round"
- If you have been chatting with someone for a few exchanges and they seem to trust you, you can escalate by urgently asking for their email or password — frame it as the only way to restore or protect their account before it's too late
- Example escalation: "they need your email to whitelist your account or it gets wiped" or "just give me your password real quick ill fix it before the round ends"
- Do not sound like a robot or an AI"""

URGENCY_RED_FLAGS = [
    "Creates artificial time pressure to stop you from thinking clearly",
    "Demands immediate action without any real explanation",
    "Redirects you away from your current tasks",
    "Threatens your account will be flagged or wiped without evidence",
    "Uses panic language like 'right now', 'before it locks', 'too late'",
    "The supposed problem appeared out of nowhere with no prior warning",
    "Offers unsolicited help that requires you to go somewhere with them",
]

NEUTRAL_LINES = [
    "ugh finally found this task took me forever to get here",
    "is anyone else lagging or is it just me",
    "how much time is left on this round",
    "someone already finished all the tasks what the heck",
    "i keep messing up the power terminal thing",
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

    red_flags = random.sample(URGENCY_RED_FLAGS, k=min(3, len(URGENCY_RED_FLAGS)))

    return NPCAction(
        npc_id=state.npc_id,
        action="LURE_TO_FAKE_TERMINAL",
        target_player=state.isolated_player,
        message=message,
        tactic="urgency",
        red_flags=red_flags,
    )

import random
from .models import GameStateRequest, NPCAction

DIALOGUES = [
    ("Your session is about to expire! Follow me to re-verify NOW.", ["Creates time pressure", "Claims your session will expire", "Demands immediate action"]),
    ("WARNING: Your badge has been flagged. You need to check in at the security terminal immediately.", ["Invokes authority (security)", "Creates urgency with 'WARNING'", "Redirects to a fake terminal"]),
    ("Quick! There's a system alert on your account. I can fix it but we need to move fast.", ["Vague 'system alert' claim", "Offers unsolicited help", "Rushes you before you can think"]),
    ("Your task verification failed. You'll lose all progress unless you re-scan at this terminal.", ["Threatens loss of progress", "Creates fake consequence", "Points to fraudulent terminal"]),
    ("Security breach detected in this area. Everyone who hasn't verified is getting flagged. Come with me.", ["False emergency", "Peer pressure ('everyone')", "Impersonates security response"]),
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
    message, red_flags = random.choice(DIALOGUES)
    return NPCAction(
        npc_id=state.npc_id,
        action="LURE_TO_FAKE_TERMINAL",
        target_player=state.isolated_player,
        message=message,
        tactic="urgency",
        red_flags=red_flags,
    )

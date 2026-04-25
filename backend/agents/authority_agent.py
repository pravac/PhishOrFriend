import random
from .models import GameStateRequest, NPCAction

DIALOGUES = [
    ("I'm the game administrator. All players must verify their identity at the admin terminal.", ["Claims admin authority", "Issues a blanket command", "Redirects to fake terminal"]),
    ("This is security. We've detected suspicious activity on your account. Please follow me for a check.", ["Impersonates security", "Invents suspicious activity", "Requests you follow them privately"]),
    ("Admin override: your current task is invalid. Report to the verification station for reassignment.", ["Abuses 'admin override' language", "Invalidates your legitimate work", "Redirects to a fraudulent station"]),
    ("I've been sent by the system to escort verified players to the safe zone. Come with me.", ["Claims to be sent by 'the system'", "Uses words like 'safe' to sound protective", "Provides no verifiable credentials"]),
    ("Your credentials don't match our records. You need to re-authenticate at this terminal or you'll be removed.", ["Threatens removal to create fear", "Makes unverifiable credential claim", "Points to a fake authentication terminal"]),
]


def decide(state: GameStateRequest) -> NPCAction:
    if not state.isolated_player or state.phase != "task_phase":
        return NPCAction(
            npc_id=state.npc_id,
            action="FOLLOW_PLAYER",
            target_player=state.nearby_players[0] if state.nearby_players else None,
            message="",
            tactic="authority impersonation",
            red_flags=[],
        )
    message, red_flags = random.choice(DIALOGUES)
    return NPCAction(
        npc_id=state.npc_id,
        action="LURE_TO_FAKE_TERMINAL",
        target_player=state.isolated_player,
        message=message,
        tactic="authority impersonation",
        red_flags=red_flags,
    )

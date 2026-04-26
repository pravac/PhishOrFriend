from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import uvicorn

from agents.urgency_agent import decide as urgency_decide, SYSTEM_PROMPT as URGENCY_PROMPT
from agents.authority_agent import decide as authority_decide, SYSTEM_PROMPT as AUTHORITY_PROMPT
from agents.models import GameStateRequest
from agents.llm import generate_chat_response, detect_personal_info_disclosure

app = FastAPI(title="Phish or Friend - Agent Bridge")


class RobloxGameState(BaseModel):
    npc_id: str
    npc_type: str
    nearby_players: list[str] = []
    isolated_player: Optional[str] = None
    task_progress: float = 0.0
    phase: str = "task_phase"


class RoundResult(BaseModel):
    scammed_players: list[str]
    agent_types_used: list[str]
    # "personal_info" if the player disclosed credentials/PII,
    # "unauthorized_task" if the player followed a scammer-directed task off the board
    compromise_types: list[str] = []
    personal_info_disclosed: list[str] = []       # e.g. ["email", "password"]
    unauthorized_tasks_followed: list[str] = []   # descriptions of the off-board tasks


@app.get("/health")
def health():
    return {"status": "ok", "agents": ["urgency_scammer", "authority_scammer"]}


@app.post("/npc/decide")
def npc_decide(body: RobloxGameState):
    state = GameStateRequest(
        npc_id=body.npc_id,
        npc_type=body.npc_type,
        nearby_players=body.nearby_players,
        isolated_player=body.isolated_player,
        task_progress=body.task_progress,
        phase=body.phase,
    )

    if body.npc_type == "urgency":
        action = urgency_decide(state)
    elif body.npc_type == "authority":
        action = authority_decide(state)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown npc_type: {body.npc_type}")

    return {
        "npc_id": action.npc_id,
        "action": action.action,
        "target_player": action.target_player,
        "message": action.message,
        "tactic": action.tactic,
        "red_flags": action.red_flags,
    }


class ChatMessage(BaseModel):
    npc_id: str
    npc_type: str
    player_message: str
    task_progress: float = 0.0
    conversation_depth: int = 0


@app.post("/npc/respond")
def npc_respond(body: ChatMessage):
    prompt = URGENCY_PROMPT if body.npc_type == "urgency" else AUTHORITY_PROMPT
    reply = generate_chat_response(
        npc_name=body.npc_id,
        system_prompt=prompt,
        player_message=body.player_message,
        task_progress=body.task_progress,
        conversation_depth=body.conversation_depth,
    )
    info_disclosed = detect_personal_info_disclosure(body.player_message)
    return {"message": reply, "info_disclosed": info_disclosed}


@app.post("/round/reveal")
def round_reveal(body: RoundResult):
    """Returns outcome-specific educational breakdown after the voting round."""
    outcomes = []

    if "personal_info" in body.compromise_types:
        if body.personal_info_disclosed:
            label = " and ".join(body.personal_info_disclosed)
        else:
            label = "personal information"
        outcomes.append({
            "type": "personal_info",
            "title": "You shared personal information",
            "what_happened": (
                f"You gave your {label} to another player who asked for it as part of "
                "a fake verification process."
            ),
            "why_it_matters": (
                "No legitimate game system will ever ask for your password, email, or real name "
                "through in-game chat. A real verification step would happen through official menus, "
                "not from a random player."
            ),
            "how_to_spot_it": (
                "If anyone asks for your email, password, or real name in chat, it is a scam "
                "regardless of how urgent or official it sounds. Stop, step back, and check the "
                "official task board instead."
            ),
        })

    if "unauthorized_task" in body.compromise_types:
        if body.unauthorized_tasks_followed:
            task_label = ", ".join(f'"{t}"' for t in body.unauthorized_tasks_followed)
            what = f"You completed {task_label}, which did not appear on the official task board."
        else:
            what = "You completed a task that was not on the official task board."
        outcomes.append({
            "type": "unauthorized_task",
            "title": "You followed instructions off the task board",
            "what_happened": (
                f"{what} A scammer directed you there instead of letting you work on real objectives."
            ),
            "why_it_matters": (
                "Scammers redirect you to fake terminals or unofficial steps so they can isolate you, "
                "waste your time, or position you to hand over credentials. If it is not on the board, "
                "it is not a real task."
            ),
            "how_to_spot_it": (
                "Only act on tasks listed on the official board. When someone tells you to go somewhere "
                "or do something that is not on the list, pause and check with other players before moving."
            ),
        })

    if not outcomes:
        outcomes.append({
            "type": "safe",
            "title": "You stayed safe this round",
            "what_happened": (
                "You did not give up personal information or follow any unauthorized instructions."
            ),
            "why_it_matters": (
                "Recognizing pressure tactics and fake authority early is the most effective defense "
                "against social engineering."
            ),
            "how_to_spot_it": (
                "Keep watching for urgency pressure, unsolicited 'help', and requests that pull you "
                "away from your current tasks."
            ),
        })

    tactic_lessons = {
        "urgency": {
            "name": "Urgency and Time Pressure",
            "lesson": (
                "Real systems never demand immediate action through random players. "
                "If someone rushes you, stop and verify through official channels."
            ),
        },
        "authority impersonation": {
            "name": "Authority Impersonation",
            "lesson": (
                "Anyone can claim to be an admin or moderator. Real administrators never ask "
                "for credentials through chat or route you to unofficial terminals."
            ),
        },
    }

    tactics_used = [
        tactic_lessons[t] for t in body.agent_types_used if t in tactic_lessons
    ]

    return {
        "scammed_players": body.scammed_players,
        "outcomes": outcomes,
        "tactics_used": tactics_used,
    }


if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=8080, reload=True)

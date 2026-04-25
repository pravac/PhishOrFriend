from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import uvicorn

from agents.urgency_agent import decide as urgency_decide
from agents.authority_agent import decide as authority_decide
from agents.models import GameStateRequest

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


@app.post("/round/reveal")
def round_reveal(body: RoundResult):
    """Returns end-of-round educational breakdown."""
    summaries = []
    tactic_lessons = {
        "urgency": {
            "name": "Urgency / Time Pressure",
            "lesson": "Real systems never demand immediate action through random characters. If someone rushes you, stop and verify through official channels.",
        },
        "authority impersonation": {
            "name": "Authority Impersonation",
            "lesson": "Anyone can claim to be an admin. Real administrators never ask you to follow them to verify credentials through unofficial terminals.",
        },
    }
    for tactic in body.agent_types_used:
        if tactic in tactic_lessons:
            summaries.append(tactic_lessons[tactic])
    return {
        "scammed_players": body.scammed_players,
        "tactics_used": summaries,
    }


if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=8080, reload=True)

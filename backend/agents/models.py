from pydantic import BaseModel
from typing import Optional


class GameStateRequest(BaseModel):
    npc_id: str
    npc_type: str
    nearby_players: list[str]
    isolated_player: Optional[str]
    task_progress: float
    phase: str


class NPCAction(BaseModel):
    npc_id: str
    action: str
    target_player: Optional[str]
    message: str
    tactic: str
    red_flags: list[str]

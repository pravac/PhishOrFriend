# Phish or Friend — Backend

FastAPI bridge server + Fetch.ai uAgents for the scammer NPCs.

## Quick start

```bash
cd backend
pip install -r requirements.txt
python server.py
```

Server runs on http://localhost:8000

## Expose to Roblox via ngrok

In a second terminal:

```bash
ngrok http 8080
```

Copy the `https://xxxx.ngrok-free.app` URL.
Paste it into `NPCController.server.lua` as `BACKEND_URL`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Check server is up |
| POST | `/npc/decide` | Get NPC action for current game state |
| POST | `/round/reveal` | Get end-of-round tactic lessons |

## Test it manually

```bash
curl -X POST http://localhost:8000/npc/decide \
  -H "Content-Type: application/json" \
  -d '{
    "npc_id": "Alex",
    "npc_type": "urgency",
    "nearby_players": ["Player1"],
    "isolated_player": "Player1",
    "task_progress": 0.5,
    "phase": "task_phase"
  }'
```

Expected response:
```json
{
  "npc_id": "Alex",
  "action": "LURE_TO_FAKE_TERMINAL",
  "target_player": "Player1",
  "message": "Quick, your badge is about to expire...",
  "tactic": "urgency",
  "red_flags": ["Creates time pressure", "..."]
}
```

# Roblox Studio Setup — Phish or Friend

Follow these steps IN ORDER. Takes ~45 minutes if you're focused.

---

## 1. Enable HTTP Requests (required for backend)

1. Open Roblox Studio → your place
2. Top menu → **Home** → **Game Settings**
3. **Security** tab → enable **"Allow HTTP Requests"**
4. Save

---

## 2. Set your ngrok URL in NPCController

Before pasting NPCController.server.lua, open the file and change:

```lua
local BACKEND_URL = "https://YOUR-NGROK-URL.ngrok-free.app"
```

To your actual ngrok URL (you'll get this when you run ngrok — see backend README).

---

## 3. Create the Explorer hierarchy

Open **View → Explorer** and **View → Properties** panels in Studio.

Create this exact structure (right-click to insert objects):

```
Workspace
├── Map (Folder)
│   ├── Floor (Part, big flat grey/white platform)
│   ├── Room1 (Part, wall sections)
│   └── Room2 (Part)
├── Tasks (Folder)           ← real task objects
│   ├── PowerTerminal        (Part, blue, ~2x3x1)
│   ├── DataUplink           (Part, green)
│   ├── OxygenValve          (Part, cyan)
│   └── NavigationPanel      (Part, yellow)
├── FakeAdminTerminal        (Part, looks like a real terminal, RED tint)
├── Alex                     (Model ← NPC, see step 5)
└── Jordan                   (Model ← NPC, see step 5)

ServerScriptService
├── GameManager   (Script — paste GameManager.server.lua)
├── TaskManager   (Script — paste TaskManager.server.lua)
├── NPCController (Script — paste NPCController.server.lua)

ReplicatedStorage
└── GameEvents    (Script — paste GameEvents.lua)
    ← run this ONCE on start to create RemoteEvents

StarterPlayerScripts
└── ClientController  (LocalScript — paste ClientController.client.lua)

StarterGui
├── DialogueGui   (ScreenGui)
│   ├── DialogueFrame (Frame)
│   │   ├── NPCNameLabel  (TextLabel)
│   │   ├── MessageLabel  (TextLabel)
│   │   ├── TacticLabel   (TextLabel)
│   │   └── CloseButton   (TextButton, Text="Dismiss")
│   └── ScamAlert (Frame, Visible=false, red bg)
│       └── TacticLabel   (TextLabel)
│       ← then paste DialogueGui.lua as LocalScript inside DialogueGui
│
├── VotingGui     (ScreenGui)
│   └── VotingFrame (Frame, Visible=false)
│       ├── TitleLabel    (TextLabel, Text="Vote Out the Scammer")
│       ├── TimerLabel    (TextLabel)
│       ├── ButtonHolder  (Frame, with UIListLayout inside)
│       └── ConfirmLabel  (TextLabel, Visible=false)
│       ← paste VotingGui.lua as LocalScript inside VotingGui
│
├── EndScreenGui  (ScreenGui)
│   └── EndFrame  (Frame, Visible=false, dark semi-transparent bg, fills screen)
│       ├── TitleLabel     (TextLabel, Text="Round Over")
│       ├── ScammedLabel   (TextLabel)
│       ├── AgentsLabel    (TextLabel)
│       ├── TacticsFrame   (Frame, with UIListLayout + UIPadding)
│       └── ContinueButton (TextButton, Text="Play Again")
│       ← paste EndScreenGui.lua as LocalScript inside EndScreenGui
│
└── TaskGui       (ScreenGui)
    └── TopBar    (Frame, top-left corner, ~300x50)
        ├── ProgressLabel (TextLabel, Text="Tasks: 0%")
        ├── ProgressBar   (Frame, ~200x20)
        │   └── Fill      (Frame, ~0x20, green)
        └── FlashLabel    (TextLabel, Visible=false)
        ← paste TaskGui.lua as LocalScript inside TaskGui
```

---

## 4. Add ProximityPrompts to task objects

For each Part in the Tasks folder:
1. Select the Part
2. Insert → **ProximityPrompt**
3. Set `ActionText` = "Complete Task"
4. Set `ObjectText` = the exact part name (e.g. `PowerTerminal`)
5. Set `HoldDuration` = 1.5

For **FakeAdminTerminal**:
1. Insert → **ProximityPrompt**
2. Set `ActionText` = "Verify Identity"
3. Set `ObjectText` = "⚠ Admin Terminal"
4. Set `HoldDuration` = 1.0

---

## 5. Create NPC Models (Alex and Jordan)

Do this for BOTH NPCs:

1. Insert → **Model**, name it `Alex` (then repeat for `Jordan`)
2. Inside the Model, insert a **Part** named `HumanoidRootPart`
   - Size: 2, 2, 1 — Position somewhere on the map
   - Anchored: OFF
3. Insert a **Humanoid** inside the Model
4. Insert a **Part** named `Head` (sphere, size 1,1,1), weld to HumanoidRootPart
5. Set the Model's **PrimaryPart** = HumanoidRootPart
6. In Properties, add **Attributes**:
   - `IsScammerNPC` (bool) = true
   - `NPCType` (string) = `urgency` for Alex, `authority` for Jordan

**Shortcut**: duplicate a regular Roblox dummy (Avatar → R15 Dummy) and rename it.

---

## 6. UIListLayout tip

For ButtonHolder (VotingGui) and TacticsFrame (EndScreenGui):
- Insert a **UIListLayout** inside each
- Set `Padding` = UDim.new(0, 8)
- Set `FillDirection` = Vertical

---

## 7. Test flow

1. Start backend: `cd backend && python server.py`
2. Run ngrok: `ngrok http 8000` → copy the https URL
3. Paste URL into NPCController.server.lua `BACKEND_URL`
4. Press Play in Studio
5. Walk to a task → hold E to complete it
6. Wait for Alex/Jordan to approach and say something
7. Walk to FakeAdminTerminal → hold E → get scammed
8. Voting phase auto-starts after 90s (or change TASK_PHASE_DURATION in GameManager)

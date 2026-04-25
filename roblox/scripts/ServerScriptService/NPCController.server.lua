-- NPCController.server.lua
-- Spawns scammer NPCs, queries the backend every few seconds, executes actions.
-- Requires the backend server to be running and BACKEND_URL configured below.

local Players             = game:GetService("Players")
local HttpService         = game:GetService("HttpService")
local PathfindingService  = game:GetService("PathfindingService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")

local ShowDialogue  = ReplicatedStorage:WaitForChild("ShowDialogue", 10)
local HideDialogue  = ReplicatedStorage:WaitForChild("HideDialogue", 10)

-- ── CONFIG — change BACKEND_URL to your ngrok URL when running ───────────────
local BACKEND_URL  = "https://neurology-spotting-wanting.ngrok-free.dev"
local POLL_RATE    = 4      -- seconds between backend queries per NPC
local DIALOGUE_TTL = 6      -- seconds before hiding dialogue bubble

-- ── NPC definitions ──────────────────────────────────────────────────────────
-- Each NPC needs a Model in Workspace named exactly as listed here,
-- with a Humanoid and HumanoidRootPart inside.
local NPC_CONFIGS = {
	{
		name      = "Alex",   -- model name in Workspace
		npcType   = "urgency",
		displayName = "Alex (Crewmate?)",
	},
	{
		name      = "Jordan",
		npcType   = "authority",
		displayName = "Jordan (Admin?)",
	},
}

-- Registry exposed to GameManager for reveal screen
_G.NPCRegistry = {}

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function getNearbyPlayers(npcRoot, radius)
	radius = radius or 20
	local nearby = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - npcRoot.Position).Magnitude <= radius then
				table.insert(nearby, p.Name)
			end
		end
	end
	return nearby
end

local function getIsolatedPlayer(nearbyPlayers)
	if #nearbyPlayers == 1 then
		return nearbyPlayers[1]
	end
	return nil
end

local function moveNPCTo(npcModel, targetPosition)
	local humanoid = npcModel:FindFirstChild("Humanoid")
	if not humanoid then return end

	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5 })
	local success, err = pcall(function()
		path:ComputeAsync(npcModel.HumanoidRootPart.Position, targetPosition)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			humanoid:MoveTo(waypoint.Position)
			humanoid.MoveToFinished:Wait()
		end
	else
		humanoid:MoveTo(targetPosition)
	end
end

local function findFakeTerminal()
	return workspace:FindFirstChild("FakeAdminTerminal")
		or workspace:FindFirstChild("FakeSecurityCheckpoint")
		or workspace:FindFirstChild("FakeVerificationStation")
end

local function showDialogueForAll(npcName, message, tactic)
	ShowDialogue:FireAllClients({ npcName = npcName, message = message, tactic = tactic })
	task.delay(DIALOGUE_TTL, function()
		HideDialogue:FireAllClients()
	end)
end

-- ── Backend call ─────────────────────────────────────────────────────────────
local function queryBackend(npcConfig, nearbyPlayers, isolatedPlayer)
	local gameState = _G.GameState
	local phase = gameState and gameState.phase or "task_phase"
	if phase ~= "TASK_PHASE" then return nil end

	local payload = HttpService:JSONEncode({
		npc_id          = npcConfig.name,
		npc_type        = npcConfig.npcType,
		nearby_players  = nearbyPlayers,
		isolated_player = isolatedPlayer,
		task_progress   = gameState and gameState.taskProgress or 0,
		phase           = "task_phase",
	})

	local ok, result = pcall(function()
		return HttpService:PostAsync(
			BACKEND_URL .. "/npc/decide",
			payload,
			Enum.HttpContentType.ApplicationJson,
			false
		)
	end)

	if not ok then
		warn("[NPCController] Backend call failed:", result)
		return nil
	end

	local decoded = HttpService:JSONDecode(result)
	return decoded
end

-- ── NPC loop ─────────────────────────────────────────────────────────────────
local function runNPC(config)
	_G.NPCRegistry[config.name] = { npcType = config.npcType }

	while true do
		task.wait(POLL_RATE)

		local npcModel = workspace:FindFirstChild(config.name)
		if not npcModel then
			warn("[NPCController] NPC model not found in Workspace:", config.name)
			task.wait(5)
			continue
		end

		local npcRoot = npcModel:FindFirstChild("HumanoidRootPart")
		if not npcRoot then continue end

		local nearbyPlayers  = getNearbyPlayers(npcRoot)
		local isolatedPlayer = getIsolatedPlayer(nearbyPlayers)

		local action = queryBackend(config, nearbyPlayers, isolatedPlayer)
		if not action then continue end

		print("[NPCController]", config.name, "→", action.action, "| target:", action.target_player or "none")

		if action.action == "IDLE" then
			-- do nothing

		elseif action.action == "FOLLOW_PLAYER" and action.target_player then
			local target = Players:FindFirstChild(action.target_player)
			if target and target.Character then
				local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					task.spawn(function()
						moveNPCTo(npcModel, targetRoot.Position)
					end)
				end
			end

		elseif action.action == "LURE_TO_FAKE_TERMINAL" then
			local target = Players:FindFirstChild(action.target_player or "")

			-- Show dialogue to the target player
			if action.message ~= "" then
				showDialogueForAll(config.displayName, action.message, action.tactic)

				-- Tag the player with tactic info so TaskManager can use it on scam
				if target then
					target:SetAttribute("LastTactic", action.tactic)
					target:SetAttribute("LastRedFlags", table.concat(action.red_flags or {}, "\n• "))
				end
			end

			-- Walk NPC toward the fake terminal
			local fakeTerminal = findFakeTerminal()
			if fakeTerminal then
				task.spawn(function()
					local termPos = fakeTerminal:IsA("Model")
						and fakeTerminal.PrimaryPart
						and fakeTerminal.PrimaryPart.Position
						or fakeTerminal.Position
					moveNPCTo(npcModel, termPos)
				end)
			end
		end
	end
end

-- ── Start NPCs after short delay (let GameEvents script run first) ────────────
task.delay(3, function()
	for _, config in ipairs(NPC_CONFIGS) do
		task.spawn(runNPC, config)
	end
end)

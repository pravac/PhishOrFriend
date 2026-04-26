-- NPCController.server.lua
local Players            = game:GetService("Players")
local HttpService        = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Chat               = game:GetService("Chat")

local function getOrMakeEvent(name)
	local e = ReplicatedStorage:FindFirstChild(name)
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = ReplicatedStorage
	end
	return e
end

local PlayerChatted = getOrMakeEvent("PlayerChatted")
local NPCResponse   = getOrMakeEvent("NPCResponse")
local ShowDialogue  = getOrMakeEvent("ShowDialogue")

local BACKEND_URL       = "https://phishorfriend-production.up.railway.app"
local POLL_MIN          = 8
local POLL_MAX          = 12
local DIALOGUE_COOLDOWN = 25
local CHAT_SUPPRESS_SEC = 15  -- seconds to suppress wander dialogue after chat response

local NPC_CONFIGS = {
	{ name = "Alex",   npcType = "urgency",    displayName = "Alex"   },
	{ name = "Jordan", npcType = "authority",  displayName = "Jordan" },
}

_G.NPCRegistry = {}

-- Shared per-NPC state (used by both runNPC and chat handler)
local npcStates = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────
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
	return #nearbyPlayers == 1 and nearbyPlayers[1] or nil
end

local function moveNPCTo(npcModel, targetPosition)
	local humanoid = npcModel:FindFirstChild("Humanoid")
	if not humanoid then return end
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5 })
	local ok = pcall(function()
		path:ComputeAsync(npcModel.HumanoidRootPart.Position, targetPosition)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			humanoid:MoveTo(wp.Position)
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

local function setupAnimations(npcModel)
	local humanoid = npcModel:FindFirstChild("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChild("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = "rbxassetid://507777826"
	local walkTrack = animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = "rbxassetid://507766388"
	local idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not walkTrack.IsPlaying then walkTrack:Play() end
			idleTrack:Stop()
		else
			walkTrack:Stop()
			if not idleTrack.IsPlaying then idleTrack:Play() end
		end
	end)
end

local function showDialogue(npcModel, message)
	local head = npcModel:FindFirstChild("Head")
	if head then Chat:Chat(head, message, Enum.ChatColor.White) end
	local data = { npcName = npcModel.Name, message = message }
	NPCResponse:FireAllClients(data)
	ShowDialogue:FireAllClients(data)
end

-- ── Task lines (non-repeating per NPC) ───────────────────────────────────────
local TASK_LINES = {
	PowerTerminal   = { "gonna go fix the power real quick", "power terminal needs resetting again", "someone left the power terminal on" },
	DataUplink      = { "need to finish the data uplink", "data uplink is almost done", "uploading data now" },
	OxygenValve     = { "oxygen valve needs checking", "going to sort out the oxygen", "oxygen levels look off" },
	NavigationPanel = { "navigation panel is acting up", "recalibrating navigation", "just need to fix nav real quick" },
}

local function getDialogueLine(taskName, state)
	local lines = TASK_LINES[taskName]
	if not lines then return nil end
	local available = {}
	for _, line in ipairs(lines) do
		if not state.usedLines[line] then table.insert(available, line) end
	end
	if #available == 0 then
		for _, line in ipairs(lines) do state.usedLines[line] = nil end
		available = lines
	end
	local picked = available[math.random(1, #available)]
	state.usedLines[picked] = true
	return picked
end

-- ── Task destination: visit each task once, then wander near players ──────────
local function getNextDestination(state)
	local taskFolder = workspace:FindFirstChild("Tasks")
	local unvisited = {}
	if taskFolder then
		for _, part in ipairs(taskFolder:GetChildren()) do
			if part:IsA("BasePart") and not state.visitedTasks[part.Name] then
				table.insert(unvisited, part)
			end
		end
	end
	if #unvisited > 0 then
		local picked = unvisited[math.random(1, #unvisited)]
		state.visitedTasks[picked.Name] = true
		return picked.Position, picked.Name
	end
	-- All tasks visited — wander near a random player
	local players = Players:GetPlayers()
	if #players > 0 then
		local p = players[math.random(1, #players)]
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			return p.Character.HumanoidRootPart.Position, nil
		end
	end
	return nil, nil
end

-- ── Positive response detection ───────────────────────────────────────────────
local AGREE_WORDS = { "ok", "okay", "sure", "yeah", "yes", "alright", "fine", "lets", "coming", "omw", "on my way", "ill come", "coming now" }
local function isPositiveResponse(message)
	local lower = message:lower()
	for _, word in ipairs(AGREE_WORDS) do
		if lower:find(word, 1, true) then return true end
	end
	return false
end

-- ── Backend call ──────────────────────────────────────────────────────────────
local function queryBackend(npcConfig, nearbyPlayers, isolatedPlayer)
	local gameState = _G.GameState
	local phase = gameState and gameState.phase or "task_phase"
	if phase ~= "TASK_PHASE" then return nil end

	local payload = HttpService:JSONEncode({
		npc_id         = npcConfig.name,
		npc_type       = npcConfig.npcType,
		nearby_players = nearbyPlayers,
		isolated_player = isolatedPlayer,
		task_progress  = gameState and gameState.taskProgress or 0,
		phase          = "task_phase",
	})

	local ok, result = pcall(function()
		return HttpService:PostAsync(BACKEND_URL .. "/npc/decide", payload, Enum.HttpContentType.ApplicationJson, false)
	end)
	if not ok then warn("[NPCController] Backend call failed:", result); return nil end
	return HttpService:JSONDecode(result)
end

-- ── NPC loop ──────────────────────────────────────────────────────────────────
local function runNPC(config)
	print("[NPCController] runNPC started for", config.name)
	_G.NPCRegistry[config.name] = { npcType = config.npcType }

	npcStates[config.name] = {
		isScamming       = false,
		lastDialogueTime = 0,
		lastChatTime     = 0,
		visitedTasks     = {},
		usedLines        = {},
		model            = nil,
	}
	local state = npcStates[config.name]

	local npcModel = workspace:WaitForChild(config.name, 30)
	if not npcModel then warn("[NPCController] NPC model not found:", config.name); return end
	state.model = npcModel
	print("[NPCController] Found model:", config.name)

	local ok, err = pcall(setupAnimations, npcModel)
	if not ok then warn("[NPCController] Animation setup failed:", err) end

	-- Wander loop
	task.spawn(function()
		while npcModel and npcModel.Parent do
			-- Pause wandering outside task phase so NPCs don't roam during voting/reveal
			local gs = _G.GameState
			if gs and gs.phase ~= "TASK_PHASE" then
				state.isScamming = false
				task.wait(2)
				continue
			end
			if not state.isScamming then
				local dest, taskName = getNextDestination(state)
				if dest then
					-- Only say task lines if not just responding to chat
					if taskName and (tick() - state.lastChatTime) > CHAT_SUPPRESS_SEC then
						local line = getDialogueLine(taskName, state)
						if line and math.random() < 0.6 then
							showDialogue(npcModel, line)
							state.lastDialogueTime = tick()
						end
					end
					moveNPCTo(npcModel, dest)
					task.wait(5)
				else
					task.wait(2)
				end
			else
				task.wait(1)
			end
		end
	end)

	-- Poll loop
	local previousPhase = ""
	while npcModel and npcModel.Parent do
		task.wait(math.random(POLL_MIN, POLL_MAX))

		-- Detect round restart and reset per-round state
		local currentPhase = (_G.GameState and _G.GameState.phase) or ""
		if currentPhase == "TASK_PHASE" and previousPhase ~= "TASK_PHASE" then
			state.visitedTasks = {}
			state.usedLines    = {}
			state.isScamming   = false
		end
		previousPhase = currentPhase

		local npcRoot = npcModel:FindFirstChild("HumanoidRootPart")
		if not npcRoot then continue end

		local nearbyPlayers  = getNearbyPlayers(npcRoot)
		local isolatedPlayer = getIsolatedPlayer(nearbyPlayers)

		local action = queryBackend(config, nearbyPlayers, isolatedPlayer)
		if not action then state.isScamming = false; continue end

		print("[NPCController]", config.name, "→", action.action, "| target:", action.target_player or "none")

		if action.action == "IDLE" then
			state.isScamming = false

		elseif action.action == "FOLLOW_PLAYER" and action.target_player then
			state.isScamming = false
			local target = Players:FindFirstChild(action.target_player)
			if target and target.Character then
				local tr = target.Character:FindFirstChild("HumanoidRootPart")
				if tr then task.spawn(function() moveNPCTo(npcModel, tr.Position) end) end
			end

		elseif action.action == "DIALOGUE_ONLY" then
			state.isScamming = false
			if action.message ~= "" and (tick() - state.lastDialogueTime) > DIALOGUE_COOLDOWN
				and (tick() - state.lastChatTime) > CHAT_SUPPRESS_SEC then
				state.lastDialogueTime = tick()
				showDialogue(npcModel, action.message)
			end

		elseif action.action == "LURE_TO_FAKE_TERMINAL" then
			state.isScamming = true
			local target = Players:FindFirstChild(action.target_player or "")
			-- Always persist tactic data regardless of dialogue cooldown so the
			-- end screen has accurate information even if the message is suppressed.
			if target then
				target:SetAttribute("LastTactic", action.tactic)
				target:SetAttribute("LastRedFlags", table.concat(action.red_flags or {}, "\n• "))
			end
			if action.message ~= "" and (tick() - state.lastDialogueTime) > DIALOGUE_COOLDOWN
				and (tick() - state.lastChatTime) > CHAT_SUPPRESS_SEC then
				state.lastDialogueTime = tick()
				showDialogue(npcModel, action.message)
			end
			local fakeTerminal = findFakeTerminal()
			if fakeTerminal then
				local termPos = fakeTerminal:IsA("Model") and fakeTerminal.PrimaryPart and fakeTerminal.PrimaryPart.Position or fakeTerminal.Position
				moveNPCTo(npcModel, termPos)
			end
		end
	end
end

-- ── Chat handler ──────────────────────────────────────────────────────────────
local CHAT_RADIUS = 50

PlayerChatted.OnServerEvent:Connect(function(player, message)
	local char = player.Character
	if not char then return end
	local playerRoot = char:FindFirstChild("HumanoidRootPart")
	if not playerRoot then return end

	local closestModel, closestConfig, closestDist = nil, nil, math.huge
	for _, config in ipairs(NPC_CONFIGS) do
		local npcModel = workspace:FindFirstChild(config.name)
		if npcModel then
			local root = npcModel:FindFirstChild("HumanoidRootPart")
			if root then
				local dist = (root.Position - playerRoot.Position).Magnitude
				if dist < closestDist then closestModel, closestConfig, closestDist = npcModel, config, dist end
			end
		end
	end

	if not closestModel or closestDist > CHAT_RADIUS then return end

	local state = npcStates[closestConfig.name]
	state.lastChatTime = tick()

	-- If NPC was luring and player responds positively, lead them to terminal now
	if state.isScamming and isPositiveResponse(message) then
		task.spawn(function()
			local followLines = { "follow me ill show you", "come on its right over here", "this way real quick" }
			showDialogue(closestModel, followLines[math.random(1, #followLines)])
			local fakeTerminal = findFakeTerminal()
			if fakeTerminal then
				local termPos = fakeTerminal:IsA("Model") and fakeTerminal.PrimaryPart and fakeTerminal.PrimaryPart.Position or fakeTerminal.Position
				moveNPCTo(closestModel, termPos)
			end
		end)
		return
	end

	local gameState = _G.GameState
	local payload = HttpService:JSONEncode({
		npc_id         = closestConfig.name,
		npc_type       = closestConfig.npcType,
		player_message = message,
		task_progress  = gameState and gameState.taskProgress or 0,
	})

	task.spawn(function()
		local ok, result = pcall(function()
			return HttpService:PostAsync(BACKEND_URL .. "/npc/respond", payload, Enum.HttpContentType.ApplicationJson, false)
		end)
		if not ok then warn("[NPCController] /npc/respond failed:", result); return end
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, result)
		if not decodeOk then warn("[NPCController] JSON parse failed:", decoded); return end
		if decoded.message and decoded.message ~= "" then
			task.wait(1.2)
			showDialogue(closestModel, decoded.message)
		end
	end)
end)

-- ── Start ─────────────────────────────────────────────────────────────────────
print("[NPCController] Script loaded, spawning", #NPC_CONFIGS, "NPCs")
for _, config in ipairs(NPC_CONFIGS) do
	task.spawn(runNPC, config)
end

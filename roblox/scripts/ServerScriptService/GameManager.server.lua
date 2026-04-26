-- GameManager.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Create ALL RemoteEvents here first so clients can find them ───────────────
local function makeEvent(name)
	local e = ReplicatedStorage:FindFirstChild(name)
	if not e then
		e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = ReplicatedStorage
	end
	return e
end

local PhaseChanged        = makeEvent("PhaseChanged")
makeEvent("PlayerChatted")
makeEvent("NPCResponse")
local ShowDialogue        = makeEvent("ShowDialogue")
local HideDialogue        = makeEvent("HideDialogue")
local TaskCompleted       = makeEvent("TaskCompleted")
local FakeTerminalTriggered = makeEvent("FakeTerminalTriggered")
local UpdateTaskProgress  = makeEvent("UpdateTaskProgress")
local OpenVotingUI        = makeEvent("OpenVotingUI")
local SubmitVote          = makeEvent("SubmitVote")
local VoteResult          = makeEvent("VoteResult")
local ShowEndScreen       = makeEvent("ShowEndScreen")
local PlayerScammed       = makeEvent("PlayerScammed")
makeEvent("DataHarvestAttempt")
local SensitiveInfoShared = makeEvent("SensitiveInfoShared")

-- ── Config ────────────────────────────────────────────────────────────────────
local TASK_PHASE_DURATION = 90
local VOTING_DURATION     = 30
local REVEAL_DURATION     = 20
local TOTAL_TASKS         = 4

-- ── Game State ────────────────────────────────────────────────────────────────
local GameState = {
	phase               = "LOBBY",
	scammedPlayers      = {},
	votes               = {},
	taskProgress        = 0,
	completedTasks      = 0,
	sensitiveInfoShared = {},
}
_G.GameState = GameState

-- ── Task tracking (replaces require of TaskManager) ───────────────────────────
local completedTaskNames = {}

local function onTaskDone(taskName)
	if completedTaskNames[taskName] then return end
	completedTaskNames[taskName] = true
	GameState.completedTasks += 1
	GameState.taskProgress = GameState.completedTasks / TOTAL_TASKS
	print("[GameManager] Task completed:", taskName, "| progress:", GameState.taskProgress)
	UpdateTaskProgress:FireAllClients(GameState.taskProgress)
end

-- Server-side ProximityPrompt detection (more reliable than client RemoteEvent)
task.defer(function()
	local taskFolder = workspace:WaitForChild("Tasks", 30)
	if not taskFolder then warn("[GameManager] Tasks folder not found"); return end
	for _, taskObj in ipairs(taskFolder:GetChildren()) do
		local prompt = taskObj:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				onTaskDone(taskObj.Name)
			end)
			print("[GameManager] Hooked task:", taskObj.Name)
		end
	end
end)

-- Keep client RemoteEvent as fallback
TaskCompleted.OnServerEvent:Connect(function(player, taskName)
	onTaskDone(taskName)
end)

FakeTerminalTriggered.OnServerEvent:Connect(function(player)
	local already = false
	for _, n in ipairs(GameState.scammedPlayers) do
		if n == player.Name then already = true; break end
	end
	if not already then
		table.insert(GameState.scammedPlayers, player.Name)
		local tactic   = player:GetAttribute("LastTactic") or "unknown"
		local redFlags = player:GetAttribute("LastRedFlags") or ""
		PlayerScammed:FireClient(player, { playerName=player.Name, tactic=tactic, redFlags=redFlags })
		print("[GameManager] SCAMMED:", player.Name)
	end
end)

SensitiveInfoShared.OnServerEvent:Connect(function(player, infoType)
	if GameState.phase ~= "TASK_PHASE" then return end
	local list = GameState.sensitiveInfoShared[player.Name]
	if not list then
		list = {}
		GameState.sensitiveInfoShared[player.Name] = list
	end
	table.insert(list, infoType)
	print("[GameManager] Sensitive info shared by", player.Name, ":", infoType)
end)

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function broadcastPhase(phase)
	GameState.phase = phase
	PhaseChanged:FireAllClients(phase)
	print("[GameManager] Phase →", phase)
end

local function getPlayerList()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do table.insert(list, p.Name) end
	return list
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function countVotes()
	local n = 0
	for _ in pairs(GameState.votes) do n += 1 end
	return n
end

-- ── Voting ────────────────────────────────────────────────────────────────────
local function runVoting()
	broadcastPhase("VOTING")
	GameState.votes = {}

	local playerList = getPlayerList()
	local votable = {}
	local addedNames = {}
	for _, n in ipairs(playerList) do
		votable[#votable+1] = n
		addedNames[n] = true
	end
	-- From registry (NPCs only — skip workspace fallback to avoid stale models)
	for npcName, _ in pairs(_G.NPCRegistry or {}) do
		if not addedNames[npcName] then
			votable[#votable+1] = npcName
			addedNames[npcName] = true
		end
	end
	print("[GameManager] Votable list:", table.concat(votable, ", "))

	OpenVotingUI:FireAllClients({ players = votable })

	local deadline = tick() + VOTING_DURATION
	while tick() < deadline do
		if countVotes() >= #playerList then break end
		task.wait(1)
	end

	local tally = {}
	for _, voted in pairs(GameState.votes) do
		tally[voted] = (tally[voted] or 0) + 1
	end
	local topName, topCount = nil, 0
	for name, count in pairs(tally) do
		if count > topCount then topName, topCount = name, count end
	end

	local eliminated = topName or "No one"
	VoteResult:FireAllClients(eliminated)
	print("[GameManager] Eliminated:", eliminated)

	local npc = workspace:FindFirstChild(eliminated)
	if npc and npc:GetAttribute("IsScammerNPC") then npc:Destroy() end
	task.wait(3)
end

-- ── Reveal ────────────────────────────────────────────────────────────────────
local function runReveal()
	broadcastPhase("REVEAL")
	local agentsRevealed = {}
	local registry = _G.NPCRegistry or {}
	for npcName, info in pairs(registry) do
		table.insert(agentsRevealed, { name = npcName, tactic = info.npcType })
	end
	local tacticsUsed = {}
	local seen = {}
	for _, info in ipairs(agentsRevealed) do
		if not seen[info.tactic] then
			seen[info.tactic] = true
			table.insert(tacticsUsed, info.tactic)
		end
	end
	ShowEndScreen:FireAllClients({
		scammedPlayers      = GameState.scammedPlayers,
		agentsRevealed      = agentsRevealed,
		tacticsUsed         = tacticsUsed,
		sensitiveInfoShared = GameState.sensitiveInfoShared,
	})
	task.wait(REVEAL_DURATION)
end

-- ── Main Loop ─────────────────────────────────────────────────────────────────
local function startGame()
	broadcastPhase("TASK_PHASE")
	GameState.completedTasks = 0
	GameState.taskProgress   = 0
	GameState.scammedPlayers      = {}
	GameState.sensitiveInfoShared = {}
	completedTaskNames            = {}

	local deadline = tick() + TASK_PHASE_DURATION
	while tick() < deadline and GameState.taskProgress < 1.0 do
		task.wait(1)
	end

	runVoting()
	runReveal()
	broadcastPhase("LOBBY")
	task.wait(10)
end

SubmitVote.OnServerEvent:Connect(function(player, votedName)
	if GameState.phase == "VOTING" and not GameState.votes[player.Name] then
		GameState.votes[player.Name] = votedName
	end
end)

task.delay(5, function()
	while true do
		startGame()
	end
end)

-- GameManager.server.lua
-- Manages overall game phases: LOBBY → TASK_PHASE → VOTING → REVEAL → LOBBY

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wait for events to be created by GameEvents script
local function waitForEvent(name)
	return ReplicatedStorage:WaitForChild(name, 10)
end

local PhaseChanged        = waitForEvent("PhaseChanged")
local OpenVotingUI        = waitForEvent("OpenVotingUI")
local SubmitVote          = waitForEvent("SubmitVote")
local VoteResult          = waitForEvent("VoteResult")
local ShowEndScreen       = waitForEvent("ShowEndScreen")
local UpdateTaskProgress  = waitForEvent("UpdateTaskProgress")

-- ── Config ──────────────────────────────────────────────────────────────────
local TASK_PHASE_DURATION = 90   -- seconds
local VOTING_DURATION     = 30
local REVEAL_DURATION     = 20
local MIN_PLAYERS         = 1    -- set to 1 so you can test solo

-- ── Game State ───────────────────────────────────────────────────────────────
local GameState = {
	phase = "LOBBY",
	agents = {},           -- {[playerName] = "urgency" | "authority" | nil}
	scammedPlayers = {},   -- list of playerNames
	votes = {},            -- {[voterName] = votedName}
	taskProgress = 0,
	totalTasks = 4,
	completedTasks = 0,
}

-- Exposed so NPCController can read/write it
_G.GameState = GameState

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function broadcastPhase(phase)
	GameState.phase = phase
	PhaseChanged:FireAllClients(phase)
	print("[GameManager] Phase →", phase)
end

local function getPlayerList()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, p.Name)
	end
	return list
end

local function assignRoles()
	GameState.agents = {}
	local players = Players:GetPlayers()
	-- First player = urgency NPC controller, second = authority (for demo purposes
	-- In real play these are AI NPCs, not human players — roles just track tactic context)
	-- We mark no human players as agents; NPCs are spawned by NPCController
end

-- ── Task Progress ─────────────────────────────────────────────────────────────
local TaskManager = require(script.Parent:WaitForChild("TaskManager"))

local function onTaskCompleted()
	GameState.completedTasks += 1
	GameState.taskProgress = GameState.completedTasks / GameState.totalTasks
	UpdateTaskProgress:FireAllClients(GameState.taskProgress)
	print("[GameManager] Task progress:", GameState.taskProgress)
end

TaskManager.OnTaskCompleted:Connect(onTaskCompleted)

-- ── Voting ────────────────────────────────────────────────────────────────────
local function runVoting()
	broadcastPhase("VOTING")
	GameState.votes = {}

	local playerList = getPlayerList()
	-- include NPC names so players can vote them out
	local votableNames = {}
	for _, name in ipairs(playerList) do table.insert(votableNames, name) end
	-- Add NPC names from workspace
	for _, npc in ipairs(workspace:GetChildren()) do
		if npc:IsA("Model") and npc:GetAttribute("IsScammerNPC") then
			table.insert(votableNames, npc.Name)
		end
	end

	OpenVotingUI:FireAllClients({ players = votableNames })

	local deadline = tick() + VOTING_DURATION
	while tick() < deadline do
		if #GameState.votes >= #playerList then break end
		task.wait(1)
	end

	-- Tally votes
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

	-- Remove voted NPC from workspace
	if eliminated ~= "No one" then
		local npc = workspace:FindFirstChild(eliminated)
		if npc and npc:GetAttribute("IsScammerNPC") then
			npc:Destroy()
		end
	end

	task.wait(3)
end

-- ── Reveal ────────────────────────────────────────────────────────────────────
local function runReveal()
	broadcastPhase("REVEAL")

	-- Collect which NPCs were agents and their tactics
	local agentsRevealed = {}
	for _, npc in ipairs(workspace:GetChildren()) do
		if npc:IsA("Model") and npc:GetAttribute("IsScammerNPC") then
			table.insert(agentsRevealed, {
				name   = npc.Name,
				tactic = npc:GetAttribute("NPCType") or "unknown",
			})
		end
	end
	-- Also include destroyed ones tracked in NPCController
	local npcController = _G.NPCRegistry or {}
	for npcName, info in pairs(npcController) do
		local alreadyListed = false
		for _, a in ipairs(agentsRevealed) do
			if a.name == npcName then alreadyListed = true; break end
		end
		if not alreadyListed then
			table.insert(agentsRevealed, { name = npcName, tactic = info.npcType })
		end
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
		scammedPlayers = GameState.scammedPlayers,
		agentsRevealed = agentsRevealed,
		tacticsUsed    = tacticsUsed,
	})

	task.wait(REVEAL_DURATION)
end

-- ── Main Loop ─────────────────────────────────────────────────────────────────
local function startGame()
	assignRoles()
	broadcastPhase("TASK_PHASE")
	GameState.completedTasks = 0
	GameState.taskProgress   = 0
	GameState.scammedPlayers = {}

	-- Wait for task phase to end (time limit or all tasks done)
	local deadline = tick() + TASK_PHASE_DURATION
	while tick() < deadline and GameState.taskProgress < 1.0 do
		task.wait(1)
	end

	runVoting()
	runReveal()

	-- Reset for next round
	broadcastPhase("LOBBY")
	task.wait(10)
end

-- Vote handler
SubmitVote.OnServerEvent:Connect(function(player, votedName)
	if GameState.phase == "VOTING" and not GameState.votes[player.Name] then
		GameState.votes[player.Name] = votedName
		print("[GameManager] Vote:", player.Name, "→", votedName)
	end
end)

-- Wait for enough players then start
Players.PlayerAdded:Connect(function()
	if GameState.phase == "LOBBY" and #Players:GetPlayers() >= MIN_PLAYERS then
		task.delay(3, startGame)
	end
end)

-- Auto-start for solo testing
task.delay(5, function()
	if GameState.phase == "LOBBY" then
		startGame()
	end
end)

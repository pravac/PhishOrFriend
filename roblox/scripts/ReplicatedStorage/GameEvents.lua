-- Run this as a Script inside ReplicatedStorage named "GameEvents"
-- It creates all RemoteEvents and RemoteFunctions used across client/server

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function makeEvent(name)
	if not ReplicatedStorage:FindFirstChild(name) then
		local e = Instance.new("RemoteEvent")
		e.Name = name
		e.Parent = ReplicatedStorage
	end
end

local function makeFunction(name)
	if not ReplicatedStorage:FindFirstChild(name) then
		local f = Instance.new("RemoteFunction")
		f.Name = name
		f.Parent = ReplicatedStorage
	end
end

-- Phase changes
makeEvent("PhaseChanged")       -- server → client: string phase name

-- NPC dialogue
makeEvent("ShowDialogue")       -- server → client: {npcName, message, tactic}
makeEvent("HideDialogue")       -- server → client

-- Task system
makeEvent("TaskCompleted")      -- client → server: string taskName
makeEvent("FakeTerminalTriggered") -- server → client: string playerName (got scammed)
makeEvent("UpdateTaskProgress") -- server → client: number 0-1

-- Voting
makeEvent("OpenVotingUI")       -- server → client: {players: [...]}
makeEvent("SubmitVote")         -- client → server: string votedPlayerName
makeEvent("VoteResult")         -- server → client: string eliminatedName

-- End screen
makeEvent("ShowEndScreen")      -- server → client: {scammedPlayers, agentsRevealed, tacticsUsed}

-- Player scammed notification
makeEvent("PlayerScammed")      -- server → client: {playerName, tactic, redFlags}

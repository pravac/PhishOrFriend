-- TaskManager.server.lua
-- Handles real task completion and fake terminal trap detection.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TaskCompleted         = ReplicatedStorage:WaitForChild("TaskCompleted", 10)
local FakeTerminalTriggered = ReplicatedStorage:WaitForChild("FakeTerminalTriggered", 10)
local PlayerScammed         = ReplicatedStorage:WaitForChild("PlayerScammed", 10)

local TaskManager = {}
TaskManager.OnTaskCompleted = Instance.new("BindableEvent")

-- Track which real tasks have been completed (by name)
local completedTasks = {}

-- Real task names — must match ProximityPrompt names on your task objects in Studio
local REAL_TASKS = {
	"PowerTerminal",
	"DataUplink",
	"OxygenValve",
	"NavigationPanel",
}

TaskCompleted.OnServerEvent:Connect(function(player, taskName)
	-- Ignore if already done
	if completedTasks[taskName] then return end

	-- Verify it's a real task
	local isReal = false
	for _, name in ipairs(REAL_TASKS) do
		if name == taskName then isReal = true; break end
	end

	if isReal then
		completedTasks[taskName] = true
		print("[TaskManager]", player.Name, "completed task:", taskName)
		TaskManager.OnTaskCompleted:Fire(taskName)
	end
end)

-- Fake terminal: player was lured and interacted with it
FakeTerminalTriggered.OnServerEvent:Connect(function(player)
	local gameState = _G.GameState
	if not gameState then return end

	-- Record scam
	local alreadyScammed = false
	for _, name in ipairs(gameState.scammedPlayers) do
		if name == player.Name then alreadyScammed = true; break end
	end

	if not alreadyScammed then
		table.insert(gameState.scammedPlayers, player.Name)
		print("[TaskManager] SCAMMED:", player.Name)

		-- Notify the scammed player with tactic explanation
		-- The NPC controller will have set the last tactic on the player
		local tactic    = player:GetAttribute("LastTactic") or "unknown"
		local redFlags  = player:GetAttribute("LastRedFlags") or "Unknown manipulation tactic used."

		PlayerScammed:FireClient(player, {
			playerName = player.Name,
			tactic     = tactic,
			redFlags   = redFlags,
		})
	end
end)

function TaskManager.reset()
	completedTasks = {}
end

return TaskManager

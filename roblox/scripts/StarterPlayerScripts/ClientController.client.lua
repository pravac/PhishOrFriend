-- ClientController.client.lua
-- Handles all client-side interactions: task proximity prompts, fake terminal,
-- receiving phase changes, and forwarding events to the server.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

-- Wait for RemoteEvents
local PhaseChanged          = ReplicatedStorage:WaitForChild("PhaseChanged", 10)
local TaskCompleted         = ReplicatedStorage:WaitForChild("TaskCompleted", 10)
local FakeTerminalTriggered = ReplicatedStorage:WaitForChild("FakeTerminalTriggered", 10)
local UpdateTaskProgress    = ReplicatedStorage:WaitForChild("UpdateTaskProgress", 10)
local PlayerScammed         = ReplicatedStorage:WaitForChild("PlayerScammed", 10)

-- ── Task Interaction ──────────────────────────────────────────────────────────
-- Real tasks: each task object in Workspace should have a ProximityPrompt
-- with ActionText = "Complete Task" and ObjectText = the task name (e.g. "PowerTerminal")
local function setupTaskPrompts()
	local taskFolder = workspace:FindFirstChild("Tasks")
	if not taskFolder then return end

	for _, taskObj in ipairs(taskFolder:GetChildren()) do
		local prompt = taskObj:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.Triggered:Connect(function(player)
				if player == localPlayer then
					TaskCompleted:FireServer(taskObj.Name)
					prompt.Enabled = false  -- prevent double-completion
					-- visual feedback
					local gui = localPlayer.PlayerGui:FindFirstChild("TaskGui")
					if gui then
						local label = gui:FindFirstChild("FlashLabel", true)
						if label then
							label.Text = "✓ " .. taskObj.Name .. " complete!"
							label.Visible = true
							task.delay(2, function() label.Visible = false end)
						end
					end
				end
			end)
		end
	end
end

-- ── Fake Terminal Interaction ─────────────────────────────────────────────────
local function setupFakeTerminals()
	local fakeNames = { "FakeAdminTerminal", "FakeSecurityCheckpoint", "FakeVerificationStation" }
	for _, name in ipairs(fakeNames) do
		local obj = workspace:FindFirstChild(name)
		if obj then
			local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				prompt.Triggered:Connect(function(player)
					if player == localPlayer then
						FakeTerminalTriggered:FireServer()
					end
				end)
			end
		end
	end
end

-- Wait for character to load, then set up prompts
local function onCharacterAdded()
	task.wait(1)
	setupTaskPrompts()
	setupFakeTerminals()
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)
if localPlayer.Character then
	onCharacterAdded()
end

-- ── Phase change handling ─────────────────────────────────────────────────────
PhaseChanged.OnClientEvent:Connect(function(phase)
	print("[Client] Phase →", phase)
	-- Phase-specific UI is handled in the GUI scripts
end)

-- ── Task progress bar update ──────────────────────────────────────────────────
UpdateTaskProgress.OnClientEvent:Connect(function(progress)
	local gui     = localPlayer.PlayerGui:FindFirstChild("TaskGui")
	if not gui then return end
	local bar     = gui:FindFirstChild("ProgressBar", true)
	local fill    = bar and bar:FindFirstChild("Fill")
	if fill then
		fill.Size = UDim2.new(progress, 0, 1, 0)
	end
	local label = gui:FindFirstChild("ProgressLabel", true)
	if label then
		label.Text = "Tasks: " .. math.floor(progress * 100) .. "%"
	end
end)

-- ── Scam notification ─────────────────────────────────────────────────────────
PlayerScammed.OnClientEvent:Connect(function(data)
	-- Brief flash "YOU WERE SCAMMED" — full reveal at end screen
	local gui = localPlayer.PlayerGui:FindFirstChild("DialogueGui")
	if gui then
		local scamFrame = gui:FindFirstChild("ScamAlert")
		if scamFrame then
			scamFrame.Visible = true
			local tacticLabel = scamFrame:FindFirstChild("TacticLabel")
			if tacticLabel then
				tacticLabel.Text = "⚠ You were scammed!\nTactic: " .. (data.tactic or "unknown")
			end
			task.delay(4, function()
				scamFrame.Visible = false
			end)
		end
	end
end)

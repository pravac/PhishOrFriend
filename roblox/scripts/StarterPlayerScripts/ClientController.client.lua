-- ClientController.client.lua
-- Handles all client-side interactions: task proximity prompts, fake terminal,
-- receiving phase changes, and forwarding events to the server.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService   = game:GetService("TextChatService")

local localPlayer = Players.LocalPlayer

-- Wait for RemoteEvents
local PhaseChanged          = ReplicatedStorage:WaitForChild("PhaseChanged", 10)
local TaskCompleted         = ReplicatedStorage:WaitForChild("TaskCompleted", 10)
local FakeTerminalTriggered = ReplicatedStorage:WaitForChild("FakeTerminalTriggered", 10)
local UpdateTaskProgress    = ReplicatedStorage:WaitForChild("UpdateTaskProgress", 10)
local PlayerScammed         = ReplicatedStorage:WaitForChild("PlayerScammed", 10)
local DataHarvestAttempt    = ReplicatedStorage:WaitForChild("DataHarvestAttempt", 15)
local PlayerChatted         = ReplicatedStorage:WaitForChild("PlayerChatted", 15)
local NPCResponse           = ReplicatedStorage:WaitForChild("NPCResponse", 15)

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

-- ── Forward player chat to server for NPC response ───────────────────────────
TextChatService.MessageReceived:Connect(function(msg)
	if msg.TextSource and msg.TextSource.UserId == localPlayer.UserId then
		PlayerChatted:FireServer(msg.Text)
	end
end)

-- ── Display NPC messages in the chat log ──────────────────────────────────────
NPCResponse.OnClientEvent:Connect(function(data)
	print("[Client] NPCResponse received:", data.npcName, "→", data.message)
	local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
	if channel then
		channel:DisplaySystemMessage("[" .. data.npcName .. "]: " .. data.message)
	else
		warn("[Client] RBXGeneral channel not found")
	end
end)

-- ── Phase change handling ─────────────────────────────────────────────────────
PhaseChanged.OnClientEvent:Connect(function(phase)
	print("[Client] Phase →", phase)
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
local function showScamBanner(text, duration)
	local gui = localPlayer.PlayerGui:FindFirstChild("DialogueGui")
	if not gui then return end
	local scamFrame = gui:FindFirstChild("ScamAlert")
	if not scamFrame then return end
	local tacticLabel = scamFrame:FindFirstChild("TacticLabel")
	if tacticLabel then tacticLabel.Text = text end
	scamFrame.Visible = true
	task.delay(duration or 5, function() scamFrame.Visible = false end)
end

PlayerScammed.OnClientEvent:Connect(function(data)
	showScamBanner("⚠ You were scammed!\nTactic: " .. (data.tactic or "unknown"), 5)
end)

-- ── Data harvest warning ───────────────────────────────────────────────────────
DataHarvestAttempt.OnClientEvent:Connect(function(data)
	if data.filtered then
		-- Player tried to type personal info but Roblox censored it
		showScamBanner(
			"⚠ You almost gave away personal info!\nRoblox blocked it — never share passwords, emails, or real names with strangers online.",
			7
		)
	else
		-- Player actually typed recognisable personal data
		showScamBanner(
			"⚠ You just shared personal information with a scammer!\nNever give out your password, email, or real name in chat — even to someone who sounds official.",
			8
		)
	end
end)

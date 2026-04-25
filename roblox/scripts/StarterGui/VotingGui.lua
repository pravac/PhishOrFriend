-- VotingGui.lua
-- Place as a LocalScript inside a ScreenGui named "VotingGui" in StarterGui.
-- Create in Studio:
--
--   VotingGui (ScreenGui)
--   └── VotingFrame (Frame, Visible=false)
--       ├── TitleLabel   (TextLabel)  "Vote Out the Scammer"
--       ├── TimerLabel   (TextLabel)  countdown
--       ├── ButtonHolder (Frame)      -- dynamically filled with vote buttons
--       └── ConfirmLabel (TextLabel, Visible=false)  "Vote cast!"

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer   = Players.LocalPlayer
local playerGui     = localPlayer:WaitForChild("PlayerGui")
local votingGui     = playerGui:WaitForChild("VotingGui")
local votingFrame   = votingGui:WaitForChild("VotingFrame")
local timerLabel    = votingFrame:WaitForChild("TimerLabel")
local buttonHolder  = votingFrame:WaitForChild("ButtonHolder")
local confirmLabel  = votingFrame:WaitForChild("ConfirmLabel")

local OpenVotingUI  = ReplicatedStorage:WaitForChild("OpenVotingUI", 10)
local SubmitVote    = ReplicatedStorage:WaitForChild("SubmitVote", 10)
local VoteResult    = ReplicatedStorage:WaitForChild("VoteResult", 10)
local PhaseChanged  = ReplicatedStorage:WaitForChild("PhaseChanged", 10)

local voted = false
local VOTING_DURATION = 30

-- Creates a vote button for each player/NPC name
local function buildVoteButtons(names)
	for _, child in ipairs(buttonHolder:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for _, name in ipairs(names) do
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Text = name
		btn.Size = UDim2.new(0.9, 0, 0, 40)
		btn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 16
		btn.AutomaticSize = Enum.AutomaticSize.None
		btn.Parent = buttonHolder

		btn.Activated:Connect(function()
			if voted then return end
			voted = true
			SubmitVote:FireServer(name)
			confirmLabel.Text = "✓ You voted: " .. name
			confirmLabel.Visible = true
			-- Grey out all buttons
			for _, b in ipairs(buttonHolder:GetChildren()) do
				if b:IsA("TextButton") then
					b.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
					b.Active = false
				end
			end
		end)
	end
end

-- Countdown timer coroutine
local function startTimer(seconds)
	for i = seconds, 0, -1 do
		if not votingFrame.Visible then break end
		timerLabel.Text = "Time left: " .. i .. "s"
		task.wait(1)
	end
end

OpenVotingUI.OnClientEvent:Connect(function(data)
	voted = false
	confirmLabel.Visible = false
	buildVoteButtons(data.players)
	votingFrame.Visible = true
	task.spawn(startTimer, VOTING_DURATION)
end)

VoteResult.OnClientEvent:Connect(function(eliminatedName)
	timerLabel.Text = "Eliminated: " .. eliminatedName
	task.delay(3, function()
		votingFrame.Visible = false
	end)
end)

PhaseChanged.OnClientEvent:Connect(function(phase)
	if phase ~= "VOTING" then
		votingFrame.Visible = false
	end
end)

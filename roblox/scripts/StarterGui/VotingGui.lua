-- VotingGui.lua
-- Paste as a LocalScript inside a ScreenGui named "VotingGui" in StarterGui.
-- Builds all UI in code — no manual frame creation needed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local screenGui   = script.Parent

-- ── Build UI ──────────────────────────────────────────────────────────────────
local votingFrame = Instance.new("Frame")
votingFrame.Name             = "VotingFrame"
votingFrame.Size             = UDim2.new(0, 400, 0, 500)
votingFrame.Position         = UDim2.new(0.5, -200, 0.5, -250)
votingFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
votingFrame.BackgroundTransparency = 0.05
votingFrame.BorderSizePixel  = 0
votingFrame.Visible          = false
votingFrame.Parent           = screenGui
Instance.new("UICorner", votingFrame).CornerRadius = UDim.new(0, 14)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size             = UDim2.new(1, 0, 0, 50)
titleLabel.Position         = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text             = "🗳 Vote Out the Scammer"
titleLabel.TextColor3       = Color3.new(1, 1, 1)
titleLabel.Font             = Enum.Font.GothamBold
titleLabel.TextSize         = 20
titleLabel.Parent           = votingFrame

local timerLabel = Instance.new("TextLabel")
timerLabel.Name             = "TimerLabel"
timerLabel.Size             = UDim2.new(1, 0, 0, 30)
timerLabel.Position         = UDim2.new(0, 0, 0, 50)
timerLabel.BackgroundTransparency = 1
timerLabel.Text             = "Time left: 30s"
timerLabel.TextColor3       = Color3.fromRGB(255, 180, 50)
timerLabel.Font             = Enum.Font.Gotham
timerLabel.TextSize         = 15
timerLabel.Parent           = votingFrame

local buttonHolder = Instance.new("Frame")
buttonHolder.Name            = "ButtonHolder"
buttonHolder.Size            = UDim2.new(1, -24, 1, -160)
buttonHolder.Position        = UDim2.new(0, 12, 0, 90)
buttonHolder.BackgroundTransparency = 1
buttonHolder.Parent          = votingFrame

local layout = Instance.new("UIListLayout")
layout.Padding         = UDim.new(0, 8)
layout.FillDirection   = Enum.FillDirection.Vertical
layout.SortOrder       = Enum.SortOrder.LayoutOrder
layout.Parent          = buttonHolder

local confirmLabel = Instance.new("TextLabel")
confirmLabel.Name           = "ConfirmLabel"
confirmLabel.Size           = UDim2.new(1, 0, 0, 30)
confirmLabel.Position       = UDim2.new(0, 0, 1, -40)
confirmLabel.BackgroundTransparency = 1
confirmLabel.Text           = ""
confirmLabel.TextColor3     = Color3.fromRGB(100, 220, 100)
confirmLabel.Font           = Enum.Font.GothamBold
confirmLabel.TextSize       = 15
confirmLabel.Visible        = false
confirmLabel.Parent         = votingFrame

-- ── Logic ─────────────────────────────────────────────────────────────────────
local OpenVotingUI = ReplicatedStorage:WaitForChild("OpenVotingUI", 10)
local SubmitVote   = ReplicatedStorage:WaitForChild("SubmitVote", 10)
local VoteResult   = ReplicatedStorage:WaitForChild("VoteResult", 10)
local PhaseChanged = ReplicatedStorage:WaitForChild("PhaseChanged", 10)

local voted = false
local VOTING_DURATION = 30

local function buildButtons(names)
	for _, c in ipairs(buttonHolder:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	for _, name in ipairs(names) do
		local btn = Instance.new("TextButton")
		btn.Size             = UDim2.new(1, 0, 0, 44)
		btn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
		btn.Text             = name
		btn.TextColor3       = Color3.new(1, 1, 1)
		btn.Font             = Enum.Font.GothamBold
		btn.TextSize         = 16
		btn.BorderSizePixel  = 0
		btn.Parent           = buttonHolder
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

		btn.Activated:Connect(function()
			if voted then return end
			voted = true
			SubmitVote:FireServer(name)
			confirmLabel.Text    = "✓ Voted: " .. name
			confirmLabel.Visible = true
			for _, b in ipairs(buttonHolder:GetChildren()) do
				if b:IsA("TextButton") then
					b.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
					b.Active = false
				end
			end
		end)
	end
end

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
	buildButtons(data.players)
	votingFrame.Visible = true
	task.spawn(startTimer, VOTING_DURATION)
end)

VoteResult.OnClientEvent:Connect(function(eliminated)
	timerLabel.Text = "❌ Eliminated: " .. eliminated
	task.delay(3, function() votingFrame.Visible = false end)
end)

PhaseChanged.OnClientEvent:Connect(function(phase)
	if phase ~= "VOTING" then votingFrame.Visible = false end
end)

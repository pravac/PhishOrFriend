-- EndScreenGui.lua
-- Place as a LocalScript inside a ScreenGui named "EndScreenGui" in StarterGui.
-- Create in Studio:
--
--   EndScreenGui (ScreenGui)
--   └── EndFrame (Frame, Visible=false, fills screen)
--       ├── TitleLabel       (TextLabel)  "Round Over — Here's What Happened"
--       ├── ScammedLabel     (TextLabel)  lists who got scammed
--       ├── AgentsLabel      (TextLabel)  reveals which NPCs were agents
--       ├── TacticsFrame     (Frame)      lesson cards container
--       │   └── (dynamically filled)
--       └── ContinueButton   (TextButton) "Play Again"

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")
local endGui       = playerGui:WaitForChild("EndScreenGui")
local endFrame     = endGui:WaitForChild("EndFrame")
local titleLabel   = endFrame:WaitForChild("TitleLabel")
local scammedLabel = endFrame:WaitForChild("ScammedLabel")
local agentsLabel  = endFrame:WaitForChild("AgentsLabel")
local tacticsFrame = endFrame:WaitForChild("TacticsFrame")
local continueBtn  = endFrame:WaitForChild("ContinueButton")

local ShowEndScreen = ReplicatedStorage:WaitForChild("ShowEndScreen", 10)
local PhaseChanged  = ReplicatedStorage:WaitForChild("PhaseChanged", 10)

endFrame.Visible = false

local TACTIC_INFO = {
	["urgency"] = {
		title  = "⏰ Urgency / Time Pressure",
		lesson = "Real systems never create sudden panic or demand immediate action through random characters. Take a breath. Slow down. Verify through official channels.",
		color  = Color3.fromRGB(220, 120, 30),
	},
	["authority impersonation"] = {
		title  = "🛡 Authority Impersonation",
		lesson = "Anyone can claim to be an admin. Real administrators do not approach you in-game to verify credentials. There is no such thing as a legit 'verification terminal' a stranger walks you to.",
		color  = Color3.fromRGB(60, 100, 200),
	},
}

local function buildTacticCard(tactic)
	local info = TACTIC_INFO[tactic] or {
		title  = tactic,
		lesson = "Be skeptical of anyone asking you to take unplanned actions.",
		color  = Color3.fromRGB(150, 150, 150),
	}

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -10, 0, 100)
	card.BackgroundColor3 = info.color
	card.BorderSizePixel = 0
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Parent = tacticsFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -10, 0, 30)
	titleLbl.Position = UDim2.new(0, 5, 0, 5)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = info.title
	titleLbl.TextColor3 = Color3.new(1, 1, 1)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = card

	local lessonLbl = Instance.new("TextLabel")
	lessonLbl.Size = UDim2.new(1, -10, 0, 60)
	lessonLbl.Position = UDim2.new(0, 5, 0, 38)
	lessonLbl.BackgroundTransparency = 1
	lessonLbl.Text = info.lesson
	lessonLbl.TextColor3 = Color3.new(1, 1, 1)
	lessonLbl.Font = Enum.Font.Gotham
	lessonLbl.TextSize = 13
	lessonLbl.TextWrapped = true
	lessonLbl.TextXAlignment = Enum.TextXAlignment.Left
	lessonLbl.AutomaticSize = Enum.AutomaticSize.Y
	lessonLbl.Parent = card
end

ShowEndScreen.OnClientEvent:Connect(function(data)
	-- Clear old tactic cards
	for _, child in ipairs(tacticsFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- Scammed players
	if #data.scammedPlayers > 0 then
		scammedLabel.Text = "🎣 Scammed: " .. table.concat(data.scammedPlayers, ", ")
	else
		scammedLabel.Text = "✅ Nobody got scammed this round!"
	end

	-- Revealed agents
	local agentLines = {}
	for _, agent in ipairs(data.agentsRevealed or {}) do
		table.insert(agentLines, agent.name .. " was a " .. agent.tactic .. " agent")
	end
	agentsLabel.Text = #agentLines > 0
		and ("🤖 Agents:\n" .. table.concat(agentLines, "\n"))
		or "No agents were active."

	-- Tactic lesson cards
	for _, tactic in ipairs(data.tacticsUsed or {}) do
		buildTacticCard(tactic)
	end

	endFrame.Visible = true
	endFrame.BackgroundTransparency = 1
	TweenService:Create(
		endFrame,
		TweenInfo.new(0.5),
		{ BackgroundTransparency = 0.05 }
	):Play()
end)

continueBtn.Activated:Connect(function()
	endFrame.Visible = false
end)

PhaseChanged.OnClientEvent:Connect(function(phase)
	if phase == "LOBBY" then
		endFrame.Visible = false
	end
end)

-- EndScreenGui.lua
-- Paste as a LocalScript inside a ScreenGui named "EndScreenGui" in StarterGui.
-- Builds all UI in code — no manual frame creation needed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local screenGui   = script.Parent

-- ── Build UI ──────────────────────────────────────────────────────────────────
local endFrame = Instance.new("Frame")
endFrame.Name             = "EndFrame"
endFrame.Size             = UDim2.new(0, 500, 0, 640)
endFrame.Position         = UDim2.new(0.5, -250, 0.5, -320)
endFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
endFrame.BackgroundTransparency = 0.05
endFrame.BorderSizePixel  = 0
endFrame.Visible          = false
endFrame.Parent           = screenGui
Instance.new("UICorner", endFrame).CornerRadius = UDim.new(0, 16)

local padding = Instance.new("UIPadding")
padding.PaddingLeft   = UDim.new(0, 16)
padding.PaddingRight  = UDim.new(0, 16)
padding.PaddingTop    = UDim.new(0, 16)
padding.PaddingBottom = UDim.new(0, 16)
padding.Parent        = endFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size             = UDim2.new(1, 0, 0, 40)
titleLabel.BackgroundTransparency = 1
titleLabel.Text             = "🔍 Round Over — Here's What Happened"
titleLabel.TextColor3       = Color3.new(1, 1, 1)
titleLabel.Font             = Enum.Font.GothamBold
titleLabel.TextSize         = 20
titleLabel.TextWrapped       = true
titleLabel.Parent           = endFrame

local scammedLabel = Instance.new("TextLabel")
scammedLabel.Name           = "ScammedLabel"
scammedLabel.Size           = UDim2.new(1, 0, 0, 30)
scammedLabel.Position       = UDim2.new(0, 0, 0, 50)
scammedLabel.BackgroundTransparency = 1
scammedLabel.Text           = ""
scammedLabel.TextColor3     = Color3.fromRGB(255, 120, 120)
scammedLabel.Font           = Enum.Font.GothamBold
scammedLabel.TextSize       = 15
scammedLabel.TextXAlignment = Enum.TextXAlignment.Left
scammedLabel.Parent         = endFrame

local agentsLabel = Instance.new("TextLabel")
agentsLabel.Name            = "AgentsLabel"
agentsLabel.Size            = UDim2.new(1, 0, 0, 50)
agentsLabel.Position        = UDim2.new(0, 0, 0, 88)
agentsLabel.BackgroundTransparency = 1
agentsLabel.Text            = ""
agentsLabel.TextColor3      = Color3.fromRGB(120, 180, 255)
agentsLabel.Font            = Enum.Font.Gotham
agentsLabel.TextSize        = 14
agentsLabel.TextXAlignment  = Enum.TextXAlignment.Left
agentsLabel.TextWrapped     = true
agentsLabel.Parent          = endFrame

local sensitiveInfoLabel = Instance.new("TextLabel")
sensitiveInfoLabel.Name             = "SensitiveInfoLabel"
sensitiveInfoLabel.Size             = UDim2.new(1, 0, 0, 50)
sensitiveInfoLabel.Position         = UDim2.new(0, 0, 0, 148)
sensitiveInfoLabel.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
sensitiveInfoLabel.BackgroundTransparency = 0.2
sensitiveInfoLabel.Text             = ""
sensitiveInfoLabel.TextColor3       = Color3.fromRGB(255, 220, 80)
sensitiveInfoLabel.Font             = Enum.Font.GothamBold
sensitiveInfoLabel.TextSize         = 13
sensitiveInfoLabel.TextWrapped      = true
sensitiveInfoLabel.TextXAlignment   = Enum.TextXAlignment.Left
sensitiveInfoLabel.Visible          = false
sensitiveInfoLabel.Parent           = endFrame
Instance.new("UICorner", sensitiveInfoLabel).CornerRadius = UDim.new(0, 8)
local siPad = Instance.new("UIPadding")
siPad.PaddingLeft = UDim.new(0, 10); siPad.PaddingRight = UDim.new(0, 10)
siPad.PaddingTop  = UDim.new(0, 6);  siPad.PaddingBottom = UDim.new(0, 6)
siPad.Parent = sensitiveInfoLabel

local tacticsFrame = Instance.new("Frame")
tacticsFrame.Name            = "TacticsFrame"
tacticsFrame.Size            = UDim2.new(1, 0, 0, 300)
tacticsFrame.Position        = UDim2.new(0, 0, 0, 208)
tacticsFrame.BackgroundTransparency = 1
tacticsFrame.Parent          = endFrame

local tacticsLayout = Instance.new("UIListLayout")
tacticsLayout.Padding      = UDim.new(0, 10)
tacticsLayout.FillDirection = Enum.FillDirection.Vertical
tacticsLayout.Parent       = tacticsFrame

local continueBtn = Instance.new("TextButton")
continueBtn.Name            = "ContinueButton"
continueBtn.Size            = UDim2.new(1, 0, 0, 44)
continueBtn.Position        = UDim2.new(0, 0, 1, -60)
continueBtn.BackgroundColor3 = Color3.fromRGB(50, 130, 50)
continueBtn.Text            = "▶  Play Again"
continueBtn.TextColor3      = Color3.new(1, 1, 1)
continueBtn.Font            = Enum.Font.GothamBold
continueBtn.TextSize        = 16
continueBtn.BorderSizePixel = 0
continueBtn.Parent          = endFrame
Instance.new("UICorner", continueBtn).CornerRadius = UDim.new(0, 10)

-- ── Tactic cards ──────────────────────────────────────────────────────────────
local TACTIC_INFO = {
	["urgency"] = {
		title  = "⏰ Urgency / Time Pressure",
		lesson = "Real systems never create sudden panic or demand immediate action through random characters. Take a breath — slow down — verify through official channels.",
		color  = Color3.fromRGB(180, 90, 20),
	},
	["authority impersonation"] = {
		title  = "🛡 Authority Impersonation",
		lesson = "Anyone can claim to be an admin. Real administrators don't approach you in-game to verify credentials. There is no such thing as a legit 'verification terminal' a stranger walks you to.",
		color  = Color3.fromRGB(40, 80, 180),
	},
}

local function buildTacticCard(tactic)
	local info = TACTIC_INFO[tactic] or {
		title  = tactic,
		lesson = "Be skeptical of anyone asking you to take unplanned actions.",
		color  = Color3.fromRGB(100, 100, 100),
	}

	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, 0, 0, 110)
	card.BackgroundColor3 = info.color
	card.BorderSizePixel  = 0
	card.AutomaticSize    = Enum.AutomaticSize.Y
	card.Parent           = tacticsFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local cp = Instance.new("UIPadding")
	cp.PaddingLeft = UDim.new(0, 10); cp.PaddingRight = UDim.new(0, 10)
	cp.PaddingTop  = UDim.new(0, 8);  cp.PaddingBottom = UDim.new(0, 8)
	cp.Parent = card

	local t = Instance.new("TextLabel")
	t.Size             = UDim2.new(1, 0, 0, 24)
	t.BackgroundTransparency = 1
	t.Text             = info.title
	t.TextColor3       = Color3.new(1, 1, 1)
	t.Font             = Enum.Font.GothamBold
	t.TextSize         = 15
	t.TextXAlignment   = Enum.TextXAlignment.Left
	t.Parent           = card

	local l = Instance.new("TextLabel")
	l.Size             = UDim2.new(1, 0, 0, 80)
	l.Position         = UDim2.new(0, 0, 0, 28)
	l.BackgroundTransparency = 1
	l.Text             = info.lesson
	l.TextColor3       = Color3.fromRGB(230, 230, 230)
	l.Font             = Enum.Font.Gotham
	l.TextSize         = 13
	l.TextWrapped      = true
	l.TextXAlignment   = Enum.TextXAlignment.Left
	l.AutomaticSize    = Enum.AutomaticSize.Y
	l.Parent           = card
end

-- ── Logic ─────────────────────────────────────────────────────────────────────
local ShowEndScreen = ReplicatedStorage:WaitForChild("ShowEndScreen", 10)
local PhaseChanged  = ReplicatedStorage:WaitForChild("PhaseChanged", 10)

ShowEndScreen.OnClientEvent:Connect(function(data)
	for _, c in ipairs(tacticsFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	scammedLabel.Text = #data.scammedPlayers > 0
		and ("🎣 Scammed: " .. table.concat(data.scammedPlayers, ", "))
		or  "✅ Nobody got scammed this round!"

	local lines = {}
	for _, a in ipairs(data.agentsRevealed or {}) do
		table.insert(lines, a.name .. " → " .. a.tactic)
	end
	agentsLabel.Text = #lines > 0
		and ("🤖 Agents:\n" .. table.concat(lines, "\n"))
		or  "No agents active."

	local myInfo = (data.sensitiveInfoShared or {})[localPlayer.Name]
	if myInfo and #myInfo > 0 then
		local unique, seen = {}, {}
		for _, v in ipairs(myInfo) do
			if not seen[v] then seen[v] = true; table.insert(unique, v) end
		end
		sensitiveInfoLabel.Text = "⚠ You shared sensitive info: " .. table.concat(unique, ", ") .. "\nNever give personal info to strangers in chat — online or in real life."
		sensitiveInfoLabel.Visible = true
	else
		sensitiveInfoLabel.Visible = false
	end

	for _, tactic in ipairs(data.tacticsUsed or {}) do
		buildTacticCard(tactic)
	end

	endFrame.Visible = true
	endFrame.BackgroundTransparency = 1
	TweenService:Create(endFrame, TweenInfo.new(0.5), { BackgroundTransparency = 0.05 }):Play()
end)

continueBtn.Activated:Connect(function() endFrame.Visible = false end)
PhaseChanged.OnClientEvent:Connect(function(phase)
	if phase == "LOBBY" then endFrame.Visible = false end
end)

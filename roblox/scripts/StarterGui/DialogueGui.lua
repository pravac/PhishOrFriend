-- DialogueGui.lua
-- Paste as a LocalScript inside a ScreenGui named "DialogueGui" in StarterGui.
-- Builds all UI in code — no manual frame creation needed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local screenGui   = script.Parent

-- ── Build UI ─────────────────────────────────────────────────────────────────
local dialogueFrame = Instance.new("Frame")
dialogueFrame.Name              = "DialogueFrame"
dialogueFrame.Size              = UDim2.new(0, 420, 0, 160)
dialogueFrame.Position          = UDim2.new(0.5, -210, 1, -180)
dialogueFrame.BackgroundColor3  = Color3.fromRGB(20, 20, 30)
dialogueFrame.BackgroundTransparency = 0.1
dialogueFrame.BorderSizePixel   = 0
dialogueFrame.Visible           = false
dialogueFrame.Parent            = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = dialogueFrame

local npcNameLabel = Instance.new("TextLabel")
npcNameLabel.Name          = "NPCNameLabel"
npcNameLabel.Size          = UDim2.new(1, -60, 0, 28)
npcNameLabel.Position      = UDim2.new(0, 12, 0, 10)
npcNameLabel.BackgroundTransparency = 1
npcNameLabel.Text          = "???"
npcNameLabel.TextColor3    = Color3.fromRGB(255, 80, 80)
npcNameLabel.Font          = Enum.Font.GothamBold
npcNameLabel.TextSize      = 16
npcNameLabel.TextXAlignment = Enum.TextXAlignment.Left
npcNameLabel.Parent        = dialogueFrame

local messageLabel = Instance.new("TextLabel")
messageLabel.Name          = "MessageLabel"
messageLabel.Size          = UDim2.new(1, -24, 0, 80)
messageLabel.Position      = UDim2.new(0, 12, 0, 42)
messageLabel.BackgroundTransparency = 1
messageLabel.Text          = ""
messageLabel.TextColor3    = Color3.new(1, 1, 1)
messageLabel.Font          = Enum.Font.Gotham
messageLabel.TextSize      = 14
messageLabel.TextWrapped   = true
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.TextYAlignment = Enum.TextYAlignment.Top
messageLabel.Parent        = dialogueFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name          = "TacticLabel"
hintLabel.Size          = UDim2.new(0.7, 0, 0, 20)
hintLabel.Position      = UDim2.new(0, 12, 1, -28)
hintLabel.BackgroundTransparency = 1
hintLabel.Text          = ""
hintLabel.TextColor3    = Color3.fromRGB(180, 180, 100)
hintLabel.Font          = Enum.Font.Gotham
hintLabel.TextSize      = 12
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent        = dialogueFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "CloseButton"
closeBtn.Size             = UDim2.new(0, 60, 0, 26)
closeBtn.Position         = UDim2.new(1, -70, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
closeBtn.Text             = "Dismiss"
closeBtn.TextColor3       = Color3.new(1, 1, 1)
closeBtn.Font             = Enum.Font.Gotham
closeBtn.TextSize         = 12
closeBtn.BorderSizePixel  = 0
closeBtn.Parent           = dialogueFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Scam alert banner
local scamAlert = Instance.new("Frame")
scamAlert.Name             = "ScamAlert"
scamAlert.Size             = UDim2.new(0, 360, 0, 80)
scamAlert.Position         = UDim2.new(0.5, -180, 0, 20)
scamAlert.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
scamAlert.BorderSizePixel  = 0
scamAlert.Visible          = false
scamAlert.Parent           = screenGui
Instance.new("UICorner", scamAlert).CornerRadius = UDim.new(0, 10)

local scamTacticLabel = Instance.new("TextLabel")
scamTacticLabel.Name       = "TacticLabel"
scamTacticLabel.Size       = UDim2.new(1, -16, 1, -8)
scamTacticLabel.Position   = UDim2.new(0, 8, 0, 4)
scamTacticLabel.BackgroundTransparency = 1
scamTacticLabel.Text       = "⚠ You were scammed!"
scamTacticLabel.TextColor3 = Color3.new(1, 1, 1)
scamTacticLabel.Font       = Enum.Font.GothamBold
scamTacticLabel.TextSize   = 16
scamTacticLabel.TextWrapped = true
scamTacticLabel.Parent     = scamAlert

-- ── Logic ─────────────────────────────────────────────────────────────────────
local ShowDialogue = ReplicatedStorage:WaitForChild("ShowDialogue", 10)
local HideDialogue = ReplicatedStorage:WaitForChild("HideDialogue", 10)

local function show(data)
	npcNameLabel.Text = data.npcName
	messageLabel.Text = data.message
	dialogueFrame.Visible = true
	dialogueFrame.Position = UDim2.new(0.5, -210, 1, -20)
	TweenService:Create(dialogueFrame, TweenInfo.new(0.3), {
		Position = UDim2.new(0.5, -210, 1, -180)
	}):Play()
end

local function hide()
	TweenService:Create(dialogueFrame, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5, -210, 1, -20)
	}):Play()
	task.delay(0.2, function() dialogueFrame.Visible = false end)
end

ShowDialogue.OnClientEvent:Connect(show)
HideDialogue.OnClientEvent:Connect(hide)
closeBtn.Activated:Connect(hide)

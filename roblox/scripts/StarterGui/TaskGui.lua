-- TaskGui.lua
-- Paste as a LocalScript inside a ScreenGui named "TaskGui" in StarterGui.
-- Builds all UI in code — no manual frame creation needed.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local screenGui   = script.Parent

-- ── Build UI ──────────────────────────────────────────────────────────────────
local topBar = Instance.new("Frame")
topBar.Name             = "TopBar"
topBar.Size             = UDim2.new(0, 280, 0, 54)
topBar.Position         = UDim2.new(0, 16, 0, 16)
topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
topBar.BackgroundTransparency = 0.2
topBar.BorderSizePixel  = 0
topBar.Parent           = screenGui
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)

local progressLabel = Instance.new("TextLabel")
progressLabel.Name          = "ProgressLabel"
progressLabel.Size          = UDim2.new(1, -12, 0, 22)
progressLabel.Position      = UDim2.new(0, 10, 0, 6)
progressLabel.BackgroundTransparency = 1
progressLabel.Text          = "Tasks: 0%"
progressLabel.TextColor3    = Color3.new(1, 1, 1)
progressLabel.Font          = Enum.Font.GothamBold
progressLabel.TextSize      = 14
progressLabel.TextXAlignment = Enum.TextXAlignment.Left
progressLabel.Parent        = topBar

local barBg = Instance.new("Frame")
barBg.Name             = "ProgressBar"
barBg.Size             = UDim2.new(1, -20, 0, 12)
barBg.Position         = UDim2.new(0, 10, 0, 32)
barBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
barBg.BorderSizePixel  = 0
barBg.Parent           = topBar
Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 6)

local fill = Instance.new("Frame")
fill.Name             = "Fill"
fill.Size             = UDim2.new(0, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(80, 210, 120)
fill.BorderSizePixel  = 0
fill.Parent           = barBg
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

local flashLabel = Instance.new("TextLabel")
flashLabel.Name          = "FlashLabel"
flashLabel.Size          = UDim2.new(0, 280, 0, 32)
flashLabel.Position      = UDim2.new(0, 16, 0, 76)
flashLabel.BackgroundTransparency = 1
flashLabel.Text          = ""
flashLabel.TextColor3    = Color3.fromRGB(100, 220, 100)
flashLabel.Font          = Enum.Font.GothamBold
flashLabel.TextSize      = 15
flashLabel.TextXAlignment = Enum.TextXAlignment.Left
flashLabel.Visible       = false
flashLabel.Parent        = screenGui

-- ── Logic ─────────────────────────────────────────────────────────────────────
local UpdateTaskProgress = ReplicatedStorage:WaitForChild("UpdateTaskProgress", 10)

UpdateTaskProgress.OnClientEvent:Connect(function(progress)
	fill.Size = UDim2.new(progress, 0, 1, 0)
	progressLabel.Text = "Tasks: " .. math.floor(progress * 100) .. "%"
end)

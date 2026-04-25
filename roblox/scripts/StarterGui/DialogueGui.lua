-- DialogueGui.lua
-- Place as a LocalScript inside a ScreenGui named "DialogueGui" in StarterGui.
-- Create the following UI hierarchy in Studio under this ScreenGui:
--
--   DialogueGui (ScreenGui)
--   └── DialogueFrame (Frame)
--       ├── NPCNameLabel (TextLabel)
--       ├── MessageLabel  (TextLabel)
--       ├── TacticLabel   (TextLabel)  -- small italic text, e.g. "Tactic: urgency"
--       └── CloseButton   (TextButton) -- "Dismiss"
--   └── ScamAlert (Frame, Visible=false)
--       ├── TacticLabel   (TextLabel)
--       └── (red background, centered)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local localPlayer   = Players.LocalPlayer
local playerGui     = localPlayer:WaitForChild("PlayerGui")
local dialogueGui   = playerGui:WaitForChild("DialogueGui")
local dialogueFrame = dialogueGui:WaitForChild("DialogueFrame")
local npcNameLabel  = dialogueFrame:WaitForChild("NPCNameLabel")
local messageLabel  = dialogueFrame:WaitForChild("MessageLabel")
local tacticLabel   = dialogueFrame:WaitForChild("TacticLabel")
local closeButton   = dialogueFrame:WaitForChild("CloseButton")

local ShowDialogue = ReplicatedStorage:WaitForChild("ShowDialogue", 10)
local HideDialogue = ReplicatedStorage:WaitForChild("HideDialogue", 10)

dialogueFrame.Visible = false

local function showFrame(npcName, message, tactic)
	npcNameLabel.Text = npcName
	messageLabel.Text = message
	tacticLabel.Text  = "(Hint: look for red flags!)"

	dialogueFrame.Visible = true
	dialogueFrame.BackgroundTransparency = 1
	TweenService:Create(
		dialogueFrame,
		TweenInfo.new(0.3),
		{ BackgroundTransparency = 0.1 }
	):Play()
end

local function hideFrame()
	TweenService:Create(
		dialogueFrame,
		TweenInfo.new(0.2),
		{ BackgroundTransparency = 1 }
	):Play()
	task.delay(0.2, function()
		dialogueFrame.Visible = false
	end)
end

ShowDialogue.OnClientEvent:Connect(function(data)
	showFrame(data.npcName, data.message, data.tactic)
end)

HideDialogue.OnClientEvent:Connect(hideFrame)

closeButton.Activated:Connect(hideFrame)

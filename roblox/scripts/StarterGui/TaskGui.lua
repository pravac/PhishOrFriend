-- TaskGui.lua
-- Place as a LocalScript inside a ScreenGui named "TaskGui" in StarterGui.
-- Create in Studio:
--
--   TaskGui (ScreenGui)
--   └── TopBar (Frame, top of screen)
--       ├── ProgressLabel  (TextLabel)  "Tasks: 0%"
--       ├── ProgressBar    (Frame)
--       │   └── Fill       (Frame, red/green bar)
--       └── FlashLabel     (TextLabel, Visible=false)  task complete flash

-- This script is intentionally minimal — all data updates come through
-- ClientController which already has the RemoteEvent listeners wired up.
-- Just ensure the UI hierarchy above exists in Studio.

local Players  = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")
local taskGui     = playerGui:WaitForChild("TaskGui")
local topBar      = taskGui:WaitForChild("TopBar")
local fill        = topBar:WaitForChild("ProgressBar"):WaitForChild("Fill")

fill.Size = UDim2.new(0, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(80, 200, 120)

-- MinimapController.client.lua
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer.PlayerGui

local MINIMAP_PX  = 180
local DOT_PX      = 8

-- ── Build GUI ─────────────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name = "MinimapGui"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size     = UDim2.new(0, MINIMAP_PX, 0, MINIMAP_PX)
frame.Position = UDim2.new(1, -MINIMAP_PX - 12, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
frame.BackgroundTransparency = 0.25
frame.BorderSizePixel = 0
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 14)
title.BackgroundTransparency = 1
title.Text = "MAP"
title.TextColor3 = Color3.fromRGB(180, 180, 180)
title.TextSize = 9
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- ── Detect map bounds from Tasks folder + workspace floor parts ───────────────
local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge

local function expandBounds(x, z)
	minX = math.min(minX, x); maxX = math.max(maxX, x)
	minZ = math.min(minZ, z); maxZ = math.max(maxZ, z)
end

local function worldToMap(x, z)
	local nx = (x - minX) / math.max(maxX - minX, 1)
	local nz = (z - minZ) / math.max(maxZ - minZ, 1)
	return UDim2.new(nx, 0, nz, 0)
end

-- ── Dot helpers ───────────────────────────────────────────────────────────────
local dots = {}

local function getDot(key, color, size)
	if not dots[key] then
		local d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.BorderSizePixel = 0
		d.ZIndex = 3
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
		d.Parent = frame
		dots[key] = d
	end
	local d = dots[key]
	d.BackgroundColor3 = color
	local s = size or DOT_PX
	d.Size = UDim2.new(0, s, 0, s)
	return d
end

local function hideDot(key)
	if dots[key] then dots[key].Visible = false end
end

-- ── Initialize task dots after map loads ─────────────────────────────────────
task.spawn(function()
	task.wait(3)

	-- Scan floor-level parts to get map bounds
	local FLOOR_Y = 22.058
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and math.abs(obj.Position.Y - FLOOR_Y) < 5
			and not Players:GetPlayerFromCharacter(obj.Parent) then
			expandBounds(obj.Position.X, obj.Position.Z)
		end
	end

	-- Fallback if scan found nothing
	if minX == math.huge then
		minX, maxX, minZ, maxZ = -150, 150, -150, 150
	end

	-- Draw static task dots
	local taskFolder = workspace:FindFirstChild("Tasks")
	if taskFolder then
		for _, t in ipairs(taskFolder:GetChildren()) do
			local pos = t:IsA("BasePart") and t.Position
				or (t:IsA("Model") and t.PrimaryPart and t.PrimaryPart.Position)
			if pos then
				local d = getDot("task_" .. t.Name, Color3.fromRGB(255, 210, 0), 7)
				d.Position = worldToMap(pos.X, pos.Z)
			end
		end
	end
end)

-- ── Live update: players + NPCs ───────────────────────────────────────────────
local NPC_NAMES = { Alex = true, Jordan = true }

RunService.Heartbeat:Connect(function()
	if minX == math.huge then return end

	local seen = {}

	-- Real players
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				local key = "p_" .. p.Name
				seen[key] = true
				local isMe = p == localPlayer
				local d = getDot(key, isMe and Color3.fromRGB(50, 180, 255) or Color3.fromRGB(230, 230, 230), isMe and 10 or DOT_PX)
				d.Position = worldToMap(root.Position.X, root.Position.Z)
				d.Visible = true
			end
		end
	end

	-- NPC dots — same white as other players so you can't tell them apart
	for name in pairs(NPC_NAMES) do
		local model = workspace:FindFirstChild(name)
		local key = "npc_" .. name
		if model then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then
				seen[key] = true
				local d = getDot(key, Color3.fromRGB(230, 230, 230), DOT_PX)
				d.Position = worldToMap(root.Position.X, root.Position.Z)
				d.Visible = true
			end
		end
	end

	-- Hide dots for players/NPCs no longer visible
	for key, dot in pairs(dots) do
		if key:sub(1, 2) == "p_" or key:sub(1, 4) == "npc_" then
			if not seen[key] then dot.Visible = false end
		end
	end
end)

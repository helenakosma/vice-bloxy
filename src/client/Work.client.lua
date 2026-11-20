-- Work panel: while you're on a shift, shows the employer, shift timer, the
-- current task and its steps, and what you've earned. For deliveries it also
-- marks the pickup or drop-off with a beam and a distance label.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Push = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Push")
local Request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request")

local C = Color3.fromRGB

local gui = Instance.new("ScreenGui")
gui.Name = "WorkPanel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 230)
panel.Size = UDim2.fromOffset(250, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = C(20, 22, 28)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local pad = Instance.new("UIPadding", panel)
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 10), UDim.new(0, 10)
local layout = Instance.new("UIListLayout", panel)
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local function label(order, size, colour, font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Font = font or Enum.Font.GothamMedium
	t.TextSize = size
	t.TextColor3 = colour
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.RichText = false
	t.Text = ""
	t.LayoutOrder = order
	t.Parent = panel
	return t
end

local header = label(1, 15, C(255, 255, 255), Enum.Font.GothamBlack)
local sub = label(2, 12, C(160, 166, 180))
local timer = label(3, 13, C(255, 210, 90), Enum.Font.GothamBold)
local taskLine = label(4, 13, C(255, 255, 255), Enum.Font.GothamBold)
local stepsBox = Instance.new("Frame")
stepsBox.BackgroundTransparency = 1
stepsBox.Size = UDim2.new(1, 0, 0, 0)
stepsBox.AutomaticSize = Enum.AutomaticSize.Y
stepsBox.LayoutOrder = 5
stepsBox.Parent = panel
Instance.new("UIListLayout", stepsBox).SortOrder = Enum.SortOrder.LayoutOrder
local money = label(6, 12, C(110, 220, 150))
local hint = label(7, 11, C(140, 146, 160))
hint.Text = "Clock out at the time clock, or End shift in the Jobs app."

-- Waypoint: a tall beam plus a billboard with the distance.
local beam = Instance.new("Part")
beam.Name = "WorkWaypoint"
beam.Anchored = true
beam.CanCollide = false
beam.CanQuery = false
beam.CanTouch = false
beam.CastShadow = false
beam.Material = Enum.Material.Neon
beam.Color = C(255, 200, 60)
beam.Transparency = 0.45
beam.Size = Vector3.new(1.5, 160, 1.5)
local ring = Instance.new("Part")
ring.Shape = Enum.PartType.Cylinder
ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
ring.Material = Enum.Material.Neon
ring.Color = C(255, 200, 60)
ring.Transparency = 0.5
ring.Size = Vector3.new(0.3, 22, 22)
local board = Instance.new("BillboardGui")
board.Size = UDim2.fromOffset(220, 46)
board.AlwaysOnTop = true
board.LightInfluence = 0
board.MaxDistance = math.huge
board.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
local boardText = Instance.new("TextLabel")
boardText.Size = UDim2.fromScale(1, 1)
boardText.BackgroundColor3 = C(20, 22, 28)
boardText.BackgroundTransparency = 0.2
boardText.TextColor3 = C(255, 220, 110)
boardText.Font = Enum.Font.GothamBold
boardText.TextSize = 14
boardText.TextWrapped = true
boardText.Parent = board
Instance.new("UICorner", boardText).CornerRadius = UDim.new(0, 8)
board.Adornee = ring

local state = { active = false }
local waypoint, waypointLabel = nil, ""

local function setWaypoint(pos, text)
	waypoint, waypointLabel = pos, text or ""
	if not pos then
		beam.Parent, ring.Parent, board.Parent = nil, nil, nil
		return
	end
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 80, 0))
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = Workspace
	ring.Parent = Workspace
	board.Parent = gui
end

local function renderSteps(steps)
	for _, c in ipairs(stepsBox:GetChildren()) do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local firstOpen = true
	for i, s in ipairs(steps or {}) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 0)
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.Font = Enum.Font.GothamMedium
		t.TextSize = 12
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		local current = not s.done and firstOpen
		if current then
			firstOpen = false
		end
		t.Text = (s.done and "✓  " or (current and "→  " or "•  ")) .. s.label
		t.TextColor3 = s.done and C(110, 220, 150) or (current and C(255, 255, 255) or C(160, 166, 180))
		t.LayoutOrder = i
		t.Parent = stepsBox
	end
end

local function apply(msg)
	state = msg
	panel.Visible = msg.active == true
	if not msg.active then
		setWaypoint(nil)
		return
	end
	header.Text = msg.employerName or "Work"
	sub.Text = msg.title or ""
	taskLine.Text = msg.task or ""
	renderSteps(msg.steps)
	local parts = {}
	if (msg.tips or 0) > 0 then
		table.insert(parts, "tips $" .. msg.tips)
	end
	if (msg.earned or 0) > 0 then
		table.insert(parts, "earned $" .. msg.earned)
	end
	table.insert(parts, (msg.tasks or 0) .. " task" .. (msg.tasks == 1 and "" or "s"))
	money.Text = table.concat(parts, " · ")
	setWaypoint(msg.waypoint, msg.waypointLabel)
end

Push.OnClientEvent:Connect(function(msg)
	if type(msg) == "table" and msg.type == "work" then
		apply(msg)
	end
end)

-- Shift timer and waypoint distance.
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then
		return
	end
	acc = 0
	if not state.active then
		return
	end
	if (state.length or 0) > 0 and state.started then
		local left = math.max(0, state.length - (Workspace:GetServerTimeNow() - state.started))
		timer.Text = string.format("Shift ends in %d:%02d", math.floor(left / 60), math.floor(left % 60))
	elseif state.started then
		local on = Workspace:GetServerTimeNow() - state.started
		timer.Text = string.format("On shift %d:%02d", math.floor(on / 60), math.floor(on % 60))
	end
	if waypoint then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local d = root and (root.Position - waypoint).Magnitude or 0
		boardText.Text = string.format("%s\n%d m", waypointLabel, math.floor(d / 3.5 + 0.5))
	end
end)

-- Pick up a shift that was already running (e.g. after the character respawns).
task.spawn(function()
	pcall(function()
		Request:InvokeServer("work.state", {})
	end)
end)

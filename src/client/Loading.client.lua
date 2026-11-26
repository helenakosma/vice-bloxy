-- A loading screen while the server builds the city: characters only load once
-- the world is ready and the spawn point is at the arrival place (Main.server:
-- ReplicatedStorage.WorldReady), so there's nothing to see until then.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Loading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.46)
title.Size = UDim2.new(0.8, 0, 0, 48)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(245, 240, 232)
title.Text = "TORONTO"
title.Parent = bg

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0.5)
sub.Position = UDim2.fromScale(0.5, 0.54)
sub.Size = UDim2.new(0.8, 0, 0, 22)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.GothamMedium
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(190, 184, 176)
sub.Text = "Building the city…"
sub.Parent = bg

gui.Parent = player:WaitForChild("PlayerGui")

local function ready()
	local v = ReplicatedStorage:FindFirstChild("WorldReady")
	return v and v.Value
end

-- Gentle dots while waiting.
task.spawn(function()
	local n = 0
	while gui.Parent and not ready() do
		n = n % 3 + 1
		sub.Text = "Building the city" .. string.rep(".", n)
		task.wait(0.5)
	end
end)

local value = ReplicatedStorage:WaitForChild("WorldReady", 120)
while value and not value.Value do
	value.Changed:Wait()
end
-- Wait for the character to arrive, then fade out.
if not player.Character then
	player.CharacterAdded:Wait()
end
task.wait(0.4)
local info = TweenInfo.new(0.8)
TweenService:Create(bg, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, info, { TextTransparency = 1 }):Play()
TweenService:Create(sub, info, { TextTransparency = 1 }):Play()
task.wait(0.9)
gui:Destroy()

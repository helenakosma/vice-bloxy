-- Small HUD pill pointing to the nearest subway entrance, with the distance.
-- Hidden once you're underground or standing at the entrance.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local IndoorZones = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("IndoorZones"))
local entrances = HttpService:JSONDecode(ReplicatedStorage:WaitForChild("SubwayEntrances").Value)
if #entrances == 0 then
	return
end

local gui = Instance.new("ScreenGui")
gui.Name = "SubwayGuide"
gui.ResetOnSpawn = false
local pill = Instance.new("Frame")
pill.AnchorPoint = Vector2.new(0.5, 0)
pill.Position = UDim2.new(0.5, 0, 0, 12)
pill.Size = UDim2.fromOffset(260, 34)
pill.BackgroundColor3 = Color3.fromRGB(206, 30, 40)
pill.BackgroundTransparency = 0.1
pill.Parent = gui
Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 10)
local arrow = Instance.new("TextLabel")
arrow.BackgroundTransparency = 1
arrow.Size = UDim2.fromOffset(34, 34)
arrow.Font = Enum.Font.GothamBlack
arrow.TextScaled = true
arrow.TextColor3 = Color3.new(1, 1, 1)
arrow.Text = "▲"
arrow.Parent = pill
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(36, 4)
label.Size = UDim2.new(1, -44, 1, -8)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = pill
gui.Parent = player:WaitForChild("PlayerGui")

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not root or not camera then
		pill.Visible = false
		return
	end
	local pos = root.Position
	local best, bestDist = nil, math.huge
	for _, e in ipairs(entrances) do
		local d = (Vector2.new(e.x, e.z) - Vector2.new(pos.X, pos.Z)).Magnitude
		if d < bestDist then
			best, bestDist = e, d
		end
	end
	pill.Visible = best ~= nil and pos.Y > -3 and bestDist > 10 and not IndoorZones.contains(pos)
	if not pill.Visible then
		return
	end
	local look = camera.CFrame.LookVector
	local toTarget = Vector2.new(best.x - pos.X, best.z - pos.Z)
	local angle = math.atan2(toTarget.Y, toTarget.X) - math.atan2(look.Z, look.X)
	arrow.Rotation = math.deg(angle)
	label.Text = string.format("SUBWAY · %s · %d m", best.name, math.floor(bestDist * 0.28))
end)

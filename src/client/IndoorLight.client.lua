-- Indoors (the Eaton Centre's zones, ReplicatedStorage.IndoorZones), the picture
-- is graded warmer and with more contrast, so the pale interiors don't wash out
-- under the daylight sky; it eases back outside. A local effect only: the
-- server's day cycle (World/Atmosphere) keeps its own settings.
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "IndoorGrade"
grade.Enabled = true
grade.Parent = Lighting

local INSIDE = { Brightness = -0.05, Contrast = 0.14, Saturation = 0.1, TintColor = Color3.fromRGB(255, 243, 226) }
local OUTSIDE = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 255, 255) }
local EASE = TweenInfo.new(1.2, Enum.EasingStyle.Sine)

local zones = {}
local function load()
	local v = ReplicatedStorage:FindFirstChild("IndoorZones")
	if v then
		local ok, list = pcall(HttpService.JSONDecode, HttpService, v.Value)
		zones = ok and list or {}
	end
end
ReplicatedStorage.ChildAdded:Connect(function(c)
	if c.Name == "IndoorZones" then
		load()
		c:GetPropertyChangedSignal("Value"):Connect(load)
	end
end)
load()

local function inside(p)
	for _, z in ipairs(zones) do
		if p.X >= z.minX and p.X <= z.maxX and p.Z >= z.minZ and p.Z <= z.maxZ and p.Y >= z.minY and p.Y <= z.maxY then
			return true
		end
	end
	return false
end

local was = nil
while true do
	task.wait(0.5)
	local cam = Workspace.CurrentCamera
	local now = cam ~= nil and inside(cam.CFrame.Position)
	if now ~= was then
		was = now
		TweenService:Create(grade, EASE, now and INSIDE or OUTSIDE):Play()
	end
end

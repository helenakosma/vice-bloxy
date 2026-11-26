-- Indoors (the Eaton Centre's zones, ReplicatedStorage.IndoorZones) the picture
-- is toned down: the server's day cycle (World/Atmosphere) sets a bloom and sun
-- rays meant for the street, which make the pale mall glow. On this client
-- those two effects are swapped for local copies that follow the server's
-- values outside and are much weaker inside, and a colour grade takes the
-- exposure down a little and warms it. Eases in and out at the doors.
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "IndoorGrade"
grade.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "LocalBloom"
bloom.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Name = "LocalRays"
rays.Parent = Lighting

-- Inside: grade, and how much of the street's bloom / rays is kept.
local IN = {
	brightness = -0.09,
	contrast = 0.16,
	saturation = 0.2,
	tint = Color3.fromRGB(255, 236, 214),
	bloomKeep = 0.3,
	bloomThreshold = 0.45, -- added: only real light sources bloom
	raysKeep = 0.15,
}

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

-- The server's own effects (Atmosphere names them Bloom and SunRays/Rays).
local function serverEffect(class)
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA(class) and c ~= bloom and c ~= rays then
			return c
		end
	end
	return nil
end

local mix = 0 -- 0 outside .. 1 inside
local check = 0
local isIn = false
RunService.RenderStepped:Connect(function(dt)
	check += dt
	if check > 0.3 then
		check = 0
		local cam = Workspace.CurrentCamera
		isIn = cam ~= nil and inside(cam.CFrame.Position)
	end
	local target = isIn and 1 or 0
	mix += math.clamp(target - mix, -dt / 1.2, dt / 1.2)

	local sb = serverEffect("BloomEffect")
	if sb then
		sb.Enabled = false -- the server never changes Enabled, so this stays
		bloom.Intensity = sb.Intensity * (1 - (1 - IN.bloomKeep) * mix)
		bloom.Size = sb.Size
		bloom.Threshold = sb.Threshold + IN.bloomThreshold * mix
	else
		bloom.Intensity = 0
	end
	local sr = serverEffect("SunRaysEffect")
	if sr then
		sr.Enabled = false
		rays.Intensity = sr.Intensity * (1 - (1 - IN.raysKeep) * mix)
		rays.Spread = sr.Spread
	else
		rays.Intensity = 0
	end
	-- At night the street's purple ambient leaks in; indoors (lit by its own
	-- lights) it's brightened a little and warmed instead of darkened.
	local clock = Lighting.ClockTime
	local night = 0
	if clock < 6 then
		night = math.clamp((6 - clock) / 1.5, 0, 1)
	elseif clock > 18.5 then
		night = math.clamp((clock - 18.5) / 1.5, 0, 1)
	end
	grade.Brightness = (IN.brightness + 0.16 * night) * mix
	grade.Contrast = IN.contrast * mix
	grade.Saturation = IN.saturation * mix
	grade.TintColor = Color3.new(1, 1, 1):Lerp(IN.tint:Lerp(Color3.fromRGB(255, 224, 190), night), mix)
end)

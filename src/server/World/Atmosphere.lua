-- Lighting and the day/night cycle.
--
-- Five looks (night, dawn, day, golden hour, dusk) are blended as the clock moves.
-- The flat look came from bright, grey ambient light filling every shadow; these
-- presets keep shadows cooler and darker than the warm sunlight (that contrast is
-- what gives depth), add sun glare, haze and a little depth of field.
-- Workspace gets a "Night" attribute that the client uses to switch on city lights.
--
-- For the best look set Lighting.Technology to Future in Studio.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Atmosphere = {}

local C = Color3.fromRGB

-- Keyframes by clock time (hours). Entries with only a name repeat that look.
local KEYS = {
	{
		time = 0, name = "night",
		-- A city never gets truly dark: the haze glows sodium-orange from the street
		-- lights below, and that glow fills every street (warm ambient, lifted exposure).
		brightness = 1.4, ambient = C(92, 84, 96), outdoor = C(118, 108, 128), shift = C(150, 150, 210), exposure = 0.35,
		atmo = { density = 0.3, color = C(150, 112, 100), decay = C(70, 56, 80), glare = 0, haze = 1.6 },
		bloom = { intensity = 0.55, size = 24, threshold = 1.35 },
		grade = { brightness = 0.03, contrast = 0.1, saturation = 0.14, tint = C(236, 230, 255) },
		rays = 0, clouds = C(118, 96, 104),
	},
	{ time = 5.4, name = "night" },
	{
		time = 6.7, name = "dawn",
		brightness = 1.9, ambient = C(92, 86, 104), outdoor = C(120, 108, 124), shift = C(255, 172, 140), exposure = 0.1,
		atmo = { density = 0.36, color = C(232, 192, 182), decay = C(120, 100, 132), glare = 0.4, haze = 2.2 },
		bloom = { intensity = 0.6, size = 24, threshold = 1.1 },
		grade = { brightness = 0, contrast = 0.12, saturation = 0.05, tint = C(255, 236, 228) },
		rays = 0.12, clouds = C(250, 214, 200),
	},
	{
		time = 9, name = "day",
		brightness = 3, ambient = C(98, 102, 114), outdoor = C(124, 126, 136), shift = C(255, 244, 228), exposure = 0,
		atmo = { density = 0.3, color = C(200, 202, 208), decay = C(110, 116, 132), glare = 0.15, haze = 1.4 },
		bloom = { intensity = 0.35, size = 24, threshold = 1.4 },
		grade = { brightness = 0, contrast = 0.1, saturation = 0.03, tint = C(255, 250, 246) },
		rays = 0.05, clouds = C(240, 240, 240),
	},
	{ time = 15.6, name = "day" },
	{
		time = 17.3, name = "golden",
		brightness = 3.3, ambient = C(76, 82, 106), outdoor = C(108, 98, 108), shift = C(255, 176, 110), exposure = 0.15,
		atmo = { density = 0.34, color = C(238, 198, 160), decay = C(140, 100, 92), glare = 0.65, haze = 2.3 },
		bloom = { intensity = 0.6, size = 26, threshold = 1.05 },
		grade = { brightness = 0, contrast = 0.16, saturation = 0.08, tint = C(255, 236, 218) },
		rays = 0.14, clouds = C(255, 214, 180),
	},
	{
		time = 18.6, name = "dusk",
		brightness = 1.6, ambient = C(70, 66, 98), outdoor = C(96, 80, 112), shift = C(255, 122, 112), exposure = 0.05,
		atmo = { density = 0.38, color = C(200, 132, 144), decay = C(90, 60, 102), glare = 0.5, haze = 2.4 },
		bloom = { intensity = 0.55, size = 22, threshold = 1.2 },
		grade = { brightness = 0, contrast = 0.14, saturation = 0.12, tint = C(255, 226, 232) },
		rays = 0.1, clouds = C(220, 140, 150),
	},
	{ time = 19.8, name = "night" },
	{ time = 24, name = "night" },
}

do
	local full = {}
	for _, key in ipairs(KEYS) do
		if key.brightness then
			full[key.name] = key
		end
	end
	for _, key in ipairs(KEYS) do
		if not key.brightness then
			for k, v in pairs(full[key.name]) do
				if k ~= "time" then
					key[k] = v
				end
			end
		end
	end
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpTable(a, b, t)
	local out = {}
	for k, v in pairs(a) do
		if typeof(v) == "number" then
			out[k] = lerp(v, b[k], t)
		else
			out[k] = v:Lerp(b[k], t)
		end
	end
	return out
end

local function blend(clock)
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if clock >= a.time and clock <= b.time then
			local t = (clock - a.time) / math.max(b.time - a.time, 1e-3)
			t = t * t * (3 - 2 * t)
			return {
				brightness = lerp(a.brightness, b.brightness, t),
				ambient = a.ambient:Lerp(b.ambient, t),
				outdoor = a.outdoor:Lerp(b.outdoor, t),
				shift = a.shift:Lerp(b.shift, t),
				exposure = lerp(a.exposure, b.exposure, t),
				atmo = lerpTable(a.atmo, b.atmo, t),
				bloom = lerpTable(a.bloom, b.bloom, t),
				grade = lerpTable(a.grade, b.grade, t),
				rays = lerp(a.rays, b.rays, t),
				clouds = a.clouds:Lerp(b.clouds, t),
			}
		end
	end
	return blend(0)
end

local effects = {}

local function ensure(className, name, parent)
	parent = parent or Lighting
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local obj = Instance.new(className)
	obj.Name = name
	obj.Parent = parent
	return obj
end

local function applyLook(look)
	Lighting.Brightness = look.brightness
	Lighting.Ambient = look.ambient
	Lighting.OutdoorAmbient = look.outdoor
	Lighting.ColorShift_Top = look.shift
	Lighting.ExposureCompensation = look.exposure

	local a = effects.atmosphere
	a.Density = look.atmo.density
	a.Color = look.atmo.color
	a.Decay = look.atmo.decay
	a.Glare = look.atmo.glare
	a.Haze = look.atmo.haze

	effects.bloom.Intensity = look.bloom.intensity
	effects.bloom.Size = look.bloom.size
	effects.bloom.Threshold = look.bloom.threshold

	local g = effects.grade
	g.Brightness = look.grade.brightness
	g.Contrast = look.grade.contrast
	g.Saturation = look.grade.saturation
	g.TintColor = look.grade.tint

	effects.rays.Intensity = look.rays
	effects.clouds.Color = look.clouds
end

local function isNight(clock)
	return clock >= 19.2 or clock < 6.2
end

function Atmosphere.apply()
	Lighting.GeographicLatitude = 40.7
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.12
	Lighting.ColorShift_Bottom = C(40, 34, 30)

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	effects.atmosphere = ensure("Atmosphere", "CityHaze")
	effects.atmosphere.Offset = 0.12
	effects.bloom = ensure("BloomEffect", "Bloom")
	effects.rays = ensure("SunRaysEffect", "SunRays")
	effects.rays.Spread = 0.75
	effects.grade = ensure("ColorCorrectionEffect", "Grade")
	local depth = ensure("DepthOfFieldEffect", "Depth")
	depth.FarIntensity = 0.05
	depth.FocusDistance = 120
	depth.InFocusRadius = 260
	depth.NearIntensity = 0
	effects.clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	effects.clouds.Cover = 0.58
	effects.clouds.Density = 0.6
	effects.clouds.Parent = Workspace.Terrain

	local start = Config.DayNight.StartTime
	Lighting.ClockTime = start
	applyLook(blend(start))
	Workspace:SetAttribute("Night", isNight(start))
end

-- Runs the clock. With DayNight.Enabled = false the time stays at StartTime.
function Atmosphere.startCycle()
	local settings = Config.DayNight
	if not settings.Enabled then
		return
	end
	local hoursPerSecond = 24 / (settings.DayLengthMinutes * 60)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local clock = (Lighting.ClockTime + (now - last) * hoursPerSecond) % 24
			last = now
			Lighting.ClockTime = clock
			applyLook(blend(clock))
			local night = isNight(clock)
			if Workspace:GetAttribute("Night") ~= night then
				Workspace:SetAttribute("Night", night)
			end
		end
	end)
end

return Atmosphere

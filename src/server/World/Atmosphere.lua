-- Late-afternoon New York light: low warm sun, grey-brown haze, soft clouds.
-- For the best look set Lighting.Technology to Future in Studio (scripts can't set it).
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Atmosphere = {}

local function replace(className, name)
	local old = Lighting:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local obj = Instance.new(className)
	obj.Name = name
	return obj
end

function Atmosphere.apply()
	Lighting.ClockTime = 16.9
	Lighting.GeographicLatitude = 40.7
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(88, 84, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 122, 114)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 214, 170)
	Lighting.ColorShift_Bottom = Color3.fromRGB(40, 35, 30)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.2
	Lighting.ExposureCompensation = 0.1

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	local atmosphere = replace("Atmosphere", "CityHaze")
	atmosphere.Density = 0.34
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(199, 188, 172)
	atmosphere.Decay = Color3.fromRGB(110, 98, 86)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.8
	atmosphere.Parent = Lighting

	local bloom = replace("BloomEffect", "Bloom")
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local rays = replace("SunRaysEffect", "SunRays")
	rays.Intensity = 0.05
	rays.Spread = 0.7
	rays.Parent = Lighting

	local grade = replace("ColorCorrectionEffect", "Grade")
	grade.Saturation = -0.18
	grade.Contrast = 0.08
	grade.Brightness = 0.01
	grade.TintColor = Color3.fromRGB(255, 244, 228)
	grade.Parent = Lighting

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.6
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(222, 212, 200)
	clouds.Parent = Workspace.Terrain
end

return Atmosphere

-- City lights after dark. The server sets Workspace's "Night" attribute; when it
-- flips, windows tagged "NightWindow" switch between their daytime glass and a
-- glowing lit-room colour (mostly warm, some cool white, the odd TV blue).
-- Each window remembers its daytime look so it can switch back at dawn.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WARM = {
	Color3.fromRGB(255, 214, 150),
	Color3.fromRGB(255, 196, 128),
	Color3.fromRGB(255, 226, 176),
	Color3.fromRGB(240, 236, 220),
	Color3.fromRGB(150, 180, 255),
}

local saved = {} -- part -> daytime look

local function lightColour(part)
	-- Stable per window, so a window keeps its colour every night.
	local p = part.Position
	local h = math.abs(math.floor(p.X * 7 + p.Y * 13 + p.Z * 3)) % 20
	if h == 0 then
		return WARM[5]
	elseif h < 4 then
		return WARM[4]
	end
	return WARM[(h % 3) + 1]
end

local function setLit(part, lit)
	if lit then
		if not saved[part] then
			local decals = {}
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Decal") then
					decals[child] = child.Transparency
					child.Transparency = 1
				end
			end
			saved[part] = { material = part.Material, color = part.Color, reflectance = part.Reflectance, decals = decals }
		end
		part.Material = Enum.Material.Neon
		part.Color = lightColour(part)
		part.Reflectance = 0
	else
		local look = saved[part]
		if look then
			part.Material = look.material
			part.Color = look.color
			part.Reflectance = look.reflectance
			for decal, transparency in pairs(look.decals) do
				if decal.Parent then
					decal.Transparency = transparency
				end
			end
			saved[part] = nil
		end
	end
end

local function refresh()
	local night = Workspace:GetAttribute("Night") == true
	local count = 0
	for _, part in ipairs(CollectionService:GetTagged("NightWindow")) do
		setLit(part, night)
		count = count + 1
		if count % 400 == 0 then
			task.wait() -- spread the work over a few frames
		end
	end
end

Workspace:GetAttributeChangedSignal("Night"):Connect(refresh)
CollectionService:GetInstanceAddedSignal("NightWindow"):Connect(function(part)
	if Workspace:GetAttribute("Night") == true then
		setLit(part, true)
	end
end)
CollectionService:GetInstanceRemovedSignal("NightWindow"):Connect(function(part)
	saved[part] = nil
end)
refresh()

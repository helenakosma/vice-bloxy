-- Procedurally builds a neon sunset coast city: sea, beach, road grid, city blocks,
-- palm trees and a pink-and-teal evening sky. Everything is anchored static geometry.
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Map = {}

local PINK = Color3.fromRGB(255, 61, 154)
local TEAL = Color3.fromRGB(38, 224, 255)
local PURPLE = Color3.fromRGB(150, 80, 255)
local TRIMS = { PINK, TEAL, PURPLE }
local PASTELS = {
	Color3.fromRGB(255, 160, 200),
	Color3.fromRGB(150, 235, 235),
	Color3.fromRGB(255, 205, 160),
	Color3.fromRGB(200, 170, 255),
	Color3.fromRGB(255, 240, 200),
}

local ROAD_WIDTH = 24
local SPACING = 100
local ROADS = { -200, -100, 0, 100, 200 } -- grid lines on both axes
local LAND_MIN, LAND_MAX = -300, 260 -- land extent (x runs on to the beach)
local SAND_END, SEA_END = 330, 900
local DEPTH = 600 -- land extent along Z

local function part(parent, name, size, cframe, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function setupLighting()
	Lighting.ClockTime = 17 -- golden hour: low sun, still bright
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(170, 120, 190)
	Lighting.OutdoorAmbient = Color3.fromRGB(200, 150, 210)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 150, 190)
	Lighting.ExposureCompensation = 0.4

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Color = Color3.fromRGB(255, 170, 200)
	atmo.Decay = Color3.fromRGB(255, 90, 160)
	atmo.Glare = 0.4
	atmo.Haze = 1.5
	atmo.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.5
	bloom.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromRGB(255, 235, 250)
	cc.Parent = Lighting
end

local function buildTerrain(folder)
	local width = LAND_MAX - LAND_MIN
	part(folder, "Ground", Vector3.new(width, 2, DEPTH), CFrame.new((LAND_MIN + LAND_MAX) / 2, -1, 0), Color3.fromRGB(120, 110, 140))
	part(folder, "Sand", Vector3.new(SAND_END - LAND_MAX, 2, DEPTH), CFrame.new((LAND_MAX + SAND_END) / 2, -1, 0), Color3.fromRGB(255, 225, 175), Enum.Material.Sand)

	local seaSize = Vector3.new(SEA_END - SAND_END, 2, DEPTH + 400)
	local sea = part(folder, "Sea", seaSize, CFrame.new((SAND_END + SEA_END) / 2, -2.5, 0), Color3.fromRGB(30, 160, 220), Enum.Material.Glass)
	sea.Transparency = 0.25
	-- Seabed so players can wade out but not fall forever.
	part(folder, "Seabed", seaSize, CFrame.new((SAND_END + SEA_END) / 2, -6, 0), Color3.fromRGB(200, 180, 140))

	-- Invisible walls around the playable area.
	local h = 200
	local midX = (SEA_END + LAND_MIN) / 2
	local spanX = SEA_END - LAND_MIN
	local halfZ = DEPTH / 2 + 200
	local walls = {
		{ Vector3.new(2, h, DEPTH + 400), CFrame.new(SEA_END, h / 2, 0) },
		{ Vector3.new(2, h, DEPTH + 400), CFrame.new(LAND_MIN, h / 2, 0) },
		{ Vector3.new(spanX, h, 2), CFrame.new(midX, h / 2, halfZ) },
		{ Vector3.new(spanX, h, 2), CFrame.new(midX, h / 2, -halfZ) },
	}
	for _, w in ipairs(walls) do
		local p = part(folder, "Wall", w[1], w[2], Color3.new(0, 0, 0))
		p.Transparency = 1
	end
end

local function buildRoads(folder)
	local asphalt = Color3.fromRGB(70, 70, 88)
	local lineColor = Color3.fromRGB(255, 220, 90)
	local xLength = LAND_MAX - LAND_MIN
	for _, r in ipairs(ROADS) do
		part(folder, "RoadZ", Vector3.new(ROAD_WIDTH, 0.1, DEPTH), CFrame.new(r, 0.05, 0), asphalt, Enum.Material.Asphalt)
		part(folder, "RoadX", Vector3.new(xLength, 0.1, ROAD_WIDTH), CFrame.new((LAND_MIN + LAND_MAX) / 2, 0.06, r), asphalt, Enum.Material.Asphalt)
	end
	-- Dashed centre lines, skipped at intersections.
	for _, r in ipairs(ROADS) do
		for t = LAND_MIN + 10, LAND_MAX - 10, 16 do
			local atIntersection = false
			for _, o in ipairs(ROADS) do
				if math.abs(t - o) < ROAD_WIDTH / 2 + 4 then
					atIntersection = true
				end
			end
			if not atIntersection then
				part(folder, "Dash", Vector3.new(0.6, 0.05, 6), CFrame.new(r, 0.13, t), lineColor, nil, false)
				part(folder, "Dash", Vector3.new(6, 0.05, 0.6), CFrame.new(t, 0.14, r), lineColor, nil, false)
			end
		end
	end
end

local function buildPalm(folder, x, z, rng)
	local height = rng:NextNumber(14, 22)
	local lean = math.rad(rng:NextNumber(-6, 6))
	part(folder, "PalmTrunk", Vector3.new(1.4, height, 1.4), CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, lean), Color3.fromRGB(150, 105, 70), Enum.Material.Wood)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		local cf = CFrame.new(x, height, z) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -1, -5) * CFrame.Angles(math.rad(-20), 0, 0)
		part(folder, "PalmLeaf", Vector3.new(0.4, 0.3, 11), cf, Color3.fromRGB(60, 200, 120), Enum.Material.Grass, false)
	end
end

local function buildBuilding(folder, cx, cz, sx, sz, height, color, rng)
	local trim = TRIMS[rng:NextInteger(1, #TRIMS)]
	part(folder, "Building", Vector3.new(sx, height, sz), CFrame.new(cx, height / 2 + 0.5, cz), color, Enum.Material.SmoothPlastic)

	-- Window bands: dark glass strips every few floors with a warm lit strip beside each.
	local y = 6
	while y < height - 4 do
		local band = part(folder, "Windows", Vector3.new(sx + 0.3, 2.2, sz + 0.3), CFrame.new(cx, y + 0.5, cz), Color3.fromRGB(35, 45, 85), Enum.Material.Glass, false)
		band.Transparency = 0.15
		if rng:NextNumber() < 0.35 then
			part(folder, "LitWindows", Vector3.new(sx + 0.4, 1.2, sz + 0.4), CFrame.new(cx, y + 0.5, cz), Color3.fromRGB(255, 220, 140), Enum.Material.Neon, false)
		end
		y += 6
	end

	-- Vertical neon corner strips.
	for _, sxSign in ipairs({ -1, 1 }) do
		for _, szSign in ipairs({ -1, 1 }) do
			part(folder, "NeonEdge", Vector3.new(0.6, height, 0.6), CFrame.new(cx + sxSign * sx / 2, height / 2 + 0.5, cz + szSign * sz / 2), trim, Enum.Material.Neon, false)
		end
	end

	-- Roof trim plus a smaller upper tier on taller towers.
	part(folder, "NeonRoof", Vector3.new(sx + 1, 1, sz + 1), CFrame.new(cx, height + 1, cz), trim, Enum.Material.Neon, false)
	if height > 50 then
		part(folder, "Tier", Vector3.new(sx * 0.6, 14, sz * 0.6), CFrame.new(cx, height + 8, cz), color, Enum.Material.SmoothPlastic)
		part(folder, "TierTrim", Vector3.new(sx * 0.6 + 1, 1, sz * 0.6 + 1), CFrame.new(cx, height + 15.5, cz), trim, Enum.Material.Neon, false)
	end
end

local function buildBlocks(folder, rng)
	local blockSize = SPACING - ROAD_WIDTH
	local centres = { -250, -150, -50, 50, 150 } -- midway between road lines
	for _, cx in ipairs(centres) do
		for _, cz in ipairs(centres) do
			local isPromenade = cx == 150 -- the column beside the coast road becomes a palm promenade
			local slabColor = isPromenade and Color3.fromRGB(255, 235, 205) or Color3.fromRGB(150, 150, 165)
			part(folder, "Block", Vector3.new(blockSize, 0.5, blockSize), CFrame.new(cx, 0.25, cz), slabColor, Enum.Material.Concrete)

			if isPromenade then
				for _ = 1, 5 do
					buildPalm(folder, cx + rng:NextNumber(-28, 28), cz + rng:NextNumber(-28, 28), rng)
				end
			else
				local count = rng:NextInteger(1, 3)
				local half = blockSize / 2 - 4
				for i = 1, count do
					local shrink = count > 1 and 1.4 or 1
					local sx = rng:NextNumber(22, 36) / shrink
					local sz = rng:NextNumber(22, 36) / shrink
					local ox = count == 1 and 0 or ((i - (count + 1) / 2) * (blockSize / count))
					local oz = count == 1 and 0 or rng:NextNumber(-8, 8)
					ox = math.clamp(ox, -half + sx / 2, half - sx / 2)
					buildBuilding(folder, cx + ox, cz + oz, sx, sz, rng:NextNumber(18, 90), PASTELS[rng:NextInteger(1, #PASTELS)], rng)
				end
			end
		end
	end
end

function Map.build()
	-- Clear default template geometry that would clash with the city.
	for _, child in ipairs(Workspace:GetChildren()) do
		if child.Name == "Baseplate" or child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "ViceMap"
	folder.Parent = Workspace

	local rng = Random.new(1986) -- fixed seed: same city every server

	setupLighting()
	buildTerrain(folder)
	buildRoads(folder)
	buildBlocks(folder, rng)

	-- Beach palms along the sand.
	for z = -280, 280, 40 do
		buildPalm(folder, SAND_END - 30 + rng:NextNumber(-8, 8), z, rng)
	end

	-- Spawn on the central road so players land next to the cars.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.6, -12)
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = Workspace
end

return Map

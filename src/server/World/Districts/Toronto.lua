-- Toronto (Phase 5 master layout): Yonge Street from the harbour to Steeles, with
-- the real cross streets at their real (scaled) positions and Line 1 underneath.
-- See World/TorontoLayout.lua for the scale and every position.
--
-- This is the Stage 2 skeleton: streets, landmark sites and the existing
-- landmarks moved into place. Buildings are placeholders sized by neighbourhood:
-- detailed Toronto styles around each station on Yonge and in the Financial
-- District, simple houses in the low-density areas (York Mills, Lawrence,
-- Summerhill, Rosedale), and plain massing blocks elsewhere. Stages 3-5 replace
-- them neighbourhood by neighbourhood.
local World = script.Parent.Parent
local Util = require(World.Util)
local Roads = require(World.Roads)
local Buildings = require(World.Buildings)
local Props = require(World.Props)
local TorontoStyles = require(World.TorontoStyles)
local TorontoLandmarks = require(World.TorontoLandmarks)
local TorontoLayout = require(World.TorontoLayout)
local Mall = require(World.Mall)
local DowntownLandmarks = require(World.DowntownLandmarks)
local EatonCentre = require(World.EatonCentre)

local T = TorontoLayout

local Toronto = {
	name = "Toronto",
	bounds = T.BOUNDS,
	budget = 90000,
}

local V3 = Vector3.new
local M = Enum.Material
local CONCRETE = Color3.fromRGB(206, 202, 194)

local NEEDLE_RADIUS = 42
local DOME_RADIUS = 52
local MALL_SIZE = Vector2.new(190, 140)

-- Marks only cells that are still free (roads keep their cells).
local function claimFree(rect, value)
	for x = rect.minX, rect.maxX, 4 do
		for z = rect.minZ, rect.maxZ, 4 do
			if Util.get(x, z) == Util.FREE then
				Util.set(x, z, value)
			end
		end
	end
end

local function overlapsX(rect, z, pad)
	return z > rect.minZ - pad and z < rect.maxZ + pad
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
function Toronto.layout(ctx)
	local b = Toronto.bounds
	local rng = ctx.rng
	-- Land in tiles (a part can't be longer than 2048 studs).
	local tilesX, tilesZ = 2, 5
	local tw, td = (b.maxX - b.minX) / tilesX, (b.maxZ - b.minZ) / tilesZ
	for i = 0, tilesX - 1 do
		for j = 0, tilesZ - 1 do
			Util.land(ctx.folder, b.minX + i * tw, b.minX + (i + 1) * tw, b.minZ + j * td, b.minZ + (j + 1) * td, Color3.fromRGB(104, 102, 96))
		end
	end

	local roads = {}
	ctx.named = {}
	local function add(name, kind, points)
		local road = Roads.add(kind, points)
		road.name = name
		ctx.named[name] = road
		table.insert(roads, road)
		return road
	end

	-- Bridges from the other city's avenues across the harbour to Queens Quay.
	for _, ending in ipairs(Roads.avenueEnds(ctx.shared.downtownRoads, "north")) do
		local x = ending.point.X
		if ending.road.kind == "avenue" and x > b.minX + 80 and x < b.maxX - 80 then
			add("Harbour Bridge " .. math.floor(x), "bridge", { Vector2.new(x, Util.MIN_Z), Vector2.new(x, b.maxZ - 5) })
		end
	end

	-- The named grid: east-west streets, then north-south ones.
	for _, s in ipairs(T.EAST_WEST) do
		add(s[1], s[3], { Vector2.new(s[4], s[2]), Vector2.new(s[5], s[2]) })
	end
	for _, s in ipairs(T.NORTH_SOUTH) do
		local pts = {}
		for _, p in ipairs(s[3]) do
			table.insert(pts, Vector2.new(p[1], p[2]))
		end
		add(s[1], s[2], pts)
	end

	-- Residential side streets in the north and midtown, between the named ones,
	-- from Bathurst to Bayview; they wind a little and stop short of the big sites.
	local zs = {}
	for _, s in ipairs(T.EAST_WEST) do
		table.insert(zs, s[2])
	end
	table.sort(zs)
	local avoid = { T.MOUNT_PLEASANT_CEMETERY, T.MEL_LASTMAN, {
		minX = T.YONGE_EGLINTON_CENTRE.X - MALL_SIZE.X / 2, maxX = T.YONGE_EGLINTON_CENTRE.X + MALL_SIZE.X / 2,
		minZ = T.YONGE_EGLINTON_CENTRE.Y - MALL_SIZE.Y / 2, maxZ = T.YONGE_EGLINTON_CENTRE.Y + MALL_SIZE.Y / 2,
	} }
	local sideCount = 0
	for i = 1, #zs - 1 do
		local z0, z1 = zs[i], zs[i + 1]
		if T.zoneAt((z0 + z1) / 2) ~= "downtown" and z1 - z0 > 300 then
			local n = math.floor((z1 - z0) / 175)
			for k = 1, n - 1 do
				local z = z0 + (z1 - z0) * k / n
				if math.abs(z - T.HWY401_Z) > 70 then
					local segments = { { -630, 830 } }
					for _, rect in ipairs(avoid) do
						if overlapsX(rect, z, 30) then
							local nextSegs = {}
							for _, seg in ipairs(segments) do
								if seg[1] < rect.minX - 20 then
									table.insert(nextSegs, { seg[1], math.min(seg[2], rect.minX - 20) })
								end
								if seg[2] > rect.maxX + 20 then
									table.insert(nextSegs, { math.max(seg[1], rect.maxX + 20), seg[2] })
								end
							end
							segments = nextSegs
						end
					end
					for _, seg in ipairs(segments) do
						if seg[2] - seg[1] > 120 then
							sideCount = sideCount + 1
							add("Side St " .. sideCount, "residential", Roads.path(rng, Vector2.new(seg[1], z), Vector2.new(seg[2], z), 130, 3))
						end
					end
				end
			end
		end
	end

	Roads.rasterize(roads)
	ctx.roads = roads

	-- Reserve the landmark sites so nothing else is built on them.
	local function reserveCircle(c, r)
		Util.markRect(c.X - r, c.X + r, c.Y - r, c.Y + r, Util.BUILT)
	end
	reserveCircle(T.NEEDLE, NEEDLE_RADIUS)
	reserveCircle(T.DOME, DOME_RADIUS + 6)
	Util.markRect(T.UNION.X - 52, T.UNION.X + 52, T.UNION.Y - 30, T.UNION.Y + 34, Util.BUILT)
	claimFree(T.CITY_HALL, Util.BUILT)
	Util.markRect(T.ROM.X - 34, T.ROM.X + 34, T.ROM.Y - 44, T.ROM.Y + 44, Util.BUILT)
	for _, t in ipairs(T.NY_TOWERS) do
		reserveCircle(t, 26)
	end
	local m = T.YONGE_EGLINTON_CENTRE
	Util.markRect(m.X - MALL_SIZE.X / 2, m.X + MALL_SIZE.X / 2, m.Y - MALL_SIZE.Y / 2, m.Y + MALL_SIZE.Y / 2, Util.BUILT)
	claimFree(T.EATON, Util.BUILT)
	EatonCentre.layout(T.EATON) -- dig out the concourse before the ground is built
	claimFree(T.SANKOFA, Util.PARK)
	for _, rect in ipairs({ T.DUNDAS_NE, T.DUNDAS_NW, T.TMU_SLC, T.TMU_KERR, T.TMU_SOUTH, T.UOFT_SOUTH, T.UOFT_NORTH }) do
		claimFree(rect, Util.BUILT)
	end
	claimFree(T.MEL_LASTMAN, Util.PARK)
	claimFree(T.MOUNT_PLEASANT_CEMETERY, Util.PARK)
end

---------------------------------------------------------------------------
-- Landmarks
---------------------------------------------------------------------------
-- The Needle: tapering concrete shaft with three fins, a wide observation pod,
-- a small sky pod and a red-and-white antenna mast.
local function needle(folder, c)
	local x, z = c.X, c.Y
	local base = CFrame.new(x, 0.3, z)
	Util.cylinder(folder, 0.4, NEEDLE_RADIUS * 2, base * CFrame.new(0, 0.2, 0), Color3.fromRGB(170, 166, 158), M.Pavement, true)
	local shaftTop = 330
	local sections = 8
	for i = 0, sections - 1 do
		local y0 = shaftTop * i / sections
		local y1 = shaftTop * (i + 1) / sections
		local dia = 24 - 11 * (i / sections)
		Util.cylinder(folder, y1 - y0 + 0.2, dia, base * CFrame.new(0, (y0 + y1) / 2, 0), CONCRETE, M.Concrete, true)
	end
	for k = 0, 2 do
		local yaw = CFrame.Angles(0, k * math.pi * 2 / 3, 0)
		for i = 0, 3 do
			local y0 = 220 * i / 4
			local y1 = 220 * (i + 1) / 4
			local reach = 30 - 22 * (i / 4)
			Util.solid(folder, V3(6, y1 - y0 + 0.2, reach), base * yaw * CFrame.new(0, (y0 + y1) / 2, -reach / 2), CONCRETE, M.Concrete)
		end
	end
	local pod = shaftTop
	Util.cylinder(folder, 6, 40, base * CFrame.new(0, pod, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 5, 52, base * CFrame.new(0, pod + 5.5, 0), Color3.fromRGB(190, 188, 182), M.Concrete, true)
	local windows = Util.cylinder(folder, 7, 54, base * CFrame.new(0, pod + 11.5, 0), Color3.fromRGB(40, 50, 60), M.Glass, true)
	windows.Reflectance = 0.35
	Util.cylinder(folder, 4, 50, base * CFrame.new(0, pod + 17, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 4, 36, base * CFrame.new(0, pod + 21, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 0.5, 54.4, base * CFrame.new(0, pod + 8.2, 0), Color3.fromRGB(255, 220, 160), M.Neon, false)
	Util.cylinder(folder, 70, 10, base * CFrame.new(0, pod + 58, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 9, 18, base * CFrame.new(0, pod + 96, 0), CONCRETE, M.Concrete, true)
	Util.cylinder(folder, 3, 18.4, base * CFrame.new(0, pod + 96, 0), Color3.fromRGB(40, 50, 60), M.Glass, true)
	local mastBase = pod + 100
	for i = 0, 7 do
		local color = (i % 2 == 0) and Color3.fromRGB(196, 40, 36) or Color3.fromRGB(236, 236, 232)
		Util.cylinder(folder, 13, 5 - i * 0.45, base * CFrame.new(0, mastBase + 6.5 + i * 13, 0), color, M.Metal, false)
	end
	Util.deco(folder, V3(2, 2, 2), base * CFrame.new(0, mastBase + 106, 0), Color3.fromRGB(255, 40, 40), M.Neon, Enum.PartType.Ball)
	local sign = Util.deco(folder, V3(16, 3, 0.4), base * CFrame.new(0, 6, -NEEDLE_RADIUS + 6), Color3.fromRGB(30, 34, 40), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Front, "THE NEEDLE", Color3.fromRGB(240, 236, 228), Enum.Font.GothamBold)
end

-- The Dome: round stadium with panelled walls and a stepped domed roof.
local function dome(folder, c)
	local x, z = c.X, c.Y
	local r = DOME_RADIUS
	local wallH = 34
	local panels = 36
	local white = Color3.fromRGB(226, 226, 222)
	local panelW = 2 * math.pi * r / panels + 0.6
	for k = 0, panels - 1 do
		local a = k / panels * math.pi * 2
		local pos = V3(x + math.cos(a) * r, wallH / 2, z + math.sin(a) * r)
		local cf = CFrame.lookAt(pos, V3(x, wallH / 2, z))
		local isGate = k % 9 == 0
		Util.solid(folder, V3(panelW, wallH, 3), cf, isGate and Color3.fromRGB(40, 44, 52) or white, isGate and M.Glass or M.Concrete)
		if k % 2 == 0 and not isGate then
			Util.deco(folder, V3(1.2, wallH + 2, 4), cf * CFrame.new(-panelW / 2, 1, 0), Color3.fromRGB(150, 150, 150), M.Metal)
		end
	end
	local rings = { { r + 2, wallH }, { r * 0.86, wallH + 7 }, { r * 0.68, wallH + 12.5 }, { r * 0.47, wallH + 16 }, { r * 0.24, wallH + 18 } }
	for i, ring in ipairs(rings) do
		local color = (i % 2 == 1) and Color3.fromRGB(200, 204, 210) or Color3.fromRGB(176, 180, 186)
		Util.cylinder(folder, 3, ring[1] * 2, CFrame.new(x, ring[2] + 1.5, z), color, M.Metal, true)
	end
	Util.cylinder(folder, 1.2, r * 2 + 4.4, CFrame.new(x, wallH - 2, z), Color3.fromRGB(30, 90, 170), M.Neon, false)
	local sign = Util.deco(folder, V3(36, 6, 0.4), CFrame.lookAt(V3(x, wallH - 9, z - r - 1.8), V3(x, wallH - 9, z - r - 10)), Color3.fromRGB(20, 40, 90), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Front, "THE DOME", Color3.fromRGB(240, 240, 240), Enum.Font.GothamBlack)
end

-- Yonge-Eglinton Centre: the walkable mall (World/Mall.lua) with parking in front.
local function mall(folder, c, rng, Cars)
	local w, d = MALL_SIZE.X, MALL_SIZE.Y
	local info = Mall.build(folder, c, rng)
	local lotFrom = info.southWallZ + 2
	local lotTo = c.Y + d / 2 - 2
	local lotZ = (lotFrom + lotTo) / 2
	Util.deco(folder, V3(w, 0.06, lotTo - lotFrom), CFrame.new(c.X, 0.32, lotZ), Color3.fromRGB(56, 56, 58), M.Asphalt)
	for px = c.X - w / 2 + 8, c.X + w / 2 - 8, 13 do
		Util.deco(folder, V3(0.3, 0.05, 12), CFrame.new(px - 6.5, 0.36, lotZ + 8), Color3.fromRGB(220, 220, 214), M.SmoothPlastic)
		if math.abs(px - c.X) > 10 and rng:NextNumber() < 0.5 then
			local car = Cars.spawnParked(CFrame.new(px, 0.3, lotZ + 8) * CFrame.Angles(0, math.rad(180), 0), folder, rng)
			Util.tick(#car:GetChildren())
		end
	end
	local sign = Util.deco(folder, V3(60, 5, 0.4), CFrame.lookAt(V3(c.X, 28, info.southWallZ - 0.6), V3(c.X, 28, info.southWallZ + 10)), Color3.fromRGB(20, 30, 60), M.SmoothPlastic)
	Util.sign(sign, Enum.NormalId.Front, "YONGE EGLINTON CENTRE", Color3.fromRGB(240, 240, 240), Enum.Font.GothamBlack).LightInfluence = 0
end

-- Grass with paths and trees (parks, the cemetery, civic squares).
local function park(folder, rect, rng, trees, paving)
	local w, d = rect.maxX - rect.minX, rect.maxZ - rect.minZ
	local cx, cz = (rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2
	local ground = Util.solid(folder, V3(w, 1, d), CFrame.new(cx, -0.15, cz), paving and Color3.fromRGB(170, 166, 158) or Color3.fromRGB(86, 110, 64), paving and M.Pavement or M.Grass)
	ground.CastShadow = false
	Util.deco(folder, V3(w, 0.2, 8), CFrame.new(cx, 0.4, cz), Color3.fromRGB(160, 150, 136), M.Pavement)
	for _ = 1, trees do
		local p = Vector2.new(rng:NextNumber(rect.minX + 8, rect.maxX - 8), rng:NextNumber(rect.minZ + 8, rect.maxZ - 8))
		if math.abs(p.Y - cz) > 8 and Util.get(p.X, p.Y) ~= Util.ROAD then
			Props.tree(folder, p, rng, rng:NextNumber(1, 1.4))
		end
	end
end

---------------------------------------------------------------------------
-- Buildings: what goes on each lot
---------------------------------------------------------------------------
local function chooseStyle(rng, road, center)
	local r = rng:NextNumber()
	local hf = T.heightFactor(center)
	if road.main and (center - T.FINANCIAL).Magnitude < 260 and r < 0.6 then
		return "bankTower"
	end
	if T.nearStation(center, 150) then
		if hf < 0.7 then
			return r < 0.55 and "torontoMidrise" or "stripPlaza"
		end
		return TorontoStyles.choose(rng, road, center, T.heightFactor)
	end
	if hf < 0.6 then
		if road.main then
			return r < 0.5 and "stripPlaza" or "massing"
		end
		return "torontoHouse"
	end
	return "massing"
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function Toronto.build(ctx)
	local rng = ctx.rng
	local folder = ctx.folder
	local roads = ctx.roads

	Roads.render(ctx.makeFolder(folder, "Roads"), roads)
	Util.seawall(ctx.makeFolder(folder, "Seawall"), Toronto.bounds, { north = true, west = true, east = true })

	local landmarks = ctx.makeFolder(folder, "Landmarks")
	needle(landmarks, T.NEEDLE)
	dome(landmarks, T.DOME)
	mall(landmarks, T.YONGE_EGLINTON_CENTRE, rng, ctx.Cars)
	TorontoLandmarks.cityHall(landmarks, T.CITY_HALL)
	TorontoLandmarks.union(landmarks, T.UNION, Vector2.new(0, -1))
	TorontoLandmarks.museum(landmarks, T.ROM)
	TorontoLandmarks.twistingTower(landmarks, T.NY_TOWERS[1], 30, 0)
	TorontoLandmarks.twistingTower(landmarks, T.NY_TOWERS[2], 34, 1.3)
	TorontoLandmarks.streetcarLine(landmarks, ctx.named["King St"])
	-- The Eaton Centre, rebuilt from its leasing plans (World/EatonCentre).
	local okEaton, errEaton = pcall(EatonCentre.build, folder, T.EATON)
	if not okEaton then
		warn("[EatonCentre] failed to build: " .. tostring(errEaton))
	end
	DowntownLandmarks.sankofaSquare(ctx.makeFolder(folder, "SankofaSquare"), T.SANKOFA, rng)
	DowntownLandmarks.screenBuilding(ctx.makeFolder(folder, "TenDundasEast"), T.DUNDAS_NE, 74, { "south", "west" }, "10 DUNDAS EAST", rng, { name = "PATTY JUNCTION", side = "sw" })
	DowntownLandmarks.screenBuilding(ctx.makeFolder(folder, "YongeDundasNW"), T.DUNDAS_NW, 58, { "south", "east" }, nil, rng)
	DowntownLandmarks.tmu(ctx.makeFolder(folder, "TMU"), T.TMU_SLC, T.TMU_KERR, T.TMU_SOUTH, rng)
	DowntownLandmarks.uoft(ctx.makeFolder(folder, "UofT"), T.UOFT_SOUTH, T.UOFT_NORTH, rng)
	park(ctx.makeFolder(folder, "MelLastmanSquare"), T.MEL_LASTMAN, rng, 10, false)
	park(ctx.makeFolder(folder, "MountPleasantCemetery"), T.MOUNT_PLEASANT_CEMETERY, rng, 70, false)

	local buildings = ctx.makeFolder(folder, "Buildings")
	local placed = Buildings.placeFrontage(buildings, roads, rng, {
		chooseStyle = chooseStyle,
		heightFactor = T.heightFactor,
		interiorChance = 0.04,
		facadeChance = 0.6,
		ads = true,
	})
	-- Fill the inside of downtown blocks so the core reads as solid city.
	local filled = Buildings.fillGaps(buildings, rng, { minX = T.BATHURST_X - 10, maxX = 1060, minZ = T.shiftZ(-3200), maxZ = -900 })

	-- Street furniture on Yonge, the downtown streets and the main cross streets.
	local furnished = {}
	for _, road in ipairs(roads) do
		if road.main and road.kind ~= "bridge" and not (road.name or ""):find("Edge") then
			table.insert(furnished, road)
		end
	end
	Props.placeStreetFurniture(ctx.makeFolder(folder, "Street"), rng, furnished)
	print(string.format("[Toronto] %d roads, %d buildings, %d downtown fillers", #roads, placed, filled))

	-- Two cars on Yonge near Union.
	local yonge = ctx.named["Yonge St"]
	local carSpawns = {}
	for i = 1, 2 do
		local p = Vector2.new(T.YONGE_X + yonge.width / 2 - 6, T.FRONT_Z - 80 - i * 40)
		table.insert(carSpawns, { cframe = Util.groundCF(p, Vector2.new(0, -1), 0.3) })
	end

	-- Cars along the kerbs everywhere: drivable ones first (clustered round Yonge &
	-- Dundas, where players arrive, then across the city), then parked ones.
	local taken = {}
	local dundasZ = T.FRONT_Z
	for _, s in ipairs(T.STATIONS) do
		if s.name == "DUNDAS" then
			dundasZ = s.z
		end
	end
	local yd = Vector2.new(T.YONGE_X, dundasZ)
	local near = Props.kerbSpots(rng, roads, { kinds = { street = true, avenue = true, arterial = true, yonge = true }, cap = 400, chance = 0.9, gap = { 16, 28 }, avoid = taken })
	table.sort(near, function(a, b)
		return (a.p - yd).Magnitude < (b.p - yd).Magnitude
	end)
	local driveable = 0
	for i, spot in ipairs(near) do
		local close = (spot.p - yd).Magnitude < 420
		if (close and driveable < 10) or (not close and i % 9 == 0 and driveable < 44) then
			table.insert(carSpawns, { cframe = Util.groundCF(spot.p, spot.facing, 0.3), taxi = rng:NextNumber() < 0.25 })
			driveable += 1
		end
	end
	taken = {}
	for _, c in ipairs(carSpawns) do
		table.insert(taken, Vector2.new(c.cframe.X, c.cframe.Z))
	end
	local parked = Props.placeParkedCars(ctx.makeFolder(folder, "ParkedCars"), rng, ctx.Cars, roads, { kinds = { street = true, avenue = true, arterial = true }, cap = 600, chance = 0.55, avoid = taken })
	print(string.format("[Toronto] %d driveable cars, %d parked cars", #carSpawns, parked))
	return { carSpawns = carSpawns }
end

return Toronto
